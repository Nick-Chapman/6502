
    org $8000

    include via.s

via_init:
    ;; set all pins on port-B and port-A as output
    lda #%11111111
    sta DDRB
    sta DDRA
    lda #%00000000 ; negative edge on any of CA1,CA2,CB1,CB2
    sta PCR
    ;;lda #%11000011 ; enable Timer1, CA1 and CA2
    lda #%11000000 ; enable just Timer1
    sta IER
    ;; Setup timer1
    lda #%01000000 ; timer-1 in free running mode
    sta ACR
    ;; 4E1E = 19998 (100/s), at 2 MhZ
    lda #$1e
    sta T1CL
    lda #$4e
    sta T1CH ;; starts timer
    rts

    include lcd.s

display_hex_nibble: ; A->()
    tax
    lda .hex_chars, x
    jsr lcd_emitChar
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; measure work getting done...
;;; 'work' is incrementing a counter; reset counter each second
;;; (main loop) display the time in seconds & the running counter
;;; explore calling display only every 1/5 second

jiffy = 20
jiffy_last_second = 21
jiffy_last_status = 22

counter = 23 ;; 3bytes (BCD
seconds = 26 ;; 2bytes (BCD)

last_counter = 28 ;; 3bytes

reset:
    cli ; enable IRQ
    stz jiffy
    stz jiffy_last_second
    jsr via_init
    jsr lcd_init
    jsr reset_counter
    jsr reset_last_counter
    jsr reset_seconds
.loop:
    ;;jsr every_second
    ;;jsr update_status_display
    jsr inc_counter
    jmp .loop

every_second:
    sec
    lda jiffy
    sbc jiffy_last_second
    cmp #100
    bcc .no
    lda jiffy
    sta jiffy_last_second
    jsr inc_seconds
    jsr snap_counter
    jsr reset_counter

    lda PORTB
    eor #1 ; toggle LED
    sta PORTB
.no:
    rts

update_status_display:
    sec
    lda jiffy
    sbc jiffy_last_status
    cmp #10
    bcc .no
    lda jiffy
    sta jiffy_last_status
    jsr display_status_now
.no:
    rts

display_status_now:
    lda #LCD_ReturnHome
    jsr lcd_command

    lda seconds+1
    jsr display_hex_byte
    lda seconds
    jsr display_hex_byte
    lda #' '
    jsr lcd_emitChar
    lda last_counter+2
    jsr display_hex_byte
    lda last_counter+1
    jsr display_hex_byte
    lda last_counter
    jsr display_hex_byte
    rts

snap_counter:
    lda counter
    sta last_counter
    lda counter+1
    sta last_counter+1
    lda counter+2
    sta last_counter+2
    rts

reset_counter:
    stz counter
    stz counter+1
    stz counter+2
    rts

reset_last_counter:
    stz last_counter
    stz last_counter+1
    stz last_counter+2
    rts

reset_seconds:
    stz seconds
    stz seconds+1
    rts

inc_counter:
    sed ; decimal
    sec
    lda counter
    adc #0
    sta counter
    bne .done
    sec
    lda counter+1
    adc #0
    sta counter+1
    bne .done
    sec
    lda counter+2
    adc #0
    sta counter+2
.done:
    cld
    rts

inc_seconds:
    sed ; decimal
    sec
    lda seconds
    adc #0
    sta seconds
    bne .done
    sec
    lda seconds+1
    adc #0
    sta seconds+1
.done:
    cld
    rts

irq:
    pha
    bit IFR
    bvs .timer1
    jmp .done
.timer1:
    lda #%01000000
    sta IFR
    inc jiffy
    jsr every_second
    jsr update_status_display
.done:
    pla
    rti

nmi:
    rti

    org $fffa
    word nmi
    word reset
    word irq
