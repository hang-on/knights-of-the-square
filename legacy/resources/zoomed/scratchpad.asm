; Scratchpad - leftovers and misc. bits and pieces.



; -------------------------------------------------------------------
; LoadColumn
; Fills a column in the name table, top to bottom.
; Source is the NextColumn in ColumnBuffer
; Entry: A = column in name table (0-31 - destination)
; WARNING: Operates directly on the VDP! Call it only when
;    1) Screen is turned of (with VDP register)
;    2) Screen is blanked during frame interrupt

; NOTE: Became obsolete when meta tile updating was optimized from
; being a whole column to just 2 tiles.
; The 'meta tile band' update. 

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

             call  PutMetaTileInColumnBuffer
             ; TODO:
             ; Load new two new columns of data into the column buffer.
             ; Should be a flag, that is read by the stage module
             ; so update is not taking up vblank time.


             ret

InitializeColumnBuffer:

             ; fill the buffer with dummy stuff
             ld    de, ColumnBuffer
             ld    hl, ColumnDummyFill
             ld    bc,  24*2*2
             ldir

             ret

PutMetaTileInColumnBuffer:

             ; the next meta tile

             ld    hl, MetaTileScript
             ld    a, (MetaTileScriptIndex)
             call  arrayItm ; now we got the item in A


             ; adjust tile offset
             xor   b
             cp    8
             jp    c, +
             ld    b, 16
+:           add   a, a
             add   a, b

             ; put four tiles in the buffer
             ld    (ColumnBuffer + 16), a
             inc   a
             ld    (ColumnBuffer + 16 + 48), a
             add   a, 16
             ld    (ColumnBuffer + 18 + 48), a
             dec   a
             ld    (ColumnBuffer + 18), a

             ld    hl, MetaTileScriptIndex
             inc   (hl)

             ret
