
    cpu_cycles_per_ms = 4000 ;; Running with 4 MHz clock
    cpu_cycles_per_sec = 1000 * cpu_cycles_per_ms

    via_portb = $6000
    via_porta = $6001
    via_ddrb  = $6002
    via_ddra  = $6003
    via_t1cl  = $6004
    via_t1ch  = $6005

    via_t2l   = $6008
    via_t2h   = $6009

    via_acr   = $600b ; auxillary control register (timer/shift/latching)
    via_pcr   = $600c ; peripheral control register (CA, CB)
    via_ifr   = $600d ; interrupt flag register
    via_ier   = $600e ; interrupt enable register

    via_acr_timer1_freerunning = $40

    via_ier_enable     = $80

    via_timer1         = $40
    via_timer2         = $20
    via_cb1            = $10
    via_cb2            = $08
    via_shift_register = $04
    via_ca1            = $02
    via_ca2            = $01
