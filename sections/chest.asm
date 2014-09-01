; Chest module

.define CHEST_IS_CLOSED $20
.define CHEST_IS_OPEN $21
.define CHEST_IS_OFF   $ff

; positions in the SAT:
.define CHESTSAT   2


.ramsection "Chest variables" slot 3

cstMode      db                    ; chest is off, closed or open?
cstX         db                    ; chest x pos
cstY         db                    ; chest y pos
ChestFlag    db                    ; chest flag for signalling
.ends

; ChestFlag has the following flags
; xxxx xxxp
; p = award points to player (for slashing it open)
; -------------------------------------------------------------------

.section "Chest initialize" free
cstInit:
; Initialize chest, but don't put it on screen.

             ld    ix, cstMode     ; point ix to the chest data block
             ld    (ix + 0), CHEST_IS_OFF
             ld    (ix + 1), 0     ; chest x pos
             ld    (ix + 2), 0     ; chest y pos
             ld    (ix + 3), 0     ; chest flags

             ld    c, 0            ; C = charcode
             ld    d, (ix + 1)
             ld    e, (ix + 2)     ; E
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ret
.ends

.section "Chest loop manager"
ManageChestLoop:

; Clear status flag.

             xor   a
             ld    (ChestFlag), a

; Check for collision between Arthur's sword and closed chest.

             call  _IsHitBySword

; Create, update or destroy chest depending on ScrollerFlag.

             call  _Scroller

; Return to main loop.

             ret

_IsHitBySword:
             ld    a, (cstMode)    ; get chest mode
             cp    CHEST_IS_OFF        ; is it closed?
             ret    z              ; if no closed chest > skip coll.

             cp    CHEST_IS_CLOSED         ; is it closed?
             ret    nz             ; if no closed chest > skip coll.


; Check if Arthur's sword collides with chest.

             ld    hl, wponX       ; hl = obj1 (x,y) - Arthur's sword
             ld    a, (plrDir)     ; adjust depending on direction
             cp    LEFT
             jp    nz, +
             inc   (hl)            ; the sword is not 8 pix wide
             inc   (hl)
             inc   (hl)
             jp    ++
+:           dec (hl)              ;
             dec (hl)
             dec (hl)
++:          ld    de, cstX       ;
             call  clDetect        ; coll. between obj1 and obj2?
             ret    nc            ; if no coll. > skip

; Open chest (sprite) and change chest mode.

             ld    ix, cstMode     ; point to chest data block
             ld    c, CHEST_IS_OPEN      ; charcode for open chest
             ld    d, (ix + 1)     ; param: chest x pos in D
             ld    e, (ix + 2)     ; param: chest y pos in E
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ld    hl, cstMode     ; point to chest mode
             ld    (hl), CHEST_IS_OPEN   ; update mode to "open"
             ld    hl, ChestFlag
             set   1, (hl)          ; signal to score module...

             ret


_Scroller:

             ld    a, (scrlFlag)
             cp    1                   ; is flag set for scrolling?
             ret    nz

; Check if there is already an active chest on screen.

             ld    a, (cstMode)
             cp    CHEST_IS_OFF             ;
             jp    nz, ++

; Determine if we should put a new chest on screen.

             call  goRandom        ; random num. 0-127 (or 0-255)?
             sub   20              ; higher number = bigger chance
             ret   po             ; if it overflowed, no new chest

; Put a new chest outside the screen to the right, ready to scroll.

             ld    ix, cstMode     ; point ix to the chest data block
             ld    (ix + 0), CHEST_IS_CLOSED  ; set chest mode to closed
             ld    (ix + 1), 255   ; chest x pos
             call  goRandom
             and   %00011111       ; get random number 0-31
             add   a, 115          ; add 115 to get a valid y pos
             ld    (ix + 2), a     ; chest y pos

             ld    c, CHEST_IS_CLOSED      ; C = charcode
             ld    d, (ix + 1)     ; chest x
             ld    e, (ix + 2)     ; chest y
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

; Scroll the chest.
++:
             ld   hl, cstX         ; point to  x pos
             dec  (hl)             ; decrement it
             ld   a, (hl)          ; put value in A for a comparison
             cp   0                ;
             jp   nz, +     ; if not, forward...

; chest has scrolled off screen, so destroy him.

             xor   a
             ld    (cstX), a
             ld    (cstY), a

             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 0            ; reset y pos
             ld    b, CHESTSAT     ; B = the chest's index in SAT
             call  goSprite        ; update SAT RAM buffer
             ld    hl, cstMode     ; point to chest mode
             ld    (hl), CHEST_IS_OFF  ; set chect mode to OFF
             ret

; Update chest sprite position.
+:
             ld    a, (cstMode)
             ld    c, a            ; chest mode
             ld    d, (hl)         ; D
             inc   hl
             ld    e, (hl)         ; E
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ret

.ends