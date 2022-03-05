; VDP lib.
; Generic, low level VDP routines.
;
; Contents:
; Sprite Attribute Table (SAT) handler.
; A simple flicker-enabled engine for handling hardware sprites.
; --- Add Sprite: Add a sprite tile to the buffer.
; --- Load SAT: Load the SAT with the buffer.
; --- Refresh SAT Handler: Reset buffer and load mode.
; VDP Register Handler. 
; --- Initialize Registers: Load all 11 registers with a string of values.
; --- Set Display: Turn the display on/off.
; --- Set Register: Load a byte into a given register.
; Misc. VDP Functions.
; --- Clear Video RAM (VRAM): Write 00 to all (16K) vram addresses.
; --- Load Color RAM (CRAM): Load a string of colors into CRAM.
; --- Load Video RAM: Load a string of bytes into VRAM.
; --- Setup Video RAM write: Send a destination address to VDP, but not data.
; --- Wait for VBLANK: Keep looping until VBLANK interrupt is detected.

; -----------------------------------------------------------------------------
; SAT Handler
; -----------------------------------------------------------------------------
.equ PRIORITY_SPRITES 5         ; Number of tiles not part of asc/desc flicker.
.equ ASCENDING 0
.equ DESCENDING $ff
.equ SAT_Y_SIZE HARDWARE_SPRITES
.equ SAT_XC_SIZE HARDWARE_SPRITES*2
; -----------------------------------------------------------------------------
.ramsection "SAT Handler Variables" slot 3
; -----------------------------------------------------------------------------
  sat_buffer_y dsb HARDWARE_SPRITES
  sat_buffer_xc dsb HARDWARE_SPRITES*2
  sat_buffer_index db
  load_mode db             ; Ascending or descending - for flickering.
.ends
; -----------------------------------------------------------------------------
.section "SAT Handler" free
; -----------------------------------------------------------------------------   
  add_sprite:
    ; Add a sprite of size = 1 character to the SAT.
    ; Entry: C = Char.
    ;        D = Y origin.
    ;        E = X origin.
    ; Exit: None
    ; Uses: A,
    ;
    push de
    push hl
    ; Test for sprite overflow (more than 64 hardware sprites at once).
    ld a,(sat_buffer_index)
    cp HARDWARE_SPRITES
    jp nc,exit_add_sprite
    ;
    ; Point DE to sat_buffer_y[sat_buffer_index].
    ld hl,sat_buffer_y
    call offset_byte_table
    ;
    ld a,d
    ld (hl),a          
    ;
    ; Point DE to sat_buffer_xc[sat_buffer_index].
    ld a,(sat_buffer_index)
    ld hl,sat_buffer_xc
    call offset_word_table
    ;
    ld a,e                  ; Get the x-pos.
    ld (hl),a
    inc hl
    ld (hl),c             ; Write the char (it should still be there)
    ;
    ld hl,sat_buffer_index
    inc (hl)
    ;
    exit_add_sprite:
    pop hl
    pop de
  ret
  ;
  load_sat:
    ; Load the vram sat with the SatY and SatXC buffers.
    ; Sonic 2 inspired flicker engine is in place: Flicker sprites by loading the
    ; SAT in ascending/descending order every other frame.
    ;
    ld hl,SAT_Y_START           ; Load the sprite Y-positions into the SAT.
    call setup_vram_write
    ld hl,sat_buffer_y
    ld c,DATA_PORT
    ;
    ld a,(load_mode)
    cp DESCENDING
    jp z,+
      .rept SAT_Y_SIZE
        outi
      .endr
      jp ++
    +:
      .rept PRIORITY_SPRITES
        outi
      .endr
      ld hl,sat_buffer_y+SAT_Y_SIZE-1  ; Point to last y-value in buffer.
      .rept HARDWARE_SPRITES-PRIORITY_SPRITES
        outd                    ; Output and decrement HL, thus going
      .endr                     ; backwards (descending) through the buffer.
    ++:
    ;                           
    ld hl,SAT_XC_START          ; Load the X-position and character code pairs
    call setup_vram_write       ; of the sprites into the SAT.
    ld hl,sat_buffer_xc
    ld c,DATA_PORT
    ;
    ld a,(load_mode)
    cp DESCENDING
    jp z,+
      .rept SAT_XC_SIZE
        outi
      .endr
      jp ++
    +:
      .rept PRIORITY_SPRITES
        outi
        outi
      .endr
      ;
      ld hl,sat_buffer_xc+SAT_XC_SIZE-2
      ld de,-4
      .rept HARDWARE_SPRITES-PRIORITY_SPRITES
        outi
        outi
        add hl,de
      .endr
    ++:
    ld a,(load_mode)
    cpl
    ld (load_mode),a
  ret
  ;
  refresh_sat_handler:
    ; Clear SAT buffer (Y), buffer index and toggle load mode.
    ; Entry: None
    ; Exit:
    ; Uses: A
    xor a
    ld (sat_buffer_index),a
    ; Toggle descending load mode on/off
    ld a,(load_mode)
    cp DESCENDING
    jp z,+
      ld a,DESCENDING
      jp ++
    +:
      cpl
    ++:
    ld (load_mode),a
    ld a,(load_mode)
    cpl
    ld (load_mode),a
    ;
    ld hl,clean_buffer
    ld de,sat_buffer_y
    ld bc,HARDWARE_SPRITES
    ldir
    ;
  ret
  clean_buffer:                       ; Data for a clean sat Y buffer.
    .rept HARDWARE_SPRITES
      .db 192
    .endr
.ends

; -----------------------------------------------------------------------------
; VDP Register Handler
; -----------------------------------------------------------------------------
  .equ MODE_0 0
  .equ MODE_1 1
  .equ BORDER_COLOR 7
  .equ HSCROLL 8
  .equ VSCROLL 9
  .equ LINE_INTERRUPT 10
; -----------------------------------------------------------------------------
; -----------------------------------------------------------------------------
.ramsection "VDP Register Variables" slot 3
; -----------------------------------------------------------------------------
  vdp_registers dsb 11
.ends
; -----------------------------------------------------------------------------
.section "VDP Register Handler" free
; -----------------------------------------------------------------------------
  initialize_vdp_registers:
    ; Load 11 bytes of init values into the 11 VDP registers and the RAM mirror.
    ; Entry: HL = Pointer to initialization data (11 bytes).
    ; Exit:  None
    ; Uses:  A, BC, DE, HL
    ld de,vdp_registers
    ld b,11
    ld c,0
    -:
      ld a,(hl)
      ld (de),a
      out (CONTROL_PORT),a
      ld a,REGISTER_WRITE_COMMAND
      or c
      out (CONTROL_PORT),a
      inc hl
      inc de
      inc c
    djnz -
  ret
  ;
  set_display:
    ; Use value passed in A to either set or reset the display bit of vdp
    ; register 1 mirror. Then load the whole mirror into the actual register.
    ; Entry: A = $ff = enable display, else disable display.
    ; Uses: A, B, HL 
    ld hl,vdp_registers+1
    cp $ff
    jp z,+
      res 6,(hl)
      jp ++
    +:
      set 6,(hl)
    ++:
    ld a,(hl)
    ld b,1
    call set_register
  ret
  ;
  set_register:
    ; Write to target register and register mirror.
    ; Entry: A = byte to be loaded into vdp register.
    ;        B = target register 0-10.
    ; Uses: AF, B, DE, HL
    ld hl,vdp_registers
    ld d,0
    ld e,b
    add hl,de
    ld (hl),A
    out (CONTROL_PORT),a
    ld a,REGISTER_WRITE_COMMAND
    or b
    out (CONTROL_PORT),a
  ret
.ends
; -----------------------------------------------------------------------------
; -----------------------------------------------------------------------------
.section "Misc. VDP functions" free
; -----------------------------------------------------------------------------
  clear_vram:
    ; Write 00 to all vram addresses.
    ; Uses AF, BC
    xor a
    out (CONTROL_PORT),a
    or VRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
    ld bc,VRAM_SIZE ; This is the whole 16K of VRAM.
    -:
      xor a
      out (DATA_PORT),a
      dec bc
      ld a,b
      or c
    jp nz,-
  ret  
  
  load_cram:
    ; Consecutively load a number of color values into color ram (CRAM), given a
    ; destination color to write the first value.
    ; Entry: A = Destination color in color ram (0-31)
    ;        B = Number of color values to load
    ;        HL = Base address of source data (color values are bytes = SMS)
    ; Uses: AF, BC, HL
    ; Assumes blanked display and interrupts off.
    out (CONTROL_PORT),a
    ld a,CRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
    -:
      ld a,(hl)
      out (DATA_PORT),a
      inc hl
    djnz -
  ret

  load_vram:
    ; Load a number of bytes from a source address into vram.
    ; Entry: A = Bank
    ;        BC = Number of bytes to load
    ;        DE = Destination address in vram
    ;        HL = Source address
    ; Exit:  DE = Next free byte in vram.
    ; Uses: AF, BC, DE, HL,
    .ifdef USE_TEST_KERNEL
      push hl
      pop ix ; save HL
      ld hl,test_kernel_destination
      ld (hl),e
      inc hl
      ld (hl),d
      ld hl,test_kernel_bytes_written
      ld (hl),c
      inc hl
      ld (hl),b
      ld hl,test_kernel_source
      push ix
      pop de
      ld (hl),e
      inc hl
      ld (hl),d
    .else
      ld (SLOT_2_CONTROL),a
      ld a,e
      out (CONTROL_PORT),a
      ld a,d
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      -:
        ld a,(hl)
        out (DATA_PORT),a
        inc hl
        dec bc
        ld a,c
        or b
      jp nz,-
    .endif
  ret

  setup_vram_write:
    ; HL = Address in vram
    ld a,l
    out (CONTROL_PORT),a
    ld a,h
    or VRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
  ret

  wait_for_vblank:
    ; Wait until vblank interrupt > 0.
    ld hl,vblank_counter
    -:
      ld a,(hl)
      cp 0
    jp z,-
    ; Reset counter.
    xor a
    ld (hl),a
  ret
.ends