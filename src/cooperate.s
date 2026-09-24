
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

spawn: macro A
    phx
    phy
    jsr \A
    ply
    plx
endmacro

finish: macro
    jmp finish_code
endmacro

finish_code:
    tsx
    cpx BOTTOM
    beq .all_tasks_finished
    rts
.all_tasks_finished:
    lda #'!'
    jsr lcd_emitChar
.spin:
    jmp .spin

yield: macro
    phx
    phy
    jsr yield_code
    ply
    plx
endmacro

yield_code:

    tsx
    ldy BOTTOM

    inx
    iny
    lda $100,x
    sta $100,y

    inx
    iny
    lda $100,x
    sta $100,y

    inx
    iny
    lda $100,x
    sta $100,y

    inx
    iny
    lda $100,x
    sta $100,y

    txs
    sty BOTTOM

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

    lda #'S' ;start
    jsr lcd_emitChar
    spawn taskA
    spawn taskB
    finish

taskA:
    ldx #5 ;; x: 5,4,3,2,1
.loop:
    lda #'a'
    jsr lcd_emitChar
    yield
    dex
    bne .loop
    finish

taskB:
    ldx #1 ;; x: 1,2,3,4,5,6,7,8
.loop:
    lda #'b'
    jsr lcd_emitChar
    yield
    inx
    cpx #8
    bne .loop
    finish
