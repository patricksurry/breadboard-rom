    .setcpu "65C02"
    .feature c_comments
    .feature underline_in_numbers
    .feature string_escapes

/*
VIA is enabled at 011. .... .... rrrr, ie. $6000 - $7FFF
the lower 4 bits select register
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

    .segment "CODE"

hello:
        lda #$ff
        sta VIA_DDRB
        inc
        sec
right:  sta VIA_IORB
        ror
        bne right
left:   sta VIA_IORB
        rol
        bne left
        bra right

    .segment "VECTORS"      ; see http://6502.org/tutorials/interrupts.html

nmi_vec:    .word 0
reset_vec:  .word hello     ; after RESB held low for 2 clocks
irqbrk_vec: .word 0