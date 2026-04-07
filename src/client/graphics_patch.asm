copy_gfx_url_to_buffer
        lda #<gfx_url_prefix
        sta zp_tmp_ptr
        lda #>gfx_url_prefix
        sta zp_tmp_ptr+1
        jsr copy_string_to_buffer
        ldy #0
gfx_find_end
        lda url_buffer,y
        beq gfx_append_source
        iny
        bne gfx_find_end

gfx_append_source
        ldx #0
gfx_append_source_loop
        lda room_patch_source_room,x
        beq gfx_append_target_sep
        sta url_buffer,y
        iny
        inx
        cpx #ROOM_NAME_MAX
        bcc gfx_append_source_loop

gfx_append_target_sep
        lda #'/'
        sta url_buffer,y
        iny
        jsr append_current_room_name
        lda #'/'
        sta url_buffer,y
        iny
        lda room_patch_width
        jsr append_hex_byte_to_buffer
        lda #'/'
        sta url_buffer,y
        iny
        lda room_patch_height
        jsr append_hex_byte_to_buffer
        lda #0
        sta url_buffer,y
        rts

room_fetch_graphics_patch
        jsr copy_gfx_url_to_buffer
        lda room_patch_y
        sta room_patch_cur_y
        lda room_patch_width
        sta room_patch_row_remaining
        lda room_patch_height
        sta room_patch_rows_left

        lda #$16
        sta debug_stage
        jsr fn_open
        lda DSTATS
        sta debug_dstats
        bcc room_patch_open_ok
        sec
        rts

room_patch_open_ok
        lda #VIEW_TIMEOUT
        sta debug_timeout_ctr

room_patch_wait
        lda room_patch_rows_left
        beq room_patch_done
        jsr poll_status
        bcc room_patch_status_ok
        jmp room_patch_fail_close

room_patch_status_ok
        lda debug_fn_error
        bmi room_patch_status_fatal
        jmp room_patch_check_data

room_patch_status_fatal
        jmp room_patch_fail_close

room_patch_check_data
        lda debug_bytes_hi
        bne room_patch_read
        lda debug_bytes_lo
        bne room_patch_read
        lda debug_connected
        beq room_patch_fail_close
        dec debug_timeout_ctr
        beq room_patch_fail_close
        jsr wait_one_frame
        jmp room_patch_wait

room_patch_read
        lda debug_bytes_hi
        beq room_patch_read_lo
        lda #READ_LIMIT
        bne room_patch_read_set

room_patch_read_lo
        lda debug_bytes_lo
        cmp #READ_LIMIT
        bcc room_patch_read_set
        lda #READ_LIMIT

room_patch_read_set
        sta zp_fn_bytes_lo
        lda #0
        sta zp_fn_bytes_hi
        jsr fn_read
        lda DSTATS
        sta debug_dstats
        bcc room_patch_read_ok
        jmp room_patch_fail_close

room_patch_read_ok
        lda zp_rx_len
        sta debug_rx_len
        jsr room_patch_write_chunk
        lda #VIEW_TIMEOUT
        sta debug_timeout_ctr
        jmp room_patch_wait

room_patch_done
        jsr fn_close
        clc
        rts

room_patch_fail_close
        jsr fn_close
        sec
        rts

room_cache_prepare_replace
        lda #0
        sta room_patch_restore_mode
        sta zp_tmp1
        sta zp_tmp2
        ldx room_patch_height

room_cache_size_loop
        cpx #0
        beq room_cache_size_ready
        clc
        lda zp_tmp1
        adc room_patch_width
        sta zp_tmp1
        lda zp_tmp2
        adc #0
        sta zp_tmp2
        dex
        bne room_cache_size_loop

room_cache_size_ready
        lda zp_tmp2
        cmp #>ROOM_PATCH_CACHE_MAX
        bcc room_cache_size_fit
        bne room_cache_size_reload
        lda zp_tmp1
        cmp #<ROOM_PATCH_CACHE_MAX
        bcc room_cache_size_fit
        bne room_cache_size_reload

room_cache_size_fit
        lda room_patch_x_lo
        sta room_patch_restore_x_lo
        lda room_patch_x_hi
        sta room_patch_restore_x_hi
        lda room_patch_y
        sta room_patch_restore_y
        lda room_patch_width
        sta room_patch_restore_width
        lda room_patch_height
        sta room_patch_restore_height
        lda #1
        sta room_patch_restore_mode
        jmp room_cache_store_region

room_cache_size_reload
        lda #2
        sta room_patch_restore_mode
        rts

room_restore_original_graphics
        lda room_patch_restore_mode
        beq room_restore_original_done
        cmp #2
        beq room_restore_original_reload

        lda room_patch_restore_x_lo
        sta room_patch_x_lo
        lda room_patch_restore_x_hi
        sta room_patch_x_hi
        lda room_patch_restore_y
        sta room_patch_y
        lda room_patch_restore_width
        sta room_patch_width
        lda room_patch_restore_height
        sta room_patch_height
        jsr room_cache_restore_region
        lda #0
        sta room_patch_restore_mode
room_restore_original_done
        rts

room_restore_original_reload
        lda #0
        sta room_patch_restore_mode
        lda #1
        sta room_action_pending_reload
        rts

room_patch_cache_init_ptr
        lda #<ROOM_PATCH_CACHE_MEMB
        sta zp_tmp_ptr2
        lda #>ROOM_PATCH_CACHE_MEMB
        sta zp_tmp_ptr2+1
        lda #ROOM_PATCH_CACHE_BANK
        sta room_patch_cache_cur_bank
        rts

room_patch_cache_open
        lda room_patch_cache_cur_bank
        ora #$80
        sta zp_memb_shadow
        ldy #VBXE_MEMAC_B
        sta (zp_vbxe_base),y
        rts

room_patch_cache_advance
        inc zp_tmp_ptr2
        bne room_patch_cache_advance_check
        inc zp_tmp_ptr2+1
room_patch_cache_advance_check
        lda zp_tmp_ptr2+1
        cmp #$80
        bne room_patch_cache_advance_done
        lda #$40
        sta zp_tmp_ptr2+1
        inc room_patch_cache_cur_bank
        lda room_patch_cache_cur_bank
        ora #$80
        sta zp_memb_shadow
        ldy #VBXE_MEMAC_B
        sta (zp_vbxe_base),y
room_patch_cache_advance_done
        rts

room_cache_store_region
        jsr room_patch_cache_init_ptr
        lda room_patch_y
        sta room_patch_cur_y
        lda room_patch_height
        sta room_patch_rows_left

room_cache_store_row_loop
        lda room_patch_rows_left
        beq room_cache_store_done
        jsr room_patch_prepare_row
        jsr demo_mem_open
        ldx #0

room_cache_store_pix_loop
        cpx room_patch_width
        beq room_cache_store_row_done
        ldy #0
        lda (zp_tmp_ptr),y
        sta zp_tmp3
        jsr room_patch_cache_open
        ldy #0
        lda zp_tmp3
        sta (zp_tmp_ptr2),y
        jsr room_patch_cache_advance
        jsr demo_mem_open
        jsr demo_mem_advance
        inx
        bne room_cache_store_pix_loop

room_cache_store_row_done
        memb_off
        inc room_patch_cur_y
        dec room_patch_rows_left
        bne room_cache_store_row_loop
room_cache_store_done
        rts

room_cache_restore_region
        jsr room_patch_cache_init_ptr
        lda room_patch_y
        sta room_patch_cur_y
        lda room_patch_height
        sta room_patch_rows_left

room_cache_restore_row_loop
        lda room_patch_rows_left
        beq room_cache_restore_done
        jsr room_patch_prepare_row
        jsr demo_mem_open
        ldx #0

room_cache_restore_pix_loop
        cpx room_patch_width
        beq room_cache_restore_row_done
        jsr room_patch_cache_open
        ldy #0
        lda (zp_tmp_ptr2),y
        sta zp_tmp3
        jsr room_patch_cache_advance
        jsr demo_mem_open
        lda zp_tmp3
        jsr demo_mem_put
        inx
        bne room_cache_restore_pix_loop

room_cache_restore_row_done
        memb_off
        inc room_patch_cur_y
        dec room_patch_rows_left
        bne room_cache_restore_row_loop
room_cache_restore_done
        rts

room_patch_write_chunk
        ldx #0
room_patch_chunk_loop
        cpx zp_rx_len
        beq room_patch_chunk_done
        lda room_patch_rows_left
        beq room_patch_chunk_done
        lda room_patch_row_remaining
        cmp room_patch_width
        bne room_patch_row_opened
        jsr room_patch_prepare_row
        jsr demo_mem_open

room_patch_row_opened
        lda rx_buffer,x
        jsr demo_mem_put
        dec room_patch_row_remaining
        bne room_patch_next_byte
        memb_off
        dec room_patch_rows_left
        beq room_patch_next_byte
        inc room_patch_cur_y
        lda room_patch_width
        sta room_patch_row_remaining

room_patch_next_byte
        inx
        jmp room_patch_chunk_loop

room_patch_chunk_done
        rts

room_patch_prepare_row
        lda room_patch_cur_y
        tay
        lda demo_row_ptr_lo,y
        sta zp_tmp_ptr
        lda demo_row_ptr_hi,y
        sta zp_tmp_ptr+1
        lda demo_row_bank,y
        sta demo_cursor_bank
        clc
        lda zp_tmp_ptr
        adc room_patch_x_lo
        sta zp_tmp_ptr
        lda zp_tmp_ptr+1
        adc room_patch_x_hi
        sta zp_tmp_ptr+1
        bcc room_patch_prepare_check
        inc demo_cursor_bank

room_patch_prepare_check
        lda zp_tmp_ptr+1
        cmp #$80
        bcc room_patch_prepare_done
        sec
        sbc #$40
        sta zp_tmp_ptr+1
        inc demo_cursor_bank
room_patch_prepare_done
        rts