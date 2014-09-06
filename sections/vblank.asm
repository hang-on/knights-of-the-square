.orga $0038
.section "Maskable interrupt handler" force
             ex    af, af'         ; save AF in their shadow register
             in    a, VDPCOM       ; VDP status / satisfy interrupt
             exx                   ; save the rest of the registers

             call  scroller        ; scrolling the background
             call  updScore        ; write the digits
             call  hdlFrame        ; bluelib frame handler
             call  PSGFrame        ; psglib housekeeping
             call  PSGSFXFrame     ; process next SFX frame

             exx                   ; restore the registers
             ex    af, af'         ; also restore AF
             ei                    ; enable interrupts
             reti                  ; return from interrupt
.ends




.section "Update score display" free
;TODO - make this a buffer to be otir'ed every frame...
updScore:
             ld    d, SCORE + 6    ; point to 100.000 digit (dest.)
             ld    ix, score       ; point to score
             ld    a, (ix + 0)     ; get MSB of score
             sub   '0'             ; subtract ASCII zero
             add   a, DIGITS       ; add tile bank index of digits
             ld    e, a            ; put result in E (source)
             call  putTile         ; write the digit tile
             ld    a, (ix + 1)     ; next digit, 10.000
             sub   '0'
             add   a, DIGITS
             inc   d
             ld    e, a
             call  putTile
             ld    a, (ix + 2)     ; next digit, 1.000
             sub   '0'
             add   a, DIGITS
             inc   d
             ld    e, a
             call  putTile
             ld    a, (ix + 3)     ; next digit, 100
             sub   '0'
             add   a, DIGITS
             inc   d
             ld    e, a
             call  putTile
             ld    a, (ix + 4)     ; next digit, 10
             sub   '0'
             add   a, DIGITS
             inc   d
             ld    e, a
             call  putTile
             ld    a, (ix + 5)     ; next digit, 1
             sub   '0'
             add   a, DIGITS
             inc   d
             ld    e, a
             call  putTile
             ret
.ends


.section "Scroller handling" free
scroller:
; Every frame: Check scroller flag to see if screen needs scrolling.

             ld    a, (scrlFlag)   ; read value of scroller flag
             cp    1               ; is it set?
             jp    nz, noScroll    ; if not, skip scrolling

; Scroll the background/tilemap one pixel to the left.

             ld    hl, scrlReg     ; update register value variable
             dec   (hl)            ; scroll left = decrement
             ld    a, (hl)         ; get current value (0-255)
             out   (VDPCOM), a     ; send 1st byte of command word
             ld    a, 8            ; register 8 = horiz. scroll
             or    CMDREG          ; or with write register command
             out   (VDPCOM), a     ; send 2nd byte of command word

; The leftmost 8 pixels on screen hides (fully/partially) one column.
; Check scroll value to see if next column is hidden = ready to fill.

chkClmn:     ld    a, (scrlReg)    ; H. scroll reg. (#8) RAM mirror
             and   %00000111       ; apply fine scroll mask
             cp    0               ; next column completely hidden?
             jp    nz, resFlag     ; if not > skip the following...

; Update the hidden column in the name table (minus status bar!).

             ld    a, (nextClmn)   ; which clmn is currently hidden?
             call  setClmn         ; update it (minus status bar!)
             ld    (nextClmn), a   ; store next hidden column number



; Reset the scroll flag and return.

resFlag:     xor    a              ; clear A
             ld    (scrlFlag), a   ; clear scroll flag

; Finish scroll handler.

noScroll:    ret                   ; return to frame int. handler



; -------------------------------------------------------------------
; LoadColumn
; Fills a column in the name table, top to bottom.
; Source is the NextColumn in ColumnBuffer
; Entry: A = column in name table (0-31 - destination)

 ; A is corrupted along the way!
LoadColumn:

; Shall we load from buffer column 0 or 1?
             push  af
             ld    de, ColumnBuffer
             ld    a, (NextColumn)
             cp    0
             jp    z, +

; we need to add a column to the offset
             ld    h, 0
             ld    l, 48
             add   hl, de
             ex    de, hl

; DE is now pointing to first word to load to column.
; Calculate destination nametable address and store in HL.

+:           pop   af
             ld    h, $38          ; all clmns start somewhere $30xx
             cp    0               ; is destination the first column?
             jp    z, ++           ; if so, then skip to data loading
             ld    b, a            ; loop count: no. of clmns to skip
             ld    a, 0            ; start with offset + 0

-:           add   a, $2           ; add 2 to offset for every clmn
             djnz  -               ; stop looping if we are at dest.

++:          ld    l, a            ; HL = addr. of name table dest.
             ld    b, 24           ; loop count: 24 rows in a column

; Load a word from source DE to name table at address HL.

-:           ld    a, l            ; load destination LSB into L
             out   (VDPCOM), a     ; send it to VDP command port
             ld    a, h            ; load destination MSB into H
             or    CMDWRITE        ; or it with write VRAM command
             out   (VDPCOM), a     ; set result to VDP command port

             ld    a, (de)         ; load source LSB into A
             out   (VDPDATA), a    ; send it to VRAM
             inc   de              ; point DE to MSB of source word
             ld    a, (de)         ; load it into A
             out   (VDPDATA), a    ; and send it to VRAM
             inc   de              ; point DE to LSB of next tile

             push  bc              ; save counter
             ld    bc, $0040       ; step down one row ($40 = 32 * 2)
             add   hl, bc          ; update destination pointer
             pop   bc              ; restore counter

             djnz  -               ; load another word-sized name?

; Update NextColumn

             ld    a, (NextColumn)
             inc   a
             cp    2
             ld    (NextColumn), a
             ret   nz
             xor   a
             ld    (NextColumn), a

             ; TODO:
             ; Load new two new columns of data into the column buffer.
             ; Should be a flag, that is read by the stage module
             ; so update is not taking up vblank time.
             ret





.ends
