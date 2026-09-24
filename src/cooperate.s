
;;; explore cooperative multi tasking. (step towards pre-emptive)

    org $fffa
    word 0
    word reset
    word 0

    org $8000

    include via.s
    include lcd.s
    include hex.s

    BOTTOM = 20

SAVE: macro
    pha
    phx
    phy
endmacro

RESTORE: macro
    ply
    plx
    pla
endmacro

spawn: macro A
    jsr .here\@
    jmp .after\@
.here\@:
    SAVE
    jmp \A
.after\@:
endmacro

finish: macro
    jmp finish_code
endmacro

finish_code:
    tsx
    cpx BOTTOM
    beq .all_tasks_finished
    RESTORE
    rts
.all_tasks_finished:
    lda #'!'
    jsr lcd_emitChar
.spin:
    jmp .spin

yield: macro
    jsr yield_code
endmacro

bury: macro
    pla
    iny
    sta $100,y
endmacro

yield_code:
    SAVE
    ldy BOTTOM
    bury ;y
    bury ;x
    bury ;a
    bury ;ret/1
    bury ;ret/2
    sty BOTTOM
    RESTORE
    rts

via_init:
    lda #%11111111
    sta DDRB
    sta DDRA
    rts

reset:
    cli
    ldx #$ff
    txs
    stx BOTTOM

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
