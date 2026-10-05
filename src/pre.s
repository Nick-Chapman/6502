;;; New simple example to sort out issues in pre-emptive tasking.
;;; Start of by controlling pre-emption on NMI. Then move to timer

    org $fffa
    word nmi
    word reset
    word irq

    org $8000

    include coop.s
    include lcd.s
    include screen.s
    include via.s

    ;; zero page
    temp0 = 0
    coop_stack_base = 1
    coop_stack_frame = 2
    newline_counter = 3
    jiffy = 4

    screen_insert_offset = 5
    screen_display_offset = 6

    screen_buffer = $200 ; 256 bytes


;; put: ;A
;;     ;pha
;;     ;lda newline_counter
;;     ;cmp #15
;;     ;bne .no
;;     ;stz newline_counter
;;     ;lda #LCD_ClearDisplay
;;     ;jsr lcd_command
;; .no:
;;     ;inc newline_counter
;;     ;pla
;;     jsr lcd_emitChar
;;     rts

spin_delay:
    phx
    phy
    ldy #0
.y:
    ldx #0
.x:
    dex
    bne .x
    dey
    bne .y
    ply
    plx
    rts

jiffys_per_sec = 100
cpu_cycles_per_jiffy = (cpu_cycles_per_sec / jiffys_per_sec - 2)

;; timer_init:
;;     lda #(via_ier_enable | via_timer1)
;;     sta via_ier
;;     lda #(via_acr_timer1_freerunning)
;;     sta via_acr
;;     lda #<cpu_cycles_per_jiffy
;;     sta via_t1cl
;;     lda #>cpu_cycles_per_jiffy
;;     sta via_t1ch ;; starts timer
;;     rts

reset:
    coop_stack_init
    jsr lcd_init
    jsr screen_init
    ;jsr timer_init
    stz newline_counter
    cli ; enable
;;     ldx #7
;; .tasks:
;;     spawn task
;;     ;dex
;;     ;bne .tasks
;;     finish
    lda #'H'
    jsr screen_putChar
.loop:
    jsr screen_refresh
    jsr .loop

;; task: ; x->
;; .loop:
;;     txa
;;     clc
;;     adc #'0'
;;     jsr spin_delay
;;     jsr screen_putChar
;;     yield
;;     jmp .loop

nmi:
    pha
    lda #'x'
    jsr screen_putChar
    pla
    rti ; _yield

irq:
    rti

;;     pha

;;     lda via_ifr
;;     and #(via_timer1)
;;     beq .done

;;     bit via_t1cl
;;     inc jiffy
;;     lda jiffy
;;     cmp #50
;;     beq .switch
;; .done:
;;     pla
;;     rti
;; .switch:
;;     stz jiffy

;;     pla
;;     rti_yield
