
PORTB = $6000
DDRB = $6002

    org $8000

;;; Example to read and write in zero page memory
    byte 0
    byte 0
    byte 0
reset:

    lda #$42
    sta $1
    nop
    ldx $1

loop:
    jmp loop

    org $fffc
    word reset
    word 0
