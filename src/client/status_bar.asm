row_addr_lo
        :29 dta <(MEMB_SCREEN + # * SCR_STRIDE)

row_addr_hi
        :29 dta >(MEMB_SCREEN + # * SCR_STRIDE)

status_copy_font
        memb_on 0
        lda CHBAS
        sta zp_tmp1

        ldx #0
status_copy_font_page_loop
        lda zp_tmp1
        clc
        adc demo_font_page_map,x
        sta zp_tmp_ptr+1
        lda #0
        sta zp_tmp_ptr

        txa
        clc
        adc #>MEMB_FONT
        sta zp_tmp_ptr2+1
        lda #0
        sta zp_tmp_ptr2

        ldy #0
status_copy_font_byte_loop
        lda (zp_tmp_ptr),y
        sta (zp_tmp_ptr2),y
        iny
        bne status_copy_font_byte_loop

        inx
        cpx #4
        bne status_copy_font_page_loop

        memb_off
        rts

status_calc_scr_ptr
        ldx zp_cursor_row
        lda row_addr_lo,x
        sta zp_scr_ptr
        lda row_addr_hi,x
        sta zp_scr_ptr+1
        lda zp_cursor_col
        asl
        clc
        adc zp_scr_ptr
        sta zp_scr_ptr
        bcc status_calc_done
        inc zp_scr_ptr+1
status_calc_done
        rts

vbxe_setpos
        sta zp_cursor_row
        stx zp_cursor_col
        jmp status_calc_scr_ptr

vbxe_setattr
        sta zp_cur_attr
        rts

vbxe_putchar
        pha
        lda zp_cursor_col
        cmp #SCR_COLS
        bcc vbxe_putchar_write
        pla
        rts

vbxe_putchar_write
        memb_on 0
        pla
        ldy #0
        sta (zp_scr_ptr),y
        iny
        lda zp_cur_attr
        sta (zp_scr_ptr),y
        memb_off

        lda zp_scr_ptr
        clc
        adc #2
        sta zp_scr_ptr
        bcc vbxe_putchar_no_carry
        inc zp_scr_ptr+1
vbxe_putchar_no_carry
        inc zp_cursor_col
        rts

vbxe_print
        sta zp_tmp_ptr
        stx zp_tmp_ptr+1
        lda #0
        sta zp_tmp3
vbxe_print_loop
        ldy zp_tmp3
        lda (zp_tmp_ptr),y
        beq vbxe_print_done
        jsr vbxe_putchar
        inc zp_tmp3
        bne vbxe_print_loop
vbxe_print_done
        rts

vbxe_fill_row
        sta zp_tmp1
        stx zp_tmp2
        memb_on 0

        ldx zp_tmp1
        lda row_addr_lo,x
        sta zp_scr_ptr
        lda row_addr_hi,x
        sta zp_scr_ptr+1

        ldy #0
vbxe_fill_row_loop
        lda #CH_SPACE
        sta (zp_scr_ptr),y
        iny
        lda zp_tmp2
        sta (zp_scr_ptr),y
        iny
        cpy #SCR_STRIDE
        bne vbxe_fill_row_loop

        memb_off
        rts