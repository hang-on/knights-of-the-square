; number_display_lib, i.e.
; 
; Based on Astroswab.
; -----------------------------------------------------------------------------
; SCORE, HISCORE AND TIMER 
; -----------------------------------------------------------------------------
; Important: The number display tiles must be placed in a sequence (0-9),
; and with ASCII_ZERO within the range of ($0 - $e9). 
.equ ASCII_ZERO $c0 ; Where in the tilebank is the ASCII zero?

.equ SCORE_ADDRESS $3810 
.equ TIMER_ADDRESS $387A 
.equ HISCORE_ADDRESS $3832

.equ SCORE_ONES 5
.equ SCORE_TENS 4
.equ SCORE_HUNDREDS 3
.equ SCORE_THOUSANDS 2
.equ SCORE_TEN_THOUSANDS 1
.equ SCORE_HUNDRED_THOUSANDS 0

.equ TIMER_ONES 1
.equ TIMER_TENS 0


.macro ADD_TO ARGS DIGIT, POINTS
  ld a,DIGIT
  ld b,POINTS
  ld hl,score
  call add_to_number
.endm

.struct timer_struct
  tens db
  ones db
.endst

.struct score_struct
  hundred_thousands db
  ten_thousands db                
  thousands db                    
  hundreds db
  tens db
  ones db
.endst

.ramsection "Number display variables" slot 3
  score instanceof score_struct
  hiscore instanceof score_struct
  score_backup instanceof score_struct
  timer instanceof timer_struct
.ends
; -----------------------------------------------------------------------------
.section "Number display functions" free

  add_to_number:
    ; Add a number passed in B to the digit specified in A. Update the other
    ; digits in the score struct as necessary. Credit to Jonathan Cauldwell.
    ; Entry:  A = Digit to add to
    ;         B = Number to add (non-ascii!)
    ;         HL = Pointer to score struct.
    ; Uses: AF, DE, HL
    ld d,0
    ld e,a
    add hl,de
    ld a,b
    add a,(hl)
    ld (hl),a

    cp ASCII_ZERO+10
    ret c
      sub 10
      ld (hl),a
      -:
        dec hl
        ;inc hl ??
        inc (hl)
        ld a,(hl)
        cp ASCII_ZERO+10
        ret c
          sub 10
          ld (hl),a
      jp -
      ;
  ret

  ;
  subtract_from_number:
    ; New version.
    ; Entry:  A = Digit to subtract from.
    ;         B = Number to subtract (non-ascii!).
    ;        HL = Pointer to score struct.
    ld c,a
    ld d,0
    ld e,a
    add hl,de
    ;
    ld a,(hl)
    sub b
    ld (hl),a
    cp ASCII_ZERO
    ret nc
      -:
      add a,10
      ld (hl),a
      ld a,c
      ;cp 0
      ;jp z,reset_score
        dec a
        ld c,a
        dec hl
        dec (hl)
        ld a,(hl)
        cp ASCII_ZERO
        ret nc
      jp -
  ret
  
  set_score:
    ; Entry: HL = Pointer to score object.
    ;        DE = Pointer to ascii string of numbers.
    ; Exit: None
    ex de,hl                            ; Switch to destination (DE).
    ld bc,_sizeof_score_struct          ; Number of digits to reset.
    ldir                                ; Do it.
  ret

  reset_score:
    ; Entry: HL = Pointer to score object.
    ; Exit: None
    ex de,hl                            ; Switch to destination (DE).
    ld hl,@reset_data              ; Point to reset data.
    ld bc,_sizeof_score_struct            ; Number of digits to reset.
    ldir                                ; Do it.
  ret
    @reset_data:
      .rept _sizeof_score_struct
        .db ASCII_ZERO  ;.asc "0"
      .endr

  reset_timer:
    ; Entry: HL = Pointer to timer struct.
    ; Exit: None
    ex de,hl                            ; Switch to destination (DE).
    ld hl,@reset_data              ; Point to reset data.
    ld bc,_sizeof_timer_struct            ; Number of digits to reset.
    ldir                                ; Do it.
  ret
    @reset_data:
      .rept _sizeof_timer_struct
        .db ASCII_ZERO+9  ;.asc "9"
      .endr

  fast_print_score:
    ; Print the digits in a score object to the name table.
    ; Entry: HL = VRAM address.
    ;        IX = Score object.
    ; Exit: None.
    ; Uses: ?
    ;
    ld a,l
    out (CONTROL_PORT),a
    ld a,h
    or VRAM_WRITE_COMMAND
    out (CONTROL_PORT),a
    push ix
    pop hl
    ld b,_sizeof_score_struct
    -:
      ld a,(hl)
      inc hl
      out (DATA_PORT),a           ; Write it to name table.
      ld a,%00000000              ; Select background palette for this char.
      out (DATA_PORT),a           ; Write 2nd byte to name table.
    djnz -
  ret

  safe_draw_number_display:
    ; Print the digits in a number display to the name table.
    ; Entry: A = number of digits 
    ;        HL = VRAM address.
    ;        IX = Number object.
    ; Exit: None.
    ; Uses: ?
    ;
    di
      ld b,a              ; Store number of digits.
      ld a,l
      out (CONTROL_PORT),a
      ld a,h
      or VRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      push ix
      pop hl
      -:
        ld a,(hl)
        inc hl
        out (DATA_PORT),a           ; Write it to name table.
        ld a,%00000000              ; Select background palette for this char.
        push ix
        pop ix
        out (DATA_PORT),a           ; Write 2nd byte to name table.
        push ix
        pop ix
      djnz -
    ei
  ret

  compare_scores:
    ; Compare two score items to each other, passed to this func in IX and IY.
    ; If score in IY is equal or higher then score in IX, then set carry. If
    ; not, then reset carry.
    ; Entry: IX, IY = Pointers to score structs to compare.
    ; Uses: AF

    ld a,(ix+score_struct.hundred_thousands)
    cp (iy+score_struct.hundred_thousands)
    jp c,iy_is_equal_or_higher
    jp z,+
    jp ix_is_higher
    +:
      ld a,(ix+score_struct.ten_thousands)
      cp (iy+score_struct.ten_thousands)
      jp c,iy_is_equal_or_higher
      jp z,+
      jp ix_is_higher
      +:
        ld a,(ix+score_struct.thousands)
        cp (iy+score_struct.thousands)
        jp c,iy_is_equal_or_higher
        jp z,+
        jp ix_is_higher
        +:
          ld a,(ix+score_struct.hundreds)
          cp (iy+score_struct.hundreds)
          jp c,iy_is_equal_or_higher
          jp z,+
          jp ix_is_higher
          +:
            ld a,(ix+score_struct.tens)
            cp (iy+score_struct.tens)
            jp c,iy_is_equal_or_higher
            jp z,+
            jp ix_is_higher
            +:
              ld a,(ix+score_struct.ones)
              cp (iy+score_struct.ones)
              jp c,iy_is_equal_or_higher
              jp z,iy_is_equal_or_higher
              jp ix_is_higher
              ;
    iy_is_equal_or_higher:
      scf
      ret
    ix_is_higher:
      or a
      ret
  ret
  ;



  copy_score_and_increment_pointers:
    ; Copy the contents of one score struct to another.
    ; Entry: Two score struct pointers:
    ;        HL = Source score
    ;        DE = Destination score.
    ; Exit: Increment HL and DE by the size of one score struct.
    ; Uses: None
    push bc
      ld bc,_sizeof_score_struct
      ldir
    pop bc
  ret

.ends
