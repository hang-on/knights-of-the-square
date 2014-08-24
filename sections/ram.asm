; ram module

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