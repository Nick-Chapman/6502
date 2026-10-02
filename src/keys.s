
    org $fffa
    word nmi
    word reset
    word irq

    org $8000

    include via.s
    include lcd.s
    include screen.s
    include scancode.s
    include coop.s

    temp0 = 0

    screen_insert_offset = 10
    screen_display_offset = 11

    scancode_seen_release = 20
    scancode_upper_case = 21

    ps2_bitcount = 30
    ps2_incoming = 31
    ps2_error_start_bit = 32
    ps2_read_offset = 33
    ps2_write_offset = 34

    ;; jiffys increment every 1/100th of a seconds; rolling over ever 2.56s
    jiffy_now = 40
    jiffy_work_snap = 42

    work_counter = 50 ; 2bytes

    coop_stack_base = 60
    coop_stack_frame = 61

    screen_buffer = $200 ; 256 bytes

    ps2_buffer_size = 8 ;; allows 7 pending scancodes
    ps2_buffer = $300 ; 8 bytes

ps2_init:
    stz ps2_error_start_bit
    stz ps2_bitcount
    stz ps2_incoming
    stz ps2_read_offset
    stz ps2_write_offset
    rts

work_counter_init:
    stz work_counter
    stz work_counter + 1
    rts

jiffys_per_sec = 100
cpu_cycles_per_jiffy = (cpu_cycles_per_sec / jiffys_per_sec - 2)

jiffy_init:
    stz jiffy_now
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
    coop_stack_init
    cli ; enable interrupts

    jsr ps2_init
    jsr lcd_init
    jsr scancode_init
    jsr screen_init
    jsr jiffy_init
    jsr work_counter_init
    jsr via_init ; starting jiffy timer

    spawn display_scancode_if_available
    spawn periodic_screen_refresh
    spawn periodic_work_counter_display_and_reset
    spawn work_loop_one_step
    finish
    ;; By calling work_loop_one_step twice in this loop, we increase
    ;; CPU utilization from 75% to 80.76% (5.76 points)
    ;; This change reduces the number of context switches, but I am not
    ;; sure how to compute the ratio, so cant pin a CPU cost on the switches.


display_scancode_if_available:
.loop:

    ;; force a delay of 1/100s to motivate the need for a ps2 scancode buffer
    lda jiffy_now
.wait:
    yield
    cmp jiffy_now
    beq .wait

    lda ps2_read_offset
    cmp ps2_write_offset
    beq .done
    ;; something to process...
    ldx ps2_read_offset
    sei
    inc ps2_read_offset
    lda #ps2_buffer_size
    trb ps2_read_offset
    cli
    lda ps2_buffer, x
    jsr scancode_display
.done:
    yield
    jmp .loop


;;; By increasing the #refresh/second from 10 to 20
;;; We see the cpu-utilization drop from 75% to 71.4% (3.6 points)
;;; So the baselne refresh rate of 10/sec costs 3.6%
periodic_screen_refresh:
.loop:
    jsr screen_refresh
    jsr wait10
    jmp .loop

wait10:
    lda #10
    clc
    adc jiffy_now
.loop:
    yield
    cmp jiffy_now
    bne .loop
    rts

periodic_work_counter_display_and_reset:
.loop:
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
    yield
    jmp .loop

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
.loop:
    ldx #80
    ;; This inner loop takes 80*5 = 400 clock cycles.
    ;; Which with a 4 MhZ clock equates to 1/10 ms (or 100us)
    ;; So, if this loop got 100% of the cpu time, it would reach 10000 every second
    ;; We shall use BCD to represent the counter.
    ;; So the value displayed each second will show the percentage (to 2dp)
    ;; of time spent doing "useful" counting work, in the inner loop.
    ;; The baseline figure for out experiments is 75%
.inner:
    dex
    bne .inner

    ;; By doubling the size of the work chunk (from 80 to 160 step)
    ;; And incrementing the counter by 2 on each step.
    ;; We see CPU utilization (time in inner loop)
    ;; increase from 75% to 83.86% (change of 8.86 points)

    ;; Since this change halves the number of times we perform the following
    ;; BCD increment and also the number of switches between co-op tasks
    ;; we can attribute double that figure, so 17.72% to the baseline
    ;; cost of tasks switching and the counter increment
    php
    sed
    lda work_counter
    clc
    adc #1
    sta work_counter
    bne .done
    lda work_counter + 1
    clc
    adc #1
    sta work_counter + 1
.done:
    plp
    yield
    jmp .loop

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
    ;; save incoming, but dont advance the write_pointer until bit-11
    ldx ps2_write_offset
    sta ps2_buffer, x
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

    inc ps2_write_offset
    lda #ps2_buffer_size
    trb ps2_write_offset

    lda ps2_write_offset
    cmp ps2_read_offset
    bne .eleven_finish

    ;; ps2_buffer overrun; show a mark but continue
    lda #'#'
    jsr screen_putChar

.eleven_finish:
    stz ps2_bitcount
    stz ps2_incoming
    jmp .done

.done:
    plx
    pla
    rti

nmi:
    rti
