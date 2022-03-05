
; Put this in the main code somewhere at the start:
; Remove comment to enable unit testing
;.equ TEST_MODE
.ifdef TEST_MODE
  .equ USE_TEST_KERNEL
.endif



.macro ASSERT_A_EQUALS
  cp \1
  jp nz,exit_with_failure
  nop
.endm

.macro ASSERT_A_EQUALS_NOT
  cp \1
  jp z,exit_with_failure
  nop
.endm

.macro ASSERT_HL_EQUALS ; (value)
  push de
  push af
  ld de,\1
  ld a,d
  cp h
  jp nz,exit_with_failure
  ld a,e
  cp l
  jp nz,exit_with_failure
  pop af
  pop de
.endm

.macro ASSERT_TOP_OF_STACK_EQUALS ; (list of bytes to test)
  ld hl,0
  add hl,sp
  .rept NARGS
    ld a,(hl)
    cp \1
    jp nz,exit_with_failure
    inc hl
    ;inc sp                    ; clean stack as we proceed.
    .SHIFT
  .endr
.endm

.macro ASSERT_TOP_OF_STACK_EQUALS_STRING ARGS LEN, STRING
  ; Parameters: Pointer to string, string length. 
  ld de,STRING                ; Comparison string in DE
  ld hl,0                     ; HL points to top of stack.
  add hl,sp       
  .rept LEN                   ; Loop through given number of bytes.
    ld a,(hl)                 ; Get byte from stack.
    ld b,a                    ; Store it.
    ld a,(de)                 ; Get comparison byte.
    cp b                      ; Compare byte on stack with comparison byte.
    jp nz,exit_with_failure   ; Fail if not equal.
    inc hl                    ; Point to next byte in stack.
    inc de                    ; Point to next comparison byte.
  .endr
  ;.rept LEN                   ; Clean stack to leave no trace on the system.
  ;  inc sp        
  ;.endr
.endm

.macro ASSERT_HL_POINTS_TO_STRING ARGS LEN, STRING
  ; Parameters: Pointer to string, string length. 
  ld de,STRING                ; Comparison string in DE
  .rept LEN                   ; Loop through given number of bytes.
    ld a,(hl)                 ; Get byte
    ld b,a                    ; Store it.
    ld a,(de)                 ; Get comparison byte.
    cp b                      
    jp nz,exit_with_failure   ; Fail if not equal.
    inc hl                    ; Point to next byte.
    inc de                    ; Point to next comparison byte.
  .endr
.endm


.macro CLEAN_STACK
  .rept \1
    inc sp
  .endr
.endm

.ramsection "Fake VRAM stuff" slot 3
  fake_sat_y dsb 64
  fake_sat_xc dsb 128
.ends

.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Test data" free
  fake_acm_data:
    ; acm_enabled:
    .db TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE       
    ; acm_frame:
    .db 0 0 1 0 0 0 0 8
    ; acm_timer:
    .db 9 0 0 0 0 0 0 9
    ; acm_pointer:
    .dw cody_walking $0000 dummy_anim dummy_anim $0000 $0000 $0000 $0000
  fake_acm_data_end:
  .equ FULL_ACM fake_acm_data_end-fake_acm_data 

  fake_acm_data_2:
    ; acm_enabled:
    .db TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE       
    ; acm_frame:
    .db 0 0 1 0 0 0 0 8
    ; acm_timer:
    .db 9 0 1 3 0 0 0 9
    ; acm_pointer:
    .dw cody_walking $0000 dummy_anim dummy_anim $0000 $0000 $0000 $0000
  fake_acm_data_2_end:

  fake_acm_data_3: ;(includes the looping dummy anim)
    ; acm_enabled:
    .db TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE       
    ; acm_frame:
    .db 0 0 0 0 0 0 0 1
    ; acm_timer:
    .db 9 0 1 3 0 0 0 1
    ; acm_pointer:
    .dw cody_walking $0000 dummy_anim dummy_anim $0000 $0000 $0000 looping_dummy_anim


  .macro LOAD_ACM
    ld hl,\1
    ld de,acm_enabled
    ld bc,FULL_ACM
    ldir
  .endm

  .macro CLEAR_VJOBS
    ld a,0
    ld hl,vjobs
    .rept 1+(2*VJOB_MAX)
      ld (hl),a
      inc hl
    .endr
  .endm
  


  ; Animation file:
  dummy_anim:
    ; Table of contents:
    .dw @header, @frame_0, @frame_1
     @header:
      .db 1                       ; Max frame.
      .db FALSE                   ; Looping.
    @frame_0:
      .db 5                       ; Duration.
      .db FALSE                   ; Require vjob?
      .dw $0000                   ; Pointer to vjob.
      .db 8                       ; Size.
      .db 10                      ; Index of first tile.
      .dw layout_2x4              ; Pointer to layout.
    @frame_1:
      .db 7                      
      .db FALSE                    
      .dw $0000 
      .db 8                       
      .db 18                       
      .dw layout_2x4              

  looping_dummy_anim:
    ; Table of contents:
    .dw @header, @frame_0, @frame_1
     @header:
      .db 1                       ; Max frame.
      .db TRUE                   ; Looping.
    @frame_0:
      .db 3                       ; Duration.
      .db FALSE                   ; Require vjob?
      .dw $0000                   ; Pointer to vjob.
      .db 8                       ; Size.
      .db 10                      ; Index of first tile.
      .dw layout_2x4              ; Pointer to layout.
    @frame_1:
      .db 3                      
      .db FALSE                    
      .dw $0000 
      .db 8                       
      .db 18                       
      .dw layout_2x4      

.ends

.section "tests" free


  test_bench:
    ; These are the animation tests:

    call initialize_acm
    


  ; These are the tileblaster tests:
    .equ FULL_TBM 1 + TBM_SLOTS + (2*TBM_SLOTS) + (2*TBM_SLOTS) + TBM_SLOTS
    .macro LOAD_TBM
    ld hl,\1
    ld de,tileblaster_tasks
    ld bc,FULL_TBM
    ldir
  .endm 
  jp +
    fake_tbm:
      ; Number of tasks:
      .db 1
      .db 2, 0, 0, 0, 0, 0, 0, 0
      .dw cody_walking_0_tiles, $0000, $0000, $0000, $0000, $0000, $0000, $0000
      .dw SPRITE_BANK_START + CHARACTER_SIZE, $0000, $0000, $0000, $0000, $0000, $0000, $0000
      .db MEDIUM_BLAST, 0, 0, 0, 0, 0, 0, 0
  +:
  RESET_TEST_KERNEL
  LOAD_TBM fake_tbm
  ld a,(tileblaster_tasks)
  ASSERT_A_EQUALS 1
  
  call blast_tiles
  ld a,(tileblaster_tasks)
  ASSERT_A_EQUALS 0
  ld a,(test_kernel_bank)
  ASSERT_A_EQUALS 2
  ld hl,test_kernel_source
  call get_word
  ASSERT_HL_EQUALS cody_walking_0_tiles
  ld hl,test_kernel_destination
  call get_word
  ASSERT_HL_EQUALS SPRITE_BANK_START + CHARACTER_SIZE
  ld hl,test_kernel_bytes_written
  call get_word 
  ASSERT_HL_EQUALS MEDIUM_BLAST_SIZE_IN_BYTES

  jp +
    fake_tileblaster_task:
      .db 2
      .dw cody_walking_1_and_3_tiles
      .dw SPRITE_BANK_START + CHARACTER_SIZE
      .db MEDIUM_BLAST
  +:
  RESET_TEST_KERNEL
  LOAD_TBM fake_tbm
  ld hl,fake_tileblaster_task
  call add_tileblaster_task
  ld a,(tileblaster_tasks)
  ASSERT_A_EQUALS 2
  
  ld a,1
  ld hl,tbm_source
  call offset_word_table
  call get_word
  ASSERT_HL_EQUALS cody_walking_1_and_3_tiles
  ld a,1
  ld hl,tbm_destination
  call offset_word_table
  call get_word
  ASSERT_HL_EQUALS SPRITE_BANK_START + CHARACTER_SIZE
  ld a,1
  ld hl,tbm_size
  call offset_byte_table
  ld a,(hl)
  ASSERT_A_EQUALS MEDIUM_BLAST
  ld a,1
  ld hl,tbm_bank
  call offset_byte_table
  ld a,(hl)
  ASSERT_A_EQUALS 2


  RESET_TEST_KERNEL
  LOAD_TBM fake_tbm_1
  jp +
    fake_tbm_1: ; zero tasks, but with garbage..
      ; Number of tasks:
      .db 0
      .db 12, 0, 0, 0, 0, 0, 0, 0
      .dw cody_walking_0_tiles, $0000, $0000, $0000, $0000, $0000, $0000, $0000
      .dw SPRITE_BANK_START + CHARACTER_SIZE, $0000, $0000, $0000, $0000, $0000, $0000, $0000
      .db 40, 0, 0, 0, 0, 0, 0, 0
  +:
  call blast_tiles
  ld a,(tileblaster_tasks)
  ASSERT_A_EQUALS 0
  ld a,(test_kernel_bank)
  ASSERT_A_EQUALS 0
  ld hl,test_kernel_source
  call get_word
  ASSERT_HL_EQUALS $0000

  ; ------- end of tests --------------------------------------------------------
  exit_with_succes:
    ld a,11
    ld b,BORDER_COLOR
    call set_register
  -:
    nop
  jp -

  exit_with_failure:
    ld a,8
    ld b,BORDER_COLOR
    call set_register
  -:
    nop
  jp -
.ends
