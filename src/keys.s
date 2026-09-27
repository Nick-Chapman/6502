
    org $fffa
    word nmi
    word reset
    word irq

    org $8000

    include via.s
    include lcd.s
    ;include hex.s ;; NOP, use screen routines here instead


    count = 20
    incoming = 21
    ready_scanCode = 22
    scancode = 23
    screen_offset = 24
    ignore_following_release = 25

init_globals:
    stz count
    stz incoming
    stz ready_scanCode
    stz scancode
    stz screen_offset
    stz ignore_following_release
    rts

screen_putChar: ; wrap around a single line; TODO better
    pha
    lda screen_offset
    and #$1f
    beq .cls
    jmp .char
.cls:
    lda #LCD_ClearDisplay
    jsr lcd_command
    jmp .char
    jmp .char
.char:
    pla
    jsr lcd_emitChar
    inc screen_offset

    lda screen_offset
    and #$f
    bne .done
    phx
    ;; position to the start of the next line by emiting 24 off screen chars
    ;; TODO use positionig commands
    ldx #24
.loop:
    lda #'*'
    jsr lcd_emitChar
    dex
    bne .loop
    plx
.done:
    rts

emit24:
    rts

screen_hex_nibble: ; copy/mod from hex.s
    phx
    tax
    lda .hex_chars, x
    jsr screen_putChar
    plx
    rts
.hex_chars:
    ascii "0123456789abcdef"

screen_hex_byte: ; copy/mod from hex.s
    pha
    lsr
    lsr
    lsr
    lsr
    jsr screen_hex_nibble
    pla
    and #$f
    jsr screen_hex_nibble
    rts

table:   ; 0123456789abcdef
    ascii "                " ;0
    ascii "     q1   zsaw2 " ;1
    ascii " cxde43   vftr5 " ;2
    ascii " nbhgy6   mju78 " ;3
    ascii " ,kio09  ./l;p- " ;4
    ascii "  ' [=     ] #  " ;5
    ascii " \              " ;6
    ascii "                " ;7
    ascii "                " ;8
    ascii "                " ;9
    ascii "                " ;a
    ascii "                " ;b
    ascii "                " ;c
    ascii "                " ;d
    ascii "                " ;e
    ascii "                " ;f

display_scanCore:   ;; global
    lda ignore_following_release
    beq .dont_ignore
    dec ignore_following_release
    rts
.dont_ignore:

    ldx scancode

    cpx #$f0
    beq .release
    cpx #$29
    beq .space

    lda table,x
    cmp #' '
    beq .unknown
    jmp .ascii
.release:
    inc ignore_following_release
    rts
.unknown:
    phx
    lda #'{'
    jsr screen_putChar
    pla
    jsr screen_hex_byte
    lda #'}'
    jsr screen_putChar
    rts
.space:
    lda #' '
.ascii:
    jmp screen_putChar ; tail

via_init:
    lda #$fe ; all outputs -- except least sig INPUT, borrowed for keyboard PS/2 data
    sta DDRB
    lda #0 ; no latching
    sta ACR
    lda #0
    sta PCR ; active edge negative
    lda #%10010000 ; enable CB1
    sta IER
    rts

reset:
    ldx #$ff
    txs
    cli
    jsr init_globals
    jsr via_init
    jsr lcd_init
.loop:
    lda ready_scanCode
    beq .loop
    stz ready_scanCode
    jsr display_scanCore
    Jmp .loop

irq:
    pha
    clc
    lda PORTB ; ack; read data bit
    and #1
    beq .rotate
.data1:
    sec
.rotate:
    ror incoming
    inc count

    lda count
    cmp #9
    beq .nine
    cmp #11
    beq .eleven
    jmp .done

.nine:
    lda incoming
    sta scancode
    inc ready_scanCode
    jmp .done

.eleven:
    stz count
    stz incoming
    jmp .done

.done:
    pla
    rti

nmi:
    rti
