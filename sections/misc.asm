.section "Misc. functions" free

; -------------------------------------------------------------------
; PUT TILE
; Puts a tile somewhere in the first 256 positions in the name table.
; Use it to update score, lives, stuff in the top status bar.
; Entry: D = Destination (0-63), E = Source (tile index in bank 1)
; Using colors from bank 2 (sprite colors)

putTile:

; Update HL so that it points to destination name table element.

             ld    h, $38          ; MSB on nametable will be $38
             ld    a, 0            ; start from the beginning
             ld    b, d            ; feed destination to loop counter
-:           add   a, 2            ; name table consist of words
             djnz  -               ; loop until we get to destination
             ld    l, a            ; put multiplied value in l

; Write a word of data to the name table.

             call  prepVRAM        ; prepare VRAM for writes at HL
             ld    a, e            ; put tile index in A (param.)
             out   (VDPDATA), a    ; write tile index to name table
             ld    a, $08          ; use sprite colors
             out   (VDPDATA), a    ; tell it to VDP
             ret                   ; return

; -------------------------------------------------------------------
; COLLISION DETECTION
; Check for collision between two 8x8 objects/sprites (width = 8)
; Math: obj1Width + obj2Width + 1 <= (abs(obj1X - obj2X) + 1)2
; Entry: HL = pointer to obj 1 x,y, DE = pointer to obj2 x,y
; Exit: carry flag is set if collision is detected

clDetect:

; Test for horizontal overlap.

             ld    a, (hl)         ; get obj1 x pos (top left corner)
             add   a, 4            ; update x pos to center of sprite
             ld    b, a            ; save it in B
             ld    a, (de)         ; get obj2 x pos (top left corner)
             add   a, 4            ; update x pos to center of sprite
             sub   b               ; subtract the two x pos'
             bit   7,a             ; is the result negative (signed)?
             jp    z, +            ; if not, go ahead with test
             neg                   ; if so, do the abs() trick
+:           add   a, 1            ; according to the formula above
             add   a ,a            ; also according to the formula
             jp    pe, resCarry    ; fix for wrap-around issue!
             cp    17              ; 8 + 8 + 1(width of the objects)
             ret   nc              ; no horiz. overlap = no coll!

; Test for vertical overlap.

             inc   hl              ; move hl from obj1X to obj1Y
             inc   de              ; move de from obj2X to obj2Y
             ld    a, (hl)         ; get obj1Y
             add   a, 4            ; update to sprite's center
             ld    b, a            ; save value in B
             ld    a, (de)         ; get obj2Y
             add   a, 4            ; update to sprite's center
             sub   b               ; subtract the two y pos'
             bit   7,a             ; is the result negative (signed)?
             jp    z, +            ; if not, go ahead
             neg                   ; if so, do the abs() trick
+:           add   a, 1            ; according to the formula
             add   a ,a            ; also according to the formula
             jp    pe, resCarry    ; fix for wrap-around issue
             cp    17              ; 2 x 8 + 1
             ret                   ; exit: if carry then collision

resCarry:    or    a               ; reset carry flag
             ret                   ; return to overlap test



; -------------------------------------------------------------------
; ADVANCE ANIMATION
; advance animation one cel
; HL = variable containing cel index, DE = pointer to animation data
; Exit: The variable pointed to by HL is updated according to script
advcAnim:    push  hl
             ld    a, (hl)         ; forward to next cel in animation
             ld    b, a
             inc   b
             ld    h, 0
             ld    l, b
             add   hl, de
             ld    a, (hl)
             cp    $ff             ; if we meet the terminator $ff
             jp    nz, +           ; reset animation to cel 0
             ld    b, 0
+:           ld    a, b
             pop   hl
             ld    (hl), a
             ret
; -------------------------------------------------------------------
; GET ARRAY ITEM
; get byte sized item from array
; Entry: HL = array, A = index (8 bit index)
; Exit: A = item at given position
arrayItm:    ld    d, 0
             ld    e, a
             add   hl, de
             ld    a, (hl)
             ret

; -------------------------------------------------------------------
; GET RANDOM NUMBER (goRandom)
; Adapted from SMS-Power (Phantasy Star)
; Uses a 16-bit RAM variable called rndSeed for seed
; Returns an 8-bit pseudo-random number in A
goRandom:    push  hl
             ld    hl,(rndSeed)
             ld    a,h             ; get high byte
             rrca                  ; rotate right by 2
             rrca
             xor   h               ; xor with original
             rrca                  ; rotate right by 1
             xor   l               ; xor with low byte
             rrca                  ; rotate right by 4
             rrca
             rrca
             rrca
             xor   l               ; xor again
             rra                   ; rotate right by 1 through carry
             adc   hl,hl           ; add rndSeed to itself
             jr    nz,+
             ld    hl,$733c        ; if last xor resulted in zero then re-seed
+:           ld    a,r             ; r = refresh register = semi-random number
             xor   l               ; xor with l which is fairly random
             ld    (rndSeed),hl
             pop   hl
             ret                   ; return random number in a


; -------------------------------------------------------------------
; COLLISION DETECTION - IMPROVED!
; H = Obj1X, L = Obj1Y, B = Obj1Size
; D = Obj2X, E = Obj2Y  C = Obj2Size
; Returns with carry flag set if the two objects overlap

DetectCollision:

; Test for horizontal overlap.

             ld    a, h         ; get obj1 x pos (top left corner)
             add   a, 4            ; update x pos to center of sprite
             ld    b, a            ; save it in B
             ld    a, d         ; get obj2 x pos (top left corner)
             add   a, 4            ; update x pos to center of sprite
             sub   b               ; subtract the two x pos'
             bit   7,a             ; is the result negative (signed)?
             jp    z, +            ; if not, go ahead with test
             neg                   ; if so, do the abs() trick
+:           add   a, 1            ; according to the formula above
             add   a ,a            ; also according to the formula
             jp    pe, ResetCarry    ; fix for wrap-around issue!
             cp    17              ; 8 + 8 + 1(width of the objects)
             ret   nc              ; no horiz. overlap = no coll!

; Test for vertical overlap.

             ld    a, l         ; get obj1Y
             add   a, 4            ; update to sprite's center
             ld    b, a            ; save value in B
             ld    a, e         ; get obj2Y
             add   a, 4            ; update to sprite's center
             sub   b               ; subtract the two y pos'
             bit   7,a             ; is the result negative (signed)?
             jp    z, +            ; if not, go ahead
             neg                   ; if so, do the abs() trick
+:           add   a, 1            ; according to the formula
             add   a ,a            ; also according to the formula
             jp    pe, ResetCarry    ; fix for wrap-around issue
             cp    17              ; 2 x 8 + 1
             ret                   ; exit: if carry then collision

ResetCarry:
             or    a               ; reset carry flag
             ret                   ; return to overlap test

.ends