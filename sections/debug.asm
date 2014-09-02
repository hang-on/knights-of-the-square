; Debug Panel

.define FLAG1 2 + 31
.define FLAG2 3 + 31

.define GREEN_FLAG $22
.define YELLOW_FLAG $23

; TODO: Make a black tile in the sprite bank for no flag.

.define NO_FLAG $10


; -------------------------------------------------------------------
.section "Debug Panel" free

InitializeDebugPanel:

             call  _ResetFlag1
             call  _ResetFlag2

             ret

ManageDebugPanelLoop:

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

             ld    d, FLAG1
             call  putTile
             ret

_SetFlag2:

; Entry: E holds the flag color

             ld    d, FLAG2
             call  putTile
             ret

.ends
; -------------------------------------------------------------------