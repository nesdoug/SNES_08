; example 8 SNES code

.p816
.smart


.segment "ZEROPAGE"

temp1: .res 2
temp2: .res 2
temp3: .res 2
temp4: .res 2
sprid: .res 1
spr_x: .res 1 ; for sprite setting code
spr_y: .res 1
spr_c: .res 1
spr_a: .res 1
spr_h: .res 1 ; high 2 bits
spr_x2:	.res 2 ; for meta sprite code
spr_y2: .res 1
spr_h2:	.res 1
spr_pri: .res 1 ; priority

pad1: .res 2
pad1_new: .res 2
pad2: .res 2
pad2_new: .res 2
in_nmi: .res 2

bg1_x: .res 1
bg1_y: .res 1
bg2_x: .res 1
bg2_y: .res 1
bg3_x: .res 1
bg3_y: .res 1
map_selected: .res 1


.segment "BSS"

OAM_BUFFER: .res 512 ;low table
OAM_BUFFER2: .res 32 ;high table


.include "defines.asm"
.include "macros.asm"
.include "init.asm"
.include "library.asm"




.segment "CODE"

; enters here in forced blank
main:
.a16 ; just a standardized setting from init code
.i16
	phk
	plb
	

	
; DMA from BG_Palette to CGRAM
	A8
	stz $2121 ; $2121 cg address = zero
	
	stz $4300 ; transfer mode 0 = 1 register write once
	lda #$22  ; $2122
	sta $4301 ; destination, pal data
	ldx #.loword(BG_Palette)
	stx $4302 ; source
	lda #^BG_Palette
	sta $4304 ; bank
	ldx #512
	stx $4305 ; length
	lda #1
	sta $420b ; start dma, channel 0
	
	
; DMA from Tiles to VRAM	
	lda #V_INC_1 ; the value $80
	sta vram_inc  ; $2115 = set the increment mode +1

	DMA_VRAM  (End_Tiles-Tiles), Tiles, $0000

; DMA from Tiles2 to VRAM	
	DMA_VRAM  (End_Tiles2-Tiles2), Tiles2, $3000
	
; DMA from SpTiles to VRAM
	DMA_VRAM  (End_SpTiles-SpTiles), SpTiles, $4000
	
; DMA from Tilemap to VRAM	
	DMA_VRAM  $700, Tilemap, $6000

; DMA from Tilemap2 to VRAM	
	DMA_VRAM  $700, Tilemap2, $6800

; DMA from Tilemap3 to VRAM	
	DMA_VRAM  $700, Tilemap3, $7000
	
	
	
; a is still 8 bit.
	lda #1|BG3_TOP ; mode 1, tilesize 8x8 all, layer 3 on top
	sta bg_size_mode ; $2105
	
; 210b = tilesets for bg 1 and bg 2
; (210c for bg 3 and bg 4)
; steps of $1000 -321-321... bg2 bg1
	stz bg12_tiles ; $210b BG 1 and 2 TILES at VRAM address $0000
	lda #$03
	sta bg34_tiles ; $210c BG3 TILES at VRAM address $3000
	
	; 2107 map address bg 1, steps of $400... -54321yx
	; y/x = map size... 0,0 = 32x32 tiles
	; $6000 / $100 = $60
	lda #$60 ; bg1 map at VRAM address $6000
	sta tilemap1 ; $2107
	
	lda #$68 ; bg1 map at VRAM address $6800
	sta tilemap2 ; $2108
	
	lda #$70 ; bg3 map at VRAM address $7000
	sta tilemap3 ; $2109
	
	lda #2 ;sprite tiles at $4000
	sta spr_addr_size ;= $2101

	;allow everything on the main screen	
	lda #ALL_ON_SCREEN ; $1f
	sta main_screen ; $212c
	
	;turn on NMI interrupts and auto-controller reads
	lda #NMI_ON|AUTO_JOY_ON
	sta $4200
	
	jsr oam_clear
	
	lda #FULL_BRIGHT ; $0f = turn the screen on, full brighness
	sta fb_bright ; $2100


InfiniteLoop:	
	A8
	jsr wait_nmi ;wait for the beginning of v-blank
	jsr dma_oam  ;copy the OAM_BUFFER to the OAM
	jsr set_scroll
	jsr pad_poll ;read controllers
	jsr oam_clear

	AXY16
	
	lda pad1
	and #KEY_UP
	beq @not_up

	jsr Up_Handler
	
@not_up:

	lda pad1
	and #KEY_DOWN
	beq @not_down

	jsr Down_Handler
	
@not_down:

	lda pad1
	and #KEY_RIGHT
	beq @not_right

	jsr Right_Handler
	
@not_right:

	lda pad1
	and #KEY_LEFT
	beq @not_left

	jsr Left_Handler
	
@not_left:

	lda pad1_new ;!!
	and #(KEY_A|KEY_B|KEY_X|KEY_Y) ;any of a,b,x,y buttons
	beq @not_button

	jsr Button_Handler
	
@not_button:


	jsr Draw_sprites
	jmp InfiniteLoop
	
	
	
	
	
Draw_sprites:
	php
	A8
	
; spr_x - x
; spr_y - y
; spr_c - tile #
; spr_a - attributes, flip, palette, priority
; spr_h - sprite size and 9th X bit
	lda #10
	sta spr_x
	sta spr_y 
	lda map_selected
	asl a ;0,2,4
	sta spr_c
	lda #SPR_PAL_0|SPR_PRIOR_2
	sta spr_a
	lda #SPR_SIZE_LG
	sta spr_h ;16x16 
	jsr oam_spr
	plp
	rts
	
Button_Handler:
.a16
.i16
;A,B,X, or Y button pressed
;change the selected BG map
	php
	A8
	lda map_selected
	inc a
	cmp #3 ; keep it 0-2
	bcc @ok
	lda #0
@ok:
	sta map_selected
	plp
	rts
	
	
;all these examples below work like a 
;switch/case on map_selected
	
Left_Handler:
.a16
.i16
	php
	A8
	lda map_selected
	;lda sets the z flag, if map_selected == 0,
	;so we don't need to cmp #0
	bne @1or2
@0: ;BG1 (map_selected == 0)
	inc bg1_x
	bra @end
@1or2:
	cmp #1 
	bne @2
@1: ;BG2 (map_selected == 1)
	inc bg2_x
	bra @end
@2: ;BG3 (map_selected == 2)
	inc bg3_x
@end:	
	plp
	rts
	

Right_Handler:
.a16
.i16
	php
	A8
	lda map_selected
	bne @1or2
@0: ;BG1
	dec bg1_x
	bra @end
@1or2:
	cmp #1
	bne @2
@1: ;BG2
	dec bg2_x
	bra @end
@2: ;BG3
	dec bg3_x
@end:	
	plp
	rts
	

Down_Handler:
.a16
.i16
	php
	A8
	lda map_selected
	bne @1or2
@0: ;BG1
	dec bg1_y
	bra @end
@1or2:
	cmp #1
	bne @2
@1: ;BG2
	dec bg2_y
	bra @end
@2: ;BG3
	dec bg3_y
@end:	
	plp
	rts
	

Up_Handler:
.a16
.i16
	php
	A8
	lda map_selected
	bne @1or2
@0: ;BG1
	inc bg1_y
	bra @end
@1or2:
	cmp #1
	bne @2
@1: ;BG2
	inc bg2_y
	bra @end
@2: ;BG3
	inc bg3_y
@end:	
	plp
	rts
	
	
	
	
set_scroll:
.a8
.i16
	php
	A8
;scroll registers are write twice, low byte then high byte	
;the high bytes are always 0 in this demo	
;because our map is 256x256 always (32x32 map and 8x8 tiles)
	lda bg1_x
	sta bg1_scroll_x ;$210d 
	stz bg1_scroll_x
	lda bg1_y
	sta bg1_scroll_y ;$210e
	stz bg1_scroll_y
	
	lda bg2_x
	sta bg2_scroll_x ;$210f
	stz bg2_scroll_x
	lda bg2_y
	sta bg2_scroll_y ;$2110
	stz bg2_scroll_y
	
	lda bg3_x
	sta bg3_scroll_x ;$2111
	stz bg3_scroll_x
	lda bg3_y
	sta bg3_scroll_y ;$2112
	stz bg3_scroll_y
	plp
	rts


wait_nmi:
.a8
.i16
;should work fine regardless of size of A
	lda in_nmi ;load A register with previous in_nmi
@check_again:	
	WAI ;wait for an interrupt
	cmp in_nmi	;compare A to current in_nmi
				;wait for it to change
				;make sure it was an nmi interrupt
	beq @check_again
	rts
	
	
dma_oam:
.a8
.i16
	php
	A8
	XY16
	ldx #$0000
	stx oam_addr_L ;$2102 (and 2103)
	
	stz $4300 ; transfer mode 0 = 1 register write once
	lda #4 ;$2104 oam data
	sta $4301 ; destination, oam data
	ldx #.loword(OAM_BUFFER)
	stx $4302 ; source
	lda #^OAM_BUFFER
	sta $4304 ; bank
	ldx #544
	stx $4305 ; length
	lda #1
	sta $420b ; start dma, channel 0
	plp
	rts

	
pad_poll:
.a8
.i16
; reads both controllers to pad1, pad1_new, pad2, pad2_new
; auto controller reads done, call this once per main loop
; copies the current controller reads to these variables
; pad1, pad1_new, pad2, pad2_new (all 16 bit)
	php
	A8
@wait:
; wait till auto-controller reads are done
	lda $4212
	lsr a
	bcs @wait
	
	A16
	lda pad1
	sta temp1 ; save last frame
	lda $4218 ; controller 1
	sta pad1
	eor temp1
	and pad1
	sta pad1_new
	
	lda pad2
	sta temp1 ; save last frame
	lda $421a ; controller 2
	sta pad2
	eor temp1
	and pad2
	sta pad2_new
	plp
	rts

	

.include "header.asm"	


.segment "RODATA1"

BG_Palette:
; 256 bytes
.incbin "ImageConverter/allBG.pal"
.incbin "Sprites/Sprites.pal"

Tiles:
; 4bpp tileset
.incbin "ImageConverter/moon.chr"
End_Tiles:

Tiles2:
; 2bpp tileset
.incbin "ImageConverter/spacebar.chr"
End_Tiles2:

Tilemap:
; $700 bytes
.incbin "ImageConverter/moon3.map"

Tilemap2:
; $700 bytes
.incbin "ImageConverter/bluebar.map"

Tilemap3:
; $700 bytes
.incbin "ImageConverter/spacebar2.map"

SpTiles: ;768 bytes
.incbin "Sprites/Numbers.chr"
End_SpTiles:
