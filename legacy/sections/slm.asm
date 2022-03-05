; SLM - swordman life meter section

.define SLM_TILES $53 ; beginning of life meter block

.ramsection "SLM ram" slot 3

SLM_buffer dsb 7

.ends

.section "SLM init" free
InitializeSLM:



             ret
.ends


.section "SLM loop" free

ManageSLMLoop:


; clear buffer
             ld    hl, SLM_buffer
             ld    b, 5
-:           ld    (hl), $5b ; red/empty bar
             inc   hl
             djnz  -



DrawSLM:

             ld   hl, SLM_buffer
             ld   a, (swordman_life)
             bit  7, a
             ret  nz
             ld   b, 9

             cp   b
             jp   c, FinishSLM

             ld   (hl), $53
             inc  hl

             ld   b, 17
             cp   b
             jp   c, FinishSLM

             ld   (hl), $53
             inc  hl

             ld   b, 25
             cp   b
             jp  c, FinishSLM

             ld   (hl), $53
             inc  hl

             ld   b, 33
             cp   b
             jp   c, FinishSLM

             ld   (hl), $53
             inc  hl

             ld   b, 41
             cp   b
             jp   c, FinishSLM

             ld   (hl), $53
             inc  hl

FinishSLM:
             sub  b
             add  a, 9
             ld   b, a
             ld   a, $5b
             sub  b
             ld   (hl), a
             ret

.ends

.section "SLM frame int." free
HandleSLMFrame:

             ld    a, (swordman_state)
             cp    SWORDMAN_OFF
             jp    z, WipeSLM
             cp    SWORDMAN_DEAD
             jp    z, WipeSLM


             ; put enemy portrait on screen
             ld    hl, $382E
             call  prepVRAM        ; prepare VRAM for writes at HL
             ld    a, 18            ; put tile index in A (param.)
             out   (VDPDATA), a    ; write tile index to name table
             ld    a, $08          ;
             out   (VDPDATA), a    ; tell it to VDP

             ; blast the enemy life meter buffer
             ld    b, 6
             ld    hl, SLM_buffer
-:           ld    a, (hl)
             out   (VDPDATA), a
             ld    a, $01          ;
             out   (VDPDATA), a    ; tell it to VDP
             inc   hl
             djnz  -

             ret

WipeSLM:
             ld    hl, $382E ; !! thug portrait
             call  prepVRAM        ; prepare VRAM for writes at HL

             ld    b, 8
-:           ld    a, $52
             out   (VDPDATA), a
             ld    a, $01
             out   (VDPDATA), a
             djnz  -


             ret

.ends

