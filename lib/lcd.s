
LCD_ClearDisplay               = %00000001
LCD_ReturnHome                 = %00000010
LCD_EntryMode_Inc_NoShift      = %00000110
LCD_DisplayOn_CursorOff        = %00001100
LCD_DisplayOn_CursorOn_NoBlink = %00001110
LCD_DisplayShift_Left          = %00011000
LCD_FunctionSet_8bit_2lines    = %00111000
LCD_FunctionSet_4bit_2lines    = %00101000

lcd_init:
    ;; (from 8 bit mode) function set: 4 bit
    jsr lcd_wait
    lda #%00100000
    jsr send_nibble_COMMAND

    lda #LCD_FunctionSet_4bit_2lines
    jsr lcd_command

    lda #LCD_DisplayOn_CursorOff
    jsr lcd_command

    ;; this is the default entry mode??
    lda #LCD_EntryMode_Inc_NoShift
    jsr lcd_command
    rts


lcd_wait:
    pha ; save caller's A

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

    pla ;; restore caller's A
    rts


lcd_command: ; A->()
    jsr lcd_wait
    pha
    and #$f0 ; high-nibble
    jsr send_nibble_COMMAND
    pla
    asl ; low-nibble (shifted to high-nibble position)
    asl
    asl
    asl
    jsr send_nibble_COMMAND
    rts


lcd_emitChar: ; A->()
    jsr lcd_wait
    pha
    and #$f0 ; high-nibble
    jsr send_nibble_DATA
    pla
    asl ; low-nibble (shifted to high-nibble position)
    asl
    asl
    asl
    jsr send_nibble_DATA
    rts


send_nibble_DATA: ; A->()
    jsr set_nibble
    jsr set_RS
    jsr clear_RW
    jsr set_enable
    jsr clear_enable ;; neg-edge
    rts

send_nibble_COMMAND: ; A->()
    jsr set_nibble
    jsr clear_RS
    jsr clear_RW
    jsr set_enable
    jsr clear_enable ;; neg-edge
    rts

TEMP = 0

set_nibble: ; A->()
    and #%11110000
    pha

    lda PORTB
    and #%00001111
    sta TEMP

    pla
    ora TEMP
    sta PORTB
    rts


;; toggle_enable:
;;     lda ENABLE_PORT
;;     eor #(E)
;;     sta ENABLE_PORT
;;     rts

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
