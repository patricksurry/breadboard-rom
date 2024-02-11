    .segment "ZEROPAGE"

XAM:    .res 2                          ; Last "opened" location
ST:     .res 2                          ; Store address
HEXV:   .res 2                          ; Hex value parsing
YSAV:   .res 1                          ; Used to see if hex value is given
MODE:   .res 1                          ; $00 = XAM, $74 = STOR, $B8 = BLOK XAM

IN    := $0200                          ; Input buffer

    .segment "WOZMON"

    .scope _wozmon
NOTCR:
                CMP     #BKSP
                BEQ     BACKSPACE
                CMP     #ESC
                BEQ     ESCAPE
                INY                    ; Advance text index.
                BPL     NEXTCHAR       ; Auto ESC if line longer than 127.
main:
ESCAPE:
                LDA     #'>'
                JSR     PRINT          ; Output prompt

GETLINE:
                LDA     #CR            ; Send CR
                JSR     PRINT

                LDY     #$01           ; Initialize text index.
BACKSPACE:      DEY                    ; Back up text index.
                BMI     GETLINE        ; Beyond start of line, reinitialize.

NEXTCHAR:
                jsr     GETC           ; wait for key, bit 7 clear
                STA     IN,Y           ; Add to text buffer.
                JSR     PRINT          ; Display character.
                CMP     #CR
                BNE     NOTCR          ; Not CR.

                LDY     #$FF           ; Reset text index.
                LDA     #$00           ; For XAM mode.
                TAX                    ; X=0.
SETBLOCK:
                ASL                    ; with A=':' leaves $B8 = $2E << 2
SETSTOR:
                ASL                    ; Leaves $74 = $3A(:) << 1 if setting STOR mode.
SETMODE:
                STA     MODE           ; 0 = XAM, $74 = STOR, $B8 = BLOK XAM.
BLSKIP:
                INY                    ; Advance text index.
NEXTITEM:
                LDA     IN,Y           ; Get character.
                CMP     #CR
                BEQ     GETLINE        ; Yes, done this line.
                CMP     #'.'
                BCC     BLSKIP         ; Skip delimiter (any char below '.')
                BEQ     SETBLOCK       ; Set BLOCK XAM mode.
                CMP     #':'
                BEQ     SETSTOR        ; Yes, set STOR mode.
                CMP     #'R'
                BEQ     RUN            ; Yes, run user program.
                STX     HEXV           ; $0000 -> HEXV
                STX     HEXV+1
                STY     YSAV           ; Save Y for comparison

NEXTHEX:
                LDA     IN,Y           ; Get character for hex test.
                EOR     #$30           ; Map digits to $0-9; 'A-F' to $71-76, 'a-f' to $11-16
                CMP     #10            ; Digit?
                BCC     DIG            ; Yes.
                ORA     #$60           ; LC => UC
                ADC     #$88           ; Map letter "A"-"F" to $FA-FF (note C=1)
                CMP     #$FA           ; Hex letter?
                BCC     NOTHEX         ; No, character not hex.
DIG:
                ASL
                ASL                    ; Hex digit to MSD of A.
                ASL
                ASL

                LDX     #$04           ; Shift count.
HEXSHIFT:
                ASL                    ; Hex digit left, MSB to carry.
                ROL     HEXV           ; Rotate into LSD.
                ROL     HEXV+1         ; Rotate into MSD's.
                DEX                    ; Done 4 shifts?
                BNE     HEXSHIFT       ; No, loop.
                INY                    ; Advance text index.
                BNE     NEXTHEX        ; Always taken. Check next character for hex.

NOTHEX:
                CPY     YSAV           ; Check if L, H empty (no hex digits).
                BEQ     ESCAPE         ; Yes, generate ESC sequence.

                BIT     MODE           ; Test MODE byte.
                BVC     NOTSTOR        ; B6=0 is STOR, 1 is XAM and BLOCK XAM.

                LDA     HEXV           ; LSD's of hex data.
                STA     (ST,X)         ; Store current 'store index'.
                INC     ST             ; Increment store index.
                BNE     NEXTITEM       ; Get next item (no carry).
                INC     ST+1           ; Add carry to 'store index' high order.
TONEXTITEM:     JMP     NEXTITEM       ; Get next command item.

RUN:
                JMP     (XAM)         ; Run at current XAM index.

NOTSTOR:
                BMI     XAMNEXT        ; B7 = 0 for XAM, 1 for BLOCK XAM.

                LDX     #$02           ; Byte count.
SETADR:         LDA     HEXV-1,X       ; Copy hex data to
                STA     ST-1,X         ;  'store index'.
                STA     XAM-1,X        ; And to 'XAM index'.
                DEX                    ; Next of 2 bytes.
                BNE     SETADR         ; Loop unless X = 0.

NXTPRNT:
                BNE     PRDATA         ; NE means no address to print.
                LDA     #CR            ; CR.
                JSR     PRINT          ; Output it.
                LDA     XAM+1          ; 'Examine index' high-order byte.
                JSR     PRBYTE         ; Output it in hex format.
                LDA     XAM            ; Low-order 'examine index' byte.
                JSR     PRBYTE         ; Output it in hex format.
                LDA     #':'
                JSR     PRINT          ; Output it.

PRDATA:
                LDA     #' '           ; Blank.
                JSR     PRINT          ; Output it.
                LDA     (XAM,X)        ; Get data byte at 'examine index'.
                JSR     PRBYTE         ; Output it in hex format.
XAMNEXT:        STX     MODE           ; 0 -> MODE (XAM mode).
                LDA     XAM
                CMP     HEXV           ; Compare 'examine index' to hex data.
                LDA     XAM+1
                SBC     HEXV+1
                BCS     TONEXTITEM     ; Not less, so no more data to output.

                INC     XAM
                BNE     MOD8CHK        ; Increment 'examine index'.
                INC     XAM+1

MOD8CHK:
                LDA     XAM            ; Check low-order 'examine index' byte
                AND     #$07           ; For MOD 8 = 0
                BPL     NXTPRNT        ; Always taken.

PRBYTE:
                PHA                    ; Save A for LSD.
                LSR
                LSR
                LSR                    ; MSD to LSD position.
                LSR
                JSR     PRHEX          ; Output hex digit.
                PLA                    ; Restore A.
                AND     #$0F           ; Mask LSD for hex print.

PRHEX:
                ORA     #$30           ; Add "0".
                CMP     #$3A           ; Digit?
                BMI     PRINT          ; Yes, output it.
                ADC     #$06           ; Add offset for letter.

PRINT:          pha                    ; safe PUTC
                phy
                phx
                jsr     PUTC
                plx
                ply
                pla
                RTS                    ; Return.
    .endscope