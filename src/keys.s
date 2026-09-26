;;; first steps to read keyboard...

    org $fffa
    word nmi
    word reset
    word irq

    org $8000

    include via.s
    include lcd.s
    include hex.s

    COUNT = 20

via_init:
    lda #%11111111
    sta DDRB
    ;;sta DDRA
    lda #%10000001 ; enable CA2
    sta IER
    rts

nmi:
    rti

irq:
    bit PORTA ; ack
    inc COUNT
    bne .done
    inc COUNT+1
.done:
    rti

reset:
    ldx #$ff
    txs
    cli

    stz COUNT+1
    stz COUNT

    jsr via_init
    jsr lcd_init

    lda #LCD_ClearDisplay
    jsr lcd_command

.loop:
    lda #LCD_ReturnHome
    jsr lcd_command
    lda COUNT+1
    jsr display_hex_byte
    lda COUNT
    jsr display_hex_byte
    jmp .loop
