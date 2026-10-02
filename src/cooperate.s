
;;; Explore cooperative multi tasking. (step towards pre-emptive)
;;; Main task spawns task1 and task2; task2 later spawns task3
;;; Main task writes "{}"
;;; task1 writes "abcde"
;;; task2 writes "1234"
;;; task3 writes "xx"
;;; Interleaved output is "{a1}bx2cx3d4e"

    org $fffa
    word 0
    word reset
    word 0

    org $8000

    include via.s
    include lcd.s
    include coop.s

    temp0 = 0
    coop_stack_base = 20
    coop_stack_frame = 21

via_init:
    lda #%11111111
    sta via_ddrb
    sta via_ddra
    rts

reset:
    coop_stack_init
    cli

    jsr via_init
    jsr lcd_init
    lda #LCD_ClearDisplay
    jsr lcd_command

    lda #'{'
    jsr lcd_emitChar
    spawn task1
    spawn task2
    lda #'}'
    jsr lcd_emitChar
    finish

task1:
    ldx #5
    lda #'a'
.loop:
    jsr lcd_emitChar
    yield
    inc a
    dex
    bne .loop
    finish

task2:
    ldx #4
    lda #'1'
.loop:
    cpx #3
    bne .nospawn3
    spawn task3
.nospawn3
    jsr lcd_emitChar
    yield
    inc a
    dex
    bne .loop
    finish

task3:
    lda #'x'
    jsr lcd_emitChar
    jsr yield2
    jsr lcd_emitChar
    finish

yield2:
    yield
    rts
