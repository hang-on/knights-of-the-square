.bank 0 slot 0
.section "Start new game" free
  start_new_game:
    
    ; Seed the randomizer (should eventually move to title screen).
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
      
    ; Score:
    ld hl,score
    call reset_score

    LOAD_BYTES current_level, 0    
    
    ld a,INITIALIZE_LEVEL
    ld (game_state),a
    
    jp main_loop
.ends
