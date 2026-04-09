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

demo_popup_line_offsets
        dta 0,DEMO_POPUP_LINE_STRIDE,DEMO_POPUP_LINE_STRIDE*2,DEMO_POPUP_LINE_STRIDE*3,DEMO_POPUP_LINE_STRIDE*4,DEMO_POPUP_LINE_STRIDE*5

demo_popup_lines
        dta c'hello world',0
        .ds DEMO_POPUP_LINE_STRIDE-(12)
        .ds DEMO_POPUP_LINE_STRIDE*(DEMO_POPUP_LINES_MAX-1)

default_room_name
        dta c'room1',0

text_url_string  dta c'N:http://127.0.0.1:3000/',0
text_url_string_end
room_url_prefix  dta c'N:http://127.0.0.1:3000/room/',0
room_url_prefix_end
room_meta_url_prefix dta c'N:http://127.0.0.1:3000/roommeta/',0
room_meta_url_prefix_end
click_url_prefix dta c'N:http://127.0.0.1:3000/click/',0
click_url_prefix_end
popup_click_url_prefix dta c'N:http://127.0.0.1:3000/popupclick/',0
popup_click_url_prefix_end
gfx_url_prefix   dta c'N:http://127.0.0.1:3000/gfx/',0
gfx_url_prefix_end
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

room_hover_x       .ds ROOM_HOVER_MAX_SELECTIONS
room_hover_y       .ds ROOM_HOVER_MAX_SELECTIONS
room_hover_w       .ds ROOM_HOVER_MAX_SELECTIONS
room_hover_h       .ds ROOM_HOVER_MAX_SELECTIONS
room_hover_names   .ds ROOM_HOVER_MAX_SELECTIONS*(ROOM_HOVER_NAME_MAX+1)

demo_popup_line_lengths .ds DEMO_POPUP_LINES_MAX

current_room_name  .ds ROOM_NAME_MAX+1
room_patch_source_room .ds ROOM_NAME_MAX+1

demo_row_ptr_lo   .ds DEMO_HEIGHT
demo_row_ptr_hi   .ds DEMO_HEIGHT
demo_row_bank     .ds DEMO_HEIGHT