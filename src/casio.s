;;; Like a casio digitil watch

    org $fffa
    word nmi
    word reset
    word irq

    org $8000

    include coop.s
    include via.s
    include lcd.s
    include jiffy.s

    temp0 = 0
    coop_stack_frame = 1
    coop_stack_base = 2
    jiffy_now = 3

    flash_bits = 4 ; 8 bits
    half_second = 5
    tick_second = 6
    tick_minute = 7
    tick_hour = 8
    set_mode = 9
    tick_advance = 10

    display = $200 ; 8 bytes in zero mem

reset:
    coop_stack_init
    cli
    jsr jiffy_init

    lda #(via_ier_enable | via_ca1)
    sta via_ier

    jsr lcd_init
    lda #LCD_DisplayOn_CursorOff
    jsr lcd_command
    stz set_mode
    stz jiffy_now
    lda #%00000000
    sta flash_bits
    lda #':'
    sta display+2
    sta display+5
    spawn flash_task
    spawn display_task
    spawn second_task
    spawn minute_task
    spawn hour_task
    spawn set_task
    spawn advance_task
    finish

nmi:
    inc set_mode
    rti

irq:
    phx
    pha
    ldx via_ifr
    txa
    and #(via_timer1)
    bne .timer1
    txa
    and #(via_ca1)
    bne .ca1
    jmp .done
.timer1:
    bit via_t1cl ; ack
    inc jiffy_now
    jmp .done
.ca1:
    lda via_porta ; ack
    inc tick_advance
    jmp .done
.done:
    pla
    plx
    rti

advance_task:
.loop:
.wait:
    yield
    lda tick_advance
    beq .wait
    dec tick_advance
    lda set_mode
    and #3
    cmp #0
    beq .running
    cmp #1
    beq .setH
    cmp #2
    beq .setM
    cmp #3
    beq .setS
    jmp .loop
.running:
    jmp .loop
.setH:
    inc tick_hour
    jmp .loop
.setM:
    inc tick_minute
    jmp .loop
.setS:
    inc tick_second
    jmp .loop

set_task:
.loop:
    yield
    lda set_mode
    and #3
    cmp #0
    beq .running
    cmp #1
    beq .setH
    cmp #2
    beq .setM
    cmp #3
    beq .setS
    jmp .loop
.running:
    stz flash_bits
    jmp .loop
.setH:
    lda #%11000000
    sta flash_bits
    jmp .loop
.setM:
    lda #%00011000
    sta flash_bits
    jmp .loop
.setS:
    lda #%00000011
    sta flash_bits
    jmp .loop

flash_task:
    stz half_second
.loop:
    lda #50
    jsr jiffy_wait
    inc half_second
    lda #50
    jsr jiffy_wait
    dec half_second
    inc tick_second
    jmp .loop

display_task:
.loop:
    jsr refresh_digits
    lda #10
    jsr jiffy_wait
    jmp .loop

refresh_digits:
    lda #LCD_ReturnHome
    jsr lcd_command
    lda #' '
    jsr lcd_emitChar
    jsr lcd_emitChar
    jsr lcd_emitChar
    jsr lcd_emitChar
    ldy flash_bits
    ldx #0
.loop:
    tya
    rol
    tay
    bcc .on
    lda half_second
    bne .on
.off:
    lda #' '
    jmp .put
.on:
    lda display,x
.put:
    jsr lcd_emitChar
    inx
    cpx #8
    bne .loop
    rts

numerals: ascii "0123456789"

second_task:
    stz tick_second
    ldy #$57 ; init
.write:
    tya
    and #$f
    tax
    lda numerals,x
    sta display+7
    tya
    and #$f0
    lsr
    lsr
    lsr
    lsr
    tax
    lda numerals,x
    sta display+6
.wait:
    yield
    lda tick_second
    beq .wait
    dec tick_second
    tya
    sed
    sec
    adc #0
    cmp #$60
    beq .zero
    tay
    jmp .write
.zero:
    spawn ripple_minute
    ldy #0
    jmp .write

ripple_minute:
    lda #30
    jsr jiffy_wait
    inc tick_minute
    finish

minute_task:
    stz tick_minute
    ldy #$59 ; init
.write:
    tya
    and #$f
    tax
    lda numerals,x
    sta display+4
    tya
    and #$f0
    lsr
    lsr
    lsr
    lsr
    tax
    lda numerals,x
    sta display+3
.wait:
    yield
    lda tick_minute
    beq .wait
    dec tick_minute
    tya
    sed
    sec
    adc #0
    cmp #$60
    beq .zero
    tay
    jmp .write
.zero:
    spawn ripple_hour
    ldy #0
    jmp .write

ripple_hour:
    lda #30
    jsr jiffy_wait
    inc tick_hour
    finish

hour_task:
    stz tick_hour
    ldy #$12 ; init
.write:
    tya
    and #$f
    tax
    lda numerals,x
    sta display+1
    tya
    and #$f0
    lsr
    lsr
    lsr
    lsr
    tax
    lda numerals,x
    sta display+0
.wait:
    yield
    lda tick_hour
    beq .wait
    dec tick_hour
    tya
    sed
    sec
    adc #0
    cmp #$13
    beq .one
    tay
    jmp .write
.one:
    ldy #1
    jmp .write
