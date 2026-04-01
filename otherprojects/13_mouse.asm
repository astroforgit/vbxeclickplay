



dli_check_mouse

	lda #0
	sta dx_change
	sta dy_change

	lda $d300
	cmp old_mouse
	bne Moved
;	jmp EXITDLI
	rts

Moved
	sta old_mouse
	and #$f0
	lsr ; not really worth using a LUT for this
	lsr
	lsr
	lsr
	pha

	and #3 ; ST mouse only
	
	ora oldx
	tax
	lda mousetab3,x
	sta oldx

;	lda x_change
;	clc
;	adc mousetab,x
;	sta x_change
	lda mousetab,X
	sta dx_change
	pla

	tax
	lda mousetab2,x

	ora oldy
	tax
	lda mousetab3,x
	sta oldy

;	lda y_change
;	clc
;	adc mousetab,x
;	sta y_change

	lda mousetab,x
	sta dy_change


;final
	lda kontrola_tryb
	and #%00000011
	beq dpoin



	rts
dpoin
	lda dy_change
	clc
	adc y_change
	sta y_change
	lda dx_change
	clc
	adc x_change
	sta x_change

	rts

; ST mouse index table
	
mousetab ; 0 = no movement, 255 = -1, 1 = +1
	.byte 0,255,1,0,1,0,0,255,255,0,0,1,0,1,255,0

mousetab2
	.byte 0,0,0,0,1,1,1,1
	.byte 2,2,2,2,3,3,3,3
	
mousetab3
	.byte 0,4,8,12
	.byte 0,4,8,12
	.byte 0,4,8,12
	.byte 0,4,8,12






