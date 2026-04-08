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

room_selection_cache_clear_all
        lda #0
        sta room_sel_cache_count
        sta room_sel_cache_used_lo
        sta room_sel_cache_used_hi
        sta room_sel_cache_active
        lda #$FF
        sta room_sel_cache_pending_slot
        sta room_sel_cache_hit_slot
        rts

room_selection_cache_is_imgsel
        lda room_patch_source_room
        cmp #'i'
        bne room_selection_cache_is_imgsel_no
        lda room_patch_source_room+1
        cmp #'m'
        bne room_selection_cache_is_imgsel_no
        lda room_patch_source_room+2
        cmp #'g'
        bne room_selection_cache_is_imgsel_no
        lda room_patch_source_room+3
        cmp #'s'
        bne room_selection_cache_is_imgsel_no
        lda room_patch_source_room+4
        cmp #'e'
        bne room_selection_cache_is_imgsel_no
        lda room_patch_source_room+5
        cmp #'l'
        bne room_selection_cache_is_imgsel_no
        lda room_patch_source_room+6
        cmp #'-'
        bne room_selection_cache_is_imgsel_no
        sec
        rts
room_selection_cache_is_imgsel_no
        clc
        rts

room_selection_cache_calc_size
        lda #0
        sta zp_tmp1
        sta zp_tmp2
        ldx room_patch_height
room_selection_cache_size_loop
        cpx #0
        beq room_selection_cache_size_done
        clc
        lda zp_tmp1
        adc room_patch_width
        sta zp_tmp1
        lda zp_tmp2
        adc #0
        sta zp_tmp2
        dex
        bne room_selection_cache_size_loop
room_selection_cache_size_done
        rts

room_selection_cache_token_ptr_from_index_a
        sta zp_tmp1
        lda #<room_sel_cache_tokens
        sta zp_tmp_ptr
        lda #>room_sel_cache_tokens
        sta zp_tmp_ptr+1
room_selection_cache_token_ptr_loop
        lda zp_tmp1
        beq room_selection_cache_token_ptr_done
        clc
        lda zp_tmp_ptr
        adc #(ROOM_NAME_MAX+1)
        sta zp_tmp_ptr
        bcc room_selection_cache_token_ptr_no_carry
        inc zp_tmp_ptr+1
room_selection_cache_token_ptr_no_carry
        dec zp_tmp1
        jmp room_selection_cache_token_ptr_loop
room_selection_cache_token_ptr_done
        rts

room_selection_cache_token_matches_index_a
        jsr room_selection_cache_token_ptr_from_index_a
        ldy #0
room_selection_cache_token_match_loop
        lda room_patch_source_room,y
        cmp (zp_tmp_ptr),y
        bne room_selection_cache_token_match_fail
        cmp #0
        beq room_selection_cache_token_match_ok
        iny
        cpy #(ROOM_NAME_MAX+1)
        bcc room_selection_cache_token_match_loop
room_selection_cache_token_match_ok
        sec
        rts
room_selection_cache_token_match_fail
        clc
        rts

room_selection_cache_find
        lda #$FF
        sta room_sel_cache_hit_slot
        jsr room_selection_cache_is_imgsel
        bcs room_selection_cache_find_scan
        sec
        rts
room_selection_cache_find_scan
        ldx #0
room_selection_cache_find_loop
        cpx room_sel_cache_count
        bcc room_selection_cache_find_check
        sec
        rts
room_selection_cache_find_check
        lda room_patch_width
        cmp room_sel_cache_width,x
        bne room_selection_cache_find_next
        lda room_patch_height
        cmp room_sel_cache_height,x
        bne room_selection_cache_find_next
        txa
        jsr room_selection_cache_token_matches_index_a
        bcc room_selection_cache_find_next
        stx room_sel_cache_hit_slot
        clc
        rts
room_selection_cache_find_next
        inx
        jmp room_selection_cache_find_loop

room_selection_cache_init_ptr_from_used
        clc
        lda #<ROOM_SELECTION_CACHE_MEMB
        adc room_sel_cache_used_lo
        sta room_sel_cache_ptr_lo
        lda #>ROOM_SELECTION_CACHE_MEMB
        adc room_sel_cache_used_hi
        sta room_sel_cache_ptr_hi
        lda #ROOM_SELECTION_CACHE_BANK
        sta room_sel_cache_cur_bank
room_selection_cache_init_ptr_check
        lda room_sel_cache_ptr_hi
        cmp #$80
        bcc room_selection_cache_init_ptr_done
        sec
        sbc #$40
        sta room_sel_cache_ptr_hi
        inc room_sel_cache_cur_bank
        jmp room_selection_cache_init_ptr_check
room_selection_cache_init_ptr_done
        rts

room_selection_cache_copy_token_to_pending
        lda room_sel_cache_pending_slot
        jsr room_selection_cache_token_ptr_from_index_a
        ldy #0
room_selection_cache_copy_token_loop
        lda room_patch_source_room,y
        sta (zp_tmp_ptr),y
        beq room_selection_cache_copy_token_done
        iny
        cpy #(ROOM_NAME_MAX+1)
        bcc room_selection_cache_copy_token_loop
        dey
        lda #0
        sta (zp_tmp_ptr),y
room_selection_cache_copy_token_done
        rts

room_selection_cache_prepare_store
        lda #0
        sta room_sel_cache_active
        lda #$FF
        sta room_sel_cache_pending_slot
        jsr room_selection_cache_is_imgsel
        bcc room_selection_cache_prepare_skip
        jsr room_selection_cache_calc_size
        lda zp_tmp2
        cmp #>ROOM_SELECTION_CACHE_MAX
        bcc room_selection_cache_prepare_size_ok
        bne room_selection_cache_prepare_skip
        lda zp_tmp1
        cmp #<ROOM_SELECTION_CACHE_MAX
        bcc room_selection_cache_prepare_size_ok
        bne room_selection_cache_prepare_skip

room_selection_cache_prepare_size_ok
        ldx room_sel_cache_count
        cpx #ROOM_SELECTION_CACHE_SLOTS
        bcc room_selection_cache_prepare_space_check
        jsr room_selection_cache_clear_all

room_selection_cache_prepare_space_check
        clc
        lda room_sel_cache_used_lo
        adc zp_tmp1
        sta zp_tmp_ptr
        lda room_sel_cache_used_hi
        adc zp_tmp2
        sta zp_tmp_ptr+1
        lda zp_tmp_ptr+1
        cmp #>ROOM_SELECTION_CACHE_MAX
        bcc room_selection_cache_prepare_allocate
        bne room_selection_cache_prepare_reset
        lda zp_tmp_ptr
        cmp #<ROOM_SELECTION_CACHE_MAX
        bcc room_selection_cache_prepare_allocate
        bne room_selection_cache_prepare_reset
        jmp room_selection_cache_prepare_allocate

room_selection_cache_prepare_reset
        jsr room_selection_cache_clear_all

room_selection_cache_prepare_allocate
        jsr room_selection_cache_init_ptr_from_used
        ldx room_sel_cache_count
        stx room_sel_cache_pending_slot
        lda zp_tmp1
        sta room_sel_cache_size_lo,x
        lda zp_tmp2
        sta room_sel_cache_size_hi,x
        lda room_patch_width
        sta room_sel_cache_width,x
        lda room_patch_height
        sta room_sel_cache_height,x
        lda room_sel_cache_cur_bank
        sta room_sel_cache_bank,x
        lda room_sel_cache_ptr_lo
        sta room_sel_cache_ptrs_lo,x
        lda room_sel_cache_ptr_hi
        sta room_sel_cache_ptrs_hi,x
        lda #1
        sta room_sel_cache_active
        jsr room_selection_cache_copy_token_to_pending
room_selection_cache_prepare_skip
        rts

room_selection_cache_finish_store
        lda room_sel_cache_active
        bne room_selection_cache_finish_do
        rts
room_selection_cache_finish_do
        ldx room_sel_cache_pending_slot
        inc room_sel_cache_count
        clc
        lda room_sel_cache_used_lo
        adc room_sel_cache_size_lo,x
        sta room_sel_cache_used_lo
        lda room_sel_cache_used_hi
        adc room_sel_cache_size_hi,x
        sta room_sel_cache_used_hi
        lda #0
        sta room_sel_cache_active
        lda #$FF
        sta room_sel_cache_pending_slot
        rts

room_selection_cache_abort_store
        lda #0
        sta room_sel_cache_active
        lda #$FF
        sta room_sel_cache_pending_slot
        rts

room_selection_cache_open
        lda room_sel_cache_ptr_lo
        sta zp_tmp_ptr2
        lda room_sel_cache_ptr_hi
        sta zp_tmp_ptr2+1
        lda room_sel_cache_cur_bank
        ora #$80
        sta zp_memb_shadow
        ldy #VBXE_MEMAC_B
        sta (zp_vbxe_base),y
        rts

room_selection_cache_advance
        inc room_sel_cache_ptr_lo
        bne room_selection_cache_advance_check
        inc room_sel_cache_ptr_hi
room_selection_cache_advance_check
        lda room_sel_cache_ptr_hi
        cmp #$80
        bne room_selection_cache_advance_done
        lda #$40
        sta room_sel_cache_ptr_hi
        inc room_sel_cache_cur_bank
room_selection_cache_advance_done
        rts

room_selection_cache_store_byte_if_active
        lda room_sel_cache_active
        beq room_selection_cache_store_done
        jsr room_selection_cache_open
        ldy #0
        lda zp_tmp3
        sta (zp_tmp_ptr2),y
        jsr room_selection_cache_advance
        jsr demo_mem_open
room_selection_cache_store_done
        rts

room_selection_cache_restore_hit
        ldx room_sel_cache_hit_slot
        lda room_sel_cache_ptrs_lo,x
        sta room_sel_cache_ptr_lo
        lda room_sel_cache_ptrs_hi,x
        sta room_sel_cache_ptr_hi
        lda room_sel_cache_bank,x
        sta room_sel_cache_cur_bank
        lda room_patch_y
        sta room_patch_cur_y
        lda room_patch_height
        sta room_patch_rows_left

room_selection_cache_restore_row_loop
        lda room_patch_rows_left
        beq room_selection_cache_restore_done
        jsr room_patch_prepare_row
        jsr demo_mem_open
        ldx #0

room_selection_cache_restore_pix_loop
        cpx room_patch_width
        beq room_selection_cache_restore_row_done
        jsr room_selection_cache_open
        ldy #0
        lda (zp_tmp_ptr2),y
        sta zp_tmp3
        jsr room_selection_cache_advance
        jsr demo_mem_open
        lda zp_tmp3
        jsr demo_mem_put
        inx
        bne room_selection_cache_restore_pix_loop

room_selection_cache_restore_row_done
        memb_off
        inc room_patch_cur_y
        dec room_patch_rows_left
        bne room_selection_cache_restore_row_loop
room_selection_cache_restore_done
        rts

room_selection_cache_try_restore
        jsr room_selection_cache_find
        bcc room_selection_cache_try_restore_hit
        sec
        rts
room_selection_cache_try_restore_hit
        jsr room_selection_cache_restore_hit
        clc
        rts

room_fetch_graphics_patch
        jsr room_selection_cache_try_restore
        bcs room_fetch_graphics_patch_network
        clc
        rts

room_fetch_graphics_patch_network
        jsr room_selection_cache_prepare_store
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
        jsr room_selection_cache_finish_store
        clc
        rts

room_patch_fail_close
        jsr fn_close
        jsr room_selection_cache_abort_store
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
        sta zp_tmp3
        jsr room_selection_cache_store_byte_if_active
        lda zp_tmp3
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