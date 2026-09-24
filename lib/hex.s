
display_hex_nibble: ; A->()
    ;;phx ;; TODO: so nicer as a debug routine
    tax
    lda .hex_chars, x
    jsr lcd_emitChar
    ;;plx
    rts
.hex_chars:
    ascii "0123456789abcdef"

display_hex_byte: ; A->()
    pha
    lsr
    lsr
    lsr
    lsr
    jsr display_hex_nibble
    pla
    and #$f
    jsr display_hex_nibble
    rts
