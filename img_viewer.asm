; VBXE Image Viewer
        opt h+
        org $3000

VBXE    = $80
TMP     = $82
TMP2    = $84
MSHD    = $86
RXLEN   = $88
IMGH    = $89
ERR     = $8A

VCTL    = $40
XDLA    = $41
CSEL    = $44
PSEL    = $45
CR      = $46
CG      = $47
CB      = $48
BADR    = $50
BLIT    = $53
MEMB    = $5D

VX_EN   = $01
VX_XC   = $02
FX_V    = $10

CHBAS   = $02F4
CH      = $02FC
SIOV    = $E459
SDMCTL  = $022F

DDEV    = $0300
DUNIT   = $0301
DCOM    = $0302
DSTA    = $0303
DBL     = $0304
DBH     = $0305
DBYL    = $0308
DBYH    = $0309
DVST    = $02EA

KN      = $FF
FN      = 1

start
        sei
        jsr detect
        bcc no_vbx
        jsr init
        cli
        jsr cls
        ldx #28
        ldy #10
        jsr setpos
        lda #3
        jsr sattr
        lda #<ttl
        ldx #>ttl
        jsr print
        jsr load
        lda ERR
        beq show_it
        jmp fail
show_it jsr show
        jsr wkey
        jsr rstxt
        rts

fail
        ldx #15
        ldy #12
        jsr setpos
        lda #5
        jsr sattr
        lda #<merr
        ldx #>merr
        jsr print
        jsr wkey
        rts

no_vbx
        cli
        lda #$09
        ldx #<mnvbx
        ldy #>mnvbx
        jmp $e456

detect
        lda #$60
        sta VBXE
        lda #$D6
        sta VBXE+1
        ldy #0
        lda #0
        sta (VBXE),y
        lda (VBXE),y
        cmp #FX_V
        beq ok_det
        lda #$70
        sta VBXE
        lda #$D7
        sta VBXE+1
        ldy #0
        lda #0
        sta (VBXE),y
        lda (VBXE),y
        cmp #FX_V
        beq ok_det
        clc
        rts

ok_det
        sec
        rts

init
        jsr m_on
        ldx #0

cfnt
        lda CHBAS
        sta TMP+1
        lda #0
        sta TMP
        lda #$60
        clc
        adc TMP2
        sta TMP2+1
        lda #0
        sta TMP2
        ldy #0

cfnt_l
        lda (TMP),y
        sta (TMP2),y
        iny
        bne cfnt_l
        inc TMP2
        inx
        cpx #4
        bne cfnt

        ldx #0

cxdl
        lda xdl_d,x
        sta $5400,x
        inx
        cpx #28
        bne cxdl

        ldx #0

cbcb
        lda bcb_d,x
        sta $5300,x
        inx
        cpx #21
        bne cbcb

        lda #' '
        sta $5380
        lda #0
        sta $5381
        jsr m_off
        jsr spal
        ldy #XDLA
        lda #$40
        sta (VBXE),y
        iny
        lda #$54
        sta (VBXE),y
        ldy #VCTL
        lda #VX_EN|VX_XC
        sta (VBXE),y
        lda #0
        sta SDMCTL
        rts

spal
        ldy #PSEL
        lda #1
        sta (VBXE),y
        ldy #CSEL
        lda #0
        sta (VBXE),y
        ldx #0

spal_l
        ldy #CR
        lda pr,x
        sta (VBXE),y
        iny
        lda pg,x
        sta (VBXE),y
        iny
        lda pb,x
        sta (VBXE),y
        ldy #CSEL
        inx
        cpx #8
        bne spal_l
        rts

pr      dta $00,$FF,$00,$FF,$00,$FF,$88,$FF
pg      dta $00,$FF,$AA,$AA,$FF,$44,$88,$FF
pb      dta $00,$FF,$FF,$00,$00,$44,$88,$00

m_on
        lda #$80
        sta MSHD
        ldy #MEMB
        lda #$80
        sta (VBXE),y
        rts

m_off
        lda #0
        sta MSHD
        ldy #MEMB
        lda #0
        sta (VBXE),y
        rts

cls
        jsr m_on
        lda #' '
        sta $5380
        lda #0
        sta $5381
        jsr m_off
        ldy #BADR
        lda #$00
        sta (VBXE),y
        iny
        lda #$13
        sta (VBXE),y
        iny
        lda #0
        sta (VBXE),y
        iny
        lda #1
        sta (VBXE),y
        ldy #BLIT

wcls
        lda (VBXE),y
        bne wcls
        lda #0
        sta TMP
        sta TMP+1
        rts

setpos
        sta TMP
        stx TMP+1
        lda #>$4000
        sta TMP2+1
        lda TMP
        asl
        clc
        adc #<$4000
        sta TMP2
        bcc spok
        inc TMP2+1

spok
        rts

sattr
        sta MSHD+1
        rts

putchar
        pha
        jsr m_on
        pla
        ldy #0
        sta (TMP2),y
        iny
        lda MSHD+1
        sta (TMP2),y
        jsr m_off
        lda TMP2
        clc
        adc #2
        sta TMP2
        bcc pcnc
        inc TMP2+1

pcnc
        inc TMP+1
        lda TMP+1
        cmp #80
        bcc pcdn
        lda #0
        sta TMP+1
        inc TMP
        lda TMP
        cmp #29
        bcc pcdn
        dec TMP
        jsr scrl

pcdn
        rts

scrl
        ldy #BADR
        lda #$15
        sta (VBXE),y
        iny
        lda #$13
        sta (VBXE),y
        iny
        lda #0
        sta (VBXE),y
        iny
        lda #1
        sta (VBXE),y
        ldy #BLIT

wscr
        lda (VBXE),y
        bne wscr
        rts

print
        sta TMP2
        stx TMP2+1
        ldy #0

prt
        lda (TMP2),y
        beq prtdn
        jsr putchar
        iny
        bne prt

prtdn
        rts

load
        lda #0
        sta ERR
        lda #FN
        sta DDEV
        sta DUNIT
        lda #<fname
        sta DBL
        lda #>fname
        sta DBH
        lda #$04
        sta DCOM
        lda #0
        sta DSTA
        jsr SIOV
        bmi e1
        lda #3
        sta DBYL
        lda #0
        sta DBYH
        lda #<hdr
        sta DBL
        lda #>hdr
        sta DBH
        lda #$52
        sta DCOM
        jsr SIOV
        bmi e2
        lda hdr+1
        cmp #2
        bcs e3
        lda hdr
        cmp #8
        bcc e3
        lda hdr+2
        cmp #8
        bcc e3
        lda hdr+2
        sta IMGH
        lda #$00
        sta TMP2
        lda #$30
        sta TMP2+1
        lda #<pal
        sta DBL
        lda #>pal
        sta DBH
        ldx #3
        stx RXLEN

rpal
        lda #255
        sta DBYL
        lda #1
        sta DBYH
        lda #$52
        sta DCOM
        jsr SIOV
        bmi e2
        lda DBL
        clc
        adc #255
        sta DBL
        bcc rpaln
        inc DBH

rpaln
        dec RXLEN
        bne rpal
        lda #<pal+3
        sta DBL
        lda #>pal+3
        sta DBH
        lda #3
        sta DBYL
        lda #0
        sta DBYH
        lda #$52
        sta DCOM
        jsr SIOV
        lda #<rx
        sta DBL
        lda #>rx
        sta DBH

rpix
        lda #255
        sta DBYL
        lda #0
        sta DBYH
        lda #$52
        sta DCOM
        jsr SIOV
        bmi pixdn
        lda DVST+1
        beq pixdn
        sta RXLEN
        jsr wpix
        jmp rpix

pixdn
        lda #$0c
        sta DCOM
        jsr SIOV
        rts

e1
        lda #1
        sta ERR
        rts

e2
        lda #2
        sta ERR
        jmp clf

e3
        lda #3
        sta ERR

clf
        lda #$0c
        sta DCOM
        jmp SIOV

wpix
        lda RXLEN
        beq wpdn
        sei
        lda #$80
        sta MSHD
        ldy #MEMB
        lda #$80
        sta (VBXE),y
        ldx #0

wpl
        ldy #0
        lda rx,x
        sta (TMP2),y
        inc TMP2
        bne wpnc
        inc TMP2+1
        lda TMP2+1
        cmp #$80
        bne wpnc
        lda #$40
        sta TMP2+1
        inc MSHD
        lda MSHD
        ora #$80
        ldy #MEMB
        sta (VBXE),y

wpnc
        inx
        cpx RXLEN
        bne wpl
        jsr m_off
        cli

wpdn
        rts

show
        jsr ipal
        jsr ixdl
        rts

ipal
        ldy #PSEL
        lda #1
        sta (VBXE),y
        ldy #CSEL
        lda #8
        sta (VBXE),y
        lda #<pal+24
        sta TMP2
        lda #>pal+24
        sta TMP2+1
        ldx #8

ipal_l
        ldy #0
        lda (TMP2),y
        ldy #CR
        sta (VBXE),y
        ldy #1
        lda (TMP2),y
        ldy #CG
        sta (VBXE),y
        ldy #2
        lda (TMP2),y
        ldy #CB
        sta (VBXE),y
        clc
        lda TMP2
        adc #3
        sta TMP2
        bcc ipaln
        inc TMP2+1

ipaln
        inx
        bne ipal_l
        rts

ixdl
        jsr m_on
        ldx #0

        lda #<(4|$0010|$0020|$0040|$0100|$0800)
        sta $5400,x
        inx
        lda #>(4|$0010|$0020|$0040|$0100|$0800)
        sta $5400,x
        inx
        lda #24-1
        sta $5400,x
        inx
        lda #<0
        sta $5400,x
        inx
        lda #>0
        sta $5400,x
        inx
        lda #0
        sta $5400,x
        inx
        lda #<160
        sta $5400,x
        inx
        lda #>160
        sta $5400,x
        inx
        lda #4
        sta $5400,x
        inx
        lda #%00010001
        sta $5400,x
        inx
        lda #$FF
        sta $5400,x
        inx

        lda #<(2|$0010|$0020|$0040|$0800)
        sta $5400,x
        inx
        lda #>(2|$0010|$0020|$0040|$0800)
        sta $5400,x
        inx
        lda IMGH
        sec
        sbc #1
        sta $5400,x
        inx
        lda #<0
        sta $5400,x
        inx
        lda #>$3000
        sta $5400,x
        inx
        lda #0
        sta $5400,x
        inx
        lda #<320
        sta $5400,x
        inx
        lda #>320
        sta $5400,x
        inx
        lda #%00010001
        sta $5400,x
        inx
        lda #$FF
        sta $5400,x
        inx

        lda #<(1|$0010|$0020|$0040|$0100|$0800|$8000)
        sta $5400,x
        inx
        lda #>(1|$0010|$0020|$0040|$0100|$0800|$8000)
        sta $5400,x
        inx
        lda #8-1
        sta $5400,x
        inx
        lda #<$2D00
        sta $5400,x
        inx
        lda #>$2D00
        sta $5400,x
        inx
        lda #0
        sta $5400,x
        inx
        lda #<160
        sta $5400,x
        inx
        lda #>160
        sta $5400,x
        inx
        lda #4
        sta $5400,x
        inx
        lda #%00010001
        sta $5400,x
        inx
        lda #$FF
        sta $5400,x

        jsr m_off
        rts

rstxt
        lda $12+2

wvb
        cmp $12+2
        beq wvb
        jsr m_on
        ldx #0

rxdl
        lda xdl_d,x
        sta $5400,x
        inx
        cpx #28
        bne rxdl
        jsr m_off
        jsr spal
        rts

wkey
        lda #KN
        sta CH

wk1
        lda CH
        cmp #KN
        beq wk1
        lda #KN
        sta CH
        rts

hdr
        dta b(0),b(0),b(0)

rx
        .ds 256

pal
        .ds 768

fname
        dta c'D1:IMAGE.VBXE',0

ttl
        dta c'VBXE Image Viewer',0

merr
        dta c'Error loading image!',0

mnvbx
        dta c'VBXE not detected!',0

xdl_d
        dta a($0004),8-1
        dta <0,>0,0
        dta a(160),4,%00010001,$FF
        dta a($0001),29*8-1
        dta <0,>0,0
        dta a(160)

bcb_d
        dta <$1380,>$1380,0,1
        dta <0,>0,0
        dta a(160),a(160-1),29-1,$FF,0,0,0,$81,0

        run start
