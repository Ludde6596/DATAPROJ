;
; POINTTEST.asm
;
; Created: 2020-03-08 17:12:54
; Author : Ludde
;


; Replace with your application code
.equ MAPSIZE = 50
.equ STEPSIZE = 5
.equ ORIGO = 15	;63 riktiga värdet

.dseg
.org $0100
Y_VAL: .byte MAPSIZE
Y_CORD:	.byte 1
X_CORD:	.byte 1
POINTS: .byte 1
.macro INCSRAM ; inc byte in SRAM
	lds r16,@0
	inc r16
	sts @0,r16
.endmacro

.macro DECSRAM ; dec byte in SRAM
	lds r16,@0
	dec r16
	sts @0,r16
.endmacro
	
;--------------------------------
;------------- KOD --------------

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
	call PEN_UP
	sbis PINB,2
	rjmp WARM
	call MAP_CREATION
	call PEN_DOWN
	call PLOT_MAP
	call PEN_UP
	call RESET_MAP
GAME_START:
	call PEN_DOWN
	call PLAY_GAME
	call PEN_UP
	call RESET_MAP
POINT_TESTING:
	lds r16,POINTS
	out PORTD,r16
FINISH:
	rjmp FINISH

MAP_CREATION:
	push r16
	push r17
	push r18
	push r20
	push YH
	push YL
	
	ldi r16,MAPSIZE ;antal loops
	ldi YH,HIGH(Y_VAL)
	ldi YL,LOW(Y_VAL)
	ldi r18,1
MAP_1:
	ldi r17,STEPSIZE
	cpi r16,MAPSIZE
	brne RANDOM
	ldi r18,ORIGO
	breq MAP_2
RANDOM:
	ldi r20, $F5
	;in r18,TCNT0	;TCNT0
	mul r18,r20
	in r20,TCNT0
	add r18,r20

	andi r18,$1F	;and med $7F för att få bort msb 
	cpi r18,$1E	
	brpl R_ADJUST	;kontroll av rand för att den ej ska bli större än 126	
	rjmp MAP_2
R_ADJUST:
	subi r18,ORIGO
MAP_2:
	;set Y_CORD VALUES WITH RANDOM
	st Y+,r18
	dec r16
	dec r17
	brne MAP_2
	cpi r16,$00
	brne MAP_1
	
	pop YL
	pop YH
	pop r20
	pop r18
	pop r17
	pop r16
	ret

PLOT_MAP:
	push r16
	push r17
	push r18
	push r19
	push ZH
	push ZL

	ldi r16,ORIGO	;sätter ut y-origo
	ldi r18,$00		;sätter ut x-origo
	ldi ZH,HIGH(Y_VAL)
	ldi ZL,LOW(Y_VAL)
PLOT_LOOP:
	ld r17,Z+
	out PORTA,r17
	cp r17,r16			;Jämför Y_VAL med nuvarande y-koord
	breq X_ADJUST
	brpl YUP_ADJUST
YDOWN_ADJUST:
	;;Skicka till plotter
	ldi r19,$02
	push r19
	call SEND
	pop r19
	dec r16
	cp r17,r16
	brne YDOWN_ADJUST
	rjmp X_ADJUST
YUP_ADJUST:
	;;Skicka till plotter
	ldi r19,$01
	push r19
	call SEND
	pop r19
	inc r16
	cp r17,r16
	brne YUP_ADJUST
	rjmp X_ADJUST
X_ADJUST:
	;;Skicka till plotter
	ldi r19,$04
	push r19
	call SEND
	pop r19
	inc r18
	cpi r18,MAPSIZE
	brne PLOT_LOOP
	sts Y_CORD,r16
	sts X_CORD,r18
	pop ZL
	pop ZH
	pop r19
	pop r18
	pop r17 
	pop r16
	ret


RESET_MAP:
	push r17
	push r18
	push r19

	lds	r18, X_CORD		;LADDAR x-koordinat från sram
	lds r17, Y_CORD		;LADDAR y-koordinat från sram
X_RESET:
	;;Skicka till plotter
	ldi r19,$06
	push r19
	call SEND
	pop r19
	dec r18
	brne X_RESET
Y_RESET:
	cpi r17,ORIGO
	breq RESET_DONE
	brpl Y_RESET2
Y_RESET2:
	;;Skicka till plotter
	ldi r19,$01
	push r19
	call SEND
	pop r19
	inc r17
	cpi r17,ORIGO
	brmi Y_RESET2
	rjmp RESET_DONE
Y_RESET1:
	;;Skicka till plotter
	ldi r19,$02
	push r19
	call SEND
	pop r19
	dec r17
	cpi r17,ORIGO
	brpl Y_RESET1
RESET_DONE:
	sts Y_CORD,r17
	sts X_CORD,r18

	pop r19
	pop r18
	pop r17
	ret

;Spelar och poäng program-----------------

PLAY_GAME:
	push r17
	push r18
	push ZH
	push ZL
	ldi ZH,HIGH(Y_VAL)
	ldi ZL,LOW(Y_VAL)
PLAY_LOOP:				;Loop för spel omgång
	lds r17,X_CORD
	call JOYSTICK
	lds r18,X_CORD
	cp r18,r17
	ld r17,Z+
	breq NO_XCHANGE
POINT_SYSTEM:
	lds r18,Y_CORD
	cp r17,r18			;Kontroll om spelaren ligger på samma YPOS som kartan 
	brne NO_XCHANGE		;Poäng om Y_CORD = Y_VAL på samma XPOS
	INCSRAM POINTS
NO_XCHANGE:
	cpi r18,MAPSIZE		;Kontroll om spelaren har kört hela banan
	brne PLAY_LOOP
	pop ZL
	pop ZH
	pop r18
	pop r17
	ret

;;HEX TO BCD OUTPUt
BCD_CODE:
	push r16
	push r17
	
	lds r16,POINTS		;Laddar poäng från sram
	mov r17,r16
	andi r17,$F0
	andi r16,$0F
	cpi r16,$0A			;konversion till BCD kodat tal
	brmi NO_CHANGE
	subi r16,$0A
	swap r17
	inc r17
	swap r17
NO_CHANGE:
	add r16,r17
	out PORTD,r16		;Utskrift av poäng till BCD Displayerna
	
	pop r17
	pop r16
	ret

;;JOYSTICK KOD-----------------------
JOYSTICK:
	push r16
	push r17
	
	ldi r16,0
	out ADMUX,r16
	ldi r16,(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)|(1<<ADEN)
	out ADCSRA,r16
CONVERT_1:
	sbi ADCSRA,ADSC
WAIT_1:
	sbic ADCSRA,ADSC
	rjmp WAIT_1
	in r16,ADCH
	cpi r16,$03
	brne X_CHECK
	INCSRAM X_CORD
	;;Skicka till plotter
	ldi r17,$04
	push r17
	call SEND
	pop r17
	rjmp JOYSTICK_Y
X_CHECK:
	cpi r16,$00
	brne JOYSTICK_Y
	DECSRAM X_CORD
	;;Skicka till plotter
	ldi r17,$06
	push r17
	call SEND
	pop r17
JOYSTICK_Y:
	ldi r16,(1<<MUX0)
	out ADMUX,r16
	ldi r16,(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)|(1<<ADEN)
	out ADCSRA,r16
CONVERT_2:
	sbi ADCSRA,ADSC
WAIT_2:
	sbic ADCSRA,ADSC
	jmp WAIT_2
	in r16,ADCH
	cpi r16,$03
	brne Y_CHECK
	INCSRAM Y_CORD
	;;Skicka till plotter
	ldi r17,$01
	push r17
	call SEND
	pop r17
	rjmp Y_FIN
Y_CHECK:
	cpi r16,$00
	brne Y_FIN
	DECSRAM Y_CORD
	;;Skicka till plotter
	ldi r17,$02
	push r17
	call SEND
	pop r17
Y_FIN:
	pop r17
	pop r16
	ret

	;DELAY PROGRAM-----------------------------
PLAYER_DELAY: ;250ms delay på 8MHz
	push r16
	push r17
	ldi r16, $04
PLAYER_DELAY1:
	ldi r17, $FA
PLAYER_DELAY2:
	dec r17
	brne PLAYER_DELAY2
	dec r16
	brne PLAYER_DELAY1
	pop r17
	pop r16
	ret

DELAY: ;1ms delay på 8MHz
	push r16
	push r17
	ldi r16, $A0
DELAY1:
	ldi r17, $FA
DELAY2:
	dec r17
	brne DELAY2
	dec r16
	brne DELAY1
	pop r17
	pop r16
	ret


;;SEND underprogram finns i både plotterjoy och mapcreation
SEND:
	push ZH
	push ZL
	push r17
	in ZH,SPH
	in ZL,SPL
SEND1:
	sbis PINB,1
	rjmp SEND1
	;call DELAY
	cbi PORTB,4		;Aktiverar slavens spi
	ldd r17,Z+6
	out SPDR,r17
WAIT:
	sbis SPSR,SPIF
	rjmp WAIT
	in r17,SPDR
	sbi PORTB,4

	pop r17
	pop ZL
	pop ZH
	ret

PEN_DOWN:
	push r19
	
	;;Skicka till plotter
	ldi r19,$03
	push r19
	call SEND
	pop r19

	pop r19
	ret

PEN_UP:
	push r19
	
	;;Skicka till plotter
	ldi r19,$05
	push r19
	call SEND
	pop r19

	pop r19
	ret

HW_INIT:
	;IN/UT inställnigar på portar
	ldi r16,$F0
	out DDRA,r16
	ldi r16,$FF
	out DDRD,r16
	;Timer0--------------
	ldi r16,(1<<CS00) 
	out TCCR0,r16
	;ldi r16,(1<<TOIE0)|(1<<OCIE1A)
	;out TIMSK,r16
	;sei interrupt code
;SPI SETUP----------------
	sbi DDRB,4
	sbi DDRB,5
	sbi DDRB,7
	ldi r16, (1<<MSTR)|(1<<SPE)|(1<<SPR1)
	sbi PORTB,4
	out SPCR,r16
	
	ret
