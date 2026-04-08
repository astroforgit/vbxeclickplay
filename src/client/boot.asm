main
        lda #$22
        sta SDMCTL
        jsr clear_debug
        jsr init_current_room_name

        jsr detect_vbxe
        bcc no_vbxe
        jsr status_copy_font
        jsr room_selection_cache_clear_all

        lda #<msg_loading_room
        ldx #>msg_loading_room
        ldy #msg_loading_room_end-msg_loading_room
        jsr print_record

load_room
        jsr clear_debug
        jsr copy_room_url_to_buffer
        jsr fetch_room_image
        bcc image_ok
        jsr report_failure
fail_loop
        jmp fail_loop

no_vbxe
        lda #$11
        sta debug_stage
        jsr report_failure
        jmp fail_loop

image_ok
        lda #0
        sta SDMCTL
        jsr show_fullscreen
        jsr room_load_hover_metadata
        lda demo_mode
        beq room_image_loop
        jmp demo_image_loop

room_image_loop
        lda #0
        sta demo_input_active
        jsr demo_init_input
        jsr demo_draw_cursor
        jsr room_update_hover_label
room_wait
        jsr wait_one_frame
        jsr demo_update_input
        jsr room_update_hover_label
        jsr demo_draw_cursor
        jsr demo_poll_click
        bcc room_key_check
        jsr room_handle_click
        lda room_action_pending_reload
        beq room_wait
        lda #0
        sta room_action_pending_reload
        jsr demo_suspend_input_irq
        lda #0
        sta demo_input_active
        lda #$22
        sta SDMCTL
        jmp load_room
room_key_check
        lda CH
        cmp #KEY_NONE
        beq room_wait
        lda #KEY_NONE
        sta CH
        lda zp_demo_prev_y
        cmp #$FF
        beq room_reload
        jsr demo_restore_cursor
        lda #$FF
        sta zp_demo_prev_x
        sta zp_demo_prev_y
room_reload
        jsr demo_suspend_input_irq
        lda #0
        sta demo_input_active
        lda #$22
        sta SDMCTL
        jmp load_room

room_handle_click
        lda zp_demo_prev_y
        cmp #$FF
        beq room_click_send
        jsr demo_restore_cursor
        lda #$FF
        sta zp_demo_prev_x
        sta zp_demo_prev_y
room_click_send
	        lda demo_popup_active
	        beq room_click_send_fetch
	        jsr demo_popup_hit_test
	        bcc room_click_popup_outside
	        jsr demo_popup_text_hit_test
	        bcc room_click_popup_consume
	        jsr demo_restore_popup_under
	        jsr demo_suspend_input_irq
	        jsr copy_popup_click_url_to_buffer
	        jsr fetch_text_payload
	        bcs room_click_resume
	        jsr room_process_click_response
	        jmp room_click_resume
room_click_popup_consume
	        jsr demo_restore_popup_under
	        jmp room_click_done
room_click_popup_outside
	        jsr demo_restore_popup_under
room_click_send_fetch
        jsr demo_suspend_input_irq
        jsr copy_click_url_to_buffer
        jsr fetch_text_payload
        bcs room_click_resume
        jsr room_process_click_response
room_click_resume
        lda room_action_pending_reload
        bne room_click_done_reload
        jsr demo_resume_input_irq
room_click_done
        jsr demo_draw_cursor
        jsr room_update_hover_label
room_click_done_reload
        rts

demo_image_loop
        lda #0
        sta demo_input_active
        jsr demo_init_input
        jsr demo_draw_cursor
demo_wait
        jsr wait_one_frame
        jsr demo_update_input
        jsr demo_draw_cursor
        jsr demo_poll_click
        bcc demo_key_check
        jsr demo_click_stamp
        jmp demo_wait
demo_key_check
        lda CH
        cmp #KEY_NONE
        beq demo_wait
        cmp #KEY_SPACE
        beq demo_popup_key
        cmp #CH_SPACE
        beq demo_popup_key
        lda #KEY_NONE
        sta CH
        jmp demo_next
demo_popup_key
        lda #KEY_NONE
        sta CH
        jsr demo_show_popup
        jmp demo_wait

demo_next
        jsr generate_demo_image
        jmp image_ok

clear_debug
        lda #0
        sta debug_stage
        sta debug_dstats
        sta debug_fn_error
        sta debug_connected
        sta debug_bytes_lo
        sta debug_bytes_hi
        sta debug_timeout_ctr
        sta debug_rx_len
        sta zp_rx_len
        sta img_pal_leftover
        sta demo_mode
        sta demo_input_active
        sta demo_popup_active
        sta room_patch_restore_mode
        sta room_sel_cache_active
        sta room_hover_count
        lda #$FF
        sta room_sel_cache_pending_slot
        sta room_sel_cache_hit_slot
        sta room_hover_match
        jsr demo_clear_popup_text
        rts

show_banner
        lda #<msg_title
        ldx #>msg_title
        ldy #msg_title_end-msg_title
        jsr print_record
        lda #<msg_text_url
        ldx #>msg_text_url
        ldy #msg_text_url_end-msg_text_url
        jsr print_record
        lda #<text_url_string
        ldx #>text_url_string
        ldy #text_url_string_end-text_url_string-1
        jsr print_record
        lda #<msg_wait_text
        ldx #>msg_wait_text
        ldy #msg_wait_text_end-msg_wait_text
        jsr print_record
        rts

wait_for_start_key
        lda #0
        sta demo_mode
        lda #KEY_NONE
        sta CH
wait_start_loop
        lda CH
        cmp #KEY_SPACE
        beq wait_space_done
        cmp #CH_SPACE
        beq wait_space_done
        cmp #KEY_D
        beq wait_demo_done
        cmp #KEY_NONE
        beq wait_start_loop
        lda #KEY_NONE
        sta CH
        jmp wait_start_loop
wait_space_done
        lda #0
        sta demo_mode
        lda #KEY_NONE
        sta CH
        rts
wait_demo_done
        lda #1
        sta demo_mode
        lda #KEY_NONE
        sta CH
        rts

wait_for_any_key
        lda #KEY_NONE
        sta CH
wait_any_loop
        lda CH
        cmp #KEY_NONE
        beq wait_any_loop
        lda #KEY_NONE
        sta CH
        rts