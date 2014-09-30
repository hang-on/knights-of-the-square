; ELM - enemy life meter section

.define ELM_TILES $53 ; beginning of life meter block

.section "ELM loop" superfree

ManageELMLoop:

             ld   a, (thug_life)
             cp   0
             jp   nz, DrawELM
             
             ld   d, 34 ;erase ELM
             ld   e, $52
             call putTile

             ret

DrawELM:     ld   d, 34
             ld   e, ELM_TILES
             call putTile

             ret

.ends

