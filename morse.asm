
    .zeropage
    ; pointer to routine that outputs one morse 'bit'

morse_emit:  .res 2    ; pointer to output routine.

/*
We can emit morse code on any desired output device (speaker, LED, text, ...)
by providing a morse_emit routine.  This routine simply sends on/off signals
for a specified duration.  The on symbols are the normal dit/dah (dot/dash)
and the off symbols represent spaces between symbols, characters and words.

The routine receives C=on/off in the carry bit with Y=1,2,3,4 as the duration units.
It can use morse_delay(Y) to wait for the appropriate duration.
It needn't preserve any registers.  For an LED or speaker pin it can be very simple (below).
See also morse_puts as an example of emitting a text representation like "... --- ..."

simple_emitter: ; (C, Y) -> nil
        bcc wait        ; signal is normally off
        signal(on)
wait:   jsr morse_delay
        signal(off)
        rts
*/

    .code

morse_delay:    ; (Y) -> nil const X
    ; delay for about Y * 100ms where <= 6
    .scope _morse_delay
        lda #42
        clc
longer: dey
        beq done
        adc #42         ; A = 42*Y
        bra longer
done:   jmp delay
    .endscope

    .if PYMON = 1
morse_puts: ; (C, Y) -> nil const X
    ; a more complex morse_emit routine that converts to a string of dash, dot and space characters
    .scope _morse_puts
        bcc off     ; output space(s) for off
        cpy #3      ; else on, dah or dit
        bne dit
        lda #'-'    ; dah
        bra on
dit:    lda #'.'    ; dit
on:     jmp PUTC    ; return from there

off:    tya
        lsr
        tay
        beq done
loop:   lda #' '    ; output Y // 2 spaces
        phy
        jsr PUTC
        ply
        dey
        bne loop
done:   rts
    .endscope
    .endif

morse_send: ; (A) -> nil
    ; Output chr A in morse code.  The ascii characters [0-9A-Za-z] and [space] are recognized.
    ; All other characters are sent as the error prosign (........) aka H^H.
    ; Normally each character is followed by an intra letter space (silent dah)
    ; but setting A's msb shortens that to an intra symbol space (silent dit)
    ; so that you can elide multiple characters to form arbitrary patterns.
    ; For example sending 'S'|$80, 'O'|$80, 'S' yields the SOS procedural sign (prosign)

    ; morse_emit should point at a routine which handles output of individual symbols
    ; essentially setting your target output device on or off for N time units as described above
    .scope _morse_send

        asl
        php         ; remember hi bit in the carry
        lsr         ; clear hi bit
        cmp #' '
        bne notspc
        plp         ; discard elide flag
        ldy #4      ; off(4) to extend prev inter-letter delay from 3 to 7 (silent dah-dit-dah)
        clc         ; signal off
        bra end     ; skip to end with
notspc: cmp #$40    ; letters vs numbers
        bmi notaz
        and #$1f    ; A-Z/a-z is $41-$5A/$61-7A, mask to $01-$1A
        dec
        cmp #26
        bpl error
        tay         ; A is index 0-25
        lda morse_az,y
        bra prefix

notaz:  sec
        sbc #$30        ; 0-9 is $30-39
        bcc error
        cmp #10
        bpl error
        tay
        lda morse_09,y

prefix: ldy #6          ; at most 6+1 bits to shift out
skip:   asl
        bcs emit        ; found leading 1 ?
        dey
        bpl skip

error:  lda #0          ; error is 8 dits ........
        ldy #7

        ; shift out Y+1 msb of A
emit:   asl             ; top bit => C
        pha
        phy
        ldy #3
        bcs on
        ldy #1
        sec             ; signal on
on:     jsr end         ; output on(1 or 3)
        ldy #1
        clc             ; signal off
        jsr end         ; output off(1) for inter-symbol delay (silent dit)
        ply
        pla
        dey
        bpl emit
        plp             ; original high bit set means elide
        bcc normal      ; no elide, add inter-character delay.  note C=0 already for off
        rts             ; if eliding just inter-symbol off(1) after chr (silent dit)
normal: ldy #2          ; usually extend +off(2) (silent dah) ...
end:                    ; ... then ' ' adds off(4) to give off(1)+off(2)+off(4) = off(7) between words
        jmp (morse_emit)    ; jump to output routine and return from there
    .endscope


morse_nibble: ; (A) -> nil
    ; send the lower four bits of A as morse sequence; hi-bit to elide with next
        ldy #$4
        asl
        php         ; stash carry (msb)
        asl
        asl
        asl
        ldy #3      ; send 3+1 bits
        jmp _morse_send::emit


morse_byte: ; (A) -> nil
    ; send the byte A as a morse sequence (msb first), by eliding the top and bottom nibbles
        pha
        lsr
        lsr
        lsr
        lsr
        ora #%1000_0000 ; high bit to elide
        jsr morse_nibble
        pla
        and #$0f
        jmp morse_nibble


    .if PYMON = 1
morse_test: ; () -> nil
    .scope _morse_test
        SETWC morse_emit, morse_puts
        ldx #0
next:   lda morse_test_data, X
        beq bits
        jsr morse_send
        inx
        bne next

bits:   lda #' '
        jsr morse_send
        lda #$0c
        jsr morse_nibble
        lda #' '
        jsr morse_send
        lda #$59
        jsr morse_byte
        lda #' '
        jsr morse_send
        brk

morse_test_data:
        .byte "6502 WHAT? SOS ", 'S'|$80, 'O'|$80, 'S', 0
    .endscope
    .endif

    .data
        ; morse characters stored one per byte, right-justified with a leading 1 prefix
        ; we shift left to find the first 1, and the remaining bits represent dit/dah symbols
        ; all the basic chars are 6 symbols or less, and any other can be formed by
        ; composition (eliding the normal intra-character space)

morse_az:
        .byte %000001_01    ; A .-
        .byte %0001_1000    ; B -...
        .byte %0001_1010    ; C -.-.
        .byte %00001_100    ; D -..
        .byte %0000001_0    ; E .
        .byte %0001_0010    ; F ..-.
        .byte %00001_110    ; G --.
        .byte %0001_0000    ; H ....
        .byte %000001_00    ; I ..
        .byte %0001_0111    ; J .---
        .byte %00001_101    ; K -.-
        .byte %0001_0100    ; L .-..
        .byte %000001_11    ; M --
        .byte %000001_10    ; N -.
        .byte %00001_111    ; O ---
        .byte %0001_0110    ; P .--.
        .byte %0001_1101    ; Q --.-
        .byte %00001_010    ; R .-.
        .byte %00001_000    ; S ...
        .byte %0000001_1    ; T -
        .byte %00001_001    ; U ..-
        .byte %0001_0001    ; V ...-
        .byte %00001_011    ; W .--
        .byte %0001_1001    ; X -..-
        .byte %0001_1011    ; Y -.--
        .byte %0001_1100    ; Z --..
morse_09:
        .byte %001_11111    ; 0 -----
        .byte %001_01111    ; 1 .----
        .byte %001_00111    ; 2 ..---
        .byte %001_00011    ; 3 ...--
        .byte %001_00001    ; 4 ....-
        .byte %001_00000    ; 5 .....
        .byte %001_10000    ; 6 -....
        .byte %001_11000    ; 7 --...
        .byte %001_11100    ; 8 ---..
        .byte %001_11110    ; 9 ----.
