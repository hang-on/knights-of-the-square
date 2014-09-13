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
.define THUG_WALKING 4
.define THUG_ATTACKING $36
.define THUG_SHIRT $19

.define THUG_WEAPON $35
.define THUG_WEAPON_SAT 6

; colors
.define YELLOW     $0f
.define ORANGE     $07



; Used by ThugFlag.
.define SCROLL     0

.ramsection "Thug ram" slot 3
thug_state db
thug_x db
thug_y db
ThugCounter db
ThugLife db
ThugFlag db
thug_speed db
ThugDelay db
thug_char_code db
.ends

; * ThugFlag, bits: xxxx xxps
; s = scroll thug left next vblank
; p = points ready to be added to player's score (for slaying!)
; -------------------------------------------------------------------

.section "Thug initialize" free
; Initialize the thug with default values.
; Call this every time the thug is brought into play.
InitializeThug:

; Put initial values into the thug's variables.

             ld    ix, thug_state
             ld    (ix + 0), THUG_STANDING
             ld    (ix + 1), 255   ; put him in the blanked column
             ld    (ix + 2), BASELINE
             ld    (ix + 4), 8
             ld    (ix + 8), THUG_STANDING  ; thug_char_code

; Put a standing thug sprite on the screen.

             ld    c, (ix + 8)
             ld    d, (ix + 1)
             ld    e, (ix + 2)
             ld    b, THUGSAT
             call  goSprite

             ret
.ends

.section "Thug loop" free

; Put a call to this function in the main game loop.

ManageThugLoop:

; Clear the status flag.

             xor   a
             ld    (ThugFlag), a

; Maybe respawn the thug.

             call  _SpawnThug

; Maybe walk the thug?

             call  _WalkThug

; Detect proximity of player, prepare for attack, etc.

             call  _HandleAttack

; Check for collision between player's sword and thug.

             call   _HitThug

; Handle affairs if thug state is 'hurting'.

             call  _HurtThug

; Handle a possible dying thug.

             call  _KillThug

             call  _UpdateThugPosition

; Scroll thug if the stage scrolls.

             call  _ScrollThug

             call  _SwitchThugOff

             ret

_SwitchThugOff:

/*             ld    a, (thug_state)
             cp    THUG_DEAD
             ret   nz
*/
             ld    a, (thug_x)
             cp    0
             ret   nz


; Thug has scrolled off screen, so destroy him.

             xor   a
             ld    (thug_x), a
             ld    (thug_y), a
             ld    (thug_char_code), a

             ld    c, 0
             ld    d, 0
             ld    e, 0
             ld    b, THUGSAT
             call  goSprite

             ld    hl, thug_state
             ld    (hl), THUG_OFF
             ret



_WalkThug:
             ld    a, (thug_state)
             cp    THUG_WALKING
             jp    z, +

             ld    a, (thug_state)
             cp    THUG_STANDING
             jp    z, +

             ret

+:
             ld    a, (plrX)
             ld    b, a
             ld    a, (thug_x)
             sub   b
             sub   20     ; distance to player
             jp    nc, +

             ld    hl, thug_state
             ld    (hl), THUG_STANDING
             ret

+:           ld    hl, thug_state
             ld    (hl), THUG_WALKING
             ; TODO: Put in animation handling

             ld    a, -1
             ld    (thug_speed), a


             ret


_UpdateThugPosition:

; Move thug horizontally according to hSpeed.

             ld    a, (thug_speed)     ; get horizontal speed
             ld    b, a            ; store it in B
             ld    a, (thug_x)       ; get current x pos
             add   a, b            ; add speed to current x pos
             ld    (thug_x), a       ; and put it into current  x
             xor   a               ; clear A
             ld    (thug_speed), a     ; set speed to zero

             ld    a, (thug_char_code)
             ld    c, a
             ld    a, (thug_x)
             ld    d, a            ; D
             ld    a, (thug_y)
             ld    e, a            ; E
             ld    b, THUGSAT       ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ret                   ; back to player loop recipe


_SpawnThug:
             ld    a, (thug_state)
             cp    THUG_OFF
             ret    nz

             ; Thug is off - should we respawn him?
             call  goRandom
             and   %11111100       ; more zeroes = more respawning
             ret   nz

             ; OK - his number came out, let's put him back on.
             call  InitializeThug
             ret


_ScrollThug:
             ld    a, (thug_state)
             cp    THUG_OFF
             ret    z

; Check the stage's scroll flag to see if scrolling will happen.

             ld    a, (ScrollFlag)
             cp    1
             ret    nz

; Scroll thug.
; TODO: Better to apply -1 to thug's horizontal speed!

             ld    hl, thug_speed
             dec  (hl)

             ret


_KillThug:
             ld    a, (thug_state)
             cp    THUG_DYING
             ret    nz

; Check if 'dying' state has expired.

             ld    hl, ThugCounter
             ld    a, (hl)
             cp    12
             jp    nz, +

; Switch thug to new state = 'dead'.

             ld    hl, thug_state
             ld    (hl), THUG_DEAD

; Signal to score module and return.

             ld    hl, ThugFlag
             set   1, (hl)
             ret

; Dying state still active - play next cel in dying animation.

+:           ld    hl, thugDie
             ld    a, (ThugCounter)
             call  arrayItm
             ld    (thug_char_code), a  ; store new charcode
             ld    c, a
             ld    a, (thug_x)
             ld    d, a
             ld    a, (thug_y)
             ld    e, a
             ld    b, THUGSAT
             call  goSprite

; Increase counter and return = one step closer to death!

             ld    hl, ThugCounter
             inc   (hl)
             ret


_HurtThug:

; Is thug status = hurting? (Paralyzed from being hit).

             ld    a, (thug_state)
             cp    THUG_HURTING
             ret    nz

; Has the hurt state expired?

             ld    hl, ThugCounter
             ld    a, (hl)
             cp    0
             jp    nz, +

; The hurt state has expired - give him back his orange shirt.

             ld    b, THUG_SHIRT
             ld    c, ORANGE
             call  dfColor

; Switch state back to standing and return.

             ld    hl, thug_state
             ld    (hl), THUG_STANDING

; Check the thug's life meter.

             ld    a, (ThugLife)
             rla
             ret    nc

; Life is below zero - switch state to 'dying'.

             ld    ix, thug_state
             ld   (ix + 3), 0
             ld   (ix + 0), THUG_DYING
             ret

; The hurt state is just going on, so decrease counter.

+:           ld    hl, ThugCounter
             dec   (hl)
             ret


_HitThug:

; Thug is vulnerable when he is standing or preparing to attack.

             ld    a, (thug_state)
             cp    THUG_STANDING
             jp    z, +
             cp    THUG_WAITING
             jp    z, +

; If none of the above, skip to next section.

             ret

; Detect collision between the player's sword and the thug's body.

+:           ld    a, (wponX)
             ld    h, a
             ld    a, (wponY)
             ld    d, a
             ld    a, (thug_x)
             ld    l, a
             ld    a, (thug_y)
             ld    e, a
             ld    b, 8
             ld    c, 16
             call  DetectCollision
             ret    nc

; Update thug mode to "hurting" and set counter for duration.

             ld    ix, thug_state
             ld    (ix + 0), THUG_HURTING
             ld    (ix + 3), 7

; Give him a yellow shirt of pain.

             ld    b, THUG_SHIRT
             ld    c, YELLOW
             call  dfColor

; Deal damage to thug using formula: (0 - 3) + weapon modifier.

             call  goRandom        ; put a pseudo-random number in A
             and   %00000011       ; mask to give us interval 0 - 3
             ld    b, a            ; store masked random number
             ld    a, (wponDam)    ; get weapon damage modifier
             add   a, b            ; add random damage to modifier
             ld    b, a            ; store this total amount of dam.
             ld    a, (ThugLife)   ; get soldier's life variable
             sub   b               ; subtract total damage
             ld    (ThugLife), a   ; and put the result back in var.

             ret

; Handle the thug's occasional attempt to attack the player.

_StartAttack:

             ld     a, THUG_ATTACKING
             ld    (thug_state), a
             ld    (thug_char_code), a
             ld    a, 10
             ld    (ThugCounter), a

             ld    c, THUG_ATTACKING
             ld    a, (thug_x)
             ld    d, a
             ld    a, (thug_y)
             ld    e, a
             ld    b, THUGSAT
             call  goSprite

             ld    c, THUG_WEAPON
             ld    a, (thug_x)
             sub   12
             ld    d, a
             ld    a, (thug_y)
             ld    e, a
             ld    b, THUG_WEAPON_SAT
             call  goSprite

             ret

_HandleAttack:

             call  _DetectProximity
             call  _PrepareAttack

             ld    a, (thug_state)
             cp    THUG_ATTACKING
             ret   nz

             ld    hl, ThugCounter
             dec   (hl)
             ld    a, (hl)
             cp    0
             ret   nz

; End attack state.

             ld    a, THUG_STANDING
             ld    (thug_state), a
             ld    (thug_char_code), a

             ld    c, THUG_STANDING
             ld    a, (thug_x)
             ld    d, a
             ld    a, (thug_y)
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
             ld    a, (thug_state)
             cp    THUG_WAITING
             ret   nz

             ld    hl, ThugCounter
             dec   (hl)
             ret   nz

             call  _StartAttack

             ret

_DetectProximity:

             ld    a, (thug_state)
             cp    THUG_STANDING
             ret   nz

             ld    a, (plrX)
             ld    h, a
             ld    a, (plrY)
             ld    d, a
             ld    b, 16            ; size of player box
             ld    a, (thug_x)
             sub   10
             ld    l, a
             ld    a, (thug_y)
             ld    e, a
             ld    c, 4            ; size of thug box

             call  DetectCollision

             ret   nc

             ;ld    a, 20
             call   goRandom
             and    %00001110
             add    a, 10
             ld    (ThugCounter), a
             ld    a, THUG_WAITING
             ld    (thug_state), a

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