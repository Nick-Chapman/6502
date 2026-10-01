
    org $fffa
    word nmi
    word reset
    word irq

    org $8000

    include via.s
    include lcd.s

    error_start_bit = 19
    count = 20
    incoming = 21
    ready_scanCode = 22
    scancode = 23
    screen_insert_offset = 24
    screen_display_offset = 25
    seen_release = 26
    upper_case = 27

init_globals:
    stz error_start_bit
    stz count
    stz incoming
    stz ready_scanCode
    stz scancode
    stz screen_insert_offset
    stz screen_display_offset
    stz seen_release
    stz upper_case
    rts

via_init:
    lda #$fe ; all outputs -- except least sig INPUT, borrowed for keyboard PS/2 data
    sta DDRB
    lda #0 ; no latching, timer2 one-shot mode
    sta ACR
    lda #0
    sta PCR ; active edge negative
    lda #(via_ier_enable | via_ca1) ;; | via_timer2)
    sta IER
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

screen_buffer = $200 ; 256 bytes

screen_init:
    ldx #0
    lda #' '
.loop:
    dex
    sta screen_buffer,x
    bne .loop
    rts

screen_refresh:
    pha
    phx
    phy
    lda #LCD_ReturnHome
    jsr lcd_command

    ldx screen_display_offset
    ldy #16
.line1:
    lda screen_buffer,x
    jsr lcd_emitChar
    inx
    dey
    bne .line1

    lda #LCD_SetAddressStartLineTwo
    jsr lcd_command
    ldy #16
.line2:
    lda screen_buffer,x
    jsr lcd_emitChar
    inx
    dey
    bne .line2

    lda screen_insert_offset
    cmp screen_display_offset
    bmi .done ;; insert-offset is outside/above display portal
    ;; insert point is below start of display
    sec
    lda screen_insert_offset
    sbc screen_display_offset
    cmp #16
    bmi .line1_cursor
    cmp #32
    bmi .line2_cursor
    ;; insert-offset is outside/below display portal
    jmp .done
.line1_cursor:
    lda screen_insert_offset
    and #$f
    ora #LCD_SetAddressStartLineOne
    jsr lcd_command
    jmp .done
.line2_cursor:
    lda screen_insert_offset
    and #$f
    ora #LCD_SetAddressStartLineTwo
    jsr lcd_command
    jmp .done
.done
    ply
    plx
    pla
    rts

screen_reposition: ;; TODO: handle upward scroll & more general reposition
    lda screen_insert_offset
    sec
    sbc screen_display_offset
    cmp #32
    bmi .done
    clc
    lda screen_display_offset
    adc #16
    sta screen_display_offset
.done:
    rts

screen_left1:
    dec screen_insert_offset
    jmp screen_reposition
screen_right1:
    inc screen_insert_offset
    jmp screen_reposition
screen_up1:
    lda screen_insert_offset
    sec
    sbc #16
    sta screen_insert_offset
    jmp screen_reposition
screen_down1:
    lda screen_insert_offset
    clc
    adc #16
    sta screen_insert_offset
    jmp screen_reposition

screen_enter:
    lda #$f0 ;; TODO: use bit test and reset opcode?
    and screen_insert_offset
    sta screen_insert_offset
    jmp screen_down1

screen_putChar: ; A
    phx
    ldx screen_insert_offset
    sta screen_buffer, x
    plx
    jmp screen_right1

screen_backspace:
    jsr screen_left1
    lda #' '
    phx
    ldx screen_insert_offset
    sta screen_buffer, x
    plx
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
    cmp #$e0
    beq .extended
    cmp #$f0
    beq .release
    cmp #$12
    beq .shift
    cmp #$59
    beq .shift
    cmp #$29
    beq .space
    cmp #$75
    beq .up_arrow
    cmp #$72
    beq .down_arrow
    cmp #$6b
    beq .left_arrow
    cmp #$74
    beq .right_arrow
    cmp #$5a
    beq .enter
    cmp #$66
    beq .backspace
    tax ;scancode
    bmi .unknown ; >$7f
    lda upper_case
    bne .read_upper
    jmp .read_lower
.extended:
    ;; just ignore the extended-prefix
    rts
.release:
    inc seen_release
    rts
.shift:
    lda upper_case
    beq .shift_to_upper
    ; already upper case; no change
    rts
.shift_to_upper:
    inc upper_case
    rts

.up_arrow:
    jmp screen_up1
.down_arrow:
    jmp screen_down1
.left_arrow:
    jmp screen_left1
.right_arrow:
    jmp screen_right1
.enter:
    jmp screen_enter
.backspace:
    jmp screen_backspace

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
    rts
.space:
    lda #' '
.ascii:
    jsr screen_putChar
.done:
    rts

reset:
    ldx #$ff
    txs
    cli ; enable interrupts
    jsr init_globals
    jsr via_init
    jsr lcd_init
    jsr screen_init
.loop:
    lda ready_scanCode
    beq .loop
    stz ready_scanCode
    lda scancode
    jsr display_scancode
    jsr screen_refresh ;; TODO: move to separate task executed on a timer
    jmp .loop

irq:
    pha
    phx

    ldx IFR

    ;; ;; Was the interrupt caused by the keyboard packet timeout?
    ;; txa
    ;; and #(via_timer2)
    ;; bne .timer2_expired

    ;; Was the interrupt caused by the keyboard?
    txa
    and #(via_ca1)
    bne .keyboard

    ;; any other interrupt. show mark, expect this case to never happen
    lda #'!'
    jsr screen_putChar
    jmp .done

.keyboard:
    clc
    lda PORTA ; ack keyboard -- TODO: do this via IRF flags
    lda PORTB ; read keyboard data bit
    and #1
    tax
    beq .rotate
.data1:
    sec
.rotate:
    ror incoming
    inc count

    lda count
    cmp #1
    beq .one
    cmp #9
    beq .nine
    cmp #11
    beq .eleven
    jmp .done

;; .timer2_expired:
;;     bit T2L ; ack
;;     ;; Show a screen mark for dev/debug.. -- TODO: if count is not already 0
;;     ;; lda #'%'
;;     ;; jsr screen_putChar
;;     ;; jsr screen_refresh ;; to see now!
;;     ;; Reset count/incoming to ensure keyboard packet re-sync
;;     stz count
;;     stz incoming
;;     jmp .done

.one:
    ;; ;; set/start timer2
    ;; lda #$ff
    ;; sta T2L
    ;; sta T2H ; start; 65k clocks; about 16ms (2ms would be plenty)
    txa
    beq .done ; start bit zero as expected
    inc error_start_bit
    jmp .done

.nine:
    lda incoming
    sta scancode ; saved for when we reach end of frame on bit 11
    jmp .done

.eleven:
    txa ; the 11th bit
    bne .eleven_ok ; must be a 1
    lda error_start_bit
    beq .eleven_ok ; must be a 0
.eleven_bad:
    stz error_start_bit
    jmp .eleven_finish
.eleven_ok:
    lda ready_scanCode
    bne .too_slow
    inc ready_scanCode
.eleven_finish:
    stz count
    stz incoming
    jmp .done

.too_slow:
    lda #'#'
    jsr screen_putChar
    jsr screen_refresh ;; to see now before we spin

.done:
    plx
    pla
    rti

nmi:
    rti
