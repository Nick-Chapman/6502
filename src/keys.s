
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
    seen_release = 25
    upper_case = 26

init_globals:
    stz count
    stz incoming
    stz ready_scanCode
    stz scancode
    stz screen_offset
    stz seen_release
    stz upper_case
    rts

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

lower:   ; 0123456789abcdef
    ascii "                " ;0
    ascii "     q1   zsaw2 " ;1
    ascii "`cxde43   vftr5 " ;2
    ascii " nbhgy6   mju78 " ;3
    ascii " ,kio09  ./l;p- " ;4
    ascii "  ' [=     ] #  " ;5
    ascii " \              " ;6
    ascii "                " ;7

upper:
    ascii "                " ;0
    ascii "     Q!   ZSAW@ " ;1
    ascii "~CXDE$#   VFTR% " ;2
    ascii " NBHGY^   MJU&* " ;3
    ascii " <KIO)(  >?L:P_ " ;4
    ascii "  @ {+     } ~  " ;5
    ascii " |              " ;6
    ascii "                " ;7

display_scancode: ;A-> (uses X)
    pha
    lda seen_release
    beq .not_release
    dec seen_release
    pla ; scancode
    cmp #$12
    beq .release_shift
    cmp #$59
    beq .release_shift
    ; ignore any other release
    rts
.release_shift:
    stz upper_case
    rts
.not_release:
    pla ;scancode
    cmp #$f0
    beq .release
    cmp #$12
    beq .shift
    cmp #$59
    beq .shift
    cmp #$29
    beq .space
    tax ;scancode
    bmi .unknown ; >$7f
    lda upper_case
    bne .read_upper
    jmp .read_lower
.release:
    inc seen_release
    jmp .done
.shift:
    lda upper_case
    beq .shift_to_upper
    ; already upper case; no change
    jmp .done
.shift_to_upper:
    inc upper_case
    jmp .done
.read_lower:
    lda lower,x
    jmp .after_read
.read_upper:
    lda upper,x
    jmp .after_read
.after_read:
    cmp #' '
    beq .unknown
    jmp .ascii
.unknown:
    lda #'{'
    jsr screen_putChar
    txa ;scancode
    jsr screen_hex_byte
    lda #'}'
    jsr screen_putChar
    jmp .done
.space:
    lda #' '
.ascii:
    jsr screen_putChar
.done:
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
    lda scancode
    jsr display_scancode
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
