/*

Knights of the Square


*/

; --------------------------------------------------------------------

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


; include the bluelib library assumed to be in the same directory:
.INCLUDE "lib\bluelib.inc"

; include psglib for handling sound. Thank you Sverx!
.include "lib\psglib.inc"

; NOTE: Remember to update these values as new tiles are included!!
.define NUMSPR     32              ; # of tiles in sprite bank (1)
.define NUMBG      41              ; # of tiles in bg. bank (2)

; positions in the SAT:
.define PLRSAT     0               ; SAT index of the player sprite
.define WPONSAT    1
.define CHESTSAT   2
.define SOLSAT     3               ; for the soldier
.define SOLWSAT    4               ; and for his little sword

; specific tiles of Arthur:
.define ARTSTAND   $10             ; Arthur standing / idle
.define ARTATTK    $12
.define ARTSWORD   $13

; tiles for the treasure chest (also for chest mode status byte):
.define CHESTCL    $16
.define CHESTOP    $17

; for the chest mode status byte
.define CHESTOFF   $ff

; tiles and mode for the soldier (basic enemy)
.define SOLSTAND   $29             ; standing
.define SOLOFF     $00             ; switched off
.define SOLHURT    $01             ; taking damage
.define SOLDYING   $02             ; dying (collapsing)
.define SOLDEAD    $2d             ; dead

; different states of the player:
.define IDLE       0
.define WALK       1
.define ATTACK     2


; colors
.define YELLOW     $0f
.define ORANGE     $07

; if player x pos. = scroll trigger, then request a screen scroll
.define SCRLTRIG   126

; scoring
.define DIGITS     27              ; tile bank index of digits
.define SCORE      19              ; where to begin the score display


; character mapping for .asc (currently not in use...)
.ASCIITABLE
MAP "A" TO "Z" = 0
MAP "!" = 90
.ENDA


; --------------------------------------------------------------------
.ramsection "Variables" slot 3
plrX         db                    ; horiz. pos. on the screen (0-256)
plrY         db                    ; vert. pos. on the screen (0-192)
plrAnim      db                    ; index of animation script
plrCC        db                    ; character code of player sprite
plrState     db                    ; player's current state
oldState     db                    ; player's previous state
hSpeed       db
vSpeed       db
plrXOld      db
plrYOld      db
plrLife      db                    ; life meter of the player

score:       ds 6                  ; a RAM data block for the score


wponX        db                    ; weapon x,y (for coll. detect)
wponY        db
wponDam      db                    ; damage dealt by the player's weapon

scrlFlag     db                    ; shall we scroll screen at int.?
scrlReg      db                    ; mirror of value in scroll reg.
nextClmn     db                    ; next name tab. clmn to be blanked
mapData      dw                    ; pointer to nxt column of map data
scrlBrk      db                    ; block scrolling

cstMode      db                    ; chest is off, closed or open?
cstX         db                    ; chest x pos
cstY         db                    ; chest y pos

solMode      db                    ; the soldier's mode
solX         db                    ; x pos
solY         db                    ; y pos
solCount     db                    ; counter for dying/hurting
solLife      db                    ; vitality, 0 = start dying

rndSeed      dw                    ; used by goRandom as seed
.ends
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

             ld    hl, $0200       ; start in bank 1, index = 16
             call  prepVRAM        ; tell this to VDP
             ld    hl, fireSPR     ; source data: Sprite tiles
             ld    bc, NUMSPR*32   ; tiles x 32, each tile = 32 bytes
             call  wrteVRAM        ; load tiles into tilebank

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

             xor    a              ; A = 0
             ld    (scrlFlag), a   ; scroll flag = 0
             ld    (scrlReg), a    ; VDP register 8 value = 0
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

; Initialize the soldier and put him on screen.

             ld    ix, solMode     ; point ix to the soldier data
             ld    (ix + 0), SOLSTAND  ; he is standing
             ld    (ix + 1), 82    ; soldier x pos
             ld    (ix + 2), 130   ; soldier y pos
             ld    (ix + 4), 10    ; soldier life meter
             ld    c, SOLSTAND     ; charcode for goSprite
             ld    d, (ix + 1)     ; x-pos for goSprite
             ld    e, (ix + 2)     ; y-pos for goSprite
             ld    b, SOLSAT       ; SAT index for goSprite
             call  goSprite        ; update SAT buffer (RAM)

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
             ld    e, DIGITS  ;    ; "O" is just like zero here
             call  putTile         ; so write O/zero
             inc   d               ; and so on...
             ld    e, DIGITS+12
             call  putTile
             inc   d
             ld    e, DIGITS+13
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

; Store the now expired player state as 'old state'.

gameLoop:    ld    hl, plrState    ; get player state
             ld    a, (hl)         ; put it in A
             inc   hl              ; point to oldState = plrState + 1
             ld    (hl), a         ; save expired state as oldState

; Begin determining current state by checking if player was attacking.

             cp    ATTACK          ; was the player attacking?
             jp    nz, getInput    ; if not, forward to test for input
             ld    a, (plrAnim)    ; else: get current animation cel
             cp    9               ; check if attack has expired
             jp    nz, stAttack    ; if not, continue attack state

; Check if there is a soldier on screen.

chkSol:      ld    a, (solMode)
             cp    SOLSTAND
             jp    nz, chkChest

; Check if Arthur's sword collides with soldier.

             ld    hl, wponX       ; hl = obj1 (x,y) - Arthur's sword
             dec (hl)              ; adjust for smaller sprite
             dec (hl)
             dec (hl)
             ld    de, solX        ; de = obj2 (x,y) - Soldier
             call  clDetect        ; coll. between obj1 and obj2?
             jp    nc, chkChest    ; if no coll. > skip

; Hurt soldier.  (yellow shirt)

             ld    ix, solMode
             ld    (ix + 0), SOLHURT   ; soldier mode
             ld    (ix + 3), 10        ; set soldier counter
            ; deal damage:
             call  goRandom
             and   %00000011  ; random damage = 0 - 3 + weapon
             ld    b, a
             ld    a, (wponDam)
             add   a, b
             ld    b, a
             ld    a, (solLife)
             sub   b
             ld    (solLife), a
             jp    nc, +
             ; switch to dying..
             ld   (ix + 3), 0  ; reset pointer
             ld   (ix + 0), SOLDYING
             jp    resSword


+:
             jp    resSword      ; can't be hitting the chest now...
; ------------

; Check if there is a closed chest on screen.

chkChest:    ld    a, (cstMode)
             cp    CHESTCL
             jp    nz, resSword    ; if no closed chest > skip coll.

; Check if Arthur's sword collides with chest.

             ld    hl, wponX       ; hl = obj1 (x,y) - Arthur's sword
             dec   (hl)            ; because the sword is small...
             dec   (hl)
             dec   (hl)
             ld    de, cstX        ; de = obj2 (x,y) - Closed chest
             call  clDetect        ; coll. between obj1 and obj2?
             jp    nc, resSword    ; if no coll. > skip chest open

; Open chest (sprite) and change chest mode.

             ld    ix, cstMode
             ld    c, CHESTOP      ; open chest
             ld    d, (ix + 1)     ; D
             ld    e, (ix + 2)     ; E
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)
             ld    hl, cstMode
             ld    (hl), CHESTOP
             jp    resSword

; Reset sword sprite.

resSword:    ld    c, 0            ; reset charcode
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

; Check for collision between soldier and player.

coll1:       ld    a, (solMode)    ; get soldier mode
             cp    SOLSTAND           ; is he off/inactive?
             jp    nz, coll2      ; if no active soldier skip...

             ld    hl, plrX        ; point HL to player x,y data
             ld    de, solX        ; point DE to chest x,y
             call  clDetect        ; call the collision detection sub
             jp    nc, coll2     ; if no carry, then no collision

             jp    stopPlr       ; fall through: collision!

; Check for collision between chest and player.

coll2:       ld    a, (cstMode)    ; get chest mode
             cp    CHESTOFF        ; is it off/inactive?
             jp    z, plrWalk      ; if no active chest skip coll.chk

             ld    hl, plrX        ; point HL to player x,y data
             ld    de, cstX        ; point DE to chest x,y
             call  clDetect        ; call the collision detection sub
             jp    nc, plrWalk     ; if no carry, then no collision

; Check if chest is closed or open.

             ld    a, (cstMode)    ; get chest mode
             cp    CHESTCL         ; is it closed?
             jp    z, stopPlr      ; if so, then player cannot pass!

; If chest is open, then pick it up.

             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 0            ; reset y pos
             ld    b, CHESTSAT     ; B = the chest's index in SAT
             call  goSprite        ; update SAT RAM buffer
             ld    hl, cstMode     ; point to chest mode
             ld    (hl), $ff       ; turn it off now

             ld    hl,sfxBonus     ; point to bonus SFX
             ld    c,SFX_CHANNELS2AND3  ; in chan. 2 and 3
             call  PSGSFXPlay      ; play the super retro bonus sound

; Add to player's score.

             ld    hl, score + 3    ; point to the hundreds column
             ld    b,  4            ; one chest is worth 400 points!
             call  goScore          ; call the score updater routine


             jp    plrWalk         ; continue to handle walking

; If chest is closed then block player movement.

stopPlr:     ld    a, (plrXOld)    ; get x-pos from before hSpeed
             ld   (plrX), a        ; revert x-pos to prev. value

             ld    a, (plrYOld)    ; get y-pos from before vSpeed
             ld    (plrY), a       ; revert y-pos to prev. value

             xor   a               ; clear A
             ld    (scrlFlag), a   ; reset scroll flag = don't scroll

; Handle walking animation of player sprite.

plrWalk:     ld    a, (oldState)   ; get old state
             cp    WALK            ; did we walk last time?
             jp    z, +            ; if so, then forward the anim.
             ld    hl, plrAnim     ; else: point to player animation
             ld    (hl), 0         ; and reset it (start from cel 0)

+:           ld    hl, plrAnim     ; param: player's animation
             ld    de, animWalk    ; param: player's anim. script
             call  advcAnim        ; advance plr's walking anim.

             ld    hl, animWalk    ; param: animation script
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

             ld    c, ARTSTAND     ; C = charcode
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
             jp    z, +            ; if so, continue the script
             xor   a               ; else, set A = 0
             ld    (plrAnim), a    ; and start new animation sequence

             ld    c, ARTSWORD     ; C = charcode (param)
             ld    a, (plrX)       ; get player x position
             add   a, 8
             ld    d, a            ; put it in D
             ld    (wponX), a      ; put it in weapon x pos
             ld    a, (plrY)       ; get player y position (param)
             ld    e, a            ; put it in E
             ld    (wponY), a
             ld    b, WPONSAT      ; B = sprite index in SAT
             call  goSprite        ; update SAT RAM buffer

             ld    hl,sfxSword     ; point hl to sword SFX
             ld    c,SFX_CHANNELS2AND3  ; use chan. 2 and 3
             call  PSGSFXPlay      ; play slashing sound


+:           ld    c, ARTATTK      ; C = charcode (param)
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

finLoop:     halt                  ; finish loop by waiting for ints.
             halt                  ; = this game runs at 30 FPS?
             jp    gameLoop        ; then over again...
.ends

.orga $0038
.section "Maskable interrupt handler" force
             ex    af, af'         ; save AF in their shadow register
             in    a, VDPCOM       ; VDP status / satisfy interrupt
             exx                   ; save the rest of the registers

             call  scroller        ; scrolling the background
             call  objects
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

.section "Objects" free
objects:
             ld    a, (solMode)
             cp    SOLHURT
             jp    z, hdlHurt  ; handle hurt
             cp    SOLDYING
             jp    nz, object2
             ; handle dying
             ld       hl, solCount
             ld       de, solDying
             call     advcAnim

             ld    hl, solDying    ; param: animation script
             ld    a, (solCount)    ; param: freshly updated anim.
             call  arrayItm        ; get charcode from anim. script
             ld    c, a            ; put charcode in C (param)
             ld    a, (solX)       ; get player's x position
             ld    d, a            ; put it in D (param)
             ld    a, (solY)       ; get player's y position
             ld    e, a            ; put it in E (param)
             ld    b, SOLSAT       ; B = plr sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ld    a, (solCount)
             cp    20 ; he is lying flat?
             jp    nz, +
             ld    hl, solMode
             ld    (hl), SOLDEAD
; Add to player's score.

             ld    hl, score + 3    ; point to the hundreds column
             ld    b,  2            ; one soldier is worth 200 points!
             call  goScore          ; call the score updater routine


+:


             jp       object2

hdlHurt:     ld    hl, solCount
             ld    a, (hl)
             cp    10 ; new hurt?
             jp    nz, +
             ld         b, C7B2
             ld         c, YELLOW              ; yellow shirt
             call       dfColor   ;
             jp         ++
+:           ; check for end hurt
             cp    0; end hurt?
             jp    nz, ++
             ld         b, C7B2
             ld         c, ORANGE              ; orange shirt
             call       dfColor   ;
             ld    hl, solMode
             ld    (hl), SOLSTAND
             jp   object2

++:          ; just count down..
             dec    (hl)

object2:
             ret

.ends


.section "Update score display" free
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

; Scroll chest if it is on screen.

             ld   a, (cstMode)     ; point to chest mode
             cp   CHESTOFF         ; is chest turned off?
             jp   z, +       ; if so, skip to column check

             ld   hl, cstX         ; point to chest x pos
             dec  (hl)             ; decrement it
             ld   a, (hl)          ; put value in A for a comparison
             cp   0                ; is chest x = 0 (blanked clmn)?
             jp   nz, uptChest     ; if not, forward to update chest

; Chest has scrolled off screen, so destroy it.

             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 0            ; reset y pos
             ld    b, CHESTSAT     ; B = the chest's index in SAT
             call  goSprite        ; update SAT RAM buffer
             ld    hl, cstMode     ; point to chest mode
             ld    (hl), CHESTOFF  ; set chect mode to OFF
             jp    +         ; forward to check column

; Update chest sprite position.

uptChest:    ld    a, (cstMode)
             ld    c, a            ; chest mode
             ld    d, (hl)         ; D
             inc   hl
             ld    e, (hl)         ; E
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

+: ; next test - the soldier...
;**

; Scroll soldier if he is on screen.

             ld   a, (solMode)     ; point to soldier mode
             cp   SOLOFF         ; is soldier turned off?
             jp   z, chkClmn       ; if so, skip to column check

             ld   hl, solX         ; point to soldier x pos
             dec  (hl)             ; decrement it
             ld   a, (hl)          ; put value in A for a comparison
             cp   0                ; is chest x = 0 (blanked clmn)?
             jp   nz, uptSol     ; if not, forward to update chest

; Soldier has scrolled off screen, so destroy him.
debug1:
             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 0            ; reset y pos
             ld    b, SOLSAT     ; B = the chest's index in SAT
             call  goSprite        ; update SAT RAM buffer
             ld    hl, solMode     ; point to chest mode
             ld    (hl), SOLOFF  ; set chect mode to OFF
             jp    chkClmn         ; forward to check column

; Update soldier sprite position.

uptSol:    ld    a, (solMode)
             ld    c, a            ; chest mode
             ld    d, (hl)         ; D
             inc   hl
             ld    e, (hl)         ; E
             ld    b, SOLSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

;**
; The leftmost 8 pixels on screen hides (fully/partially) one column.
; Check scroll value to see if next column is hidden = ready to fill.

chkClmn:     ld    a, (scrlReg)    ; H. scroll reg. (#8) RAM mirror
             and   %00000111       ; apply fine scroll mask
             cp    0               ; next column completely hidden?
             jp    nz, resFlag     ; if not > skip the following...

; Update the hidden column in the name table (minus status bar!).

             ld    a, (nextClmn)   ; which clmn is currently hidden?
             call  setClmn         ; update it (minus status bar!)
             ld    (nextClmn), a   ; store next hidden column number

; Check if there is already an active chest on screen.

             ld    a, (cstMode)    ; get chest mode
             cp    CHESTOFF        ; is the chest currently off?
             jp    nz, resFlag     ; if so, forward to reset flag

; Determine if we should put a new chest on screen.

             call  goRandom        ; random num. 0-127 (or 0-255)?
             sub   20              ; higher number = bigger chance
             jp    po, resFlag     ; if it overflowed, no new chest

; Put a new chest oustide the screen to the right, ready to scroll.

             ld    ix, cstMode     ; point ix to the chest data block
             ld    (ix + 0), CHESTCL  ; set chest mode to closed
             ld    (ix + 1), 255   ; chest x pos
             call  goRandom
             and   %00011111       ; get random number 0-31
             add   a, 115          ; add 115 to get a valid y pos
             ld    (ix + 2), a     ; chest y pos

             ld    c, CHESTCL      ; C = charcode
             ld    d, (ix + 1)     ; chest x
             ld    e, (ix + 2)     ; chest y
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

; Reset the scroll flag and return.

resFlag:     xor    a              ; clear A
             ld    (scrlFlag), a   ; clear scroll flag

; Finish scroll handler.

noScroll:    ret                   ; return to frame int. handler

.ends

.section "Player movement handling" free

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

mvEast:      ld    hl, plrX        ; the horizontal pos. of player
             ld    a, (hl)         ; read from variable to register
             cp    SCRLTRIG        ; player on the scroll trigger?
             jp    nz, +           ; if not, then no scrolling

; Read from map data to see if the next byte is the terminator ($ff).

             ld    ix, mapData     ; mapData is a 16-bit pointer
             ld    e, (ix + 0)     ; LSB to E
             ld    d, (ix + 1)     ; MSB to D
             ld    a, (de)         ; get next byte from map data block
             cp    $ff             ; is it the terminator?
             jp    z, +            ; if so, then no scrolling

; Scrolling OK. Set the scroll flag to signal to interrupt handler.

             ld    a, 1            ; 1 = flag is set
             ld    (scrlFlag), a   ; set scroller flag
             ret                   ; scrolling will happen in int.

; No scrolling. Move sprite one pixel to the right, if within bounds.

+:           ld    a, (hl)         ; get player horiz. position
             cp    248             ; is player on the right bound?
             ret   z               ; ... no straying offscreen!
             ld    a, 1
             ld    (hSpeed), a
             ret

; Move the player one pixel west (left).

mvWest:      ld    hl, plrX
             ld    a, (hl)
             cp    8
             ret   z

             ld    a, -1
             ld    (hSpeed), a
             ret
.ends

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





; -------------------------------------------------------------------
;                            DATA
; -------------------------------------------------------------------

.section "Animation tables" free

; cel array for shifting between legs apart (char $10) and wide ($11)
animWalk:
.db $11 $11 $11 $11 $10 $10 $10 $10 $ff

; cel array for animating the attacking Arthur
animAttk:
.db $10 $12 $12 $12 $12 $12 $12 $12 $12 $10 $10 $ff


solDying:
.db $2b $2b $2b $2b $2b $2b $2b $2b $2b $2b $2c $2c $2c $2c $2c $2c $2c $2c $2c $2c $2d $ff
.ends

.section "Level 1 data: Village on fire (abbrev. 'fire')" free

; Palette data for CRAM banks 1 (backgr.) and 2 (backgr. + sprites):
firePal:
.include "palette\firePal1.inc"
.include "palette\firePal2.inc"

; Sprite tiles in pattern generator bank 1:
fireSPR:
.include "tile\fireSPR.inc"

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