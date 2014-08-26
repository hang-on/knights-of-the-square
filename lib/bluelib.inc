/*

**********************************************************************
                                 BLUELIB
**********************************************************************

     NAME                             SUMMARY
-----------------   --------------------------------------------------
dfColor             DEFINE COLOR: Defines a specified color in
                    CRAM bank 1 or 2

dfTile              DEFINE TILE: Defines a 32 byte pattern

hdlFrame            HANDLE FRAME: Housekeeping function to
                    handle bluelib matters during frame interrupt

getPlr1             GET PLAYER 1 INPUT: Get input from player 1's
                    controller

getPlr2             GET PLAYER 2 INPUT: Get input from player 2's
                    controller


initBuff            INITIALIZE SAT BUFFER: Write zeroes to the
                    designated bytes in RAM

initVDP             INITIALIZE VDP REGISTERS: Set up all 11 registers 
                    in one function call

setBrdr             SET BORDER COLOR: Set the border color to a color
                    defined in CRAM bank 2

wtPlr1              WAIT FOR PLAYER 1: Wait for player 1 to release
                    all keys

wtPlr2              WAIT FOR PLAYER 2: Wait for player 2 to release
                    all keys

setCRAM             SET COLOR RAM: define all 32 colors in CRAM

initBlib            INITIALIZE BLUELIB: Initializes bluelib

toglDSP             TOGGLE DISPLAY: Enable / disable display

prepVRAM            Send command word to VDP

wrteVRAM            Write data to VDP data port

----------------------------------------------------------------------
REQUIREMENTS AND LIMITATIONS
----------------------------------------------------------------------
VDP:
- Frame interrupts are enabled
- Line interrupts are disabled

----------------------------------------------------------------------
SOURCES AND INSPIRATION
----------------------------------------------------------------------
- Charles MacDonald, ...
- Sverx, ...
- Maxim, ...
- Bock, ...
- Calindro
- homsar47, ...
- Kagesan, ...
- SEGA Software Reference, ...
- SMS-Power dev. forum and documents, ...
*/

; ********************************************************************
; DEFINITIONS
; ********************************************************************

.define VDPCOM     $bf             ; VDP command port
.define VDPDATA    $be             ; VDP control port
.define CMDCRAM    %11000000       ; command word: Write CRAM
.define CMDWRITE   %01000000       ; command word: Write VRAM
.define CMDREG     %10000000       ; command word: Set VDP register
.define TILEBNK1   $ffe0           ; address of VRAM tilebank 1
.define TILEBNK2   $1fe0           ; address of VRAM tilebank 2

.define SMAPSIZE   768 * 2         ; size of screen map/name table
.define SMAPADDR   $3800           ; screen map address (default set.)

; for toggling the display: (assuming bluelib std VDP settings)
.define DSPOFF     %10100000       ; display off
.define DSPON      %11100000       ; display on


; for defining character patterns:
.define VRAM1      %00000001       ; VRAM tile bank 1
.define VRAM2      %00000010       ; VRAM tile bank 2

; color bank 1 or 2 in CRAM
.define CRAM1      $01
.define CRAM2      $02

; definitions for writing to individual color slots in the CRAM
; used by the function dfColor
.define C0B1       $00 ; color 0 in bank 1 is also the screen
.define C1B1       $01 ; background color
.define C2B1       $02
.define C3B1       $03
.define C4B1       $04
.define C5B1       $05
.define C6B1       $06
.define C7B1       $07
.define C8B1       $08
.define C9B1       $09
.define C10B1      $0A
.define C11B1      $0B
.define C12B1      $0C
.define C13B1      $0D
.define C14B1      $0E
.define C15B1      $0F

.define C0B2       $10 ; bank 2 is for sprites and border color
.define C1B2       $11 ; - according to the software reference.
.define C2B2       $12 ; (seems to contradict with reality)
.define C3B2       $13
.define C4B2       $14
.define C5B2       $15
.define C6B2       $16
.define C7B2       $17
.define C8B2       $18
.define C9B2       $19
.define C10B2      $1A
.define C11B2      $1B
.define C12B2      $1C
.define C13B2      $1D
.define C14B2      $1E
.define C15B2      $1F

; use these in a bit test with getPlr1 or getPlr2
.define CTUP       0
.define CTDOWN     1
.define CTLEFT     2
.define CTRIGHT    3
.define CTBTN1     4
.define CTBTN2     5

; for flags
.define FLGSET     1
.define FLGRESET   0


; ********************************************************************
; VARIABLES
; ********************************************************************
.ramsection "Bluelib variables" slot 3
frmCount     DB                    ; counts frames
portDC       DB                    ; keeps the latest reading of the
portDD       DB                    ; input ports
CRAMBuf      DSB 32                ; 2 x 16 colors
CRAMFlag     DB                    ; flag for CRAM buffer
.ends

.ramsection "Sprite Attribute Table RAM buffer" slot 3
bfVert       DSB 64                ; byte: Vertical pos. of sprites
bfHoriz      DSB 128               ; word: Horiz. pos. + charcode
.ends



; *********************************************************************
; FUNCTIONS
; *********************************************************************

; ====================================================================
.section "hdlFrame" free
; HANDLE FRAME
; Frame-by-frame housekeeping. Put this function in the maskable
; interrupt handler (at $0038) - assuming line interrupts are disabled
; --------------------------------------------------------------------
hdlFrame:

             ld    hl, frmCount    ; increment frame counter
             inc   (hl)

; copy Sprite Attribute Table (SAT) from RAM buffer to VRAM
; --------------------------------------------------------------------
; SAT begins at $3F00 in VRAM and at bfVert in RAM
; Issue a command word to the VDP, saying we want to write to VRAM
; starting at $3F00 (refer to the Software Reference p. 12.)
; Command word = $4000 or'ed with $3F00 - LSB. Which means that we send
; $00 first, and then 0100 0000 or'ed with ($40) - the command to
; prepare to writing to VRAM
; 0011 1111  ($3F) - the most significant byte of the target address
; 0100 0000  ($40) - command word CMDWRITE
; 0111 1111 = $7F

             ld    a, $00          ; it's safe to issue this command
             out   (VDPCOM), a     ; since interrupts are disabled
             ld    a, $7F
             out   (VDPCOM), a     ; now the VDPDATA is ready at $3F00

             ld    b, 64           ; 64 bytes of bfVert
             ld    c, VDPDATA      ; to send to the VDPDATA
             ld    hl, bfVert      ; by copying from vertical buffer
             otir

             ld    a, $80          ; point to where VRAM sat stores
             out   (VDPCOM), a     ; words of HPos and char codes
             ld    a, $7F
             out   (VDPCOM), a     ; now the VDPDATA is ready at $3F80

             ld    b, 128          ; 128 bytes of HPos and char codes
             ld    c, VDPDATA      ; to send to the VDPDATA
             ld    hl, bfHoriz     ; by copying from horiz. buffer
             otir

; Store input from controllers in variables

             in    a, $DC          ; read input port $DC
             ld    hl, portDC      ; store it in designated variable
             ld    (hl),a

             in    a, $DD           ; read input port $DD
             ld    hl, portDD       ; store it in designated variable
             ld    (hl),a

; Check CRAM buffer flag, and copy on request.

             ld    a, (CRAMFlag)
             cp    FLGSET
             jp    nz, +


             ld    a, $00          ; prepare VDP for write to CRAM
             out   (VDPCOM), a     ; starting at color $00
             ld    a, CMDCRAM
             out   (VDPCOM), a

             ld    hl, CRAMBuf
             ld    b, 32           ; write all 32 bytes of color data
             otir

             ld    a, FLGRESET          ; reset flag
             ld    (CRAMFlag), a

+:
             ret                   ; return from frame housekeeping
.ends
; ====================================================================


; ====================================================================
.section " getPlr1" free
; GET PLAYER 1 INPUT: Returns formatted input byte in register A, to
; be tested with the definitions for user input
; --------------------------------------------------------------------
getPlr1:     ld    a, (portDC)
             cpl                   ; invert bits in register A
             res   6, a            ; clean bits related to player two
             res   7, a
             ret
.ends
; ====================================================================


; ====================================================================
.section "getPlr2" free
; GET PLAYER 2 INPUT: Returns formatted input byte in register A
; --------------------------------------------------------------------
getPlr2:
             ld    a, (portDC)     ; indirectly read data from port
             cpl                   ; invert bits in register A
             and   %11000000       ; reset all bits except 6 and 7
             rlca                  ; shift these bits to obtain a
             rlca                  ; format like player 1 input data
             ld    b, a

             ld    a, (portDD)
             cpl                   ; invert bits
             rlca                  ; shift the bits left two times
             rlca                  ; and finally combine the reading
             or    b               ; from first port (up and down) +
                                   ; second (left, right and buttons)
             ret
.ends
; ====================================================================


; ====================================================================
.section  "wtPlr1" free
; WAIT FOR PLAYER 1
; Keep looping until player 1 releases all keys
; --------------------------------------------------------------------
wtPlr1:      call  getPlr1
             cp    %00000000       ; bits are off = no keys pressed
             jp    nz, wtPlr1
             ret
.ends
; ====================================================================

; ====================================================================
.section "wtPlr2" free
; WAIT FOR PLAYER 2
; Keep looping until player 2 releases all keys
; --------------------------------------------------------------------
wtPlr2:      call  getPlr2
             cp    %00000000       ; bits are off = no keys pressed
             jp    nz, wtPlr2
             ret
.ends
; ====================================================================



; ====================================================================
.section "_toggleDisplay" free
; TOGGLE DISPLAY: Turn the screen on or off
; Parameter: A = enableDisplay or disableDisplay (definitions)
; Note: Frame interrupts and 8 x 8 sprites are alsO enabled each time
; this function is called.
; Note: Remember to disable interrupts prior to calling this function.
toglDSP:     out   (VDPCOM), a
             ld     a, $81
             out    (VDPCOM), a
             ret
.ends
; ====================================================================


; ====================================================================
.section "initVDP" free
; INITIALIZE VDP REGISTERS
; Entry: HL = pointer to 11 bytes of data
initVDP:     ld    b, 11
             ld    c, $80

-:           ld    a, (hl)
             out   (VDPCOM), a
             inc   hl
             ld    a, c
             out   (VDPCOM), a
             inc    c
             djnz   -
             ret
.ends
; ===================================================================

; ===================================================================
.section "_VDPInitData" free
; VDP STANDARD REGISTER SETTINGS
; Standard bluelib VDP register settings
; Use this data to initialize VDP registers so that they comply with
; requirements of bluelib.
; NOTE: Ended up being pretty specific to Blockquest horiz. scroller
VDPStd:
    .db %01100110                  ; b4 = line interrupt (disabled)
                                   ; b5 = blank left column (enabled)
                                   ; b6 = dont scroll top two rows

    .db %10100000                  ; b5 = frame interrupt (enabled)
                                   ; b6 = turn display off
    .db $FF                        ; name table at $3800
    .db $FF                        ; always $ff
    .db $FF                        ; alwaus $ff
    .db $FF                        ; sprite attrib. table at $3F00
    .db $FB                        ; sprite tiles in first 8K of VRAM
    .db %11110001                  ; border color (color 1 in bank 2)
    .db $00                        ; horiz. scroll = 0
    .db $00                        ; vert. scroll = 0
    .db $FF                        ; disable line counter
.ends
; ====================================================================


; ====================================================================
.section "initBuff" free
; INITIALIZE SAT BUFFER
; initializes the Sprite Attribute Table RAM buffer.
initBuff:    ld    b, 64           ; 64 sprites
             ld    hl, bfVert      ; HL pointing to bfVert in RAM
-:           ld    (hl), $00       ; write $00 to avoid messy RAM
             inc   hl              ; point to next byte
             djnz  -               ; process every 64 bfVert byte

             ld    hl, bfVert
             ld    (hl), $D0       ; sprite terminator placed at
                                   ; first sprite to disable them all

             ld    b, 128          ; like above, now with HPos
             ld    hl, bfHoriz     ; and char code (word-sized data)
-:           ld    (hl), $00
             inc   hl
             djnz  -
             ret
.ends
; ====================================================================


; ====================================================================
.section "setBrdr" free
; SET BORDER COLOR
; function to set the border color
; Entry: Register A = an aready defined color in bank 2
; --------------------------------------------------------------------
setBrdr:     or    %11110000
             out   (VDPCOM), a
             ld    a, $87
             out   (VDPCOM), a
             ret
.ends
; ====================================================================

; ====================================================================
.section "dfColor" free
; DEFINE COLOR
; define a color in either bank 1 or 2 in CRAM
; Entry: Register B = CRAM index (which color in which bank?),
;        Register C = Color (in RGB format)
; tip: use the CRAM definitions
; example:
;     ld         b, C0B2
;     ld         c, MAROON              ; defined in code
;     call       dfColor
; --------------------------------------------------------------------
dfColor:     ld    hl, CRAMBuf
             ld    d, 0
             ld    e, b
             add   hl, de
             ld    (hl), c
             ld    a, FLGSET
             ld    (CRAMFlag), a
             ret
.ends
; ====================================================================


; ====================================================================
.section "dfTile" free
; DEFINE TILE
; Entry: A = character to define (index), B = bank 1 or 2 (use def.!)
;        HL = pointing to 32 bytes of character pattern (tile data)
; --------------------------------------------------------------------
dfTile:      inc   a
             push  hl              ; save the source data pointer
             bit   1, b
             jp    nz, +
; first 8K (fall through)
             ld    hl, $ffe0       ; the start of VRAM bank 1
             jp    writTile
; second 8K of RAM - almost
+:           ld    hl, $1fe0       ; the start of VRAM bank 2

writTile:    ld    b, a
             ld    de, 32          ; 32 bytes = character pattern
-:           add   hl, de          ; fast forward through patterns
             djnz   -              ; do it until we reach the target

             ld     a, l           ; tell VDP to be ready for writing
             out    (VDPCOM), a    ; to VRAM address DE and beyond
             ld     a, h
             or     CMDWRITE
             out    (VDPCOM), a

             pop    hl             ; retrieve the source pointer
             ld     b, 32          ; prepare to out 32 bytes
             ld     c, VDPDATA     ; to the data port
             otir

             ret
.ends
; ====================================================================

; ====================================================================
.section "goSprite" free
; GO SPRITE
; Updates a sprite's SAT attributes in the bluelib SAT buffer
; Entry: B = sprite number (index), C = CharCode
;        D = X (HPos), E = Y (VPos)
; --------------------------------------------------------------------

; Load new sprite y (vertical position) into buffer.

goSprite:    push  de              ; save new x and y pos
             ld    d, 0            ; set D = 0
             ld    e, b            ; set E = sprite index
             ld    hl, bfVert      ; point to first part of buffer
             add   hl, de          ; update HL to point to sprite y
             pop   de              ; retrieve new y pos
             ld    (hl), e         ; load new y pos into buffer

; Load new sprite x (horizontal position) and charcode into buffer.

             push  de              ; save new x and y pos
             ld    d,0             ; set D = 0
             ld    a, b            ; set A = sprite index
             add   a, b            ; A = A * 2 (words in this part!)
             ld    e, a            ; put multiplied value into E
             ld    hl, bfHoriz     ; point to second part of buffer
             add   hl, de          ; update HL to point to sprite x
             pop   de              ; retrieve new x pos
             ld    (hl), d         ; load new x pos into buffer
             inc   hl              ; HL points to sprite char code
             ld    (hl), c         ; load new char code into buffer

             ret
.ends
; ====================================================================

; ====================================================================
.section "setCRAM" free
; SET COLOR RAM
; define all 32 colors in CRAM
; Entry: HL = pointer to 32 bytes of color
; example:
;     ld         hl, myColors
;     call       setCRAM
; --------------------------------------------------------------------
setCRAM:     ld    de, CRAMBuf
             ld    bc, 32
             ldir
             ld    a, FLGSET               ; set flag
             ld    (CRAMFlag), a

             ret
.ends
; ====================================================================


; ====================================================================
.section "initBlib" free
; INITIALIZE BLUELIB
; should be called before interrupts are enabled
; and before any bluelib function is called
; --------------------------------------------------------------------
initBlib:    ld    hl, VDPStd
             call  initVDP         ; init VDP
             call  initBuff        ; init SAT RAM buffer
             ret
.ends
; ====================================================================

; ====================================================================
.section "Prepare VRAM" free
; PREPARE VRAM
; Set up VDP to recieve data at VRAM address in HL
; --------------------------------------------------------------------
prepVRAM:    push  af
             ld    a, l
             out   (VDPCOM), a
             ld    a, h
             or    CMDWRITE
             out   (VDPCOM), a
             pop   af
             ret
.ends
; ====================================================================

; ====================================================================
.section "Write to VRAM" free
; Write BC amount of bytes from data source pointed to be HL
; TIP: Use prepVRAM before calling, to set the destionation address
; --------------------------------------------------------------------
wrteVRAM:
             ld    a, (hl)
             out   (VDPDATA), a
             inc   hl
             dec   bc
             ld    a, c
             or    b
             jp    nz, wrteVRAM
             ret
.ends
; ====================================================================


