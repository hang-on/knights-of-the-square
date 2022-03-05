; -----------------------------------------------------------------------------
; HARDWARE DEFINITIONS
; Assumes hardware is initialized to default values
; -----------------------------------------------------------------------------
; Video (VDP)
.equ SAT_Y_START $3f00
.equ SAT_XC_START SAT_Y_START+64+64
.equ SPRITE_TERMINATOR $d0
.equ HARDWARE_SPRITES 64
;
.equ NAME_TABLE_START $3800
.equ VISIBLE_NAME_TABLE_SIZE 2*32*24
.equ FULL_NAME_TABLE_SIZE 2*32*28
.equ SPRITE_BANK_START $0000
.equ BACKGROUND_BANK_START $2000
.equ CHARACTER_SIZE 32
.equ START_OF_UNUSED_SAT_AREA $3f40
;
.equ FIRST_LINE_OF_VBLANK 192
.equ INTERRUPT_TYPE_BIT 7
;
.equ V_COUNTER_PORT $7e
.equ CONTROL_PORT $BF
.equ DATA_PORT $BE
.equ VRAM_WRITE_COMMAND %01000000
.equ VRAM_READ_COMMAND %00000000
.equ REGISTER_WRITE_COMMAND %10000000
.equ CRAM_WRITE_COMMAND %11000000
.equ VRAM_SIZE $4000                  ; 16K
;
.equ HORIZONTAL_SCROLL_REGISTER 8
.equ VERTICAL_SCROLL_REGISTER 9
.equ RASTER_INTERRUPT_REGISTER 10
; 
.equ CRT_LEFT_BORDER 0
.equ CRT_RIGHT_BORDER 255
.equ CRT_TOP_BORDER 0
.equ CRT_BOTTOM_BORDER 191
;
.equ INVISIBLE_AREA_TOP_BORDER 192
.equ INVISIBLE_AREA_BOTTOM_BORDER 224
; -----------------------------------------------------------------------------
; Sound (PSG)
.equ PSG_PORT $7f
; -----------------------------------------------------------------------------
; Control
.equ INPUT_PORT_1 $dc
.equ INPUT_PORT_2 $dd
; -----------------------------------------------------------------------------
; Memory
.equ RAM_START $c000
.equ SET_EXTRAM_BIT %00001000
.equ RESET_EXTRAM_BIT %11110111
.equ EXTRAM_START $8000
.equ EXTRAM_SIZE $4000
.equ SLOT_2_CONTROL $ffff
.equ BANK_CONTROL $fffc

