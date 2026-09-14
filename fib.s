
PORTB = $6000
DDRB = $6002

    org $8000

;;; compute fib, using zero page memory
P = $1
Q = $2

reset:
    lda #%11111111
    sta DDRB
    stz P
    lda #1
    sta Q
loop:
    nop
    lda P
    clc
    adc Q
    tax
    stx PORTB

    lda Q
    sta P
    txa
    sta Q

    jmp loop

    org $fffc
    word reset
    word 0
