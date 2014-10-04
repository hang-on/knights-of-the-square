; ------------------------------------------------------------------;
;                    KNIGHTS OF THE SQUARE                          ;
; ------------------------------------------------------------------;

; Work in progress, 2014
.SDSCTAG 0.25, "Knights of the Square", "Hack and slash!", "Anders Skriver Jensen"

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

; Include libraries and modules.

.include "lib\bluelib.inc"
.include "lib\psglib.inc"
.include "sections\chest.asm"
.include "sections\thug.asm"
.include "sections\player.asm"
.include "sections\score.asm"
.include "sections\debug.asm"
.include "sections\elm.asm"
.include "sections\plm.asm"
.include "sections\slm.asm"
.include "sections\swordman.asm"

; ATTENTION! Update the following vars when changing the graphics --;
;                                                                   ;
.define NUMBER_OF_SPRITE_TILES $4b                                   ;
.define NUMBER_OF_BACKGROUND_TILES $5c                              ;
;                                                                   ;
; -------------------------------------------------------------------

.define SCROLL_TRIGGER   126       ; step here to scroll the screen
.define BASELINE   92              ; where is the common ground?

.asciitable
map " " to "~" = 0
.enda


; All variables default to 0, because ram is cleared by bluelib.
.ramsection "Variables" slot 3
; NOTE: must not be separated (see title screen set seed...)
RandomizerSeed      dw             ; used by goRandom as seed
seed                dw             ; seed for Cauldwell's rnd

scroll_flag db                      ; shall we scroll screen at int.?
HorizontalScrollRegister db        ; mirror of value in scroll reg.
NextScrollColumn db                ; next name tab. clmn to be blanked

MetaTileScriptIndex db             ; next MetaTileScript byte to read
MetaTileBuffer dsb 4               ; the current meta tile's tiles
MetaTileBufferIndex db             ; next MetaTileBuffer byte to read

palette_stepper db                 ; used by FlashMessage in title screen
titlescreen_counter dw

debug_byte db
.ends

.bank 0 slot 0
.org 0
.section "Startup" force
begin_rom:
             di                    ; disable interrupts
             im    1               ; interrupt mode 1
             ld    sp, $dff0       ; stack pointer near end of RAM
             jp    title_screen
.ends

.section "Initialize game" free
; TODO: Initialize the mapper a'la Charles MacDonald.
; - if I ever need paging...

InitializeGame:

             call  InitializeStage

             call  InitializeScore

             ;call  InitializeThug

             ;call  InitializeSwordman

             call  InitializeChest

             call  InitializePlayer


             call  InitializeDebugPanel

; Turn display on.

             call   ToggleDisplay        ; turn display on using bluelib

             ei                    ; enable interrupts

             jp     gameLoop       ; jump to main game loop
.ends


.section "Main game loop" free

gameLoop:

; Invoke the modules' loop handlers.
             call  ManageStageLoop
             call  ManagePlayerLoop
             call  ManageChestLoop
             call  ManageThugLoop
             call  ManageSwordmanLoop
             call  ManageScoreLoop
             call  ManageELMLoop
             call  ManageSLMLoop

             ; check to see if level has ended
             ld    a, (plrX)
             cp    $f8  ;
             jp    z, EndLevel


gameloop_finished:                 ; breakpoint for profiling
             nop
             halt
             jp    gameLoop

.ends

.orga $0038
.section "Maskable interrupt handler" force
frame_interrupt_start:
             ex    af, af'         ; save AF in their shadow register

             in    a, VDPCOM       ; VDP status / satisfy interrupt

             exx                   ; save the rest of the registers

             call  ManageScrolling  ; scrolling the background
             call  UpdateScore     ; write the digits
             call  HandleELMFrame
             call  HandlePLMFrame
             call  HandleSLMFrame
             call  hdlFrame        ; bluelib frame handler
             call  PSGFrame        ; psglib housekeeping
             call  PSGSFXFrame     ; process next SFX frame

             exx                   ; restore the registers
             ex    af, af'         ; also restore AF

             ei                    ; enable interrupts

frame_interrupt_finished:          ; breakpoint for profiling
             nop

             reti                  ; return from interrupt
.ends



.orga $0066
.section "Non-Maskable interrupt handler (pause)" force
             retn                  ; disable pause button
.ends

.section "Update score display" free
;TODO - make this a buffer to be otir'ed every frame...
UpdateScore:

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
ManageScrolling:
; Every frame: Check ManageScrolling flag to see if screen needs scrolling.

             ld    a, (scroll_flag)   ; read value of ManageScrolling flag
             cp    1               ; is it set?
             jp    nz, noScroll    ; if not, skip scrolling

; Scroll the background/tilemap one pixel to the left.

             ld    hl, HorizontalScrollRegister     ; update register value variable
             dec   (hl)            ; scroll left = decrement
             ld    a, (hl)         ; get current value (0-255)
             out   (VDPCOM), a     ; send 1st byte of command word
             ld    a, 8            ; register 8 = horiz. scroll
             or    CMDREG          ; or with write register command
             out   (VDPCOM), a     ; send 2nd byte of command word

; The leftmost 8 pixels on screen hides (fully/partially) one column.
; Check scroll value to see if next column is hidden = ready to fill.

chkClmn:     ld    a, (HorizontalScrollRegister)    ; H. scroll reg. (#8) RAM mirror
             and   %00000111       ; apply fine scroll mask
             cp    0               ; next column completely hidden?
             jp    nz, resFlag     ; if not > skip the following...

; Update the hidden column in the name table .

             ld    a, (NextScrollColumn)   ; which clmn is currently hidden?
             push  af
             call  UpdateScrollColumn
             pop   af
             inc   a
             cp    32
             jp    nz, +
             xor   a
+:           ld    (NextScrollColumn), a   ; store next hidden column number



; Reset the scroll flag and return.

resFlag:     xor    a              ; clear A
             ld    (scroll_flag), a   ; clear scroll flag

; Finish scroll handler.

noScroll:    ret                   ; return to frame int. handler


UpdateScrollColumn:
; Loads the next two tiles from meta tile buffer to the name table.
; The precise destination is rows 9 and 10 in the scroll column.

; Get the destination address on the name table into HL.

             ld    a, (NextScrollColumn)
             cp    0
             jp    z, +            ; go straight to writing

             ld    b, a
             ld    a, 0
-:           add   a, 2            ; elements are word-sized
             djnz  -

+:           push  af              ; save the offset LSB
             ld    h, $3a
             ld    l, a            ; now HL points to destination

; Prepare VDP for writes to VRAM (the name table).

             ld    a, l            ; load destination LSB into L
             out   (VDPCOM), a     ; send it to VDP command port
             ld    a, h            ; load destination MSB into H
             or    CMDWRITE        ; or it with write VRAM command
             out   (VDPCOM), a     ; send result to VDP command port

; Is it time to reload the meta tile buffer?

             ld    a, (MetaTileBufferIndex)
             push  af
             cp    0
             jp    nz, +

             ; load new tilemap into buffer !!
/*             ld    hl, DummyData
             ld    de, MetaTileBuffer
             ld    bc, 4
             ldir
*/
             call  LoadMetaTileToBuffer


; Get the meta tile char code (source) to write to name table.

+:           pop   af
             ld    hl, MetaTileBuffer
             call  arrayItm        ; source charcode now in A

; Increment the buffer index.

             ld    hl, MetaTileBufferIndex
             inc   (hl)

; Write name table word (char code + '01') to name table.

             out   (VDPDATA), a    ; write the char code
             ld    a, 01           ; '01' says: tile is in bank 2
             out   (VDPDATA), a    ; write the second byte

; First tile has been written to VRAM.
; Prepare the VDP for writes to the address of the name table element
; that corresponds to the tile just below the one set above.

             pop  af               ; retrieve the destination LSB
             add  a, $40           ; point to the tile just below


             out   (VDPCOM), a     ; send it to VDP command port
             ld    a, $3a          ; stil the same MSB
             or    CMDWRITE        ; or it with write VRAM command
             out   (VDPCOM), a     ; send result to VDP command port

; Now VDP is ready at the new address. Get the source charcode.

             ld    hl, MetaTileBuffer
             ld    a, (MetaTileBufferIndex)
             call  arrayItm        ; now A holds the char code
             push   af
; Increment the buffer index

             ld    hl, MetaTileBufferIndex
             inc   (hl)

             ld    a, (MetaTileBufferIndex)
             cp    4
             jp    nz, +
             xor   a
             ld    (MetaTileBufferIndex), a
+:
             pop  af
; Write name table word (char code + '01') to name table.
             out   (VDPDATA), a    ; write the char code
             ld    a, 01           ; '01' says: tile is in bank 2
             out   (VDPDATA), a    ; write the second byte

             ret

LoadMetaTileToBuffer:

             ld    hl, MetaTileScript
             ld    a, (MetaTileScriptIndex)
             call  arrayItm ; now we got the item in A


             ; adjust tile offset
             xor   b
             cp    8
             jp    c, +
             ld    b, 16
+:           add   a, a
             add   a, b


             ld    ix, MetaTileBuffer
             ; put four tiles in the buffer
             ld    (ix + 0), a
             inc   a
             ld    (ix + 2), a
             add   a, 16
             ld    (ix + 3), a
             dec   a
             ld    (ix + 1), a

             ld    hl, MetaTileScriptIndex
             inc   (hl)

             ret

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


; ***** THIS IS IMPORTANT ******************
             ld    a, 1
             ld    (NextScrollColumn), a
; I need to find a better place for it!!!
; ******************************************

; Create initial name table setup.


; Get VDP ready for writes to the name table.

             ld    hl, NAME_TABLE
             call  prepVRAM

; Draw 2 black rows for the menu.

             ld    b, 32*2
-:           ld    a, 00
             out   (VDPDATA), a
             ld    a, 01
             out   (VDPDATA), a
             djnz  -

; Draw 8 bright blue rows for the sky.

.rept 2
             ld    b, 32*4
-:           ld    a, 02
             out   (VDPDATA), a
             ld    a, 01
             out   (VDPDATA), a
             djnz  -
.endr

; Draw 4 dark blue rows for the path.

             ld    b, 32*4
-:           ld    a, 04
             out   (VDPDATA), a
             ld    a, 01
             out   (VDPDATA), a
             djnz  -

; Fill the bottom of the screen with evil blackness.

.rept 2
             ld    b, 32*5
-:           ld    a, 00
             out   (VDPDATA), a
             ld    a, 01
             out   (VDPDATA), a
             djnz  -
.endr

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


.section "Stage loop" free
; -------------------------------------------------------------------
;                           CHECK SCROLL TRIGGER                    ;
; -------------------------------------------------------------------
ManageStageLoop:
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
             ld    (scroll_flag), a   ; set ManageScrolling flag

_step1:
             ret



.ends

.section "Misc routines" free



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
; Uses a 16-bit RAM variable called RandomizerSeed for seed
; Returns an 8-bit pseudo-random number in A
goRandom:    push  hl
             ld    hl,(RandomizerSeed)
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
             adc   hl,hl           ; add RandomizerSeed to itself
             jr    nz,+
             ld    hl,$733c        ; if last xor resulted in zero then re-seed
+:           ld    a,r             ; r = refresh register = semi-random number
             xor   l               ; xor with l which is fairly random
             ld    (RandomizerSeed),hl
             pop   hl
             ret                   ; return random number in a

; Cauldwell's rnd
; Simple pseudo-random number generator.
; Steps a pointer through the ROM (held in seed), returning
; the contents of the byte at that location.
GenerateRandomNumber:
             ld hl,(seed) ; Pointer
             ld a, (frame_counter)  ; tweaking Cauldwell's code here
             add a,h
             and 31 ; keep it within first 8k of ROM.
             ld h,a
             ld a,(hl) ; Get "random" number from location.
             inc hl ; Increment pointer.
             ld (seed),hl

             ret


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
             ; object (plrX, plrY) and a thug object (thug_x, thug_y)

             ld    a, (plrX)       ; set up the paramters
             ld    h, a
             ld    a, (plrY)
             ld    d, a
             ld    b, 8            ; the player is an 8x8 box
             ld    a, (thug_x)
             ld    l, a
             ld    a, (thug_y)
             ld    e, a
             ld    c, 8            ; the thug is also an 8x8 box

             call  DetectCollision ; invoke the routine
             call  c, HandleCollision  ; branch in case of collision
*/




.ends



; -------------------------------------------------------------------
;                            DATA
; -------------------------------------------------------------------

.section "Level 1 data: Village on fire (abbrev. 'fire')" free

; Meta tile dictionary:
; 0 = Black square    1 = Sky        2 = Road
; 3 = Tree            4 = House      5 = Fence

MetaTileScript:
; One screen is 15 meta tiles
.db 3 1 1 1 11 3 1 6 1 1 1 1 1 1 4
.db 1 6 6 11 1 1 1 1 1 1 4 5 4 5 5
.db 5 5 4 5 5 11 1 1 8 9 10 4 7 12 4
.db 1 1 1 5 5 4 5 5 12 1 1 1 1 5 5
.db 5 5 5 7

; END_OF_LEVEL = amount of meta tiles + 1
.define END_OF_LEVEL 65

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

.bank 1 slot 1
.section "End level" free
EndLevel:
             call  PSGSFXStop
             di
             call  ToggleDisplay

; load title screen assets to VDP


             ld    hl, $c000       ; start in bank 1, index = 00
             call  prepVRAM        ; tell this to VDP
             ld    hl, text_screen_palette     ; source data
             ld    bc, 16*2            ;
             call  wrteVRAM


             ld    hl, $2000       ;
             call  prepVRAM        ; tell this to VDP
             ld    hl, font_data      ; source data
             ld    bc, font_data_end-font_data
             call  wrteVRAM        ; load tiles into tilebank

             ld    hl, $3800
             call  prepVRAM
             ld    hl, $d000 ; rot! a place in RAM!!
             ld    bc, 32*24*2
             call  wrteVRAM

             ;write congrats to the name table
             call  _DisplayMessage

             ; kill sprites
             ld    hl, $3f00 ; SAT start
             call  prepVRAM
             ld    a, $d0
             out   (VDPDATA), a

             ; minimal screen turn on
             ld    a, %00100110   ; register 0
             out   (VDPCOM), a
             ld     a, $80
             out    (VDPCOM), a

             ld    a, %11000000    ; register 1
             out   (VDPCOM), a
             ld     a, $81
             out    (VDPCOM), a

              ld    a, %11110000   ; register 7 = border color
             out   (VDPCOM), a
             ld     a, $87
             out    (VDPCOM), a

             ld    a, 0   ; register 8 = horiz. scroll
             out   (VDPCOM), a
             ld     a, $88
             out    (VDPCOM), a


; Wait for P1 button
--:          in    a, ($dc)
             bit   4, a
             jp    nz, --

             jp    title_screen

;-:           jp    -


_DisplayMessage:
             ;ld    a, (ix + 0)
             ;cp   $10
             ;ret  nz


             ld    hl, $3ad0       ;
             call  prepVRAM        ; tell this to VDP
             ld    hl, _message
             ld    b, 16

-:           ld    a, (hl)            ; put tile index in A (param.)
             inc   hl
             out   (VDPDATA), a    ; write tile index to name table
             ld    a, %00001001          ; sprite palette and bank 2
             out   (VDPDATA), a    ; tell it to VDP
             djnz  -

             ret

_message:
.asc "LEVEL COMPLETED!"
_message_end


.ends


.section "Title screen" free
title_screen:
             call  clearRam



; load title screen assets to VDP


             ld    hl, $c000       ; start in bank 1, index = 00
             call  prepVRAM        ; tell this to VDP
             ld    hl, text_screen_palette     ; source data
             ld    bc, 16*2            ;
             call  wrteVRAM

             ld    hl, $0000       ;
             call  prepVRAM        ; tell this to VDP
             ld    hl, _tiles     ; source data
             ld    bc, 65*32            ; tiles x 32, each tile = 32 bytes
             call  wrteVRAM        ; load tiles into tilebank

             ld    hl, $3800       ;
             call  prepVRAM        ; tell this to VDP
             ld    hl, _tilemap     ; source data
             ld    bc, 32*24*2
             call  wrteVRAM        ;

             ld    hl, $2000       ;
             call  prepVRAM        ; tell this to VDP
             ld    hl, font_data      ; source data
             ld    bc, font_data_end-font_data
             call  wrteVRAM        ; load tiles into tilebank


; turn minimal screen on

             ld    a, %00100110   ; register 0
             out   (VDPCOM), a
             ld     a, $80
             out    (VDPCOM), a

             ld    a, %11000000    ; register 1
             out   (VDPCOM), a
             ld     a, $81
             out    (VDPCOM), a

              ld    a, %11110000   ; register 7 = border color
             out   (VDPCOM), a
             ld     a, $87
             out    (VDPCOM), a

             call  PSGInit         ; initialize PSGLib

             ld    a, $ff
             ld    (palette_stepper), a
             xor   a
             ld    ix, titlescreen_counter
             ld    (ix + 0), a
             ld    (ix + 1), a

             ld    hl, title_music
             call PSGPlayNoRepeat



--:
             call  GoRastertime ; wait until rasterline 192 (below visible display)
             call  PSGFrame

             ; inc word-sized frame counter
             ld    ix, titlescreen_counter
             inc   (ix + 0)
             jp    po, +
             inc   (ix +1)

+:
             ; very poor solution
             ; tiles are blasted to name table every frame from now on...
             ld    a, (ix + 1)
             cp    3
             call  nc, _DisplayMessage

             ld    a, (ix + 1)
             cp    4
             call  nc, _FlashMessage

/*             ld    b,250   ; make sure we go past line $c0 (GoRastertime)
-:             nop
             nop
             nop
             nop
             nop
             djnz  -
*/
; Wait for P1 button
             in    a, ($dc)
             bit   4, a
             jp    nz, --

; Start level 1
             call  PSGStop

             call  initBlib

; seed the timer with title screen button press
; two randomizer functions, oh, what a mess
debug:
             ld    ix, RandomizerSeed
             ld    a, (titlescreen_counter)
             ld    (ix + 0), a
             rla
             ld    (ix + 1), a
             rla
             ld    (ix + 2), a
             rla
             ld    (ix + 3), a


             jp    InitializeGame




; DIY wait for end of active display (0-191)
GoRastertime:
-:           in    a, ($7e)
             cp    $c0
             jp    nz, -
             ret

_FlashMessage:
             ld    a, $11          ; prepare VDP for write to CRAM
             out   (VDPCOM), a     ; starting at color $00
             ld    a, CMDCRAM
             out   (VDPCOM), a

             ; write a new value to sprite palette item 1
             ; depending on the stepper...
             ld    a, (palette_stepper)
             out   (VDPDATA), a
             dec   a
             ld    (palette_stepper), a
             ret


_DisplayMessage:
             ;ld    a, (ix + 0)
             ;cp   $10
             ;ret  nz


             ld    hl, $3b56       ;
             call  prepVRAM        ; tell this to VDP
             ld    hl, _message
             ld    b, 11

-:           ld    a, (hl)            ; put tile index in A (param.)
             inc   hl
             out   (VDPDATA), a    ; write tile index to name table
             ld    a, %00001001          ; sprite palette and bank 2
             out   (VDPDATA), a    ; tell it to VDP
             djnz  -

             ret

_message:
.asc "PRESS START"
_message_end

_tiles:
.include "titlescreen\tiles.inc"

text_screen_palette:
.include "titlescreen\palette.inc"

_tilemap:
.include "titlescreen\tilemap.inc"

.ends

.section "Music" free
title_music:
.incbin "titlescreen\ks-title-compr.psg"
.ends

.section "Font data" free
font_data:
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00
.db $18,$00,$00,$00,$00,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00
.db $6C,$00,$00,$00,$6C,$00,$00,$00,$6C,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $36,$00,$00,$00,$36,$00,$00,$00,$7F,$00,$00,$00,$36,$00,$00,$00
.db $7F,$00,$00,$00,$36,$00,$00,$00,$36,$00,$00,$00,$00,$00,$00,$00
.db $0C,$00,$00,$00,$3F,$00,$00,$00,$68,$00,$00,$00,$3E,$00,$00,$00
.db $0B,$00,$00,$00,$7E,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00
.db $60,$00,$00,$00,$66,$00,$00,$00,$0C,$00,$00,$00,$18,$00,$00,$00
.db $30,$00,$00,$00,$66,$00,$00,$00,$06,$00,$00,$00,$00,$00,$00,$00
.db $38,$00,$00,$00,$6C,$00,$00,$00,$6C,$00,$00,$00,$38,$00,$00,$00
.db $6D,$00,$00,$00,$66,$00,$00,$00,$3B,$00,$00,$00,$00,$00,$00,$00
.db $0C,$00,$00,$00,$18,$00,$00,$00,$30,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $0C,$00,$00,$00,$18,$00,$00,$00,$30,$00,$00,$00,$30,$00,$00,$00
.db $30,$00,$00,$00,$18,$00,$00,$00,$0C,$00,$00,$00,$00,$00,$00,$00
.db $30,$00,$00,$00,$18,$00,$00,$00,$0C,$00,$00,$00,$0C,$00,$00,$00
.db $0C,$00,$00,$00,$18,$00,$00,$00,$30,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$18,$00,$00,$00,$7E,$00,$00,$00,$3C,$00,$00,$00
.db $7E,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$7E,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$30,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7E,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$06,$00,$00,$00,$0C,$00,$00,$00,$18,$00,$00,$00
.db $30,$00,$00,$00,$60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$6E,$00,$00,$00,$7E,$00,$00,$00
.db $76,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $18,$00,$00,$00,$38,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$7E,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$06,$00,$00,$00,$0C,$00,$00,$00
.db $18,$00,$00,$00,$30,$00,$00,$00,$7E,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$06,$00,$00,$00,$1C,$00,$00,$00
.db $06,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $0C,$00,$00,$00,$1C,$00,$00,$00,$3C,$00,$00,$00,$6C,$00,$00,$00
.db $7E,$00,$00,$00,$0C,$00,$00,$00,$0C,$00,$00,$00,$00,$00,$00,$00
.db $7E,$00,$00,$00,$60,$00,$00,$00,$7C,$00,$00,$00,$06,$00,$00,$00
.db $06,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $1C,$00,$00,$00,$30,$00,$00,$00,$60,$00,$00,$00,$7C,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $7E,$00,$00,$00,$06,$00,$00,$00,$0C,$00,$00,$00,$18,$00,$00,$00
.db $30,$00,$00,$00,$30,$00,$00,$00,$30,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$3E,$00,$00,$00
.db $06,$00,$00,$00,$0C,$00,$00,$00,$38,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00
.db $00,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00
.db $00,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$30,$00,$00,$00
.db $0C,$00,$00,$00,$18,$00,$00,$00,$30,$00,$00,$00,$60,$00,$00,$00
.db $30,$00,$00,$00,$18,$00,$00,$00,$0C,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$7E,$00,$00,$00,$00,$00,$00,$00
.db $7E,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $30,$00,$00,$00,$18,$00,$00,$00,$0C,$00,$00,$00,$06,$00,$00,$00
.db $0C,$00,$00,$00,$18,$00,$00,$00,$30,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$0C,$00,$00,$00,$18,$00,$00,$00
.db $18,$00,$00,$00,$00,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$6E,$00,$00,$00,$6A,$00,$00,$00
.db $6E,$00,$00,$00,$60,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$7E,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$00,$00,$00,$00
.db $7C,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$7C,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$7C,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00
.db $60,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $78,$00,$00,$00,$6C,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$6C,$00,$00,$00,$78,$00,$00,$00,$00,$00,$00,$00
.db $7E,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00,$7C,$00,$00,$00
.db $60,$00,$00,$00,$60,$00,$00,$00,$7E,$00,$00,$00,$00,$00,$00,$00
.db $7E,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00,$7C,$00,$00,$00
.db $60,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$60,$00,$00,$00,$6E,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$7E,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$00,$00,$00,$00
.db $7E,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$7E,$00,$00,$00,$00,$00,$00,$00
.db $3E,$00,$00,$00,$0C,$00,$00,$00,$0C,$00,$00,$00,$0C,$00,$00,$00
.db $0C,$00,$00,$00,$6C,$00,$00,$00,$38,$00,$00,$00,$00,$00,$00,$00
.db $66,$00,$00,$00,$6C,$00,$00,$00,$78,$00,$00,$00,$70,$00,$00,$00
.db $78,$00,$00,$00,$6C,$00,$00,$00,$66,$00,$00,$00,$00,$00,$00,$00
.db $60,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00
.db $60,$00,$00,$00,$60,$00,$00,$00,$7E,$00,$00,$00,$00,$00,$00,$00
.db $63,$00,$00,$00,$77,$00,$00,$00,$7F,$00,$00,$00,$6B,$00,$00,$00
.db $6B,$00,$00,$00,$63,$00,$00,$00,$63,$00,$00,$00,$00,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$76,$00,$00,$00,$7E,$00,$00,$00
.db $6E,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $7C,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$7C,$00,$00,$00
.db $60,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00
.db $6A,$00,$00,$00,$6C,$00,$00,$00,$36,$00,$00,$00,$00,$00,$00,$00
.db $7C,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$7C,$00,$00,$00
.db $6C,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$00,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$60,$00,$00,$00,$3C,$00,$00,$00
.db $06,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $7E,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$3C,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00
.db $63,$00,$00,$00,$63,$00,$00,$00,$6B,$00,$00,$00,$6B,$00,$00,$00
.db $7F,$00,$00,$00,$77,$00,$00,$00,$63,$00,$00,$00,$00,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$18,$00,$00,$00
.db $3C,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$00,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00
.db $7E,$00,$00,$00,$06,$00,$00,$00,$0C,$00,$00,$00,$18,$00,$00,$00
.db $30,$00,$00,$00,$60,$00,$00,$00,$7E,$00,$00,$00,$00,$00,$00,$00
.db $7C,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00
.db $60,$00,$00,$00,$60,$00,$00,$00,$7C,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$60,$00,$00,$00,$30,$00,$00,$00,$18,$00,$00,$00
.db $0C,$00,$00,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $3E,$00,$00,$00,$06,$00,$00,$00,$06,$00,$00,$00,$06,$00,$00,$00
.db $06,$00,$00,$00,$06,$00,$00,$00,$3E,$00,$00,$00,$00,$00,$00,$00
.db $18,$00,$00,$00,$3C,$00,$00,$00,$66,$00,$00,$00,$42,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$00,$00,$00
.db $1C,$00,$00,$00,$36,$00,$00,$00,$30,$00,$00,$00,$7C,$00,$00,$00
.db $30,$00,$00,$00,$30,$00,$00,$00,$7E,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$3C,$00,$00,$00,$06,$00,$00,$00
.db $3E,$00,$00,$00,$66,$00,$00,$00,$3E,$00,$00,$00,$00,$00,$00,$00
.db $60,$00,$00,$00,$60,$00,$00,$00,$7C,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$7C,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$3C,$00,$00,$00,$66,$00,$00,$00
.db $60,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $06,$00,$00,$00,$06,$00,$00,$00,$3E,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$3E,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$3C,$00,$00,$00,$66,$00,$00,$00
.db $7E,$00,$00,$00,$60,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $1C,$00,$00,$00,$30,$00,$00,$00,$30,$00,$00,$00,$7C,$00,$00,$00
.db $30,$00,$00,$00,$30,$00,$00,$00,$30,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$3E,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$3E,$00,$00,$00,$06,$00,$00,$00,$3C,$00,$00,$00
.db $60,$00,$00,$00,$60,$00,$00,$00,$7C,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$00,$00,$00,$00
.db $18,$00,$00,$00,$00,$00,$00,$00,$38,$00,$00,$00,$18,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $18,$00,$00,$00,$00,$00,$00,$00,$38,$00,$00,$00,$18,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$70,$00,$00,$00
.db $60,$00,$00,$00,$60,$00,$00,$00,$66,$00,$00,$00,$6C,$00,$00,$00
.db $78,$00,$00,$00,$6C,$00,$00,$00,$66,$00,$00,$00,$00,$00,$00,$00
.db $38,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$36,$00,$00,$00,$7F,$00,$00,$00
.db $6B,$00,$00,$00,$6B,$00,$00,$00,$63,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$7C,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$3C,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$7C,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$7C,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$3E,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$3E,$00,$00,$00,$06,$00,$00,$00,$07,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$6C,$00,$00,$00,$76,$00,$00,$00
.db $60,$00,$00,$00,$60,$00,$00,$00,$60,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$3E,$00,$00,$00,$60,$00,$00,$00
.db $3C,$00,$00,$00,$06,$00,$00,$00,$7C,$00,$00,$00,$00,$00,$00,$00
.db $30,$00,$00,$00,$30,$00,$00,$00,$7C,$00,$00,$00,$30,$00,$00,$00
.db $30,$00,$00,$00,$30,$00,$00,$00,$1C,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$66,$00,$00,$00,$3E,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$3C,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$63,$00,$00,$00,$6B,$00,$00,$00
.db $6B,$00,$00,$00,$7F,$00,$00,$00,$36,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$66,$00,$00,$00,$3C,$00,$00,$00
.db $18,$00,$00,$00,$3C,$00,$00,$00,$66,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$66,$00,$00,$00,$66,$00,$00,$00
.db $66,$00,$00,$00,$3E,$00,$00,$00,$06,$00,$00,$00,$3C,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$7E,$00,$00,$00,$0C,$00,$00,$00
.db $18,$00,$00,$00,$30,$00,$00,$00,$7E,$00,$00,$00,$00,$00,$00,$00
.db $0C,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$70,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$0C,$00,$00,$00,$00,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00
.db $30,$00,$00,$00,$18,$00,$00,$00,$18,$00,$00,$00,$0E,$00,$00,$00
.db $18,$00,$00,$00,$18,$00,$00,$00,$30,$00,$00,$00,$00,$00,$00,$00
.db $31,$00,$00,$00,$6B,$00,$00,$00,$46,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
font_data_end:
.ends

