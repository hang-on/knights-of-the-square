; 
.section "Animations: Data" free 
  ; ---------------------------------------------------------------------------
  ; Layouts
  ; ---------------------------------------------------------------------------

    layout_2x5_3x3:
    .db -56, -12     
    .db -56, -4      ; XX
    .db -48, -12     ; XX
    .db -48, -4      ; XX
    .db -40, -12     ; XX
    .db -40, -4      ; XX
    .db -32, -12     ; XXX
    .db -32, -4      ; XXX 
    .db -24, -12
    .db -24, -4
    .db -16, -12
    .db -16, -4
    .db -16, 4
    .db -8, -12
    .db -8, -4
    .db -8, 4
  
  layout_2x4:
    ; Y and X offsets to apply to the origin of an actor.
    .db -32, -8     ; XX
    .db -32, 0      ; XX
    .db -24, -8     ; XX
    .db -24, 0      ; XX
    .db -16, -8
    .db -16, 0
    .db -8, -8
    .db -8, 0

  layout_2x3_1b:
    .db -24, -8     ; XX
    .db -24, 0      ; XX
    .db -16, -8     ; XXX
    .db -16, 0
    .db -8, -8
    .db -8, 0
    .db -8, 8

  layout_1t_3x4:
    .db -40, -12     ; X
    .db -32, -12     ; XXX
    .db -32, -4      ; XXX
    .db -32, 4       ; XXX
    .db -24, -12     ; XXX
    .db -24, -4
    .db -24, 4
    .db -16, -12
    .db -16, -4
    .db -16, 4
    .db -8, -12
    .db -8, -4
    .db -8, 4

  layout_2t_3x4:
    .db -48, -12     ; X
    .db -40, -12     ; X
    .db -32, -12     ; XXX
    .db -32, -4      ; XXX
    .db -32, 4       ; XXX
    .db -24, -12     ; XXX
    .db -24, -4
    .db -24, 4
    .db -16, -12
    .db -16, -4
    .db -16, 4
    .db -8, -12
    .db -8, -4
    .db -8, 4

  layout_2m_3x4:
    .db -48, -4      ;  X
    .db -40, -4      ;  X
    .db -32, -12     ; XXX
    .db -32, -4      ; XXX
    .db -32, 4       ; XXX
    .db -24, -12     ; XXX
    .db -24, -4
    .db -24, 4
    .db -16, -12
    .db -16, -4
    .db -16, 4
    .db -8, -12
    .db -8, -4
    .db -8, 4

.ends
