; ELM - enemy life meter section

.define ELM_TILES $53 ; beginning of life meter block

.ramsection "ELM ram" slot 3

ELM_buffer dsb 8

.ends

.section "ELM init" superfree
InitializeELM:



             ret
.ends


.section "ELM loop" superfree

ManageELMLoop:


; clear buffer
             ld    hl, ELM_buffer
             ld    b, 8
-:           ld    (hl), $5b ; red/empty bar
             inc   hl
             djnz  -



DrawELM:

             ld   hl, ELM_buffer
             ld   a, (thug_life)
             bit  7, a
             ret  nz
             ld   b, 9

             cp   b
             jp   c, FinishELM

             ld   (hl), $53
             inc  hl

             ld   b, 17
             cp   b
             jp   c, FinishELM

             ld   (hl), $53
             inc  hl

             ld   b, 25
             cp   b
             jp  c, FinishELM

             ld   (hl), $53
             inc  hl

             ld   b, 33
             cp   b
             jp   c, FinishELM

             ld   (hl), $53
             inc  hl

             ld   b, 41
             cp   b
             jp   c, FinishELM

             ld   (hl), $53
             inc  hl

FinishELM:
             sub  b
             add  a, 9
             ld   b, a
             ld   a, $5b
             sub  b
             ld   (hl), a
             ret

.ends

.section "ELM frame int." superfree
HandleELMFrame:

             ld   ix, ELM_buffer

             ld   d, 34 ;erase ELM
             ld   e, (ix + 0)
             call putTile

             ld   d, 35 ;erase ELM
             ld   e, (ix + 1)
             call putTile

             ld   d, 36 ;erase ELM
             ld   e, (ix + 2)
             call putTile
             ld   d, 37 ;erase ELM
             ld   e, (ix + 3)
             call putTile
             ld   d, 38 ;erase ELM
             ld   e, (ix + 4)
             call putTile
             ld   d, 39 ;erase ELM
             ld   e, (ix + 5)
             call putTile
             ld   d, 40 ;erase ELM
             ld   e, (ix + 6)
             call putTile
             ld   d, 41 ;erase ELM
             ld   e, (ix + 7)
             call putTile

             ret
.ends

