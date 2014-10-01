; Score module


.define DIGITS     $40             ; tile bank index of digits
.define SCORE      42              ; where to begin the score display

.ramsection "Score variables" slot 3
score:       ds 6                  ; a RAM data block for the score
.ends

.section "Score init" free
InitializeScore:
; Initialize score counter to 000000.

             ld    a, '0'          ; put ASCII zero into A
             ld    b, 6            ; we need 6 digits for the display
             ld    hl, score       ; pt. to score data block (6 byt.)
-:           ld    (hl), a         ; set digit to ASCII zero
             inc   hl              ; next digit
             djnz  -               ; do it for all 6 digits

; Write the word "SCORE" on the status bar.

             ld    d, SCORE        ; where to start putting tiles
             ld    e, DIGITS + 10  ; "SCORE" comes after the digits
             call  putTile         ; write "S"
             inc   d               ; next destination
             inc   e               ; next source ("C")
             call  putTile         ; write it
             inc   d               ; next destination
             inc   e         ;    ; "O" is just like zero here
             call  putTile         ; so write O/zero
             inc   d               ; and so on...
             inc   e
             call  putTile
             inc   d
             inc   e
             call  putTile

             ret
.ends

.section "Score loop" free
ManageScoreLoop:

             call  GetThugPoints
             call  GetChestPoints
             call  GetGoldPoints

             ret

GetThugPoints:

             ld    a, (ThugFlag)
             bit   1, a
             ret   z
             ld    hl, score + 3   ; point to the hundreds column
             ld    b,  2           ; one soldier is worth 200 points!
             call  goScore         ; call the score updater routine
             ret

GetChestPoints:

; Award player for smashing open a chest.

             ld    a, (ChestFlag)
             bit   0, a
             ret   z
             ld    hl, score + 3
             ld    b,  1
             call  goScore
             ret

GetGoldPoints:

; Award player for picking up gold (an open chest).

             ld    a, (player_flag)
             bit   0, a
             ret   z
             ld    hl, score + 3
             ld    b,  4
             call  goScore

             ret

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
             ret   z
; Update the next digit to the left.

             sub   10
             ld    (hl), a
nxtDigit:    dec   hl              ; move pointer to nxt digit (left)
             inc   (hl)            ; increase that digit
             ld    a, (hl)         ; load value into A
             cp    '9'             ; test it
             ret   c               ; if below 9, then scoring is done
             ret   z
             sub   10
             ld    (hl), a
             jp    nxtDigit        ; update the next digit



.ends