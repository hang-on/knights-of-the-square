; Score module


.define DIGITS     $10             ; tile bank index of digits
.define SCORE      19              ; where to begin the score display

.ramsection "Score variables" slot 3
score:       ds 6                  ; a RAM data block for the score
.ends

.section "Score init" free
scorInit:
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
scorLoop:
             ; the flags (part of?) are reset every loop
             ; read thugflag - add points
             ; read  cstFlag - add points  - dont touch these

             ; move score code out of vblank, and blast 6 bytes of ram every frame..
             ; work on a score ram buffer

             ret

/*; Add to player's score.

             ld    hl, score + 3    ; point to the hundreds column
             ld    b,  4            ; one chest is worth 400 points!
             call  goScore          ; call the score updater routine
*/

; Soldier is dead, add to player's score. (should go into player or score object)
; we can set a flag here?
;             ld    hl, score + 3   ; point to the hundreds column
;             ld    b,  2           ; one soldier is worth 200 points!
;             call  goScore         ; call the score updater routine



.ends