; ------------------------------------------------------------------;
;                    KNIGHTS OF THE SQUARE                          ;
; ------------------------------------------------------------------;

; Work in progress, 2014

; -------------------------------------------------------------------


; Create 3 x 16 KB slots for ROM and 1 x 8 KB slot for RAM.

.memorymap
defaultslot 2
slotsize $4000
slot 0 $0000
slot 1 $4000
slot 2 $8000
slotsize $2000
slot 3 $C000
.endme

; Map 32 KB of ROM into 2 x 16 KB banks.

.rombankmap
bankstotal 2
banksize $4000
banks 2
.endro

; TODO: Initialize the mapper a'la Charles MacDonald.
; - if I ever need paging...

; ATTENTION! Update the following vars when changing the graphics.

.define NUMBER_OF_SPRITE_TILES 64
.define NUMBER_OF_BACKGROUND_TILES $52

.define SCROLL_TRIGGER   126       ; step here to scroll the screen
.define BASELINE   92              ; where is the common ground?

; All variables default to 0, because ram is cleared by bluelib.
.ramsection "Variables" slot 3
rndSeed      dw                    ; used by goRandom as seed

scrlFlag     db                    ; shall we scroll screen at int.?
scrlReg      db                    ; mirror of value in scroll reg.
nextClmn     db                    ; next name tab. clmn to be blanked
mapData      dw                    ; pointer to nxt column of map data
scrlBrk      db                    ; block scrolling


; Two buffer columns (the width of one 16 x 16 meta tile).
; 'Filler' name table elements are on both sides of the meta tile.
; Refer to DummyColumnFill (menu, sky, road, black bottom).
ColumnBuffer dsb 2 * 24 * 2

; Which of the two buffer columns is the next one to load from?
NextColumn db

; The next byte to read from the MetaTileScript?
MetaTileScriptIndex db

.ends

.section "Stagestuff" free


; Meta tile dictionary:
; 0 = Black square    1 = Sky        2 = Road
; 3 = Tree            4 = House      5 = Fence

MetaTileScript:
; One screen is 15 meta tiles
.db 1 1 1 1 11 3 1 6 1 1 1 3 3 1 4
.db 1 6 6 11 1 1 3 1 1 3 4 5 4 5 5
.db 5 5 4 5 5 11 1 1 8 9 10 4 7 12 4
.db 3 3 1 5 5 4 5 5 12 1 1 1 7 12 7 
.db 5 5 5 5
MetaTileScriptEnd:

; END_OF_LEVEL = amount of meta tiles + 1
.define END_OF_LEVEL 65

ColumnDummyFill:
; column 0
.db $00 $01 $10 $01   ; black

.db $02 $01 $12 $01  ;sky
.db $02 $01 $12 $01
.db $02 $01 $12 $01
.db $02 $01 $12 $01

.db $04 $01 $14 $01    ; road
.db $04 $01 $14 $01

.db $00 $01 $10 $01   ; black
.db $00 $01 $10 $01   ; black
.db $00 $01 $10 $01   ; black
.db $00 $01 $10 $01   ; black
.db $00 $01 $10 $01   ; black

; column 1:
.db $00 $01 $10 $01   ; black

.db $02 $01 $12 $01  ;sky
.db $02 $01 $12 $01
.db $02 $01 $12 $01
.db $02 $01 $12 $01

.db $04 $01 $14 $01    ; road
.db $04 $01 $14 $01

.db $00 $01 $10 $01   ; black
.db $00 $01 $10 $01   ; black
.db $00 $01 $10 $01   ; black
.db $00 $01 $10 $01   ; black
.db $00 $01 $10 $01   ; black

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

; score module
.include "sections\score.asm"

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

             call  stagLoop
             call  plrLoop
             call  ManageThugLoop        ; update the thug object
 ;            call  ManageChestLoop

 ;            call  scorLoop
 ;            call  ManageDebugPanelLoop

            ; halt                  ; finish loop by waiting for ints.
             halt                  ; = this game runs at 30 FPS?
             jp    gameLoop        ; then over again...
.ends

.orga $0038
.section "Maskable interrupt handler" force
             ex    af, af'         ; save AF in their shadow register
             in    a, VDPCOM       ; VDP status / satisfy interrupt
             exx                   ; save the rest of the registers

             call  scroller        ; scrolling the background
             call  updScore        ; write the digits
             call  hdlFrame        ; bluelib frame handler
             call  PSGFrame        ; psglib housekeeping
             call  PSGSFXFrame     ; process next SFX frame

             exx                   ; restore the registers
             ex    af, af'         ; also restore AF
             ei                    ; enable interrupts
             reti                  ; return from interrupt
.ends



.orga $0066
.section "Non-Maskable interrupt handler (pause)" force
             retn                  ; disable pause button
.ends

.section "Update score display" free
;TODO - make this a buffer to be otir'ed every frame...
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

; The leftmost 8 pixels on screen hides (fully/partially) one column.
; Check scroll value to see if next column is hidden = ready to fill.

chkClmn:     ld    a, (scrlReg)    ; H. scroll reg. (#8) RAM mirror
             and   %00000111       ; apply fine scroll mask
             cp    0               ; next column completely hidden?
             jp    nz, resFlag     ; if not > skip the following...

; Update the hidden column in the name table .

             ld    a, (nextClmn)   ; which clmn is currently hidden?
             push  af
;             call  setClmn         ; update it (minus status bar!)
             call   LoadColumn
             pop   af
             inc   a
             cp    32
             jp    nz, +
             xor   a
+:           ld    (nextClmn), a   ; store next hidden column number



; Reset the scroll flag and return.

resFlag:     xor    a              ; clear A
             ld    (scrlFlag), a   ; clear scroll flag

; Finish scroll handler.

noScroll:    ret                   ; return to frame int. handler


.ends

.section "Stage initialize" free
InitializeStage:
             ld    hl, firePal     ; firePal: Lev. 1 palette data
             call  setCRAM         ; define all colors in CRAM

             ld    hl, $0000       ; start in bank 1, index = 00
             call  prepVRAM        ; tell this to VDP
             ld    hl, fireSPR     ; source data: Sprite tiles
             ld    bc, NUMBER_OF_SPRITE_TILES*32   ; tiles x 32, each tile = 32 bytes
             call  wrteVRAM        ; load tiles into tilebank


             ld    hl, $2000       ; start at bank 2 (index = 256)
             call  prepVRAM        ; tell this to VDP
             ld    hl, fireBG      ; source data: Background tiles
             ld    bc, NUMBER_OF_BACKGROUND_TILES*32       ; no. of tiles x 32
             call  wrteVRAM        ; load tiles into tilebank
             
             call  InitializeColumnBuffer
             
; ***** THIS IS IMPORTANT ******************
             ld    a, 1
             ld    (nextClmn), a
; I need to find a better place for it!!!
; ******************************************

; Create initial name table setup.


             ld    a, 1
-:
             push  af
             call  LoadColumn      ; don't worry, the screen is off
             pop   af
             inc   a
             cp    32
             jp    nz, -

             ld   a, 0
             call LoadColumn
             ret



.ends


.section "Stage loop" free
; -------------------------------------------------------------------
;                           CHECK SCROLL TRIGGER                    ;
; -------------------------------------------------------------------
stagLoop:
             ld    hl, plrX        ; the horizontal pos. of player
             ld    a, (hl)         ; read from variable to register
             cp    SCROLL_TRIGGER        ; player on the scroll trigger?
             jp    nz, _step1           ; if not, then no scrolling


             ld    a, (plrState)
             cp    ATTACK
             jp    z, _step1

             call  getPlr1         ; get player 1 input indirectly
             bit   CTRIGHT, a      ; standing on trigger pushing right?
             jp    z, _step1


; Read from map data to see if the next byte is the terminator ($ff).

             ld    a, (MetaTileScriptIndex)
             cp    END_OF_LEVEL
             jp    nc, _step1

; Scrolling OK. Set the scroll flag

             ld    a, 1            ; 1 = flag is set
             ld    (scrlFlag), a   ; set scroller flag

_step1:
             ret
.ends

.section "Stage helper functions" free
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