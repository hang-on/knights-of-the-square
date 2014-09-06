; Stage

; Header ------------------------------------------------------------
.define NUMSPR     64              ; # of tiles in sprite bank (1)
.define NUMBG      $52              ; # of tiles in bg. bank (2)

.define SCRLTRIG   126
.define BASELINE   92

.section "Stagestuff" free


; Meta tile dictionary:
; 0 = Black square    1 = Sky        2 = Road
; 3 = Tree            4 = House      5 = Fence

MetaTileScript:
.db 1 1 1 1 1 1 1 1 3 1 4 5 5 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1

.define END_OF_LEVEL 50            ; level length in meta tiles

ColumnDummyFill:
; column 0
.db $00 $01 $10 $01   ; black

.db $02 $01 $12 $01  ;sky
.db $02 $01 $12 $01
.db $02 $01 $12 $01
.db $06 $01 $16 $01  ;tree

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

.ramsection "Stage variables" slot 3
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
; -------------------------------------------------------------------

.section "Stage initialize" free
InitializeStage:
             ld    hl, firePal     ; firePal: Lev. 1 palette data
             call  setCRAM         ; define all colors in CRAM

             ld    hl, $0000       ; start in bank 1, index = 00
             call  prepVRAM        ; tell this to VDP
             ld    hl, fireSPR     ; source data: Sprite tiles
             ld    bc, NUMSPR*32   ; tiles x 32, each tile = 32 bytes
             call  wrteVRAM        ; load tiles into tilebank


             ld    hl, $2000       ; start at bank 2 (index = 256)
             call  prepVRAM        ; tell this to VDP
             ld    hl, fireBG      ; source data: Background tiles
             ld    bc, NUMBG*32       ; no. of tiles x 32
             call  wrteVRAM        ; load tiles into tilebank
             
             call  InitializeColumnBuffer
             
; Create initial name table setup.

             ld    b, 32
             ld    a, 0
-:
             push  af
             push  bc
             call  LoadColumn      ; don't worry, the screen is off
             pop   bc
             pop   af
             inc   a
             djnz  -



             ret



.ends


.section "Stage loop" free
; -------------------------------------------------------------------
;                           CHECK SCROLL TRIGGER                    ;
; -------------------------------------------------------------------
stagLoop:
             ld    hl, plrX        ; the horizontal pos. of player
             ld    a, (hl)         ; read from variable to register
             cp    SCRLTRIG        ; player on the scroll trigger?
             jp    nz, _step1           ; if not, then no scrolling


             ld    a, (plrState)
             cp    ATTACK
             jp    z, _step1

             call  getPlr1         ; get player 1 input indirectly
             bit   CTRIGHT, a      ; standing on trigger pushing right?
             jp    z, _step1


; Read from map data to see if the next byte is the terminator ($ff).

             ld    ix, mapData     ; mapData is a 16-bit pointer
             ld    e, (ix + 0)     ; LSB to E
             ld    d, (ix + 1)     ; MSB to D
             ld    a, (de)         ; get next byte from map data block
             cp    $ff             ; is it the terminator?
             jp    z, _step1            ; if so, then no scrolling

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


