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

             ld    a, (thug_state)
             cp    THUG_OFF
             jp    z, WipeELM
             cp    THUG_DEAD
             jp    z, WipeELM


             ; put enemy portrait on screen
             ld    hl, $386E
             call  prepVRAM        ; prepare VRAM for writes at HL
             ld    a, 17            ; put tile index in A (param.)
             out   (VDPDATA), a    ; write tile index to name table
             ld    a, $08          ;
             out   (VDPDATA), a    ; tell it to VDP

             ; blast the enemy life meter buffer
             ld    b, 6
             ld    hl, ELM_buffer
-:           ld    a, (hl)
             out   (VDPDATA), a
             ld    a, $01          ;
             out   (VDPDATA), a    ; tell it to VDP
             inc   hl
             djnz  -

             ret

WipeELM:
             ld    hl, $386E ; thug portrait
             call  prepVRAM        ; prepare VRAM for writes at HL

             ld    b, 8
-:           ld    a, $52
             out   (VDPDATA), a
             ld    a, $01
             out   (VDPDATA), a
             djnz  -


             ret

.ends

