;
; mapcreation.asm
;
; Created: 2020-03-02 02:22:47
; Author : Ludde
;


; Replace with your application code
	.equ POINTS = 10
	.equ STEPSIZE = 2
	.equ ORIGO = 63

.dseg
.org SRAM_START
Y_VAL: .byte POINTS
Y_CORD:	.byte 1
X_CORD:	.byte 1
SEED: .byte 1

.cseg
.org 0
jmp COLD	
;.org OVF0addr interrupt address
;jmp GEN_SEED
COLD: 
	ldi r16,HIGH(RAMEND)
	out SPH,r16
	ldi r16,LOW(RAMEND)
	out SPL,r16
	call HW_INIT
WARM:
	call MAP_CREATION
	rjmp WARM

MAP_CREATION:
	push r16
	push r17
	push r18
	push ZH
	push ZL
	ldi r16,POINTS ;antal loops
	ldi ZH,HIGH(Y_CORD)
	ldi ZL,LOW(Y_CORD)
MAP_1:
	ldi r17,STEPSIZE
	ldi r18,ORIGO
	cpi r16,POINTS
	breq MAP_2
RANDOM:
	;call DELAY
	in r18,TCNT0
	andi r18,$7F
	cpi r18,$7E
	brpl R_ADJUST
	rjmp MAP_2
R_ADJUST:
	subi r18,$01
MAP_2:
	;set Y_CORD VALUES WITH RANDOM
	st Z+,r18
	dec r16
	dec r17
	brne MAP_2
	cpi r16,$00
	brne MAP_1
	pop ZL
	pop ZH
	pop r18
	pop r17
	pop r16
	ret

DELAY: ;RANDOM DELAY
	push r16
	push r17
	in r16,TCNT0
	andi r16,$07
DELAY1:
	ldi r17, $55
DELAY2:
	dec r17
	brne DELAY2
	dec r16
	brne DELAY1
	pop r17
	pop r16
	ret

HW_INIT:
	ldi r16,(1<<CS00) ;Timer0
	out TCCR0,r16
	;ldi r16,(1<<TOIE0)|(1<<OCIE1A)
	;out TIMSK,r16
	;sei interrupt code
	ret