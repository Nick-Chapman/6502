;;; How many concurrent tasks can we run?

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

    temp0 = 0
    coop_stack_frame = 1
    coop_stack_base = 2
    screen_insert_offset = 3
    screen_display_offset = 4
    jiffy_now = 5
    screen_buffer = $200

reset:
    coop_stack_init
    jsr jiffy_init
    jsr lcd_init
    jsr screen_init
    cli
    lda #'A'
    jsr screen_putChar
    spawn screen_task

    ldx #0
.loop:
    lda .names, x
    beq .done
    spawn task
    lda #1
    jsr jiffy_wait
    inx
    jmp .loop
.names:
    ;;asciiz "abcdefghijklmnopqrstuvwxyz01234567"
    asciiz "abcdefghijklmnopqrstuvwxyz"
.done:
    finish

screen_task:
.loop:
    jsr screen_refresh
    lda #10
    jsr jiffy_wait
    jmp .loop

task: ;A
    tax
.loop:
    txa
    jsr screen_putChar
    lda #10
    jsr jiffy_wait
    jmp .loop

irq:
    pha
    lda via_ifr
    and #(via_timer1)
    bne .timer1
    jmp .done
.timer1:
    bit via_t1cl ;ack
    inc jiffy_now
    pla
    rti ;_yield
.done:
    pla
    rti

nmi:
    pha
    lda #'x'
    jsr screen_putChar
    pla
    rti
