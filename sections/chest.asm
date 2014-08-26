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

; -------------------------------------------------------------------

; Scroll chest if it is on screen.

scrlCst:     ld   a, (cstMode)     ; point to chest mode
             cp   CHESTOFF         ; is chest turned off?
             ret   z               ; if so, skip to column check

             ld   hl, cstX         ; point to chest x pos
             dec  (hl)             ; decrement it
             ld   a, (hl)          ; put value in A for a comparison
             cp   0                ; is chest x = 0 (blanked clmn)?
             jp   nz, +            ; if not, forward to update chest

; Chest has scrolled off screen, so destroy it.

             ld    c, 0            ; reset charcode
             ld    d, 0            ; reset x pos
             ld    e, 0            ; reset y pos
             ld    b, CHESTSAT     ; B = the chest's index in SAT
             call  goSprite        ; update SAT RAM buffer
             ld    hl, cstMode     ; point to chest mode
             ld    (hl), CHESTOFF  ; set chect mode to OFF
             ret             ; forward to check column

; Update chest sprite position.

+:           ld    a, (cstMode)
             ld    c, a            ; chest mode
             ld    d, (hl)         ; D
             inc   hl
             ld    e, (hl)         ; E
             ld    b, CHESTSAT     ; B = Sprite index in SAT
             call  goSprite        ; update SAT buffer (RAM)

             ret ;



.ends