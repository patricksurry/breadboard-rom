/*
exchange data with SD card by pairing a '595 shift register with the VIA one.

trigger an exchange by writing to VIA SR using shift-out under PHI2
this uses CB1 as clock (@ half the PHI2 rate) and CB2 as data.
The SD card wants SPI mode 0 where the clock has a rising edge after the data is ready.
We use a D-flip flop to invert and delay the CB1 clock by half a PHI2 cycle,
see http://forum.6502.org/viewtopic.php?t=1674

*/

    .zeropage

sd_cmdp:  .res 2

    .code

sd_init:
  ; Let the SD card boot up, by pumping the clock with SD CS disabled

  ; We need to apply around 80 clock pulses with CS and MOSI high.
  ; Normally MOSI doesn't matter when CS is high, but the card is
  ; not yet is SPI mode, and in this non-SPI state it does care.

        lda VIA_ACR
        and #(255 - VIA_SR_MASK)
        ora #VIA_SR_OUT_PHI2
        sta VIA_ACR

        ldx #20         ; 20 * 8 = 160 clock transitions
        lda #$ff
@warm:  sta VIA_SR      ; clock 8 hi-bits out without chip enable (CS hi)
        dex
        bne @warm

        lda #<sd_cmd0
        sta sd_cmdp
        lda #>sd_cmd0
        sta sd_cmdp+1
        jsr sd_command

        rts

sd_command:     ; (sd_cmdp) -> A
    ; write five bytes from (sd_cmdp), wait for result with a 0 bit
        DVC_SET_CTRL #DVC_SLCT_SD, DVC_SLCT_MASK
        ldy #0
@next:  lda (sd_cmdp),y
        sta VIA_SR
        iny
        cpy #5
        bne @next
@wait:  lda DVC_DATA
        cmp #$ff
        beq @wait
        pha
        lda #DVC_SLCT_MASK
        trb DVC_CTRL
        pla
        rts

sd_cmd0:
        .byte $40, $00, $00, $00, $00, $95
