    .setcpu "65C02"
    .feature c_comments
    .feature underline_in_numbers
    .feature string_escapes

RAM_TOP := $4000            ; top r/w memory
PYMON = 0                   ; emulation with no actual hardware

    .if PYMON
        .out "** Building debug ROM for pymon **"
GETC    := pymon_getc
    .else
GETC    := kb_getc
    .endif

PUTC  := lcd_putc           ; patched internally to route to pymon_putc

    .include "util.asm"
    .include "via.asm"
    .include "kb.asm"
    .include "lcd.asm"
    .include "sd.asm"
    .include "p8drv.asm"
    .include "morse.asm"
    .include "speaker.asm"
    .include "wozmon.asm"

    .segment "VECTORS"      ; see http://6502.org/tutorials/interrupts.html

nmi_vec:    .word 0
reset_vec:  .word hello     ; after RESB held low for 2 clocks
;TODO currently ignore BRK
irqbrk_vec: .word kb_isr    ; on irq or brk

    .segment "INIT"

hello:
        ldx #$ff
        txs                 ; init stack

        jsr via_init

    .if PYMON = 1
_morse_emit := morse_puts
    .else
_morse_emit := spk_morse
    .endif

        jsr spk_init

        SETWC morse_emit, _morse_emit

        lda #('A' | $80)    ; prosign "wait" elides A^S  ._...
        jsr morse_send
        lda #'S'
        jsr morse_send

        jsr kb_init         ; set up KB shift register to trigger interrupt
        jsr lcd_init        ; show a startup display

        cli                 ; enable interrupts by clearing the disable flag

        ; show splash screen
        SETWC LCDBUFP, splash
        jsr lcd_puts

        lda #' '
        jsr morse_send
        lda #'V'
        jsr morse_send       ; good to go ...-

        lda #$ff
        jsr delay

    .if 0
        ; play a song
        SETWC spk_notes, twinkle
        jsr spk_play
    .endif

        ; low level SD card init
        lda #'S'
        jsr PUTC
        lda #'D'
        jsr PUTC

        jsr sd_init         ; try to init SD card
        bne @woz

        ; Init ProDOS8 with SD card driver
        lda #'P'
        jsr PUTC
        lda #'8'
        jsr PUTC

        jsr p8_init
        bcs @woz

        ; show the file we read
        SETWC LCDBUFP, ScratchBuffer
        jsr lcd_puts

        jsr kb_getc     ; wait for key press

@woz:   jmp wozmon

    .if PYMON
pymon_putc:
        sta $f001
        rts
pymon_getc:
        lda $f004
        beq pymon_getc
        rts
    .endif

    .data

splash:
        .byte "    ___      ___    "
        .byte "   (o o)    (o o)   "
        .byte "  (  V  )  (  V  )  "
        .byte " /--m-m------m-m--/ "
        .byte 0

    .if 0
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
    .endif
