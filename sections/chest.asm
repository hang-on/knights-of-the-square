.section "Chest handling"
chkChest:    ld    a, (cstMode)    ; get chest mode
             cp    CHESTCL         ; is it closed?
             ret    nz             ; if no closed chest > skip coll.

; Check if Arthur's sword collides with chest.

             ld    hl, wponX       ; point to Arthur's sword (x, y)
             dec   (hl)            ; move center so (x-3, y)
             dec   (hl)            ; ... because sword width < 8 pix
             dec   (hl)            ; ...
             ld    de, cstX        ; point to closed chest (x, y)
             call  clDetect        ; coll. between player and chest?
             ret    nc             ; if no coll. > skip forward

; Open chest (sprite) and change chest mode.

             ld    ix, cstMode     ; point to chest data block
             ld    c, CHESTOP      ; charcode for open chest
             ld    d, (ix + 1)     ; param: chest x pos in D
             ld    e, (ix + 2)     ; param: chest y pos in E
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ld    hl, cstMode     ; point to chest mode
             ld    (hl), CHESTOP   ; update mode to "open"
             ret
.ends