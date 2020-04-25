;===== SUBROUTINES ========================================
;				toya@v007.vaio.ne.jp
	.FORM	COL=120
	.PRINT	LIST		;アセンブル時にリストファイルを出力する
	.CPU 300HN		;ＣＰＵの指定

	.INCLUDE "io.inc"

	.EXPORT	TIME100u
	.EXPORT	TIME00
	.EXPORT	TIME_N

	.SECTION ROM, CODE, ALIGN=2

;------	0.1mS Timer -----
TIME100u:	PUSH.W	R0			; 6 clocks +
		MOV.W	#266,R0			; 4 clocks +
TIME100u1:	DEC.W	#1,R0			; 2 clocks * 266 +
		BNE	TIME100u1			; 4 clocks * 266 +
		POP.W	R0			; 6 clocks +
		RTS				; 10 clocks + 10 clocks =  16002

;------	1mS Timer -----
TIME00:	PUSH.W	R0			; 6 clocks +
	MOV.W	#2661,R0		; 4 clocks +
TIME01:	DEC.W	#1,R0			; 2 clocks * 2661 +
	BNE	TIME01			; 4 clocks * 2661 +
	POP.W	R0			; 6 clocks +
	RTS				; 10 clocks + 10 clocks =  16002

;------	N mS Timer -----		; N = R0
TIME_N:
TIME10:	PUSH.W	R0			; 6 clocks * N +
	MOV.W	#2660,R0		; 4 clocks * N +
TIME11:	DEC.W	#1,R0			; 2 clocks * 2660 * N +
	BNE	TIME11			; 4 clocks * 2660 * N +
	POP.W	R0			; 6 clocks * N +
	DEC.W	#1,R0			; 2 clocks * N +
	BNE	TIME10			; 4 clocks * N +
	RTS				; 10 clocks + 10 clocks =  MANY

	.END
