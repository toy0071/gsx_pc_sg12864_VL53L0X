;===== PCII_LCD_DEBUG.INC ========================================
;	LCD表示処理
;				toya@v007.vaio.ne.jp
;	CPU H8/3664
;-------------------------------------------------
;	サブルーチン
;
;	表示は、20x4。
;		+01234567890123456789
;		+----------+---------+
;		|TXD:XX              |
;		|00 11 22 33 44 55 66|
;		|77 88 99 00 11 22 33|
;		|44 55 66 77 88 99   |
;		+----------+---------+

;		+----------+---------+
;		| FF80:XX            |
;		| FF: 11 22 33 44    |
;		| CD: XX 11 22 33 44 |
;		|                    |
;		+----------+---------+

;		+----------+---------+
;		|-----rpm  TP: -XX%  |
;		|Fuel:-XX% TPo:-XX%  |
;		|Air:-X.XinHg        |
;		|IGN-T:-XXdeg        |
;		+----------+---------+

	.EXPORT		SHOW_TXD
	.EXPORT		SHOW_TXD_RE
	.EXPORT		SHOW_RX_HOME
	.EXPORT		SHOW_RXD

;=================================================
	.SECTION ROM, CODE, ALIGN=2
;--------------------------------------------------------
;--------------------------------------------------------
SHOW_TXD:	MOV.B	R0L, @TX_DATA
SHOW_TXD_RE:	MOV.W	#H'0100, R0
		JSR	@LCD_OFFSET
		MOV.W	#STR_TXD, R0
		JSR	@LCD_STRING
		MOV.B	@TX_DATA, R0L
		JSR	@LCD_HEXDATA
		JSR	@SET_RX_LOC
		RTS

SHOW_RX_HOME:	MOV.B	#0, R0L
		MOV.B	R0L, @RX_LOC
		MOV.B	#H'0D, R0L		; DISP=ON, CUR=OFF, BLINK=ON
		JSR	@LCD_SET_CTRL
SET_RX_LOC:	PUSH.W	R0
		PUSH.W	R1
		MOV.W	#RXD_LOC_OFFSET, R0
		MOV.W	#0, R1
		MOV.B	@RX_LOC,R1L
		ADD.W	R0,R1
		MOV.B	@R1, R0L
		BSET	#7, R0L
		JSR	@LCD_SET_CTRL
		POP.W	R1
		POP.W	R0
		RTS

SHOW_RXD:	JSR	@SET_RX_LOC
		JSR	@LCD_HEXDATA

		MOV.B	@RX_LOC, R0L
		INC.B	R0L
		CMP.B	#14, R0L
		BEQ	SHOW_RX_HOME
		MOV.B	R0L, @RX_LOC
		CMP.B	#7, R0L
		BEQ	SHOW_RXD_E
		MOV.B	#h'2E, R0L
		JSR	@LCD_CHAR
SHOW_RXD_E:	RTS

;---
STR_TXD		.SDATA		"TXD:"
		.DATA.B		0
RXD_LOC_OFFSET	.DATA.B		20,23,26,29,32,35,38,84,87,90,93,96,99,102

		.ALIGN	2

;=================================================
	.SECTION DATA, DATA, ALIGN=2

TX_DATA		.RES.B		1
RX_LOC		.RES.B		1

;;;;;;;;;;;;;;;;;;
;	.END
;;;;;;;;;;;;;;;;;;