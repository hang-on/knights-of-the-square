; Minions

.equ MINION_DEACTIVATED $ff
.equ MINION_ACTIVATED 0
.equ MINION_HURTING 1
.equ MINION_MAX 3

.struct minion
  y db
  x db
  height db
  width db

  state db
  direction db
  index db
  timer db
  frame db
  hspeed db
  vspeed db
  hurt_counter db
.endst

.ramsection "Minions ram section" slot 3
  random_number db
  minions INSTANCEOF minion 3
  spawner dw
  spawn_minions db

.ends

.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Minions" free
; -----------------------------------------------------------------------------
  ; INIT:
  initialize_minions: 
    .ifdef DISABLE_MINIONS
      ret
    .endif

    
    RESET_BLOCK 40, spawner, 2
    LOAD_BYTES spawn_minions, TRUE

    ld ix,minions
    ld b,MINION_MAX
    -:
      push bc
        call @initialize
        ld de,_sizeof_minion    
        add ix,de               ; Point ix to next minion.
      pop bc
    djnz -

  ret
    @initialize:
      ld hl,minion_init_data
      push ix
      pop de
      ld bc,_sizeof_minion_init_data
      ldir
    ret
      minion_init_data:
          .db 0, 0, 14, 14        ; Y, x, height, width.
          .db MINION_DEACTIVATED  ; State.
          .db 0 0 0 0 0 0 0       ; 
        __:
  ; --------------------------------------------------------------------------- 
  ; DRAW:
  draw_minions:
    .ifdef DISABLE_MINIONS
      ret
    .endif


    ; Put non-deactivated minions in the SAT buffer.
    ld ix,minions
    ld b,MINION_MAX
    -:                          ; For all non-deactivated minions, do...
      push bc                   ; Save loop counter.
        ld a,(ix+minion.state)
        cp MINION_DEACTIVATED
        jp z,+
          ld d,(ix+minion.y)
          ld e,(ix+minion.x)
          ld a,(ix+minion.index) 
          call spr_2x2          
        +:
        ld de,_sizeof_minion    
        add ix,de               ; Point ix to next minion.
      pop bc                    ; Restore loop counter.
    djnz -                      ; Process next minion.
  ret
  ; --------------------------------------------------------------------------- 
  ; UPDATE:
  process_minions:
    .ifdef DISABLE_MINIONS
      ret
    .endif

    ; Spawn a minion?
    ld hl,spawner
    call tick_counter
    jp nc,+++                   ; Skip forward if the counter is not up.
      ld a,(brute_state)
      cp BRUTE_DEACTIVATED
      jp z,+
        ld b,60
        jp ++
      +:
        ld b,75
      ++:
      call get_random_number  ; Counter is up - get a random number 0-255.
      cp b                   ; Roll under the spawn chance.
      jp nc,+++
        call spawn_minion     ; OK, spawn a minion.
    +++:

    ; Process each minion
    ld ix,minions
    ld b,MINION_MAX
    -:                          ; For all non-deactivated minions, do...
      push bc                   ; Save loop counter.
        ld a,(ix+minion.state)
        cp MINION_DEACTIVATED
        jp z,+
          call @clip_at_borders
          call @hurt_with_player_attack
          call @move            ; Apply h- and vspeed to x and y.
          call @animate
          call @hurt
          call @hurt_player

          ; ...
        +:
        ld de,_sizeof_minion    
        add ix,de               ; Point ix to next minion.
      pop bc                    ; Restore loop counter.
    djnz -                      ; Process next minion.
  ret
    @clip_at_borders:
      ld a,(ix+minion.direction)
      cp LEFT
      jp nz,+
        ; Facing left - check if over left limit.
        ld a,(ix+minion.x)
        cp LEFT_LIMIT
        call c,deactivate_minion
        ret
      +:
        ; Facing right - check if over right limit.
        ld a,(ix+minion.x)
        cp RIGHT_LIMIT+1
        call nc,deactivate_minion
    ret

    @hurt_with_player_attack:
      ; Axis aligned bounding box:
      ;    if (rect1.x < rect2.x + rect2.w &&
      ;    rect1.x + rect1.w > rect2.x &&
      ;    rect1.y < rect2.y + rect2.h &&
      ;    rect1.h + rect1.y > rect2.y)
      ;    ---> collision detected!
      ; ---------------------------------------------------
      ;
      ld a,(state)
      cp ATTACKING
      jp z,+
      cp JUMP_ATTACKING
      jp z,+
        ret
      +:
      ld a,(ix+minion.state)
      cp MINION_HURTING
      ret z

      ld iy,killbox_y         ; Put the player's killbox in IY.
      call detect_collision   ; IX holds the minion.
      ret nc

      ; Collision! Hurt the minion.
      ADD_TO SCORE_HUNDREDS, 1

      ld hl,hurt_sfx
      ld c,SFX_CHANNELS2AND3                  
      call PSGSFXPlay                         ; Play the SFX with PSGlib.
      ;      
      ld a,MINION_HURTING
      ld (ix+minion.state),a
      ld a,10
      ld (ix+minion.hurt_counter),a
      ld a,(ix+minion.direction)
      cp RIGHT
      jp nz,+
        ; Looking right
        ld a,$84
        ld (ix+minion.index),a
        ret
      +:
        ; Looking left
        ld a,$8A
        ld (ix+minion.index),a
    ret 

    @hurt:
      ld a,(ix+minion.state)
      cp MINION_HURTING
      ret nz
      ;
      ld a,(ix+minion.hurt_counter)
      dec a
      ld (ix+minion.hurt_counter),a
      call z,deactivate_minion
      ld a,(is_scrolling)
      cp TRUE
      jp nz,+
        dec (ix+minion.x)
      +:
    ret

    @hurt_player:
      ld a,(state)
      cp HURTING
      ret z
      ld a,(ix+minion.state)
      cp MINION_HURTING
      ret z

        ld a,(invincibility_timer)
        cp 0
        ret nz
          ld iy,player_y
          call detect_collision   ; IX holds the minion.
          ret nc
            ; Player collides with minion.
            TRANSITION_PLAYER_STATE HURTING
            LOAD_BYTES invincibility_timer, INVINCIBILITY_TIMER_MAX
            ld a,1
            call dec_health
    ret

    @move:
      ld a,(ix+minion.state)
      cp MINION_HURTING
      ret z
      ;
      ld a,(is_scrolling)
      cp TRUE
      jp nz,+
        ld a,(ix+minion.x)
        add a,(ix+minion.hspeed)
        sub 1
        ld (ix+minion.x),a
        jp ++
      +: 
        ld a,(ix+minion.x)
        add a,(ix+minion.hspeed)
        ld (ix+minion.x),a
      ++:
      ld a,(ix+minion.y)
      add a,(ix+minion.vspeed)
      ld (ix+minion.y),a
    ret

    @animate:
      ld a,(ix+minion.state)
      cp MINION_HURTING
      ret z
      ;
      ld a,(ix+minion.timer)
      dec a
      jp nz,+
        call @@update_index
        ld a,5                    ; Load timer reset value.
      +:
      ld (ix+minion.timer),a      ; Reset the timer.
    ret
      @@update_index:
        ld a,(ix+minion.direction)
        cp RIGHT
        jp nz,++
          ; Facing right
          ld a,(ix+minion.index)
          cp $80
          jp nz,+
            ld a,$82
            ld (ix+minion.index),a
            ret
          +:
          ld a,$80
          ld (ix+minion.index),a
          ret
        ++:
        ; Facing left
        ld a,(ix+minion.index)
        cp $86
        jp nz,+
          ld a,$88
          ld (ix+minion.index),a
          ret
        +:
        ld a,$86
        ld (ix+minion.index),a
      ret

  deactivate_minion:  
      ld a,MINION_DEACTIVATED
      ld (ix+minion.state),a
      ld a,192
      ld (ix+minion.y),a

  ret

  spawn_minion:
    ld a,(spawn_minions)
    cp TRUE
    ret nz
    ; Spawn a minion.
    ld ix,minions
    ld b,MINION_MAX
    -:
      ld a,(ix+minion.state)
      cp MINION_DEACTIVATED
      jp z,@activate
      ld de,_sizeof_minion
      add ix,de
    djnz -
    scf   ; Set carry = failure (no deactivated minion to spawn).
  ret
    @activate:  
      ld a,MINION_ACTIVATED
      ld (ix+minion.state),a
      call get_random_number
      bit 0,a
      jp z,+
        ; Spawn a minion at the left side, facing right.
        ld a,RIGHT
        ld (ix+minion.direction),a
        ld a,FLOOR_LEVEL
        ld (ix+minion.y),a
        ld a,0
        ld (ix+minion.x),a
        ld a,2
        ld (ix+minion.hspeed),a
        ld a,$80
        ld (ix+minion.index),a
        jp ++
      +:
        ; Spawn a minion on the right side, facing left.
        ld a,LEFT
        ld (ix+minion.direction),a
        ld a,FLOOR_LEVEL
        ld (ix+minion.y),a
        ld a,250
        ld (ix+minion.x),a
        ld a,-2
        ld (ix+minion.hspeed),a
        ld a,$86
        ld (ix+minion.index),a
      ++:
      ld a,5
      ld (ix+minion.timer),a
      or a    ; Reset carry = succes.
    ret
  ret

.ends

