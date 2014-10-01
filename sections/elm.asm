; ELM - enemy life meter section

.define ELM_TILES $53 ; beginning of life meter block

.ramsection "ELM ram" slot 3

ELM_buffer dsb 7

.ends

.section "ELM init" superfree
InitializeELM:



             ret
.ends


.section "ELM loop" superfree

ManageELMLoop:


; clear buffer
             ld    hl, ELM_buffer
             ld    b, 5
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


             ; put enemy portrait on screen
             ld    hl, $386E
             call  prepVRAM        ; prepare VRAM for writes at HL
             ld    a, 17            ; put tile index in A (param.)
             out   (VDPDATA), a    ; write tile index to name table
             ld    a, $08          ;
             out   (VDPDATA), a    ; tell it to VDP


             ld   ix, ELM_buffer

             ld   d, 56
             ld   e, (ix + 0)
             call putTile

             ld   d, 57
             ld   e, (ix + 1)
             call putTile

             ld   d, 58
             ld   e, (ix + 2)
             call putTile
             ld   d, 59
             ld   e, (ix + 3)
             call putTile
             ld   d, 60
             ld   e, (ix + 4)
             call putTile
             ld   d, 61
             ld   e, (ix + 5)
             call putTile
             ld   d, 62
             ld   e, (ix + 6)
             call putTile

             ret
.ends

