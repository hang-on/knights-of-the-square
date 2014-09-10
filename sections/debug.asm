; Debug Panel


; flag positions on the name table
.define FLAG1 2 + 31
.define FLAG2 3 + 31

; flag tiles
.define GREEN_FLAG $50
.define YELLOW_FLAG $51
.define NO_FLAG $00                ; solid black


; -------------------------------------------------------------------
.section "Debug Panel" free

InitializeDebugPanel:

             call  _ResetFlag1
             call  _ResetFlag2

             ret

ManageDebugPanelLoop:

/*               call  _ResetFlag1

             ld    a, (plrX)
             ld    h, a
             ld    a, (plrY)
             ld    d, a
             ld    b, 8            ; size of player box
             ld    a, (ThugX)
             sub   2
             ld    l, a
             ld    a, (ThugY)
             ld    e, a
             ld    c, 8            ; size of thug box

             call  DetectCollision

             ret   nc

             call  _SetFlag1
*/
             ret

; -------------------------------------------------------------------

_ResetFlag1:

             ld    d, FLAG1
             ld    e, NO_FLAG
             call  putTile
             ret

_ResetFlag2:

             ld    d, FLAG2
             ld    e, NO_FLAG
             call  putTile
             ret

_SetFlag1:

; Entry: E holds the flag color

             ld    e, GREEN_FLAG
             ld    d, FLAG1
             call  putTile
             ret

_SetFlag2:

             ld    e, YELLOW_FLAG
             ld    d, FLAG2
             call  putTile
             ret

.ends
; -------------------------------------------------------------------