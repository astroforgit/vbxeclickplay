demo_click_stamp
        lda zp_demo_prev_y
        cmp #$FF
        beq demo_click_stamp_patch
        jsr demo_restore_cursor
        lda #$FF
        sta zp_demo_prev_x
        sta zp_demo_prev_y
demo_click_stamp_patch
        jsr demo_apply_stamp
        jsr demo_draw_cursor
        rts

demo_show_popup
        lda zp_demo_prev_y
        cmp #$FF
        beq demo_show_popup_check
        jsr demo_restore_cursor
        lda #$FF
        sta zp_demo_prev_x
        sta zp_demo_prev_y
demo_show_popup_check
        lda demo_popup_active
        beq demo_show_popup_draw
        jsr demo_popup_hit_test
        bcs demo_show_popup_done
        jsr demo_restore_popup_under
demo_show_popup_draw
        jsr demo_calc_popup_position
        jsr demo_save_popup_under
        jsr demo_draw_popup_box
        jsr demo_draw_popup_text
        lda #1
        sta demo_popup_active
demo_show_popup_done
        jsr demo_draw_cursor
        rts

demo_calc_popup_position
        lda zp_demo_cursor_x
        cmp #DEMO_POPUP_MAX_X
        bcc demo_popup_x_ok
        lda #DEMO_POPUP_MAX_X
demo_popup_x_ok
        sta demo_popup_x

        lda zp_demo_cursor_y
        cmp #DEMO_POPUP_MAX_Y
        bcc demo_popup_y_ok
        lda #DEMO_POPUP_MAX_Y
demo_popup_y_ok
        sta demo_popup_y
        rts

demo_popup_hit_test
        lda zp_demo_cursor_x
        sec
        sbc demo_popup_x
        cmp #DEMO_POPUP_WIDTH_LOGICAL
        bcs demo_popup_hit_miss
        lda zp_demo_cursor_y
        sec
        sbc demo_popup_y
        cmp #DEMO_POPUP_HEIGHT
        bcs demo_popup_hit_miss
        sec
        rts
demo_popup_hit_miss
        clc
        rts

demo_save_popup_under
        lda #<demo_popup_saved
        sta zp_tmp_ptr2
        lda #>demo_popup_saved
        sta zp_tmp_ptr2+1
        lda #0
        sta demo_popup_row
demo_popup_save_row_loop
        lda demo_popup_y
        clc
        adc demo_popup_row
        ldx demo_popup_x
        jsr demo_prepare_cursor_row_table
        jsr demo_mem_open
        ldx #0
demo_popup_save_pix_loop
        ldy #0
        lda (zp_tmp_ptr),y
        ldy #0
        sta (zp_tmp_ptr2),y
        inc zp_tmp_ptr2
        bne demo_popup_save_ptr_ok
        inc zp_tmp_ptr2+1
demo_popup_save_ptr_ok
        jsr demo_mem_advance
        inx
        cpx #DEMO_POPUP_WIDTH
        bne demo_popup_save_pix_loop
        memb_off
        inc demo_popup_row
        lda demo_popup_row
        cmp #DEMO_POPUP_HEIGHT
        bne demo_popup_save_row_loop
        rts

demo_restore_popup_under
        lda #<demo_popup_saved
        sta zp_tmp_ptr2
        lda #>demo_popup_saved
        sta zp_tmp_ptr2+1
        lda #0
        sta demo_popup_row
demo_popup_restore_row_loop
        lda demo_popup_y
        clc
        adc demo_popup_row
        ldx demo_popup_x
        jsr demo_prepare_cursor_row_table
        jsr demo_mem_open
        ldx #0
demo_popup_restore_pix_loop
        ldy #0
        lda (zp_tmp_ptr2),y
        inc zp_tmp_ptr2
        bne demo_popup_restore_ptr_ok
        inc zp_tmp_ptr2+1
demo_popup_restore_ptr_ok
        jsr demo_mem_put
        inx
        cpx #DEMO_POPUP_WIDTH
        bne demo_popup_restore_pix_loop
        memb_off
        inc demo_popup_row
        lda demo_popup_row
        cmp #DEMO_POPUP_HEIGHT
        bne demo_popup_restore_row_loop
        lda #0
        sta demo_popup_active
        rts

demo_draw_popup_box
        lda #0
        sta demo_popup_row
demo_popup_box_row_loop
        lda demo_popup_y
        clc
        adc demo_popup_row
        ldx demo_popup_x
        jsr demo_prepare_cursor_row_table
        jsr demo_mem_open
        lda demo_popup_row
        beq demo_popup_border_row
        cmp #DEMO_POPUP_LAST_ROW
        beq demo_popup_border_row

        lda #DEMO_POPUP_BORDER_COLOR
        jsr demo_mem_put
        ldx #0
demo_popup_fill_loop
        lda #DEMO_POPUP_FILL_COLOR
        jsr demo_mem_put
        inx
        cpx #DEMO_POPUP_INNER_WIDTH
        bne demo_popup_fill_loop
        lda #DEMO_POPUP_BORDER_COLOR
        jsr demo_mem_put
        jmp demo_popup_box_row_done

demo_popup_border_row
        ldx #0
demo_popup_border_fill_loop
        lda #DEMO_POPUP_BORDER_COLOR
        jsr demo_mem_put
        inx
        cpx #DEMO_POPUP_WIDTH
        bne demo_popup_border_fill_loop

demo_popup_box_row_done
        memb_off
        inc demo_popup_row
        lda demo_popup_row
        cmp #DEMO_POPUP_HEIGHT
        bne demo_popup_box_row_loop
        rts

demo_draw_popup_text
        lda #0
        sta demo_popup_text_row
demo_popup_text_row_loop
        lda demo_popup_y
        clc
        adc demo_popup_text_row
        adc #2
        ldx demo_popup_x
        inx
        inx
        jsr demo_prepare_cursor_row_table
        jsr demo_mem_open

        lda #0
        sta demo_popup_char_ix
demo_popup_char_loop
        ldy demo_popup_char_ix
        lda demo_popup_text,y
        beq demo_popup_text_row_done
        jsr demo_get_popup_font_bits
        sta demo_popup_font_bits
        ldx #0
demo_popup_font_bit_loop
        lda demo_popup_font_bits
        asl
        sta demo_popup_font_bits
        bcc demo_popup_font_skip
        lda #DEMO_POPUP_TEXT_COLOR
        jsr demo_mem_put
        jmp demo_popup_font_next
demo_popup_font_skip
        jsr demo_mem_advance
demo_popup_font_next
        inx
        cpx #8
        bne demo_popup_font_bit_loop
        inc demo_popup_char_ix
        jmp demo_popup_char_loop

demo_popup_text_row_done
        memb_off
        inc demo_popup_text_row
        lda demo_popup_text_row
        cmp #8
        bne demo_popup_text_row_loop
        rts

demo_get_popup_font_bits
        sta zp_tmp1
        and #$1F
        asl
        asl
        asl
        clc
        adc demo_popup_text_row
        sta zp_tmp_ptr2
        lda zp_tmp1
        lsr
        lsr
        lsr
        lsr
        lsr
        tax
        lda CHBAS
        clc
        adc demo_font_page_map,x
        sta zp_tmp_ptr2+1
        ldy #0
        lda (zp_tmp_ptr2),y
        rts