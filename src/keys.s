
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

    ;; jiffys increment every 1/100th of a seconds; rolling over ever 2.56s
    jiffy_now = 40
    jiffy_last_screen_refresh = 41
    jiffy_work_snap = 42

    work_counter = 50 ; 2bytes

    screen_buffer = $200 ; 256 bytes

ps2_init:
    stz ps2_error_start_bit
    stz ps2_bitcount
    stz ps2_incoming
    stz ps2_ready
    stz ps2_scancode
    rts

work_counter_init:
    stz work_counter
    stz work_counter + 1
    rts

jiffys_per_sec = 100
cpu_cycles_per_jiffy = (cpu_cycles_per_sec / jiffys_per_sec - 2)

jiffy_init:
    stz jiffy_now
    stz jiffy_last_screen_refresh
    rts

via_init:
    lda #$fe ; all outputs -- except least sig INPUT, borrowed for keyboard PS/2 data
    sta via_ddrb

    lda #0
    sta via_pcr ; active edge negative

    lda #(via_ier_enable | via_ca1 | via_timer1 | via_timer2)
    sta via_ier

    lda #(via_acr_timer1_freerunning)
    sta via_acr

    lda #<cpu_cycles_per_jiffy
    sta via_t1cl
    lda #>cpu_cycles_per_jiffy
    sta via_t1ch ;; starts timer
    rts

reset:
    ldx #$ff
    txs
    cli ; enable interrupts
    jsr ps2_init
    jsr lcd_init
    jsr scancode_init
    jsr screen_init
    jsr jiffy_init
    jsr work_counter_init
    jsr via_init ; starting jiffy timer

.loop:
    jsr display_scancode_if_available
    jsr periodic_screen_refresh
    jsr periodic_work_counter_display_and_reset
    jsr work_loop_one_step
    jmp .loop

display_scancode_if_available:
    lda ps2_ready
    beq .done
    stz ps2_ready
    lda ps2_scancode
    jmp scancode_display ; tail
.done:
    rts

periodic_screen_refresh:
    ;; TODO: co-op tasks would avoid need for global: jiffy_last_screen_refresh
    ldx jiffy_now
    txa
    sec
    sbc jiffy_last_screen_refresh
    cmp #10 ; 1/10s (fast enough for eye?)
    bcc .done
    stx jiffy_last_screen_refresh
    jmp screen_refresh ; tail
.done
    rts

periodic_work_counter_display_and_reset:
    ldx jiffy_now
    txa
    sec
    sbc jiffy_work_snap
    cmp #100 ; every second
    bcc .done
    stx jiffy_work_snap
    jsr work_counter_display
    jsr work_counter_init
.done
    rts

work_counter_display:
    lda screen_insert_offset
    pha
    lda screen_display_offset
    pha
    lda #11
    sta screen_insert_offset
    lda work_counter + 1
    jsr screen_hex_byte
    lda work_counter
    jsr screen_hex_byte
    pla
    sta screen_display_offset
    pla
    sta screen_insert_offset
    rts

work_loop_one_step:
    ldx #0
.loop:
    dex
    bne .loop
    inc work_counter
    bne .done
    inc work_counter + 1
.done:
    rts

irq:
    pha
    phx
    ldx via_ifr

    ;; Was the interrupt caused by the keyboard?
    txa
    and #(via_ca1)
    bne .keyboard

    ;; Was the interrupt caused by the keyboard inactivity timeout?
    txa
    and #(via_timer2)
    bne .timer2_expired

    ;; Was the interrupt caused by the jiffy timer?
    txa
    and #(via_timer1)
    bne .timer1_expired

    ;; Any other interrupt? We never expect this to happen. Show a mark.
    lda #'!'
    jsr screen_putChar
    jmp .done

.timer1_expired:
    bit via_t1cl
    inc jiffy_now
    jmp .done

.timer2_expired:
    bit via_t2l ; ack
    lda ps2_bitcount
    beq .done ; we are already synchronised
    ;; framing error; re-synchronize
    stz ps2_bitcount
    stz ps2_incoming
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
    ;; Loose packets if the scancode display routine is too slow
    ;lda ps2_ready
    ;bne .too_slow
    inc ps2_ready
.eleven_finish:
    stz ps2_bitcount
    stz ps2_incoming
    jmp .done

;; .too_slow:
;;     lda #'#'
;;     jsr screen_putChar
;;     jsr screen_refresh ;; to see now before we spin
;; .spin:
;;     jmp .spin

.done:
    plx
    pla
    rti

nmi:
    rti
