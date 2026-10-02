
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
    jsr .here\@ ; 2 bytes on stack
    jmp .after\@
.here\@:
    SAVE ; 4 more
    tsx
    stx coop_stack_frame
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

SAVE: macro
    pha
    phx
    phy

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

    ply
    plx
    pla
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
    tax ;; this will be 6 + #temps on the stack for this task

.loop:
    BURY
    dex
    bne .loop

    sty coop_stack_base
    RESTORE
    rts
