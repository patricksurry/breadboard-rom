/*
VIA is visible at (msb) 011. .... .... rrrr (lsb), ie. $6000 - $7FFF
with the lower four bits selecting register 0..15
*/

VIA = $6000
VIA_IORB = VIA + $0
VIA_IORA = VIA + $1
VIA_DDRB = VIA + $2
VIA_DDRA = VIA + $3
VIA_T1CL = VIA + $4
VIA_T1CH = VIA + $5
VIA_T1LL = VIA + $6
VIA_T1LH = VIA + $7
VIA_T2CL = VIA + $8
VIA_T2CH = VIA + $9
VIA_SR   = VIA + $a
VIA_ACR  = VIA + $b
VIA_PCR  = VIA + $c
VIA_IFR  = VIA + $d
VIA_IER  = VIA + $e
VIA_IORA_ = VIA + $f

/* test routine that rolls a bit back and forth forever on port b */
rollpbbit:
    .proc _rollpbbit
        inc
        sec
right:  sta VIA_IORB
        ror
        bne right
left:   sta VIA_IORB
        rol
        bne left
        bra right
    .endproc