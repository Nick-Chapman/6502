
PORTB = $6000
PORTA = $6001
DDRB  = $6002 ; data-direction register
DDRA  = $6003

T1CL  = $6004
T1CH  = $6005

ACR   = $600b ; auxillary control register (times and shift)
PCR   = $600c ; peripheral control register (CA, CB)
IFR   = $600d ; interrupt flag register
IER   = $600e ; interrupt enable register

RS = %00000010 ; register select
RW = %00000100 ; read/write
E  = %00001000 ; enable

;;; switch back to B
RS_PORT = PORTB
RW_PORT = PORTB
ENABLE_PORT = PORTB

via_init:
    ;; set all pins on port-B and port-A as output
    lda #%11111111
    sta DDRB
    sta DDRA
    lda #%00000000 ; negative edge on any of CA1,CA2,CB1,CB2
    sta PCR
    ;;lda #%11000011 ; enable Timer1, CA1 and CA2
    lda #%11000000 ; enable just Timer1
    sta IER
    ;; Setup timer1
    lda #%01000000 ; timer-1 in free running mode
    sta ACR
    ;; 4E1E = 19998 (100/s), at 2 MhZ
    lda #$1e
    sta T1CL
    lda #$4e
    sta T1CH ;; starts timer
    rts
