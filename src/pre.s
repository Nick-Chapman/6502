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
    include jiffy.s

    ;; zero page
    temp0 = 0
    coop_stack_base = 1
    coop_stack_frame = 2
    screen_insert_offset = 3
    screen_display_offset = 4
    jiffy_now = 5
    work_counter = 6 ; 2bytes
    ;; 8 next
    screen_buffer = $200 ; 256 bytes

reset:
    coop_stack_init
    jsr jiffy_init
    jsr lcd_init
    jsr screen_init
    jsr work_counter_init
    cli ; enable
    lda #'A'
    jsr screen_putChar
    spawn screen_refresh_task
    spawn slow_letters_task
    spawn unyielding_counting_task
    spawn show_count_reached_every_second
    finish

work_counter_init:
    stz work_counter
    stz work_counter + 1
    rts

unyielding_counting_task:
    sed ; this provoked a bug in co-op which must clear the BCD flag
.loop:
    ldx #80
.inner:
    dex
    bne .inner
    ;; 16it BCD increment
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
    jmp .loop

show_count_reached_every_second:
.loop:
    jsr work_counter_display
    jsr work_counter_init
    lda #100
    jsr jiffy_wait
    jmp .loop

work_counter_display:
    lda #'{'
    jsr screen_putChar
    lda work_counter + 1
    jsr screen_hex_byte
    lda work_counter
    jsr screen_hex_byte
    lda #'}'
    jsr screen_putChar
    rts

screen_refresh_task:
.loop:
    jsr screen_refresh
    lda #10
    jsr jiffy_wait
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
    rti_yield ;; pre-emption

nmi:
    pha
    lda #'x'
    jsr screen_putChar
    pla
    rti
