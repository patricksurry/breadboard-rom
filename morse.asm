
    .segment "ZEROPAGE"
    ; pointer to routine that outputs one morse 'bit'

morse_emit:  .res 2    ; pointer to output routine.

    ; C=1 indicates 'on' for dit/dah and C=0 means 'off' for silent
    ; Y contains the symbol length (1 for dit, 3 for dah; or 1, 2, 4 for silences)
    ; A and Y can be stomped
    ; for an LED or speaker the code can be very simple:
/*
my_emit:
        bcc wait        ; signal is normally off
        signal(on)
wait:   jsr morse_delay
        signal(off)
        rts
*/

    .segment "CODE"

morse_delay:
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
morse_puts:
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

morse_send:
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

    .if PYMON = 1
morse_test:
    .scope _morse_test
        lda #<morse_puts
        sta morse_emit
        lda #>morse_puts
        sta morse_emit+1
        ldx #0
next:   lda morse_test_data, X
        beq quit
        jsr morse_send
        inx
        bne next
quit:   brk

morse_test_data:
        .byte "6502 WHAT? SOS ", 'S'|$80, 'O'|$80, 'S', 0
    .endscope
    .endif

    .segment "DATA"
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
