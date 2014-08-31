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


; semi-generic SMS library
.include "lib\bluelib.inc"

; sound handling. Thank you Sverx!
.include "lib\psglib.inc"

; the definitions
.include "sections\define.asm"

; the RAM map
.include "sections\ram.asm"

; VBlank handling
.include "sections\vblank.asm"

; misc. functions
.include "sections\misc.asm"

; chest object handling
.include "sections\chest.asm"

; experimental thug module
.include "sections\thug.asm"


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

; Load graphical assets for level 1: Village on Fire.

             ld    hl, firePal     ; firePal: Lev. 1 palette data
             call  setCRAM         ; define all colors in CRAM

.ifdef PSASSETS
             ld    hl, $0000       ; start in bank 1, index = 00
             call  prepVRAM        ; tell this to VDP
             ld    hl, fireSPR     ; source data: Sprite tiles
             ld    bc, NUMSPR*32   ; tiles x 32, each tile = 32 bytes
             call  wrteVRAM        ; load tiles into tilebank

.else
             ld    hl, $0200       ; start in bank 1, index = 16
             call  prepVRAM        ; tell this to VDP
             ld    hl, fireSPR     ; source data: Sprite tiles
             ld    bc, NUMSPR*32   ; tiles x 32, each tile = 32 bytes
             call  wrteVRAM        ; load tiles into tilebank

.endif

             ld    hl, $2000       ; start at bank 2 (index = 256)
             call  prepVRAM        ; tell this to VDP
             ld    hl, fireBG      ; source data: Background tiles
             ld    bc, NUMBG*32       ; no. of tiles x 32
             call  wrteVRAM        ; load tiles into tilebank

; Initialize random number seed.

             ld    hl, rndSeed     ; point hl to random seed word
             ld    a, r            ; get refresh register
             ld    (hl), a         ; update LSB of seed
             inc   hl              ; point to MSB
             ld    (hl), a         ; update MSB of seed


; Initialize variables for horizontal scrolling.

             ld    de, fireMap     ; start address lev. 1 map data
             ld    hl, mapData     ; current level's map data
             ld    (hl), e         ; transfer LSB of 16-bit pointer
             inc   hl
             ld    (hl), d         ; transfer MSB of 16-bit pointer

; Draw initial name table with column routine.

             ld    b, 32           ; the screen is 32 columns wide
             ld    a, 0            ; start with the first column
-:           push  bc              ; save the counter B
             call  setClmn2        ; load 1 column of names to table
             pop   bc              ; retrieve counter
             djnz  -               ; shall we load another column?

; Fill next scroll column with next level map column.

             ld    a, 0            ; target first column
             call  setClmn2        ; load next column from lev. map
             ld    (nextClmn), a   ; initialize variable

; Put an idle/standing Arthur on the screen.

             ld    a, IDLE         ; get state constant
             ld    (plrState), a   ; init player state to 'idle'
             ld    hl, plrX        ; address of player x position
             ld    (hl), 8         ; load initial x pos. on screen
             inc   hl              ; forward to player y position
             ld    (hl), 119       ; load initial y pos. on screen

; Give him standard sword and life.

             ld    a, 1            ; lv. 1 sword damage modifier = 1
             ld    (wponDam), a    ; put it the variable
             ld    a, 10           ; lv. 1 life meter
             ld    (plrLife), a    ; put it in the variable

; Initialize chest, but don't put it on screen.

             ld    ix, cstMode     ; point ix to the chest data block
             ld    (ix + 0), CHESTOFF
             ld    (ix + 1), 0     ; chest x pos
             ld    (ix + 2), 0     ; chest y pos

             ld    c, 0            ; C = charcode
             ld    d, (ix + 1)
             ld    e, (ix + 2)     ; E
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

; Initialize the thug.

             call  thugInit

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

; Store the now expired player state as 'old state'.

             ld    hl, plrState    ; get player state
             ld    a, (hl)         ; put it in A
             inc   hl              ; point to oldState = plrState + 1
             ld    (hl), a         ; save expired state as oldState

; Begin determining current state by checking if player was attacking.

             cp    ATTACK          ; was the player attacking?
             jp    nz, getInput    ; if not, forward to test for input
             ld    a, (plrAnim)    ; else: get current animation cel
             cp    8               ; is Arthur stabbing (last cel)?
             jp    nz, stAttack    ; if not, continue attack state


; Reset sword sprite.

resSword:
             xor   a
             ld    (wponX), a
             ld    (wponY), a
             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 0            ; reset y pos
             ld    b, WPONSAT      ; B = the weapon's index in SAT
             call  goSprite        ; update SAT RAM buffer
             jp    stIdle          ; switch state to idle

; Read player 1's controller in order to determine current state.

getInput:    call  getPlr1         ; get player 1 input indirectly
             cp    0               ; if no input: plrState = idle
             jp    z, stIdle       ; so jump there
             bit   5, a            ; if btn1: plrState = attacking
             jp    nz, stAttack    ; so jump there
             and   %00001111       ; directional button mask
             jp    nz, stWalk      ; if pressed, then attempt to walk
             jp    stIdle          ; default to idle if no match

; Update current player state to 'walking'.

stWalk:      ld    a, WALK         ; get constant
             ld    (plrState), a   ; set player state to walking

; Respond to directional input (up, down, left and right).

             call  getPlr1         ; get formatted input in A
             rra                   ; rotate 'up bit' into carry
             push  af              ; save input
             call  c, mvNorth      ; if bit is set: Attempt mv. north
             pop   af              ; retrieve input
             rra                   ; carry = down bit
             push  af              ; save input
             call  c, mvSouth      ; if bit is set, then mv. south
             pop   af              ; retrieve input
             rra                   ; carry = left bit
             push  af              ; save input
             call  c, mvWest       ; should we atttempt to go west?
             pop   af              ; retrieve input
             rra                   ; carry = right bit
             call  c, mvEast       ; go east?

; Move player horizontally according to hSpeed.

             ld    a, (hSpeed)     ; get horizontal speed
             ld    b, a            ; store it in B
             ld    a, (plrX)       ; get current x pos of player
             ld    (plrXOld), a    ; save it as old
             add   a, b            ; add speed to current x pos
             ld    (plrX), a       ; and put it into current player x
             xor   a               ; clear A
             ld    (hSpeed), a     ; set speed to zero

; Move player vertically according to vSpeed.

             ld    a, (vSpeed)     ; just like horiz. move...
             ld    b, a
             ld    a, (plrY)
             ld    (plrYOld), a
             add   a, b
             ld    (plrY), a
             xor   a
             ld   (vSpeed), a


; Check for, and handle, collision with chest

             call  collCst

; Handle walking animation of player sprite.

plrWalk:     ld    a, (oldState)   ; get old state
             cp    WALK            ; did we walk last time?
             jp    z, +            ; if so, then forward the anim.
             ld    hl, plrAnim     ; else: point to player animation
             ld    (hl), 0         ; and reset it (start from cel 0)

+:           ld    hl, plrAnim     ; param: player's animation

             ; branch on direction
             ld    a, (plrDir)
             cp    RIGHT
             jp    nz, +
             ld    de, artRight    ; param: player's anim. script
             call  advcAnim        ; advance plr's walking anim.
             ld    hl, artRight    ; param: animation script
             jp    ++
+:
             ld    de, artLeft    ; param: player's anim. script
             call  advcAnim        ; advance plr's walking anim.
             ld    hl, artLeft    ; param: animation script
++:
             ld    a, (plrAnim)    ; param: freshly updated anim.
             call  arrayItm        ; get charcode from anim. script
             ld    c, a            ; put charcode in C (param)
             ld    a, (plrX)       ; get player's x position
             ld    d, a            ; put it in D (param)
             ld    a, (plrY)       ; get player's y position
             ld    e, a            ; put it in E (param)
             ld    b, PLRSAT       ; B = plr sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)
             jp    finLoop         ; finish this game loop pass

; Handle player state = idle.

stIdle:      ld    a, IDLE         ; get constant
             ld    (plrState), a   ; set player state to idle

; Put a standing Arthur on screen.
             ld    a, (plrDir)
             cp    RIGHT
             jp    nz, +
             ld    c, ARTSTAND     ; C = charcode
             jp    ++
+:
             ld    c, ARTSTAND+4     ; C = charcode
++:
             ld    a, (plrX)
             ld    d, a            ; D
             ld    a, (plrY)
             ld    e, a            ; E
             ld    b, PLRSAT       ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)
             jp    finLoop         ; finish this game loop pass

; Handle player state = attacking.

stAttack:    ld    a, ATTACK       ; get constant
             ld    (plrState), a   ; set player state to attacking

             ld    a, (oldState)   ; get old state
             cp    ATTACK          ; where we attacking last time?
             jp    z, attack1      ; if so, continue the script
             xor   a               ; else, set A = 0
             ld    (plrAnim), a    ; and start new animation sequence

             ld    hl,sfxSword     ; point hl to sword SFX
             ld    c,SFX_CHANNELS2AND3  ; use chan. 2 and 3
             call  PSGSFXPlay      ; play slashing sound

             ; branch on direction
             ld    a, (plrDir)
             cp    RIGHT
             jp    nz, +
             ld    c, ARTSWORD     ; C = charcode (param)
             ld    a, (plrX)       ; get player x position
             add   a, 8
             ld    d, a            ; put it in D
             jp    ++
+:
             ld    c, ARTSWORD+4   ; C = charcode (param)
             ld    a, (plrX)       ; get player x position
             sub   8
             ld    d, a            ; put it in D

++:
             ld    (wponX), a      ; put it in weapon x pos
             ld    a, (plrY)       ; get player y position (param)
             ld    e, a            ; put it in E
             ld    (wponY), a
             ld    b, WPONSAT      ; B = sprite index in SAT
             call  goSprite        ; update SAT RAM buffer



attack1:     ld    a, (plrDir)
             cp    RIGHT
             jp    z, +
             add   a, 3
+:
             add   a, 3
             ld    c, a           ; C = charcode (param)
             ld    a, (plrX)       ; get player x position
             ld    d, a            ; put it in D
             ld    a, (plrY)       ; get player y position (param)
             ld    e, a            ; put it in E
             ld    b, PLRSAT       ; B = sprite index in SAT
             call  goSprite        ; update SAT RAM buffer


             ld    hl, plrAnim
             inc   (hl)
             jp    finLoop         ; jump to finish loop


; Finish game loop.

finLoop:
             call  thugLoop        ; update the thug object

             halt                  ; finish loop by waiting for ints.
             halt                  ; = this game runs at 30 FPS?
             jp    gameLoop        ; then over again...
.ends



.orga $0066
.section "Non-Maskable interrupt handler (pause)" force
             retn                  ; disable pause button
.ends


.section "Player movement handling" free

; Stop player.

stopPlr:     ld    a, (plrXOld)    ; get x-pos from before hSpeed
             ld   (plrX), a        ; revert x-pos to prev. value

             ld    a, (plrYOld)    ; get y-pos from before vSpeed
             ld    (plrY), a       ; revert y-pos to prev. value

             xor   a               ; clear A
             ld    (scrlFlag), a   ; reset scroll flag = don't scroll
             scf   ; set carry
             ret


; Move the player one pixel south (down).

mvSouth:     ld    hl, plrY
             ld    a, (hl)
             cp    151
             ret   z
             ld    a, 1
             ld    (vSpeed), a
             ret

; Move the player one pixel north (up).

mvNorth:     ld    hl, plrY
             ld    a, (hl)
             cp    111
             ret   z
             ld    a, -1
             ld    (vSpeed), a
             ret

; Player wants to move east - check if he is at the scroll trigger.

mvEast:      ld   a, RIGHT         ;
             ld   (plrDir), a      ;

             ld    hl, plrX        ; the horizontal pos. of player
             ld    a, (hl)         ; read from variable to register
             cp    SCRLTRIG        ; player on the scroll trigger?
             jp    nz, noScrl           ; if not, then no scrolling

; Read from map data to see if the next byte is the terminator ($ff).

             ld    ix, mapData     ; mapData is a 16-bit pointer
             ld    e, (ix + 0)     ; LSB to E
             ld    d, (ix + 1)     ; MSB to D
             ld    a, (de)         ; get next byte from map data block
             cp    $ff             ; is it the terminator?
             jp    z, noScrl            ; if so, then no scrolling

; Scrolling OK. Set the scroll flag to signal to interrupt handler.

             ld    a, 1            ; 1 = flag is set
             ld    (scrlFlag), a   ; set scroller flag

; Scroll thug
             set    SCROLL, a
             ld     (thugFlag), a

; Scroll chest if it is on screen.

             call  scrlCst


             ret                   ; scrolling will happen in int.

; No scrolling. Move sprite one pixel to the right, if within bounds.
; TODO: bad label name (noScroll already exist, fixit!)
noScrl:      ld    a, (hl)         ; get player horiz. position
             cp    248             ; is player on the right bound?
             ret   z               ; ... no straying offscreen!
             ld    a, 1
             ld    (hSpeed), a
             ret

; Move the player one pixel west (left).

mvWest:      ld   a, LEFT          ;
             ld   (plrDir), a      ;

             ld    hl, plrX
             ld    a, (hl)
             cp    8
             ret   z

             ld    a, -1
             ld    (hSpeed), a
             ret
.ends



; -------------------------------------------------------------------
;                            DATA
; -------------------------------------------------------------------

.section "Animation tables" free

; cel array for shifting between legs apart (char $10) and wide ($11)
artRight:
.redefine C1 ARTSTAND+1
.redefine C2 ARTSTAND
.db C1 C1 C1 C1 C2 C2 C2 C2 $ff

; walking left
artLeft:
.redefine C1 ARTSTAND+5
.redefine C2 ARTSTAND+4
.db C1 C1 C1 C1 C2 C2 C2 C2 $ff


; cel array for animating the attacking Arthur
atkRight:
.redefine C1 ARTSTAND
.redefine C2 ARTSTAND+2
.db C1 C2 C2 C2 C2 C2 C1 $ff

atkLeft:
.redefine C1 ARTSTAND+4
.redefine C2 ARTSTAND+6
.db C1 C2 C2 C2 C2 C2 C1 $ff

; cel array for animating collapsing soldier
solDying:
.redefine C1 SOLSTAND+2
.redefine C2 SOLSTAND+3
.redefine C3 SOLSTAND+4
.db C1 C1 C1 C1 C1 C1 C2 C2 C2 C2 C2 C3 $ff

.ends

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

; Tile map of whole level, organized column-by-column:
fireMap:
.include "tilemap\fireMap.inc"

; sound effect:
sfxSword:
.incbin "sfx\slash.psg"

sfxBonus:
.incbin "sfx\bonus.psg"
.ends