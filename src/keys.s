
    org $fffa
    word nmi
    word reset
    word irq

    org $8000

    include via.s
    include lcd.s
    include screen.s
    include scancode.s

    screen_insert_offset = 10
    screen_display_offset = 11

    scancode_seen_release = 20
    scancode_upper_case = 21

    ps2_bitcount = 30
    ps2_incoming = 31
    ps2_error_start_bit = 32
    ps2_scancode = 33
    ps2_ready = 34

    screen_buffer = $200 ; 256 bytes

ps2_init:
    stz ps2_error_start_bit
    stz ps2_bitcount
    stz ps2_incoming
    stz ps2_ready
    stz ps2_scancode
    rts

via_init:
    lda #$fe ; all outputs -- except least sig INPUT, borrowed for keyboard PS/2 data
    sta via_ddrb
    lda #0 ; no latching, timer2 one-shot mode
    sta via_acr
    lda #0
    sta via_pcr ; active edge negative
    lda #(via_ier_enable | via_ca1 | via_timer2)
    sta via_ier
    rts

reset:
    ldx #$ff
    txs
    cli ; enable interrupts
    jsr ps2_init
    jsr via_init
    jsr lcd_init
    jsr scancode_init
    jsr screen_init
.loop:
    lda ps2_ready
    beq .loop
    stz ps2_ready
    lda ps2_scancode
    jsr scancode_display
    jsr screen_refresh ;; TODO: move to separate task executed on a timer
    jmp .loop

irq:
    pha
    phx
    ldx via_ifr
    ;; Was the interrupt caused by the keyboard inactivity timeout?
    txa
    and #(via_timer2)
    bne .timer2_expired
    ;; Was the interrupt caused by the keyboard?
    txa
    and #(via_ca1)
    bne .keyboard
    ;; Any other interrupt? We never expect this to happen. Show a mark.
    lda #'!'
    jsr screen_putChar
    jmp .done

.keyboard:
    clc
    lda via_porta ; ack keyboard (alternatively: lda #(via_ca1) / sta via_ifr)
    lda via_portb ; read keyboard data bit
    and #1
    tax
    beq .rotate
.data1:
    sec
.rotate:
    ror ps2_incoming
    inc ps2_bitcount

    lda ps2_bitcount
    cmp #1
    beq .one
    cmp #9
    beq .nine
    cmp #11
    beq .eleven
    jmp .done

.timer2_expired:
    bit via_t2l ; ack
    lda ps2_bitcount
    beq .done ; we are already synchronised
    ;; framing error; re-synchronize
    stz ps2_bitcount
    stz ps2_incoming
    jmp .done

.one:
    ;; start timer2 for keyboard inactivity.
    ;; The 11-bit packet should be received within 1ms from the first-bit arriving
    ;; (long enough for even the slowest keyboard -- 10 kHz)
    ;; The fastest keyboard (17 kHz) may transmit successive packets without aany pause.
    ;; The inactivity timeout will just be restarted on bit-1 of subsequent packets
    keyboard_inactivity_timeout = cpu_cycles_per_ms ;; 1ms
    lda #<keyboard_inactivity_timeout
    sta via_t2l
    lda #>keyboard_inactivity_timeout
    sta via_t2h
    txa
    beq .done ; start bit zero as expected
    inc ps2_error_start_bit
    jmp .done

.nine:
    lda ps2_incoming
    sta ps2_scancode ; saved for when we reach end of frame on bit 11
    jmp .done

.eleven:
    txa ; the 11th bit
    bne .eleven_ok ; must be a 1
    lda ps2_error_start_bit
    beq .eleven_ok ; must be a 0
.eleven_bad:
    stz ps2_error_start_bit
    jmp .eleven_finish
.eleven_ok:
    lda ps2_ready
    bne .too_slow
    inc ps2_ready
.eleven_finish:
    stz ps2_bitcount
    stz ps2_incoming
    jmp .done

.too_slow:
    lda #'#'
    jsr screen_putChar
    jsr screen_refresh ;; to see now before we spin
.spin:
    jmp .spin

.done:
    plx
    pla
    rti

nmi:
    rti
