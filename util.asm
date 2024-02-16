BKSP    = $08                           ; special char constants
TAB     = $09
LF      = $0A
CR      = $0D
ESC     = $1B

    .define DELAY2  cmp #0          ; 2 cycles
    .define DELAY3  cmp $0          ; 3 cycles
    .define DELAY4  cmp $0,X        ; 4 cycles
    .define DELAY6  cmp ($0,X)      ; 6 cycles
    .define DELAY12 jsr _delay12     ; 6 + 6 = 12 cycles

    .macro SETWC adr, val
        lda #<(val)
        sta adr
        lda #>(val)
        sta adr+1
    .endmac

    .macro SETDWC adr, val
        SETWC adr, val & $ffff
        SETWC adr+2, val >> 16
    .endmac

    .code

delay:  ; (A, Y) -> nil; X const
    ; delay 9*(256*A+Y)+12 cycles = 2304 A + 9 Y + 12 cycles
    ; at 1MHz about 2.3 A ms + (9Y + 12) us
    ; max delay 9*65535+12 is about 590ms
    ; credit http://forum.6502.org/viewtopic.php?f=12&t=5271&start=0#p62581
        cpy #1      ; 2 cycles
        dey         ; 2 cycles
        sbc #0      ; 2 cycles
        bcs delay   ; 2 cycles + 1 if branch occurs (same page)
_delay12:
        rts         ; 6 cycles (+ 6 for call)
