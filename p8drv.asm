    .include "api.s"

    .import InitMLI, RegisterMLI, ReserveMLI, GoMLI, NoClock

ClockDriver = NoClock
    .export ClockDriver

ScratchParams := $100       ; scratch space for r/w params
ScratchBuffer := $400       ; scratch space for file read
FileBuffer := $800

        .code
p8_init:
        lda #'i'
        jsr lcd_putc

        jsr InitMLI         ; init MLI

        lda #'m'
        jsr lcd_putc

        ; install the SD device driver as d0s0
        SETWC DEVICE_DRV, p8_sd_drv
        lda #%0000_1111      ; d0s000 rwfs
        sta DEVICE_UNT
        jsr RegisterMLI

        ; mark everything from RAM end upwards as unusable (not RAM)
        ldx #>RAM_TOP
@mark:  jsr ReserveMLI
        inx
        cpx #$C0            ; ProDOS maps lower 48K
        bne @mark

        ldx #>ScratchParams
        jsr ReserveMLI

        .data
p8_online_params:
        .byte 2, 0          ; request all devices
        .word ScratchBuffer ; 256 byte output buffer

        .code
        lda #'n'
        jsr lcd_putc

        jsr GoMLI
        .byte MLI_ONLINE
        .word p8_online_params

        bcc p8_set_prefix
        jmp p8_init_fail

        .data
p8_set_prefix_params:
        .byte 1
        .word ScratchParams    ; volume prefix

        .code
p8_set_prefix:
        lda #'$'
        jsr lcd_putc
        lda ScratchBuffer
        jsr PRBYTE

        lda ScratchBuffer
        and #$0f            ; get vol name length
        tax
        inc
        sta ScratchParams   ; write vol name with / prefix
@cp:    lda ScratchBuffer,x
        sta ScratchParams+1,x
        dex
        bne @cp
        lda #'/'
        sta ScratchParams+1

        jsr lcd_putc

        jsr GoMLI
        .byte MLI_SET_PREFIX
        .word p8_set_prefix_params

        bcc p8_open
        jmp p8_init_fail

p8_open_params:
        .byte 3
        .word PathName
        .word FileBuffer
open_fh_offset = * - p8_open_params
        .res 1              ; filehandle result
open_params_len = * - p8_open_params
PathName:
        .byte 6, "README"

        .code
p8_open:          ; try reading the file
        lda #'o'
        jsr lcd_putc

        ; copy the params to scratch so MLI can write FH
        ldx #0
@cp:    lda p8_open_params,x
        sta ScratchParams,x
        inx
        cpx #open_params_len
        bne @cp

        jsr GoMLI
        .byte MLI_OPEN
        .word ScratchParams

        bcc p8_read
        jmp p8_init_fail

        .data
p8_read_params:
        .byte 4
read_fh_offset = * - p8_read_params
        .res 1
        .word ScratchBuffer
        .word $400      ; request bytes
read_actual_offset = * - p8_read_params
        .res 2          ; actual bytes
read_params_len = * - p8_read_params

        .code
p8_read:
        lda #'r'
        jsr lcd_putc

        ; copy param block to scratch so we can include file handle
        lda ScratchParams + open_fh_offset
        tay
        ldx #0
@cp:    lda p8_read_params,x
        sta ScratchParams,x
        inx
        cpx #read_params_len
        bne @cp
        ; update the FH
        sty ScratchParams + read_fh_offset

        jsr GoMLI
        .byte MLI_READ
        .word ScratchParams

        ; hack to zero-terminate the (long) string we read
        clc
        lda ScratchParams + read_actual_offset
        adc #<ScratchBuffer
        sta LCDBUFP
        lda ScratchParams + read_actual_offset + 1
        adc #>ScratchBuffer
        sta LCDBUFP+1
        lda #0
        sta (LCDBUFP)

        ; leave final carry value and return
p8_init_fail:
        rts

        .code
p8_sd_drv:
        ldx DEVICE_CMD

        lda #'v'
        jsr lcd_putc
        txa
        jsr PRBYTE

        bne @next

        ; DEVICE_CMD_STATUS return volume size in (Y,X)
        ; assume all SD volumes are constant size $ffff blocks (~32Mb)
        ldy #$ff
        ldx #$ff
        bra @ok

@next:  cpx #DEVICE_CMD_FORMAT
        beq @ok         ; format is a no-op

        ; for read/write, set up sd_blk from the ProDOS block index
        lda DEVICE_BLK
        sta sd_blk
        lda DEVICE_BLK+1
        sta sd_blk+1
        lda DEVICE_UNT  ; high nibble is the volume number
        lsr
        lsr
        lsr
        lsr
        sta sd_blk+2
        stz sd_blk+3

        lda DEVICE_BUF
        sta sd_bufp
        lda DEVICE_BUF+1
        sta sd_bufp+1

        cpx #DEVICE_CMD_READ
        bne @write

@read:  lda #'{'
        jsr lcd_putc
        jsr sd_readblock
        lda #'}'
        jsr lcd_putc
        bra @ok

@write: jsr sd_writeblock

@ok:    lda #0
        clc
        rts

@err:   lda #$27    ; IO error
        sec
        rts
