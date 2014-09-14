;-------------------------------------------------------------------;
;                          CHEST MODULE                             ;
; ------------------------------------------------------------------;

; Definitions for ChestState.

.define CHEST_IS_CLOSED $25
.define CHEST_IS_OPEN $26
.define CHEST_IS_OFF $ff

; The chest's SAT index:

.define CHESTSAT 2

.ramsection "Chest variables" slot 3
ChestState db
ChestX db
ChestY db
ChestFlag db
.ends

; ChestFlag has the following bits: xxxx xxxp
; x = undefined
; p = award points to player (for slashing chest open)

; -------------------------------------------------------------------

.section "Chest initialize" free

InitializeChest:

; Initialize chest variables.

             ld    ix, ChestState
             ld    (ix + 0), CHEST_IS_OFF
             ld    (ix + 1), 0
             ld    (ix + 2), 0
             ld    (ix + 3), 0

; Blank out chest sprite.

             ld    c, 0
             ld    d, (ix + 1)
             ld    e, (ix + 2)
             ld    b, CHESTSAT
             call  goSprite

             ret

.ends

.section "Chest loop manager" free

ManageChestLoop:

; Clear status flag.

             xor   a
             ld    (ChestFlag), a

; Check for collision between Arthur's sword and closed chest.

             ;call  _IsHitBySword

; Create, update or destroy chest depending on ScrollerFlag.

             call  _Scroller

; Return to main loop.

             ret

/*
_IsHitBySword:

; Skip collision check if chest is off or already open.

             ld    a, (ChestState)
             cp    CHEST_IS_OFF
             ret    z

             cp    CHEST_IS_CLOSED
             ret    nz

; Check if Arthur's sword collides with chest.

; TODO: Implement new collision detection here!


             ld    hl, wponX
             ld    a, (plrDir)
             cp    LEFT
             jp    nz, +
             inc   (hl)
             inc   (hl)
             inc   (hl)
             jp    ++
+:           dec (hl)
             dec (hl)
             dec (hl)
++:          ld    de, ChestX
             call  clDetect
             ret    nc

; Open chest (sprite).

             ld    ix, ChestState
             ld    c, CHEST_IS_OPEN
             ld    d, (ix + 1)
             ld    e, (ix + 2)
             ld    b, CHESTSAT
             call  goSprite

; Update ChestState to reflect this.

             ld    hl, ChestState
             ld    (hl), CHEST_IS_OPEN

; Set a bit in ChestFlag to signal to score module.

; TODO: Reactivate scoring + chest in score module

             ld    hl, ChestFlag
             set   0, (hl)

             ret

*/
_Scroller:

; Is ScrollerFlag set?

             ld    a, (scroll_flag)
             cp    1
             ret    nz

; Check if there is already an active chest on screen.

             ld    a, (ChestState)
             cp    CHEST_IS_OFF
             jp    nz, ++

; Determine if we should put a new chest on screen.

             call  goRandom
             sub   20
             ret   po

; Put a new chest outside the screen to the right, ready to scroll.

             ld    ix, ChestState
             ld    (ix + 0), CHEST_IS_CLOSED
             ld    (ix + 1), 255


             ld    (ix + 2), BASELINE

             ld    c, CHEST_IS_CLOSED
             ld    d, (ix + 1)
             ld    e, (ix + 2)
             ld    b, CHESTSAT
             call  goSprite

++:

; Scroll the chest.

             ld   hl, ChestX
             dec  (hl)
             ld   a, (hl)
             cp   0
             jp   nz, +

; Chest has scrolled off screen, so destroy it.

             xor   a
             ld    (ChestX), a
             ld    (ChestY), a

             ld    c, 0
             ld    d, 0
             ld    e, 0
             ld    b, CHESTSAT
             call  goSprite
             ld    hl, ChestState
             ld    (hl), CHEST_IS_OFF
             ret

+:

; Update chest sprite position.

             ld    a, (ChestState)
             ld    c, a
             ld    d, (hl)
             inc   hl
             ld    e, (hl)
             ld    b, CHESTSAT
             call  goSprite

             ret

.ends