   ld a,(brute_dir)
    cp LEFT
    jp nz,+  
      ; This is for brute facing left.
      ld a,(brute_index)
      ld c,a
      ld a,(brute_y)
      ld d,a
      ld a,(brute_x)
      ld e,a
      call add_sprite
      ld a,8
      add e
      ld e,a
      inc c
      call add_sprite
      ld a,32
      add c
      ld c,a
      ld a,8
      add d
      ld d,a
      call add_sprite
      dec c
      ld a,e
      sub 8
      ld e,a
      call add_sprite
      ld a,(brute_index)
      add 31
      ld c,a
      ld a,(brute_y)
      add a,8
      ld d,a
      ld a,(brute_x)
      sub 8
      ld e,a
      call add_sprite
      ret
    +:
      ; Facing right
      ld a,(brute_index)
      ld c,a
      ld a,(brute_y)
      ld d,a
      ld a,(brute_x)
      ld e,a
      call add_sprite
      ld a,8
      add e
      ld e,a
      inc c
      call add_sprite
      ld a,32
      add c
      ld c,a
      ld a,8
      add d
      ld d,a
      call add_sprite
      dec c
      ld a,e
      sub 8
      ld e,a
      call add_sprite
      ;
      ld a,(brute_index)
      add a,34
      ld c,a
      ld a,(brute_y)
      add a,8
      ld d,a
      ld a,(brute_x)
      add a,16
      ld e,a
      call add_sprite


    @attack:
      ld a,(brute_state)
      cp BRUTE_HURTING
      ret z
      cp BRUTE_ATTACKING ; already attacking?
      jp z,+++
        ld a,(brute_dir)
        cp LEFT
        jp nz,+
          ; Facing left
          ld a,(player_x)
          ld b,a
          ld a,(brute_x)
          sub b
          sub 28
          ret nc
            ; Within range
            ld a,BRUTE_ATTACKING
            ld (brute_state),a
            ld a,$99
            ld (brute_index),a
            RESET_BLOCK 30, brute_attack_counter, 2
            ret
        +:
          ; Facing right
          ld a,(brute_x)
          ld b,a
          ld a,(player_x)
          sub b
          sub 28
          ret nc
            ; Within range
            ld a,BRUTE_ATTACKING
            ld (brute_state),a
            ld a,$39
            ld (brute_index),a
            RESET_BLOCK 30, brute_attack_counter, 2
            ret

      +++:  ; Already attacking, just tick the counter
      ld hl,brute_attack_counter
      call tick_counter
      ret nc
        ; Counter is up, attack finished...
        ld a,BRUTE_MOVING
        ld (brute_state),a
    ret





    ; Clear the top two rows with that special tile.
    ld hl,NAME_TABLE_START
    call setup_vram_write
    ld b,32*2
    -:
      ld a,$fa ; Tilebank index of special tile.
      out (DATA_PORT),a
      ld a,%00000001
      out (DATA_PORT),a
    djnz -


     metatile_lut:
    .rept 90 INDEX COUNT
      .dw $2000+(COUNT*$40) ; Address of top-left tile
      .dw $2400+(COUNT*$40) ; Address of bottom-left tile
      .dw $2020+(COUNT*$40) ; Address of top-right tile
      .dw $2420+(COUNT*$40) ; Address of bottom-right tile
    .endr
    
  ;load_column_xx:
    .rept 20 INDEX COUNT
      ld hl,$3880+COUNT*64
      call setup_vram_write
      ld a,(column_buffer+COUNT)
      out (DATA_PORT),a   
      ld a,%00000001
      out (DATA_PORT),a
    .endr


    ; Write first half of meta tile to name table.
    ld hl,$3802
    call setup_vram_write
    ld a,0    
    out (DATA_PORT),a   
    ld a,%00000001
    out (DATA_PORT),a
    
    ld hl,$3842
    call setup_vram_write
    ld a,32    
    out (DATA_PORT),a   
    ld a,%00000001
    out (DATA_PORT),a


    ; Write first half of meta tile to name table.
    ld hl,$3882
    call setup_vram_write
    ld a,$40    
    out (DATA_PORT),a   
    ld a,%00000001
    out (DATA_PORT),a
    
    ld hl,$38C2
    call setup_vram_write
    ld a,$60   
    out (DATA_PORT),a   
    ld a,%00000001
    out (DATA_PORT),a


    ld hl,test_anim_counter
    call tick_counter
        ; Count down to next frame.
    jp nc,+
      ld hl,test_frame
      inc (hl)
    +:
    ; Reset/loop animation if last frame expires. 
    ld hl,test_frame
    ld a,_sizeof_attacking_frame_to_index_table
    call reset_hl_on_a
    
    ld a,(test_frame)
    ld hl,attacking_frame_to_index_table
    call lookup_byte
    ld de,$8080
    call spr_2x2
    ld a,(test_frame)
    cp 1
    jp c,+
      ld c,32
      ld d,$88
      ld e,$90
      call add_sprite
    +:
  test_anim_counter dw
  test_frame db

  
    ; test
    ld a,0
    ld (test_frame),a
    ld a,ANIM_COUNTER_RESET
    ld (test_anim_counter),a
    ld (test_anim_counter+1),a

