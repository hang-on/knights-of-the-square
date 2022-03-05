; Items

.equ ITEM_DEACTIVATED $ff
.equ ITEM_ACTIVATED 0
.equ APPLE 140
.equ TOMATO 142
.equ JUG 144
.equ GOLD 146

.equ ITEM_MAX 3


.struct item
  state db
  y db
  x db
  index db
  timer db
.endst

.ramsection "Items ram section" slot 3
  items INSTANCEOF item 3
  item_spawner dw
  spawn_items db
  item_pool db
  item_pool_counter dw
.ends

.bank 0 slot 0
; -----------------------------------------------------------------------------
.section "Items" free
; -----------------------------------------------------------------------------
  ; INIT:
  initialize_items:
    ; In: hl = ptr. to init data.
    RESET_BLOCK 60, item_spawner, 2
    RESET_BLOCK 60, item_pool_counter, 2
    LOAD_BYTES item_pool, 1, item_pool_counter, 0
    ld hl,item_init_data
    ld de,items
    ld bc,_sizeof_item_init_data
    ldir
    LOAD_BYTES spawn_items, TRUE
  ret
    item_init_data:
      .rept ITEM_MAX
        .db ITEM_DEACTIVATED
        .rept _sizeof_item-1
          .db 0
        .endr
      .endr
      __:
  ; --------------------------------------------------------------------------- 
  ; DRAW:
  draw_items:
    ; Put non-deactivated items in the SAT buffer.
    ld ix,items
    ld b,ITEM_MAX
    -:                          ; For all non-deactivated items, do...
      push bc                   ; Save loop counter.
        ld a,(ix+item.state)
        cp ITEM_DEACTIVATED
        jp z,+
          ld d,(ix+item.y)
          ld e,(ix+item.x)
          ld a,(ix+item.index); FIXME: Depending on direction and state!
          call spr_2x2          ; + animation...
        +:
        ld de,_sizeof_item    
        add ix,de               ; Point ix to next item.
      pop bc                    ; Restore loop counter.
    djnz -                      ; Process next item.
  ret
  ; --------------------------------------------------------------------------- 
  ; UPDATE:
  process_items:
    ; Process the item aspect of the game.
    ld a,(end_of_map)           ; Load the end of map indicator.
    cp TRUE                     ; Are we at the map's end?
    jp nz,+                     ; If we are...
      ld (spawn_items),a        ; ... disable item spawning.
    +:
    ld a,(is_scrolling)         ; Is the world scrolling this frame?
    cp TRUE                     ; Yes?
    jp nz,+
      ld hl,item_pool_counter   ; Tick the item pool counter.
      call tick_counter
      jp nc,+                   ; Counter reaches 0...
        ld a,(item_pool)        ; How many item waiting to be spawned?
        cp 4                    ; If it is already max (4), skip...
        jp z,+
          inc a                 ; Else, increment the pool.
          ld (item_pool),a
    +:
    ld hl,item_spawner          ; Tick the item spawner.
    call tick_counter         
    jp nc,+                     ; Skip forward if the counter is not up.
      call get_random_number    ; Counter is up - get a random number 0-255.
      cp 55                     ; Roll under the spawn chance.
      jp nc,+
        ld a,(state)            ; Dont spawn items
        cp JUMPING              ; when the player is in the air.
        jp z,+
        cp JUMP_ATTACKING
        jp z,+
          call spawn_item     ;    OK, spawn an item.
    +:


    ; Process each item individually.
    ld ix,items
    ld b,ITEM_MAX
    -:                          ; For all non-deactivated items, do...
      push bc                   ; Save loop counter.
        ld a,(ix+item.state)
        cp ITEM_DEACTIVATED
        jp z,+
          call @clip_at_borders
          call @pick_up
          call @move
          ; ...
        +:
        ld de,_sizeof_item    
        add ix,de               ; Point ix to next item.
      pop bc                    ; Restore loop counter.
    djnz -                      ; Process next item.    
  ret

    @clip_at_borders:
      ld a,(ix+item.x)
      cp LEFT_LIMIT
      call c,deactivate_item
    ret
    @pick_up: 
      ; Axis aligned bounding box:
      ;    if (rect1.x < rect2.x + rect2.w &&
      ;    rect1.x + rect1.w > rect2.x &&
      ;    rect1.y < rect2.y + rect2.h &&
      ;    rect1.h + rect1.y > rect2.y)
      ;    ---> collision detected!
      ; ---------------------------------------------------
      ; IN: IX = Pointer to item struct. (rect 1)
      ;     IY = Pointer to arthur (y, x, height, width of rect2.)
      ; OUT:  Carry set = collision / not set = no collision.
      ;
      ; rect1.x < rect2.x + rect2.width
      ;
      ld iy,player_y

      ld a,(iy+1)
      add a,(iy+3)
      ld b,a
      ld a,(ix+item.x)
      cp b
      ret nc
        ; rect1.x + rect1.width > rect2.x
        ld a,(ix+item.x)
        add a,16
        ld b,a
        ld a,(iy+1)
        cp b
        ret nc
          ; rect1.y < rect2.y + rect2.height
          ld a,(iy+0)
          add a,(iy+2)
          ld b,a
          ld a,(ix+item.y)
          cp b
          ret nc
            ; rect1.y + rect1.height > rect2.y
            ld a,(ix+item.y)
            add a,16
            ld b,a
            ld a,(iy+0)
            cp b
            ret nc
      ; Collision! 
      ld hl,item_sfx
      ld c,SFX_CHANNELS2AND3                  
      call PSGSFXPlay                         ; Play the SFX with PSGlib.
      ;      
      ; Award different points for different items
      ld a,(ix+item.index)
      cp APPLE
      jp nz,+
        ADD_TO SCORE_HUNDREDS, 1
        ADD_TO SCORE_TENS, 5
        ld a,2
        call inc_health
        jp ++
      +:
      cp TOMATO
      jp nz,+
        ADD_TO SCORE_HUNDREDS, 2
        ADD_TO SCORE_TENS, 5
        ld a,3
        call inc_health
        jp ++
      +:
      cp JUG
      jp nz,+
        ADD_TO SCORE_THOUSANDS, 1
        jp ++
      +:
      cp GOLD
      jp nz,+
        ADD_TO SCORE_THOUSANDS, 2
        jp ++
      +:

      ++:

      ld a,ITEM_DEACTIVATED
      ld (ix+item.state),a
    ret 
    
    @move:
      ld a,(is_scrolling)
      cp TRUE
      ret nz
        ld a,(ix+item.x)
        sub 1
        ld (ix+item.x),a
    ret


  deactivate_item:  
      ld a,ITEM_DEACTIVATED
      ld (ix+item.state),a
  ret

  spawn_item:
    ld a,(spawn_items)
    cp TRUE
    ret nz
    ld a,(item_pool)
    cp 0
    ret z

    ; Spawn a item.
    ld hl,item_pool
    dec (hl)

    ld ix,items
    ld b,ITEM_MAX
    -:
      ld a,(ix+item.state)
      cp ITEM_DEACTIVATED
      jp z,@activate
      ld de,_sizeof_item
      add ix,de
    djnz -
    scf   ; Set carry = failure (no deactivated item to spawn).
  ret
    @activate:  
      ld a,ITEM_ACTIVATED
      ld (ix+item.state),a
      call get_random_number
      and %01111111
      add a,80
      ld (ix+item.x),a
      call get_random_number
      and %00011111
      add a,24
      ld b,a
      ld a,FLOOR_LEVEL
      sub b
      ld (ix+item.y),a
      call get_random_number
      and %00000011
      add a,a
      add a,$8c
      ld (ix+item.index),a
    ret



.ends

