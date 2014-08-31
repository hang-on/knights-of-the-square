; Thug module.

; Header ------------------------------------------------------------

.define THUGSAT    5
.define THUGSTAN   $30
.define THUGHURT   $01
.define THUGDIE    $02

.define THUGOFF     $00             ; switched off
.define THUGDEAD    $34             ; dead
.define THUGSHIR   $19             ; palette index for shirt

.define SCROLL     0

.ramsection "Thug ram" slot 3
thugStat     db
thugX        db
thugY        db
thugCoun     db
thugLife     db
thugFlag     db
.ends

; -------------------------------------------------------------------

.section "Thug initialize" free
; initialize thug with default values
thugInit:
             ld    ix, thugStat
             ld    (ix + 0), THUGSTAN
             ld    (ix + 1), 100
             ld    (ix + 2), 110
             ld    (ix + 4), 8

             ld    c, THUGSTAN     ; charcode for goSprite
             ld    d, (ix + 1)     ; x-pos for goSprite
             ld    e, (ix + 2)     ; y-pos for goSprite
             ld    b, THUGSAT      ; SAT index for goSprite
             call  goSprite        ; update SAT buffer (RAM)

             ret
.ends

.section "Thug loop" free
; handle the thug object each pass in the game loop
thugLoop:
; -------------------------------------------------------------------
;                 COLLISION DETECTION: SWORD AND THUG               ;
; -------------------------------------------------------------------
             ld    a, (thugStat)
             cp    THUGSTAN
             jp   nz, thugLp1

             ld    hl, wponX       ; hl = obj1 (x,y) - Arthur's sword
             dec (hl)              ; adjust for smaller sprite
             dec (hl)
             dec (hl)
             ld    de, thugX       ;
             call  clDetect        ; coll. between obj1 and obj2?
             jp    nc, thugLp1         ; if no coll. > skip

; Update thug mode to "hurting" and set counter for duration.

             ld    ix, thugStat     ; point to data block
             ld    (ix + 0), THUGHURT  ; set mode = hurting
             ld    (ix + 3), 7    ; set counter

; Give him a yellow shirt

             ld    b, THUGSHIR     ; soldier's shirt is col. 7, bnk 2
             ld    c, YELLOW       ; set up for a yellow shirt
             call  dfColor         ; define color in CRAM

; Deal damage to thug using formula: (0 - 3) + weapon modifier.

             call  goRandom        ; put a pseudo-random number in A
             and   %00000011       ; mask to give us interval 0 - 3
             ld    b, a            ; store masked random number
             ld    a, (wponDam)    ; get weapon damage modifier
             add   a, b            ; add random damage to modifier
             ld    b, a            ; store this total amount of dam.
             ld    a, (thugLife)    ; get soldier's life variable
             sub   b               ; subtract total damage
             ld    (thugLife), a    ; and put the result back in var.

; -------------------------------------------------------------------
;                 STATUS = HURTING                                  ;
; -------------------------------------------------------------------

thugLp1:     ; is thug status = hurting (he is taking damage)
             ld    a, (thugStat)
             cp    THUGHURT
             jp    nz, thugLp2

             ld    hl, thugCoun    ; point to counter
             ld    a, (hl)         ; get value
             cp    0               ; is counter = 0? (end hurt)
             jp    nz, +           ; if not, skip forward...

; B) The hurting sequence has ended - give him his orange shirt back.

             ld    b, THUGSHIR         ; shirt is color 7 in CRAM bank 2
             ld    c, ORANGE       ; prepare for an orange shirt
             call  dfColor           ;  define color in CRAM

             ld    hl, thugStat     ; point to soldier's mode variable
             ld    (hl), THUGSTAN   ; switch back to standing
             jp    thugLp2               ; jump to next objects

; C) Hurt sequence is just going on...

+:           ld    hl, thugCoun
             dec   (hl)            ; decrease counter

; -------------------------------------------------------------------
;                 CHECK THUG HEALTH                                 ;
; -------------------------------------------------------------------
thugLp2:
             ld    a, (thugStat)
             cp    THUGSTAN
             jp    nz, thugLp3

             ld    a, (thugLife)   ;
             rla                   ; life below 0?
             jp    nc, thugLp3

             ld    ix, thugStat
             ld   (ix + 3), 0      ; if so, reset counter
             ld   (ix + 0), THUGDIE  ; update mode to "dying"

; -------------------------------------------------------------------
;                 THUG IS DYING                                     ;
; -------------------------------------------------------------------
thugLp3:
             ld    a, (thugStat)
             cp    THUGDIE
             jp    nz, thugLp4

             ld    hl, thugCoun
             ld    a, (hl)   ; get counter
             cp    12              ; he is lying flat by now?
             jp    nz, +
             ld    hl, thugStat     ;
             ld    (hl), THUGDEAD   ;
             jp    thugLp4
+:
             ld    hl, solDying    ; param: animation script
             ld    a, (thugCoun)   ; param: freshly updated anim.
             call  arrayItm        ; get charcode from anim. script
             ld    c, a            ; put charcode in C (param)
             ld    a, (thugX)       ; get player's x position
             ld    d, a            ; put it in D (param)
             ld    a, (thugY)       ; get player's y position
             ld    e, a            ; put it in E (param)
             ld    b, THUGSAT       ; B = plr sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ld    hl, thugCoun
             inc   (hl)

; Soldier is dead, add to player's score. (should go into player or score object)
; we can set a flag here?
;             ld    hl, score + 3   ; point to the hundreds column
;             ld    b,  2           ; one soldier is worth 200 points!
;             call  goScore         ; call the score updater routine


; -------------------------------------------------------------------
;                 THUG SCROLLER                                     ;
; -------------------------------------------------------------------
thugLp4:
             ld    a, (thugStat)
             cp    THUGOFF             ; don't scroll if he is off
             jp    z, thugLp5

             ld    a, (thugFlag)
             bit   SCROLL, a            ; is flag set for scrolling?
             jp    z, thugLp5

             ; reset flag
             res   SCROLL, a
             ld    (thugFlag), a

             ld   hl, thugX         ; point to soldier x pos
             dec  (hl)             ; decrement it
             ld   a, (hl)          ; put value in A for a comparison
             cp   0                ; is chest x = 0 (blanked clmn)?
             jp   nz, +     ; if not, forward...

; thug has scrolled off screen, so destroy him.

             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 0            ; reset y pos
             ld    b, THUGSAT     ; B = the chest's index in SAT
             call  goSprite        ; update SAT RAM buffer
             ld    hl, thugStat     ; point to chest mode
             ld    (hl), THUGOFF  ; set chect mode to OFF
             jp    thugLp5

; Update thug sprite position.
+:
             ld    a, (thugStat)
             ld    c, a            ; chest mode
             ld    d, (hl)         ; D
             inc   hl
             ld    e, (hl)         ; E
             ld    b, THUGSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

thugLp5:
             ret



.ends