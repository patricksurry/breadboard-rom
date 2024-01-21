/*
Writing IER is special:
- when hi bit clear, set bit 0-6 to clear corresponding IER bit
- when hi bit set, set bit 0-6 to set corresponding IER bit
*/

    /*
The Shift Register (SR) performs bidirectional serial data transfers on line CB2
Shift Register and Auxiliary Control Register Control ($0A, $0B)
(msb) x x x 0 1 1 x x  Shift in under control of external clock (CB1)

The SR counter will interrupt the microprocessor after each eight bits have been shifted in.
Reading or writing the SR resets IFR2 and initializes the counter to count another eight
pulses. Note that data is shifted during the first PHI2 clock cycle following the positive going edge
of the CB1 shift pulse. For this reason, data must be held stable during the first full cycle following
CB1 going high.

In this mode, CB1 serves as an input to the SR. In this way, an external device can load the SR at
its own pace. The SR counter will interrupt the microprocessor after each eight bits have been
shifted in. The SR counter does not stop the shifting operation. Its function is simply that of a pulse
counter. Reading or writing the SR resets IFR2 and initializes the counter to count another eight
pulses. Note that data is shifted during the first PHI2 clock cycle following the positive going edge
of the CB1 shift pulse. For this reason, data must be held stable during the first full cycle following
CB1 going high. See Figure 2-8

Interrupt Flag Register ($0D) bit 2 (0x04) - interrupt on complete 8 shifts
Interrupt Enable Register ($0E) set bit 2 to enable corresponding interrupt
    */

    .segment "ZEROPAGE"
KB_KEY7:    .res 1               ; bit 7 indicates key ready, with low seven bits of last chr
KB_KEY8:    .res 1               ; last full 8-bit character received

    .segment "CODE"

kb_init:
        lda #VIA_SR_IN_CB1      ; shift in using external (CB1) clock
        sta VIA_ACR
        lda #(VIA_IER_SET | VIA_INT_SR)     ; enable interrupt on shift complete
        sta VIA_IER
        rts

kb_getc:
        lda KB_KEY7
        bpl kb_getc
        eor #$80
        stz KB_KEY7
        rts

kb_isr:
        pha
        lda VIA_SR
        sta KB_KEY8
        ora #$80
        sta KB_KEY7
        pla
        rti