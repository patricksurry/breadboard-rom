/*
originally we used shift-in under external clock, with the kbd generating the clock signal.

now the keyboard shifts in to a '595 register and strobes a data ready line CA1
*/

    .zeropage

KB_KEY7:    .res 1          ; bit 7 indicates key ready, with low seven bits of last chr
KB_KEY8:    .res 1          ; last full 8-bit character received

    .code

kb_init:    ; () -> nil const X, Y
    ; set up handshake mode and interrupt on data ready
        lda VIA_PCR
        and #(255-VIA_HS_CA1_MASK)
        ora #VIA_HS_CA1_RISE
        sta VIA_PCR
        lda #(VIA_IER_SET | VIA_INT_CA1)
        sta VIA_IER
        rts

kb_getc:    ; () -> A const X, Y
    ; wait for a keypress to appear in KB_KEY7 and return with bit 7 clear
        lda KB_KEY7     ; has top-bit set on ready
        bpl kb_getc
        and #$7f        ; clear top bit
        stz KB_KEY7     ; key taken
        rts

kb_isr:     ; () -> nil const A, X, Y
    ; handle interrupt when keyboard byte is available
        pha

        lda DVC_CTRL     ; stash current control bits
        pha
        lda DVC_DDR     ; stash current DDR bits
        pha

        ; select the KB shift-register for input
        DVC_SET_CTRL #DVC_SLCT_KBD, DVC_SLCT_MASK

        stz DVC_DDR      ; set data port for reading
        lda DVC_DATA     ; fetch the value

        sta KB_KEY8     ; store original
        ora #$80        ; flag key ready
        sta KB_KEY7     ; store with top bit set for getc

        ; restore control registers
        pla
        sta DVC_DDR
        pla
        sta DVC_CTRL     ; restore control register

        pla
        rti