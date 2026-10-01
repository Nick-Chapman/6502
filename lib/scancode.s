
;;; Parse a PS/2 scancode, ignoring release scancodes & tracking shift to uppercase.

;;; requires:
;;; - include screen.s
;;; - scancode_seen_release (1 byte space)
;;; - scancode_upper_case (1 byte space)
;;; provides:
;;; - scancode_init
;;; - scancode_display

scancode_init:
    stz scancode_seen_release
    stz scancode_upper_case
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

scancode_display: ;A-> (uses X)
    pha
    lda scancode_seen_release
    beq .not_release
    dec scancode_seen_release
    pla ; scancode
    cmp #$12
    beq .release_shift
    cmp #$59
    beq .release_shift
    ; ignore any other release
    rts
.release_shift:
    stz scancode_upper_case
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
    lda scancode_upper_case
    bne .read_upper
    jmp .read_lower
.extended:
    ;; just ignore the extended-prefix
    rts
.release:
    inc scancode_seen_release
    rts
.shift:
    lda scancode_upper_case
    beq .shift_to_upper
    ; already upper case; no change
    rts
.shift_to_upper:
    inc scancode_upper_case
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

