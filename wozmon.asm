    .zeropage

XAM:    .res 2                          ; Last "opened" location
ST:     .res 2                          ; Store address
HEXV:   .res 2                          ; Hex value parsing
YSAV:   .res 1                          ; Used to see if hex value is given
MODE:   .res 1                          ; $00 = XAM, $74 = STOR, $B8 = BLOK XAM

IN    := $0200                          ; Input buffer

    .segment "WOZMON"

_NOTCR:
                CMP     #BKSP
                BEQ     _BACKSPACE
                CMP     #ESC
                BEQ     _ESCAPE
                INY                    ; Advance text index.
                BPL     _NEXTCHAR      ; Auto ESC if line longer than 127.
wozmon:
_ESCAPE:
                LDA     #'>'
                JSR     PRINT          ; Output prompt

GETLINE:
                LDA     #CR            ; Send CR
                JSR     PRINT

                LDY     #$01           ; Initialize text index.
_BACKSPACE:     DEY                    ; Back up text index.
                BMI     GETLINE        ; Beyond start of line, reinitialize.

_NEXTCHAR:
                jsr     GETC           ; wait for key, bit 7 clear
                STA     IN,Y           ; Add to text buffer.
                JSR     PRINT          ; Display character.
                CMP     #CR
                BNE     _NOTCR         ; Not CR.

                LDY     #$FF           ; Reset text index.
                LDA     #$00           ; For XAM mode.
                TAX                    ; X=0.
_SETBLOCK:
                ASL                    ; with A=':' leaves $B8 = $2E << 2
_SETSTOR:
                ASL                    ; Leaves $74 = $3A(:) << 1 if setting STOR mode.
_SETMODE:
                STA     MODE           ; 0 = XAM, $74 = STOR, $B8 = BLOK XAM.
_BLSKIP:
                INY                    ; Advance text index.
_NEXTITEM:
                LDA     IN,Y           ; Get character.
                CMP     #CR
                BEQ     GETLINE        ; Yes, done this line.
                CMP     #'.'
                BCC     _BLSKIP        ; Skip delimiter (any char below '.')
                BEQ     _SETBLOCK      ; Set BLOCK XAM mode.
                CMP     #':'
                BEQ     _SETSTOR       ; Yes, set STOR mode.
                CMP     #'R'
                BEQ     _RUN           ; Yes, run user program.
                STX     HEXV           ; $0000 -> HEXV
                STX     HEXV+1
                STY     YSAV           ; Save Y for comparison

_NEXTHEX:
                LDA     IN,Y           ; Get character for hex test.
                EOR     #$30           ; Map digits to $0-9; 'A-F' to $71-76, 'a-f' to $11-16
                CMP     #10            ; Digit?
                BCC     _DIG           ; Yes.
                ORA     #$60           ; LC => UC
                ADC     #$88           ; Map letter "A"-"F" to $FA-FF (note C=1)
                CMP     #$FA           ; Hex letter?
                BCC     _NOTHEX        ; No, character not hex.
_DIG:
                ASL
                ASL                    ; Hex digit to MSD of A.
                ASL
                ASL

                LDX     #$04           ; Shift count.
_HEXSHIFT:
                ASL                    ; Hex digit left, MSB to carry.
                ROL     HEXV           ; Rotate into LSD.
                ROL     HEXV+1         ; Rotate into MSD's.
                DEX                    ; Done 4 shifts?
                BNE     _HEXSHIFT      ; No, loop.
                INY                    ; Advance text index.
                BNE     _NEXTHEX       ; Always taken. Check next character for hex.

_NOTHEX:
                CPY     YSAV           ; Check if L, H empty (no hex digits).
                BEQ     _ESCAPE        ; Yes, generate ESC sequence.

                BIT     MODE           ; Test MODE byte.
                BVC     _NOTSTOR       ; B6=0 is STOR, 1 is XAM and BLOCK XAM.

                LDA     HEXV           ; LSD's of hex data.
                STA     (ST,X)         ; Store current 'store index'.
                INC     ST             ; Increment store index.
                BNE     _NEXTITEM      ; Get next item (no carry).
                INC     ST+1           ; Add carry to 'store index' high order.
_TONEXTITEM:    JMP     _NEXTITEM      ; Get next command item.

_RUN:
                JMP     (XAM)         ; Run at current XAM index.

_NOTSTOR:
                BMI     _XAMNEXT       ; B7 = 0 for XAM, 1 for BLOCK XAM.

                LDX     #$02           ; Byte count.
_SETADR:        LDA     HEXV-1,X       ; Copy hex data to
                STA     ST-1,X         ;  'store index'.
                STA     XAM-1,X        ; And to 'XAM index'.
                DEX                    ; Next of 2 bytes.
                BNE     _SETADR         ; Loop unless X = 0.

_NXTPRNT:
                BNE     _PRDATA        ; NE means no address to print.
                LDA     #CR            ; CR.
                JSR     PRINT          ; Output it.
                LDA     XAM+1          ; 'Examine index' high-order byte.
                JSR     PRBYTE         ; Output it in hex format.
                LDA     XAM            ; Low-order 'examine index' byte.
                JSR     PRBYTE         ; Output it in hex format.
                LDA     #':'
                JSR     PRINT          ; Output it.

_PRDATA:
                LDA     #' '           ; Blank.
                JSR     PRINT          ; Output it.
                LDA     (XAM,X)        ; Get data byte at 'examine index'.
                JSR     PRBYTE         ; Output it in hex format.
_XAMNEXT:       STX     MODE           ; 0 -> MODE (XAM mode).
                LDA     XAM
                CMP     HEXV           ; Compare 'examine index' to hex data.
                LDA     XAM+1
                SBC     HEXV+1
                BCS     _TONEXTITEM    ; Not less, so no more data to output.

                INC     XAM
                BNE     _MOD8CHK       ; Increment 'examine index'.
                INC     XAM+1

_MOD8CHK:
                LDA     XAM            ; Check low-order 'examine index' byte
                AND     #$07           ; For MOD 8 = 0
                BPL     _NXTPRNT       ; Always taken.

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
