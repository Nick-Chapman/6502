
;;; explore cooperative multi tasking. (step towards pre-emptive)

    org $fffa
    word 0
    word reset
    word 0

    org $8000

    include via.s
    include lcd.s
    include hex.s ;; TODO, not needed
    include coop.s

    coop_stack_bottom = 20

via_init:
    lda #%11111111
    sta via_ddrb
    sta via_ddra
    rts

reset:
    cli
    ldx #$ff
    txs
    stx coop_stack_bottom

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
    yield
    jsr lcd_emitChar
    finish
