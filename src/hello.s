
PORTB = $6000
PORTA = $6001
DDRB  = $6002
DDRA  = $6003

E  = %10000000 ; enable
RW = %01000000 ; read/write
RS = %00100000 ; register select

LCD_ClearDisplay               = %00000001
LCD_ReturnHome                 = %00000010
LCD_EntryMode_Inc_NoShift      = %00000110
LCD_DisplayOn_CursorOn_NoBlink = %00001110
LCD_DisplayShift_Left          = %00011000
LCD_FunctionSet_8bit_2lines    = %00111000

    org $8000

    include lcd.s

via_init:
    ;; set all pins on port-B as output
    lda #%11111111
    sta DDRB
    ;; set most significant 3 pins on port-A as output
    lda #%11100000
    rts

reset:
    jsr via_init
    jsr lcd_init

    ldx #0
.nextMessageChar:
    lda message, x
    beq .done
    jsr lcd_emitChar
    inx
    jmp .nextMessageChar
.done:

finalHang:
    ;;lda #LCD_DisplayShift_Left
    ;;jsr lcd_instruction
    jmp finalHang

message:
    asciiz "Hello, world!"

    org $fffc
    word reset
    word 0

