;;; First play with ACIA

    org $fffa
    word nmi
    word reset
    word irq

    org $8000
    include via.s
    include lcd.s
    include hex.s

nmi:
    rti
irq:
    rti

reset:
    ldx #$ff
    txs

    jsr lcd_init
    lda #'1'
    jsr lcd_emitChar
    jsr acia_init

    lda #'2'
    jsr lcd_emitChar
;.spin:
;    jmp .spin

.loop:
    jsr acia_receive

    pha
    lda #'3'
    jsr lcd_emitChar
    pla

    jsr lcd_emitChar

    jmp .loop


    acia_data = $5000
    acia_status = $5001
    acia_command = $5002
    acia_control = $5003

    acia_status_receiver_data_register_full    = %00001000
    acia_command_noParity_noEcho_noInterrupt   = %00001011
    acia_control_1StopBit_8DataBits_baud_19200 = %00011111

acia_init:
    sta acia_status ; soft reset (any value)
    lda #(acia_command_noParity_noEcho_noInterrupt)
    sta acia_command
    lda #(acia_control_1StopBit_8DataBits_baud_19200)
    sta acia_control

    lda acia_command
    jsr display_hex_byte
    lda acia_control
    jsr display_hex_byte

    rts

acia_receive: ; ->A
    ;lda #(acia_status_receiver_data_register_full)
.wait:
    ;bit acia_status
    lda acia_status
    pha
    jsr display_hex_byte
    pla
    and #(acia_status_receiver_data_register_full)
    beq .wait
    lda acia_data
    rts

