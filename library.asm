;from easySNES
;Doug Fraker 2020

oam_buffer = OAM_BUFFER

.segment "CODE"

oam_spr:
.a8
.i16
; to put one sprite on screen
; copy all the sprite values to these 8 bit variables
; spr_x - x (9 bit)
; spr_y - y
; spr_c - tile #
; spr_a - attributes, flip, palette, priority
; spr_sz = sprite size, 0 or 2

	php
	rep #$30 ;axy16
	lda sprid
	and #$007f
	tax
	asl a
	asl a ; 0-511
	tay
	
	txa
	sep #$20 ;a8
	lsr a
	lsr a ; 0-31
	tax
	lda spr_x ;x low byte
	sta a:oam_buffer, y
	lda spr_y ;y
	sta a:oam_buffer+1, y
	lda spr_c ;tile
	sta a:oam_buffer+2, y
	lda spr_a ;attribute
	sta a:oam_buffer+3, y
	
; handle the high table
; two bits, shift them in
; this is slow, so if this is zero, skip it, it was
; zeroed in oam_clear

	lda spr_x+1 ;9th x bit
	and #1 ;we only need 1 bit
	ora spr_sz ;size
	beq @end
	sta spr_h
	
	lda sprid
	and #3
	beq @zero
	dec a
	beq @one
	dec a
	beq @two
	bne @three
	
@zero:
	lda spr_h
	sta a:oam_buffer+$200, x
	bra @end
	
@one:
	lda spr_h
	asl a
	asl a
	ora a:oam_buffer+$200, x
	sta a:oam_buffer+$200, x
	bra @end
	
@two:
	lda spr_h
	asl a
	asl a
	asl a
	asl a
	ora a:oam_buffer+$200, x
	sta a:oam_buffer+$200, x
	bra @end

@three:
	lda spr_h
	lsr a ; 0000 0001 c
	ror a ; 1000 0000 c
	ror a ; 1100 0000 0
	ora a:oam_buffer+$200, x
	sta a:oam_buffer+$200, x	
	
@end:	
	lda sprid
	inc a
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





