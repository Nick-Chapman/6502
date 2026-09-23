
    org $8000

    include via.s
    include lcd.s

via_init:
    ;; set all pins on port-B and port-A as output
    lda #%11111111
    sta DDRB
    sta DDRA
    lda #%00000000 ; negative edge on any of CA1,CA2,CB1,CB2
    sta PCR
    lda #%10000001 ; enable CA2
    sta IER
    rts

    include hex.s

reset:
    ldx #$ff
    txs
    cli ; enable IRQ
    jsr via_init
    jsr lcd_init
.loop:
    jmp .loop

irq:
    pha
    lda IFR
    ror
    bcs .ca2
    ror
    bcs .ca1
    ;; something else
    lda #'x'
    jsr lcd_emitChar
    jmp .done
.ca1:
    lda #'1'
    jsr lcd_emitChar
    lda #%00000010
    sta IFR
    jmp .done
.ca2:
    lda #'2'
    jsr lcd_emitChar
    lda #%00000001
    sta IFR
    jmp .done
.done:
    pla
    rti

nmi:
    lda #'n'
    jsr lcd_emitChar
    rti

    org $fffa
    word nmi
    word reset
    word irq
