init_current_room_name
        ldx #0
init_room_name_loop
        lda default_room_name,x
        sta current_room_name,x
        beq init_room_name_done
        inx
        cpx #ROOM_NAME_MAX
        bcc init_room_name_loop
        lda #0
        sta current_room_name+ROOM_NAME_MAX
init_room_name_done
        rts

room_clear_hover_metadata
        lda #0
        sta room_hover_count
        lda #$FF
        sta room_hover_match
        ldx #0
room_clear_hover_names_loop
        lda #0
        sta room_hover_names,x
        inx
        cpx #(ROOM_HOVER_MAX_SELECTIONS*(ROOM_HOVER_NAME_MAX+1))
        bcc room_clear_hover_names_loop
        rts

room_clear_hover_label
        lda #STATUS_ROW
        ldx #COL_BLACK
        jmp vbxe_fill_row

room_load_hover_metadata
        jsr room_clear_hover_metadata
        jsr room_clear_hover_label
        jsr copy_room_meta_url_to_buffer
        jsr fetch_text_payload
        bcs room_load_hover_done
        jsr room_parse_hover_metadata
room_load_hover_done
        rts

room_hover_name_ptr_from_index_a
        sta zp_tmp1
        lda #<room_hover_names
        sta zp_tmp_ptr
        lda #>room_hover_names
        sta zp_tmp_ptr+1
room_hover_name_ptr_loop
        lda zp_tmp1
        beq room_hover_name_ptr_done
        clc
        lda zp_tmp_ptr
        adc #(ROOM_HOVER_NAME_MAX+1)
        sta zp_tmp_ptr
        bcc room_hover_name_ptr_no_carry
        inc zp_tmp_ptr+1
room_hover_name_ptr_no_carry
        dec zp_tmp1
        jmp room_hover_name_ptr_loop
room_hover_name_ptr_done
        rts

room_parse_hover_metadata
        lda rx_buffer
        cmp #'S'
        beq room_parse_hover_check_e
        jmp room_parse_hover_done
room_parse_hover_check_e
        lda rx_buffer+1
        cmp #'E'
        beq room_parse_hover_check_l
        jmp room_parse_hover_done
room_parse_hover_check_l
        lda rx_buffer+2
        cmp #'L'
        beq room_parse_hover_check_colon
        jmp room_parse_hover_done
room_parse_hover_check_colon
        lda rx_buffer+3
        cmp #':'
        beq room_parse_hover_start
        jmp room_parse_hover_done

room_parse_hover_start
        ldy #4
room_parse_hover_entry
        lda rx_buffer,y
        bne room_parse_hover_check_ret
        jmp room_parse_hover_done
room_parse_hover_check_ret
        cmp #ATASCII_RET
        bne room_parse_hover_check_count
        jmp room_parse_hover_done
room_parse_hover_check_count
        ldx room_hover_count
        cpx #ROOM_HOVER_MAX_SELECTIONS
        bcc room_parse_hover_parse_x
        jmp room_parse_hover_done

room_parse_hover_parse_x
        jsr room_parse_hex_byte_field
        bcc room_parse_hover_store_x
        jmp room_parse_hover_done
room_parse_hover_store_x
        sta room_hover_x,x
        iny
        lda rx_buffer,y
        cmp #','
        beq room_parse_hover_parse_y
        jmp room_parse_hover_done

room_parse_hover_parse_y
        iny

        jsr room_parse_hex_byte_field
        bcc room_parse_hover_store_y
        jmp room_parse_hover_done
room_parse_hover_store_y
        ldx room_hover_count
        sta room_hover_y,x
        iny
        lda rx_buffer,y
        cmp #','
        beq room_parse_hover_parse_w
        jmp room_parse_hover_done

room_parse_hover_parse_w
        iny

        jsr room_parse_hex_byte_field
        bcc room_parse_hover_store_w
        jmp room_parse_hover_done
room_parse_hover_store_w
        ldx room_hover_count
        sta room_hover_w,x
        iny
        lda rx_buffer,y
        cmp #','
        beq room_parse_hover_parse_h
        jmp room_parse_hover_done

room_parse_hover_parse_h
        iny

        jsr room_parse_hex_byte_field
        bcc room_parse_hover_store_h
        jmp room_parse_hover_done
room_parse_hover_store_h
        ldx room_hover_count
        sta room_hover_h,x
        iny
        lda rx_buffer,y
        cmp #','
        beq room_parse_hover_parse_name
        jmp room_parse_hover_done

room_parse_hover_parse_name
        iny

        sty zp_tmp2
        lda room_hover_count
        jsr room_hover_name_ptr_from_index_a
        ldx #0
room_parse_hover_name_loop
        ldy zp_tmp2
        lda rx_buffer,y
        beq room_parse_hover_name_done
        cmp #ATASCII_RET
        beq room_parse_hover_name_done
        cmp #'|'
        beq room_parse_hover_name_done
        cpx #ROOM_HOVER_NAME_MAX
        bcs room_parse_hover_name_skip_store
        ldy #0
        sta (zp_tmp_ptr),y
        inc zp_tmp_ptr
        bne room_parse_hover_name_store_done
        inc zp_tmp_ptr+1
room_parse_hover_name_store_done
        inx
room_parse_hover_name_skip_store
        inc zp_tmp2
        bne room_parse_hover_name_loop

room_parse_hover_name_done
        ldy #0
        lda #0
        sta (zp_tmp_ptr),y
        ldy zp_tmp2
        inc room_hover_count
        lda rx_buffer,y
        cmp #'|'
        bne room_parse_hover_done
        iny
        jmp room_parse_hover_entry

room_parse_hover_done
        rts

room_show_hover_label
        txa
        pha
        lda #STATUS_ROW
        ldx #COL_BLACK
        jsr vbxe_fill_row
        lda #STATUS_ROW
        ldx #0
        jsr vbxe_setpos
        lda #ATTR_NORMAL
        jsr vbxe_setattr
        pla
        jsr room_hover_name_ptr_from_index_a
        lda zp_tmp_ptr
        ldx zp_tmp_ptr+1
        jmp vbxe_print

room_update_hover_label
        lda room_hover_count
        bne room_hover_scan_start
        lda room_hover_match
        cmp #$FF
        beq room_hover_update_done
        lda #$FF
        sta room_hover_match
        jsr room_clear_hover_label
        rts

room_hover_scan_start
        ldx room_hover_count
        beq room_hover_no_match
        dex
room_hover_scan_loop
        lda zp_demo_cursor_y
        cmp room_hover_y,x
        bcc room_hover_next
        sec
        sbc room_hover_y,x
        cmp room_hover_h,x
        bcs room_hover_next

        lda zp_demo_cursor_x
        cmp room_hover_x,x
        bcc room_hover_next
        sec
        sbc room_hover_x,x
        cmp room_hover_w,x
        bcs room_hover_next

        txa
        cmp room_hover_match
        beq room_hover_update_done
        sta room_hover_match
        jsr room_show_hover_label
        rts

room_hover_next
        dex
        bpl room_hover_scan_loop
        jmp room_hover_no_match

room_hover_no_match
        lda room_hover_match
        cmp #$FF
        beq room_hover_update_done
        lda #$FF
        sta room_hover_match
        jsr room_clear_hover_label
room_hover_update_done
        rts

room_process_click_response
        lda #0
        sta room_action_pending_reload
        lda rx_buffer
        bne room_action_has_data
        jmp room_action_done

room_action_has_data

        cmp #'R'
        bne room_check_text
        lda rx_buffer+1
        cmp #'O'
        bne room_check_text
        lda rx_buffer+2
        cmp #'O'
        bne room_check_text
        lda rx_buffer+3
        cmp #'M'
        bne room_check_text
        lda rx_buffer+4
        cmp #':'
        bne room_check_text
        jsr room_apply_change_action
        rts

room_check_text
        lda rx_buffer
        cmp #'P'
        bne room_check_text_legacy
        lda rx_buffer+1
        cmp #'O'
        bne room_check_text_legacy
        lda rx_buffer+2
        cmp #'P'
        bne room_check_text_legacy
        lda rx_buffer+3
        cmp #':'
        bne room_check_text_legacy
        jsr room_apply_popup_action
        rts

room_check_text_legacy
        lda rx_buffer
        cmp #'T'
        bne room_check_gfx
        lda rx_buffer+1
        cmp #'E'
        bne room_check_gfx
        lda rx_buffer+2
        cmp #'X'
        bne room_check_gfx
        lda rx_buffer+3
        cmp #'T'
        bne room_check_gfx
        lda rx_buffer+4
        cmp #':'
        bne room_check_gfx
        jsr room_apply_text_action
        rts

room_check_gfx
        lda rx_buffer
        cmp #'G'
        bne room_check_orig
        lda rx_buffer+1
        cmp #'F'
        bne room_check_orig
        lda rx_buffer+2
        cmp #'X'
        bne room_check_orig
        lda rx_buffer+3
        cmp #':'
        bne room_check_orig
        jsr room_apply_graphics_action
        rts

room_check_orig
        lda rx_buffer
        cmp #'O'
        bne room_action_done
        lda rx_buffer+1
        cmp #'R'
        bne room_action_done
        lda rx_buffer+2
        cmp #'I'
        bne room_action_done
        lda rx_buffer+3
        cmp #'G'
        bne room_action_done
        jsr room_apply_original_graphics_action

room_action_done
        rts

room_apply_change_action
        ldx #0
        ldy #5
room_change_copy_loop
        cpx #ROOM_NAME_MAX
        bcs room_change_finish_max
        lda rx_buffer,y
        beq room_change_finish
        cmp #ATASCII_RET
        beq room_change_finish
        sta current_room_name,x
        inx
        iny
        bne room_change_copy_loop

room_change_finish
        lda #0
        sta current_room_name,x
        cpx #0
        beq room_change_done
        lda #1
        sta room_action_pending_reload
room_change_done
        rts

room_change_finish_max
        lda #0
        sta current_room_name+ROOM_NAME_MAX
        lda #1
        sta room_action_pending_reload
        rts

room_popup_line_ptr_from_index_a
        sta zp_tmp1
        lda #<demo_popup_lines
        sta zp_tmp_ptr
        lda #>demo_popup_lines
        sta zp_tmp_ptr+1
room_popup_line_ptr_loop
        lda zp_tmp1
        beq room_popup_line_ptr_done
        clc
        lda zp_tmp_ptr
        adc #DEMO_POPUP_LINE_STRIDE
        sta zp_tmp_ptr
        bcc room_popup_line_ptr_no_carry
        inc zp_tmp_ptr+1
room_popup_line_ptr_no_carry
        dec zp_tmp1
        jmp room_popup_line_ptr_loop
room_popup_line_ptr_done
        rts

room_apply_text_action
        jsr demo_clear_popup_text
        ldx #0
        ldy #5
room_text_copy_loop
        cpx #DEMO_POPUP_TEXT_MAX
        bcs room_text_finish
        lda rx_buffer,y
        beq room_text_finish
        cmp #ATASCII_RET
        beq room_text_finish
        sta demo_popup_lines,x
        inx
        iny
        bne room_text_copy_loop

room_text_finish
        lda #0
        sta demo_popup_lines,x
        stx demo_popup_line_lengths
        cpx #0
        beq room_text_done
        lda #1
        sta demo_popup_line_count
        jsr demo_show_popup
room_text_done
        rts

room_apply_popup_action
        jsr demo_clear_popup_text
        ldy #4
        lda rx_buffer,y
        cmp #'1'
        bne room_popup_clickable_done
        lda #1
        sta demo_popup_clickable
room_popup_clickable_done
        iny
        lda rx_buffer,y
        cmp #'|'
        bne room_popup_done
        iny
        ldx #0

room_popup_line_loop
        cpx #DEMO_POPUP_LINES_MAX
        bcs room_popup_finish
        stx demo_popup_line_ix
        txa
        jsr room_popup_line_ptr_from_index_a
        ldx #0

room_popup_char_copy_loop
        lda rx_buffer,y
        beq room_popup_line_done
        cmp #ATASCII_RET
        beq room_popup_line_done
        cmp #'|'
        beq room_popup_line_done
        cpx #DEMO_POPUP_TEXT_MAX
        bcs room_popup_char_skip_store
        sty zp_tmp2
        ldy #0
        sta (zp_tmp_ptr),y
        inc zp_tmp_ptr
        bne room_popup_char_store_done
        inc zp_tmp_ptr+1
room_popup_char_store_done
        ldy zp_tmp2
        inx
room_popup_char_skip_store
        iny
        bne room_popup_char_copy_loop

room_popup_line_done
        sty zp_tmp2
        ldy #0
        lda #0
        sta (zp_tmp_ptr),y
        ldy demo_popup_line_ix
        txa
        sta demo_popup_line_lengths,y
        inc demo_popup_line_count
        ldy zp_tmp2
        lda rx_buffer,y
        cmp #'|'
        bne room_popup_finish
        iny
        ldx demo_popup_line_ix
        inx
        jmp room_popup_line_loop

room_popup_finish
        lda demo_popup_line_count
        beq room_popup_done
        jsr demo_show_popup
room_popup_done
        rts

room_apply_graphics_action
        ldx #0
        ldy #4
room_gfx_room_copy_loop
        cpx #ROOM_NAME_MAX
        bcs room_gfx_fail
        lda rx_buffer,y
        beq room_gfx_fail
        cmp #','
        beq room_gfx_room_done
        cmp #ATASCII_RET
        beq room_gfx_fail
        sta room_patch_source_room,x
        inx
        iny
        bne room_gfx_room_copy_loop

room_gfx_room_done
        lda #0
        sta room_patch_source_room,x
        cpx #0
        beq room_gfx_fail
        iny
        jsr room_parse_hex_byte_field
        bcs room_gfx_fail
        sta room_patch_x_hi
        iny
        lda rx_buffer,y
        cmp #','
        bne room_gfx_fail
        iny
        jsr room_parse_hex_byte_field
        bcs room_gfx_fail
        sta room_patch_x_lo
        iny
        lda rx_buffer,y
        cmp #','
        bne room_gfx_fail
        iny
        jsr room_parse_hex_byte_field
        bcs room_gfx_fail
        sta room_patch_y
        iny
        lda rx_buffer,y
        cmp #','
        bne room_gfx_fail
        iny
        jsr room_parse_hex_byte_field
        bcs room_gfx_fail
        sta room_patch_width
        iny
        lda rx_buffer,y
        cmp #','
        bne room_gfx_fail
        iny
        jsr room_parse_hex_byte_field
        bcs room_gfx_fail
        sta room_patch_height
        jsr room_cache_prepare_replace
        jsr room_fetch_graphics_patch
room_gfx_fail
        rts

room_apply_original_graphics_action
        ldy #4
        lda rx_buffer,y
        cmp #':'
        beq room_orig_parse_payload
        jsr room_restore_original_graphics
        rts

room_orig_parse_payload
        iny
        jsr room_parse_hex_byte_field
        bcs room_orig_fail
        sta room_patch_x_hi
        iny
        lda rx_buffer,y
        cmp #','
        bne room_orig_fail
        iny
        jsr room_parse_hex_byte_field
        bcs room_orig_fail
        sta room_patch_x_lo
        iny
        lda rx_buffer,y
        cmp #','
        bne room_orig_fail
        iny
        jsr room_parse_hex_byte_field
        bcs room_orig_fail
        sta room_patch_y
        iny
        lda rx_buffer,y
        cmp #','
        bne room_orig_fail
        iny
        jsr room_parse_hex_byte_field
        bcs room_orig_fail
        sta room_patch_width
        iny
        lda rx_buffer,y
        cmp #','
        bne room_orig_fail
        iny
        jsr room_parse_hex_byte_field
        bcs room_orig_fail
        sta room_patch_height
        jsr room_original_graphics_matches_cache
        bcc room_orig_fail
        jsr room_restore_original_graphics
room_orig_fail
        rts

room_original_graphics_matches_cache
        lda room_patch_restore_mode
        beq room_orig_match_fail
        lda room_patch_x_lo
        cmp room_patch_restore_x_lo
        bne room_orig_match_fail
        lda room_patch_x_hi
        cmp room_patch_restore_x_hi
        bne room_orig_match_fail
        lda room_patch_y
        cmp room_patch_restore_y
        bne room_orig_match_fail
        lda room_patch_width
        cmp room_patch_restore_width
        bne room_orig_match_fail
        lda room_patch_height
        cmp room_patch_restore_height
        bne room_orig_match_fail
        sec
        rts

room_orig_match_fail
        clc
        rts

room_parse_hex_byte_field
        lda rx_buffer,y
        jsr room_ascii_hex_to_nibble
        cmp #$FF
        beq room_parse_hex_byte_fail
        asl
        asl
        asl
        asl
        sta zp_tmp1
        iny
        lda rx_buffer,y
        jsr room_ascii_hex_to_nibble
        cmp #$FF
        beq room_parse_hex_byte_fail
        ora zp_tmp1
        clc
        rts

room_parse_hex_byte_fail
        sec
        rts

room_ascii_hex_to_nibble
        cmp #'0'
        bcc room_ascii_hex_fail
        cmp #'9'+1
        bcc room_ascii_hex_digit
        cmp #'A'
        bcc room_ascii_hex_lower_check
        cmp #'F'+1
        bcc room_ascii_hex_upper
room_ascii_hex_lower_check
        cmp #'a'
        bcc room_ascii_hex_fail
        cmp #'f'+1
        bcs room_ascii_hex_fail
        sec
        sbc #'a'-10
        rts

room_ascii_hex_upper
        sec
        sbc #'A'-10
        rts

room_ascii_hex_digit
        sec
        sbc #'0'
        rts

room_ascii_hex_fail
        lda #$FF
        rts