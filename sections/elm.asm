; ELM - enemy life meter section

.define ELM_TILES $53 ; beginning of life meter block

.section "ELM loop" superfree

ManageELMLoop:
/*

             ld   d, 34 ;erase ELM
             ld   e, $52
             call putTile

             ld   d, 35 ;erase ELM
             ld   e, $52
             call putTile

             ld   d, 36 ;erase ELM
             ld   e, $52
             call putTile
             ld   d, 37 ;erase ELM
             ld   e, $52
             call putTile
             ld   d, 38 ;erase ELM
             ld   e, $52
             call putTile
             ld   d, 39 ;erase ELM
             ld   e, $52
             call putTile


DrawELM:

             ld   a, (thug_life)
             cp   8
             ret  c

             ld   d, 34
             ld   e, ELM_TILES
             call putTile

             ld   a, (thug_life)
             cp   16
             ret   c

             ld   d, 35
             ld   e, ELM_TILES
             call putTile

             ld   a, (thug_life)
             cp   24
             ret  c

             ld   d, 36
             ld   e, ELM_TILES
             call putTile

             ld   a, (thug_life)
             cp   32
             ret  c

             ld   d, 37
             ld   e, ELM_TILES
             call putTile

             ld   a, (thug_life)
             cp   40
             ret  c

             ld   d, 38
             ld   e, ELM_TILES
             call putTile
*/
             ret

.ends

.section "ELM frame int." superfree
HandleELMFrame:

             ld   d, 34 ;erase ELM
             ld   e, $53
             call putTile

             ld   d, 35 ;erase ELM
             ld   e, $53
             call putTile

             ld   d, 36 ;erase ELM
             ld   e, $53
             call putTile
             ld   d, 37 ;erase ELM
             ld   e, $53
             call putTile
             ld   d, 38 ;erase ELM
             ld   e, $53
             call putTile
             ld   d, 39 ;erase ELM
             ld   e, $55
             call putTile

             ret
.ends

