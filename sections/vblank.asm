.orga $0038
.section "Maskable interrupt handler" force
             ex    af, af'         ; save AF in their shadow register
             in    a, VDPCOM       ; VDP status / satisfy interrupt
             exx                   ; save the rest of the registers

             call  scroller        ; scrolling the background
             call  objects
             call  updScore        ; write the digits
             call  hdlFrame        ; bluelib frame handler
             call  PSGFrame        ; psglib housekeeping
             call  PSGSFXFrame     ; process next SFX frame

             exx                   ; restore the registers
             ex    af, af'         ; also restore AF
             ei                    ; enable interrupts
             reti                  ; return from interrupt
.ends


.section "Objects" free
objects:

; Respond to soldier's current mode (TODO: move out of VBlank!)

             ld    a, (solMode)    ; get soldier mode
             cp    SOLHURT         ; is he currently hurting?
             jp    z, hdlHurt      ; handle hurting process

             cp    SOLDYING        ; is he dying?
             jp    nz, object2     ; if not, skip to next object

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
             jp    nz, object2     ; if not, handle nwxt object
             ld    hl, solMode     ; if so, point to soldier's mode
             ld    (hl), SOLDEAD   ; and update it to "dead"

; Soldier is dead; add to player's score.

             ld    hl, score + 3   ; point to the hundreds column
             ld    b,  2           ; one soldier is worth 200 points!
             call  goScore         ; call the score updater routine
             jp       object2      ; handle next object

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
             jp    object2         ; jump to next objects

; C) Hurt sequence is just going on...

++:          dec   (hl)            ; decrease counter

; Handle next object (currently no other objects...)

object2:
             ret                   ; return to int. handler
.ends


.section "Update score display" free
updScore:
             ld    d, SCORE + 6    ; point to 100.000 digit (dest.)
             ld    ix, score       ; point to score
             ld    a, (ix + 0)     ; get MSB of score
             sub   '0'             ; subtract ASCII zero
             add   a, DIGITS       ; add tile bank index of digits
             ld    e, a            ; put result in E (source)
             call  putTile         ; write the digit tile
             ld    a, (ix + 1)     ; next digit, 10.000
             sub   '0'
             add   a, DIGITS
             inc   d
             ld    e, a
             call  putTile
             ld    a, (ix + 2)     ; next digit, 1.000
             sub   '0'
             add   a, DIGITS
             inc   d
             ld    e, a
             call  putTile
             ld    a, (ix + 3)     ; next digit, 100
             sub   '0'
             add   a, DIGITS
             inc   d
             ld    e, a
             call  putTile
             ld    a, (ix + 4)     ; next digit, 10
             sub   '0'
             add   a, DIGITS
             inc   d
             ld    e, a
             call  putTile
             ld    a, (ix + 5)     ; next digit, 1
             sub   '0'
             add   a, DIGITS
             inc   d
             ld    e, a
             call  putTile
             ret
.ends


.section "Scroller handling" free
scroller:
; Every frame: Check scroller flag to see if screen needs scrolling.

             ld    a, (scrlFlag)   ; read value of scroller flag
             cp    1               ; is it set?
             jp    nz, noScroll    ; if not, skip scrolling

; Scroll the background/tilemap one pixel to the left.

             ld    hl, scrlReg     ; update register value variable
             dec   (hl)            ; scroll left = decrement
             ld    a, (hl)         ; get current value (0-255)
             out   (VDPCOM), a     ; send 1st byte of command word
             ld    a, 8            ; register 8 = horiz. scroll
             or    CMDREG          ; or with write register command
             out   (VDPCOM), a     ; send 2nd byte of command word

; Scroll chest if it is on screen.

             ld   a, (cstMode)     ; point to chest mode
             cp   CHESTOFF         ; is chest turned off?
             jp   z, +       ; if so, skip to column check

             ld   hl, cstX         ; point to chest x pos
             dec  (hl)             ; decrement it
             ld   a, (hl)          ; put value in A for a comparison
             cp   0                ; is chest x = 0 (blanked clmn)?
             jp   nz, uptChest     ; if not, forward to update chest

; Chest has scrolled off screen, so destroy it.

             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 0            ; reset y pos
             ld    b, CHESTSAT     ; B = the chest's index in SAT
             call  goSprite        ; update SAT RAM buffer
             ld    hl, cstMode     ; point to chest mode
             ld    (hl), CHESTOFF  ; set chect mode to OFF
             jp    +         ; forward to check column

; Update chest sprite position.

uptChest:    ld    a, (cstMode)
             ld    c, a            ; chest mode
             ld    d, (hl)         ; D
             inc   hl
             ld    e, (hl)         ; E
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

+: ; next test - the soldier...
;**

; Scroll soldier if he is on screen.

             ld   a, (solMode)     ; point to soldier mode
             cp   SOLOFF         ; is soldier turned off?
             jp   z, chkClmn       ; if so, skip to column check

             ld   hl, solX         ; point to soldier x pos
             dec  (hl)             ; decrement it
             ld   a, (hl)          ; put value in A for a comparison
             cp   0                ; is chest x = 0 (blanked clmn)?
             jp   nz, uptSol     ; if not, forward to update chest

; Soldier has scrolled off screen, so destroy him.
debug1:
             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 0            ; reset y pos
             ld    b, SOLSAT     ; B = the chest's index in SAT
             call  goSprite        ; update SAT RAM buffer
             ld    hl, solMode     ; point to chest mode
             ld    (hl), SOLOFF  ; set chect mode to OFF
             jp    chkClmn         ; forward to check column

; Update soldier sprite position.

uptSol:    ld    a, (solMode)
             ld    c, a            ; chest mode
             ld    d, (hl)         ; D
             inc   hl
             ld    e, (hl)         ; E
             ld    b, SOLSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

;**
; The leftmost 8 pixels on screen hides (fully/partially) one column.
; Check scroll value to see if next column is hidden = ready to fill.

chkClmn:     ld    a, (scrlReg)    ; H. scroll reg. (#8) RAM mirror
             and   %00000111       ; apply fine scroll mask
             cp    0               ; next column completely hidden?
             jp    nz, resFlag     ; if not > skip the following...

; Update the hidden column in the name table (minus status bar!).

             ld    a, (nextClmn)   ; which clmn is currently hidden?
             call  setClmn         ; update it (minus status bar!)
             ld    (nextClmn), a   ; store next hidden column number

; Check if there is already an active chest on screen.

             ld    a, (cstMode)    ; get chest mode
             cp    CHESTOFF        ; is the chest currently off?
             jp    nz, resFlag     ; if so, forward to reset flag

; Determine if we should put a new chest on screen.

             call  goRandom        ; random num. 0-127 (or 0-255)?
             sub   20              ; higher number = bigger chance
             jp    po, resFlag     ; if it overflowed, no new chest

; Put a new chest oustide the screen to the right, ready to scroll.

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

; Reset the scroll flag and return.

resFlag:     xor    a              ; clear A
             ld    (scrlFlag), a   ; clear scroll flag

; Finish scroll handler.

noScroll:    ret                   ; return to frame int. handler

.ends
