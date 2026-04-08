copy_text_url_to_buffer
        lda #<text_url_string
        sta zp_tmp_ptr
        lda #>text_url_string
        sta zp_tmp_ptr+1
        jmp copy_string_to_buffer

copy_room_url_to_buffer
        lda #<room_url_prefix
        sta zp_tmp_ptr
        lda #>room_url_prefix
        sta zp_tmp_ptr+1
        jsr copy_string_to_buffer
        ldy #0
copy_room_find_end
        lda url_buffer,y
        beq copy_room_append_name
        iny
        bne copy_room_find_end
copy_room_append_name
        jsr append_current_room_name
        lda #0
        sta url_buffer,y
        rts

copy_room_meta_url_to_buffer
        lda #<room_meta_url_prefix
        sta zp_tmp_ptr
        lda #>room_meta_url_prefix
        sta zp_tmp_ptr+1
        jsr copy_string_to_buffer
        ldy #0
copy_room_meta_find_end
        lda url_buffer,y
        beq copy_room_meta_append_name
        iny
        bne copy_room_meta_find_end
copy_room_meta_append_name
        jsr append_current_room_name
        lda #0
        sta url_buffer,y
        rts

copy_click_url_to_buffer
        lda #<click_url_prefix
        sta zp_tmp_ptr
        lda #>click_url_prefix
        sta zp_tmp_ptr+1
        jsr copy_string_to_buffer
        ldy #0
copy_click_find_end
        lda url_buffer,y
        beq copy_click_append_room
        iny
        bne copy_click_find_end
copy_click_append_room
        jsr append_current_room_name
        lda #'/'
        sta url_buffer,y
        iny
        lda zp_demo_cursor_x
        jsr append_hex_byte_to_buffer
        lda #'/'
        sta url_buffer,y
        iny
        lda zp_demo_cursor_y
        jsr append_hex_byte_to_buffer
        lda #0
        sta url_buffer,y
        rts

copy_popup_click_url_to_buffer
        lda #<popup_click_url_prefix
        sta zp_tmp_ptr
        lda #>popup_click_url_prefix
        sta zp_tmp_ptr+1
        jsr copy_string_to_buffer
        ldy #0
copy_popup_click_find_end
        lda url_buffer,y
        beq copy_popup_click_append_room
        iny
        bne copy_popup_click_find_end
copy_popup_click_append_room
        jsr append_current_room_name
        lda #'/'
        sta url_buffer,y
        iny
        lda demo_popup_click_line
        jsr append_hex_byte_to_buffer
        lda #'/'
        sta url_buffer,y
        iny
        lda demo_popup_click_col
        jsr append_hex_byte_to_buffer
        lda #0
        sta url_buffer,y
        rts

copy_slide_url_to_buffer
        lda slide_index
        lsr
        lsr
        lsr
        lsr
        jsr nibble_to_hex
        sta slide_url_hex_hi

        lda slide_index
        jsr nibble_to_hex
        sta slide_url_hex_lo

        lda #<slide_url_string
        sta zp_tmp_ptr
        lda #>slide_url_string
        sta zp_tmp_ptr+1
        jmp copy_string_to_buffer

copy_string_to_buffer
        lda #0
        tay
copy_url_clear_loop
        sta url_buffer,y
        iny
        bne copy_url_clear_loop

        ldy #0
copy_url_copy_loop
        lda (zp_tmp_ptr),y
        sta url_buffer,y
        beq copy_url_done
        iny
        bne copy_url_copy_loop
copy_url_done
        rts

append_current_room_name
        ldx #0
append_room_name_loop
        lda current_room_name,x
        beq append_room_name_done
        sta url_buffer,y
        iny
        inx
        cpx #ROOM_NAME_MAX
        bcc append_room_name_loop
append_room_name_done
        rts

append_hex_byte_to_buffer
        pha
        lsr
        lsr
        lsr
        lsr
        jsr nibble_to_hex
        sta url_buffer,y
        iny
        pla
        jsr nibble_to_hex
        sta url_buffer,y
        iny
        rts

fetch_text_payload
        lda #1
        sta debug_stage
        jsr fn_open
        lda DSTATS
        sta debug_dstats
        bcc text_open_ok
        jmp text_fail

text_open_ok
        lda #VIEW_TIMEOUT
        sta debug_timeout_ctr

text_wait
        lda #2
        sta debug_stage
        jsr poll_status
        bcc text_status_ok
        jmp text_fail_close

text_status_ok
        lda debug_fn_error
        bmi text_status_fatal
        jmp text_check_bytes

text_status_fatal
        cmp #136
        beq text_fail_close
        jmp text_fail_close

text_check_bytes
        lda debug_bytes_hi
        bne text_read
        lda debug_bytes_lo
        bne text_read
        lda debug_connected
        beq text_fail_close
        dec debug_timeout_ctr
        beq text_fail_close
        jsr wait_one_frame
        jmp text_wait

text_read
        lda #3
        sta debug_stage
        lda debug_bytes_hi
        beq text_read_lo
        lda #READ_LIMIT
        bne text_read_set

text_read_lo
        lda debug_bytes_lo
        cmp #READ_LIMIT
        bcc text_read_set
        lda #READ_LIMIT

text_read_set
        sta zp_fn_bytes_lo
        lda #0
        sta zp_fn_bytes_hi
        jsr fn_read
        lda DSTATS
        sta debug_dstats
        bcc text_read_ok
        jmp text_fail_close

text_read_ok
        lda zp_rx_len
        sta debug_rx_len
        jsr sanitize_rx_buffer
        jsr fn_close
        clc
        rts

text_fail_close
        jsr fn_close
text_fail
        sec
        rts

poll_status
        jsr fn_status
        lda DSTATS
        sta debug_dstats
        lda zp_fn_error
        sta debug_fn_error
        lda zp_fn_connected
        sta debug_connected
        lda zp_fn_bytes_lo
        sta debug_bytes_lo
        lda zp_fn_bytes_hi
        sta debug_bytes_hi
        rts

wait_one_frame
        lda RTCLOK+2
wait_one_frame_loop
        cmp RTCLOK+2
        beq wait_one_frame_loop
        rts

sanitize_rx_buffer
        ldx #0
sanitize_loop
        cpx zp_rx_len
        beq sanitize_done
        lda rx_buffer,x
        cmp #13
        beq sanitize_nl
        cmp #10
        beq sanitize_nl
        cmp #32
        bcc sanitize_dot
        cmp #127
        bcs sanitize_dot
        jmp sanitize_next

sanitize_nl
        lda #ATASCII_RET
        bne sanitize_store

sanitize_dot
        lda #'.'

sanitize_store
        sta rx_buffer,x

sanitize_next
        inx
        jmp sanitize_loop
sanitize_done
        cpx #255
        beq sanitize_no_term
        lda #0
        sta rx_buffer,x
sanitize_no_term
        rts