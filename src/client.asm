; Atari XEX header is generated automatically by MADS with -o:*.xex

        icl 'vbxe_const.asm'

CIOV    = $E456
ICCOM   = $0342
ICBAL   = $0344
ICBAH   = $0345
ICBLL   = $0348
ICBLH   = $0349

VIEW_TIMEOUT = 240
READ_LIMIT   = 96
KEY_D        = $3A
DEMO_HEIGHT  = 200
DEMO_STAMP_SIZE = 20
DEMO_CURSOR_MAX_X = 152
DEMO_CURSOR_MAX_Y = 192
DEMO_CURSOR_START_X = 76
DEMO_CURSOR_START_Y = 96
DEMO_CURSOR_COLOR = 1
DEMO_CURSOR_WIDTH = 16
DEMO_POPUP_WIDTH = 96
DEMO_POPUP_WIDTH_LOGICAL = 48
DEMO_POPUP_INNER_WIDTH = 94
DEMO_POPUP_HEIGHT = 12
DEMO_POPUP_LAST_ROW = 11
DEMO_POPUP_MAX_X = 112
DEMO_POPUP_MAX_Y = 188
DEMO_POPUP_BORDER_COLOR = 250
DEMO_POPUP_FILL_COLOR = 24
DEMO_POPUP_TEXT_COLOR = 252

STUB_BASE      = $0600
STUB_TIRQ_EXIT = STUB_BASE+17

zp_demo_cursor_x = $B0
zp_demo_cursor_y = $B1
zp_demo_prev_x   = $B2
zp_demo_prev_trig = $B3
zp_mouse_dx      = $B4
zp_mouse_dy      = $B5
zp_demo_prev_y   = $B6

        org $2000

main
        lda #$22
        sta SDMCTL
        jsr clear_debug

        jsr detect_vbxe
        bcc no_vbxe

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
        lda demo_mode
        beq room_image_loop
        jmp demo_image_loop

room_image_loop
        lda #0
        sta demo_input_active
        jsr demo_init_input
        jsr demo_draw_cursor
room_wait
        jsr wait_one_frame
        jsr demo_update_input
        jsr demo_draw_cursor
        jsr demo_poll_click
        bcc room_key_check
        jsr room_handle_click
        jmp room_wait
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
        jsr demo_suspend_input_irq
        jsr copy_click_url_to_buffer
        jsr fetch_text_payload
        jsr demo_resume_input_irq
room_click_done
        jsr demo_draw_cursor
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

demo_init_input
        lda demo_input_active
        bne demo_init_done

        lda #DEMO_CURSOR_START_X
        sta zp_demo_cursor_x
        lda #DEMO_CURSOR_START_Y
        sta zp_demo_cursor_y
        lda #$FF
        sta zp_demo_prev_x
        sta zp_demo_prev_y
        lda #0
        sta zp_mouse_dx
        sta zp_mouse_dy

        lda PORTA
        lsr
        lsr
        lsr
        lsr
        tax
        txa
        and #$03
        asl
        asl
        sta demo_mouse_old_x
        txa
        lsr
        lsr
        and #$03
        asl
        asl
        sta demo_mouse_old_y

        lda STRIG1
        beq demo_init_trig_pressed
        lda #1
        bne demo_init_trig_store
demo_init_trig_pressed
        lda #0
demo_init_trig_store
        sta zp_demo_prev_trig

        jsr demo_install_timer_stubs

        sei
        lda #<STUB_BASE
        sta VTIMR2
        lda #>STUB_BASE
        sta VTIMR2+1

        lda POKMSK
        ora #$02
        sta POKMSK
        sta IRQEN

        lda #0
        sta AUDCTL
        sta AUDC2
        lda #$40
        sta AUDF2
        sta STIMER
        cli

        lda #1
        sta demo_input_active
demo_init_done
        rts

demo_install_timer_stubs
        ldy #0
demo_stub_copy
        lda demo_timer_stubs,y
        sta STUB_BASE,y
        iny
        cpy #demo_timer_stubs_end-demo_timer_stubs
        bne demo_stub_copy

        lda #<demo_timer_irq
        sta STUB_BASE+15
        lda #>demo_timer_irq
        sta STUB_BASE+16
        rts

demo_timer_irq
        txa
        pha
        tya
        pha

        lda PORTA
        lsr
        lsr
        lsr
        lsr
        tax

        and #$03
        ora demo_mouse_old_x
        tay
        lda demo_mouse_movtab,y
        beq demo_timer_x_done
        bmi demo_timer_x_left
        inc zp_mouse_dx
        jmp demo_timer_x_done
demo_timer_x_left
        dec zp_mouse_dx
demo_timer_x_done
        txa
        and #$03
        asl
        asl
        sta demo_mouse_old_x

        txa
        lsr
        lsr
        and #$03
        ora demo_mouse_old_y
        tay
        lda demo_mouse_movtab,y
        beq demo_timer_y_done
        bmi demo_timer_y_up
        inc zp_mouse_dy
        jmp demo_timer_y_done
demo_timer_y_up
        dec zp_mouse_dy
demo_timer_y_done
        txa
        lsr
        lsr
        and #$03
        asl
        asl
        sta demo_mouse_old_y

        pla
        tay
        pla
        tax
        jmp STUB_TIRQ_EXIT

demo_update_input
        sei
        lda zp_mouse_dx
        sta demo_pending_dx
        lda #0
        sta zp_mouse_dx
        lda zp_mouse_dy
        sta demo_pending_dy
        lda #0
        sta zp_mouse_dy
        cli

        lda demo_pending_dx
        ora demo_pending_dy
        beq demo_update_joy
        jsr demo_apply_mouse
demo_update_joy
        jsr demo_apply_joystick
        rts

demo_apply_mouse
        lda demo_pending_dx
        beq demo_apply_mouse_y
        bpl demo_apply_mouse_x_pos
        eor #$FF
        clc
        adc #1
        lsr
        tax
        beq demo_apply_mouse_x_clear
demo_apply_mouse_x_neg_loop
        lda zp_demo_cursor_x
        beq demo_apply_mouse_x_clear
        dec zp_demo_cursor_x
        dex
        bne demo_apply_mouse_x_neg_loop
        jmp demo_apply_mouse_x_clear

demo_apply_mouse_x_pos
        lsr
        tax
        beq demo_apply_mouse_x_clear
demo_apply_mouse_x_pos_loop
        lda zp_demo_cursor_x
        cmp #DEMO_CURSOR_MAX_X
        bcs demo_apply_mouse_x_clear
        inc zp_demo_cursor_x
        dex
        bne demo_apply_mouse_x_pos_loop

demo_apply_mouse_x_clear
        lda #0
        sta demo_pending_dx

demo_apply_mouse_y
        lda demo_pending_dy
        beq demo_apply_mouse_done
        bpl demo_apply_mouse_y_pos
        eor #$FF
        clc
        adc #1
        lsr
        tax
        beq demo_apply_mouse_y_clear
demo_apply_mouse_y_neg_loop
        lda zp_demo_cursor_y
        beq demo_apply_mouse_y_clear
        dec zp_demo_cursor_y
        dex
        bne demo_apply_mouse_y_neg_loop
        jmp demo_apply_mouse_y_clear

demo_apply_mouse_y_pos
        lsr
        tax
        beq demo_apply_mouse_y_clear
demo_apply_mouse_y_pos_loop
        lda zp_demo_cursor_y
        cmp #DEMO_CURSOR_MAX_Y
        bcs demo_apply_mouse_y_clear
        inc zp_demo_cursor_y
        dex
        bne demo_apply_mouse_y_pos_loop

demo_apply_mouse_y_clear
        lda #0
        sta demo_pending_dy
demo_apply_mouse_done
        rts

demo_apply_joystick
        lda STICK1
        and #$0F
        sta demo_stick_state
        cmp #$0F
        beq demo_joy_done

        lda demo_stick_state
        and #$04
        bne demo_joy_right
        lda zp_demo_cursor_x
        beq demo_joy_right
        dec zp_demo_cursor_x
demo_joy_right
        lda demo_stick_state
        and #$08
        bne demo_joy_up
        lda zp_demo_cursor_x
        cmp #DEMO_CURSOR_MAX_X
        bcs demo_joy_up
        inc zp_demo_cursor_x
demo_joy_up
        lda demo_stick_state
        and #$01
        bne demo_joy_down
        lda zp_demo_cursor_y
        beq demo_joy_down
        dec zp_demo_cursor_y
demo_joy_down
        lda demo_stick_state
        and #$02
        bne demo_joy_done
        lda zp_demo_cursor_y
        cmp #DEMO_CURSOR_MAX_Y
        bcs demo_joy_done
        inc zp_demo_cursor_y
demo_joy_done
        rts

demo_poll_click
        lda STRIG1
        beq demo_click_pressed
        lda #1
        sta zp_demo_prev_trig
        clc
        rts

demo_click_pressed
        lda zp_demo_prev_trig
        beq demo_click_held
        lda #0
        sta zp_demo_prev_trig
        sec
        rts
demo_click_held
        clc
        rts

demo_suspend_input_irq
        lda demo_input_active
        beq demo_suspend_done
        sei
        lda POKMSK
        and #$FD
        sta POKMSK
        sta IRQEN
        cli
demo_suspend_done
        rts

demo_resume_input_irq
        lda demo_input_active
        beq demo_resume_done
        sei
        lda POKMSK
        ora #$02
        sta POKMSK
        sta IRQEN
        lda #$40
        sta AUDF2
        sta STIMER
        cli
demo_resume_done
        rts

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
        lda #0
        sta demo_cursor_row_ix
        sta demo_cursor_save_ix
demo_save_row_loop
        lda zp_demo_cursor_y
        clc
        adc demo_cursor_row_ix
        ldx zp_demo_cursor_x
        jsr demo_prepare_cursor_row_table
        jsr demo_mem_open
        ldx #0
demo_save_pix_loop
        ldy #0
        lda (zp_tmp_ptr),y
        ldy demo_cursor_save_ix
        sta demo_cursor_saved,y
        inc demo_cursor_save_ix
        jsr demo_mem_advance
        inx
        cpx #DEMO_CURSOR_WIDTH
        bne demo_save_pix_loop
        memb_off
        inc demo_cursor_row_ix
        lda demo_cursor_row_ix
        cmp #demo_arrow_data_end-demo_arrow_data
        bne demo_save_row_loop
        rts

demo_restore_cursor
        lda #0
        sta demo_cursor_row_ix
        sta demo_cursor_save_ix
demo_restore_row_loop
        lda zp_demo_prev_y
        clc
        adc demo_cursor_row_ix
        ldx zp_demo_prev_x
        jsr demo_prepare_cursor_row_table
        jsr demo_mem_open
        ldx #0
demo_restore_pix_loop
        ldy demo_cursor_save_ix
        lda demo_cursor_saved,y
        inc demo_cursor_save_ix
        jsr demo_mem_put
        inx
        cpx #DEMO_CURSOR_WIDTH
        bne demo_restore_pix_loop
        memb_off
        inc demo_cursor_row_ix
        lda demo_cursor_row_ix
        cmp #demo_arrow_data_end-demo_arrow_data
        bne demo_restore_row_loop
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
        lda #0
        sta demo_cursor_row_ix
demo_plot_row_loop
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
        cpx #8
        bne demo_plot_bit_loop
        memb_off
demo_plot_row_next
        inc demo_cursor_row_ix
        lda demo_cursor_row_ix
        cmp #demo_arrow_data_end-demo_arrow_data
        bne demo_plot_row_loop
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

copy_text_url_to_buffer
        lda #<text_url_string
        sta zp_tmp_ptr
        lda #>text_url_string
        sta zp_tmp_ptr+1
        jmp copy_string_to_buffer

copy_room_url_to_buffer
        lda #<room_url_string
        sta zp_tmp_ptr
        lda #>room_url_string
        sta zp_tmp_ptr+1
        jmp copy_string_to_buffer

copy_click_url_to_buffer
        lda zp_demo_cursor_x
        lsr
        lsr
        lsr
        lsr
        jsr nibble_to_hex
        sta click_url_x_hi

        lda zp_demo_cursor_x
        jsr nibble_to_hex
        sta click_url_x_lo

        lda zp_demo_cursor_y
        lsr
        lsr
        lsr
        lsr
        jsr nibble_to_hex
        sta click_url_y_hi

        lda zp_demo_cursor_y
        jsr nibble_to_hex
        sta click_url_y_lo

        lda #<click_url_string
        sta zp_tmp_ptr
        lda #>click_url_string
        sta zp_tmp_ptr+1
        jmp copy_string_to_buffer

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
        rts

fetch_room_image
        lda #$12
        sta debug_stage
        jsr fn_open
        lda DSTATS
        sta debug_dstats
        bcc fetch_open_ok
        jmp fetch_fail

fetch_open_ok
        lda #$13
        sta debug_stage
        jsr read_header_chunk
        bcc fetch_header_ok
        jmp fetch_fail_close

fetch_header_ok
        lda img_height
        sta debug_rx_len

        lda #$14
        sta debug_stage
        jsr read_palette_stream
        bcc fetch_palette_ok
        jmp fetch_fail_close

fetch_palette_ok
        jsr init_image_write
        jsr demo_build_row_table
        lda img_pal_leftover
        sta zp_rx_len
        jsr write_pixel_chunk

        lda #$15
        sta debug_stage
        jsr read_pixels_stream
        bcc fetch_pixels_ok
        jmp fetch_fail_close

fetch_pixels_ok
        jsr fn_close
        lda #<img_pal_buf
        sta zp_tmp_ptr
        lda #>img_pal_buf
        sta zp_tmp_ptr+1
        jsr set_image_palette
        clc
        rts

fetch_fail_close
        jsr fn_close
fetch_fail
        sec
        rts

read_header_chunk
        lda #VIEW_TIMEOUT
        sta debug_timeout_ctr

        lda #3
        sta zp_fn_bytes_lo
        sta debug_bytes_lo
        lda #0
        sta zp_fn_bytes_hi
        sta debug_bytes_hi
        jsr fn_read
        lda DSTATS
        sta debug_dstats
        bcc hdr_read_ok

hdr_wait
        jsr poll_status
        bcc hdr_status_ok
        jmp hdr_err

hdr_status_ok
        lda debug_fn_error
        beq hdr_check_bytes
        cmp #136
        beq hdr_err
        cmp #128
        bcs hdr_err

hdr_check_bytes
        lda debug_bytes_hi
        bne hdr_ready
        lda debug_bytes_lo
        cmp #3
        bcs hdr_ready
        lda debug_connected
        beq hdr_err
        dec debug_timeout_ctr
        beq hdr_err
        jsr wait_one_frame
        jmp hdr_wait

hdr_ready
        lda #3
        sta zp_fn_bytes_lo
        lda #0
        sta zp_fn_bytes_hi
        jsr fn_read
        lda DSTATS
        sta debug_dstats
        bcc hdr_read_ok
        jmp hdr_err

hdr_read_ok
        lda rx_buffer
        sta img_width
        lda rx_buffer+1
        sta img_width+1
        lda rx_buffer+2
        sta img_height

        lda img_width+1
        cmp #2
        bcc hdr_chk_lo
        beq hdr_chk_hi
        jmp hdr_err

hdr_chk_hi
        lda img_width
        cmp #$41
        bcs hdr_err
        jmp hdr_chk_h

hdr_chk_lo
        lda img_width
        cmp #8
        bcc hdr_err

hdr_chk_h
        lda img_height
        cmp #8
        bcc hdr_err
        cmp #209
        bcs hdr_err
        clc
        rts
hdr_err
        sec
        rts

read_palette_stream
        lda #<img_pal_buf
        sta zp_tmp_ptr
        lda #>img_pal_buf
        sta zp_tmp_ptr+1
        lda #0
        sta img_pal_count
        sta img_pal_count+1
        sta img_pal_leftover
        lda #VIEW_TIMEOUT
        sta debug_timeout_ctr

pal_wait
        jsr poll_status
        bcc pal_status_ok
        jmp pal_err

pal_status_ok
        lda debug_fn_error
        cmp #136
        beq pal_err
        cmp #128
        bcs pal_err
        lda debug_bytes_lo
        ora debug_bytes_hi
        beq pal_no_data

        jsr fn_read
        lda DSTATS
        sta debug_dstats
        bcc pal_read_ok
        jmp pal_err

pal_no_data
        dec debug_timeout_ctr
        beq pal_err
        jsr wait_one_frame
        jmp pal_wait

pal_read_ok
        lda zp_rx_len
        beq pal_wait
        lda #VIEW_TIMEOUT
        sta debug_timeout_ctr

        ldy #0
pal_copy
        cpy zp_rx_len
        beq pal_check_done
        lda rx_buffer,y
        sty zp_tmp3
        ldy #0
        sta (zp_tmp_ptr),y
        ldy zp_tmp3
        inc zp_tmp_ptr
        bne pal_ptr_ok
        inc zp_tmp_ptr+1
pal_ptr_ok
        inc img_pal_count
        bne pal_count_ok
        inc img_pal_count+1
pal_count_ok
        lda img_pal_count+1
        cmp #3
        bcs pal_done
        iny
        jmp pal_copy

pal_check_done
        jmp pal_wait

pal_done
        iny
        cpy zp_rx_len
        bcs pal_no_left
        ldx #0
pal_shift
        lda rx_buffer,y
        sta rx_buffer,x
        iny
        inx
        cpy zp_rx_len
        bcc pal_shift
        stx img_pal_leftover
        clc
        rts

pal_no_left
        lda #0
        sta img_pal_leftover
        clc
        rts
pal_err
        lda #0
        sta img_pal_leftover
        sec
        rts

read_pixels_stream
        lda #VIEW_TIMEOUT
        sta debug_timeout_ctr
pix_wait
        jsr poll_status
        bcc pix_status_ok
        jmp pix_err

pix_status_ok
        lda debug_fn_error
        bmi pix_status_fatal
        jmp pix_check_data

pix_status_fatal
        cmp #136
        beq pix_done
        jmp pix_err

pix_check_data
        lda debug_connected
        beq pix_done
        lda debug_bytes_lo
        ora debug_bytes_hi
        bne pix_read
        dec debug_timeout_ctr
        beq pix_done
        jsr wait_one_frame
        jmp pix_wait

pix_read
        jsr fn_read
        lda DSTATS
        sta debug_dstats
        bcc pix_read_ok
        jmp pix_done

pix_read_ok
        lda zp_rx_len
        beq pix_wait
        lda #VIEW_TIMEOUT
        sta debug_timeout_ctr
        jsr write_pixel_chunk
        jmp pix_wait

pix_done
        clc
        rts
pix_err
        sec
        rts

init_image_write
        lda #<VRAM_IMG_BASE
        sta img_vram
        lda #>VRAM_IMG_BASE
        sta img_vram+1
        lda #0
        sta img_vram+2

        lda img_vram+2
        asl
        asl
        sta img_wr_bank
        lda img_vram+1
        asl
        rol img_wr_bank
        asl
        rol img_wr_bank

        lda img_vram
        sta zp_img_ptr
        lda img_vram+1
        and #$3F
        ora #$40
        sta zp_img_ptr+1
        rts

write_pixel_chunk
        lda zp_rx_len
        beq write_done

        sei
        lda img_wr_bank
        ora #$80
        sta zp_memb_shadow
        ldy #VBXE_MEMAC_B
        sta (zp_vbxe_base),y

        ldx #0
write_loop
        ldy #0
        lda rx_buffer,x
        sta (zp_img_ptr),y
        inc zp_img_ptr
        bne write_next
        inc zp_img_ptr+1
        lda zp_img_ptr+1
        cmp #$80
        bne write_next
        lda #$40
        sta zp_img_ptr+1
        inc img_wr_bank
        lda img_wr_bank
        ora #$80
        sta zp_memb_shadow
        ldy #VBXE_MEMAC_B
        sta (zp_vbxe_base),y

write_next
        inx
        cpx zp_rx_len
        bne write_loop
        memb_off
        cli
write_done
        rts

generate_demo_image
        lda demo_phase
        clc
        adc #$11
        sta demo_phase

        lda #DEMO_HEIGHT
        sta img_height
        jsr init_image_write
        jsr demo_build_row_table
        jsr build_demo_palette

        lda #0
        sta demo_row
demo_row_loop
        lda #0
        sta demo_x_base
        lda #160
        sta demo_chunk_len
        jsr fill_demo_chunk

        lda #160
        sta demo_x_base
        lda #160
        sta demo_chunk_len
        jsr fill_demo_chunk

        inc demo_row
        lda demo_row
        cmp #DEMO_HEIGHT
        bne demo_row_loop

        lda #<img_pal_buf
        sta zp_tmp_ptr
        lda #>img_pal_buf
        sta zp_tmp_ptr+1
        jsr set_image_palette
        rts

build_demo_palette
        lda #<img_pal_buf
        sta zp_tmp_ptr
        lda #>img_pal_buf
        sta zp_tmp_ptr+1
        ldx #0
demo_pal_loop
        txa
        ldy #0
        sta (zp_tmp_ptr),y
        txa
        asl
        ldy #1
        sta (zp_tmp_ptr),y
        txa
        eor #$FF
        ldy #2
        sta (zp_tmp_ptr),y
        clc
        lda zp_tmp_ptr
        adc #3
        sta zp_tmp_ptr
        bcc demo_pal_next
        inc zp_tmp_ptr+1
demo_pal_next
        inx
        bne demo_pal_loop
        rts

fill_demo_chunk
        ldx #0
demo_fill_loop
        txa
        clc
        adc demo_x_base
        eor demo_row
        clc
        adc demo_phase
        ora #8
        sta rx_buffer,x
        inx
        cpx demo_chunk_len
        bne demo_fill_loop
        stx zp_rx_len
        jmp write_pixel_chunk

set_image_palette
        ldy #VBXE_PSEL
        lda #1
        sta (zp_vbxe_base),y

        ldy #VBXE_CSEL
        lda #0
        sta (zp_vbxe_base),y
        ldy #VBXE_CR
        lda #0
        sta (zp_vbxe_base),y
        ldy #VBXE_CG
        sta (zp_vbxe_base),y
        ldy #VBXE_CB
        sta (zp_vbxe_base),y

        ldy #VBXE_CSEL
        lda #COL_WHITE
        sta (zp_vbxe_base),y
        ldy #VBXE_CR
        lda #$FF
        sta (zp_vbxe_base),y
        ldy #VBXE_CG
        sta (zp_vbxe_base),y
        ldy #VBXE_CB
        sta (zp_vbxe_base),y

        ldy #VBXE_CSEL
        lda #COL_RED
        sta (zp_vbxe_base),y
        ldy #VBXE_CR
        lda #$FF
        sta (zp_vbxe_base),y
        ldy #VBXE_CG
        lda #0
        sta (zp_vbxe_base),y
        ldy #VBXE_CB
        sta (zp_vbxe_base),y

        ldy #VBXE_CSEL
        lda #8
        sta (zp_vbxe_base),y

        clc
        lda zp_tmp_ptr
        adc #24
        sta zp_tmp_ptr
        bcc pal_skip_ok
        inc zp_tmp_ptr+1
pal_skip_ok
        ldx #8
setpal_loop
        ldy #0
        lda (zp_tmp_ptr),y
        ldy #VBXE_CR
        sta (zp_vbxe_base),y
        ldy #1
        lda (zp_tmp_ptr),y
        ldy #VBXE_CG
        sta (zp_vbxe_base),y
        ldy #2
        lda (zp_tmp_ptr),y
        ldy #VBXE_CB
        sta (zp_vbxe_base),y
        clc
        lda zp_tmp_ptr
        adc #3
        sta zp_tmp_ptr
        bcc setpal_next
        inc zp_tmp_ptr+1
setpal_next
        inx
        bne setpal_loop
        rts

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

demo_timer_stubs
        tya
        pha
        lda zp_memb_shadow
        sta zp_tirq_saved
        lda #0
        sta zp_memb_shadow
        ldy #VBXE_MEMAC_B
        sta (zp_vbxe_base),y
        jmp $0000

        lda zp_tirq_saved
        sta zp_memb_shadow
        beq *+4
        sta (zp_vbxe_base),y
        pla
        tay
        pla
        rti
demo_timer_stubs_end

demo_mouse_movtab
        dta 0,$FF,1,0, 1,0,0,$FF, $FF,0,0,1, 0,1,$FF,0

demo_font_page_map
        dta 2,0,1,3

demo_arrow_data
        dta $80,$C0,$E0,$F0,$F8,$E0,$A0,$00
demo_arrow_data_end

demo_popup_text
        dta c'hello world',0

        icl 'fujinet.asm'

text_url_string  dta c'N:http://127.0.0.1:3000/',0
text_url_string_end
room_url_string  dta c'N:http://127.0.0.1:3000/room/room1',0
room_url_string_end
click_url_string dta c'N:http://127.0.0.1:3000/click/room1/'
click_url_x_hi   dta c'0'
click_url_x_lo   dta c'0'
                 dta c'/'
click_url_y_hi   dta c'0'
click_url_y_lo   dta c'0',0
click_url_string_end
slide_url_string dta c'N:http://127.0.0.1:3000/slide/'
slide_url_hex_hi dta c'0'
slide_url_hex_lo dta c'0',0
slide_url_string_end

msg_title            dta c'FujiNet demo: text then image', ATASCII_RET
msg_title_end
msg_text_url         dta c'Text URL:', ATASCII_RET
msg_text_url_end
msg_wait_text        dta c'Fetching text...', ATASCII_RET
msg_wait_text_end
msg_text_ok          dta c'Text received from server', ATASCII_RET
msg_text_ok_end
msg_text_fail        dta c'Text fetch failed', ATASCII_RET
msg_text_fail_end
msg_img_fail         dta c'Image fetch failed', ATASCII_RET
msg_img_fail_end
msg_no_vbxe          dta c'VBXE not detected', ATASCII_RET
msg_no_vbxe_end
msg_payload          dta c'Payload:', ATASCII_RET
msg_payload_end
msg_press_space      dta c'Press SPACE for slideshow or D for demo', ATASCII_RET
msg_press_space_end
msg_loading_image    dta c'Loading image...', ATASCII_RET
msg_loading_image_end
msg_loading_room     dta c'Loading room1...', ATASCII_RET
msg_loading_room_end
msg_generating_demo  dta c'Generating demo image...', ATASCII_RET
msg_generating_demo_end
msg_stage_text_open  dta c'Stage: OPEN TEXT', ATASCII_RET
msg_stage_text_open_end
msg_stage_text_wait  dta c'Stage: WAIT TEXT', ATASCII_RET
msg_stage_text_wait_end
msg_stage_text_read  dta c'Stage: READ TEXT', ATASCII_RET
msg_stage_text_read_end
msg_stage_img_open   dta c'Stage: OPEN IMAGE', ATASCII_RET
msg_stage_img_open_end
msg_stage_hdr        dta c'Stage: READ HEADER', ATASCII_RET
msg_stage_hdr_end
msg_stage_pal        dta c'Stage: READ PALETTE', ATASCII_RET
msg_stage_pal_end
msg_stage_pix        dta c'Stage: READ PIXELS', ATASCII_RET
msg_stage_pix_end
dbg_line             dta c'ST=00 DS=00 FE=00 CN=00 BL=00 BH=00 RX=00', ATASCII_RET
dbg_line_end

        org $8800
debug_stage       dta b(0)
debug_dstats      dta b(0)
debug_fn_error    dta b(0)
debug_connected   dta b(0)
debug_bytes_lo    dta b(0)
debug_bytes_hi    dta b(0)
debug_timeout_ctr dta b(0)
debug_rx_len      dta b(0)
img_width         dta b(0),b(0)
img_pal_count     dta b(0),b(0)
img_pal_leftover  dta b(0)
img_height        dta b(0)
img_vram          dta b(0),b(0),b(0)
img_wr_bank       dta b(0)
slide_index       dta b(0)
demo_mode         dta b(0)
demo_phase        dta b(0)
demo_row          dta b(0)
demo_x_base       dta b(0)
demo_chunk_len    dta b(0)
demo_input_active dta b(0)
demo_pending_dx   dta b(0)
demo_pending_dy   dta b(0)
demo_mouse_old_x  dta b(0)
demo_mouse_old_y  dta b(0)
demo_stick_state  dta b(0)
demo_cursor_row_ix dta b(0)
demo_cursor_mask   dta b(0)
demo_cursor_bank   dta b(0)
demo_cursor_x2     dta b(0)
demo_cursor_abs_y  dta b(0)
demo_cursor_ofs_hi dta b(0)
demo_cursor_save_ix dta b(0)
demo_stamp_phase   dta b(0)
demo_stamp_width   dta b(0)
demo_stamp_height  dta b(0)
demo_stamp_row     dta b(0)
demo_popup_active  dta b(0)
demo_popup_x       dta b(0)
demo_popup_y       dta b(0)
demo_popup_row     dta b(0)
demo_popup_char_ix dta b(0)
demo_popup_text_row dta b(0)
demo_popup_font_bits dta b(0)
demo_rowtab_ptr_lo dta b(0)
demo_rowtab_ptr_hi dta b(0)
demo_rowtab_bank   dta b(0)

url_buffer  .ds 256
rx_buffer   .ds 256
img_pal_buf .ds 768
demo_cursor_saved .ds DEMO_CURSOR_WIDTH*(demo_arrow_data_end-demo_arrow_data)
demo_popup_saved .ds DEMO_POPUP_WIDTH*DEMO_POPUP_HEIGHT
demo_row_ptr_lo .ds DEMO_HEIGHT
demo_row_ptr_hi .ds DEMO_HEIGHT
demo_row_bank   .ds DEMO_HEIGHT

        run main