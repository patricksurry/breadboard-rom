    .setcpu "65C02"
    .feature c_comments
    .feature underline_in_numbers
    .feature string_escapes

PYMON = 0   ; emulation with no actual hardware
DEBUG = 0   ; include additional debugging code

    .if PYMON
        .out "** Building debug ROM for pymon **"
GETC    := pymon_getc
    .else
GETC    := kb_getc
    .endif

PUTC  := lcd_putc           ; patched internally to route to pymon_putc

BKSP    = $08                           ; special char constants
TAB     = $09
LF      = $0A
CR      = $0D
ESC     = $1B

    .include "via.asm"
    .include "kb.asm"
    .include "lcd.asm"
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

    .if PYMON = 1
_morse_emit := morse_puts
    .else
_morse_emit := spk_morse
    .endif

        jsr spk_init

        lda #<_morse_emit
        sta morse_emit
        lda #>_morse_emit
        sta morse_emit+1

        lda #('A' | $80)    ; prosign "wait" elides A^S
        jsr morse_send
        lda #'S'
        jsr morse_send

        jsr kb_init         ; set up KB shift register to trigger interrupt
        jsr lcd_init        ; show a startup display

        cli                 ; enable interrupts by clearing the disable flag

        lda #<splash        ; show splash screen
        sta LCDBUFP
        lda #>splash
        sta LCDBUFP+1
        lda #(donut - splash)
        jsr lcd_puts

        lda #' '
        jsr morse_send
        lda #'K'
        jsr morse_send       ; good to go

.if DEBUG
        lda #'e'
        jsr PUTC
        lda VIA_IER
        jsr _wozmon::PRBYTE

        lda #'f'
        jsr PUTC
        lda VIA_IFR
        jsr _wozmon::PRBYTE

        lda #'a'
        jsr PUTC
        lda VIA_ACR
        jsr _wozmon::PRBYTE

        lda #'s'
        jsr PUTC
        lda VIA_SR
        jsr _wozmon::PRBYTE
.endif

        jmp _wozmon::main

    .if 0
        lda #<(donut + 43*2 + 2)
        sta LCDBUFP
        lda #>(donut + 43*2 + 2)
        sta LCDBUFP+1
        lda #23
        sta LCDPAD
        jsr lcd_blit

forever:
        jmp forever
    .endif

; delay 9*(256*A+Y)+12 cycles = 2304 A + 9 Y + 12 cycles
; at 1MHz about 2.3 A ms + (9Y + 12) us
; max delay 9*65535+12 is about 590ms
; credit http://forum.6502.org/viewtopic.php?f=12&t=5271&start=0#p62581
delay:
        cpy #1      ; 2 cycles
        dey         ; 2 cycles
        sbc #0      ; 2 cycles
        bcs delay   ; 2 cycles + 1 if branch occurs (same page)
        rts         ; 6 cycles (+ 6 for call)

    .if PYMON
pymon_putc:
        sta $f001
        rts
pymon_getc:
        lda $f004
        beq pymon_getc
        rts
    .endif

    .segment "DATA"

splash:
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
