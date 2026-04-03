demo_draw_cursor
        lda zp_demo_prev_y
        cmp #$FF
        beq demo_draw_new
        lda zp_demo_cursor_x
        cmp zp_demo_prev_x
        bne demo_draw_move
        lda zp_demo_cursor_y
        cmp zp_demo_prev_y
        beq demo_draw_done
demo_draw_move
        jsr demo_restore_cursor

demo_draw_new
        jsr demo_save_cursor_under
        jsr demo_plot_cursor
        lda zp_demo_cursor_x
        sta zp_demo_prev_x
        lda zp_demo_cursor_y
        sta zp_demo_prev_y
demo_draw_done
        rts

demo_save_cursor_under
        lda zp_demo_cursor_y
        jsr demo_calc_cursor_visible_rows
        sta demo_cursor_clip_h
        lda zp_demo_cursor_x
        jsr demo_calc_cursor_visible_bytes
        sta demo_cursor_clip_w
        lda #0
        sta demo_cursor_row_ix
        sta demo_cursor_save_ix
demo_save_row_loop
        lda demo_cursor_row_ix
        cmp demo_cursor_clip_h
        bcs demo_save_done
        lda zp_demo_cursor_y
        clc
        adc demo_cursor_row_ix
        ldx zp_demo_cursor_x
        jsr demo_prepare_cursor_row_table
        jsr demo_mem_open
        ldx #0
demo_save_pix_loop
        cpx demo_cursor_clip_w
        beq demo_save_row_done
        ldy #0
        lda (zp_tmp_ptr),y
        ldy demo_cursor_save_ix
        sta demo_cursor_saved,y
        inc demo_cursor_save_ix
        jsr demo_mem_advance
        inx
        bne demo_save_pix_loop
demo_save_row_done
        memb_off
        inc demo_cursor_row_ix
        bne demo_save_row_loop
demo_save_done
        rts

demo_restore_cursor
        lda zp_demo_prev_y
        jsr demo_calc_cursor_visible_rows
        sta demo_cursor_clip_h
        lda zp_demo_prev_x
        jsr demo_calc_cursor_visible_bytes
        sta demo_cursor_clip_w
        lda #0
        sta demo_cursor_row_ix
        sta demo_cursor_save_ix
demo_restore_row_loop
        lda demo_cursor_row_ix
        cmp demo_cursor_clip_h
        bcs demo_restore_done
        lda zp_demo_prev_y
        clc
        adc demo_cursor_row_ix
        ldx zp_demo_prev_x
        jsr demo_prepare_cursor_row_table
        jsr demo_mem_open
        ldx #0
demo_restore_pix_loop
        cpx demo_cursor_clip_w
        beq demo_restore_row_done
        ldy demo_cursor_save_ix
        lda demo_cursor_saved,y
        inc demo_cursor_save_ix
        jsr demo_mem_put
        inx
        bne demo_restore_pix_loop
demo_restore_row_done
        memb_off
        inc demo_cursor_row_ix
        bne demo_restore_row_loop
demo_restore_done
        rts

demo_apply_stamp
        lda demo_stamp_phase
        clc
        adc #$29
        sta demo_stamp_phase

        lda #160
        sec
        sbc zp_demo_cursor_x
        cmp #10
        bcc demo_stamp_width_clip
        lda #DEMO_STAMP_SIZE
        bne demo_stamp_width_done
demo_stamp_width_clip
        asl
demo_stamp_width_done
        sta demo_stamp_width

        lda #DEMO_HEIGHT
        sec
        sbc zp_demo_cursor_y
        cmp #DEMO_STAMP_SIZE
        bcc demo_stamp_height_clip
        lda #DEMO_STAMP_SIZE
demo_stamp_height_clip
        sta demo_stamp_height

        lda demo_stamp_width
        beq demo_apply_stamp_done
        lda demo_stamp_height
        beq demo_apply_stamp_done

        lda #0
        sta demo_stamp_row
demo_stamp_row_loop
        lda zp_demo_cursor_y
        clc
        adc demo_stamp_row
        ldx zp_demo_cursor_x
        jsr demo_prepare_cursor_row_table
        jsr demo_mem_open
        ldx #0
demo_stamp_pix_loop
        txa
        asl
        clc
        adc demo_stamp_row
        eor demo_stamp_phase
        clc
        adc zp_demo_cursor_x
        ora #$18
        jsr demo_mem_put
        inx
        cpx demo_stamp_width
        bne demo_stamp_pix_loop
        memb_off
        inc demo_stamp_row
        lda demo_stamp_row
        cmp demo_stamp_height
        bne demo_stamp_row_loop
demo_apply_stamp_done
        rts

demo_plot_cursor
        lda zp_demo_cursor_y
        jsr demo_calc_cursor_visible_rows
        sta demo_cursor_clip_h
        lda zp_demo_cursor_x
        jsr demo_calc_cursor_visible_pairs
        sta demo_cursor_clip_w
        lda #0
        sta demo_cursor_row_ix
demo_plot_row_loop
        lda demo_cursor_row_ix
        cmp demo_cursor_clip_h
        bcs demo_plot_done
        ldy demo_cursor_row_ix
        lda demo_arrow_data,y
        beq demo_plot_row_next
        sta demo_cursor_mask
        lda zp_demo_cursor_y
        clc
        adc demo_cursor_row_ix
        ldx zp_demo_cursor_x
        jsr demo_prepare_cursor_row_table
        jsr demo_mem_open
        ldx #0
demo_plot_bit_loop
        cpx demo_cursor_clip_w
        beq demo_plot_row_done
        lda demo_cursor_mask
        asl
        sta demo_cursor_mask
        bcc demo_plot_skip_pair
        lda #DEMO_CURSOR_COLOR
        jsr demo_mem_put
        lda #DEMO_CURSOR_COLOR
        jsr demo_mem_put
        jmp demo_plot_next_bit
demo_plot_skip_pair
        jsr demo_mem_advance
        jsr demo_mem_advance
demo_plot_next_bit
        inx
        bne demo_plot_bit_loop
demo_plot_row_done
        memb_off
demo_plot_row_next
        inc demo_cursor_row_ix
        bne demo_plot_row_loop
demo_plot_done
        rts

demo_calc_cursor_visible_rows
        sta zp_tmp1
        lda #DEMO_HEIGHT
        sec
        sbc zp_tmp1
        cmp #demo_arrow_data_end-demo_arrow_data
        bcc demo_clip_rows_done
        lda #demo_arrow_data_end-demo_arrow_data
demo_clip_rows_done
        rts

demo_calc_cursor_visible_pairs
        sta zp_tmp1
        lda #160
        sec
        sbc zp_tmp1
        cmp #8
        bcc demo_clip_pairs_done
        lda #8
demo_clip_pairs_done
        rts

demo_calc_cursor_visible_bytes
        jsr demo_calc_cursor_visible_pairs
        asl
        rts

demo_prepare_cursor_row
        sta demo_cursor_abs_y
        txa
        asl
        sta demo_cursor_x2
        sta zp_tmp_ptr
        lda #0
        adc #0
        sta demo_cursor_ofs_hi

        lda demo_cursor_abs_y
        asl
        rol demo_cursor_ofs_hi
        asl
        rol demo_cursor_ofs_hi
        asl
        rol demo_cursor_ofs_hi
        asl
        rol demo_cursor_ofs_hi
        asl
        rol demo_cursor_ofs_hi
        asl
        rol demo_cursor_ofs_hi
        clc
        adc zp_tmp_ptr
        sta zp_tmp_ptr
        lda demo_cursor_ofs_hi
        adc #0
        sta demo_cursor_ofs_hi

        clc
        lda demo_cursor_abs_y
        adc demo_cursor_ofs_hi
        sta demo_cursor_ofs_hi

        lda demo_cursor_ofs_hi
        lsr
        lsr
        lsr
        lsr
        lsr
        lsr
        clc
        adc #2
        sta demo_cursor_bank

        lda demo_cursor_ofs_hi
        and #$3F
        ora #$40
        sta zp_tmp_ptr+1
        rts

demo_prepare_cursor_row_table
        sta demo_cursor_abs_y
        tay
        lda demo_row_ptr_lo,y
        sta zp_tmp_ptr
        lda demo_row_ptr_hi,y
        sta zp_tmp_ptr+1
        lda demo_row_bank,y
        sta demo_cursor_bank

        txa
        asl
        sta demo_cursor_x2
        lda #0
        adc #0
        sta demo_cursor_ofs_hi

        clc
        lda zp_tmp_ptr
        adc demo_cursor_x2
        sta zp_tmp_ptr
        lda zp_tmp_ptr+1
        adc demo_cursor_ofs_hi
        sta zp_tmp_ptr+1

        lda zp_tmp_ptr+1
        cmp #$80
        bcc demo_prepare_row_table_done
        sec
        sbc #$40
        sta zp_tmp_ptr+1
        inc demo_cursor_bank
demo_prepare_row_table_done
        rts

demo_build_row_table
        lda img_vram
        sta demo_rowtab_ptr_lo
        lda img_vram+1
        and #$3F
        ora #$40
        sta demo_rowtab_ptr_hi
        lda img_wr_bank
        sta demo_rowtab_bank

        ldy #0
demo_build_row_loop
        lda demo_rowtab_ptr_lo
        sta demo_row_ptr_lo,y
        lda demo_rowtab_ptr_hi
        sta demo_row_ptr_hi,y
        lda demo_rowtab_bank
        sta demo_row_bank,y

        clc
        lda demo_rowtab_ptr_lo
        adc #<320
        sta demo_rowtab_ptr_lo
        lda demo_rowtab_ptr_hi
        adc #>320
        sta demo_rowtab_ptr_hi
        cmp #$80
        bcc demo_build_row_next
        sec
        sbc #$40
        sta demo_rowtab_ptr_hi
        inc demo_rowtab_bank
demo_build_row_next
        iny
        cpy #DEMO_HEIGHT
        bne demo_build_row_loop
        rts

demo_mem_open
        lda demo_cursor_bank
        ora #$80
        sta zp_memb_shadow
        ldy #VBXE_MEMAC_B
        sta (zp_vbxe_base),y
        rts

demo_mem_put
        ldy #0
        sta (zp_tmp_ptr),y
        jmp demo_mem_advance

demo_mem_advance
        inc zp_tmp_ptr
        bne demo_mem_advance_check
        inc zp_tmp_ptr+1
demo_mem_advance_check
        lda zp_tmp_ptr+1
        cmp #$80
        bne demo_mem_advance_done
        lda #$40
        sta zp_tmp_ptr+1
        inc demo_cursor_bank
        lda demo_cursor_bank
        ora #$80
        sta zp_memb_shadow
        ldy #VBXE_MEMAC_B
        sta (zp_vbxe_base),y
demo_mem_advance_done
        rts