
lcd_init:
    sta DDRA
    lda #LCD_FunctionSet_8bit_2lines
    jsr lcd_instruction
    lda #LCD_DisplayOn_CursorOn_NoBlink
    jsr lcd_instruction
    ;;lda #LCD_ReturnHome
    lda #LCD_ClearDisplay
    jsr lcd_instruction

lcd_wait:
    pha
.loop:
    ;; set port-B mode to input
    stz DDRB
    ;; read busy flag
    lda #RW
    sta PORTA
    lda #(RW | E)
    sta PORTA
    lda PORTB
    ;; test busy bit
    and #$80
    bne .loop
    lda #RW
    sta PORTA
    ;; restore port-B mode to output
    lda #$ff
    sta DDRB
    pla
    rts

lcd_instruction:
    jsr lcd_wait
    sta PORTB
    lda #0
    sta PORTA
    lda #E
    sta PORTA
    lda #0
    sta PORTA
    rts

lcd_emitChar:
    jsr lcd_wait
    sta PORTB
    lda #RS
    sta PORTA
    lda #(RS | E)
    sta PORTA
    lda #RS
    sta PORTA
    rts
