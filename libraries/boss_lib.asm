; boss_lib.asm

.equ BOSS_DEACTIVATED 0
.equ BOSS_WALKING 1
.equ BOSS_IDLE 2
.equ BOSS_ATTACKING 3

; Sprite sheet indexes:
.equ BOSS_WALKING_LEFT_0 117
.equ BOSS_WALKING_LEFT_1 120
.equ BOSS_ATTACKING_LEFT 123
.equ BOSS_ATTACKING_RIGHT 27
.equ BOSS_WALKING_RIGHT_0 21
.equ BOSS_WALKING_RIGHT_1 24

; Boss stats
.equ BOSS_SHIELD_MAX 15
.equ BOSS_LIFE_MAX 16


.ramsection "Boss ram section" slot 3
  boss_state db
  boss_y db
  boss_x db
  boss_height db
  boss_width db
  boss_dir db
  boss_index db
  boss_anim_counter dw
  boss_life db
  boss_shield db

  boss_counter db
  boss_hitbox_y db
  boss_hitbox_x db
  boss_hitbox_height db
  boss_hitbox_width db

  boss_weapon_y db
  boss_weapon_x db
  boss_weapon_height db
  boss_weapon_width db
  
  boss_killbox_y db
  boss_killbox_x db
  boss_killbox_height db
  boss_killbox_width db


.ends

.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Boss" free
; -----------------------------------------------------------------------------
  initialize_boss:
    LOAD_BYTES boss_state, BOSS_DEACTIVATED
    LOAD_BYTES boss_y, FLOOR_LEVEL+16, boss_x, 239
    LOAD_BYTES boss_dir, LEFT
    LOAD_BYTES boss_height, 22, boss_width, 22
    LOAD_BYTES boss_index, BOSS_WALKING_LEFT_0
    RESET_COUNTER boss_anim_counter, 11
    LOAD_BYTES boss_counter, 100
    LOAD_BYTES boss_shield, 15
    LOAD_BYTES boss_life, BOSS_LIFE_MAX 
    LOAD_BYTES boss_weapon_height, 7, boss_weapon_width, 7
    LOAD_BYTES boss_killbox_height, 5, boss_killbox_width, 7

    call get_random_number
    and %00000111
    ld b,a
    ld a,(boss_counter)
    add a,b
    ld (boss_counter),a


    .ifdef SPAWN_BOSS_INSTANTLY
      LOAD_BYTES boss_state, BOSS_WALKING
    .endif

  ret
  ; ---------------------------------------------------------------------------
  
  draw_boss:
    ld a,(boss_state)
    cp BOSS_DEACTIVATED
    ret z

    ld a,(boss_y)
    ld d,a
    ld a,(boss_x)
    ld e,a
    ld a,(boss_index)
    call spr_3x3

    ; Place the tip of the weapon if boss is attacking...
    ld a,(boss_state)
    cp BOSS_ATTACKING
    ret nz
      ld a,(boss_dir)
      cp LEFT
      jp nz,++
        ld c,180
        ld a,(boss_y)
        sub 8
        ld d,a
        ld a,(boss_x)
        sub 8
        ld e,a
        call add_sprite
        ret          
      ++:
        ld c,148
        ld a,(boss_y)
        sub 8
        ld d,a
        ld a,(boss_x)
        add 24
        ld e,a
        call add_sprite
        ret          

  ret
  ; ---------------------------------------------------------------------------

  update_boss:
    ld a,(end_of_map)
    cp TRUE
    jp nz,+
      ; Maybe spawn the boss
      ld a,(current_level)
      cp 1
      jp nz,+
        ld a,(boss_state)
        cp BOSS_DEACTIVATED
        jp nz,+
          ld a,(boss_life)
          cp 1
          jp c,+
            ; At the end of level 1 - spawn the boss.
            ; Boss is deactivated and but fresh.
            ld a,BOSS_WALKING
            ld (boss_state),a
            ; Lock exit
            ld a,TRUE
            ld (exit_locked),a
            ld hl,boss_music
            call PSGPlay
    +:
    
    ; The rest is for an activated boss.
    ld a,(boss_state)
    cp BOSS_DEACTIVATED
    ret z
    
    ; Tick shield if not at max (boss has been hurt, recently)
    ld a,(boss_shield)
    cp BOSS_SHIELD_MAX
    jp z,+
      dec a
      cp 0
      jp nz,++
        ld a,BOSS_SHIELD_MAX
      ++:
      ld (boss_shield),a
    +:

    call @hurt_with_player_attack
    call @animate 
    call @handle_walking
    call @handle_idle
    call @handle_attacking
    call @reorient
    call @move
    call @sync_weapon
    call @sync_killbox
    call @hurt_player

  ret

    @hurt_with_player_attack:
      ; Axis-aligned bounding box.
      ld a,(state)        ; Only check for collision if player
      cp ATTACKING        ; is attacking og jump-attacking.
      jp z,+
      cp JUMP_ATTACKING   ; Consider only hurting boss with ground attacks...
      jp z,+
        ret
      +:
      ld a,(boss_shield)
      cp BOSS_SHIELD_MAX
      ret nz
      ;ld a,(boss_state)  ; Don't check if Brute is already hurting.
      ;cp BRUTE_HURTING
      ;ret z
      ;
      ; Ugly workaround because boss's origin point is centre, bottom.

      ld iy,killbox_y     ; Put the player's killbox in IY.
      
      ld hl,boss_y
      ld de,boss_hitbox_y
      ld bc,4
      ldir
      ld a,(boss_hitbox_y)
      sub 24
      ld (boss_hitbox_y),a
      ;ld a,(boss_hitbox_x)
      ;sub 12
      ;ld (boss_hitbox_x),a
      ld ix,boss_hitbox_y
      call detect_collision
      ret nc
        ; Collision! Hurt the brute.
        ld hl,boss_shield
        dec (hl)            ; Start the shield counter..
        ADD_TO SCORE_TENS, 5
        
        ld hl,boss_hurt_sfx
        ld c,SFX_CHANNELS2AND3                  
        call PSGSFXPlay      

        ld hl,boss_life
        dec (hl)
        ld a,(hl)
        cp 0
        jp nz,+
          ; Boss is dead!
          ld hl,boss_dies_sfx
          ld c,SFX_CHANNELS2AND3                  
          call PSGSFXPlay  
          ;ld hl,stage_clear_music
          ;call PSGPlayNoRepeat    
          call PSGStop
          ld a,BOSS_DEACTIVATED
          ld (boss_state),a
          ADD_TO SCORE_THOUSANDS, 5
          ; unock exit
          ld a,FALSE
          ld (exit_locked),a
          RESET_COUNTER force_end_level_counter, 250
          LOAD_BYTES is_boss_dead, TRUE
        +:
        ;      
        ;ld a,BOSS_HURTING
        ;ld (boss_state),a

    ret 


    @handle_walking:
      ld a,(boss_state)
      cp BOSS_WALKING
      ret nz

      ld a,(boss_counter)
      dec a
      jp nz,+
        LOAD_BYTES boss_state, BOSS_IDLE
        call get_random_number
        and %00001111               ; Setup a random period for idle.
        add a,40
        ld (boss_counter),a
        ld a,(boss_dir)
        cp LEFT
        jp nz,++
          ld a,BOSS_WALKING_LEFT_0
          jp +++          
        ++:
          ld a,BOSS_WALKING_RIGHT_0
        +++:
        ld (boss_index),a
        ret
      +:
      ; Counter is not up yet.
      ld (boss_counter),a
    ret

    @handle_idle:
      ld a,(boss_state)
      cp BOSS_IDLE
      ret nz

      ld a,(boss_counter)
      dec a
      jp nz,+
        ; Switch to attack or walking?
        call get_random_number
        cp 200
        jp c,++
          ; Switch to walking.
          LOAD_BYTES boss_state, BOSS_WALKING
          call get_random_number
          and %00000111               ; Setup a random period for walking.
          add a,100
          ld (boss_counter),a
          ret
        ++:
          ; Switch to attacking
          LOAD_BYTES boss_state, BOSS_ATTACKING
          LOAD_BYTES boss_counter, 10
          ld a,(boss_dir)
          cp LEFT
          jp nz,++
            ld a,BOSS_ATTACKING_LEFT
            jp +++          
          ++:
            ld a,BOSS_ATTACKING_RIGHT
          +++:
          ld (boss_index),a
          ret
      +:
      ; Counter is not up yet.
      ld (boss_counter),a
    ret

    @handle_attacking:
      ld a,(boss_state)
      cp BOSS_ATTACKING
      ret nz

      ld a,(boss_counter)
      dec a
      jp nz,+
        ; Counter up, back to walking
        LOAD_BYTES boss_state,BOSS_WALKING
        LOAD_BYTES boss_counter, 100
        ld a,(boss_index)
        sub 6
        ld (boss_index),a
        ret
      +:
      ld (boss_counter),a
    ret

    @reorient:
      ld a,(boss_state)
      cp BOSS_ATTACKING
      ret z

      ld a,(boss_x)
      ld b,a
      ld a,(player_x)
      sub b
      jp nc,+
        ; Boss is right of the player, face boss left.
        ld a,(boss_dir)
        cp LEFT
        ret z
        ld a,LEFT
        ld (boss_dir),a
        ld a,BOSS_WALKING_LEFT_0
        ld (boss_index),a
        ret
      +:
        ; Boss is left of the player, face boss right.
        ld a,(boss_dir)
        cp RIGHT
        ret z
        ld a,RIGHT
        ld (boss_dir),a
        ld a,BOSS_WALKING_RIGHT_0
        ld (boss_index),a
    ret


    @move:
      ld a,(boss_state)
      cp BOSS_WALKING
      ret nz

      ld a,(odd_frame)
      cp TRUE
      ret nz

      ; Do not crazy-flip the boss when he is on the player.
      ld a,(boss_x)
      ld hl,player_x
      cp (hl)
      ret z

      ld hl,boss_x
      ld a,(boss_dir)
      cp LEFT
      jp nz,+
        dec (hl)  ; Move left.
        jp ++
      +:          
        inc (hl)  ; Move right.
      ++:
    ret

    @animate:
      ld a,(boss_state)
      cp BOSS_WALKING
      ret nz
      
      ld hl,boss_anim_counter
      call tick_counter
      call c,@@update_index
    ret
      @@update_index:
        ld a,(boss_dir)
        cp RIGHT
        jp nz,++
          ; Facing right
          ld a,(boss_index)
          cp BOSS_WALKING_RIGHT_0
          jp nz,+
            ld a,BOSS_WALKING_RIGHT_1
            ld (boss_index),a
            ret
          +:
          ld a,BOSS_WALKING_RIGHT_0
          ld (boss_index),a
          ret
        ++:
        ; Facing left
        ld a,(boss_index)
        cp BOSS_WALKING_LEFT_0
        jp nz,+
          ld a,BOSS_WALKING_LEFT_1
          ld (boss_index),a
          ret
        +:
        ld a,BOSS_WALKING_LEFT_0
        ld (boss_index),a
      ret

    @sync_weapon:
      ; Sync it for the collision detection (hurt player).
      ld a,(boss_state)
      cp BOSS_ATTACKING
      jp z,+
        ; Else: Do away with the weapon
        ld a,192
        ld (boss_weapon_y),a
        ret
      +:
      ;
      ld a,(boss_y)
      sub 8
      ld (boss_weapon_y),a
      ld a,(boss_dir)
      cp LEFT
      jp nz,+
        ld a,(boss_x)
        sub 12
        ld (boss_weapon_x),a
        jp ++
      +: 
        ld a,(boss_x)
        add a,24
        ld (boss_weapon_x),a
      ++:
    ret

    @sync_killbox:
      ; Sync it for the collision detection (hurt player).
      ld a,(boss_y)
      sub 12
      ld (boss_killbox_y),a
      ld a,(boss_x)
      add a,6
      ld (boss_killbox_x),a
      ;ld a,(boss_killbox_y)
      ;ld d,a
      ;ld a,(boss_killbox_x)
      ;ld e,a
      ;ld c,239
      ;call add_sprite
    ret


    @hurt_player:
      ld a,(state)
      cp HURTING
      ret z
      ld a,(boss_state)
      cp ATTACKING
      ret z
        ;
        ld a,(invincibility_timer)
        cp 0
        ret nz
          ; First test: Boss weapon
          ld ix,boss_weapon_y
          ld iy,player_y
          call detect_collision   
          jp nc,_f
            ; Player collides with boss weapon.
            TRANSITION_PLAYER_STATE HURTING
            LOAD_BYTES invincibility_timer, INVINCIBILITY_TIMER_MAX
            ld a,2
            call dec_health
            ld a,(boss_dir)
            cp LEFT
            jp nz,+
            ; Left
              ld a,(player_x)
              sub 8
              ld (player_x),a
              jp ++
            +:
            ; Right
              ld a,(player_x)
              add a,8
              ld (player_x),a
            ++:
            ret ; !! We exit here.
          __:
          ; Second test: Boss body killbox
          ld a,(state)
          cp JUMPING
          ret z
          cp JUMP_ATTACKING
          ret z
          ;
          ld ix,boss_killbox_y
          ld iy,player_y
          call detect_collision   
          jp nc,_f
            ; Player collides with boss body killbox.
            TRANSITION_PLAYER_STATE HURTING
            LOAD_BYTES invincibility_timer, INVINCIBILITY_TIMER_MAX
            ld a,1
            call dec_health
          __:


    ret


.ends
