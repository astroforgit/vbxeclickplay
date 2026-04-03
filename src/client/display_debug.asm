detect_vbxe
        lda #<$D600
        sta zp_vbxe_base
        lda #>$D600
        sta zp_vbxe_base+1
        ldy #VBXE_CORE_VER
        lda #0
        sta (zp_vbxe_base),y
        lda (zp_vbxe_base),y
        cmp #FX_CORE_VER
        beq dv_ok

        lda #<$D700
        sta zp_vbxe_base
        lda #>$D700
        sta zp_vbxe_base+1
        ldy #VBXE_CORE_VER
        lda #0
        sta (zp_vbxe_base),y
        lda (zp_vbxe_base),y
        cmp #FX_CORE_VER
        beq dv_ok
        clc
        rts
dv_ok
        sec
        rts

show_fullscreen
        memb_on 0
        ldx #0

        lda #<(XDLC_OVOFF|XDLC_MAPOFF|XDLC_RPTL|XDLC_OVADR|XDLC_CHBASE|XDLC_OVATT)
        sta MEMB_XDL,x
        inx
        lda #>(XDLC_OVOFF|XDLC_MAPOFF|XDLC_RPTL|XDLC_OVADR|XDLC_CHBASE|XDLC_OVATT)
        sta MEMB_XDL,x
        inx
        lda #24-1
        sta MEMB_XDL,x
        inx
        lda #<VRAM_SCREEN
        sta MEMB_XDL,x
        inx
        lda #>VRAM_SCREEN
        sta MEMB_XDL,x
        inx
        lda #0
        sta MEMB_XDL,x
        inx
        lda #<SCR_STRIDE
        sta MEMB_XDL,x
        inx
        lda #>SCR_STRIDE
        sta MEMB_XDL,x
        inx
        lda #CHBASE_VAL
        sta MEMB_XDL,x
        inx
        lda #$11
        sta MEMB_XDL,x
        inx
        lda #$FF
        sta MEMB_XDL,x
        inx

        lda #<(XDLC_GMON|XDLC_MAPOFF|XDLC_RPTL|XDLC_OVADR|XDLC_OVATT)
        sta MEMB_XDL,x
        inx
        lda #>(XDLC_GMON|XDLC_MAPOFF|XDLC_RPTL|XDLC_OVADR|XDLC_OVATT)
        sta MEMB_XDL,x
        inx
        lda img_height
        sec
        sbc #1
        sta MEMB_XDL,x
        inx
        lda img_vram
        sta MEMB_XDL,x
        inx
        lda img_vram+1
        sta MEMB_XDL,x
        inx
        lda img_vram+2
        sta MEMB_XDL,x
        inx
        lda #<320
        sta MEMB_XDL,x
        inx
        lda #>320
        sta MEMB_XDL,x
        inx
        lda #$11
        sta MEMB_XDL,x
        inx
        lda #$FF
        sta MEMB_XDL,x
        inx

        lda #<(XDLC_OVOFF|XDLC_END)
        sta MEMB_XDL,x
        inx
        lda #>(XDLC_OVOFF|XDLC_END)
        sta MEMB_XDL,x

        memb_off

        ldy #VBXE_XDL_ADR0
        lda #<VRAM_XDL
        sta (zp_vbxe_base),y
        iny
        lda #>VRAM_XDL
        sta (zp_vbxe_base),y
        iny
        lda #0
        sta (zp_vbxe_base),y

        ldy #VBXE_VCTL
        lda #VC_XDL_ENABLED|VC_XCOLOR
        sta (zp_vbxe_base),y
        rts

print_record
        sta ICBAL
        stx ICBAH
        sty ICBLL
        lda #0
        sta ICBLH
        lda #$09
        sta ICCOM
        ldx #0
        jmp CIOV

nibble_to_hex
        and #$0F
        cmp #10
        bcc nibble_digit
        clc
        adc #6
nibble_digit
        clc
        adc #'0'
        rts

write_dbg_hex
        pha
        lsr
        lsr
        lsr
        lsr
        jsr nibble_to_hex
        sta dbg_line,x
        inx
        pla
        and #$0F
        jsr nibble_to_hex
        sta dbg_line,x
        rts

report_failure
        lda #$22
        sta SDMCTL

        lda debug_stage
        cmp #$11
        beq report_no_vbxe
        cmp #$12
        bcs report_img_fail

        lda #<msg_text_fail
        ldx #>msg_text_fail
        ldy #msg_text_fail_end-msg_text_fail
        jsr print_record
        jmp report_stage

report_no_vbxe
        lda #<msg_no_vbxe
        ldx #>msg_no_vbxe
        ldy #msg_no_vbxe_end-msg_no_vbxe
        jsr print_record
        jmp report_dbg

report_img_fail
        lda #<msg_img_fail
        ldx #>msg_img_fail
        ldy #msg_img_fail_end-msg_img_fail
        jsr print_record

report_stage
        lda debug_stage
        cmp #1
        bne report_stage_2
        lda #<msg_stage_text_open
        ldx #>msg_stage_text_open
        ldy #msg_stage_text_open_end-msg_stage_text_open
        jsr print_record
        jmp report_dbg
report_stage_2
        cmp #2
        bne report_stage_3
        lda #<msg_stage_text_wait
        ldx #>msg_stage_text_wait
        ldy #msg_stage_text_wait_end-msg_stage_text_wait
        jsr print_record
        jmp report_dbg
report_stage_3
        cmp #3
        bne report_stage_4
        lda #<msg_stage_text_read
        ldx #>msg_stage_text_read
        ldy #msg_stage_text_read_end-msg_stage_text_read
        jsr print_record
        jmp report_dbg
report_stage_4
        cmp #$12
        bne report_stage_5
        lda #<msg_stage_img_open
        ldx #>msg_stage_img_open
        ldy #msg_stage_img_open_end-msg_stage_img_open
        jsr print_record
        jmp report_dbg
report_stage_5
        cmp #$13
        bne report_stage_6
        lda #<msg_stage_hdr
        ldx #>msg_stage_hdr
        ldy #msg_stage_hdr_end-msg_stage_hdr
        jsr print_record
        jmp report_dbg
report_stage_6
        cmp #$14
        bne report_stage_7
        lda #<msg_stage_pal
        ldx #>msg_stage_pal
        ldy #msg_stage_pal_end-msg_stage_pal
        jsr print_record
        jmp report_dbg
report_stage_7
        cmp #$15
        bne report_dbg
        lda #<msg_stage_pix
        ldx #>msg_stage_pix
        ldy #msg_stage_pix_end-msg_stage_pix
        jsr print_record

report_dbg
        lda debug_stage
        ldx #3
        jsr write_dbg_hex
        lda debug_dstats
        ldx #9
        jsr write_dbg_hex
        lda debug_fn_error
        ldx #15
        jsr write_dbg_hex
        lda debug_connected
        ldx #21
        jsr write_dbg_hex
        lda debug_bytes_lo
        ldx #27
        jsr write_dbg_hex
        lda debug_bytes_hi
        ldx #33
        jsr write_dbg_hex
        lda debug_rx_len
        ldx #39
        jsr write_dbg_hex
        lda #<dbg_line
        ldx #>dbg_line
        ldy #dbg_line_end-dbg_line
        jsr print_record
        rts

report_text_success
        lda #<msg_text_ok
        ldx #>msg_text_ok
        ldy #msg_text_ok_end-msg_text_ok
        jsr print_record
        jsr report_dbg
        lda #<msg_payload
        ldx #>msg_payload
        ldy #msg_payload_end-msg_payload
        jsr print_record
        lda #<rx_buffer
        ldx #>rx_buffer
        ldy debug_rx_len
        jsr print_record
        lda #<msg_press_space
        ldx #>msg_press_space
        ldy #msg_press_space_end-msg_press_space
        jsr print_record
        rts