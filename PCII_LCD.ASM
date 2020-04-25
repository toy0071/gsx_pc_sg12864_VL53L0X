;===== PCII_LCD.ASM ========================================
;	LCD表示処理
;				toya@v007.vaio.ne.jp
;	CPU H8/3664
;-------------------------------------------------
;	P80-P87	: LCD-data
;	P74	: LCD Sel
;	P76	: LCD Sig
;
;	表示は、20x4。
;		+01234567890123456789
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

;	DDRAMは、
;		+----------+---------+
;		|0...............0x13|
;		|0x40............0x53|
;		|Ox14............0x27|
;		|0x54............0x67|
;		+----------+---------+

	.FORM	COL=120
	.PRINT	LIST		;アセンブル時にリストファイルを出力する
	.CPU 300HN		;ＣＰＵの指定

	.INCLUDE "io.inc"

	.IMPORT	TIME100u
	.IMPORT	TIME00
	.IMPORT	TIME_N

	.EXPORT	LCD_INIT
	.EXPORT	LCD_HEXDATA
	.EXPORT	LCD_DEC_B_S
	.EXPORT	LCD_DEC_W
	.EXPORT	LCD_DEC_B_0
	.EXPORT	LCD_DEC_B
	.EXPORT	LCD_DEC_000
	.EXPORT	LCD_STRING
	.EXPORT	LCD_CLEAR_LINE
	.EXPORT	LCD_CLEAR
	.EXPORT	LCD_CHAR
	.EXPORT	LCD_OFFSET

	.EXPORT	HEX2ASCII

	.EXPORT	SHOW_REC_PAGE
	.EXPORT	SHOW_REC_END
	.EXPORT	SHOW_REC_ERR

;-----シンボルの設定-----
LCD_SEL		.BEQU	4,PDR7
LCD_RW		.BEQU	5,PDR7
LCD_SIG		.BEQU	6,PDR7
CMD_BUFF_SIZE	.EQU	16

R_LED		.BEQU	1,PDR1
G_LED		.BEQU	2,PDR1

;;;	.INCLUDE "PCII_LCD_DEBUG.INC"

;=================================================
	.SECTION ROM, CODE, ALIGN=2
;-------------------------------------------------
;	初期化処理
;-------------------------------------------------
LCD_INIT:
		MOV.W	#50, R0			; wait 50ms
		JSR	@TIME_N
		MOV.B	#H'30, R0L
		JSR	@LCD_SET_CTRL_NO_BUSY_CHK	; おまじない

		MOV.W	#4, R0			; wait 4.2ms
		JSR	@TIME_N
		JSR	@TIME100u
		JSR	@TIME100u
		MOV.B	#H'30, R0L
		JSR	@LCD_SET_CTRL_NO_BUSY_CHK	; おまじない

		JSR	@TIME100u		; wait 100us

		MOV.B	#H'38, R0L		; DL=1, N=1, F=0
		JSR	@LCD_SET_CTRL
		MOV.B	#H'08, R0L		; DISP=OFF, CUR=OFF, BLINK=OFF
		JSR	@LCD_SET_CTRL
		MOV.B	#H'01, R0L		; CLR
		JSR	@LCD_SET_CTRL
		MOV.B	#H'06, R0L		; Cursor shift right
		JSR	@LCD_SET_CTRL
		MOV.B	#H'0C, R0L		; DISP=ON, CUR=OFF, BLINK=OF
		JSR	@LCD_SET_CTRL

		RTS

;--------------------------------------------------------
;	HEX to ASCII
;	IN  : R0L
;	OUT : R0H= 2keta  R0L=1keta
;--------------------------------------------------------
HEX2ASCII:	MOV.B	R0L, R0H
		SHLR.B	R0H
		SHLR.B	R0H
		SHLR.B	R0H
		SHLR.B	R0H
		AND.B	#H'0F, R0H
		ADD.B	#H'30, R0H
		CMP.B	#H'3A, R0H
		BMI	HEX2ASCII_L1
		ADD.B	#07, R0H
HEX2ASCII_L1:	AND.B	#H'0F, R0L
		ADD.B	#H'30, R0L
		CMP.B	#H'3A, R0L
		BMI	HEX2ASCII_L2
		ADD.B	#07, R0L
HEX2ASCII_L2:	RTS

;-------------------------------------------------
;	SEND TO LCD
;-------------------------------------------------
LCD_SET_CTRL:	PUSH.W	R0
		BSR	LCD_BUSY_CHK
		POP.W	R0
LCD_SET_CTRL_NO_BUSY_CHK:
;;;		ANDC.B	#H'7F,CCR		; 割り込み禁止
		MOV.B	R0L,@PDR8		; 制御データ出力
		BCLR	LCD_SEL			; 制御データフラグ
		NOP
		BCLR	LCD_RW			; 書き込み
		NOP
		BSET	LCD_SIG			; 書き込みシグナル
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		BCLR	LCD_SIG
;;;		ORC.B	#H'80,CCR		; 割り込み許可
		RTS

LCD_CHAR:
LCD_SET_DATA:	PUSH.W	R0
;;;		ANDC.B	#H'7F,CCR		; 割り込み禁止
		BSR	LCD_BUSY_CHK
		POP.W	R0

		MOV.B	R0L,@PDR8		; 制御データ出力
		BSET	LCD_SEL			; 制御データフラグ
		NOP
		BCLR	LCD_RW			; 書き込み
		NOP
		BSET	LCD_SIG			; 書き込みシグナル
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		BCLR	LCD_SIG
;;;		ORC.B	#H'80,CCR		; 割り込み許可
		RTS

LCD_BUSY_CHK:	MOV.B	#0, R0L			; P8*を入力に変更
		MOV.B	R0L,@PCR8

LCD_BUSY_CHK_l1:
;;;		ANDC.B	#H'7F,CCR		; 割り込み禁止
		BCLR	LCD_SEL			; 制御データフラグ
		NOP
		BSET	LCD_RW			; 書き込み
		NOP
		BSET	LCD_SIG			; 書き込みシグナル
		NOP
		NOP
		NOP
		MOV.B	@PDR8, R0L
		NOP
		NOP
		BCLR	LCD_SIG
;;;		ORC.B	#H'80,CCR		; 割り込み許可
		BTST	#7, R0L
		BNE	LCD_BUSY_CHK_l1

		MOV.B	#H'FF, R0L		; P8*を出力に変更
		MOV.B	R0L,@PCR8
		RTS

LCD_HEXDATA	PUSH.W	R0
		JSR	@HEX2ASCII
		PUSH.W	R0
		MOV.B	R0H, R0L
		BSR	LCD_SET_DATA
		POP.W	R0
		BSR	LCD_SET_DATA
		POP.W	R0
		RTS

;-------------------------------------------------
;	R0の10進表示。符号なし。最上位桁０詰めなし
;-------------------------------------------------
LCD_DEC_W	PUSH.L	ER0
		PUSH.L	ER1
		MOV.W	#0, E0
		MOV.W	#10, R1
		DIVXU.W	R1, ER0
		PUSH.W	E0
		MOV.W	#0, E0
		DIVXU.W	R1, ER0
		PUSH.W	E0
		MOV.W	#0, E0
		DIVXU.W	R1, ER0
		PUSH.W	E0
		MOV.W	#0, E0
		DIVXU.W	R1, ER0
		PUSH.W	E0

		MOV.B	R0L, R1L		; 上位０か？
		ADD.B	#H'30, R0L
		CMP.B	#H'0, R1L
		BNE	LCD_DEC_W_L1
		MOV.B	#H'20, R0L
LCD_DEC_W_L1:
		JSR	@LCD_CHAR
		POP.W	R0

		OR.B	R0L, R1L		; 上位桁チェック用 ORを取ることで、０以外かを確認
		ADD.B	#H'30, R0L
		CMP.B	#H'0, R1L
		BNE	LCD_DEC_W_L2
		MOV.B	#H'20, R0L
LCD_DEC_W_L2:
		JSR	@LCD_CHAR
		POP.W	R0

		OR.B	R0L, R1L		; 上位桁チェック用 ORを取ることで、０以外かを確認
		ADD.B	#H'30, R0L
		CMP.B	#H'0, R1L
		BNE	LCD_DEC_W_L3
		MOV.B	#H'20, R0L
LCD_DEC_W_L3:
		JSR	@LCD_CHAR
		POP.W	R0
		
		ADD.B	#H'30, R0L
		JSR	@LCD_CHAR
		POP.W	R0
		ADD.B	#H'30, R0L
		JSR	@LCD_CHAR
		POP.L	ER1
		POP.L	ER0
		RTS

;-------------------------------------------------
;	R0Lの10進2桁表示。符号なし。０埋めあり
;-------------------------------------------------
LCD_DEC_B_0	PUSH.W	R1
		MOV.B	#10, R1L
		MOV.B	#0, R0H
		DIVXU.B	R1L, R0
		PUSH.W	R0
		MOV.B	#0, R0H
		DIVXU.B	R1L, R0
		MOV.B	R0H, R0L
		ADD.B	#H'30, R0L
		JSR	@LCD_CHAR
		POP.W	R0
		MOV.B	R0H, R0L
		ADD.B	#H'30, R0L
		JSR	@LCD_CHAR
		POP.W	R1
		RTS

;-------------------------------------------------
;	R0Lの10進表示。符号なし。最上位桁０詰めなし
;-------------------------------------------------
LCD_DEC_B	PUSH.L	ER0
		PUSH.L	ER1
		MOV.B	#10, R1L
		MOV.B	#0, R0H
		DIVXU.B	R1L, R0
		PUSH.W	R0
		MOV.B	#0, R0H
		DIVXU.B	R1L, R0
		PUSH.W	R0

		MOV.B	R0L, R1L		; 上位０か？
		ADD.B	#H'30, R0L
		CMP.B	#H'0, R1L
		BNE	LCD_DEC_B_L1
		MOV.B	#H'20, R0L
LCD_DEC_B_L1:
		JSR	@LCD_CHAR
		POP.W	R0
		MOV.B	R0H, R0L
		OR.B	R0L, R1L		; 上位桁チェック用 ORを取ることで、０以外かを確認
		ADD.B	#H'30, R0L
		CMP.B	#H'0, R1L
		BNE	LCD_DEC_B_L2
		MOV.B	#H'20, R0L
LCD_DEC_B_L2:
		JSR	@LCD_CHAR
		POP.W	R0
		MOV.B	R0H, R0L
		ADD.B	#H'30, R0L
		JSR	@LCD_CHAR

		POP.L	ER1
		POP.L	ER0
		RTS


;-------------------------------------------------
;	R0Lの10進2桁表示。符号あり(+はスペース)
;	R0Hが０以外の時、小数点を付ける
;-------------------------------------------------
LCD_DEC_B_S	PUSH.W	R0
		PUSH.W	R1
		BTST	#7,R0L
		BNE	LCD_DEC_B_MINUS
		MOV.W	R0, R1
		MOV.B	#H'20, R0L
		JSR	@LCD_CHAR
		MOV.W	R1, R0
		JMP	@LCD_DEC_B_U
LCD_DEC_B_MINUS:
		MOV.W	R0, R1
		MOV.B	#H'2D, R0L
		JSR	@LCD_CHAR
		MOV.W	R1, R0
		NEG.B	R0L

LCD_DEC_B_U:
		MOV.B	R0H, R1H		;小数点フラグ
		MOV.B	#0, R0H
		MOV.B	#10, R1L
		DIVXU.B	R1L, R0
		PUSH.W	R0		; R0H LOWEST
		MOV.B	#0, R0H
		DIVXU.B	R1L, R0
		MOV.B	R0H, R0L
		ADD.B	#H'30, R0L
		JSR	@LCD_CHAR
		CMP.B	#0, R1H
		BEQ	LCD_DEC_B_U1
		MOV.B	#H'2E, R0L
		JSR	@LCD_CHAR
LCD_DEC_B_U1:
		POP.W	R0
		MOV.B	R0H, R0L
		ADD.B	#H'30, R0L
		JSR	@LCD_CHAR
		JMP	@LCD_DEC_B_S_END
LCD_DEC_B_S_END:
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	R0の10進3桁表示。UNSIGNED
;	IN	R0:３ケタ表示するデータ
;	BREAK	R1
;-------------------------------------------------
LCD_DEC_000:
		MOV.B	#100, R1L
		DIVXU.B	R1L, R0
		PUSH.W	R0
		ADD.B	#H'30, R0L
		JSR	@LCD_CHAR
		POP.W	R0
		MOV.B	R0H, R0L
		JSR	@LCD_DEC_B_0
		RTS

;-------------------------------------------------
;	文字列表示
;	IN R0:文字列のポインタ。終端は、\0
;-------------------------------------------------
LCD_STRING:	PUSH.L	ER0
		PUSH.L	ER1
		MOV.L	ER0, ER1
LCD_STRING_L1:	MOV.B	@R1+, R0L
		BEQ	LCD_STRING_E
		BSR	LCD_SET_DATA
		JMP	@LCD_STRING_L1
LCD_STRING_E:	POP.L	ER1
		POP.L	ER0
		RTS

;-------------------------------------------------
;	LCD　1行クリア
;-------------------------------------------------
LCD_CLEAR_LINE:	MOV.B	R0L, R0H
		MOV.B	#0, R0L
		JSR	@LCD_OFFSET
		MOV.B	#20, R0H
		MOV.B	#h'20, R0L
LCD_CLEAR_LINE_L:
		BSR	LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_CLEAR_LINE_L
		RTS

;-------------------------------------------------
;	LCD　全画面クリア
;-------------------------------------------------
LCD_CLEAR:	MOV.B	#H'01, R0L
		BSR	LCD_SET_CTRL
		RTS

;-------------------------------------------------
;	LOCATE X<0..19>,Y<0..3>  X=R0L, Y=R0H
;-------------------------------------------------
;		+----------+---------+
;		|0...............0x13|
;		|0x40............0x53|
;		|Ox14............0x27|
;		|0x54............0x67|
;		+----------+---------+
LCD_OFFSET:	PUSH.W	R0
		CMP.B	#20, R0L
		BCS	LOC_OFFSET_L1		; R0L - 20 < 0
		MOV.B	#19, R0L
LOC_OFFSET_L1:	CMP.B	#0, R0H
		BEQ	LCD_OFFSET_SET
		CMP.B	#1, R0H
		BNE	LCD_OFFSET_L2
		ADD.B	#64, R0L
		JMP	@LCD_OFFSET_SET
LCD_OFFSET_L2:	CMP.B	#2, R0H
		BNE	LCD_OFFSET_L3
		ADD.B	#20, R0L
		JMP	@LCD_OFFSET_SET
LCD_OFFSET_L3:	ADD.B	#84, R0L

LCD_OFFSET_SET:	BSET	#7, R0L
		JSR	@LCD_SET_CTRL
		POP.W	R0
		RTS

;-------------------------------------------------
;	REC DISP
;-------------------------------------------------
SHOW_REC_PAGE:
		PUSH.W	R0
		MOV.W	#H'0013, R0
		JSR	@LCD_OFFSET
		MOV.B	#H'FF, R0L
		JSR	@LCD_CHAR
		POP.W	R0
		RTS

SHOW_REC_END:
		PUSH.W	R0
		MOV.W	#H'0013, R0
		JSR	@LCD_OFFSET
		MOV.B	#H'20, R0L
		JSR	@LCD_CHAR
		POP.W	R0
		RTS

SHOW_REC_ERR:
		PUSH.W	R0
		MOV.W	#H'0013, R0
		JSR	@LCD_OFFSET
		MOV.B	#H'45, R0L
		JSR	@LCD_CHAR
		POP.W	R0
		RTS

	.END
