	processor 6502

	ORG 4097
		
; 10 SYS4109
	byte	$0b,$10,$04,$00,$9e,$34,$31,$31,$30,0,0,0,0
	
; disable and acknowledge interrupts	
	lda #$7f
	sta $912e     
	sta $912d
	sta $911e 
; no interrupts for sho!
	sei
; no decimal mode!
	cld

SCREEN_CHR_RAM_1 EQU $1e00
SCREEN_CHR_RAM_2 EQU $1f00
SCREEN_COL_RAM_1 EQU $9600
SCREEN_COL_RAM_2 EQU $9700

RAM_BAS EQU $1000
BALL_X EQU $f9
BALL_Y EQU $fa
PLAYFIELD_WIDTH EQU $3c
PLAYFIELD_HEIGHT EQU $3d
KEYBOARD_VALUE EQU $3e
PLAYER_X_POS EQU $10
PLAYER_Y_POS EQU $11
; $0340..$0387 = 18 stars @ 4 bytes/star
PLAYFIELD_STAR_RAM   EQU $40
PLAYFIELD_STAR_XPOS  EQU $40
PLAYFIELD_STAR_SPEED EQU $41
PLAYFIELD_STAR_WAIT  EQU $42
PLAYFIELD_STAR_TWINK EQU $43
PLAYFIELD_STAR_COUNT EQU $88
PLAYFIELD_STAR_ROW   EQU $89
PLAYFIELD_STAR_NEW   EQU $8a

DRAW_THING_X_POS EQU $f0
DRAW_THING_Y_POS EQU $f1
DRAW_THING_COLOR EQU $f2
DRAW_THING_CHAR  EQU $f3
DRAW_THING_RAM   EQU $f4

CLOCK_SEED EQU $fb



PLAYFIELD_SETUP_BEGIN:
; supposedly 28x18 characters
; NTSC or PAL
	lda $9000
	clc
	cmp #5
	bne PLAYFIELD_PAL_SETUP
PLAYFIELD_NTSC_SETUP:
; set x position
	lda #1
	sta $9000
; set x width
	lda #153 ; actually 25
	sta $9002
	lda #25
	sta PLAYFIELD_WIDTH
; set y position
	lda #32
	sta $9001
; set y height
	lda #36
	sta $9003
	lda #18
	sta PLAYFIELD_HEIGHT
	jmp PLAYFIELD_SETUP_END
PLAYFIELD_PAL_SETUP:
; set x position
	lda #6
	sta $9000
; set x width
	lda #156 ; actually 28
	sta $9002
	lda #28
	sta PLAYFIELD_WIDTH
; set y position
	lda #46
	sta $9001
; set y height
	lda #36
	sta $9003
	lda #18
	sta PLAYFIELD_HEIGHT
PLAYFIELD_SETUP_END:
; set bg and border colors
	lda #8
	sta $900f


;init player
	lda #20
	sta PLAYER_X_POS
	lda #7
	sta PLAYER_Y_POS


;init starfield
	lda #255 ; value means star inactive
; clear star data
	ldx #0
clearing_star_data:
	sta PLAYFIELD_STAR_RAM,x
	inx
	clc
	cpx #$48 ; 72 bytes for 18 stars
	bne clearing_star_data


	jsr CLEAR_PLAYFIELD


GAME_LOOP:
	inc CLOCK_SEED
	jsr RASTER_ZERO
	;lda #93
	;sta $900f
	jsr STARFIELD_LAYER
	jsr PLANET_LAYER
	jsr KEYBOARD_SCANNER
	jsr CLEAR_PLAYER
	jsr INTERPRET_INPUT
	jsr DRAW_PLAYER
	;lda #8
	;sta $900f
	jmp GAME_LOOP


; check if zero point raster beam is hit
RASTER_ZERO:
	clc
	lda $9004
	cmp #01
	bne RASTER_ZERO
	rts



STARFIELD_LAYER:
; PLAYFIELD_STAR_XPOS  
; PLAYFIELD_STAR_SPEED 
; PLAYFIELD_STAR_WAIT  
; PLAYFIELD_STAR_TWINK
	ldx #0 ; star ram location
	ldy #0 ; star row
	stx PLAYFIELD_STAR_NEW
	sty PLAYFIELD_STAR_ROW
moving_star:
	lda PLAYFIELD_STAR_XPOS,x
	cmp #255
	bne moving_star_is_alive_star
; rebirth the star
	lda #0
	cmp PLAYFIELD_STAR_NEW
	bne moving_star_skip_movement
	lda #0
	sta PLAYFIELD_STAR_XPOS,x ; x position
	sta PLAYFIELD_STAR_WAIT,x ; travel counter
	lda CLOCK_SEED
	sta PLAYFIELD_STAR_TWINK,x ; twinklez
	and #3
	adc #1
	sta PLAYFIELD_STAR_SPEED,x ; travel speed
	lda #46 ; use . for stars
	; return early to create organic starfield
	rts
moving_star_is_alive_star:
	inc PLAYFIELD_STAR_WAIT,x
	lda PLAYFIELD_STAR_SPEED,x
	cmp PLAYFIELD_STAR_WAIT,x
	bne moving_star_skip_movement
; delete old star
	lda PLAYFIELD_STAR_XPOS,x
	sta DRAW_THING_X_POS
	ldy PLAYFIELD_STAR_ROW
	sty DRAW_THING_Y_POS
	lda #32 ; use ' ' to remove shit
	sta DRAW_THING_CHAR
	stx PLAYFIELD_STAR_COUNT
	jsr DRAW_THING_FUNCTION
	ldx PLAYFIELD_STAR_COUNT
; move star forward
	inc PLAYFIELD_STAR_XPOS,x
	lda #0
	sta PLAYFIELD_STAR_WAIT,x
	lda PLAYFIELD_WIDTH
	cmp PLAYFIELD_STAR_XPOS,x
	bne skipping_kill_star
	lda #255
	sta PLAYFIELD_STAR_XPOS,x
	jmp moving_star_skip_movement
skipping_kill_star:
; draw this fucker
	lda PLAYFIELD_STAR_XPOS,x
	sta DRAW_THING_X_POS
	lda #46 ; use . for stars
	sta DRAW_THING_CHAR
	lda PLAYFIELD_STAR_TWINK,x
	lsr
	and #7
	sta DRAW_THING_COLOR
	stx PLAYFIELD_STAR_COUNT
	jsr DRAW_THING_FUNCTION
	ldx PLAYFIELD_STAR_COUNT
	ldy PLAYFIELD_STAR_ROW
moving_star_skip_movement:
	inc PLAYFIELD_STAR_TWINK,x
	inc PLAYFIELD_STAR_ROW
	inx
	inx
	inx
	inx
	cpx #$48
	bne moving_star
	rts

	



CLEAR_PLAYFIELD:
; clear screen
	ldy #0
clearing_screen:
	lda #32
	sta SCREEN_CHR_RAM_1,y
	sta SCREEN_CHR_RAM_2,y
	;lda #1
	;sta SCREEN_COL_RAM_1,y
	;sta SCREEN_COL_RAM_2,y
	iny
	cpy #$00
; RUN
	bne clearing_screen
	rts



PLANET_LAYER:
; delete old planet
	lda BALL_X
	sta DRAW_THING_X_POS
	lda BALL_Y
	sta DRAW_THING_Y_POS
	lda #32 ; remove stuff with ' '
	sta DRAW_THING_COLOR
	jsr DRAW_THING_FUNCTION
; move planet
	inc BALL_X
	lda BALL_X
	cmp PLAYFIELD_WIDTH
	bne move_planet_no_reset
	lda #0
	sta BALL_X
	sta DRAW_THING_X_POS
	lda CLOCK_SEED
	and #15
	adc #1
	sta BALL_Y
move_planet_no_reset:
; draw planet
	lda BALL_X
	sta DRAW_THING_X_POS
	lda BALL_Y
	sta DRAW_THING_Y_POS
	lda #81 ; big dot character
	sta DRAW_THING_CHAR
	lda CLOCK_SEED
	and #7
	sta DRAW_THING_COLOR
	jsr DRAW_THING_FUNCTION
	rts



DRAW_THING_FUNCTION:
	ldy DRAW_THING_Y_POS
	lda #0
	sta DRAW_THING_RAM 
draw_thing_calc_y_loop:
	cpy #0
	beq draw_thing_done_calc_y
	clc
	adc PLAYFIELD_WIDTH
; set to draw on page 2
	bcs draw_thing_page2_calc_y_enter
	dey
	jmp draw_thing_calc_y_loop
draw_thing_done_calc_y:
	clc
	adc DRAW_THING_X_POS
	tay
; set to draw on page 2
	bcs draw_thing_page_2
draw_thing_page_1:
	lda DRAW_THING_CHAR
	sta SCREEN_CHR_RAM_1,y
	lda DRAW_THING_COLOR
	sta SCREEN_COL_RAM_1,y
	rts
draw_thing_page2_calc_y_loop:
	cpy #0
	beq draw_thing_page2_done_calc_y
	clc
	adc PLAYFIELD_WIDTH
draw_thing_page2_calc_y_enter:
	dey
	jmp draw_thing_page2_calc_y_loop
draw_thing_page2_done_calc_y:
	clc
	adc DRAW_THING_X_POS	
	tay
draw_thing_page_2:
	lda DRAW_THING_CHAR
	sta SCREEN_CHR_RAM_2,y
	lda DRAW_THING_COLOR
	sta SCREEN_COL_RAM_2,y
	rts


KEYBOARD_SCANNER:
; leaves bitwise game keys pressed in accumulator
; bit 7 - any key pressed
; bit 5 & 6 - no plans
; bit 4 - spacebar or fire
; bit 3 - w or up
; bit 2 - a or left
; bit 1 - s or down
; bit 0 - d or right
	lda #0
	sta $9120
	ldx $9121
	cpx #$ff
	bne keyboard_pressed
	sta KEYBOARD_VALUE
	rts
keyboard_pressed:
	ora #128
	tay
; check spacebar
	lda #$ef
	sta $9120
	lda $9121
	and #1
	cmp #1
	bne keyboard_spacebar_no
	tya
	ora #16
	tay
keyboard_spacebar_no:
; check w
	lda #$fd
	sta $9120
	lda $9121
	and #2
	cmp #2
	bne keyboard_w_no
	tya
	ora #8
	tay
keyboard_w_no:
; check a
	lda #$fb
	sta $9120
	lda $9121
	and #2
	cmp #2
	bne keyboard_a_no
	tya
	ora #4
	tay
keyboard_a_no:
; check s
	lda #$df
	sta $9120
	lda $9121
	and #2
	cmp #2
	bne keyboard_s_no
	tya
	ora #2
	tay
keyboard_s_no:
; check d
	lda #$fb
	sta $9120
	lda $9121
	and #4
	cmp #4
	bne keyboard_d_no
	tya
	ora #1
	tay
keyboard_d_no:
	tya
	sta KEYBOARD_VALUE
	rts


INTERPRET_INPUT:
; uses KEYBOARD_VALUE
	lda #1
	sta DRAW_THING_X_POS
	sta DRAW_THING_Y_POS
	sta DRAW_THING_COLOR
	; clean up key feedback area
	lda #32
	sta DRAW_THING_CHAR
	jsr DRAW_THING_FUNCTION ; x = 1
	inc DRAW_THING_X_POS
	inc DRAW_THING_X_POS
	jsr DRAW_THING_FUNCTION ; x = 3
	inc DRAW_THING_X_POS
	jsr DRAW_THING_FUNCTION ; x = 4
	inc DRAW_THING_X_POS
	jsr DRAW_THING_FUNCTION ; x = 5
	inc DRAW_THING_X_POS
	jsr DRAW_THING_FUNCTION ; x = 6
	inc DRAW_THING_X_POS
	inc DRAW_THING_X_POS
	jsr DRAW_THING_FUNCTION ; x = 8
	; check for any key
	lda KEYBOARD_VALUE
	and #128
	cmp #128
	beq interpret_any_key
	rts
interpret_any_key:
	lda #1
	STA DRAW_THING_X_POS
	lda #42
	sta DRAW_THING_CHAR
	jsr DRAW_THING_FUNCTION
;process w
	lda KEYBOARD_VALUE
	and #8
	cmp #8
	beq interpret_no_w
	lda #3
	sta DRAW_THING_X_POS
	lda #23
	sta DRAW_THING_CHAR
	jsr DRAW_THING_FUNCTION
	dec PLAYER_Y_POS
interpret_no_w:
	lda KEYBOARD_VALUE
	and #4
	cmp #4
	beq interpret_no_a
	lda #4
	sta DRAW_THING_X_POS
	lda #1
	sta DRAW_THING_CHAR
	jsr DRAW_THING_FUNCTION
	dec PLAYER_X_POS
interpret_no_a:
	lda KEYBOARD_VALUE
	and #2
	cmp #2
	beq interpret_no_s
	lda #5
	sta DRAW_THING_X_POS
	lda #19
	sta DRAW_THING_CHAR
	jsr DRAW_THING_FUNCTION
	inc PLAYER_Y_POS
interpret_no_s:
	lda KEYBOARD_VALUE
	and #1
	cmp #1
	beq interpret_no_d
	lda #6
	sta DRAW_THING_X_POS
	lda #4
	sta DRAW_THING_CHAR
	jsr DRAW_THING_FUNCTION
	inc PLAYER_X_POS
interpret_no_d:
	lda KEYBOARD_VALUE
	and #16
	cmp #16
	beq interpret_fire_no
	lda #8
	sta DRAW_THING_X_POS
	lda #83
	sta DRAW_THING_CHAR
	jsr DRAW_THING_FUNCTION
interpret_fire_no:
	rts
	
	

CLEAR_PLAYER:
; clear old position
	lda PLAYER_X_POS
	sta DRAW_THING_X_POS
	lda PLAYER_Y_POS
	sta DRAW_THING_Y_POS
	lda #32
	sta DRAW_THING_COLOR
	jmp DRAW_THING_FUNCTION


DRAW_PLAYER:
; make sure player is in screen range
; do the x
	lda PLAYER_X_POS
	clc
	cmp #250
	bcs player_reset_moving_left
	cmp PLAYFIELD_WIDTH
	bcs player_reset_moving_right
	jmp player_setup_x
player_reset_moving_left:
	lda PLAYFIELD_WIDTH
	sta PLAYER_X_POS
	jmp player_setup_x
player_reset_moving_right:
	lda #0
	sta PLAYER_X_POS
player_setup_x:
	sta DRAW_THING_X_POS
; do the y
	lda PLAYER_Y_POS
	clc
	cmp #250
	bcs player_reset_moving_up
	cmp PLAYFIELD_HEIGHT
	bcs player_reset_moving_down
	jmp player_setup_y
player_reset_moving_up:
	lda PLAYFIELD_HEIGHT
	sta PLAYER_Y_POS
	jmp player_setup_y
player_reset_moving_down:
	lda #0
	sta PLAYER_Y_POS
player_setup_y:
	lda PLAYER_Y_POS
	sta DRAW_THING_Y_POS
; draw this puppy
	lda #5
	sta DRAW_THING_COLOR
	lda #94
	sta DRAW_THING_CHAR
	jmp DRAW_THING_FUNCTION
