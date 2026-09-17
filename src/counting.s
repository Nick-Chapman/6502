
PORTB = $6000
PORTA = $6001
DDRB  = $6002
DDRA  = $6003

E  = %10000000 ; enable
RW = %01000000 ; read/write
RS = %00100000 ; register select

LCD_ClearDisplay               = %00000001
LCD_ReturnHome                 = %00000010
LCD_EntryMode_Inc_NoShift      = %00000110
LCD_DisplayOn_CursorOn_NoBlink = %00001110
LCD_DisplayShift_Left          = %00011000
LCD_FunctionSet_8bit_2lines    = %00111000

    org $8000

lcd_init:
    ;; set all pins on port-B as output
    lda #%11111111
    sta DDRB
    ;; set most significant 3 pins on port-A as output
    lda #%11100000
    sta DDRA
    lda #LCD_FunctionSet_8bit_2lines
    jsr lcd_instruction
    lda #LCD_DisplayOn_CursorOn_NoBlink
    jsr lcd_instruction
    lda #LCD_ClearDisplay
    jsr lcd_instruction
    rts

lcd_wait:
    pha
.loopBusy:
    ;; V1
    ;; IO wait invokes workload
    ;; counter reach 2^20 in 46s
    ;; so ~87 clocks/tick, of which ~23 are the workload
    ;;jsr inc_counter

    ;; set port-B mode to input
    stz DDRB
    ;; read busy flag
    lda #RW
    sta PORTA
    lda #(RW | E)
    sta PORTA
    lda PORTB
    ;; test busy bit
    and #$80
    bne .loopBusy
    lda #RW
    sta PORTA
    ;; restore port-B mode to output
    lda #$ff
    sta DDRB
    pla
    rts

lcd_instruction: ; A->()
    jsr lcd_wait
    sta PORTB
    lda #0
    sta PORTA
    lda #E
    sta PORTA
    lda #0
    sta PORTA
    rts

lcd_emitChar: ; A->()
    jsr lcd_wait
    sta PORTB
    lda #RS
    sta PORTA
    lda #(RS | E)
    sta PORTA
    lda #RS
    sta PORTA
    rts

display_hex_nibble: ; A->()
    tax
    lda .hex_chars, x
    jsr lcd_emitChar
    rts
.hex_chars:
    ascii "0123456789abcdef"

display_hex_byte: ; A->()
    pha
    lsr
    lsr
    lsr
    lsr
    jsr display_hex_nibble
    pla
    and #$f
    jsr display_hex_nibble
    rts

COUNTER = 20 ;; 3bytes in zero page

init_counter:
    stz COUNTER
    stz COUNTER+1
    stz COUNTER+2
    rts

inc_counter:
    inc COUNTER
    bne .done

    ;; V3... selected
    ;; workload invokes IO (approx every 3ms)
    ;; counter reach 2^20 in 13s
    ;; so ~24 clocks/tick, which is only about 5% overhead for IO
    jsr display_counter

    inc COUNTER+1
    bne .done
    inc COUNTER+2

    ;; V2
    ;; workload invokes IO (approx every 3/4 sec)
    ;; counter reach 2^20 in 12s
    ;; so ~23 clocks/tick, IO overhead is basically zero
    ;; jsr display_counter

.done:
    rts

display_counter:
    lda #LCD_ReturnHome
    jsr lcd_instruction
    lda COUNTER+2
    jsr display_hex_byte
    lda COUNTER+1
    jsr display_hex_byte
    lda COUNTER
    jsr display_hex_byte
    rts

reset:
    jsr lcd_init
    jsr init_counter
.loop:
    ;;jsr display_counter ;; (for V1)
    jsr inc_counter ;; (for V2 or V3)
    jmp .loop

    org $fffc
    word reset
    word 0


