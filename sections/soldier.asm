.section "Update soldier" free
updSol:
; Respond to soldier's current mode

             ld    a, (solMode)    ; get soldier mode
             cp    SOLHURT         ; is he currently hurting?
             jp    z, hdlHurt      ; handle hurting process

             cp    SOLDYING        ; is he dying?
             ret    nz             ; if not, skip to next object

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
             cp    20              ; he is lying flat by now?
             ret   nz              ; if not, handle next object
             ld    hl, solMode     ; if so, point to soldier's mode
             ld    (hl), SOLDEAD   ; and update it to "dead"

; Soldier is dead; add to player's score.

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

             ld    b, C7B2         ; soldier's shirt is col. 7, bnk 2
             ld    c, YELLOW       ; set up for a yellow shirt
             call  dfColor         ; define color in CRAM
             jp    ++              ; skip forward to count down

+:           cp    0               ; is counter = 0? (end hurt)
             jp    nz, ++          ; if not, skip forward...

; B) The hurting sequence has ended - give him his orange shirt back.

             ld    b, C7B2         ; shirt is color 7 in CRAM bank 2
             ld    c, ORANGE       ; prepare for an orange shirt
             call  dfColor         ; define color in CRAM
             ld    hl, solMode     ; point to soldier's mode variable
             ld    (hl), SOLSTAND  ; switch back to standing
             ret                   ; jump to next objects

; C) Hurt sequence is just going on...

++:          ld    hl, solCount
             dec   (hl)            ; decrease counter

             ret
.ends