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
PlayerFlag   db

wponX        db                    ; weapon x,y (for coll. detect)
wponY        db
wponDam      db                    ; damage dealt by the player's weapon

.ends
; PlayerFlag is formatted as follows:
; xxxx xxxc
; x = undefined
; c = player touches and open chest (award points)


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

; Clear status flag.

             xor   a
             ld    (PlayerFlag), a


; Store the now expired player state as 'old state'.

             ld    hl, plrState    ; get player state
             ld    a, (hl)         ; put it in A
             inc   hl              ; point to oldState = plrState + 1
             ld    (hl), a         ; save expired state as oldState

; -------------------------------------------------------------------
;                           RESPOND TO INPUT                        ;
; -------------------------------------------------------------------
_step1:

             ld    a, (plrState)
             cp    ATTACK
             jp   z, _step2        ; not input when attacking


; Read player 1's controller in order to determine current state.

             call  getPlr1         ; get player 1 input indirectly
             ld    hl, plrState
             cp    0               ; if no input: plrState = idle
             jp    nz, +
             ld    (hl), IDLE
             jp    _step2
+:
             bit   CTBTN1, a            ; button 1
             jp    z, +
             ld    (hl), ATTACK
             jp    _step2
+:
             and   %00001111       ; directional button mask
             jp    z, +            ; if pressed, then attempt to walk
             ld    (hl), WALK
             jp    _step2
+:
             ld    (hl), IDLE      ; fall through to idle state

; -------------------------------------------------------------------
;                           HANDLE PLRSTATE = IDLE                  ;
; -------------------------------------------------------------------
_step2:
             ld    a, (plrState)
             cp    IDLE
             jp   nz, _step3        ; gatekeeping: only plrMode = idle


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

; -------------------------------------------------------------------
;                          HANDLE PLRSTATE = WALK                   ;
; -------------------------------------------------------------------
_step3:
             ld    a, (plrState)
             cp    WALK
             jp   nz, _step4        ; gatekeeping: only walking

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
+:
             ld    de, artLeft    ; param: player's anim. script
             call  advcAnim        ; advance plr's walking anim.
             ld    hl, artLeft    ; param: animation script
++:
             ld    a, (plrAnim)    ; param: freshly updated anim.
             call  arrayItm        ; get charcode from anim. script
             ld    c, a            ; put charcode in C (param)
             ld    a, (plrX)       ; get player's x position
             ld    d, a            ; put it in D (param)
             ld    a, (plrY)       ; get player's y position
             ld    e, a            ; put it in E (param)
             ld    b, PLRSAT       ; B = plr sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)


; -------------------------------------------------------------------
;                          HANDLE PLRSTATE = ATTACK                 ;
; -------------------------------------------------------------------
_step4:
             ld    a, (plrState)
             cp    ATTACK
             jp   nz, _step5        ; gatekeeping: only attacking

             ld    a, (oldState)   ; get old state
             cp    ATTACK          ; where we attacking last time?
             jp    z, attack1      ; if so, continue the script
             xor   a               ; else, set A = 0
             ld    (plrAnim), a    ; and start new animation sequence

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
+:
             ld    c, ARTSWORD     ; C = charcode (param)
             ld    a, (plrX)       ; get player x position
             sub   12
             ld    d, a            ; put it in D

++:
             ld    (wponX), a      ; put it in weapon x pos
             ld    a, (plrY)       ; get player y position (param)
             ld    e, a            ; put it in E
             ld    (wponY), a
             ld    b, WPONSAT      ; B = sprite index in SAT
             call  goSprite        ; update SAT RAM buffer
             jp    _step5


attack1:     ld    a, (plrDir)
             cp    RIGHT
             jp    z, +
             add   a, 3
+:
             add   a, 3
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
             jp    nz, _step5

; Reset sword sprite.

             ld    hl, plrState
             ld    (hl), IDLE

             xor   a
             ld    (wponX), a
             ld    (wponY), a
             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 0            ; reset y pos
             ld    b, WPONSAT      ; B = the weapon's index in SAT
             call  goSprite        ; update SAT RAM buffer


; -------------------------------------------------------------------
;                    (DON'T) SCROLL PLAYER                          ;
; -------------------------------------------------------------------
_step5:
             ld    a, (ScrollFlag)
             cp    1
             jp    nz, _step6
             xor   a
             ld    (hSpeed), a     ; dont move forward.

_step6:

_step8:

; -------------------------------------------------------------------
;                           MOVE PLAYER / UPDATE POSITION           ;
; -------------------------------------------------------------------
_step10:
; Move player horizontally according to hSpeed.

             ld    a, (hSpeed)     ; get horizontal speed
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

; -------------------------------------------------------------------
;                    Check for collision w. chest                   ;
; -------------------------------------------------------------------
_step11:
             ld    a, (ChestState)    ; get chest mode
             cp    CHEST_IS_OFF        ; is it off/inactive?
             jp    z, _step13      ; if no active chest skip coll.chk
             ld    a, (plrState)
             cp    WALK
             jp    nz, _step13

             ld    hl, plrX        ; point HL to player x,y data
             ld    de, ChestX        ; point DE to chest x,y

; NOTE: Implement new collision detection handler
;             call  clDetect        ; call the collision detection sub
             jp    nc, _step13              ; if no carry, then no collision

; Check if chest is closed or open.

             ld    a, (ChestState)    ; get chest mode
             cp    CHEST_IS_CLOSED         ; is it closed?
             jp    nz, +           ; if so, then player cannot pass!
             call  stopPlr
             jp    _step13
+:
; If chest is open, then pick it up.
             ld    hl, PlayerFlag
             set   0, (hl)

             xor   a
             ld    (ChestX), a
             ld    (ChestY), a

             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 0            ; reset y pos
             ld    b, CHESTSAT     ; B = the chest's index in SAT
             call  goSprite        ; update SAT RAM buffer
             ld    hl, ChestState     ; point to chest mode
             ld    (hl), $ff       ; turn it off now

             ld    hl,sfxBonus     ; point to bonus SFX
             ld    c,SFX_CHANNELS2AND3  ; in chan. 2 and 3
             call  PSGSFXPlay      ; play the super retro bonus sound



_step13:
             ret

.ends

.section "Player movement handling" free

; Stop player.

stopPlr:     ld    a, (plrXOld)    ; get x-pos from before hSpeed
             ld   (plrX), a        ; revert x-pos to prev. value

             ld    a, (plrYOld)    ; get y-pos from before vSpeed
             ld    (plrY), a       ; revert y-pos to prev. value

             xor   a               ; clear A
             ld    (ScrollFlag), a   ; reset scroll flag = don't scroll
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
