    .setcpu "65C02"
    .feature c_comments
    .feature underline_in_numbers
    .feature string_escapes

    .segment "ZEROPAGE"
STRP:   .res 2
TMP:    .res 1

    .segment "CODE"

hello:
        lda #$ff            ; set both VIA ports for output
        sta VIA_DDRA
        sta VIA_DDRB

        jsr lcd_init

        lda #<startup
        sta STRP
        lda #>startup
        sta STRP+1
        jsr lcd_puts

        lda #2
        jsr delay

        lda #<(donut + 43*2 + 2)
        sta STRP
        lda #>(donut + 43*2 + 2)
        sta STRP+1
        lda #23
        jsr lcd_blit

forever:
        jmp forever
        ; jmp rollpbbit

startup:
        .byte "    ___      ___    "
        .byte "   (o o)    (o o)   "
        .byte "  (  V  )  (  V  )  "
        .byte " /--m-m------m-m--/ "
        .byte 0

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

    .include "via.asm"
    .include "lcd.asm"

; delay 9*(256*A+Y)+8 cycles = 2304 A + 9 Y + 20 cycles
; at 1MHz about 2.3 A ms + (9Y + 20) ms
delay:
        cpy #1      ; 2 cycles
        dey         ; 2 cycles
        sbc #0      ; 2 cycles
        bcs delay   ; 2 cycles + 1 if branch occurs (same page)
        rts         ; 6 cycles (+ 6 for call)

    .segment "VECTORS"      ; see http://6502.org/tutorials/interrupts.html

nmi_vec:    .word 0
reset_vec:  .word hello     ; after RESB held low for 2 clocks
irqbrk_vec: .word 0