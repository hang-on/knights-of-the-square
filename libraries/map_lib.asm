; Library to interface with map (Tiled, converter etc.)
; -----------------------------------------------------------------------------
; Map
; Note: This lib needs access to quite some tables. Best placed in bank 1.
; TODO: Refactor this lib around a MAP_TABLES_BANK constant.
; -----------------------------------------------------------------------------
.equ MAP_HEIGHT 10        ; Height in metatiles.
; -----------------------------------------------------------------------------
.ramsection "Map Variables" slot 3
; -----------------------------------------------------------------------------
  tile_buffer dsb MAP_HEIGHT*2
  metatile_buffer dsb MAP_HEIGHT
  map_head dw
  nametable_head db
  metatile_halves db          ; Convert left or right half of the metatile to tiles.
  end_of_map db
.ends

; -----------------------------------------------------------------------------
.section "Map" free
; -----------------------------------------------------------------------------   

;  Core functions
  initialize_map:
    ; In: Nothing. It uses the value in current_level to load the map data.
    ld a,(current_level)
    add a,LEVEL_BANK_OFFSET
    ld (SLOT_2_CONTROL),a

    ; Init end of map data (fixme: This is overly complex - use LUT).
    ld hl,level_map_table
    ld a,(current_level)
    call lookup_word
    jp +
      level_map_table:
        .dw level_0_map, level_1_map
    +:
    push hl
      ld hl,level_map_size_table
      ld a,(current_level)
      call lookup_word
      jp +
        level_map_size_table:
          .dw SIZEOF_STANDARD_LEVEL_TILEMAP
          .dw SIZEOF_BOSS_LEVEL_TILEMAP
      +:
      ex de,hl
    pop hl
    add hl,de
    ld a,l
    ld b,h
    ld hl,end_of_map_data
    ld (hl),a
    inc hl
    ld (hl),b
    
    ; Init map head
    ld hl,level_map_table
    ld a,(current_level)
    call lookup_word  
    ld a,l
    ld (map_head),a
    ld a,h
    ld (map_head+1),a
    
    call map_column_to_metatile_buffer

    ld a,FALSE
    ld (end_of_map),a
  ret

  draw_columns:
    ; IN: B = Number of nametable columns to draw.
    ; Fast and unsafe!
    -:
      push bc
        call next_metatile_half_to_tile_buffer
        call tilebuffer_to_nametable
      pop bc
    djnz -
  ret


  map_column_to_metatile_buffer:
      ; Read a column.
    ld hl,(map_head)
    ld de,metatile_buffer
    ld bc,MAP_HEIGHT      
    ldir
    ; Forward map head.
    ld hl,(map_head)
    ld de,MAP_HEIGHT      
    add hl,de
    ld a,l
    ld (map_head),a
    ld a,h
    ld (map_head+1),a
  ret

  next_metatile_half_to_tile_buffer:
    ld a,(metatile_halves)
    cp 0
    jp nz,+
      call convert_left_half_of_metatile_column
      jp ++
    +:
      call convert_right_half_of_metatile_column
      call map_column_to_metatile_buffer          ; Ready next metatile column.
    ++:
    ld a,(metatile_halves)
    cpl
    ld (metatile_halves),a
  ret

  tilebuffer_to_nametable:
    ; Fast and unsafe. Run when interrupts = disabled + display = disabled.
    ld a,(nametable_head)
    ld h,0
    ld l,a
    add hl,hl
    ld de,column_loader_table
    add hl,de
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    call function_at_hl
    ; Forward the name table head:
    ld a,(nametable_head)
    cp 31
    jp nz,+
      xor a
      jp ++
    +:
      inc a
    ++:
    ld (nametable_head),a
  ret

.ends

.bank 1 slot 1
 ; ----------------------------------------------------------------------------
.section "Tables" free
; -----------------------------------------------------------------------------
  column_loader_table:
    ; To be indexed by the variable name_table_head.
    .dw load_column_0
    .dw load_column_1
    .dw load_column_2
    .dw load_column_3
    .dw load_column_4
    .dw load_column_5
    .dw load_column_6
    .dw load_column_7
    .dw load_column_8
    .dw load_column_9
    .dw load_column_10
    .dw load_column_11
    .dw load_column_12
    .dw load_column_13
    .dw load_column_14
    .dw load_column_15
    .dw load_column_16
    .dw load_column_17
    .dw load_column_18
    .dw load_column_19
    .dw load_column_20
    .dw load_column_21
    .dw load_column_22
    .dw load_column_23
    .dw load_column_24
    .dw load_column_25
    .dw load_column_26
    .dw load_column_27
    .dw load_column_28
    .dw load_column_29
    .dw load_column_30
    .dw load_column_31

  ; Convert left half of a column of metatiles to tiles in the buffer.
  convert_left_half_of_metatile_column:
    .rept MAP_HEIGHT INDEX COUNT
      ld a,(metatile_buffer+COUNT)
      ld hl,top_left_corner ;
      call lookup_byte      ; 
      ld (tile_buffer+(COUNT*2)),a
      ld a,(metatile_buffer+COUNT)
      ld hl,bottom_left_corner
      call lookup_byte      
      ld (tile_buffer+(COUNT*2)+1),a
    .endr
  ret

  ; Convert right half of a column of metatiles to tiles in the buffer.
  convert_right_half_of_metatile_column:
    .rept MAP_HEIGHT INDEX COUNT
      ld a,(metatile_buffer+COUNT)
      ld hl,top_right_corner ;
      call lookup_byte      ; 
      ld (tile_buffer+(COUNT*2)),a
      ld a,(metatile_buffer+COUNT)
      ld hl,bottom_right_corner
      call lookup_byte      
      ld (tile_buffer+(COUNT*2)+1),a
    .endr
  ret
  
  top_left_corner:
  ; ID 0 1 2 3 4 5  6  7  8  9  10 11 12 13 14 15
   .db 0 2 4 6 8 10 12 14 16 18 20 22 24 26 28 30
  ; ID 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 
   .db 64 66 68 70 72 74 76 78 80 82 84 86 88 90 92 94
  ; ID 32  33  34  35  36  37  38  39  40  41  42  43  44  45  46  47 
   .db 128 130 132 134 136 138 140 142 144 146 148 150 152 154 156 158

  bottom_left_corner:
    .rept 16 INDEX COUNT
      ; ID 0-15
      .db 32+(COUNT*2)
    .endr 
    .rept 16 INDEX COUNT
      ; ID 16-31
      .db 96+(COUNT*2)
    .endr 
    .rept 16 INDEX COUNT
      ; ID 32-47
      .db 160+(COUNT*2)
    .endr 

  top_right_corner:
    .rept 16 INDEX COUNT
      ; ID 0-15
      .db 1+(COUNT*2)
    .endr 
    .rept 16 INDEX COUNT
      ; ID 16-31
      .db 65+(COUNT*2)
    .endr 
    .rept 16 INDEX COUNT
      ; ID 32-47
      .db 129+(COUNT*2)
    .endr 

  bottom_right_corner:
    .rept 16 INDEX COUNT
      ; ID 0-15
      .db 33+(COUNT*2)
    .endr 
    .rept 16 INDEX COUNT
      ; ID 16-31
      .db 97+(COUNT*2)
    .endr 
    .rept 16 INDEX COUNT
      ; ID 32-47
      .db 161+(COUNT*2)
    .endr 

  ; Unrolled loops to quickly load a name table column from the buffer.
  .macro COLUMN_LOADER ARGS ADDRESS
    load_column_\@:
      .rept MAP_HEIGHT*2 INDEX COUNT
        ld hl,ADDRESS+COUNT*64
        ld a,l
        out (CONTROL_PORT),a
        ld a,h
        or VRAM_WRITE_COMMAND
        out (CONTROL_PORT),a
        ld a,(tile_buffer+COUNT)
        out (DATA_PORT),a              
        ; Set priority bit on tile id = 0 (grass tile).
        ;or a
        ;jp nz,+ 
          ;ld a,%00010001
          ;jp ++
        +:
          ld a,%00000001
        ++:
        out (DATA_PORT),a
      .endr
    ret
  .endm
  .rept 32 INDEX COLUMN
    ; A loader function for each column on the nametable.
    COLUMN_LOADER $3880+(COLUMN*2)
  .endr

.ends