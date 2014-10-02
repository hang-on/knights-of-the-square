;-------------------------------------------------------------------;
;                          Swordman section                             ;
; ------------------------------------------------------------------;

.define SWORDMAN_SAT 7 ; not sure that this is a free number?
.define SWORDMAN_WEAPON_SAT 8

.define SWORDMAN_OFF $00
.define SWORDMAN_STANDING $40

; sword tile indexes
.define SWORD_LEFT $4a      ; duplicates! see below
.define SWORD_UP $49
.define SWORD_RIGHT $48


.define SWORDMAN_DEAD $44

.define SWORDMAN_HURTING 1
.define SWORDMAN_DYING 2
.define SWORDMAN_WAITING 3
.define SWORDMAN_WALKING 4
.define SWORDMAN_ATTACKING $47
.define SWORDMAN_SHIRT $19  ; check this number!

.define SWORDMAN_WEAPON_FRONT $48
.define SWORDMAN_WEAPON_TOP $49
.define SWORDMAN_WEAPON_BEHIND $4a

; colors
;.define YELLOW     $0f
.define GREEN     $1d



; Used by ThugFlag.
;.define SCROLL     0

.ramsection "Swordman ram" slot 3
swordman_state db
swordman_x db
swordman_y db
swordman_counter db

swordman_life db
swordman_flag db
swordman_speed db
swordman_delay db
swordman_char_code db
swordman_animation_cel db

.ends

; must change this
; * swordman_flag, bits: xxxx xxps
; s = scroll swordman left next vblank
; p = points ready to be added to player's score (for slaying!)
; -------------------------------------------------------------------

.section "Swordman initialize" free
; Initialize the swordman with default values.
; Call this every time the thug is brought into play.
InitializeSwordman:

; Put initial values into the swordman's variables.

             ld    ix, swordman_state
             ld    (ix + 0), SWORDMAN_STANDING
             ld    (ix + 1), 0   ; put him in the blanked column
             ld    (ix + 2), BASELINE
             ld    (ix + 4), 40 ;life
             ld    (ix + 8), SWORDMAN_STANDING  ; swordman_char_code

; Put a standing thug sprite on the screen.

             ld    c, (ix + 8)
             ld    d, (ix + 1)
             ld    e, (ix + 2)
             ld    b, SWORDMAN_SAT
             call  goSprite

             ; put sword just left of swordman
             ld    a, d
             sub   16
             ld    d, a
             ld    b, SWORDMAN_WEAPON_SAT
             ld    c, SWORD_LEFT
             call  goSprite

             ret
.ends



.section "Swordman loop" free

; Put a call to this function in the main game loop.

ManageSwordmanLoop:

; Clear the status flag.

             xor   a
             ld    (swordman_flag), a

; Maybe respawn the swordman.

             call  _SpawnSwordman

; Maybe walk the swordman?

             call  _WalkSwordman

; Detect proximity of player, prepare for attack, etc.

             call  _HandleAttack

; Check for collision between player's sword and swordman.

             call   _HitSwordman

; Handle affairs if swordman state is 'hurting'.

             call  _HurtSwordman

; Handle a possible dying swordman.

             call  _KillSwordman

             call  _UpdateSwordmanPosition

; Scroll swordman if the stage scrolls.

             call  _ScrollSwordman

             call  _SwitchSwordmanOff

             ret

_SwitchSwordmanOff:

             ld    a, (swordman_x)
             cp    0
             ret   nz


; Swordman has scrolled off screen, so destroy him.

             xor   a
             ld    (swordman_x), a
             ld    (swordman_y), a
             ld    (swordman_char_code), a

             ld    c, 0
             ld    d, 0
             ld    e, 0
             ld    b, SWORDMAN_SAT
             call  goSprite

             ; also clear his sword
             ld    c, 0
             ld    d, 0
             ld    e, 0
             ld    b, SWORDMAN_WEAPON_SAT
             call  goSprite


             ld    hl, swordman_state
             ld    (hl), SWORDMAN_OFF
             ret



_WalkSwordman:
             ld    a, (swordman_state)
             cp    SWORDMAN_WALKING
             jp    z, +

             ld    a, (swordman_state)
             cp    SWORDMAN_STANDING
             jp    z, +

             ret

+:
             ld    a, (plrX)
             ld    b, a
             ld    a, (swordman_x)
             sub   b
             sub   25     ; distance to player - long (sword)
             jp    nc, +

             ld    hl, swordman_state
             ld    (hl), SWORDMAN_STANDING
             ret

+:           ld    hl, swordman_state
             ld    (hl), SWORDMAN_WALKING

             ld    hl, swordman_animation_cel
             ld    de, swordman_walking_right
             call  advcAnim

             ld    a, (swordman_animation_cel)
             ld    hl, swordman_walking_right
             call  arrayItm

             ld    (swordman_char_code), a

             ld    hl, swordman_speed
             inc   (hl)                ; move right?


             ret


_UpdateSwordmanPosition:

; Move swordman horizontally

             ld    a, (swordman_speed)     ; get horizontal speed
             ld    b, a            ; store it in B
             ld    a, (swordman_x)       ; get current x pos
             add   a, b            ; add speed to current x pos
             ld    (swordman_x), a       ; and put it into current  x
             xor   a               ; clear A
             ld    (swordman_speed), a     ; set speed to zero

             ld    a, (swordman_char_code)
             ld    c, a
             ld    a, (swordman_x)
             ld    d, a            ; D
             ld    a, (swordman_y)
             ld    e, a            ; E
             ld    b, SWORDMAN_SAT       ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ; put sword just left of swordman
             ld    a, d
             sub   16
             ld    d, a
             ld    b, SWORDMAN_WEAPON_SAT
             ld    c, SWORD_LEFT
             call  goSprite

             ret                   ; back to player loop recipe


_SpawnSwordman:
             ld    a, (swordman_state)
             cp    SWORDMAN_OFF
             ret    nz

             ; Swordman is off - should we respawn him?
             call  goRandom
             and   %01111111       ; more zeroes = more respawning
             ret   nz

             ; OK - his number came out, let's put him back on.
             call  InitializeSwordman
             ret


_ScrollSwordman:
             ld    a, (swordman_state)
             cp    SWORDMAN_OFF
             ret    z

; Check the stage's scroll flag to see if scrolling will happen.

             ld    a, (scroll_flag)
             cp    1
             ret    nz

; Scroll swordman.

             ld    hl, swordman_speed
             dec  (hl)

             ret


_KillSwordman:

; Switch thug to new state = 'dead'.

             ld    hl, swordman_state
             ld    (hl), SWORDMAN_DEAD

; Signal to score module and return.

             ld    hl, swordman_flag
             set   1, (hl)
             ret


_HurtSwordman:

; Is swordman status = hurting? (Paralyzed from being hit).

             ld    a, (swordman_state)
             cp    SWORDMAN_HURTING
             ret    nz

; Has the hurt state expired?

             ld    hl, swordman_counter
             ld    a, (hl)
             cp    0
             jp    nz, +

; The hurt state has expired - give him back his green shirt.

             ld    b, SWORDMAN_SHIRT
             ld    c, GREEN
             call  dfColor   ; ! hey, this should be when ints are off!!

; Switch state back to standing and return.

             ld    hl, swordman_state
             ld    (hl), SWORDMAN_STANDING

; Check the swordman's life meter.

             ld    a, (swordman_life)
             rla
             ret    nc

; Life is below zero - switch state to 'dying'.

             ld    ix, swordman_state
             ld   (ix + 3), 0
             ld   (ix + 0), SWORDMAN_DYING
             ret

; The hurt state is just going on, so decrease counter.

+:           ld    hl, swordman_counter
             dec   (hl)
             ret


_HitSwordman:

; Swordman is vulnerable when he is standing or preparing to attack.

             ld    a, (swordman_state)
             cp    SWORDMAN_STANDING
             jp    z, +
             cp    SWORDMAN_WAITING
             jp    z, +

; If none of the above, skip to next section.

             ret

; Detect collision between the player's sword and the swordman's body.

+:           ld    a, (wponX)
             ld    h, a
             ld    a, (wponY)
             ld    d, a
             ld    a, (swordman_x)
             ld    l, a
             ld    a, (swordman_y)
             ld    e, a
             ld    b, 8
             ld    c, 16
             call  DetectCollision
             ret    nc

; Update swordman mode to "hurting" and set counter for duration.

             ld    ix, swordman_state
             ld    (ix + 0), SWORDMAN_HURTING
             ld    (ix + 3), 7

; Give him a yellow shirt of pain.

             ld    b, SWORDMAN_SHIRT
             ld    c, YELLOW
             call  dfColor       ; ! hey, in frame int!?!

; Deal damage to swordman

             call  goRandom        ; put a pseudo-random number in A
             and   %00000111       ; mask to give us interval 0 - 7
             inc   a               ; always 1 damage (dam. 1-8)
             ld    b, a            ; store masked random number
             ld    a, (wponDam)    ; get weapon damage modifier
             add   a, b            ; add random damage to modifier
             ld    b, a            ; store this total amount of dam.
             ld    a, (swordman_life)   ; get soldier's life variable
             sub   b               ; subtract total damage
             ld    (swordman_life), a   ; and put the result back in var.

             ret

; Handle the swordman's occasional attempt to attack the player.

_StartAttack:

             ld     a, SWORDMAN_ATTACKING
             ld    (swordman_state), a
             ld    (swordman_char_code), a
             ld    a, 10
             ld    (swordman_counter), a

             ld    c, SWORDMAN_ATTACKING
             ld    a, (swordman_x)
             ld    d, a
             ld    a, (swordman_y)
             ld    e, a
             ld    b, SWORDMAN_SAT
             call  goSprite

             ; also put in the sword...?


             ld    c, SWORDMAN_WEAPON_FRONT
             ld    a, (swordman_x)
             add   a, 12
             ld    d, a
             ld    a, (swordman_y)
             ld    e, a
             ld    b, SWORDMAN_WEAPON_SAT
             call  goSprite

             ret

_HandleAttack:

             call  _DetectProximity
             call  _PrepareAttack

             ld    a, (swordman_state)
             cp    SWORDMAN_ATTACKING
             ret   nz

             ld    hl, swordman_counter
             dec   (hl)
             ld    a, (hl)
             cp    0
             ret   nz

; End attack state.

             ld    a, SWORDMAN_STANDING
             ld    (swordman_state), a
             ld    (swordman_char_code), a

             ld    c, SWORDMAN_STANDING
             ld    a, (swordman_x)
             ld    d, a
             ld    a, (swordman_y)
             ld    e, a
             ld    b, SWORDMAN_SAT
             call  goSprite

             ld    c, 0
             ld    d, 0
             ld    e, 200     ; drop sword below the screen
             ld    b, SWORDMAN_WEAPON_SAT
             call  goSprite

             ret

_PrepareAttack:
             ld    a, (swordman_state)
             cp    SWORDMAN_WAITING
             ret   nz

             ld    hl, swordman_counter
             dec   (hl)
             ret   nz

             call  _StartAttack

             ret

_DetectProximity:

             ld    a, (swordman_state)
             cp    SWORDMAN_STANDING
             ret   nz

             ld    a, (plrX)
             ld    h, a
             ld    a, (plrY)
             ld    d, a
             ld    b, 16            ; size of player box
             ld    a, (swordman_x)
             add   a, 16
             ld    l, a
             ld    a, (swordman_y)
             ld    e, a
             ld    c, 12            ; size of thug box

             call  DetectCollision

             ret   nc

             ;ld    a, 20
             call   goRandom
             and    %00001110
             add    a, 10
             ld    (swordman_counter), a
             ld    a, SWORDMAN_WAITING
             ld    (swordman_state), a

             ret


.ends

.section "Swordman data" free
; cel array for animating collapsing thug

; walking right
swordman_walking_right:
.redefine C1 SWORDMAN_STANDING
.redefine C2 SWORDMAN_STANDING + 1
.db C1 C1 C1 C1 C1 C1 C2 C2 C2 C2 C2 C2 $ff

.ends

*/