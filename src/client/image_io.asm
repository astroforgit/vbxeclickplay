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