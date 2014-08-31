; Scene

; The scroll trigger is a scene attribute!!!
; other objects should read from /query the scene object in order to 
; know if the should scroll....

             ld    hl, plrX        ; the horizontal pos. of player
             ld    a, (hl)         ; read from variable to register
             cp    SCRLTRIG        ; player on the scroll trigger?
             jp    nz, noScrl           ; if not, then no scrolling

; Read from map data to see if the next byte is the terminator ($ff).

             ld    ix, mapData     ; mapData is a 16-bit pointer
             ld    e, (ix + 0)     ; LSB to E
             ld    d, (ix + 1)     ; MSB to D
             ld    a, (de)         ; get next byte from map data block
             cp    $ff             ; is it the terminator?
             jp    z, noScrl            ; if so, then no scrolling

; Scrolling OK. Set the scroll flag to signal to interrupt handler.

             ld    a, 1            ; 1 = flag is set
             ld    (scrlFlag), a   ; set scroller flag

; Scroll thug
             set    SCROLL, a
             ld     (thugFlag), a

; Scroll chest if it is on screen.

             call  scrlCst


             ret                   ; scrolling will happen in int.
