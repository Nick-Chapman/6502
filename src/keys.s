;;; first steps to read keyboard...

    org $fffa
    word nmi
    word reset
    word irq

    org $8000

    include via.s
    include lcd.s
    include hex.s

    count = 20
    scancode = 22
    res = 24

via_init:
    lda #$fe ; all outputs -- except least sig INPUT, borrowed for keyboard PS/2 data
    sta DDRB

    ;lda #3 ; latching
    lda #0 ; no latching
    sta ACR

    lda #0
    sta PCR ; active edge negative

    lda #%10010000 ; enable CB1
    sta IER

    rts

reset:
    ldx #$ff
    txs
    cli
    stz scancode
    stz scancode+1
    stz count
    stz count+1
    jsr via_init
    jsr lcd_init
    lda #LCD_ClearDisplay
    jsr lcd_command
.loop:
    lda #LCD_ReturnHome
    jsr lcd_command

    lda count+1
    jsr display_hex_byte
    lda count
    jsr display_hex_byte

    lda #' '
    jsr lcd_emitChar

    lda scancode+1
    jsr display_hex_byte
    lda scancode
    jsr display_hex_byte

    lda scancode+1
    sta res
    lda scancode
    rol
    rol res
    rol
    rol res

    lda #' '
    jsr lcd_emitChar

    lda res
    jsr display_hex_byte

    jmp .loop

irq:
    pha
    clc
    lda PORTB ; ack; read data bit
    and #1
    beq .rotate
.data1:
    sec
.rotate:
    ror scancode+1
    ror scancode ;; TODO: check order bits come in. might be rol is needed
    ;;rol ;; back one pos to loose the stop bit
    inc count
    bne .done
    inc count+1
.done:
    pla
    rti

nmi:
    rti
