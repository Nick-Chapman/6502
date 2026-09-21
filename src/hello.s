
    org $8000

    include via.s
    include lcd.s

reset:
    jsr via_init
    jsr lcd_init

    lda #LCD_ReturnHome
    jsr lcd_command

    ldx #0
.nextMessageChar:
    lda message, x
    beq .done
    jsr lcd_emitChar
    inx
    jmp .nextMessageChar
.done:

finalHang:
    jmp finalHang

message:
    asciiz "Hello, world!"

    org $fffc
    word reset
    word 0

