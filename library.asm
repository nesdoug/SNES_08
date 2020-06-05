;from easySNES
;Doug Fraker 2020

oam_buffer = OAM_BUFFER

.segment "CODE"

oam_spr:
.a8
.i16
; to put one sprite on screen
; copy all the sprite values to these 8 bit variables
; spr_x - x
; spr_y - y
; spr_c - tile #
; spr_a - attributes, flip, palette, priority
; spr_h - 0-3, optional, keep zero if not needed
;  bit 0 = X high bit (neg)
;  bit 1 = sprite size
	php
	sep #$20
	lda sprid ; 0-127
	lsr a
	lsr a
	sta temp1 ; 0-31
	lda sprid
	rep #$30
	and #$007f
	asl a
	asl a ; 0-511
	tay
	sep #$20
	lda spr_x
	sta a:oam_buffer, y
	lda spr_y
	sta a:oam_buffer+1, y
	lda spr_c
	sta a:oam_buffer+2, y
	lda spr_a
	sta a:oam_buffer+3, y
	
; handle the high table
; two bits, shift them in
; this is slow, so if this is zero, skip it, it was
; zeroed in oam_clear

	lda spr_h ; if zero, skip
	beq @end
	and #3 ; to be safe, we only need 2 bits
	sta spr_h
	
	lda #0
	xba ; clear that H byte, a is 8 bit
	lda temp1 ; sprid >> 2
	tay ; should be 0-31
	
	lda sprid
	and #3
	beq @zero
	cmp #1
	beq @one
	cmp #2
	beq @two
	bne @three
@zero:
	lda a:oam_buffer+$200, y
	and #$fc
	sta temp1
	lda spr_h
	ora temp1
	sta a:oam_buffer+$200, y
	bra @end
	
@one:
	lda a:oam_buffer+$200, y
	and #$f3
	sta temp1
	lda spr_h
	asl a
	asl a
	ora temp1
	sta oam_buffer+$200, y
	bra @end
	
@two:
	lda a:oam_buffer+$200, y
	and #$cf
	sta temp1
	lda spr_h
	asl a
	asl a
	asl a
	asl a
	ora temp1
	sta a:oam_buffer+$200, y	
	bra @end

@three:
	lda a:oam_buffer+$200, y
	and #$3f
	sta temp1
	lda spr_h
	lsr a ; 0000 0001 c
	ror a ; 1000 0000 c
	ror a ; 1100 0000 0
	ora temp1
	sta a:oam_buffer+$200, y	
	
@end:	
	lda sprid
	clc
	adc #1
	and #$7f ; keep it 0-127
	sta sprid
	plp
	rts



oam_clear:
.a8
.i16
; do at the start of each frame	
; clears the sprite buffer
; put all y at 224
	php
	sep #$20
	rep #$10
	stz sprid
	lda #224
	ldy #1
@loop:
; more efficient than a one lined sta
	sta a:oam_buffer, y
	sta a:oam_buffer+$40, y
	sta a:oam_buffer+$80, y
	sta a:oam_buffer+$c0, y
	sta a:oam_buffer+$100, y
	sta a:oam_buffer+$140, y
	sta a:oam_buffer+$180, y
	sta a:oam_buffer+$1c0, y
	iny
	iny
	iny
	iny
	cpy #$40 ; 41, but whatever
	bcc @loop
	
; clear the high table too
; then the oam_spr code can skip the 5th byte, if zero

	ldx #30
	rep #$20
@loop2:
	stz a:oam_buffer+$200, x
	dex
	dex
	bpl @loop2
	plp
	rts	





