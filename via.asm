/*
VIA is visible at (msb) 011. .... .... rrrr (lsb), ie. $6000 - $7FFF
with the lower four bits selecting register 0..15
*/

VIA := $6000
VIA_IORB := VIA + $0    ; port a/b latches
VIA_IORA := VIA + $1
VIA_DDRB := VIA + $2    ; data direction for port a/b pins (1=output, 0=input`)
VIA_DDRA := VIA + $3
VIA_T1C  := VIA + $4    ; timer 1 lo/hi counter
VIA_T1L  := VIA + $6    ; timer 1 latches
VIA_T2C  := VIA + $8    ; timer 2 lo/hi counter
VIA_SR   := VIA + $a    ; shift register (timers, shift, port a/b latching)
VIA_ACR  := VIA + $b    ; aux control register
VIA_PCR  := VIA + $c    ; peripheral control register (r/w handshake mode for C[AB][12])
VIA_IFR  := VIA + $d    ; interrupt flags
VIA_IER  := VIA + $e    ; write bit 7 hi + bits to set, or bit 7 lo + bits to clear
VIA_IORA_ := VIA + $f

; three VIA_SR control bits  ...x xx..
VIA_SR_MASK     = %0001_1100

VIA_SR_DISABLED = %0000_0000
VIA_SR_IN_T2    = %0000_0100
VIA_SR_IN_PHI2  = %0000_1000
VIA_SR_IN_CB1   = %0000_1100
VIA_SR_OUT_T2FR = %0001_0000     ; T2 free-running
VIA_SR_OUT_T2   = %0001_0100
VIA_SR_OUT_PHI2 = %0001_1000
VIA_SR_OUT_CB1  = %0001_1100

; two VIA_T1 control bits xx.. ....
VIA_T1_MASK     = %1100_0000

VIA_T1_ONCE     = %0000_0000
VIA_T1_CTS      = %0100_0000
VIA_T1_PB7_ONCE = %1000_0000
VIA_T1_PB7_CTS  = %1100_0000

VIA_IER_SET = %1000_0000    ; set accompanying set bits in IER
VIA_IER_CLR = %0000_0000    ; clr accompanying set bits in IER

VIA_INT_ANY = %1000_0000    ; set on any enabled interrupt
VIA_INT_T1  = %0100_0000    ; set on T1 time out
VIA_INT_T2  = %0010_0000    ; set on T2 time out
VIA_INT_CB1 = %0001_0000    ; set on CB1 active edge
VIA_INT_CB2 = %0000_1000    ; set on CB2 active edge
VIA_INT_SR  = %0000_0100    ; set on 8 shifts complete
VIA_INT_CA1 = %0000_0010    ; set on CA1 active edge
VIA_INT_CA2 = %0000_0001    ; set on CA2 active edge


.if 0
/* test routine that rolls a bit back and forth forever on port b */
rollpbbit:
    .scope _rollpbbit
        inc
        sec
right:  sta VIA_IORB
        ror
        bne right
left:   sta VIA_IORB
        rol
        bne left
        bra right
    .endscope
.endif