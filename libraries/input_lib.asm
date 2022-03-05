; Input_lib.asm


; -----------------------------------------------------------------------------
.ramsection "Input library variables" slot 3
; -----------------------------------------------------------------------------
  input_ports dw
  ;  

.ends

.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Input library functions" free
; -----------------------------------------------------------------------------

  is_reset_pressed:
    ld a,(input_ports+1)
    and %00010000
    ret nz            ; Return with carry flag reset
    scf
  ret                 ; Return with carry flag set.

  is_button_1_or_2_pressed:
    ld a,(input_ports)
    and %00010000
    jp nz,+            
      scf
      ret
    +:
    ld a,(input_ports)
    and %00100000
    ret nz
    scf
  ret                 ; Return with carry flag set.


  is_button_1_pressed:
    ld a,(input_ports)
    and %00010000
    ret nz            ; Return with carry flag reset
    scf
  ret                 ; Return with carry flag set.

  is_button_2_pressed:
    ld a,(input_ports)
    and %00100000
    ret nz            ; Return with carry flag reset
    scf
  ret                 ; Return with carry flag set.

  is_dpad_pressed:
    ld a,(input_ports)
    and %00001111   ; Isolate the dpad bits.
    cpl             ; Invert bits; now 1 = keypress!
    and %00001111   ; Get rid of garbage from cpl in last four bits.
    cp 0            ; Now, is any dpad key preseed?
    ret z           ; No, then return with carry flag reset (by the AND).
    scf             ; Yes, then set carry flag and...
  ret               ; Return with carry flag set.

  is_left_or_right_pressed: ; might be buggy!!
    ld a,(input_ports)
    and %00001100   ; Isolate the bits.
    cpl             ; Invert bits; now 1 = keypress!
    and %00001100   ; Get rid of garbage 
    cp 0            ;
    ret z           ; No, then return with carry flag reset (by the AND).
    scf             ; Yes, then set carry flag and...
  ret               ; Return with carry flag set.

  is_left_pressed:
    ld a,(input_ports)
    and %00000100
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.

  is_right_pressed:
    ld a,(input_ports)
    and %00001000
    ret nz          ; Return with carry flag reset
    scf
  ret               ; Return with carry flag set.


  is_player_2_button_1_pressed:
    ld a,(input_ports+1)
    and %00000100
    ret nz            ; Return with carry flag reset
    scf
  ret                 ; Return with carry flag set.


  refresh_input_ports:
    ; Set input_ports (word) to mirror current state of ports $dc and $dd.
    in a,(INPUT_PORT_1)
    ld (input_ports),a
    in a,(INPUT_PORT_2)
    ld (input_ports+1),a
  ret


.ends