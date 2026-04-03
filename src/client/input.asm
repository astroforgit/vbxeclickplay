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