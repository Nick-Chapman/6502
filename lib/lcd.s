
lcd_init:
    lda #LCD_FunctionSet_8bit_2lines
    jsr lcd_instruction
    lda #LCD_DisplayOn_CursorOff
    jsr lcd_instruction
    lda #LCD_ClearDisplay
    jsr lcd_instruction
    rts

lcd_wait:
    pha
    ;; set port-B mode to input
    stz DDRB
    ;; RS=0, RW=1, E=1
    lda PORTA
    and #(~RS)
    ora #(RW | E)
    sta PORTA
.loopBusy:
    ;; read busy flag
    lda PORTB
    ;; test busy bit
    and #$80
    bne .loopBusy
    ;; restore port-B mode to output
    lda #$ff
    sta DDRB
    pla
    rts

lcd_instruction: ; A->()
    jsr lcd_wait
    sta PORTB
    lda PORTA
    ;; RS=0. RW=0, E=1
    and #(~(RS | RW))
    ora #E
    sta PORTA
    ;; trigger E neg-edge
    eor #E
    sta PORTA
    rts

lcd_emitChar: ; A->()
    jsr lcd_wait
    sta PORTB
    lda PORTA
    ;; RS=1, RW=0, E=1
    and #(~RW)
    ora #(RS | E)
    sta PORTA
    ;; trigger E neg-edge
    eor #E
    sta PORTA
    rts
