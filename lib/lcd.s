
RS = %00000010 ; register select
RW = %00000100 ; read/write
E  = %00001000 ; enable

;;; switch back to B
RS_PORT = PORTB
RW_PORT = PORTB
ENABLE_PORT = PORTB

LCD_ClearDisplay               = %00000001
LCD_ReturnHome                 = %00000010
LCD_EntryMode_Inc_NoShift      = %00000110
LCD_DisplayOn_CursorOff        = %00001100
LCD_DisplayOn_CursorOn_NoBlink = %00001110
LCD_DisplayShift_Left          = %00011000
LCD_FunctionSet_4bit_2lines    = %00101000

LCD_FunctionSet_4bit           = %00100000
LCD_FunctionSet_8bit           = %00110000

lcd_init:
    ;; An initialization sequence that works whatever state we are in.
    lda #LCD_FunctionSet_8bit
    jsr lcd_half_command
    lda #LCD_FunctionSet_8bit
    jsr lcd_half_command
    lda #LCD_FunctionSet_8bit
    jsr lcd_half_command
    lda #LCD_FunctionSet_4bit
    jsr lcd_half_command

    lda #LCD_FunctionSet_4bit_2lines
    jsr lcd_command

    lda #LCD_DisplayOn_CursorOff
    jsr lcd_command

    lda #LCD_ClearDisplay
    jsr lcd_command

    ;; this is the default entry mode??
    lda #LCD_EntryMode_Inc_NoShift
    jsr lcd_command
    rts

lcd_half_command: ; A->() ;; for use during initialization
    pha
    jsr lcd_wait
    jsr clear_RS
    jsr clear_RW
    pla
    jmp send_nibble

lcd_command: ; A->()
    pha
    jsr lcd_wait
    jsr clear_RS
    jsr clear_RW
    pla
    jmp send_hi_and_lo_nibbles

lcd_emitChar: ; A->()
    pha
    pha
    jsr lcd_wait
    jsr set_RS
    jsr clear_RW
    pla
    jsr send_hi_and_lo_nibbles
    pla
    rts


lcd_wait: ; splats A
    jsr clear_RS
    jsr set_RW
    jsr set_enable
    lda #%00001111 ; temp set read for least-sig for pins of port-B
    sta DDRB
.loop:
    lda PORTB
    and #$80
    bne .loop ; tight loop
    lda #$ff ; revert port-B to all-write
    sta DDRB
    jsr clear_enable
    jsr set_enable
    jsr clear_enable
    rts


send_hi_and_lo_nibbles:
    pha
    and #$f0 ; high-nibble
    jsr send_nibble
    pla
    asl ; low-nibble (shifted to high-nibble position)
    asl
    asl
    asl
    jmp send_nibble


send_nibble: ; A->()
    jsr set_nibble
    jsr set_enable
    jsr clear_enable ;; neg-edge
    rts

TEMP = 0

set_nibble: ; A->()
    and #$f0 ; change high nibble only
    pha
    lda PORTB
    and #$0f ; preserve low nibble
    sta TEMP
    pla
    ora TEMP
    sta PORTB
    rts

set_enable:
    lda ENABLE_PORT
    ora #(E)
    sta ENABLE_PORT
    rts

clear_enable:
    lda ENABLE_PORT
    and #(~(E))
    sta ENABLE_PORT
    rts

set_RS:
    lda RS_PORT
    ora #(RS)
    sta RS_PORT
    rts

clear_RS:
    lda RS_PORT
    and #(~(RS))
    sta RS_PORT
    rts

set_RW:
    lda RW_PORT
    ora #(RW)
    sta RW_PORT
    rts

clear_RW:
    lda RW_PORT
    and #(~(RW))
    sta RW_PORT
    rts
