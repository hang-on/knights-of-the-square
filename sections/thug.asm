;-------------------------------------------------------------------;
;                          THUG MODULE                              ;
; ------------------------------------------------------------------;

.define THUGSAT 5
.define THUG_OFF $00
.define THUG_DEAD $34
.define THUG_STANDING $30
.define THUG_HURTING 1
.define THUG_DYING 2
.define THUG_WAITING 3
.define THUG_ATTACKING $36
.define THUG_SHIRT $19

.define THUG_WEAPON $35
.define THUG_WEAPON_SAT 6

; Used by ThugFlag.
.define SCROLL     0

.ramsection "Thug ram" slot 3
ThugState db
ThugX db
ThugY db
ThugCounter db
ThugLife db
ThugFlag db
ThugSpeed db
ThugDelay db
.ends

; * ThugFlag, bits: xxxx xxps
; s = scroll thug left next vblank
; p = points ready to be added to player's score (for slaying!)
; -------------------------------------------------------------------

.section "Thug initialize" free
; initialize thug with default values
; call this every time the thug is brought into play
thugInit:
             ld    ix, ThugState
             ld    (ix + 0), THUG_STANDING
             ld    (ix + 1), 80
             ld    (ix + 2), 120
             ld    (ix + 4), 8

             ld    c, THUG_STANDING     ; charcode for goSprite
             ld    d, (ix + 1)     ; x-pos for goSprite
             ld    e, (ix + 2)     ; y-pos for goSprite
             ld    b, THUGSAT      ; SAT index for goSprite
             call  goSprite        ; update SAT buffer (RAM)

             ret
.ends

.section "Thug loop" free
; handle the thug object each pass in the game loop
; put a call to this function in the main game loop
thugLoop:
            ; clear status flag
             xor   a
             ld    (ThugFlag), a

             call  _HandleAttack


; -------------------------------------------------------------------
;                 COLLISION DETECTION: SWORD AND THUG               ;
; -------------------------------------------------------------------
             
             ; Thug is vulnerable when he is standing or preparing
             ; for an attack.
             ld    a, (ThugState)
             cp    THUG_STANDING
             jp    z, +
             cp    THUG_WAITING
             jp    z, +

             ; If none of the above, skip to next section.
             jp   thugLp1

+:           ld    a, (wponX)
             ld    h, a

             ; Adjust x-pos if player is facing left because the
             ; sword is only 4 pixels wide.
             ld    a, (plrDir)
             cp    LEFT
             jp    nz, +
             ld    a, 4
             add   a, h
             ld    h, a

+:           ld    a, (wponY)
             ld    d, a
             ld    a, (ThugX)
             ld    l, a
             ld    a, (ThugY)
             ld    e, a
             ld    b, 4
             ld    c, 8
             call  DetectCollision
             jp    nc, thugLp1

; Update thug mode to "hurting" and set counter for duration.

             ld    ix, ThugState     ; point to data block
             ld    (ix + 0), THUG_HURTING  ; set mode = hurting
             ld    (ix + 3), 7    ; set counter

; Give him a yellow shirt

             ld    b, THUG_SHIRT     ; soldier's shirt is col. 7, bnk 2
             ld    c, YELLOW       ; set up for a yellow shirt
             call  dfColor         ; define color in CRAM

; Deal damage to thug using formula: (0 - 3) + weapon modifier.

             call  goRandom        ; put a pseudo-random number in A
             and   %00000011       ; mask to give us interval 0 - 3
             ld    b, a            ; store masked random number
             ld    a, (wponDam)    ; get weapon damage modifier
             add   a, b            ; add random damage to modifier
             ld    b, a            ; store this total amount of dam.
             ld    a, (ThugLife)    ; get soldier's life variable
             sub   b               ; subtract total damage
             ld    (ThugLife), a    ; and put the result back in var.

; -------------------------------------------------------------------
;                 STATUS = HURTING                                  ;
; -------------------------------------------------------------------

thugLp1:     ; is thug status = hurting (he is taking damage)
             ld    a, (ThugState)
             cp    THUG_HURTING
             jp    nz, thugLp2

             ld    hl, ThugCounter    ; point to counter
             ld    a, (hl)         ; get value
             cp    0               ; is counter = 0? (end hurt)
             jp    nz, +           ; if not, skip forward...

; B) The hurting sequence has ended - give him his orange shirt back.

             ld    b, THUG_SHIRT         ; shirt is color 7 in CRAM bank 2
             ld    c, ORANGE       ; prepare for an orange shirt
             call  dfColor           ;  define color in CRAM

             ld    hl, ThugState     ; point to soldier's mode variable
             ld    (hl), THUG_STANDING   ; switch back to standing
             jp    thugLp2               ; jump to next objects

; C) Hurt sequence is just going on...

+:           ld    hl, ThugCounter
             dec   (hl)            ; decrease counter

; -------------------------------------------------------------------
;                 CHECK THUG HEALTH                                 ;
; -------------------------------------------------------------------
thugLp2:
             ld    a, (ThugState)
             cp    THUG_STANDING
             jp    nz, thugLp3

             ld    a, (ThugLife)   ;
             rla                   ; life below 0?
             jp    nc, thugLp3

             ld    ix, ThugState
             ld   (ix + 3), 0      ; if so, reset counter
             ld   (ix + 0), THUG_DYING  ; update mode to "dying"

; -------------------------------------------------------------------
;                 THUG IS DYING                                     ;
; -------------------------------------------------------------------
thugLp3:
             ld    a, (ThugState)
             cp    THUG_DYING
             jp    nz, thugLp4

             ld    hl, ThugCounter
             ld    a, (hl)   ; get counter
             cp    12              ; he is lying flat by now?
             jp    nz, +
             ld    hl, ThugState     ;
             ld    (hl), THUG_DEAD   ;
             ld    hl, ThugFlag
             set   1, (hl)          ; signal to score module...
             jp    thugLp4
+:
             ld    hl, thugDie    ; param: animation script
             ld    a, (ThugCounter)   ; param: freshly updated anim.
             call  arrayItm        ; get charcode from anim. script
             ld    c, a            ; put charcode in C (param)
             ld    a, (ThugX)       ; get player's x position
             ld    d, a            ; put it in D (param)
             ld    a, (ThugY)       ; get player's y position
             ld    e, a            ; put it in E (param)
             ld    b, THUGSAT       ; B = plr sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ld    hl, ThugCounter
             inc   (hl)

; -------------------------------------------------------------------
;                 THUG SCROLLER                                     ;
; -------------------------------------------------------------------
thugLp4:
             ld    a, (ThugState)
             cp    THUG_OFF             ; don't scroll if he is off
             jp    z, thugLp5

             ld    a, (scrlFlag)
             cp    1                   ; is flag set for scrolling?
             jp    nz, thugLp5

             ld   hl, ThugX         ; point to  x pos
             dec  (hl)             ; decrement it
             ld   a, (hl)          ; put value in A for a comparison
             cp   0                ;
             jp   nz, +     ; if not, forward...

; thug has scrolled off screen, so destroy him.

             xor   a
             ld    (ThugX), a
             ld    (ThugY), a

             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 0            ; reset y pos
             ld    b, THUGSAT     ; B = the chest's index in SAT
             call  goSprite        ; update SAT RAM buffer
             ld    hl, ThugState     ; point to chest mode
             ld    (hl), THUG_OFF  ; set chect mode to OFF
             jp    thugLp5

; Update thug sprite position.
+:
             ld    a, (ThugState)
             ld    c, a            ; chest mode
             ld    d, (hl)         ; D
             inc   hl
             ld    e, (hl)         ; E
             ld    b, THUGSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

; -------------------------------------------------------------------
;                 SCROLL THUG?                                      ;
; -------------------------------------------------------------------
thugLp5:


; -------------------------------------------------------------------
;                 THUG MOVEMENT                                     ;
; -------------------------------------------------------------------
thugLp6:
/*
; Move thug horizontally according to hSpeed.

             ld    a, (ThugSpeed)    ; get horizontal speed
             ld    b, a            ; store it in B
             ld    a, (ThugX)       ; get current x pos of player
             add   a, b            ; add speed to current x pos
             ld    (ThugX), a       ; and put it into current player x
             xor   a               ; clear A
             ld    (ThugSpeed), a     ; set speed to zero
*/
             ret


; Handle the thug's occasional attempt to attack the player.

_StartAttack:

             ld     a, THUG_ATTACKING
             ld    (ThugState), a
             ld    a, 10
             ld    (ThugCounter), a

             ld    c, THUG_ATTACKING
             ld    a, (ThugX)
             ld    d, a
             ld    a, (ThugY)
             ld    e, a
             ld    b, THUGSAT
             call  goSprite

             ld    c, THUG_WEAPON
             ld    a, (ThugX)
             sub   8
             ld    d, a
             ld    a, (ThugY)
             ld    e, a
             ld    b, THUG_WEAPON_SAT
             call  goSprite

             ret

_HandleAttack:

             call  _DetectProximity
             call  _PrepareAttack

             ld    a, (ThugState)
             cp    THUG_ATTACKING
             ret   nz

             ld    hl, ThugCounter
             dec   (hl)
             ld    a, (hl)
             cp    0
             ret   nz

; End attack state.

             ld    a, THUG_STANDING
             ld    (ThugState), a

             ld    c, THUG_STANDING
             ld    a, (ThugX)
             ld    d, a
             ld    a, (ThugY)
             ld    e, a
             ld    b, THUGSAT
             call  goSprite

             ld    c, 0
             ld    d, 0
             ld    e, 0
             ld    b, THUG_WEAPON_SAT
             call  goSprite

             ret

_PrepareAttack:
             ld    a, (ThugState)
             cp    THUG_WAITING
             ret   nz

             ld    hl, ThugCounter
             dec   (hl)
             ret   nz

             call  _StartAttack

             ret

_DetectProximity:

             ld    a, (ThugState)
             cp    THUG_STANDING
             ret   nz

             ld    a, (plrX)
             ld    h, a
             ld    a, (plrY)
             ld    d, a
             ld    b, 8            ; size of player box
             ld    a, (ThugX)
             sub   4
             ld    l, a
             ld    a, (ThugY)
             ld    e, a
             ld    c, 8            ; size of thug box

             call  DetectCollision

             ret   nc

             ;ld    a, 20
             call   goRandom
             and    %00001110
             add    a, 10
             ld    (ThugCounter), a
             ld    a, THUG_WAITING
             ld    (ThugState), a

             ret


.ends

.section "Thug data" free
; cel array for animating collapsing thug
thugDie:
.redefine C1 THUG_STANDING+2
.redefine C2 THUG_STANDING+3
.redefine C3 THUG_STANDING+4
.db C1 C1 C1 C1 C1 C1 C2 C2 C2 C2 C2 C3 $ff
.ends