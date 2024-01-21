    .setcpu "65C02"
    .feature c_comments
    .feature underline_in_numbers
    .feature string_escapes

SLOW_CLOCK = 0

    .segment "ZEROPAGE"
STRP:   .res 2
TMP:    .res 1

    .segment "CODE"

hello:
        lda #$ff            ; set both VIA ports for output
        sta VIA_DDRA
        sta VIA_DDRB
        lda #$7f
        sta VIA_IFR         ; clear all interrupt flags (write 1 to bit 0-6)
        sta VIA_IER         ; disable all interrupts

        jsr kb_init         ; set up KB shift register to trigger interrupt
        jsr lcd_init        ; show a startup display

        lda #<startup
        sta STRP
        lda #>startup
        sta STRP+1
        lda #(donut - startup)
        jsr lcd_puts

        lda #$ff
        jsr delay
        lda #$ff
        jsr delay

        lda #<(donut + 43*2 + 2)
        sta STRP
        lda #>(donut + 43*2 + 2)
        sta STRP+1
        lda #23
        sta LCDPAD
        jsr lcd_blit

forever:
        jsr kb_getc
        jsr lcd_putc
        jmp forever

; delay 9*(256*A+Y)+8 cycles = 2304 A + 9 Y + 20 cycles
; at 1MHz about 2.3 A ms + (9Y + 20) us
delay:
    .if .not SLOW_CLOCK
        cpy #1      ; 2 cycles
        dey         ; 2 cycles
        sbc #0      ; 2 cycles
        bcs delay   ; 2 cycles + 1 if branch occurs (same page)
    .endif
        rts         ; 6 cycles (+ 6 for call)

    .include "via.asm"
    .include "kb.asm"
    .include "lcd.asm"

startup:
        .byte "    ___      ___    "
        .byte "   (o o)    (o o)   "
        .byte "  (  V  )  (  V  )  "
        .byte " /--m-m------m-m--/ "

donut:      ; https://www.a1k0n.net/2011/07/20/donut-math.html
        .byte "                                           "
        .byte "            @@@@@@@@                       "
        .byte "        ####$$$$$$$$@@@$$                  "
        .byte "      *******#####$$$$$$$$$$               "
        .byte "     =====!!!!***#####$$$$$$$#             "
        .byte "    :;;;;;;==!!!****########$###           "
        .byte "    ::~~::;;;=!!=!!*****#########          "
        .byte "    --,,-~~~:;;;===!******#*#####**        "
        .byte "    ,.....,-~~:;:====!!*!***********       "
        .byte "    .........--~::;;===!!!*!********!      "
        .byte "    ..........,--~:;;;;==!!!!!*****!!      "
        .byte "     ...........,-~~::;;===!=!!!!!!!!=     "
        .byte "      ......,,-..,,-~::;;;====!=!!!!!=     "
        .byte "      .,-~~~;;##..,,-~~::;;;==========;    "
        .byte "       .-~;=*#$$@...,-~~:::;;;;;======;    "
        .byte "         -;!!*#$$#...,--~~:::;;;;;;;;;:    "
        .byte "          -;=!**!=~...,---~:::::;;;;;:     "
        .byte "           ,:=:;;:-...,,,--~~~:::::::~     "
        .byte "             -:;:~-.....,,--~~~~~~~~~      "
        .byte "               ,--,.....,,,---------       "
        .byte "                 .........,,,,,,,,,        "
        .byte "                    .............          "
        .byte "                                           "

    .include "wozmon.asm"

    .segment "VECTORS"      ; see http://6502.org/tutorials/interrupts.html

nmi_vec:    .word 0
reset_vec:  .word hello     ; after RESB held low for 2 clocks
;TODO kb_isr detect brk v irq?
irqbrk_vec: .word 0         ; on irq or brk
