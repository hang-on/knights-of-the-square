; Chest module

; Header ------------------------------------------------------------
.define CHESTCL    $20
.define CHESTOP    $21

; positions in the SAT:
.define CHESTSAT   2

; for the chest mode status byte
.define CHESTOFF   $ff

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
             ld    (ix + 0), CHESTOFF
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

.section "Chest handling"
cstLoop:
            ; clear status flag
             xor   a
             ld    (ChestFlag), a

; -------------------------------------------------------------------
;                 COLLISION DETECTION: SWORD AND CHEST              ;
; -------------------------------------------------------------------

             ld    a, (cstMode)    ; get chest mode
             cp    CHESTOFF        ; is it closed?
             jp    z, _step1       ; if no closed chest > skip coll.

             cp    CHESTCL         ; is it closed?
             jp    nz, _step1       ; if no closed chest > skip coll.


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
             jp    nc, _step1         ; if no coll. > skip

; Open chest (sprite) and change chest mode.

             ld    ix, cstMode     ; point to chest data block
             ld    c, CHESTOP      ; charcode for open chest
             ld    d, (ix + 1)     ; param: chest x pos in D
             ld    e, (ix + 2)     ; param: chest y pos in E
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ld    hl, cstMode     ; point to chest mode
             ld    (hl), CHESTOP   ; update mode to "open"
             ld    hl, ChestFlag
             set   1, (hl)          ; signal to score module...


; -------------------------------------------------------------------
;                 CHEST SCROLLER                                    ;
; -------------------------------------------------------------------
_step1:

             ld    a, (scrlFlag)
             cp    1                   ; is flag set for scrolling?
             jp    nz, _step3

; -------
; Check if there is already an active chest on screen.

             ld    a, (cstMode)
             cp    CHESTOFF             ;
             jp    nz, ++

; Determine if we should put a new chest on screen.

             call  goRandom        ; random num. 0-127 (or 0-255)?
             sub   20              ; higher number = bigger chance
             jp    po, _step3     ; if it overflowed, no new chest

; Put a new chest outside the screen to the right, ready to scroll.

             ld    ix, cstMode     ; point ix to the chest data block
             ld    (ix + 0), CHESTCL  ; set chest mode to closed
             ld    (ix + 1), 255   ; chest x pos
             call  goRandom
             and   %00011111       ; get random number 0-31
             add   a, 115          ; add 115 to get a valid y pos
             ld    (ix + 2), a     ; chest y pos

             ld    c, CHESTCL      ; C = charcode
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
             ld    (hl), CHESTOFF  ; set chect mode to OFF
             jp    _step3

; Update chest sprite position.
+:
             ld    a, (cstMode)
             ld    c, a            ; chest mode
             ld    d, (hl)         ; D
             inc   hl
             ld    e, (hl)         ; E
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)


_step3:

            ret




; goes into player module -------------------------------------------

; Check for collision between chest and player.



.ends