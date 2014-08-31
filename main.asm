/*
Knights of the Square
*/

; -------------------------------------------------------------------
; Command line options
.define PSASSETS                  ; enable PSP assets
; -------------------------------------------------------------------


; creates 3 x 16 KB slots for ROM and 1 x 8 KB slot for RAM
; TODO: Initialize the mapper a'la Charles MacDonald!!
.memorymap
defaultslot 2
slotsize $4000
slot 0 $0000
slot 1 $4000
slot 2 $8000
slotsize $2000
slot 3 $C000
.endme

; maps 32 KB of ROM into 2 x 16 KB banks
.rombankmap
bankstotal 2
banksize $4000
banks 2
.endro

; Definitions

; scoring
.define DIGITS     $10             ; tile bank index of digits
.define SCORE      19              ; where to begin the score display

; colors
.define YELLOW     $0f
.define ORANGE     $07


; Ram module.
; All variables default to 0, because ram is cleared by bluelib.
; --------------------------------------------------------------------
.ramsection "Variables" slot 3
score:       ds 6                  ; a RAM data block for the score

rndSeed      dw                    ; used by goRandom as seed
.ends

; semi-generic SMS library
.include "lib\bluelib.inc"

; sound handling. Thank you Sverx!
.include "lib\psglib.inc"

; VBlank handling
.include "sections\vblank.asm"

; misc. functions
.include "sections\misc.asm"

; chest object handling
.include "sections\chest.asm"

; thug module
.include "sections\thug.asm"

; player module
.include "sections\player.asm"

; stage module
.include "sections\stage.asm"


; --------------------------------------------------------------------

.bank 0 slot 0
.org 0
.section "Startup" force
             di                    ; disable interrupts
             im    1               ; interrupt mode 1
             ld    sp, $dff0       ; stack pointer near end of RAM
             jp    init            ; begin initializing game
.ends

.section "Initialize game" free
init:        call  initBlib        ; initialize bluelib

             call  stagInit

; Initialize random number seed.

             ld    hl, rndSeed     ; point hl to random seed word
             ld    a, r            ; get refresh register
             ld    (hl), a         ; update LSB of seed
             inc   hl              ; point to MSB
             ld    (hl), a         ; update MSB of seed


             call cstInit          ; initialize chest

; Initialize the thug.

             call  thugInit

; Initialize player character.

             call  plrInit

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

; Initilize PSGLib.

             call PSGInit          ; initialize PSGLib

; Turn display on.

             ld     a, DSPON       ; get display constant
             call   toglDSP        ; turn display on using bluelib
             ei                    ; enable interrupts
             jp     gameLoop       ; jump to main game loop
.ends


.section "Main game loop" free

gameLoop:

             call  stagLoop
             call  plrLoop
             call  thugLoop        ; update the thug object
             call  cstLoop

             halt                  ; finish loop by waiting for ints.
             halt                  ; = this game runs at 30 FPS?
             jp    gameLoop        ; then over again...
.ends



.orga $0066
.section "Non-Maskable interrupt handler (pause)" force
             retn                  ; disable pause button
.ends

; -------------------------------------------------------------------
;                            DATA
; -------------------------------------------------------------------

.section "Level 1 data: Village on fire (abbrev. 'fire')" free
; Sprite tiles in pattern generator bank 1:
fireSPR:
.ifdef PSASSETS

.include "tile\ps\fireSPR.inc"
; Palette data for CRAM banks 1 (backgr.) and 2 (backgr. + sprites):
firePal:
.include "palette\firePal1.inc"
.include "palette\ps\firePal2.inc"

.else

.include "tile\fireSPR.inc"
; Palette data for CRAM banks 1 (backgr.) and 2 (backgr. + sprites):
firePal:
.include "palette\firePal1.inc"
.include "palette\firePal2.inc"

.endif


; Background tiles in pattern generator bank 2:
fireBG:
.include "tile\fireBG.inc"

; sound effect:
sfxSword:
.incbin "sfx\slash.psg"

sfxBonus:
.incbin "sfx\bonus.psg"
.ends