;; TODO: lower case & prefix with via_

PORTB = $6000
PORTA = $6001
DDRB  = $6002 ; data-direction register
DDRA  = $6003

T1CL  = $6004
T1CH  = $6005

T2L   = $6008
T2H   = $6009

ACR   = $600b ; auxillary control register (timer/shift/latching)
PCR   = $600c ; peripheral control register (CA, CB)
IFR   = $600d ; interrupt flag register
IER   = $600e ; interrupt enable register

    via_ier_enable     = $80

    via_timer1         = $40
    via_timer2         = $20
    via_cb1            = $10
    via_cb2            = $08
    via_shift_register = $04
    via_ca1            = $02
    via_ca2            = $01
