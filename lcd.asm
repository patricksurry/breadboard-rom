/*
Provides a simple interface to a small LCD controlled by a HD44780 or equivalent

    lcd_init    wake up the LCD and send sequence of initialization commands
    lcd_cls     clear screen (fill with space chr $20) and set xy to 0,0
    lcd_setxy   set cursor position to LCDX = 0..LCD_WIDTH-1, LCDY = 0..LCD_HEIGHT-1
    lcd_getxy   get current cursor position into LCDX, LCDY
    lcd_putc    put chr A at the current position and advance with appropriate wrapping
    lcd_puts    put zero-terminated string in STRP with wrapping
    lcd_blit    fill the screen from a buffer in STRP skipping A bytes of padding between rows

The hardware exposes a 8-pin data bus (or optionally a 4-pin interface),
with a RW pin (read=1; write=0), a RS pin (command=0; data=1) and an Enable pin
which is pulsed high to execute a command.

The physical layout of the LCD screen is defined by the constants
LCD_WIDTH (16, 20, 40) and LCD_HEIGHT (1, 2, 4).
NB. a 16x1 (type 1) should be configured here as 8 x 2 but
Note that the underlying logical hardware model is always 40 x 2 (80 bytes)
indexed as two logical rows $0 .. $27, $40 .. $67 with bit 7 ($40) giving the logical row,
and the lower six bits counting 0...$27 = 39 along it.
It auto-increments from $27 to $40 and $67 to $0 but doesn't know anything about the
physical layout of the LCD itself so need to understand how the logical layout maps to the physical display.

All LCDs have the first physical row starting at address 0
LCDs with 2 or 4 physical rows have the second row starting at $40 (as does 16x1 type 1)
LCDs with four physical rows have the third and forth rows starting at 0+LCD_WIDTH, $40+LCD_WIDTH
This leads to very weird default wrapping and off-screen characters if you write sequentially

See detail at https://web.alfredstate.edu/faculty/weimandn/lcd/lcd_addressing/lcd_addressing_index.html

The underlying controller interface supports these actions:

Write commands (RS = 0, RW = 0)

data          command
0000 0000     clear/home (fill display with $20 and set DDRAM addr to $0)
0000 001-     home (DDRAM addr to $0, cursor home)
0000 01SD     Entry mode Cursor (1=inc, 0=dec after DDRAM r/w), Shift (1=on, 0=off)
              Sets the effect of subsequent DD RAM read or write operations.
              Sets the cursor move direction and specifies or not to shift the display.
              These operations are performed during data read and write.
0000 1DCB     Display (1=on, 0=off), Cursor (1=on, 0=off), and cursor Blink (1=on, 0=off)
0001 SD--     Shift (1=display, 0=cursor); Direction (right=1, 0=left)
              Shifts cursor position or display to the right or left without writing or reading display data.
              In a 2-line display, the cursor moves to the 2nd line when it passes the 40th digit of the 1st line.
              Notice that the 1st and 2nd line displays will shift at the same time.
              When the displayed data is shifted repeatedly each line only moves horizontally.
              The 2nd line of the display does not shift into the 1st line position.
001D NF--     Data (1=8-bit, 0=4-bit); Number display lines (1=2, 0=1), Font type (1=5x11, 0=5x8)
01.. ....     Set character graphics address 0-63
1... ....     Set DDRAM (display offset) 0-$67

Read commands (RS = 0, RW = 1)

B... ....     Read DDRAM offset 0-$67 and busy flag (internal operation in progress)

Data commands

RS = 1, RW = 0: write data to current DDRAM or CGRAM address
RS = 1, RW = 1: read data from current DDRAM or CGRAM address

The destination (CGRAM or DDRAM) is determined by the most recent `Set RAM Address' command
*/

LCD_WIDTH = 20
LCD_HEIGHT = 4


; NB. the most common 16x1 display has its single physical row mapped to 0..$7, $40..$47
; as if it was 8x2.  This type isn't handled here.

LCD_DATA := VIA_IORB    ; LCD D0..7 data pins mapped to VIA PORTB D0..7
LCD_DDR  := VIA_DDRB    ; set to 0 for read DATA, #$ff to write DATA

LCD_CTRL := VIA_IORA    ; RS, RW, E mapped to port A pins 5, 6, 7

LCD_RS = %0010_0000     ; register select 0 = command, 1 = data
LCD_RW = %0100_0000     ; read = 1, write = 0       ** NB we assume RW > RS below
LCD_E  = %1000_0000     ; toggle high to read/write

; Four actions based on RW/RS combinations
LCD_CMD     = 0
LCD_STATUS  = LCD_RW
LCD_WRITE   = LCD_RS
LCD_READ    = LCD_RS | LCD_RW

LCD_WAKE    = $30       ; wake value

    .segment "ZEROPAGE"
LCDX:       .res 1
LCDY:       .res 1
LCDPAD:     .byte 0      ; for lcd_blit

    .segment "CODE"

lcd_do:
    ; A = action (LCD_CMD, LCD_STATUS, LCD_READ, LCD_WRITE)
    ; Y = data (for LCD_CMD and LCD_WRITE)
    ; on return A contains result for LCD_STATUS or LCD_READ
    .scope _lcd_do
        phx
        tax
        stz LCD_DDR         ; set data for read
        lda #LCD_STATUS     ; wait for LCD ready
        sta LCD_CTRL
        ora #LCD_E
        sta LCD_CTRL        ; enable to read status
busy:   lda LCD_DATA
        bmi busy            ; wait for bit 7 to clear

        stx LCD_CTRL        ; set up new action, clearing E
        cpx #LCD_RW         ; RW=1 (read)?
        bmi wc              ; else write or cmd

        cpx #LCD_STATUS
        beq done            ; A already has status result (LCD addr)

        lda #LCD_READ | LCD_E   ; else it's read
        sta LCD_CTRL        ; pulse on
        lda LCD_DATA        ; fetch result
        bra off             ; pulse off and return

nowait: phx                 ; alternate entry for no wait init
        tax
        stx LCD_CTRL

wc:     lda #$ff
        sta LCD_DDR         ; set data pins for write
        sty LCD_DATA        ; write the operand
        txa
        ora #LCD_E
        sta LCD_CTRL
off:    stx LCD_CTRL        ; pulse off
done:   plx
        rts
    .endscope


lcd_init:           ; wake up the LCD and send sequence of initialization commands
    .scope _lcd_init
        ldx #3      ; beetlejuice, beetlejuice, beetlejuice
wakeywakey:
        ; assume that manual reset is at least 40ms+ after power on, so skip explicit initial wait
        lda #LCD_CMD
        ldy #LCD_WAKE
        jsr _lcd_do::nowait
        cpx #3
        bne short
        ; wait 5ms+ after first call
        lda #2      ; 2*2304 + 9*42 + 20 = 5006 cycles
        ldy #42
        bra wait
short:  ; wait 160us+ after second and third call
        lda #0      ; 2*0 + 9*16 + 20 = 164 cycles
        ldy #16
wait:   jsr delay
        dex
        bne wakeywakey

next:   ldy init_seq,x      ; x=0 on entry
        cpy #$ff
        beq done
        lda #LCD_CMD
        jsr lcd_do
        inx
        bne next
done:   stz LCDX
        stz LCDY
        rts

init_seq:
        .byte %0011_1000     ; 8-bit, 2-line, 5x8 font
        .byte %0000_0000     ; clear/home
        .byte %0000_0110     ; after r/w inc DDRAM, no display shift
        .byte %0000_1100     ; display on, cursor off, blink off
        .byte $ff
    .endscope


lcd_cls:        ; clear screen (fill with space chr $20) and set xy to 0,0
        lda #LCD_CMD
        ldy #0
        jsr lcd_do
        stz LCDX
        stz LCDY
        rts


lcd_getxy:      ; get the current physical screen position LCDX = 0..LCD_WIDTH-1(*), LCDY = 0..LCD_HEIGHT-1
                ; (*) offscreen coords can have LCDX >= LCD_WIDTH
    .scope _lcd_getxy
        lda #LCD_STATUS
        jsr lcd_do          ; fetch A = DDRAM addr
        ldy #0
.if ::LCD_HEIGHT >= 2
        cmp #$40            ; second logical row?
        bmi top
        iny                 ; second logical row => odd physical row
        and #$3f            ; clear bit 6
top:
.if ::LCD_HEIGHT = 4
        cmp #LCD_WIDTH      ; remainder of physical row split at LCD_WIDTH
        bmi left
        iny
        iny
        sec
        sbc #LCD_WIDTH
left:
.endif
.endif
        sta LCDX
        sty LCDY
        rts
    .endscope


lcd_setxy:      ; set cursor position to LCDX = 0..LCD_WIDTH-1, LCDY = 0..LCD_HEIGHT-1
    .scope _lcd_setxy
        lda LCDX
        ldy LCDY
.if ::LCD_HEIGHT = 4
        cpy #2
        bmi left
        dey
        dey
        clc
        adc #LCD_WIDTH      ; rows mapped to right slice of logical layout start at LCD_WIDTH
left:
.if ::LCD_HEIGHT >= 2
        cpy #0
        beq top
        ora #$40            ; rows mapped to bottom row of logical layout start at +$40
top:
.endif
.endif
        ora #$80            ; set bit 7 for "set DDRAM offset" command
        tay
        lda #LCD_CMD
        jsr lcd_do
        rts
    .endscope


lcd_putc:       ; put chr A at the current position and advance position with proper wrapping
    .scope _lcd_putc
        tay
        lda #LCD_WRITE      ; write character
        jsr lcd_do
        inc LCDX            ; update position for next write
        lda LCDX
        cmp #LCD_WIDTH      ; end of line?
        bmi done
        stz LCDX            ; wrap to start of next line
        inc LCDY
        lda LCDY
        cmp #LCD_HEIGHT     ; past last row?
        bmi setxy
        stz LCDY
setxy:  jsr lcd_setxy
done:   rts
    .endscope


lcd_puts:       ; put A < 256 chars from STRP (preserved) starting at current position
    .scope
        sta TMP
        ldy #0
loop:   lda (STRP),y
        phy
        jsr lcd_putc
        ply
        iny
        cpy TMP
        bne loop
done:   rts
    .endscope


lcd_blit:   ; fill the screen from a buffer in STRP (stomped) skipping LCDPAD bytes between rows
    .scope _lcd_blit
        stz LCDX            ; go to start of screen
        stz LCDY
        lda #LCD_CMD
        ldy #$80            ; bit 7 for "set DDRAM offset" command, 0 for address
        jsr lcd_do
loop:   lda #LCD_WIDTH
        jsr lcd_puts
        lda STRP
        clc
        adc #LCD_WIDTH
        bcc pad
        inc STRP+1
        clc
pad:    adc LCDPAD
        sta STRP
        bcc next
        inc STRP+1
next:   lda LCDY            ; wrapped back to start?
        bne loop
        rts
    .endscope
