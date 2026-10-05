;;; Explore pre-emption..

    org $fffa
    word nmi
    word reset
    word irq

    org $8000

    include coop.s
    include via.s
    include lcd.s
    include screen.s

    ;; zero page
    temp0 = 0
    coop_stack_base = 1
    coop_stack_frame = 2
    screen_insert_offset = 3
    screen_display_offset = 4
    jiffy_now = 5

    screen_buffer = $200 ; 256 bytes

;;; TODO: move to jiffy.s
;;; need jiffy_now (1 byte)
;;; client must call jiffy_init

jiffys_per_sec = 100
cpu_cycles_per_jiffy = (cpu_cycles_per_sec / jiffys_per_sec - 2)

jiffy_init:
    ;; TODO: use tsb, so requires no knowledge of existing state?
    lda #(via_acr_timer1_freerunning)
    sta via_acr

    lda #(via_ier_enable | via_timer1)
    sta via_ier
    lda #<cpu_cycles_per_jiffy
    sta via_t1cl
    lda #>cpu_cycles_per_jiffy
    sta via_t1ch ;; starts timer
    rts

jiffy_wait: ; A (max 128)
    clc
    adc jiffy_now
    dec
.loop:
    yield
    cmp jiffy_now
    ;; we cannot be sure not to overshoot, so must not use bne
    ;; we do an inital "dec" above, so bpl makes sense
    bpl .loop
    rts

reset:
    coop_stack_init
    jsr jiffy_init
    jsr lcd_init
    jsr screen_init
    cli ; enable
    lda #'A'
    jsr screen_putChar
    spawn screen_refresh_task
    spawn slow_letters_task
    spawn unyielding_spin_task
    finish

screen_refresh_task:
.loop:
    jsr screen_refresh
    lda #10
    jsr jiffy_wait
    jmp .loop

unyielding_spin_task: ; Mimic CPU intensive computation
.loop:
    jmp .loop

slow_letters_task:
.start:
    lda #'a'
.loop:
    jsr screen_putChar
    jsr wait_quarter_sec
    cmp #'e'
    beq .start
    inc
    jmp .loop

wait_quarter_sec:
    pha
    lda #25
    jsr jiffy_wait
    pla
    rts

irq:
    pha
    lda via_ifr ; what?
    and #(via_timer1)
    bne .timer1_expired
    jmp .done ; unexpected interrupt
.timer1_expired:
    bit via_t1cl ; ack
    inc jiffy_now
.done
    pla
    rti_yield

nmi:
    pha
    lda #'x'
    jsr screen_putChar
    pla
    rti
