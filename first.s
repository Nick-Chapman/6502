
PORTB = $6000
DDRB = $6002

    org $8000

reset:
    ;;ldx #$43
    ;;txs
    lda #%11111111
    sta DDRB
    lda #7
    sec
loop:
    sta $PORTB
    rol
    jmp loop

    org $fffc
    word reset
    word 0
