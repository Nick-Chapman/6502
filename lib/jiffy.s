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
    ;; TODO: broken detection when jiffy_now+A roll over?
    yield
    cmp jiffy_now
    ;; we cannot be sure not to overshoot, so must not use bne
    ;; we do an inital "dec" above, so bpl makes sense
    bpl .loop
    rts


;; jiffy_wait:
;;     clc
;;     adc jiffy_now
;;     bcc .loop2
;; .loop:
;;     yield
;;     cmp jiffy_now
;;     bpl .loop
;;     rts

;; .loop2:
;;     yield
;;     cmp jiffy_now
;;     bmi .loop2
;;     jmp .loop
