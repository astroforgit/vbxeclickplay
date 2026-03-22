; ============================================================================
; VBXE Web Browser for Atari XE/XL
; Requires: VBXE + FujiNet
; Assembler: MADS
; Build: mads browser.asm -o:browser.xex
; ============================================================================

        opt h+                 ; Atari XEX header
        opt o+                 ; Optimize branches

        icl 'vbxe_const.asm'

; ============================================================================
; Main program
; ============================================================================
        org $3000

; ============================================================================
; Entry point
; ============================================================================
.proc main
        lda #0
        sta SDMCTL
        sei

        jsr vbxe_detect
        bcc no_vbxe

        jsr vbxe_init
        cli

        jsr kbd_init
        jsr mouse_init
        jsr history_init
        jsr html_reset
        jsr render_reset
        jsr ui_init
        jsr show_welcome
        jsr ui_main_loop
        ; ui_main_loop never returns (Q goes to welcome screen)
        ; To exit browser, user presses Reset on Atari

no_vbxe cli
        lda #$22
        sta SDMCTL
        ; Can't do much without VBXE, just cold start
        jmp (COLDSV)
.endp

; ----------------------------------------------------------------------------
; show_welcome
; ----------------------------------------------------------------------------
.proc show_welcome
        ; Title
        lda #TITLE_ROW
        ldx #0
        jsr vbxe_setpos
        lda #ATTR_H1
        jsr vbxe_setattr
        lda #<msg_welcome
        ldx #>msg_welcome
        jsr vbxe_print

        ; Subtitle
        lda #3
        ldx #0
        jsr vbxe_setpos
        lda #ATTR_NORMAL
        jsr vbxe_setattr
        lda #<msg_welcome2
        ldx #>msg_welcome2
        jsr vbxe_print

        ; Requirements
        lda #5
        ldx #0
        jsr vbxe_setpos
        lda #ATTR_DECOR
        jsr vbxe_setattr
        lda #<msg_req
        ldx #>msg_req
        jsr vbxe_print

        ; Controls
        lda #7
        ldx #0
        jsr vbxe_setpos
        lda #ATTR_H3
        jsr vbxe_setattr
        lda #<msg_keys_hdr
        ldx #>msg_keys_hdr
        jsr vbxe_print

        lda #8
        ldx #2
        jsr vbxe_setpos
        lda #ATTR_NORMAL
        jsr vbxe_setattr
        lda #<msg_keys1
        ldx #>msg_keys1
        jsr vbxe_print

        lda #9
        ldx #2
        jsr vbxe_setpos
        lda #<msg_keys2
        ldx #>msg_keys2
        jsr vbxe_print

        lda #10
        ldx #2
        jsr vbxe_setpos
        lda #<msg_keys3
        ldx #>msg_keys3
        jsr vbxe_print

        lda #11
        ldx #2
        jsr vbxe_setpos
        lda #<msg_keys4
        ldx #>msg_keys4
        jsr vbxe_print

        ; Prompt
        lda #13
        ldx #0
        jsr vbxe_setpos
        lda #ATTR_LINK
        jsr vbxe_setattr
        lda #<msg_press_u
        ldx #>msg_press_u
        jsr vbxe_print

        ; Author / credits
        lda #CONTENT_BOT
        ldx #0
        jsr vbxe_setpos
        lda #ATTR_DECOR
        jsr vbxe_setattr
        lda #<msg_author
        ldx #>msg_author
        jsr vbxe_print

        lda #ATTR_NORMAL
        jsr vbxe_setattr
        rts
.endp

; ============================================================================
; Include all modules
; ============================================================================
        icl 'vbxe_detect.asm'
        icl 'vbxe_init.asm'
        icl 'vbxe_text.asm'
        icl 'vbxe_gfx.asm'
        icl 'fujinet.asm'
        icl 'http.asm'
        icl 'url.asm'
        icl 'html_parser.asm'
        icl 'html_tags.asm'
        icl 'html_entities.asm'
        icl 'renderer.asm'
        icl 'keyboard.asm'
        icl 'ui.asm'
        icl 'img_fetch.asm'
        icl 'history.asm'
        icl 'mouse.asm'
        icl 'data.asm'

; ============================================================================
; Run address
; ============================================================================
        run main
