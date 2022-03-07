; Knights of the Square. Demo for the SMS-Power coding competition 2022. 
.sdsctag 1.0, "Knights of the Square", "Capcom's classic... if it was a single-plane kung-fu style sidescroller with cute gfx. (Demo / proof of concept).", "hang-on Entertainment"
; -----------------------------------------------------------------------------
.memorymap
; -----------------------------------------------------------------------------
  defaultslot 0
  slotsize $4000
  slot 0 $0000
  slot 1 $4000
  slot 2 $8000
  slotsize $2000
  slot 3 $c000
.endme
.rombankmap ; 128K rom
  bankstotal 8
  banksize $4000
  banks 8
.endro
;
; -----------------------------------------------------------------------------
; GLOBAL DEFINITIONS
; -----------------------------------------------------------------------------
.include "libraries/sms_constants.asm"

; Remove comment to enable unit testing
; .equ TEST_MODE
.ifdef TEST_MODE
  .equ USE_TEST_KERNEL
.endif

.bank 0 slot 0
.section "Game states" free
  .equ INITIALIZE_LEVEL 0
  .equ RUN_LEVEL 1
  .equ START_NEW_GAME 2
  .equ FINISH_LEVEL 3
  .equ INITIALIZE_CHAPTER_COMPLETED 4
  .equ RUN_CHAPTER_COMPLETED 5
  .equ INITIALIZE_END_OF_DEMO 6
  .equ RUN_END_OF_DEMO 7
  .equ INITIALIZE_TITLE 8
  .equ RUN_TITLE 9
  .equ INITIALIZE_GAME_OVER 10
  .equ RUN_GAME_OVER 11
  .equ INITIALIZE_MINIMAP 12
  .equ RUN_MINIMAP 13
  .equ INITIALIZE_SPLASH 14
  .equ RUN_SPLASH 15
  .equ INITIAL_GAMESTATE INITIALIZE_SPLASH
  ;.equ INITIAL_GAMESTATE INITIALIZE_CHAPTER_COMPLETED
    game_state_jump_table:
    .dw initialize_level, run_level 
    .dw start_new_game, finish_level 
    .dw initialize_chapter_completed, run_chapter_completed
    .dw initialize_end_of_demo, run_end_of_demo
    .dw initialize_title, run_title
    .dw initialize_game_over, run_game_over
    .dw initialize_minimap, run_minimap
    .dw initialize_splash, run_splash
.ends

; Development dashboard:

.equ FIRST_LEVEL 0
;.equ MUSIC_OFF          ; Comment to turn music on
;.equ DISABLE_MINIONS    ; Comment to enable minions.
;.equ DISABLE_SCROLL     ; Comment to scroll levels normally.
;.equ SPAWN_BOSS_INSTANTLY ; Comment to spawn boss normally.

.equ SFX_BANK 3
.equ MUSIC_BANK 3
.equ MISC_ASSETS_BANK 6
.equ MISC_ASSETS_BANK_II 7

.equ SCROLL_POSITION 152
.equ LEFT_LIMIT 10
.equ RIGHT_LIMIT 240
.equ FLOOR_LEVEL 127

.equ LEFT 1
.equ RIGHT 0
; 
.equ IDLE 0
.equ WALKING 1
.equ ATTACKING 2
.equ JUMPING 3
.equ JUMP_ATTACKING 4
.equ HURTING 5
.equ DEAD 6

.equ ANIM_COUNTER_RESET 4
.equ PLAYER_WALKING_SPEED 1
.equ PLAYER_JUMPING_HSPEED 2

.equ SWORD_HEIGHT 4
.equ SWORD_WIDTH 4

.equ HEALTH_MAX 13
.equ INVINCIBILITY_TIMER_MAX 70
.equ TIMER_DELAY_VALUE 140


.equ SIZEOF_LEVEL_TILES $bf*32
.equ LEVEL_BANK_OFFSET 4        ; Level data is at current level + offset
.equ SIZEOF_STANDARD_LEVEL_TILEMAP $501  ; Size in bytes.
.equ SIZEOF_BOSS_LEVEL_TILEMAP $281

.macro TRANSITION_PLAYER_STATE ARGS NEWSTATE, SFX
  ; Perform the standard actions when the player's state transitions:
  ; 1) Load new state into state variable, 2) reset animation frame and
  ; 3) (optional) play a sound effect.
  LOAD_BYTES state, NEWSTATE, frame, 0      ; Set the state and frame variables.
  .IF NARGS == 2                            ; Is an SFX pointer provided?
    call PSGSFXGetStatus
    cp PSG_STOPPED
    jp nz,TRANSITION\@
      ld hl,SFX                               ; If so, point HL to the SFX-data.
      ld c,SFX_CHANNELS2AND3                  ; Set the channel.
      call PSGSFXPlay                         ; Play the SFX with PSGlib.
    TRANSITION\@:
  .ENDIF
.endm


; Hierarchy: Most fundamental first. 
.include "libraries/psglib.inc"
.include "libraries/vdp_lib.asm"
.include "libraries/map_lib.asm"
.include "libraries/input_lib.asm"
.include "libraries/tiny_games.asm"
.include "libraries/number_display_lib.asm"
.include "libraries/minions_lib.asm"
.include "libraries/items_lib.asm"
.include "libraries/brute_lib.asm"
.include "libraries/boss_lib.asm"

.include "sub_workshop.asm"
.include "sub_tests.asm"        

; -----------------------------------------------------------------------------
.ramsection "Variables" slot 3
; -----------------------------------------------------------------------------
  temp_byte db                  ; Temporary variable - byte.
  temp_word db                  ; Temporary variable - word.
  temp_counter dw               ; Temporary counter.
  temp_composite_counter dsb 3
  ;
  vblank_counter db
  hline_counter db
  pause_flag db
  ;
  substate db
  substate_counter dw
  ctrl_lock db

  ; Player variables. Note - this order is expected!
  anim_counter dw
  frame db
  direction db
  state db
  attack_counter dw
  
  player_y db
  player_x db
  player_height db
  player_width db
  ; ------------
  jump_counter db
  hurt_counter dw
  hspeed db
  vspeed db
  invincibility_timer db
  health db                 ; The player's health

  killbox_y db
  killbox_x db
  killbox_height db
  killbox_width db
  ; ----------------

  force_end_level_counter dw
  is_boss_dead db
  timer_delay dw
  current_level db
  is_scrolling db
  hscroll_screen db ; 0-255
  hscroll_column db ; 0-7
  column_load_trigger db ; flag
  scroll_enabled db
  end_of_map_data dw
  exit_locked db      ; Can you progress from the level now?
  wait_counter dw

  vblank_finish_low db
  vblank_finish_high db
  odd_frame db
  frame_counter db
  rnd_seed dw
  game_state db

  accept_button_1_input db
  accept_button_2_input db

  PaletteBuffer dsb 32  
.ends

.org 0
.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Boot" force
; -----------------------------------------------------------------------------
  boot:
  di
  im 1
  ld sp,$dff0
  ;
  ; Initialize the memory control registers.
  ld de,$fffc
  ld hl,initial_memory_control_register_values
  ld bc,4
  ldir
  FILL_MEMORY $00
  ;
  jp init
  ;
  initial_memory_control_register_values:
    .db $00,$00,$01,$02
.ends
.org $0038
; ---------------------------------------------------------------------------
.section "!VDP interrupt" force
; ---------------------------------------------------------------------------
  push af
  push hl
    in a,CONTROL_PORT
    bit INTERRUPT_TYPE_BIT,a  ; HLINE or VBLANK interrupt?
    jp z,+
      ld hl,vblank_counter
      inc (hl)
      jp ++
    +:
      ld hl,hline_counter
      inc (hl)
    ++:
  pop hl
  pop af
  ei
  reti
.ends
.org $0066
; ---------------------------------------------------------------------------
.section "!Pause interrupt" force
; ---------------------------------------------------------------------------
  push af
    ld a,(pause_flag)
    cpl
    ld (pause_flag),a
  pop af
  retn
.ends
; -----------------------------------------------------------------------------
.section "main" free
; -----------------------------------------------------------------------------
  init:
  ; Run this function once (on game load/reset). 
    ld hl,vdp_register_init
    call initialize_vdp_registers
    call clear_vram
    
    ld a,1
    ld b,BORDER_COLOR
    call set_register
    ld a,0
    ld b,32
    ld hl,all_black_palette
    call load_cram
    jp +
      sweetie16_palette:
        .db $00 $00 $11 $12 $17 $1B $2E $19 $14 $10 $35 $38 $3D $3F $2A $15
        .db $00 $00 $11 $12 $17 $1B $2E $19 $14 $10 $35 $38 $3D $3F $2A $15
      all_black_palette:
        .db $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .db $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 
      test_palette:
        .db $00 $2E $17 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .db $00 $2E $17 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
    +:

    .ifdef TEST_MODE
      ld a,0
      ld b,32
      ld hl,test_palette
      call load_cram

      ld a,ENABLED
      call set_display
      jp test_bench
    .endif

    ; Seed the randomizer.
    ld hl,my_seed
    ld a,(hl)
    ld (rnd_seed),a
    inc hl
    ld a,(hl)
    ld (rnd_seed+1),a
    jp +
      my_seed:
      .dbrnd 2, 0, 255
    +:

    call PSGInit

    ; Score:
    ld hl,score
    call reset_score

    ld hl,hiscore
    ld de,hiscore_init
    call set_score
    jp +
      hiscore_init:
        .db ASCII_ZERO, ASCII_ZERO+1, ASCII_ZERO, ASCII_ZERO, ASCII_ZERO, ASCII_ZERO
    +:

    ld a,INITIAL_GAMESTATE
    ld (game_state),a
    
  jp main_loop

    vdp_register_init:
    .db %01100110  %10100000 $ff $ff $ff
    .db $ff $fb $f0 $00 $00 $00

    vdp_register_init_show_left_column:
    .db %01000110  %10100000 $ff $ff $ff
    .db $ff $fb $f0 $00 $00 $00


  ; ---------------------------------------------------------------------------
  main_loop:
    ld a,(game_state)   ; Get current game state - it will serve as JT offset.
    add a,a             ; Double it up because jump table is word-sized.
    ld h,0              ; Set up HL as the jump table offset.
    ld l,a
    ld de,game_state_jump_table ; Point to JT base address
    add hl,de           ; Apply offset to base address.
    ld a,(hl)           ; Get LSB from table.
    inc hl              ; Increment pointer.
    ld h,(hl)           ; Get MSB from table.
    ld l,a              ; HL now contains the address of the state handler.
    jp (hl)             ; Jump to this handler - note, not call!
  ; ---------------------------------------------------------------------------
  start_new_game: 
    call PSGSilenceChannels

    ; Score:
    ld hl,score
    call reset_score

    ; Timer
    ld hl,timer
    call reset_timer


    LOAD_BYTES health, HEALTH_MAX ; Start the game with full health.

    LOAD_BYTES current_level, FIRST_LEVEL

    ld a,INITIALIZE_MINIMAP
    ld (game_state),a
    
    jp main_loop

  ; ---------------------------------------------------------------------------
  initialize_level:
    call PSGSilenceChannels
    call PSGStop
    call PSGSFXStop
    call PSGSFXFrame
    call PSGFrame
    halt
    halt
    di
    ld hl,vdp_register_init
    call initialize_vdp_registers    
    call clear_vram

    ld a,1
    ld b,BORDER_COLOR
    call set_register

    ld a,(current_level)
    add a,LEVEL_BANK_OFFSET
    ld hl,sprite_tiles
    ld de,$0000
    ld bc,_sizeof_sprite_tiles
    call load_vram

    ld hl,level_tiles_table
    ld a,(current_level)
    call lookup_word
    jp +
      level_tiles_table:
        .dw level_0_tiles, level_1_tiles
    +:
    ld a,(current_level)
    add a,LEVEL_BANK_OFFSET
    ld de,BACKGROUND_BANK_START
    ld bc,SIZEOF_LEVEL_TILES 
    call load_vram

    LOAD_BYTES pause_flag, 0

    RESET_VARIABLES 0, frame, direction, jump_counter, hspeed, vspeed
    LOAD_BYTES player_y, 127, player_x, 60, state, IDLE
    LOAD_BYTES player_height, 13, player_width, 13
    RESET_BLOCK ANIM_COUNTER_RESET, anim_counter, 2
    RESET_BLOCK _sizeof_attacking_frame_to_index_table*ANIM_COUNTER_RESET, attack_counter, 2

    LOAD_BYTES killbox_y, 0, killbox_x, 0
    LOAD_BYTES killbox_height, SWORD_HEIGHT, killbox_width, SWORD_WIDTH

    RESET_BLOCK $0e, tile_buffer, 20
    LOAD_BYTES metatile_halves, 0, nametable_head, 0
    LOAD_BYTES hscroll_screen, 0, hscroll_column, 0, column_load_trigger, 0
    LOAD_BYTES vblank_finish_high, 0, vblank_finish_low, 255
    LOAD_BYTES odd_frame, TRUE, frame_counter, 0

    LOAD_BYTES is_boss_dead, FALSE

    LOAD_BYTES accept_button_1_input, FALSE, accept_button_2_input, FALSE

    LOAD_BYTES exit_locked, FALSE  ; Todo: Boss will lock it.

    RESET_COUNTER hurt_counter, 24
    RESET_COUNTER timer_delay, TIMER_DELAY_VALUE


    LOAD_BYTES invincibility_timer, 0


    .ifdef DISABLE_SCROLL
      LOAD_BYTES scroll_enabled, FALSE
    .else
      LOAD_BYTES scroll_enabled, TRUE
    .endif

    ; Initialize the minions.
    call initialize_minions

    ; Initialize the items.
    call initialize_items

    ; Initialize the brute.
    call initialize_brute

    ; Initialize the boss.
    call initialize_boss

    ; Make solid block special tile in SAT.
    ld a,2
    ld bc,CHARACTER_SIZE
    ld hl,solid_block
    ld de,START_OF_UNUSED_SAT_AREA
    call load_vram
    jp +
      solid_block:
        ; Filled with color 1 in the palette:
        .db $FF $00 $00 $00 $FF $00 $00 $00 $FF $00 $00 $00 $FF $00 $00 $00 $FF $00 $00 $00 $FF $00 $00 $00 $FF $00 $00 $00 $FF $00 $00 $00

    +:

    ; Clear the bottom two rows with that special tile.
    ld hl,NAME_TABLE_START+(32*22*2)
    call setup_vram_write
    ld b,32*2
    -:
      ld a,$fa ; Tilebank index of special tile.
      out (DATA_PORT),a
      ld a,%00000001
      out (DATA_PORT),a
    djnz -

    ld hl,mockup_dashboard
    ld a,TRUE
    ld b,0
    ld c,_sizeof_mockup_dashboard
    call copy_string_to_nametable

    call initialize_map    
    ; Draw a full screen 
    ld b,32
    call draw_columns

    ; Fill the blanked column.
    call next_metatile_half_to_tile_buffer
    call tilebuffer_to_nametable

    ; Music:
    ld a,(current_level)
    cp 0
    jp nz,+
      ld hl,village_on_fire
      call PSGPlay
      jp ++
    +:
      call PSGResume
    ++:

    call refresh_sat_handler
    call refresh_input_ports

    ei
    halt
    halt
    call load_sat
    xor a
    ld (vblank_counter),a
    
    ld a,ENABLED
    call set_display

    call FadeInScreen

    ld a,RUN_LEVEL
    ld (game_state),a
  jp main_loop

  mockup_dashboard:
    .db $fc $fc $e6 $e7 $e8 $e5 $e9 $ed $c0 $c0 $c0 $c0 $c0 $c0 $fc $fc $fc
    .db $ea $eb $e6 $e7 $e8 $e5 $e9 $ed $c0 $c0 $c0 $c0 $c0 $c0
    .db $fc $fc $fc $e0 $e1 $e2 $e3 $e4 $e5
    .db $ee $ef $ef $ef $ef $ef $ef $ef $ef $ef $ef $ef $ef $f0 $f1 $fc 
    .db $e2 $eb $ec $e9 $ed $c0 $c0 $fc
  __:

  run_level:
    ld a,(current_level)
    add a,LEVEL_BANK_OFFSET
    SELECT_BANK_IN_REGISTER_A      
    call wait_for_vblank
    
    ; Begin vblank critical code (DRAW) ---------------------------------------
    call load_sat

    ld a,(column_load_trigger)
    cp 0
    jp z,+
      xor a
      ld (column_load_trigger),a
      call tilebuffer_to_nametable
    +:

    ; Sync the vdp-scroll with the ram-mirror.
    ld a,(hscroll_screen)
    ld b,HORIZONTAL_SCROLL_REGISTER
    call set_register 

    ; Quick and dirty vblank profiling.
    ; Note: A high value of $DA means vblank finishes between 218-223.
    in a,V_COUNTER_PORT                 ; Get the counter. 
    ld b,a                              ; Store in B.
    ld a,(vblank_finish_low)            ; Get the current lowest value.
    cp b                                ; Compare to counter value.
    jp c,+                              ; Is counter > lowest value? 
      ld a,b                            ; No, we got a new lowest. Get counter.
      ld (vblank_finish_low),a          ; Store in ram.
      jp ++                             ; Skip next part.
    +:                                  ; Not new lowest - maybe new highest?
      ld a,(vblank_finish_high)         ; Get the current highest value. 
      cp b                              ; Compare to counter value.
      jp nc,++                          ; Is counter > highest value?
        ld a,b                          ; Yes = new highest! Get counter.
        ld (vblank_finish_high),a       ; Store in ram.
    ++:                                 ;

    ; End of critical vblank routines. ----------------------------------------
    begin_profile:

    ; Begin general updating (UPDATE).
    .ifdef MUSIC_OFF
      call PSGStop
    .endif
    ld a,MUSIC_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGFrame
    ld a,SFX_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGSFXFrame

    ld a,(pause_flag)
    cp 0
    jp nz,main_loop
    
    ld a,(current_level)
    add a,4                   ; FIXME: Don't we have an offset const?
    SELECT_BANK_IN_REGISTER_A
    
    call refresh_sat_handler
    call refresh_input_ports

    ld a,(odd_frame)                ; Get value, either TRUE or FALSE.
    cpl                             ; Invert (TRUE -> FALSE, FALSE -> TRUE).
    ld (odd_frame),a                ; Store value.
    ld hl,frame_counter
    inc (hl)

    ; Seed the random number generator with button 1.
    call is_button_1_pressed
    jp nc,+
      call get_random_number
    +:

    ; Set the player's direction depending on controller input (LEFT/RIGHT).
    ld a,(direction)
    cp LEFT
    jp z,+
    cp RIGHT
    jp z,++
    +: ; Player is facing left.
      call is_right_pressed
      jp nc,+
        ld a,RIGHT
        ld (direction),a
      +:
      jp +++
    ++: ; Player is facing right.
      call is_left_pressed
      jp nc,+
        ld a,LEFT
        ld (direction),a
      +:
    +++:

    RESET_VARIABLES 0, vspeed, hspeed

    ld a,(state)
    cp IDLE ; is state = idle?
    jp z,handle_idle_state
    cp WALKING ; is state = walking?
    jp z,handle_walking_state
    cp ATTACKING
    jp z,handle_attacking_state
    cp JUMPING
    jp z,handle_jumping_state
    cp JUMP_ATTACKING
    jp z,handle_jump_attacking_state
    cp HURTING
    jp z,handle_hurting_state
    ; Fall through to error
    -:
      nop ; STATE ERROR
    jp -

    handle_idle_state:      
      call is_button_1_pressed
      jp nc,+
        ld a,(accept_button_1_input)
        cp TRUE
        jp nz,+
          TRANSITION_PLAYER_STATE ATTACKING, slash_sfx
          jp _f
      +:
      call is_left_or_right_pressed
      jp nc,+
        ; Directional input - switch from idle to walking.
        LOAD_BYTES state, WALKING, frame, 0
        jp _f
      +:
      call is_button_2_pressed
      jp nc,+
        ld a,(accept_button_2_input)
        cp TRUE
        jp nz,+
          TRANSITION_PLAYER_STATE JUMPING, jump_sfx
          jp _f
      +:
      jp _f

    handle_walking_state:
      call is_button_1_pressed
      jp nc,+
        ld a,(accept_button_1_input)
        cp TRUE
        jp nz,+
          TRANSITION_PLAYER_STATE ATTACKING, slash_sfx
        jp _f
      +:
      call is_left_or_right_pressed
      jp c,+
        ; Not directional input.
        TRANSITION_PLAYER_STATE IDLE
        jp _f
      +:
      call is_button_2_pressed
      jp nc,+
        ld a,(accept_button_2_input)
        cp TRUE
        jp nz,+
          TRANSITION_PLAYER_STATE JUMPING, jump_sfx
          jp _f
      +:
      ld a,(direction)
      cp RIGHT
      ld a,PLAYER_WALKING_SPEED
      jp z,+
        neg
      +:
      ld (hspeed),a
      jp _f

    handle_attacking_state:
      ld hl,attack_counter
      call tick_counter
      jp nc,+
        TRANSITION_PLAYER_STATE IDLE
      +:
    jp _f

    handle_jumping_state:
      ld a,(jump_counter)
      ld hl,jump_counter_to_vspeed_table
      call lookup_byte
      ld (vspeed),a

      ld a,(jump_counter)
      inc a
      cp 32
      jp nz,+
        TRANSITION_PLAYER_STATE IDLE
        LOAD_BYTES jump_counter, 0
        jp _f
      +:
      ld (jump_counter),a
      
      call is_left_or_right_pressed
      jp nc,+ 
        ld a,(jump_counter)
        ld hl,jump_counter_to_hspeed_table
        call lookup_byte
        ld b,a      
        ld a,(direction)
        cp RIGHT
        ld a,b
        jp z,+
          neg
        +:
        ld (hspeed),a
      +:

      call is_button_1_pressed
      jp nc,+
        ld a,(accept_button_1_input)
        cp TRUE
        jp nz,+
          TRANSITION_PLAYER_STATE JUMP_ATTACKING, slash_sfx
      +:
    jp _f

    handle_jump_attacking_state:
      ld a,(jump_counter)
      ld hl,jump_counter_to_vspeed_table
      call lookup_byte
      ld (vspeed),a

      ld a,(jump_counter)
      inc a
      cp 32
      jp nz,+
        ld a,(attack_counter)
        cp 0
        jp nz,@continue_with_attack
          ; If not attacking, continue with idle.
          TRANSITION_PLAYER_STATE IDLE        
          LOAD_BYTES jump_counter, 0
          jp _f
        @continue_with_attack:
          ; if attacking
          TRANSITION_PLAYER_STATE ATTACKING        
          LOAD_BYTES jump_counter, 0
          jp _f
      +:
      ld (jump_counter),a
      
      ld hl,attack_counter
      call tick_counter
      jp nc,+
        TRANSITION_PLAYER_STATE JUMPING
      +:

      call is_left_or_right_pressed
      jp nc,+ 
        ld a,(jump_counter)
        ld hl,jump_counter_to_hspeed_table
        call lookup_byte
        ld b,a      
        ld a,(direction)
        cp RIGHT
        ld a,b
        jp z,+
          neg
        +:
        ld (hspeed),a
      +:

    jp _f

    handle_hurting_state:      
      ld a,(player_y)
      cp FLOOR_LEVEL
      jp nc,+
        ld a,1
        ld (vspeed),a
      +:
      LOAD_BYTES jump_counter, 0
      ld hl,hurt_counter
      call tick_counter
      jp nc,+
        ; Counter is up - stop hurting, and go to idle.
        TRANSITION_PLAYER_STATE IDLE
      +:
    jp _f
    __: ; End of player state checks. 

    ld a,(invincibility_timer)
    cp 0
    jp z,+
      dec a
      ld (invincibility_timer),a
    +:

    ; State of buttons 1 and 2 to differentiate keydown/keypress.
    ld a,FALSE
    ld (accept_button_1_input),a
    ld (accept_button_2_input),a
    call is_button_1_pressed
    jp c,+
      ld a,TRUE
      ld (accept_button_1_input),a
    +:
    call is_button_2_pressed
    jp c,+
      ld a,TRUE
      ld (accept_button_2_input),a
    +:

    ld a,FALSE
    ld (is_scrolling),a
    ld a,(scroll_enabled)
    cp TRUE
    jp nz,+    
      ; Check if screen should scroll instead of right movement.
      ld a,(player_x)
      cp SCROLL_POSITION
      jp c,+
        ; Player is over the scroll position
        ld a,(hspeed)
        bit 7,a             ; Negative value = walking left
        jp nz,+ 
        cp 0                ; Zero = no horizontal motion.
        jp z,+
          xor a
          ld (hspeed),a
          ; Scroll instead
          ld a,TRUE
          ld (is_scrolling),a
          ld a,(hscroll_screen)
          dec a                     
          ld (hscroll_screen),a
          
          ld a,(hscroll_column)
          inc a                     
          ld (hscroll_column),a
          cp 8
          jp nz,+
            xor a
            ld (hscroll_column),a
            ; Load new column
            call next_metatile_half_to_tile_buffer
            ld hl,column_load_trigger               ; Load on next vblank.
            inc (hl)
    +:

    ; End of map check.
    ld a,(end_of_map)
    cp TRUE
    jp z,_f
      
      ld hl,(end_of_map_data)
      ex de,hl
      ld hl,(map_head)
      sbc hl,de
      jp c,_f
        ld a,FALSE
        ld (scroll_enabled),a
        ld (spawn_minions),a
        ld a,TRUE
        ld (end_of_map),a
    __:

    ; Check if player is about to exit the left side of the screen.
    ld a,(player_x)
    cp LEFT_LIMIT
    jp nc,+
      ld a,(hspeed)
      bit 7,a             ; Positive value = walking right
      jp z,+ 
      cp 0                ; Zero = no horizontal motion.
      jp z,+
        xor a
        ld (hspeed),a
    +:

    ; Check if player is about to exit the right side of the screen.
    ld a,(player_x)
    cp RIGHT_LIMIT
    jp c,+
      ld a,(hspeed)
      bit 7,a             ; Negative value = walking left
      jp nz,+ 
      cp 0                ; Zero = no horizontal motion.
      jp z,+
        xor a
        ld (hspeed),a
        ld a,(end_of_map)
        cp TRUE
        jp nz,+
          ld a,(exit_locked)
          cp FALSE
          jp nz,+
            call PSGSFXStop
            call PSGSilenceChannels
            ld a,FINISH_LEVEL
            ld (game_state),a
            jp main_loop
    +:

    ; Apply this frame's h and v speed to the player y,x
    ld a,(vspeed)
    ld b,a
    ld a,(player_y)
    add a,b
    ld (player_y),a
    ld a,(hspeed)
    ld b,a
    ld a,(player_x)
    add a,b
    ld (player_x),a
    
    ; Count down to next frame.
    ld hl,anim_counter
    call tick_counter
    jp nc,+
      ld hl,frame
      inc (hl)
    +:
    ; Reset/loop animation if last frame expires. 
    ld a,(state)
    ld hl,state_to_frames_total_table
    call lookup_byte
    ld b,a
    ld a,(frame)
    cp b
    jp nz,+
      xor a
      ld (frame),a
    +:

    call draw_player
    jp _f
      draw_player:
        ; Put the sprite tiles in the SAT buffer. 
        ld a,(state)
        ld hl,state_to_frame_table
        call lookup_word
        ld a,(frame)
        call lookup_byte
        ld b,0
        push af
          .equ ONE_ROW_OFFSET 64
          ; Offset to left-facing tiles if necessary.
          ld a,(direction)
          ld b,0
          cp RIGHT
          jp z,+
            ld b,ONE_ROW_OFFSET
          +:
          ld a,(player_y)
          ld d,a
          ld a,(player_x)
          ld e,a
        pop af
        add a,b                           ; Apply offset (0 or ONE_ROW)
        
        call spr_2x2
      ret
    __:

    LOAD_BYTES killbox_y, 0, killbox_x, 0
    ; Add the sword sprite on the relevant player states.
    ld a,(state)
    cp ATTACKING
    jp z,+
    cp JUMP_ATTACKING
    jp z,+
    jp _f
    +:
      ld a,(frame)
      cp 1
      jp c,_f
        ld a,(direction)
        cp RIGHT
        jp nz,+
          ld c,32
          ld a,(player_y)
          add a,8
          ld d,a
          ld (killbox_y),a
          ld a,(player_x)
          add a,16
          ld e,a
          ld (killbox_x),a
          call add_sprite
          jp _f
        +:
          ld c,64
          ld a,(player_y)
          add a,8
          ld d,a
          ld (killbox_y),a
          ld a,(player_x)
          sub 8
          ld e,a
          ld a,(killbox_width)
          ld b,a
          ld a,(player_x)
          sub b
          ld (killbox_x),a
          call add_sprite
    __:

    ; Minions
    call process_minions
    call draw_minions

    ; Items
    call process_items
    call draw_items

    ; Brute
    call process_brute
    call draw_brute

    ; Boss
    call update_boss
    call draw_boss

    ; Update the score
    ld a,_sizeof_score_struct
    ld ix,score
    ld hl,SCORE_ADDRESS
    call safe_draw_number_display

    ld iy,score
    ld ix,hiscore
    call compare_scores
    jp nc,+
      ; Make hiscore mirror current score.
      ld hl,score
      ld de,hiscore
      ld bc,_sizeof_score_struct
      ldir
    +:


    ; Update the hiscore
    ld a,_sizeof_score_struct
    ld ix,hiscore
    ld hl,HISCORE_ADDRESS
    call safe_draw_number_display


    ; Update the timer
    ld hl,timer_delay
    call tick_counter
    jp nc,+
      ; Time to shave one second of the timer
      ; But is the timer at 00?
      ld hl,timer
      ld a,(hl)
      cp ASCII_ZERO
      jp nz,++
        inc hl
        ld a,(hl)
        cp ASCII_ZERO
        jp nz,++
          ; Timer is 00, game over instead of decrement.
          call PSGStop
          call PSGSFXStop
          call FadeOutScreen
          ld a,INITIALIZE_GAME_OVER
          ld (game_state),a
          jp main_loop
      ++:
      ld a,TIMER_ONES
      ld b,1
      ld hl,timer
      call subtract_from_number
    +:
    ld a,_sizeof_timer_struct
    ld ix,timer
    ld hl,TIMER_ADDRESS
    call safe_draw_number_display

    jp _f ; Skip over the functions below.
      ; Player health regulating functions
      dec_health:
        ; Amount in A.
        ld b,a
        ld a,(health)
        sub b
        bit 7,a       ; Has health dropped below zero?
        jp z,+
          ; Player dies.
          TRANSITION_PLAYER_STATE DEAD
          xor a       ; Reset health to zero.
          ; Player has lost all health:
          ld (health),a
          ld hl,player_hurt_sfx
          ld c,SFX_CHANNELS2AND3                            
          call PSGSFXPlay                
          ld b,80
          -:
            push bc
              halt
              call load_sat
              
              call refresh_sat_handler
              call draw_player

              ld a,SFX_BANK
              SELECT_BANK_IN_REGISTER_A
              call PSGSFXFrame
            pop bc
          djnz -
          call FadeOutScreen
          ld a,INITIALIZE_GAME_OVER
          ld (game_state),a
          jp main_loop
        +:
        ld (health),a
        ld hl,player_hurt_sfx
        ld c,SFX_CHANNELS2AND3                  
        call PSGSFXPlay      
      ret

      inc_health:
        ; Amount in A.
        ld b,a
        ld a,(health)
        add a,b
        cp HEALTH_MAX
        jp z,+
        jp c,+
          ld a,HEALTH_MAX       ; Cannot go over health max.
        +:
        ld (health),a
      ret
    
    draw_health_bar:
      ld hl,$3852
      call setup_vram_write
      ld a,(health)
      cp 0
      jp z,+
        ld b,a
        -:
          ld a,239
          out (DATA_PORT),a
          push ix
          pop ix
          ld a,0
          out (DATA_PORT),a
          push ix
          pop ix
        djnz -
      +:
      ; Fill the rest of the bar with empty tiles
      ld a,(health)
      ld b,a
      ld a,HEALTH_MAX
      sub b
      cp 0
      jp z,+
        ld b,a
        -:
          ld a,240
          out (DATA_PORT),a
          push ix
          pop ix
          ld a,0
          out (DATA_PORT),a
          push ix
          pop ix
        djnz -
      +:
    ret    
    __:
    call draw_health_bar

    ld a,(is_boss_dead)
    cp TRUE
    jp nz,+
      ld hl,force_end_level_counter
      call tick_counter
      jp nc,+
        call PSGSFXStop
        call PSGSilenceChannels
        ld a,FINISH_LEVEL
        ld (game_state),a
    +:

  end_profile: ; For profiling...
  jp main_loop

  ; Data for controlling the player character.
  idle_frame_to_index_table:
    .db 1 1 3 3 5 7 7 
    __:

  walking_frame_to_index_table:
    .db 1 9 11 13 11 9  
    __:
  
  attacking_frame_to_index_table:
    .db 13 15 17
    __:

  jumping_frame_to_index_table:
    .db 1
    __:

  jump_attacking_frame_to_index_table:
    .db 13 15 17
    __:
  
  hurting_frame_to_index_table:
    .db 19
    __:

  dead_frame_to_index_table:
    .db 30
    __:

  state_to_frame_table:
    .dw idle_frame_to_index_table
    .dw walking_frame_to_index_table
    .dw attacking_frame_to_index_table
    .dw jumping_frame_to_index_table
    .dw jump_attacking_frame_to_index_table
    .dw hurting_frame_to_index_table
    .dw dead_frame_to_index_table
    __:

  state_to_frames_total_table:
    .db _sizeof_idle_frame_to_index_table
    .db _sizeof_walking_frame_to_index_table
    .db _sizeof_attacking_frame_to_index_table
    .db _sizeof_jumping_frame_to_index_table
    .db _sizeof_jump_attacking_frame_to_index_table
    .db _sizeof_hurting_frame_to_index_table
    .db _sizeof_dead_frame_to_index_table

  jump_counter_to_vspeed_table:
    .db -5, -4, -3, -3, -3, -3, -3, -3, -3, -3, -3, -3, -2, -2, -1, -1 
    .db 1 1 2 2 3 3 3 3 3 3 3 3 3 3 4 5 

  jump_counter_to_hspeed_table:
    .db 4 3 3 2 2 2 2 2 2 2 2 2 2 2 2 2
    .db 2 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1

  finish_level:
    call FadeOutScreen
    ld a,(current_level)
    inc a       ; Fixme: Also check for other stuff, like the end...
    cp 2        
    jp nz,+     
      ; The demo ends after level 1...
      ld a,INITIALIZE_CHAPTER_COMPLETED
      ld (game_state),a
      jp main_loop
    +:
    ld (current_level),a
    ld a,INITIALIZE_LEVEL
    ld (game_state),a
  jp main_loop

  ; ---------------------------------------------------------------------------
  initialize_chapter_completed:
    call PSGStop

    di
    call clear_vram
    ld hl,vdp_register_init
    call initialize_vdp_registers    

    ld a,1
    ld b,BORDER_COLOR
    call set_register

    ld a,DISABLED
    call set_display

    ld a,MISC_ASSETS_BANK
    ld hl,chapter_completed_tiles
    ld de,BACKGROUND_BANK_START
    ld bc,_sizeof_chapter_completed_tiles
    call load_vram

    ld a,MISC_ASSETS_BANK
    ld hl,chapter_completed_tilemap
    ld de,NAME_TABLE_START
    ld bc,_sizeof_chapter_completed_tilemap
    call load_vram
    
    ld a,MISC_ASSETS_BANK_II
    ld hl,misc_sprite_tiles
    ld de,SPRITE_BANK_START
    ld bc,_sizeof_misc_sprite_tiles
    call load_vram

    ld hl,mockup_dashboard
    ld a,TRUE
    ld b,0
    ld c,_sizeof_mockup_dashboard
    call copy_string_to_nametable

    LOAD_BYTES substate, 0
    RESET_COUNTER substate_counter, 60
    
    ; For developing, dummy set timer
    ld hl,timer_data
    ld de,timer
    ;ldi
    ;ldi
    jp +
      timer_data:
        .db ASCII_ZERO+3, ASCII_ZERO+6 
    +:
    ; For developing, dummy set timer
    ld hl,@score_data
    ld de,score
    ld bc,_sizeof_score_struct
    ;ldir
    jp +
      @score_data:
        .db ASCII_ZERO, ASCII_ZERO, ASCII_ZERO+1, ASCII_ZERO+3
        .db ASCII_ZERO+5, ASCII_ZERO 
    +:


    ; For development, dummy set health
    ;LOAD_BYTES health, 5

    call draw_health_bar

    ld a,_sizeof_timer_struct
    ld ix,timer
    ld hl,TIMER_ADDRESS
    call safe_draw_number_display

    ; Update the score
    ld a,_sizeof_score_struct
    ld ix,score
    ld hl,SCORE_ADDRESS
    call safe_draw_number_display

    ; Update the hiscore
    ld a,_sizeof_score_struct
    ld ix,hiscore
    ld hl,HISCORE_ADDRESS
    call safe_draw_number_display

    call refresh_sat_handler


    ei
    halt
    halt
    call wait_for_vblank    
    call load_sat

    ld a,ENABLED
    call set_display

    call FadeInScreen

    ld a,RUN_CHAPTER_COMPLETED
    ld (game_state),a

  jp main_loop

  run_chapter_completed:    
    call wait_for_vblank
    
    ; Begin vblank critical code (DRAW) ---------------------------------------
    call load_sat

    ; End of critical vblank routines. ----------------------------------------

    ; Begin general updating (UPDATE).
    ld a,MUSIC_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGFrame
    ld a,SFX_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGSFXFrame
    
    call refresh_sat_handler
    call refresh_input_ports

    ; Branch depending on substate
    ld a,(substate)   
    add a,a             ; Double it up because jump table is word-sized.
    ld h,0              ; Set up HL as the jump table offset.
    ld l,a
    ld de,@substate_jt  ; Point to JT base address
    add hl,de           ; Apply offset to base address.
    ld a,(hl)           ; Get LSB from table.
    inc hl              ; Increment pointer.
    ld h,(hl)           ; Get MSB from table.
    ld l,a              ; HL now contains the address of the state handler.
    jp (hl)             ; Jump to this handler - note, not call!

    @substate_jt:
      .dw @intro
      .dw @time_to_score
      .dw @pause_0
    
    @intro:
      .equ YPOS 90
      
      ld d,YPOS
      ld e,(256-12)/2
      ld a,3
      call spr_3x3      

      ld hl,substate_counter
      call tick_counter
      jp nc,+
        RESET_COUNTER temp_counter, 10
        ld hl,substate
        inc (hl)
        jp main_loop
      +:
    
    jp main_loop
    
    @time_to_score:
      ld d,YPOS
      ld e,(256-12)/2
      ld a,3
      call spr_3x3      

      ; Is timer 00?
      ld hl,timer
      ld a,(hl)
      cp ASCII_ZERO
      jp nz,+
        inc hl
        ld a,(hl)
        cp ASCII_ZERO
        jp nz,+
          ; Timer is down to 00.
          RESET_COUNTER substate_counter, 145
          ld hl,substate
          inc (hl)
          ld hl,score_tally_music
          call PSGPlayNoRepeat
          RESET_COUNTER wait_counter 200
          LOAD_BYTES ctrl_lock, TRUE
          jp main_loop
      +:

      ; Dec timer.
      ld hl,temp_counter
      call tick_counter
      jp nc,+
        ld hl,tick
        ld c,SFX_CHANNEL2
        call PSGSFXPlay

        ; Add to score
        ADD_TO SCORE_TENS, 5
        ld a,_sizeof_score_struct
        ld hl,SCORE_ADDRESS
        ld ix,score
        call safe_draw_number_display

        ld a,TIMER_ONES
        ld b,1
        ld hl,timer
        call subtract_from_number
      +:
      ld a,_sizeof_timer_struct
      ld hl,TIMER_ADDRESS
      ld ix,timer
      call safe_draw_number_display

      ld iy,score
      ld ix,hiscore
      call compare_scores
      jp nc,+
        ; Make hiscore mirror current score.
        ld hl,score
        ld de,hiscore
        ld bc,_sizeof_score_struct
        ldir
      +:

      ; Update the hiscore
      ld a,_sizeof_score_struct
      ld ix,hiscore
      ld hl,HISCORE_ADDRESS
      call safe_draw_number_display

    jp main_loop

    @pause_0:
      ld d,YPOS
      ld e,(256-12)/2
      ld a,6
      call spr_3x3      

    ld a,(ctrl_lock)
    cp TRUE
    jp nz,+
      ld hl,wait_counter
      call tick_counter
      jp nc,+
        ld a,FALSE
        ld (ctrl_lock),a
    +:


    ld a,(ctrl_lock)
    cp TRUE
    jp z,+
      call is_button_1_or_2_pressed
      jp nc,+
        call FadeOutScreen      
        ld a,INITIALIZE_END_OF_DEMO
        ld (game_state),a
        call PSGStop
        halt
        jp main_loop
    +:

    call PSGGetStatus
    cp PSG_PLAYING
    jp z,+
        call FadeOutScreen      
        ld a,INITIALIZE_END_OF_DEMO
        ld (game_state),a
        call PSGStop
        halt
        jp main_loop
    +:


    jp main_loop

      ;call is_button_1_or_2_pressed
      ;jp nc,+
      ;  call FadeOutScreen
      ;  ld a,INITIALIZE_END_OF_DEMO
      ;  ld (game_state),a
      ;+:


  ; ---------------------------------------------------------------------------
  initialize_end_of_demo:
    ld a,DISABLED
    call set_display
        
    call PSGStop


    di
    call clear_vram
    ld hl,vdp_register_init_show_left_column
    call initialize_vdp_registers    

   
    ld a,0
    ld b,32
    ld hl,ukraine_palette
    call load_cram
    
    jp +
    ukraine_palette:
      .db $00 $00 $11 $12 $17 $1B $34 $0f $14 $10 $35 $38 $3D $3F $2A $15
      .db $00 $00 $11 $12 $17 $1B $34 $0f $14 $10 $35 $38 $3D $3F $2A $15
    +:

    ld a,1
    ld b,BORDER_COLOR
    call set_register

    ld a,MISC_ASSETS_BANK_II
    ld hl,misc_sprite_tiles
    ld de,SPRITE_BANK_START
    ld bc,_sizeof_misc_sprite_tiles
    call load_vram

    ld a,MISC_ASSETS_BANK_II
    ld hl,end_of_demo_tiles
    ld de,BACKGROUND_BANK_START
    ld bc,_sizeof_end_of_demo_tiles
    call load_vram

    ld a,MISC_ASSETS_BANK_II
    ld hl,end_of_demo_tilemap
    ld de,NAME_TABLE_START
    ld bc,_sizeof_end_of_demo_tilemap
    call load_vram

    ld hl,end_of_demo_music
    call PSGPlay

    RESET_COUNTER temp_counter, 30
    LOAD_BYTES temp_byte, 15, frame_counter, 0

    RESET_COUNTER wait_counter, 140
    LOAD_BYTES ctrl_lock, TRUE

    call refresh_sat_handler
    call refresh_input_ports
    call load_sat

    ei
    halt
    ld a,ENABLED
    call set_display
    call wait_for_vblank    

    ;call FadeInScreen

    ld a,RUN_END_OF_DEMO
    ld (game_state),a

  jp main_loop
  
  run_end_of_demo:
    call wait_for_vblank
    
    ; Begin vblank critical code (DRAW) ---------------------------------------
    call load_sat

    ; End of critical vblank routines. ----------------------------------------

    ld hl,frame_counter
    inc (hl)

    ; Begin general updating (UPDATE).
    ld a,(temp_byte)
    ld l,a
    call PSGSetMusicVolumeAttenuation
    ld hl,temp_counter
    call tick_counter
    jp nc,+
      ; Fade in music by turning down attenuation
      ld a,(temp_byte)
      cp 0
      jp z,+
        dec a
        ld (temp_byte),a
    +:

    ld a,MUSIC_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGFrame
    ld a,SFX_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGSFXFrame
    
    call refresh_sat_handler
    call refresh_input_ports

    ;ld a,96
    ld a,(frame_counter)
    ld hl,flag_anim
    call lookup_byte
    ld d,143
    ld e,16
    call spr_3x4

    jp _f
      flag_anim:
      .rept 10
        .db 96 96 96 96 96
        .db 100 100 100 100
        .db 104 104 104 104
        .db 108 108 108 108 108
        .db 112 112 112 112
        .db 116 116 116 116
      .endr

    __:

    ld a,(ctrl_lock)
    cp TRUE
    jp nz,+
      ld hl,wait_counter
      call tick_counter
      jp nc,+
        ld a,FALSE
        ld (ctrl_lock),a
    +:


    ld a,(ctrl_lock)
    cp TRUE
    jp z,+
      call is_button_1_or_2_pressed
      jp nc,+
        call FadeOutScreen      
        ld a,INITIALIZE_TITLE
        ld (game_state),a
        call PSGStop
        halt
    +:
  jp main_loop

  ; ---------------------------------------------------------------------------
  initialize_title:
    ;call PSGStop
    ;call PSGSFXStop
    ;call PSGSilenceChannels
    di
    ld hl,vdp_register_init_show_left_column
    call initialize_vdp_registers    
    call clear_vram

    ld a,1
    ld b,BORDER_COLOR
    call set_register

    ld a,0
    ld b,32
    ld hl,sweetie16_palette
    call load_cram

    ld a,MISC_ASSETS_BANK
    ld hl,title_tiles
    ld de,BACKGROUND_BANK_START
    ld bc,_sizeof_title_tiles
    call load_vram

    ld a,MISC_ASSETS_BANK
    ld hl,title_tilemap
    ld de,NAME_TABLE_START
    ld bc,_sizeof_title_tilemap
    call load_vram
  
    ld a,LEVEL_BANK_OFFSET  ; Use lvl 0 tiles..
    ld hl,sprite_tiles
    ld de,SPRITE_BANK_START
    ld bc,_sizeof_sprite_tiles
    call load_vram

    ld hl,mockup_dashboard
    ld a,TRUE
    ld b,0
    ld c,_sizeof_mockup_dashboard/2
    call copy_string_to_nametable

    RESET_VARIABLES 0, frame, direction, jump_counter, hspeed, vspeed
    LOAD_BYTES player_y, 87, player_x, 105, state, WALKING
    LOAD_BYTES player_height, 13, player_width, 13
    RESET_BLOCK ANIM_COUNTER_RESET, anim_counter, 2
    LOAD_BYTES temp_byte,TRUE
    RESET_COUNTER wait_counter, 100

    ; Update the score
    ld a,_sizeof_score_struct
    ld ix,score
    ld hl,SCORE_ADDRESS
    call safe_draw_number_display

    ; Update the hiscore
    ld a,_sizeof_score_struct
    ld ix,hiscore
    ld hl,HISCORE_ADDRESS
    call safe_draw_number_display

    call PSGInit

    ld hl,title_music
    call PSGPlay
    ;call PSGRestoreVolumes


    call refresh_sat_handler
    call refresh_input_ports

    ei
    halt
    halt
    call wait_for_vblank    
    call load_sat
    
    ld a,ENABLED
    call set_display

    call FadeInScreen
    call PSGRestoreVolumes
    ld a,RUN_TITLE
    ld (game_state),a

  jp main_loop
  
  run_title:
    call wait_for_vblank
    
    -:
      in a,($7e)
      cp $d7
    jp nz,-
    
    ; Begin vblank critical code (DRAW) ---------------------------------------
    ld a,(frame_counter)
    ld bc,_sizeof_blink_frames
    ld hl,blink_frames
    cpir
    jp nz,+    
      ld a,4
      out (CONTROL_PORT),a
      ld a,CRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      ld a,$1b
      out (DATA_PORT),a
      jp ++
    +:
      ld a,4
      out (CONTROL_PORT),a
      ld a,CRAM_WRITE_COMMAND
      out (CONTROL_PORT),a
      ld a,$17
      out (DATA_PORT),a
    ++:


    call load_sat

    ; End of critical vblank routines. ----------------------------------------

    ; Begin general updating (UPDATE).
    ld hl,frame_counter
    inc (hl)

    ld a,MUSIC_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGFrame
    ld a,SFX_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGSFXFrame
    
    call refresh_sat_handler
    call refresh_input_ports

    ; Count down to next frame.
    ld hl,anim_counter
    call tick_counter
    jp nc,+
      ld hl,frame
      inc (hl)
    +:
    ; Reset/loop animation if last frame expires. 
    ld a,(state)
    ld hl,state_to_frames_total_table
    call lookup_byte
    ld b,a
    ld a,(frame)
    cp b
    jp nz,+
      xor a
      ld (frame),a
    +:

    ; Put the sprite tiles in the SAT buffer. 
    ld a,(state)
    ld hl,state_to_frame_table
    call lookup_word
    ld a,(frame)
    call lookup_byte
    ld b,0
    push af
      ;.equ ONE_ROW_OFFSET 64
      ; Offset to left-facing tiles if necessary.
      ld a,(direction)
      ld b,0
      cp RIGHT
      jp z,+
        ld b,ONE_ROW_OFFSET
      +:
      ld a,(player_y)
      ld d,a
      ld a,(player_x)
      ld e,a
    pop af
    add a,b                           ; Apply offset (0 or ONE_ROW)
    
    call spr_2x2


    ; Seed the random number generator
    call get_random_number

    ld a,(temp_byte)
    cp TRUE
    jp nz,+
      ld hl,wait_counter
      call tick_counter
      jp nc,+
        ld a,FALSE
        ld (temp_byte),a
    +:

    ld a,(temp_byte)    ; Temp byte is used to lock/unlock controller.
    cp TRUE
    jp z,+
      call is_button_1_or_2_pressed
      jp nc,+
        call FadeOutScreen
        ld l,0
        call PSGSetMusicVolumeAttenuation  
        ld a,START_NEW_GAME
        ld (game_state),a
      +:


    jp +
      blink_frames:
        .db 65 66 100 200 239 240 241
        __:
    +:

  jp main_loop


  initialize_game_over:
    call PSGStop

    di
    ld hl,vdp_register_init
    call initialize_vdp_registers    
    call clear_vram

    ld a,1
    ld b,BORDER_COLOR
    call set_register

    ld a,MISC_ASSETS_BANK
    ld hl,game_over_tiles
    ld de,SPRITE_BANK_START
    ld bc,_sizeof_game_over_tiles
    call load_vram

    ld a,MISC_ASSETS_BANK
    ld hl,game_over_tilemap
    ld de,NAME_TABLE_START
    ld bc,_sizeof_game_over_tilemap
    call load_vram

    RESET_COUNTER wait_counter, 240

    call refresh_sat_handler
    call refresh_input_ports

    ei
    halt
    halt

    call wait_for_vblank    
    call load_sat

    ld a,ENABLED
    call set_display

    call FadeInScreen

    ld a,RUN_GAME_OVER
    ld (game_state),a

  jp main_loop
  
  run_game_over:
    call wait_for_vblank    
    ; Begin vblank critical code (DRAW) ---------------------------------------
    call load_sat

    ; End of critical vblank routines. ----------------------------------------

    ; Begin general updating (UPDATE).
    ld a,MUSIC_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGFrame
    ld a,SFX_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGSFXFrame
    
    call refresh_sat_handler
    call refresh_input_ports

    ld hl,wait_counter
    call tick_counter
    jp nc,+
      call FadeOutScreen
      ld a,INITIALIZE_TITLE
      ld (game_state),a
    +:
  jp main_loop
z

  ; ---------------------------------------------------------------------------
  initialize_minimap:
    call PSGStop
    call PSGSFXStop
    call PSGSilenceChannels
    di
    ld hl,vdp_register_init_show_left_column
    call initialize_vdp_registers    
    call clear_vram

    ld a,1
    ld b,BORDER_COLOR
    call set_register

    ld a,MISC_ASSETS_BANK
    ld hl,minimap_tiles
    ld de,BACKGROUND_BANK_START
    ld bc,_sizeof_minimap_tiles
    call load_vram

    ld a,MISC_ASSETS_BANK_II
    ld hl,misc_sprite_tiles
    ld de,SPRITE_BANK_START
    ld bc,_sizeof_misc_sprite_tiles
    call load_vram

    ld a,MISC_ASSETS_BANK
    ld hl,minimap_tilemap
    ld de,NAME_TABLE_START
    ld bc,_sizeof_minimap_tilemap
    call load_vram

    call refresh_sat_handler    
    call refresh_input_ports

    ld hl,minimap_music
    call PSGPlayNoRepeat

    ; Use the temp. composite counter to delay transition to level.
    RESET_COMPOSITE_COUNTER temp_composite_counter, 1
    LOAD_BYTES temp_byte,$ff  ; Flag to blink the player horse.
    RESET_COUNTER temp_counter, 20

    ei
    halt
    halt
    call wait_for_vblank    
    call load_sat

    ld a,ENABLED
    call set_display


    call FadeInScreen
    call PSGRestoreVolumes
    ld a,RUN_MINIMAP
    ld (game_state),a

  jp main_loop
  
  run_minimap:
    call wait_for_vblank
    
    ; Begin vblank critical code (DRAW) ---------------------------------------
    call load_sat

    ; End of critical vblank routines. ----------------------------------------

    ; Begin general updating (UPDATE).
    ld a,MUSIC_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGFrame
    ld a,SFX_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGSFXFrame
    
    call refresh_sat_handler
    call refresh_input_ports

    ld hl,temp_counter
    call tick_counter
    jp nc,+
      ; Flip flag (blink horse).
      ld a,(temp_byte)
      cpl
      ld (temp_byte),a
    +:

    ld a,(temp_byte)
    cp $ff
    jp nz,+
      ; Flag says draw the horse...
      ld d,130
      ld e,20
      ld a,0
      call spr_3x3
    +:

    ; Seed the random number generator
    call get_random_number

    ld hl,temp_composite_counter
    call tick_composite_counter
    jp nc,+
      call FadeOutScreen
      ld a,INITIALIZE_LEVEL
      ld (game_state),a
    +:

    call is_button_1_or_2_pressed
    jp nc,+
      ld a,(temp_composite_counter+1) ; get the coarse value
      cp 0
      jp nz,+           ; Delay, so you cannot instaclick the minimap.
      call FadeOutScreen
      ld a,INITIALIZE_LEVEL
      ld (game_state),a
    +:
  jp main_loop


  initialize_splash:
    ld a,DISABLED
    call set_display

    di
    call clear_vram
    ld hl,vdp_register_init_show_left_column
    call initialize_vdp_registers    

    ld a,0
    ld b,16
    ld hl,pal_7
    call load_cram


    ld a,1
    ld b,BORDER_COLOR
    call set_register

    ld a,MISC_ASSETS_BANK_II
    ld hl,splash_tiles
    ld de,BACKGROUND_BANK_START
    ld bc,_sizeof_splash_tiles
    call load_vram

    ld a,MISC_ASSETS_BANK_II
    ld hl,splash_tilemap
    ld de,NAME_TABLE_START
    ld bc,_sizeof_splash_tilemap
    call load_vram


    ;RESET_COUNTER temp_counter, 30
    LOAD_BYTES temp_byte, 0

    ;RESET_COUNTER wait_counter, 140
    ;LOAD_BYTES ctrl_lock, TRUE

    call refresh_sat_handler

    ei
    halt
    call PSGInit
    ld hl,coin_music
    call PSGPlayNoRepeat
    halt
    ld a,ENABLED
    call set_display
    call wait_for_vblank    

    ld a,RUN_SPLASH
    ld (game_state),a

  jp main_loop
  
  run_splash:
    call wait_for_vblank
  
    ; Begin vblank critical code (DRAW) ---------------------------------------
   -:
      in a,($7e)
      cp $d7
    jp nz,-
    ld a,(temp_byte)
    ld hl,pal_table
    call lookup_word
    ld a,0
    ld b,16
    call load_cram

    call load_sat

    ; End of critical vblank routines. ----------------------------------------

    ; Begin general updating (UPDATE).

    ld a,MUSIC_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGFrame
    ld a,SFX_BANK
    SELECT_BANK_IN_REGISTER_A
    call PSGSFXFrame
    
    call refresh_sat_handler
    call refresh_input_ports


    ld a,(temp_byte)
    inc a
    cp 13
    jp nz,+
      ld a,INITIALIZE_TITLE
      ld (game_state),a
      ld a,0
      ld b,32
      ld hl,all_black_palette
      call load_cram
      halt
      jp main_loop

    +:
    ld (temp_byte),a
    .rept 6
      ; Wow, close to release uglyness....
      ld a,MUSIC_BANK
      SELECT_BANK_IN_REGISTER_A
      call PSGFrame
      halt
    .endr
  jp main_loop

  pal_table:
    .dw pal_7, pal_0, pal_1, pal_2, pal_3, pal_4, pal_5, pal_6
    .dw pal_7, pal_7, pal_7, pal_7, pal_7
  pal_0:
  .db $3f $10 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  pal_1:
  .db 0 0 $3f $10 0 0 0 0 0 0 0 0 0 0 0 0 
  pal_2:
  .db 0 0 0 0 $3f $10 0 0 0 0 0 0 0 0 0 0 
  pal_3:
  .db 0 0 0 0 0 0 $3f $10 0 0 0 0 0 0 0 0 
  pal_4:
  .db 0 0 0 0 0 0 0 0 $3f $10 0 0 0 0 0 0
  pal_5:
  .db 0 0 0 0 0 0 0 0 0 0 $3f $10 0 0 0 0
  pal_6:
  .db 0 0 0 0 0 0 0 0 0 0 0 0 $3f $10 0 0
  pal_7:
  .db 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
  pal_8:
  .db $3f $10 $3f $10 $3f $10 $3f $10 $3f $10 0 0 0 0 0 0
  pal_9:
  .db 0 0 0 0 0 0 0 0 $3f $10 $3f $10 $3f $10 0 0 

.ends

; -----------------------------------------------------------------------------
.bank 3 slot 2
.section "Sound effects" free
  slash_sfx:
    .incbin "data/slash.psg"

  jump_sfx:
    .incbin "data/jump.psg"

  hurt_sfx:
    .incbin "data/hurt.psg"

  boss_hurt_sfx:
    .incbin "data/boss_hurt.psg"

  boss_dies_sfx:
    .incbin "data/boss_dies.psg"

  player_hurt_sfx:
    .incbin "data/player_hurt.psg"

  item_sfx:
    .incbin "data/item.psg"

  village_on_fire:
    .incbin "data/village_on_fire.psg"

  minimap_music:
    .incbin "data/minimap.psg"

  end_of_demo_music:
    .incbin "data/eod.psg"

  title_music:
    .incbin "data/title.psg"

  boss_music:
    .incbin "data/boss.psg"

  coin_music:
    .incbin "data/coin.psg"

  score_tally_music:
    .incbin "data/score_tally.psg"
  
  tick:
    .incbin "data/tick.psg"

.ends

; -----------------------------------------------------------------------------
.bank 4 slot 2
.section "Level 0 assets" free
  sprite_tiles:
    .include "data/sprite_tiles.inc"
    __:
  level_0_tiles:
    .include "data/village_tiles.inc"
  level_0_map:
    .incbin "data/village_tilemap.bin"
    level_0_map_end:
.ends

; -----------------------------------------------------------------------------
.bank 5 slot 2
.section "Level 1 assets" free
  level_1_sprite_tiles:
    .include "data/boss_sprite_tiles.inc"
    __:
  level_1_tiles:
    .include "data/boss_tiles.inc"

  level_1_map:
    .incbin "data/boss_tilemap.bin"
    level_1_map_end:
.ends

.bank 6 slot 2
.section "Misc assets" free
  chapter_completed_tiles:
    .include "data/chapter_completed_tiles.inc"
    __:
  chapter_completed_tilemap:
    .include "data/chapter_completed_tilemap.inc"
    __:

  title_tiles:
    .include "data/title_tiles.inc"
    __:
  title_tilemap:
    .include "data/title_tilemap.inc"
    __:

  game_over_tiles:
    .include "data/game_over_tiles.inc"
    __:
  game_over_tilemap:
    .include "data/game_over_tilemap.inc"
    __:

  minimap_tiles:
    .include "data/minimap_tiles.inc"
    __:
  minimap_tilemap:
    .include "data/minimap_tilemap.inc"
    __:

.ends

.bank 7 slot 2
.section "Misc assets II" free
  misc_sprite_tiles:
    .include "data/misc_sprite_tiles.inc"
    __:

  end_of_demo_tiles:
    .include "data/end_of_demo_tiles.inc"
    __:
  end_of_demo_tilemap:
    .include "data/end_of_demo_tilemap.inc"
    __:

  splash_tiles:
    .include "data/splash_tiles.inc"
    __:
  splash_tilemap:
    .include "data/splash_tilemap.inc"
    __:



.ends

