    .setcpu "65C02"
    .feature c_comments
    .feature underline_in_numbers
    .feature string_escapes

BKSP    = $08                           ; special char constants
TAB     = $09
LF      = $0A
CR      = $0D
ESC     = $1B

FF      = $0F   ;todo

    .zeropage
txt_strz:       .res 2  ; input zero-terminated string
txt_outz:       .res 2  ; output buffer for zero-terminated string
txt_digrams:    .res 2  ; digram lookup table (128 2-byte pairs)

_cnt:
_col:   .res 1
_row:   .res 1

WIDTH   = 20    ; <256
HEIGHT  = 3
TEST    = 1

    .code

_out:       ; (A) -> nil
    ; write a chr to output buffer and inc position
        sta (txt_outz)
        inc txt_outz
        bne @done
        inc txt_outz+1
@done:  rts


_inc_strz:
        inc txt_strz    ; inc pointer
        bne _rts
_inc_strz1:
        inc txt_strz+1
_rts:   rts

_iny_strz:
        iny
        bne _rts
        beq _inc_strz1


txt_wrap:   ; (txt_strz) -> nil
    ; replace selected whitespace chrs with newline / formfeed
    ; to give nicer wrapping on a small screen
    ; modifies string at txt_strz in place

        ; txt_strz points at current char, with screen coord (_col, _row)
        stz _col
        stz _row

@scan:  ldy #0          ; seek forward within row for next natural break
        ldx _col        ; y tracks char offset, x tracks updated _col

        bit _rts        ; set overflow with RTS = #$60 (first pass V=1, second V=0)

@skip:  cpx #WIDTH      ; skip past sequence of ws (first pass) then non-ws (second pass)
        bpl @eol
        lda (txt_strz),y
        beq @end        ; end of string?
        cmp #' '+1      ; is char whitespace (' ' or below)
        bvc @chk2       ; second pass?
        bmi @cont       ; continue first pass on ws
        clv             ; else start second pass
        bra @skip

@chk2:  bmi @adv        ; end second pass on ws
                        ;TODO handle tab which could bump col more than one
@cont:  inx             ; update col and offset
        iny
        bne @skip       ;TODO what happens with y overflow?

        ; advance natural break point
@adv:   tya         ; add offset y to txt_strz
        clc
        adc txt_strz
        sta txt_strz
        bcc @chknl
        inc txt_strz+1
@chknl: lda (txt_strz)  ; if curr chr is NL, force a break
        cmp #CR
        beq @eol
        cmp #LF
        beq @eol
        stx _col    ; update current natural break
        bra @scan   ; keep looking

@eol:   stz _col    ; reset _col, increment _row
        ldx #LF     ; normally insert LF, but FF at end of page
        lda _row
        inc
        cmp #HEIGHT
        bne @nopg
        lda #0
        ldx #FF     ; new page insert FF
@nopg:  sta _row    ; current _row
        phx         ; stash brk chr
        lda (txt_strz)
        cmp #' '+1
        bmi @soft

        ; hard break, skip ahead y and carry on
        plx         ; discard brk chr
        ldx #0
        bra @adv    ; advance breakpoint with offset y, at column x=0

@soft:  pla         ; insert our break char and skip past it
        sta (txt_strz)
        jsr _inc_strz
        bra @scan

@end:   rts


txt_unwoozy:        ; (txt_strz, txt_outz) -> nil
    ; undo woozy prep for dizzy
        ldy #0
        ldx #0      ; shift status, X=0, X=1 capitalize, X=2 all caps
@loop:  lda (txt_strz),y
        beq @done
        cmp #$0d    ; $b,c: set shift status
        bpl @out
        cmp #$0b
        bmi @nobc
        sbc #$0a
        tax
        bra @next
@nobc:  cmp #$08    ; $3-8: rle next char
        bpl @out
        cmp #$03
        bmi @out
        dec         ; last iter in fall thru
        sta _cnt
        jsr _iny_strz
        lda (txt_strz),y
@rpt:   jsr _out
        dec _cnt
        bne @rpt
@out:   cmp #'A'
        bmi @notAZ
        cmp #'Z'+1
        bpl @notAZ
        ora #%0010_0000     ; lowercase
        pha
        lda #' '            ; add a space
        jsr _out
        pla
@notAZ: cpx #0
        beq @putc
        cmp #'a'
        bmi @notaz
        cmp #'z'+1
        bpl @notaz
        and #%0101_1111     ; capitalize
        cpx #2      ; all caps?
        beq @putc
@notaz: ldx #0      ; else end shift
@putc:  jsr _out
@next:  jsr _iny_strz
        bra @loop

@done:  sta (txt_outz)  ; store the terminator
        rts


txt_undizzy:        ; (txt_strz, txt_digrams, txt_outz) -> nil
    ; uncompress a zero-terminated dizzy string at txt_strz using txt_digrams lookup
    ; writes uncompressed data to txt_outz (including the terminator)

        ldx #0          ; track stack depth
@nextz: lda (txt_strz)  ; get encoded char
@chk7:  bmi @subst      ; is it a digraph (bit 7 set)?
        beq @done       ; if 0 we're done
        jsr _out
@stk:   cpx #0          ; any stacked items?
        beq @cont
        dex
        pla             ; pop latest
        bra @chk7

@subst: sec
        rol             ; index*2+1 for second char in digram
        tay
        lda (txt_digrams),y
        inx             ; track stack depth
        pha             ; stack the second char
        dey
        lda (txt_digrams),y   ; fetch the first char of the digram
        bra @chk7       ; keep going

@cont:  jsr _inc_strz
        bra @nextz

@done:  sta (txt_outz)  ; store the terminator
        rts


    .if TEST

    .code

test_buf = $400

PUTC:   sta $f001   ; pymon character output, or could write buffer etc
        rts

test_start:

test_undizzy:
        lda #<test_digrams
        sta txt_digrams
        lda #>test_digrams
        sta txt_digrams+1

        ; undizzy: dzy -> buf
        lda #<test_dzy
        sta txt_strz
        lda #>test_dzy
        sta txt_strz+1

        lda #<test_buf
        sta txt_outz
        lda #>test_buf
        sta txt_outz+1

        jsr txt_undizzy

        ; unwoozy: buf -> dzy

        lda #<test_buf
        sta txt_strz
        lda #>test_buf
        sta txt_strz+1

        lda #<test_dzy
        sta txt_outz
        lda #>test_dzy
        sta txt_outz+1

        jsr txt_unwoozy

        ; wrap: dzy

        lda #<test_dzy
        sta txt_strz
        lda #>test_dzy
        sta txt_strz+1

        jsr txt_wrap        ; wrap it

        lda #<test_dzy
        sta txt_strz
        lda #>test_dzy
        sta txt_strz+1

        ldy #0              ; print it
@loop:  lda (txt_strz),y
        beq @done
        cmp #FF
        bne @putc
        lda #LF
        jsr PUTC
        lda #'*'
        jsr PUTC
        lda #LF
@putc:  jsr PUTC
        iny
        bne @loop
        inc txt_strz+1
        bra @loop
@done:  brk

    .data
test_digrams:
        .byte $68, $65, $72, $65, $6f, $75, $54, $80, $69, $6e, $73, $74, $84, $67, $6e, $64
        .byte $69, $74, $6c, $6c, $49, $6e, $65, $72, $61, $72, $2e, $0b, $4f, $66, $0b, $79
        .byte $8f, $82, $65, $73, $6f, $72, $49, $73, $59, $82, $6f, $6e, $6f, $6d, $54, $6f
        .byte $61, $6e, $6f, $77, $6c, $65, $61, $73, $76, $65, $61, $74, $74, $80, $41, $81
        .byte $0b, $9e, $65, $6e, $42, $65, $67, $65, $61, $89, $65, $64, $41, $87, $54, $68
        .byte $90, $9f, $69, $64, $74, $68, $65, $81, $73, $61, $61, $64, $52, $6f, $69, $63
        .byte $9b, $ac, $6c, $79, $63, $6b, $27, $81, $41, $4c, $65, $74, $50, $b0, $6c, $6f
        .byte $69, $73, $67, $68, $4f, $6e, $43, $98, $90, $b3, $41, $74, $49, $74, $65, $ad
        .byte $88, $74, $88, $68, $75, $74, $61, $6d, $6f, $74, $a8, $8a, $8d, $83, $57, $c1
        .byte $69, $85, $4d, $61, $53, $74, $41, $6e, $72, $6f, $81, $93, $57, $68, $45, $87
        .byte $8e, $83, $69, $72, $76, $8b, $48, $ab, $63, $74, $ae, $96, $65, $85, $61, $9c
        .byte $61, $79, $53, $65, $20, $22, $61, $6c, $61, $85, $69, $95, $6b, $65, $72, $61
        .byte $8a, $83, $46, $72, $45, $78, $b6, $a3, $27, $74, $72, $82, $c0, $9a, $55, $70
        .byte $2c, $41, $52, $65, $a0, $cd, $72, $79, $97, $83, $41, $53, $6c, $64, $e1, $96
        .byte $75, $81, $a9, $65, $63, $65, $57, $d6, $b9, $74, $69, $f4, $bc, $8a, $0b, $64
        .byte $43, $68, $6e, $74, $50, $88, $96, $65, $98, $74, $4f, $c2, $44, $69, $9d, $65
test_dzy:
        .byte $0b, $73, $fb, $77, $80, $81, $4e, $65, $8c, $62, $79, $93, $0b, $43, $6f, $b7
        .byte $73, $ac, $6c, $0b, $43, $d7, $2c, $57, $80, $81, $4f, $9e, $72, $73, $48, $d7
        .byte $46, $82, $87, $46, $92, $74, $75, $6e, $91, $8a, $54, $81, $9b, $f0, $a6, $47
        .byte $6f, $ee, $2c, $a7, $82, $b9, $be, $93, $52, $75, $6d, $6f, $81, $64, $a7, $9d
        .byte $53, $fb, $ce, $6f, $45, $f9, $8b, $9f, $4e, $65, $d2, $d9, $a1, $41, $67, $61
        .byte $84, $8d, $c9, $67, $af, $93, $53, $61, $a9, $97, $57, $92, $6b, $e0, $43, $d7
        .byte $8d, $49, $57, $69, $89, $a2, $94, $72, $45, $79, $91, $a6, $48, $61, $87, $73
        .byte $8d, $fe, $81, $d4, $4d, $65, $c7, $43, $96, $6d, $61, $87, $73, $8e, $20, $31
        .byte $4f, $72, $20, $32, $57, $92, $64, $73, $8d, $49, $53, $68, $82, $ee, $57, $8c
        .byte $6e, $94, $a7, $9d, $0b, $49, $4c, $6f, $6f, $6b, $bd, $ba, $b1, $83, $46, $d1
        .byte $85, $46, $69, $9c, $4c, $b5, $74, $8b, $73, $8e, $45, $61, $63, $68, $57, $92
        .byte $64, $2c, $53, $6f, $94, $27, $89, $48, $d7, $97, $45, $f9, $8b, $da, $0b, $6e
        .byte $92, $9e, $dc, $22, $41, $73, $da, $6e, $65, $22, $97, $44, $c8, $86, $75, $b8
        .byte $68, $be, $ef, $da, $0b, $6e, $92, $aa, $22, $2e, $20, $28, $0b, $73, $68, $82
        .byte $ee, $94, $47, $b5, $ca, $75, $b2, $2c, $54, $79, $70, $65, $da, $80, $6c, $70
        .byte $22, $46, $92, $53, $fb, $47, $a1, $8b, $db, $48, $84, $74, $73, $29, $2e, $00

    .endif
