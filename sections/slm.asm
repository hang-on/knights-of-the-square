; swordman life meter slm section

.section "Swordman life meter frame int." free
HandleSLMFrame:


             ; put swordman portrait on screen
             ld    hl, $382e
             call  prepVRAM        ; prepare VRAM for writes at HL
             ld    a, 18            ; put tile index in A (param.)
             out   (VDPDATA), a    ; write tile index to name table
             ld    a, $08          ;
             out   (VDPDATA), a    ; tell it to VDP

             ; put fake life meter on screen
             ld    b, 6
-:           ld    a, $53
             out   (VDPDATA), a
             ld    a, $01
             out   (VDPDATA), a
             djnz  -

             ret
.ends