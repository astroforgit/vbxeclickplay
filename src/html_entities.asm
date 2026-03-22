; ============================================================================
; HTML Entity Decoding & Tag Lookup Tables
; ============================================================================

; ============================================================================
; lookup_tag - Find tag ID from tag_name_buf
; Output: A = tag ID
; ============================================================================
NUM_TAGS = 34

.proc lookup_tag
        ldx #0
?next   lda tag_tbl_lo,x
        sta zp_tmp_ptr
        lda tag_tbl_hi,x
        sta zp_tmp_ptr+1

        ldy #0
?cmp    lda (zp_tmp_ptr),y
        beq ?chk
        cmp tag_name_buf,y
        bne ?skip
        iny
        bne ?cmp

?chk    lda tag_name_buf,y
        beq ?found
?skip   inx
        cpx #NUM_TAGS
        bne ?next
        lda #TAG_UNKNOWN
        rts
?found  lda tag_ids,x
        rts
.endp

ts_h1     dta c'h1',0
ts_h2     dta c'h2',0
ts_h3     dta c'h3',0
ts_p      dta c'p',0
ts_br     dta c'br',0
ts_a      dta c'a',0
ts_ul     dta c'ul',0
ts_ol     dta c'ol',0
ts_li     dta c'li',0
ts_b      dta c'b',0
ts_strong dta c'strong',0
ts_i      dta c'i',0
ts_em     dta c'em',0
ts_title  dta c'title',0
ts_script dta c'script',0
ts_style  dta c'style',0
ts_img    dta c'img',0
ts_input  dta c'input',0
ts_form   dta c'form',0
ts_div    dta c'div',0
ts_span   dta c'span',0
ts_pre    dta c'pre',0
ts_hr     dta c'hr',0
ts_noscript dta c'noscript',0
ts_table  dta c'table',0
ts_tr     dta c'tr',0
ts_td     dta c'td',0
ts_th     dta c'th',0
ts_blockquote dta c'blockquote',0
ts_dt     dta c'dt',0
ts_dd     dta c'dd',0
ts_code   dta c'code',0
ts_head   dta c'head',0
ts_body   dta c'body',0

tag_tbl_lo
        dta <ts_h1, <ts_h2, <ts_h3, <ts_p
        dta <ts_br, <ts_a, <ts_ul, <ts_ol
        dta <ts_li, <ts_b, <ts_strong, <ts_i
        dta <ts_em, <ts_title, <ts_script, <ts_style
        dta <ts_img, <ts_input, <ts_form, <ts_div
        dta <ts_span, <ts_pre, <ts_hr, <ts_noscript
        dta <ts_table, <ts_tr, <ts_td, <ts_th
        dta <ts_blockquote, <ts_dt, <ts_dd, <ts_code
        dta <ts_head, <ts_body

tag_tbl_hi
        dta >ts_h1, >ts_h2, >ts_h3, >ts_p
        dta >ts_br, >ts_a, >ts_ul, >ts_ol
        dta >ts_li, >ts_b, >ts_strong, >ts_i
        dta >ts_em, >ts_title, >ts_script, >ts_style
        dta >ts_img, >ts_input, >ts_form, >ts_div
        dta >ts_span, >ts_pre, >ts_hr, >ts_noscript
        dta >ts_table, >ts_tr, >ts_td, >ts_th
        dta >ts_blockquote, >ts_dt, >ts_dd, >ts_code
        dta >ts_head, >ts_body

tag_ids dta TAG_H1, TAG_H2, TAG_H3, TAG_P
        dta TAG_BR, TAG_A, TAG_UL, TAG_OL
        dta TAG_LI, TAG_B, TAG_STRONG, TAG_I
        dta TAG_EM, TAG_TITLE, TAG_SCRIPT, TAG_STYLE
        dta TAG_IMG, TAG_INPUT, TAG_FORM, TAG_DIV
        dta TAG_SPAN, TAG_PRE, TAG_HR, TAG_NOSCRIPT
        dta TAG_TABLE, TAG_TR, TAG_TD, TAG_TH
        dta TAG_BLOCKQUOTE, TAG_DT, TAG_DD, TAG_CODE
        dta TAG_HEAD, TAG_BODY

; ============================================================================
; Entity decoding
; ============================================================================
.proc decode_entity
        lda entity_buf
        cmp #'a'
        beq ?amp
        cmp #'l'
        beq ?lt
        cmp #'g'
        beq ?gt
        cmp #'n'
        beq ?nbsp
        cmp #'q'
        beq ?quot
        cmp #'#'
        beq ?num
        lda #'?'
        rts

?amp    lda entity_buf+1
        cmp #'m'
        bne ?unk
        lda #'&'
        rts
?lt     lda entity_buf+1
        cmp #'t'
        bne ?unk
        lda #'<'
        rts
?gt     lda entity_buf+1
        cmp #'t'
        bne ?unk
        lda #'>'
        rts
?nbsp   lda entity_buf+1
        cmp #'b'
        bne ?unk
        lda #CH_SPACE
        rts
?quot   lda entity_buf+1
        cmp #'u'
        bne ?unk
        lda #'"'
        rts
?unk    lda #'?'
        rts

?num    lda #0
        sta zp_tmp1
        ldx #1
?nlp    lda entity_buf,x
        beq ?nd
        sec
        sbc #'0'
        bcc ?unk
        cmp #10
        bcs ?unk
        pha
        lda zp_tmp1
        asl
        asl
        clc
        adc zp_tmp1
        asl
        sta zp_tmp1
        pla
        clc
        adc zp_tmp1
        sta zp_tmp1
        inx
        cpx #4
        bne ?nlp
?nd     lda zp_tmp1
        rts
.endp

.proc emit_entity_buf
        ldx #0
?lp     cpx zp_entity_idx
        beq ?done
        lda entity_buf,x
        stx zp_tmp2
        jsr html_emit_char
        ldx zp_tmp2
        inx
        bne ?lp
?done   rts
.endp
