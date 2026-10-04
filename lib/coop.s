
;;; cooperative tasking

;;; requires:
;;; - coop_stack_base (1 byte)
;;; - coop_stack_frame (1 byte)
;;; provides:
;;; - coop_stack_init (macro)
;;; - spawn (macro)
;;; - finish (macro)
;;; - yield (macro)

coop_stack_init: macro
    ldx #$ff
    txs
    stx coop_stack_base
    stx coop_stack_frame
endmacro

spawn: macro A
    jsr .here\@ ;; 2 bytes on stack for 'return' address
    jmp .after\@
.here\@:
    SAVE ; 5 more
    tsx
    stx coop_stack_frame
    inx
    inx
    lda $100,x ; preserve a for spawned yask
    pha
    inx
    lda $100,x
    tax ; preserve x for spawned task
    pla
    jmp \A
.after\@:
endmacro

finish: macro
    jmp finish_code
endmacro

yield: macro
    jsr yield_code
endmacro

;;; Internal macros: SAVE, RESTORE, BURY

SAVE: macro ; mucks a/x
    php
    phy
    phx
    pha

    tsx
    stx temp0
    lda coop_stack_frame
    sec
    sbc temp0
    pha
endmacro

RESTORE: macro
    pla

    tsx
    stx temp0
    clc
    adc temp0
    sta coop_stack_frame

    pla
    plx
    ply
    plp
endmacro

BURY: macro
    pla
    iny
    sta $100,y
endmacro

finish_code:
    tsx
    cpx coop_stack_base
    beq .all_tasks_finished
    RESTORE
    rts
.all_tasks_finished:
.spin:
    jmp .spin

yield_code:
    SAVE
    ldy coop_stack_base
    tsx
    stx temp0
    lda coop_stack_frame
    sec
    sbc temp0
    tax ;; this will be 7 + #temps on the stack for this task
.loop:
    BURY
    dex
    bne .loop
    sty coop_stack_base
    RESTORE
    rts

fix_return_address:  macro
    pha
    phx
    tsx
    inx ; to x
    inx ; to a
    inx ; to p
    inx ; to ret-lo
    lda $100,x
    beq .dec_lo_and_hi
.dec_just_lo:
    dec $100,x
    jmp .after_dec_lo
.dec_lo_and_hi:
    dec $100,x
    inx ; to ret-hi
    dec $100,x
.after_dec_lo:
    plx
    pla
endmacro

rti_yield: macro
    fix_return_address
    plp
    jmp yield_code
endmacro
