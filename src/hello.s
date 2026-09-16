
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

lcd_instruction:
    sta PORTB
    lda #0
    sta PORTA
    lda #E
    sta PORTA
    lda #0
    sta PORTA
    rts

lcd_emitChar:
    sta PORTB
    lda #RS
    sta PORTA
    lda #(RS | E)
    sta PORTA
    lda #RS
    sta PORTA
    rts

reset:
    ;; set all pins on port-B as output
    lda #%11111111
    sta DDRB
    ;; set most significant 3 pins on port-A as output
    lda #%11100000
    sta DDRA

    lda #LCD_FunctionSet_8bit_2lines
    jsr lcd_instruction

    lda #LCD_DisplayOn_CursorOn_NoBlink
    jsr lcd_instruction

    lda #LCD_ReturnHome
    ;;lda #LCD_ClearDisplay
    jsr lcd_instruction

    ldx #0
nextMessageChar:
    lda message, x
    beq done
    jsr lcd_emitChar
    inx
    jmp nextMessageChar
done:

loop:
    ;;lda #LCD_DisplayShift_Left
    ;;jsr lcd_instruction
    jmp loop

message:
    asciiz "Hello, world!"

    org $fffc
    word reset
    word 0

