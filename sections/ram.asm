; Ram module.
; All variables default to 0, because ram is cleared by bluelib.
; --------------------------------------------------------------------
.ramsection "Variables" slot 3
score:       ds 6                  ; a RAM data block for the score


cstMode      db                    ; chest is off, closed or open?
cstX         db                    ; chest x pos
cstY         db                    ; chest y pos

rndSeed      dw                    ; used by goRandom as seed
.ends