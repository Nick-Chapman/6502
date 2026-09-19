
PORTB = $6000
PORTA = $6001
DDRB  = $6002 ; data-direction register
DDRA  = $6003

ACR   = $600b ; auxillary control register (times and shift)
PCR   = $600c ; peripheral control register (CA, CB)
IFR   = $600d ; interrupt flag register
IER   = $600e ; interrupt enable register

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

via_init:
    ;; set all pins on port-B as output
    lda #%11111111
    sta DDRB
    ;; set most significant 3 pins on port-A as output
    ;; and least sig for LED
    lda #%11100001
    sta DDRA

    lda #%00000000 ; negative edge on any of CA1,CA2,CB1,CB2
    sta PCR

    lda #%01111111 ; disable all
    sta IER
    lda #%10000011 ; enable CA1 and CA2
    sta IER
    lda #$ff ; zero all interrupt flags
    sta IFR
    rts

lcd_init:
    lda #LCD_FunctionSet_8bit_2lines
    jsr lcd_instruction
    lda #LCD_DisplayOn_CursorOn_NoBlink
    jsr lcd_instruction
    lda #LCD_ClearDisplay
    jsr lcd_instruction
    rts

lcd_wait:
    pha
    ;; set port-B mode to input
    stz DDRB
    ;; RS=0, RW=1, E=1
    lda PORTA
    and #(~RS)
    ora #(RW | E)
    sta PORTA
.loopBusy:
    ;; read busy flag
    lda PORTB
    ;; test busy bit
    and #$80
    bne .loopBusy
    ;; restore port-B mode to output
    lda #$ff
    sta DDRB
    pla
    rts

lcd_instruction: ; A->()
    jsr lcd_wait
    sta PORTB
    lda PORTA
    ;; RS=0. RW=0, E=1
    and #(~(RS | RW))
    ora #E
    sta PORTA
    ;; trigger E neg-edge
    eor #E
    sta PORTA
    rts

lcd_emitChar: ; A->()
    jsr lcd_wait
    sta PORTB
    lda PORTA
    ;; RS=1, RW=0, E=1
    and #(~RW)
    ora #(RS | E)
    sta PORTA
    ;; trigger E neg-edge
    eor #E
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
    inc COUNTER+1
    bne .done
    inc COUNTER+2
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
    jsr via_init
    jsr lcd_init
    jsr init_counter
    cli ; enable IRQ
.loop:
    jsr display_counter
    jmp .loop

toggle_led:
    lda PORTA
    eor #%1
    sta PORTA
    rts

nmi:
    rti

irq:
    pha
    lda IFR
    ror
    bcs .ca2
    ror
    bcs .ca1
.hang:
    ;; IRQ fired; but IFR has 0s for ca1/2. how possible?
    ;; do nothing
    jmp .done
.ca1:
    jsr toggle_led
    inc COUNTER+2
    lda #%00000010
    sta IFR
    jmp .done
.ca2:
    inc COUNTER+1
    lda #%00000001
    sta IFR
    jmp .done
.done:
    pla
    rti

    org $fffa
    word nmi
    word reset
    word irq
