; Player module

; Header ------------------------------------------------------------
.define ARTSTAND   $1              ; Arthur standing / idle
.define ARTATTK    $3
.define ARTSWORD   $4

.define PLRSAT     0               ; SAT index of the player sprite
.define WPONSAT    1

; different states of the player:
.define IDLE       0
.define WALK       1
.define ATTACK     2

; different directions:
.define RIGHT      0
.define LEFT       1

.ramsection "Player variables" slot 3
plrX         db                    ; horiz. pos. on the screen (0-256)
plrY         db                    ; vert. pos. on the screen (0-192)
plrAnim      db                    ; index of animation script
plrCC        db                    ; character code of player sprite
plrState     db                    ; player's current state
oldState     db                    ; player's previous state
hSpeed       db
vSpeed       db
plrXOld      db
plrYOld      db
plrLife      db                    ; life meter of the player
plrDir       db                    ; player's direction
player_flag   db
attack_delay db

wponX        db                    ; weapon x,y (for coll. detect)
wponY        db
wponDam      db                    ; damage dealt by the player's weapon

.ends
; player_flag is formatted as follows:
; xxxx xxac
; x = undefined
; c = player touches and open chest (award points)
; a = attacklock, 1 = locked, 0 = unlocked

.define ATTACK_LOCK_FLAG 1

; --------------------------------------------------------------------

.section "Player initialize" free
; Put an idle/standing Arthur on the screen.
InitializePlayer:
             ld    a, IDLE         ; get state constant
             ld    (plrState), a   ; init player state to 'idle'
             ld    hl, plrX        ; address of player x position
             ld    (hl), 8         ; load initial x pos. on screen
             inc   hl              ; forward to player y position
             ld    (hl), BASELINE       ; load initial y pos. on screen

; Give him standard sword and life.

             ld    a, 1            ; lv. 1 sword damage modifier = 1
             ld    (wponDam), a    ; put it the variable
             ld    a, 10           ; lv. 1 life meter
             ld    (plrLife), a    ; put it in the variable

             ret
.ends


.section "Player loop" free
ManagePlayerLoop:

; Manage the player flags.

             ; turn of chest flag every loop
             ld    a, (player_flag)
             and   %11111110
             ld    (player_flag), a

             ; reset attack lock if button is released
             call   getPlr1
             bit    CTBTN1, a
             jp     nz, +
             ld     hl, player_flag
             res    ATTACK_LOCK_FLAG, (hl)
+:

; Store the now expired player state as 'old state'.

             ld    hl, plrState    ; get player state
             ld    a, (hl)         ; put it in A
             inc   hl              ; point to oldState = plrState + 1
             ld    (hl), a         ; save expired state as oldState

; Decrement attack_delay if necessary.

             ld    a, (attack_delay)
             cp    0
             jp    z, +
             dec   a
             ld   (attack_delay), a
+:

             call  _GetInput

             call  _HandleIdlePlayer

             call  _HandleWalkingPlayer

             call  _HandleAttackingPlayer

             call  _UpdatePlayerPosition

             ret


_UpdatePlayerPosition:

; Cancel horizontal movement if stage is scrolling.

             ld    a, (scroll_flag)
             cp    1
             jp    nz, +
             xor   a
             ld    (hSpeed), a     ; dont move forward.


; Move player horizontally according to hSpeed.

+:           ld    a, (hSpeed)     ; get horizontal speed
             ld    b, a            ; store it in B
             ld    a, (plrX)       ; get current x pos of player
             ld    (plrXOld), a    ; save it as old
             add   a, b            ; add speed to current x pos
             ld    (plrX), a       ; and put it into current player x
             xor   a               ; clear A
             ld    (hSpeed), a     ; set speed to zero

; Move player vertically according to vSpeed.

             ld    a, (vSpeed)     ; just like horiz. move...
             ld    b, a
             ld    a, (plrY)
             ld    (plrYOld), a
             add   a, b
             ld    (plrY), a
             xor   a
             ld   (vSpeed), a

             ret                   ; back to player loop recipe


_GetInput:

             ld    a, (plrState)
             cp    ATTACK
             ret   z               ; not input when attacking

; Read player 1's controller in order to determine current state.

             call  getPlr1         ; get player 1 input indirectly
             ld    hl, plrState
             cp    0               ; if no input: plrState = idle
             jp    nz, +
             ld    (hl), IDLE
             ret

+:           bit   CTBTN1, a       ; is button 1 pressed
             jp    z, +            ; if not, skip to next test
             ld    a, (player_flag)
             bit   1, a
             jp    nz, +           ; is attack option free?

             ld    a, (attack_delay)  ; too close to prev. attack?
             cp    0
             jp    nz, +

             ld    (hl), ATTACK    ; OK, player is allowed to attack
             ret

+:           call  getPlr1         ; get player 1 input indirectly
             and   %00001111       ; directional button mask
             jp    z, +            ; if pressed, then attempt to walk
             ld    (hl), WALK
             ret

+:           ld    (hl), IDLE      ; fall through to idle state
             ret


_HandleIdlePlayer:

             ld    a, (plrState)
             cp    IDLE
             ret   nz              ; gatekeeping: only plrMode = idle

; Put a standing Arthur on screen (left or right?).

             ld    a, (plrDir)
             cp    RIGHT
             jp    nz, +
             ld    c, ARTSTAND     ; C = charcode
             jp    ++
+:
             ld    c, ARTSTAND+4     ; C = charcode
++:
             ld    a, (plrX)
             ld    d, a            ; D
             ld    a, (plrY)
             ld    e, a            ; E
             ld    b, PLRSAT       ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)
             ret


_HandleWalkingPlayer:

             ld    a, (plrState)
             cp    WALK
             ret   nz              ; gatekeeping: only walking

; Respond to directional input (set vSpeed and hSpeed).

             call  getPlr1         ; get formatted input in A
             rra                   ; rotate 'up bit' into carry
             rra                   ; carry = down bit
             rra                   ; carry = left bit
             push  af              ; save input
             call  c, mvWest       ; should we atttempt to go west?
             pop   af              ; retrieve input
             rra                   ; carry = right bit
             call  c, mvEast       ; go east?

; NOTE: plrX and plrY has not changed yet - only the speed!

; Handle walking animation of player sprite.

             ld    a, (oldState)   ; get old state
             cp    WALK            ; did we walk last time?
             jp    z, +            ; if so, then forward the anim.
             ld    hl, plrAnim     ; else: point to player animation
             ld    (hl), 0         ; and reset it (start from cel 0)

+:           ld    hl, plrAnim     ; param: player's animation

             ; branch on direction
             ld    a, (plrDir)
             cp    RIGHT
             jp    nz, +
             ld    de, artRight    ; param: player's anim. script
             call  advcAnim        ; advance plr's walking anim.
             ld    hl, artRight    ; param: animation script
             jp    ++

+:           ld    de, artLeft    ; param: player's anim. script
             call  advcAnim        ; advance plr's walking anim.
             ld    hl, artLeft    ; param: animation script

++:          ld    a, (plrAnim)    ; param: freshly updated anim.
             call  arrayItm        ; get charcode from anim. script
             ld    c, a            ; put charcode in C (param)
             ld    a, (plrX)       ; get player's x position
             ld    d, a            ; put it in D (param)
             ld    a, (plrY)       ; get player's y position
             ld    e, a            ; put it in E (param)
             ld    b, PLRSAT       ; B = plr sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ret


_HandleAttackingPlayer:

             ld    a, (plrState)
             cp    ATTACK
             ret   nz              ; gatekeeping: only attacking

             ld    a, (oldState)   ; get old state
             cp    ATTACK          ; where we attacking last time?
             jp    z, ContinueAttack  ; if so, continue the script

; Begin new attack.

             xor   a               ; else, set A = 0
             ld    (plrAnim), a    ; and start new animation sequence

             ; start the attack delay counter (limit attacks)
             ld    a, 15
             ld    (attack_delay), a

             ; set the attack lock flag
             ld    hl, player_flag
             set   ATTACK_LOCK_FLAG, (hl)

             ld    hl,sfxSword     ; point hl to sword SFX
             ld    c,SFX_CHANNELS2AND3  ; use chan. 2 and 3
             call  PSGSFXPlay      ; play slashing sound

             ; branch on direction
             ld    a, (plrDir)
             cp    RIGHT
             jp    nz, +
             ld    c, ARTSWORD     ; C = charcode (param)
             ld    a, (plrX)       ; get player x position
             add   a, 12
             ld    d, a            ; put it in D
             jp    ++

+:           ld    c, ARTSWORD     ; C = charcode (param)
             ld    a, (plrX)       ; get player x position
             sub   12
             ld    d, a            ; put it in D

++:          ld    (wponX), a      ; put it in weapon x pos
             ld    a, (plrY)       ; get player y position (param)
             ld    e, a            ; put it in E
             ld    (wponY), a
             ld    b, WPONSAT      ; B = sprite index in SAT
             call  goSprite        ; update SAT RAM buffer
             ret


ContinueAttack:

             ld    a, (plrDir)
             cp    RIGHT
             jp    z, +
             add   a, 3

+:           add   a, 3
             ld    c, a           ; C = charcode (param)
             ld    a, (plrX)       ; get player x position
             ld    d, a            ; put it in D
             ld    a, (plrY)       ; get player y position (param)
             ld    e, a            ; put it in E
             ld    b, PLRSAT       ; B = sprite index in SAT
             call  goSprite        ; update SAT RAM buffer

             ld    hl, plrAnim
             inc   (hl)
             ld    a, (hl)
             cp    8               ; take sword back up
             ret    nz

; Reset sword sprite.

             ld    hl, plrState
             ld    (hl), IDLE

             xor   a
             ld    (wponX), a
             ld    (wponY), a
             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 200            ; reset y pos
             ld    b, WPONSAT      ; B = the weapon's index in SAT
             call  goSprite        ; update SAT RAM buffer
             ret


.ends

.section "Player movement handling" free

; Stop player.

stopPlr:     ld    a, (plrXOld)    ; get x-pos from before hSpeed
             ld   (plrX), a        ; revert x-pos to prev. value

             ld    a, (plrYOld)    ; get y-pos from before vSpeed
             ld    (plrY), a       ; revert y-pos to prev. value

             xor   a               ; clear A
             ld    (scroll_flag), a   ; reset scroll flag = don't scroll
             ret

; Move the player one pixel south (down).

mvSouth:     ld    hl, plrY
             ld    a, (hl)
             cp    151
             ret   z
             ld    a, 1
             ld    (vSpeed), a
             ret

; Move the player one pixel north (up).

mvNorth:     ld    hl, plrY
             ld    a, (hl)
             cp    111
             ret   z
             ld    a, -1
             ld    (vSpeed), a
             ret

; Player wants to move east - check if he is at the scroll trigger.

mvEast:      ld   a, RIGHT         ;
             ld   (plrDir), a      ;

             ld    a, (plrX)         ; get player horiz. position
             cp    248             ; is player on the right bound?
             ret   z               ; ... no straying offscreen!
             ld    a, 1
             ld    (hSpeed), a
             ret

; Move the player one pixel west (left).

mvWest:      ld   a, LEFT          ;
             ld   (plrDir), a      ;

             ld    hl, plrX
             ld    a, (hl)
             cp    8
             ret   z

             ld    a, -1
             ld    (hSpeed), a
             ret
.ends



.section "Player data" free
; cel array for shifting between legs apart (char $10) and wide ($11)
artRight:
.redefine C1 ARTSTAND+1
.redefine C2 ARTSTAND
.db C1 C1 C1 C1 C2 C2 C2 C2 $ff

; walking left
artLeft:
.redefine C1 ARTSTAND+5
.redefine C2 ARTSTAND+4
.db C1 C1 C1 C1 C2 C2 C2 C2 $ff


; cel array for animating the attacking Arthur
atkRight:
.redefine C1 ARTSTAND
.redefine C2 ARTSTAND+2
.db C1 C2 C2 C2 C2 C2 C2 C2 C1 C1 C1 $ff

atkLeft:
.redefine C1 ARTSTAND+4
.redefine C2 ARTSTAND+6
.db C1 C2 C2 C2 C2 C2 C2 C2 C1 C1 C1 $ff

.ends
