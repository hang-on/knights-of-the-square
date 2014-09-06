/*
Knights of the Square
*/


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


; colors
.define YELLOW     $0f
.define ORANGE     $07


; All variables default to 0, because ram is cleared by bluelib.
; --------------------------------------------------------------------
.ramsection "Variables" slot 3
rndSeed      dw                    ; used by goRandom as seed
.ends

; semi-generic SMS library
.include "lib\bluelib.inc"

; sound handling. Thank you Sverx!
.include "lib\psglib.inc"


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

; score module
.include "sections\score.asm"

; VBlank handling
.include "sections\vblank.asm"

; Debugger panel w. flags
.include "sections\debug.asm"


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

             call  InitializeStage

; Initialize random number seed.

             ld    hl, rndSeed     ; point hl to random seed word
             ld    a, r            ; get refresh register
             ld    (hl), a         ; update LSB of seed
             inc   hl              ; point to MSB
             ld    (hl), a         ; update MSB of seed

;             call scorInit         ; init score module

;             call InitializeChest          ; initialize chest

; Initialize the thug.

             call  ThugInit

; Initialize player character.

             call  plrInit

; Initilize PSGLib.

             call PSGInit          ; initialize PSGLib

; Initialize debug panel

;             call  InitializeDebugPanel

; Turn display on.

             ld     a, DSPON       ; get display constant
             call   toglDSP        ; turn display on using bluelib
             ei                    ; enable interrupts
             jp     gameLoop       ; jump to main game loop
.ends


.section "Main game loop" free

gameLoop:

 ;            call  stagLoop
             call  plrLoop
             call  ManageThugLoop        ; update the thug object
 ;            call  ManageChestLoop

 ;            call  scorLoop
 ;            call  ManageDebugPanelLoop

            ; halt                  ; finish loop by waiting for ints.
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
; .include "tile\ps\fireSPR.inc"
;.include "tile\zoom\sprites.inc"
.include "tile\zoomed\Sprite-tiles.inc"


; Palette data for CRAM banks 1 (backgr.) and 2 (backgr. + sprites):
firePal:
;.include "palette\firePal1.inc"
;.include "palette\ps\firePal2.inc"
.include "palette\zoomed\Background-palette.inc"
.include "palette\zoomed\Sprite-palette.inc"

; Background tiles in pattern generator bank 2:
fireBG:
; .include "tile\fireBG.inc"
.include "tile\zoomed\Background-tiles.inc"

; sound effect:
sfxSword:
.incbin "sfx\slash.psg"

sfxBonus:
.incbin "sfx\bonus.psg"
.ends