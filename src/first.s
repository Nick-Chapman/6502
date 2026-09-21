
PORTB = $6000
DDRB = $6002

    org $8000

reset:
    lda #%11111111
    sta DDRB
    lda #3
    clc
.loop:
    sta $PORTB
    rol
    jmp .loop

    org $fffc
    word reset
    word 0
