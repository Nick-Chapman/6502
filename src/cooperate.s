
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

    lda #'s' ;start
    jsr lcd_emitChar
    jsr taskA ; spawn
    jsr taskB ; spawn
    rts

taskA:
    lda #'x'
    jsr lcd_emitChar
    jsr yield
    lda #'y'
    jsr lcd_emitChar
    jsr yield
    lda #'z'
    jsr lcd_emitChar
    jsr finish

taskB:
    lda #'1'
    jsr lcd_emitChar
    jsr yield
    lda #'2'
    jsr lcd_emitChar
    jsr finish

;;;TODO change finish so we jump to it. do it macro
finish: ;; basically like rts, but checks for when all tasks are done
    tsx
    inx
    inx
    cpx BOTTOM
    beq all_tasks_finished
    txs
    rts

all_tasks_finished:
    lda #'!'
    jsr lcd_emitChar
.spin:
    jmp .spin

yield: ;; MACRO for this
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
    txs
    sty BOTTOM
    rts
