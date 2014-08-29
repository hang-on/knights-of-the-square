.section "Soldier routines" free

; Respond to, and update, the soldier's current mode.

updSol:      ld    a, (solMode)    ; get soldier mode
             cp    SOLHURT         ; is he currently hurting?
             jp    z, hdlHurt      ; handle hurting process

             cp    SOLDYING        ; is he dying?
             ret    nz             ; if not, return

             cp    SOLSTAND        ; is he standing?
             jp    z, hitSol       ; collision detection

; Soldier is dying - animate the sprite.

             ld       hl, solCount ; param: cel counter
             ld       de, solDying ; param: animation script
             call     advcAnim     ; forward to net cel in animation

             ld    hl, solDying    ; param: animation script
             ld    a, (solCount)   ; param: freshly updated anim.
             call  arrayItm        ; get charcode from anim. script
             ld    c, a            ; put charcode in C (param)
             ld    a, (solX)       ; get player's x position
             ld    d, a            ; put it in D (param)
             ld    a, (solY)       ; get player's y position
             ld    e, a            ; put it in E (param)
             ld    b, SOLSAT       ; B = plr sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ld    a, (solCount)   ; get soldier's counter
             cp    11              ; he is lying flat by now?
             ret   nz              ; if not, handle next object
             ld    hl, solMode     ; if so, point to soldier's mode
             ld    (hl), SOLDEAD   ; and update it to "dead"

; Soldier is dead, add to player's score.

             ld    hl, score + 3   ; point to the hundreds column
             ld    b,  2           ; one soldier is worth 200 points!
             call  goScore         ; call the score updater routine
             ret                   ; handle next object

; Soldier is hurting (he is taking damage from player's weapon).

hdlHurt:     ld    hl, solCount    ; point to soldier's counter
             ld    a, (hl)         ; get value
             cp    10              ; is this a new hurt sequence?
             jp    nz, +           ; if not, skip forward...

; A) New hurt sequence started - give soldier a yellow shirt.

 ;            ld    b, C7B2         ; soldier's shirt is col. 7, bnk 2
             ld    b, SOLSHIRT         ; soldier's shirt is col. 7, bnk 2
             ld    c, YELLOW       ; set up for a yellow shirt
             call  dfColor         ; define color in CRAM
             jp    ++              ; skip forward to count down

+:           cp    0               ; is counter = 0? (end hurt)
             jp    nz, ++          ; if not, skip forward...

; B) The hurting sequence has ended - give him his orange shirt back.

             ld    b, SOLSHIRT         ; shirt is color 7 in CRAM bank 2
             ld    c, ORANGE       ; prepare for an orange shirt
             call  dfColor         ; define color in CRAM
             ld    hl, solMode     ; point to soldier's mode variable
             ld    (hl), SOLSTAND  ; switch back to standing
             ret                   ; jump to next objects

; C) Hurt sequence is just going on...

++:          ld    hl, solCount
             dec   (hl)            ; decrease counter

             ret

; Check if Arthur's sword collides with soldier.

hitSol:      ld    hl, wponX       ; hl = obj1 (x,y) - Arthur's sword
             dec (hl)              ; adjust for smaller sprite
             dec (hl)
             dec (hl)
             ld    de, solX        ; de = obj2 (x,y) - Soldier
             call  clDetect        ; coll. between obj1 and obj2?
             ret    nc             ; if no coll. > skip

; Update soldier mode to "hurting" and set counter for duration.

             ld    ix, solMode     ; point to soldier data block
             ld    (ix + 0), SOLHURT  ; set soldier mode = hurting
             ld    (ix + 3), 10    ; set soldier counter = 10

; Deal damage to soldier using formula: (0 - 3) + weapon modifier.

             call  goRandom        ; put a pseudo-random number in A
             and   %00000011       ; mask to give us interval 0 - 3
             ld    b, a            ; store masked random number
             ld    a, (wponDam)    ; get weapon damage modifier
             add   a, b            ; add random damage to modifier
             ld    b, a            ; store this total amount of dam.
             ld    a, (solLife)    ; get soldier's life variable
             sub   b               ; subtract total damage
             ld    (solLife), a    ; and put the result back in var.
             jp    nc, +           ; has soldier below 0 life now?
             ld   (ix + 3), 0      ; if so, reset counter
             ld   (ix + 0), SOLDYING  ; update mode to "dying"
+:           ret

; Check for collision between soldier and player.

collSol:     ld    a, (solMode)    ; get soldier mode
             cp    SOLSTAND           ; is he off/inactive?
             ret   nz              ; if no active soldier skip...

             ld    hl, plrX        ; point HL to player x,y data
             ld    de, solX        ; point DE to chest x,y
             call  clDetect        ; call the collision detection sub
             call  c, stopPlr     ; if carry, then collision!

             ret
.ends
