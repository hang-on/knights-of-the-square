; Definitions

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

; different directions:
.define RIGHT      0
.define LEFT       1

; colors
.define YELLOW     $0f
.define ORANGE     $07

; if player x pos. = scroll trigger, then request a screen scroll
.define SCRLTRIG   126

; scoring
.define DIGITS     27              ; tile bank index of digits
.define SCORE      19              ; where to begin the score display

