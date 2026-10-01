
;;; cooperative tasking

;;; requires:
;;; - coop_stack_bottom (1 byte)
;;; provides:
;;; - spawn (macro)
;;; - finish (macro)
;;; - yield (macro)

;;; Client facing macros: spawn, finish, yield
spawn: macro A
    jsr .here\@
    jmp .after\@
.here\@:
    SAVE
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
endmacro

RESTORE: macro
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
    cpx coop_stack_bottom
    beq .all_tasks_finished
    RESTORE
    rts
.all_tasks_finished:
    lda #'!'
    jsr lcd_emitChar ;; TODO: need to remove
.spin:
    jmp .spin

yield_code:
    SAVE
    ldy coop_stack_bottom
    BURY ;y
    BURY ;x
    BURY ;a
    BURY ;ret/1
    BURY ;ret/2
    sty coop_stack_bottom
    RESTORE
    rts
