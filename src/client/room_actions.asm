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

room_process_click_response
        lda #0
        sta room_action_pending_reload
        lda rx_buffer
        beq room_action_done

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
        bne room_action_done
        lda rx_buffer+1
        cmp #'F'
        bne room_action_done
        lda rx_buffer+2
        cmp #'X'
        bne room_action_done
        lda rx_buffer+3
        cmp #':'
        bne room_action_done
        jsr room_apply_graphics_action

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

room_apply_text_action
        ldx #0
        ldy #5
room_text_copy_loop
        cpx #DEMO_POPUP_TEXT_MAX
        bcs room_text_finish
        lda rx_buffer,y
        beq room_text_finish
        cmp #ATASCII_RET
        beq room_text_finish
        sta demo_popup_text,x
        inx
        iny
        bne room_text_copy_loop

room_text_finish
        lda #0
        sta demo_popup_text,x
        cpx #0
        beq room_text_done
        jsr demo_show_popup
room_text_done
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
        jsr room_fetch_graphics_patch
room_gfx_fail
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