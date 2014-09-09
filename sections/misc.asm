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
             ld    a, $01          ; use bg. colors and tile bank 1
             out   (VDPDATA), a    ; tell it to VDP
             ret                   ; return




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
; COLLISION DETECTION
; Detects collision between two square objects on a 2D field.
; Each object has a (x,y) position (like in the SAT).
; The size of each object is the object's width or height in pixels.
; The collision detection routine makes the following two tests:
; 1) Overlap on x-axis?
;    Obj1Size + Obj2Size + 1 <= (Abs(Obj1X - Obj2X) + 1)2
;
; 2) Overlap on y-axis?
; 2) Obj1Size + Obj2Size + 1 <= (Abs(Obj1Y - Obj2Y) + 1)2
;
; If both tests are true, then we have a collision!
; The following parameters are expected on entry:
; H = Obj1X, L = Obj2X,
; D = Obj1Y, E = Obj2Y
; B = Obj1Size, C = Obj2Size
;
; Returns with carry flag set if the two objects overlap on both axes
; = collision!
; (c)arry = (c)ollision - oh, clever :)

DetectCollision:

             call  TestOverlap     ; test for x-axis overlap
             ret   nc              ; if no overlap, skip next test
             ld    h, d            ; load Obj1Y into h
             ld    l, e            ; load Obj2Y into l
             call  TestOverlap     ; test for y-axis overlap

             ret                   ; return (w. carry flag set/reset)

TestOverlap:

             ; Start by working out the right side of the equation.
             ; Pos (position) is either X or Y: Depends on the test.

             ; Prepare stuff.
             push  bc              ; save BC for later
             srl   b               ; get half of Obj1's size
             srl   c               ; get half of Obj2's size

             ; Update H to contain the center of Obj1.
             ld    a, h            ; load Obj1Pos into A
             add   a, b            ; Obj1Pos + (Obj1Size/2) = center
             ld    h, a            ; update H

             ; Update A to contain the center of Obj2.
             ld    a, l            ; load Obj2Pos into A
             add   a, c            ; Obj2Pos + (Obj2Size/2) = center
             pop   bc              ; restore non-halved sizes

             ; Perform (Obj1Pos - Obj2Pos).
             sub   h               ; subtract the two coordinates

             ; Make sure we got the absolute value, Abs().
             jp    p, +            ; is the result negative (signed)?
             neg                   ; if so, do the Abs() trick

             ; Complete the right side (Abs(Obj1Pos - Obj2Pos)+1)2.
+:           inc   a               ; add the + 1
             add   a ,a            ; add the * 2

             ; Fix for screen wrap-around collision.
             jp  po, +             ; if no overflow, then proceed...
             or    a               ; else, reset carry flag
             ret                   ; and return no-carry 

             ; Do the Obj1Size + Obj2Size + 1.
+:           push  af
             ld    a, b            ; store Obj1 size in A
             add   a, c            ; add Obj2 size
             inc   a               ; add + 1 (left side is complete)
             ld    b, a            ; copy left side into B
             pop   af              ; retrieve right side of equation
             cp    b               ; compare left and right side
             ret                   ; return (with carry set/reset)

/*
             ; Example of DetectCollision in action.
             ; The following detects collision between the player
             ; object (plrX, plrY) and a thug object (ThugX, ThugY)

             ld    a, (plrX)       ; set up the paramters
             ld    h, a
             ld    a, (plrY)
             ld    d, a
             ld    b, 8            ; the player is an 8x8 box
             ld    a, (ThugX)
             ld    l, a
             ld    a, (ThugY)
             ld    e, a
             ld    c, 8            ; the thug is also an 8x8 box

             call  DetectCollision ; invoke the routine
             call  c, HandleCollision  ; branch in case of collision
*/




.ends