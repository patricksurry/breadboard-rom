
    .segment "ZEROPAGE"

spk_duty: .res 2

; Beethoven's fifth GGGEb|FFFD played |-1114|-1114

    .segment "CODE"

spk_tone:
    .scope _spk_tone
        ; A = note index, A0 = 0, A4 = 48
        ldy #0
noct:   cmp #12             ; Y = A // 12 (octave shifts)
        bmi found
        sec
        sbc #12
        iny
        bra noct
found:  tax
        lda spk_octave, x   ; get hi/lo from octave lookup
        sta spk_duty
        lda spk_octave+12, x
        sta spk_duty+1
halve:  dey                 ; halve y times
        bmi done
        lsr spk_duty+1
        ror spk_duty
        bra halve
done:   lda VIA_ACR
        and #(255-VIA_T1_MASK)
        ora #VIA_T1_PB7_CTS ; enable PB7 square wave
        sta VIA_ACR

        lda spk_duty
        sta VIA_T1C
        lda spk_duty+1
        sta VIA_T1C+1
        rts
    .endscope

spk_morse:
    .scope _spk_morse
        bcc wait        ; signal is normally off
        phy
        lda #48
        jsr spk_tone
        ply
wait:   jsr morse_delay
        ; fall through to spk_off
    .endscope

spk_off:
        lda VIA_ACR
        and #(255-VIA_T1_MASK)
        ora #VIA_T1_ONCE    ; disable PB7 square wave
        sta VIA_ACR
        rts

spk_octave:
        .byte $06   ; A     0 27.5Hz  N=18182
        .byte $09   ; A# Bb 0 29.1Hz  N=17161
        .byte $46   ; B     1 30.9Hz  N=16198
        .byte $b9   ; C     1 32.7Hz  N=15289
        .byte $5f   ; C# Db 1 34.6Hz  N=14431
        .byte $35   ; D     1 36.7Hz  N=13621
        .byte $38   ; D# Eb 1 38.9Hz  N=12856
        .byte $67   ; E     1 41.2Hz  N=12135
        .byte $be   ; F     1 43.7Hz  N=11454
        .byte $3b   ; F# Gb 1 46.2Hz  N=10811
        .byte $dc   ; G     1 49.0Hz  N=10204
        .byte $9f   ; G# Ab 1 51.9Hz  N=9631
    ; hi bytes
        .byte $47
        .byte $43
        .byte $3f
        .byte $3b
        .byte $38
        .byte $35
        .byte $32
        .byte $2f
        .byte $2c
        .byte $2a
        .byte $27
        .byte $25



spk_beep:
    ; enable speaker
        ;TODO
spk_wait:
    ; wait for X * 100ms
    .scope _spk_wait
more:   lda #42     ; about 100ms
        ldy #0
        jsr delay
        dex
        bne more
    ; disable speaker
        ;TODO
        rts
    .endscope


/*
tone of the i-th key on a 88 key piano, 49 = A-440
freq = 440 * pow(2, (i-49)/12)
at clock freq F=1Mhz
cycles = F/freq = 1e6/440 * pow(2, i-49/12)
VIA timer should be half = 1e6/440 * pow(2, i-49/12 - 1)

from math import pow

clock = 1e6
notes = "A A# B C C# D D# E F F# G G#".split()
for i in range(0, 12): # 88):
    freq = 440 * pow(2, (i-48)/12.)
    duty = round(clock/freq/2)
    octave = (i+10)//12
    note = notes[i%12]
    print(f".byte ${duty & 0xff:02x}, ${duty >> 8:02x}   ; {note:3s}{octave} {freq:.1f}Hz  N={duty}")

*/