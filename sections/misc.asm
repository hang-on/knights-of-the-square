.section "Misc. functions" free
; -------------------------------------------------------------------
; SCORE
; Assumes a data block for keeping the score
; Data block: a series of bytes, ie: 00000
; Adapted from Jonathan Cauldwell
; Entry: HL points to the digit we want to increase
;        B holds the amount by which to increase the digit
; Exit: The data block pointed to by HL is updated

goScore:

; Add the specified amount to the digit.

             ld    a, (hl)         ; get the value of the digit
             add   a, b            ; add the amount to this value
             ld    (hl), a         ; put updated digit back in string
             cp    '9'             ; test updated digit
             ret   c               ; if 9 or less, relax and return

; Update the next digit to the left.

             sub   10
             ld    (hl), a
nxtDigit:    dec   hl              ; move pointer to nxt digit (left)
             inc   (hl)            ; increase that digit
             ld    a, (hl)         ; load value into A
             cp    '9'             ; test it
             ret   c               ; if below 9, then scoring is done
             sub   10
             ld    (hl), a
             jp    nxtDigit        ; update the next digit

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
; SET COLUMN
; Set the tiles of a column in the name table MINUS the status bar!
; Expects variable 'mapData' to point to a column of tiles (source)
; Entry: A = column in name table (0-31 - destination)
; Exit:  A = next column (entry + 1)

; Load pointer to source data into DE.

setClmn:     ld    hl, mapData     ; load pointer to data
             inc  (hl)
             inc  (hl)
             inc  (hl)
             inc  (hl)

             ld    e, (hl)         ; LSB to E
             inc   hl
             ld    d, (hl)         ; MSB to D, now DE = source addr.

; Calculate destination nametable address and store in HL.

             push  af              ; save param. destination column
             ld    h, $38          ; all clmns start somewhere $30xx
             cp    0               ; is destination the first column?
             jp    z, ++           ; if so, then skip to data loading
             ld    b, a            ; loop count: no. of clmns to skip
             ld    a, 0            ; start with offset + 0

-:           add   a, $2           ; add 2 to offset for every clmn
             djnz  -               ; stop looping if we are at dest.

++:          ld    l, a            ; HL = addr. of name table dest.
             ld    bc, $0080
             add   hl, bc          ; skip status bar
             ld    b, 22           ; loop count: 22 rows in a column

; Load a word from source DE to name table at address HL.

ldName:      ld    a, l            ; load destination LSB into L
             out   (VDPCOM), a     ; send it to VDP command port
             ld    a, h            ; load destination MSB into H
             or    CMDWRITE        ; or it with write VRAM command
             out   (VDPCOM), a     ; set result to VDP command port

             ld    a, (de)         ; load source LSB into A
             out   (VDPDATA), a    ; send it to VRAM
             inc   de              ; point DE to MSB of source word
             ld    a, (de)         ; load it into A
             out   (VDPDATA), a    ; and send it to VRAM
             inc   de              ; point DE to LSB of next tile

             push  bc              ; save counter
             ld    bc, $0040       ; step down one row ($40 = 32 * 2)
             add   hl, bc          ; update destination pointer
             pop   bc              ; restore counter

             djnz  ldName          ; load another word-sized name?

; Update RAM copy of map data pointer (DE) + return next column in A.

             ld    hl, mapData     ; let HL point to variable
             ld    (hl), e         ; load LSB of data pointer
             inc   hl
             ld    (hl), d         ; load MSB of data pointer

             pop   af              ; retrieve entry value
             inc   a               ; increment it
             cp    32              ; are we outside the name table?
             ret   nz              ; if not, just return
             xor   a               ; return 0 as next column
             ret                   ; and then return

; -------------------------------------------------------------------
; SET COLUMN 2 - nasty workaround! Sets a column incl. status bar
; Set the tiles of a column in the name table
; Expects variable 'mapData' to point to a column of tiles (source)
; Entry: A = column in name table (0-31 - destination)
; Exit:  A = next column (entry + 1)

; Load pointer to source data into DE.

setClmn2:     ld    hl, mapData     ; load pointer to data

             ld    e, (hl)         ; LSB to E
             inc   hl
             ld    d, (hl)         ; MSB to D, now DE = source addr.

; Calculate destination nametable address and store in HL.

             push  af              ; save param. destination column
             ld    h, $38          ; all clmns start somewhere $30xx
             cp    0               ; is destination the first column?
             jp    z, ++           ; if so, then skip to data loading
             ld    b, a            ; loop count: no. of clmns to skip
             ld    a, 0            ; start with offset + 0

-:           add   a, $2           ; add 2 to offset for every clmn
             djnz  -               ; stop looping if we are at dest.

++:          ld    l, a            ; HL = addr. of name table dest.
             ld    b, 24           ; loop count: 24 rows in a column

; Load a word from source DE to name table at address HL.

ldName2:      ld    a, l            ; load destination LSB into L
             out   (VDPCOM), a     ; send it to VDP command port
             ld    a, h            ; load destination MSB into H
             or    CMDWRITE        ; or it with write VRAM command
             out   (VDPCOM), a     ; set result to VDP command port

             ld    a, (de)         ; load source LSB into A
             out   (VDPDATA), a    ; send it to VRAM
             inc   de              ; point DE to MSB of source word
             ld    a, (de)         ; load it into A
             out   (VDPDATA), a    ; and send it to VRAM
             inc   de              ; point DE to LSB of next tile

             push  bc              ; save counter
             ld    bc, $0040       ; step down one row ($40 = 32 * 2)
             add   hl, bc          ; update destination pointer
             pop   bc              ; restore counter

             djnz  ldName2          ; load another word-sized name?

; Update RAM copy of map data pointer (DE) + return next column in A.

             ld    hl, mapData     ; let HL point to variable
             ld    (hl), e         ; load LSB of data pointer
             inc   hl
             ld    (hl), d         ; load MSB of data pointer

             pop   af              ; retrieve entry value
             inc   a               ; increment it
             cp    32              ; are we outside the name table?
             ret   nz              ; if not, just return
             xor   a               ; return 0 as next column
             ret                   ; and then return

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


.ends