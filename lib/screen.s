
;;; 256 byte "screen" (16 lines of 16 columns)
;;; Viewed on the LCD through a 2-line "display portal"
;;; Scrolled to keep the insert point always visible.
;;;
;;; requires:
;;; - include lcd.s
;;; - screen_insert_offset (1 byte)
;;; - screen_display_offset (1 byte)
;;; - screen_buffer (256 bytes)
;;; provides:
;;; - screen_init
;;; - screen_refresh
;;; - screen_left1
;;; - screen_right1
;;; - screen_up1
;;; - screen_down1
;;; - screen_enter
;;; - screen_putChar
;;; - screen_backspace
;;; - screen_hex_nibble
;;; - screen_hex_byte

screen_init:
    stz screen_insert_offset
    stz screen_display_offset
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
    ;; display the 32 characters of the screen which can be 'seen' by the display
    ;; line1...
    ldx screen_display_offset
    ldy #16
.line1:
    lda screen_buffer,x
    jsr lcd_emitChar
    inx
    dey
    bne .line1
    ;; line2...
    lda #LCD_SetAddressStartLineTwo
    jsr lcd_command
    ldy #16
.line2:
    lda screen_buffer,x
    jsr lcd_emitChar
    inx
    dey
    bne .line2
    ;; position the cursor at the insert point, if visible
    lda screen_insert_offset
    cmp screen_display_offset
    bmi .done ;; insert-offset is outside/above display portal
    ;; insert point is below start of display
    sec
    lda screen_insert_offset
    sbc screen_display_offset
    cmp #16
    bmi .line1_cursor ; visible on line1
    cmp #32
    bmi .line2_cursor ; visible on line2
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

screen_reposition:
    lda screen_insert_offset
    sec
    sbc screen_display_offset
    bmi .reposition_up
    cmp #32
    bpl .reposition_down
    ; insert offset is visible; no reposition necessary
    rts
    ;; NOTE: this reposition code assumes movement of no more than a single line up/down.
    ;; So works well enough for the arrow keys, Enter and Backspace
    ;; But it wont work for Home/End.
.reposition_up:
    lda screen_display_offset
    sec
    sbc #16 ; up one line
    sta screen_display_offset
    rts
.reposition_down:
    lda screen_display_offset
    clc
    adc #16 ; down one line
    sta screen_display_offset
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
    lda #$0f
    trb screen_insert_offset
    jmp screen_down1

screen_putChar: ; A
    pha
    phx
    ldx screen_insert_offset
    sta screen_buffer, x
    jsr screen_right1
    plx
    pla
    rts

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
