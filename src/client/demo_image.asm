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