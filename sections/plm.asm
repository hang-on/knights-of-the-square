; player life meter plm section

.section "PLM frame int." free
HandlePLMFrame:


             ; put Arthur portrait on screen
             ld    hl, $3842
             call  prepVRAM        ; prepare VRAM for writes at HL
             ld    a, 16            ; put tile index in A (param.)
             out   (VDPDATA), a    ; write tile index to name table
             ld    a, $08          ;
             out   (VDPDATA), a    ; tell it to VDP

             ; put fake life meter on screen
             ld    b, 7
-:           ld    a, $53
             out   (VDPDATA), a
             ld    a, $01
             out   (VDPDATA), a
             djnz  -

             ret
.ends