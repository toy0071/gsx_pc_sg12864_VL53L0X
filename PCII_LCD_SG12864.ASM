;===== PCII_LCD.ASM ========================================
;	LCD表示処理 FOR SG12864/TG12864
;				toya@v007.vaio.ne.jp
;	CPU H8/3664 H8/3694
;-------------------------------------------------
;	P50	: LCD CS1
;	P51	: LCD CS2
;	P52	: LCD RST
;	P74	: LCD RS    1:DATA/0:COMMAND
;	P75	: LCD R/W   1:R/0:W
;	P76	: LCD SIG   0:TRIG
;	P80-P87	: LCD-data
;
;	表示は、128x64 pixel


	.FORM	COL=120
	.PRINT	LIST		;アセンブル時にリストファイルを出力する
	.CPU 300HN		;ＣＰＵの指定

	.INCLUDE "io.inc"
	.INCLUDE "PCII.inc"

	.IMPORT		TIME100u
	.IMPORT		TIME00
	.IMPORT		TIME_N

	.IMPORT		TIMEV_CNT

	.IMPORT		M_REV
	.IMPORT		M_TP
	.IMPORT		M_AAP
	.IMPORT		M_TPo
	.IMPORT		M_MP

	.IMPORT		GET_G_XY
	.IMPORT		OFFSET_AX_LOG
	.IMPORT		OFFSET_AY_LOG

	.IMPORT		SUS_LOG
	.IMPORT		SUS_LOG_STATE
	.IMPORT		VL53L0X_SUS
	.IMPORT		VL53L0X_SUS_MM
	.IMPORT		DISP_MULTI_TIME

	.IMPORT		MODE1_PAGE_COUNT
	.IMPORT		MODE2_PAGE_COUNT
	.IMPORT		MODE3_PAGE_COUNT
	.IMPORT		MODE4_PAGE_COUNT
	.IMPORT		NULL_PAGE_COUNT

	.EXPORT		LCD_INIT
	.EXPORT		TOP_MENU
	.EXPORT		LCD_PCII_MON
	.EXPORT		LCD_G_MON
	.EXPORT		LCD_G_TRACK_CS2
	.EXPORT		LCD_SUS_TRACK
	.EXPORT		LCD_MULTI_MON
	.EXPORT		LCD_EEPROM_MEM_INFO
	.EXPORT		LCD_I2C_FORMAT_MENU
	.EXPORT		LCD_I2C_FORMAT_CONFIRM
	.EXPORT		LCD_I2C_FORMAT_DOING
	.EXPORT		LCD_I2C_FORMAT_DONE
	.EXPORT		LCD_PCII_DATA_CS1_INIT
	.EXPORT		LCD_PCII_DATA_CS1

	.EXPORT		VRAM_TO_LCD_CS1
	.EXPORT		VRAM_TO_LCD_CS2
	.EXPORT		LCD_CLR_CS1
	.EXPORT		LCD_CLR_CS2
	.EXPORT		LCD_OFFSET		; 使用しないこと
	.EXPORT		LCD_TEXT_OFFSET
	.EXPORT		LCD_HEXDATA
	.EXPORT		LCD_DEC_B_S
	.EXPORT		LCD_DEC_W
	.EXPORT		LCD_DEC_B_0
	.EXPORT		LCD_DEC_B
	.EXPORT		LCD_DEC_000
	.EXPORT		LCD_STRING
	.EXPORT		LCD_NUM
	.EXPORT		LCD_CHAR
	.EXPORT		LCD_CH_IMAGE
	.EXPORT		LCD_STRING_INV
	.EXPORT		LCD_CHAR_INV

	.EXPORT		LCD_LNUM
	.EXPORT		LCD_LCHAR
	.EXPORT		LCD_LDEC_B_0
	.EXPORT		LCD_LDEC_000

	.EXPORT		HEX2ASCII

	.EXPORT		VRAM_CLR
	.EXPORT		VRAM_XY_CS1
	.EXPORT		VRAM_X_CS1
	.EXPORT		VRAM_X_CS2
	.EXPORT		VRAM_X_3L
	.EXPORT		VRAM_X_4L
	.EXPORT		VRAM_STRING
	.EXPORT		VRAM_PCII_CS2
	.EXPORT		VRAM_RPM_CS2
	.EXPORT		VRAM_STR_RPM_CS2
	.EXPORT		VRAM_STR_TP_CS2
	.EXPORT		VRAM_DEC_B_S
	.EXPORT		VRAM_DEC_B

	.INCLUDE "CONST_EX.inc"

;-----シンボルの設定-----
LCD_DI		.BEQU	4,PDR7		; DATA/CMD, 
LCD_RW		.BEQU	5,PDR7
LCD_E		.BEQU	6,PDR7
LCD_CS1		.BEQU	0,PDR5
LCD_CS2		.BEQU	1,PDR5
LCD_RST		.BEQU	2,PDR5
CMD_BUFF_SIZE	.EQU	16

R_LED		.BEQU	1,PDR1
G_LED		.BEQU	2,PDR1

;;;	.INCLUDE "const.def"
	.INCLUDE "const_98f.def"

;=================================================
	.SECTION ROM, CODE, ALIGN=2

;=================================================
;	汎用処理
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

;=================================================
;	LCD用のVRAM処理
;-------------------------------------------------
;-------------------------------------------------
;	VRAMへのコピー
;	IN	R0L:ページ 0/1
;		R1 :イメージデータアドレス
;-------------------------------------------------
IMAGE_TO_VRAM	PUSH.W	R0
		PUSH.W	R5
		PUSH.W	R6
		MOV.W	#VRAM_X00Y00, R6
		CMP.B	#0, R0L
		BEQ	IMAGE_TO_VRAM_L0
		MOV.W	#VRAM_X64Y00, R6
IMAGE_TO_VRAM_L0:
		MOV.W	#128, R0
IMAGE_TO_VRAM_L1:
		MOV.L	@R1+,ER5
		MOV.L	ER5, @R6
		ADD.W	#4, R6
		DEC.W	#1, R0
		BNE	IMAGE_TO_VRAM_L1
		POP.W	R6
		POP.W	R5
		POP.W	R0
		RTS

;-------------------------------------------------
;	VRAMのクリア for SG12864
;-------------------------------------------------
VRAM_CLR	PUSH.W	R0
		PUSH.W	R1
		PUSH.L	ER2
		MOV.W	#VRAM_X00Y00, R1
VRAM_CLR_L0:	MOV.W	#256, R0
		MOV.L	#0, ER2
VRAM_CLR_L1:	MOV.L	ER2, @R1
		ADD.W	#4,R1
		DEC.W	#1, R0
		BNE	VRAM_CLR_L1
		POP.L	ER2
		POP.W	R1
		POP.W	R0
		RTS
		
;-------------------------------------------------
;	VRAM へ個々のイメージコピー
;-------------------------------------------------
;	レーダーイメージ
;-------------------------------------------------
VRAM_PCII_CS1	PUSH.W	R0
		PUSH.W	R1
		MOV.B	#0, R0L
		MOV.W	#Graph_cir_00,R1
		JSR	@IMAGE_TO_VRAM
		POP.W	R1
		POP.W	R0
		RTS

VRAM_PCII_CS2	PUSH.W	R0
		PUSH.W	R1
		MOV.B	#1, R0L
		MOV.W	#Graph_cir_00,R1
		JSR	@IMAGE_TO_VRAM
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	ＸＹ軸イメージ
;-------------------------------------------------
VRAM_XY_CS1	PUSH.W	R0
		PUSH.W	R1
		MOV.B	#0, R0L
		MOV.W	#Graph_cross_00,R1
		JSR	@IMAGE_TO_VRAM
		POP.W	R1
		POP.W	R0
		RTS

VRAM_XY_CS2	PUSH.W	R0
		PUSH.W	R1
		MOV.B	#1, R0L
		MOV.W	#Graph_cross_00,R1
		JSR	@IMAGE_TO_VRAM
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	Ｘ軸イメージ（8行、一画面）
;-------------------------------------------------
VRAM_X_CS1	PUSH.W	R0
		PUSH.W	R1
		PUSH.L	ER2
		MOV.W	#VRAM_X00Y00, R1
		JMP	@VRAM_X_CS
VRAM_X_CS2	PUSH.W	R0
		PUSH.W	R1
		PUSH.L	ER2
		MOV.W	#VRAM_X64Y00, R1
		JMP	@VRAM_X_CS
VRAM_X_CS:
		MOV.W	#48, R0
		MOV.L	#0, ER2
VRAM_X_CS1_L1:
		MOV.L	ER2, @R1
		ADD.W	#4, R1
		DEC.W	#1, R0
		BNE	VRAM_X_CS1_L1

		MOV.W	#8, R0
VRAM_X_CS1_L2:
		MOV.L	#0, ER2
		MOV.L	ER2, @R1
		ADD.W	#4, R1
		MOV.L	#H'000000C0, ER2
		MOV.L	ER2, @R1
		ADD.W	#4, R1
		DEC.W	#1, R0
		BNE	VRAM_X_CS1_L2

		MOV.W	#8, R0
VRAM_X_CS1_L3:
		MOV.L	#H'01010101, ER2
		MOV.L	ER2, @R1
		ADD.W	#4, R1
		MOV.L	#H'01010107, ER2
		MOV.L	ER2, @R1
		ADD.W	#4, R1
		DEC.W	#1, R0
		BNE	VRAM_X_CS1_L3

		MOV.W	#48, R0
		MOV.L	#0, ER2
VRAM_X_CS1_L4:
		MOV.L	ER2, @R1
		ADD.W	#4, R1
		DEC.W	#1, R0
		BNE	VRAM_X_CS1_L4

		POP.L	ER2
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	Ｘ軸イメージ（３行、横軸フル）
;	IN R0L:開始Y行(0,1,2,3,4,5)
;-------------------------------------------------
VRAM_X_3L	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2
		PUSH.L	ER3
		MOV.B	R0L, R0H		; Y * 256
		AND.W	#H'700, R0
		SHLR.W	R0			; Y * 128
		SHLR.W	R0			; Y * 64
		MOV.W	#VRAM_X00Y00, R1
		MOV.W	#VRAM_X64Y00, R2
		ADD.W	R0, R1
		ADD.W	R0, R2

		MOV.W	#16, R0
		MOV.L	#H'01010101, ER3
VRAM_X_3L_L1:
		MOV.L	ER3, @R1
		MOV.L	ER3, @R2
		ADD.W	#4, R1
		ADD.W	#4, R2
		DEC.W	#1, R0
		BNE	VRAM_X_3L_L1

		MOV.W	#8, R0
VRAM_X_3L_L2:
		MOV.L	#H'10101010, ER3
		MOV.L	ER3, @R1
		MOV.L	ER3, @R2
		ADD.W	#4, R1
		ADD.W	#4, R2
		MOV.L	#H'1010107C, ER3
		MOV.L	ER3, @R1
		MOV.L	ER3, @R2
		ADD.W	#4, R1
		ADD.W	#4, R2
		DEC.W	#1, R0
		BNE	VRAM_X_3L_L2

		MOV.W	#16, R0
		MOV.L	#0, ER3
VRAM_X_3L_L3:
		MOV.L	ER3, @R1
		MOV.L	ER3, @R2
		ADD.W	#4, R1
		ADD.W	#4, R2
		DEC.W	#1, R0
		BNE	VRAM_X_3L_L3

		POP.L	ER3
		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS
		
;-------------------------------------------------
;	Ｘ軸イメージ（４行、横軸フル、2ライン）
;-------------------------------------------------
VRAM_X_4L	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2
		PUSH.L	ER3
		PUSH.W	R4
		PUSH.W	R5
		MOV.W	#VRAM_X00Y00, R1
		MOV.W	#VRAM_X64Y00, R2
		MOV.W	#VRAM_X00Y32, R4
		MOV.W	#VRAM_X64Y32, R5

		MOV.W	#16, R0
		MOV.L	#H'0, ER3
VRAM_X_4L_L1:
		MOV.L	ER3, @R1
		MOV.L	ER3, @R2
		MOV.L	ER3, @R4
		MOV.L	ER3, @R5
		ADD.W	#4, R1
		ADD.W	#4, R2
		ADD.W	#4, R4
		ADD.W	#4, R5
		DEC.W	#1, R0
		BNE	VRAM_X_4L_L1

		MOV.W	#8, R0
VRAM_X_4L_L2:
		MOV.L	#H'00000000, ER3
		MOV.L	ER3, @R1
		MOV.L	ER3, @R2
		MOV.L	ER3, @R4
		MOV.L	ER3, @R5
		ADD.W	#4, R1
		ADD.W	#4, R2
		ADD.W	#4, R4
		ADD.W	#4, R5
		MOV.L	#H'000000C0, ER3
		MOV.L	ER3, @R1
		MOV.L	ER3, @R2
		MOV.L	ER3, @R4
		MOV.L	ER3, @R5
		ADD.W	#4, R1
		ADD.W	#4, R2
		ADD.W	#4, R4
		ADD.W	#4, R5
		DEC.W	#1, R0
		BNE	VRAM_X_4L_L2

		MOV.W	#8, R0
VRAM_X_4L_L3:
		MOV.L	#H'01010101, ER3
		MOV.L	ER3, @R1
		MOV.L	ER3, @R2
		MOV.L	ER3, @R4
		MOV.L	ER3, @R5
		ADD.W	#4, R1
		ADD.W	#4, R2
		ADD.W	#4, R4
		ADD.W	#4, R5
		MOV.L	#H'01010107, ER3
		MOV.L	ER3, @R1
		MOV.L	ER3, @R2
		MOV.L	ER3, @R4
		MOV.L	ER3, @R5
		ADD.W	#4, R1
		ADD.W	#4, R2
		ADD.W	#4, R4
		ADD.W	#4, R5
		DEC.W	#1, R0
		BNE	VRAM_X_4L_L3

		MOV.W	#16, R0
		MOV.L	#h'80808080, ER3
VRAM_X_4L_L4:
		MOV.L	ER3, @R1
		MOV.L	ER3, @R2
		MOV.L	ER3, @R4
		MOV.L	ER3, @R5
		ADD.W	#4, R1
		ADD.W	#4, R2
		ADD.W	#4, R4
		ADD.W	#4, R5
		DEC.W	#1, R0
		BNE	VRAM_X_4L_L4

		POP.W	R5
		POP.W	R4
		POP.L	ER3
		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	ドットをVRAMにプロット
;	IN	R0L=X(0..127), R0H=Y(0..63)
;-------------------------------------------------
VRAM_SET_DOT:	PUSH.W	R0
		PUSH.L	ER1
		PUSH.W	R2
		MOV.W	#VRAM_X00Y00, R2
		CMP.B	#64, R0L
		BCS	VRAM_SET_DOT_L1
		MOV.W	#VRAM_X64Y00, R2
		SUB.W	#64, R0			; SUBはWのみ
VRAM_SET_DOT_L1:
		MOV.B	R0H, R1L
		MOV.B	#0, R1H
		AND.B	#H'F8, R1L		; YをByteに(8倍したまま)
		SHAL.W	R1			; 1Bytesごとに64倍（x桁分）
		SHAL.W	R1			; x32
		SHAL.W	R1			; x64
		ADD.W	R2, R1
		MOV.B	#0, R2H
		MOV.B	R0L, R2L
		ADD.W	R2,R1			; VRAMのアドレス(Y/8*64+X)
		AND.B	#7, R0H
		MOV.W	#0, E1
		BSET	R0H, @ER1
		POP.W	R2
		POP.L	ER1
		POP.W	R0
		RTS

;-------------------------------------------------
;	VRAMに、縦線をプロット
;	IN	R0L=X(0..127), R0H=Y(0..63)
;			       R1H=Y(0..63)
;-------------------------------------------------
VRAM_SET_VLINE:	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2
		PUSH.W	R3
		AND.B	#H'3F,R1H
		AND.B	#H'3F,R0H
		CMP.B	R1H, R0H
		BCC	VRAM_SET_VLINE_L1
		MOV.B	R1H, R3H
		JMP	@VRAM_SET_VLINE_L2
VRAM_SET_VLINE_L1
		MOV.B	R0H, R3H
		MOV.B	R1H, R0H
VRAM_SET_VLINE_L2:
		MOV.W	#VRAM_X00Y00, R2
		CMP.B	#64, R0L
		BCS	VRAM_SET_VLINE_L3
		MOV.W	#VRAM_X64Y00, R2
		SUB.W	#64, R0			; SUBはWのみ
VRAM_SET_VLINE_L3:
		MOV.B	R0H, R1L
		MOV.B	#0, R1H
		AND.B	#H'F8, R1L		; YをByteに(8倍したまま)
		SHAL.W	R1			; 1Bytesごとに64倍（x桁分）
		SHAL.W	R1			; x32
		SHAL.W	R1			; x64
		ADD.W	R2, R1
		MOV.B	#0, R2H
		MOV.B	R0L, R2L
		ADD.W	R2,R1			; VRAMのアドレス(Y/8*64+X)

		MOV.B	#0, R2L			; 線のパターン作成（すべて０）
		SUB.B	R0H, R3H		; Yの長さ
		INC.B	R3H			; 最短は1
		AND.B	#7, R0H			; 初期ドット位置
VRAM_SET_VLINE_L4:
		BSET	R0H, R2L
		INC.B	R0H
		CMP.B	#8, R0H
		BNE	VRAM_SET_VLINE_L5
		MOV.B	@R1, R2H
		OR.B	R2L, R2H
		MOV.B	R2H, @R1
		MOV.B	#0, R2L
		MOV.B	R2L, R0H
		ADD.W	#64, R1
VRAM_SET_VLINE_L5:
		DEC.B	R3H
		BNE	VRAM_SET_VLINE_L4
		CMP.B	#0, R0H
		BEQ	VRAM_SET_VLINE_L6
		MOV.B	@R1, R2H
		OR.B	R2L, R2H
		MOV.B	R2H, @R1
VRAM_SET_VLINE_L6:
		POP.W	R3
		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	3x3（中心はなし）をVRAMにプロット
;	IN	R0L=X(1..127), R0H=Y(1..63)
;-------------------------------------------------
VRAM_SET_3SEQ:	PUSH.W	R0
		PUSH.L	ER1
		PUSH.W	R2
		MOV.W	#VRAM_X00Y00, R2
		CMP.B	#64, R0L
		BCS	VRAM_SET_3SEQ_L1
		MOV.W	#VRAM_X64Y00, R2
		SUB.W	#64, R0			; SUBはWのみ
VRAM_SET_3SEQ_L1:
		DEC.B	R0L
		BPL	VRAM_SET_3SEQ_L2
		MOV.B	#0, R0L
VRAM_SET_3SEQ_L2:
		DEC.B	R0H
		BPL	VRAM_SET_3SEQ_L3
		MOV.B	#0, R0H
VRAM_SET_3SEQ_L3:
		MOV.B	R0H, R1L
		MOV.B	#0, R1H
		AND.B	#H'F8, R1L		; YをByteに(8倍したまま)
		SHAL.W	R1			; 1Bytesごとに64倍（x桁分）
		SHAL.W	R1			; x32
		SHAL.W	R1			; x64
		ADD.W	R2, R1
		MOV.B	#0, R2H
		MOV.B	R0L, R2L
		ADD.W	R2,R1			; VRAMのアドレス(Y/8*64+X)
		MOV.W	#0, E1
		AND.B	#7, R0H
		CMP.B	#7, R0H
		BEQ	VRAM_SET_3SEQ_1BITONLY
		CMP.B	#6, R0H
		BEQ	VRAM_SET_3SEQ_2BITS
VRAM_SET_3SEQ_3BITS:				; ページ内に3ドット分入る場合
		BSET	R0H, @ER1
		INC.B	R0H
		BSET	R0H, @ER1
		INC.B	R0H
		BSET	R0H, @ER1
		DEC.B	R0H
		DEC.B	R0H

		INC.L	#1, ER1
		BSET	R0H, @ER1
		INC.B	R0H
		INC.B	R0H
		BSET	R0H, @ER1
		DEC.B	R0H
		DEC.B	R0H

		INC.L	#1, ER1
		BSET	R0H, @ER1
		INC.B	R0H
		BSET	R0H, @ER1
		INC.B	R0H
		BSET	R0H, @ER1
		JMP	@VRAM_SET_3SEQ_E
VRAM_SET_3SEQ_2BITS:				; ページ内に2ドット分入る場合
		BSET	R0H, @ER1
		INC.B	R0H
		BSET	R0H, @ER1
		DEC.B	R0H

		INC.L	#1, ER1
		BSET	R0H, @ER1

		INC.L	#1, ER1
		BSET	R0H, @ER1
		INC.B	R0H
		BSET	R0H, @ER1

		ADD.L	#62, ER1		; ページ段下げ
		MOV.B	#0, R0H			; 一ドット目
		BSET	R0H, @ER1
		INC.L	#1, ER1
		BSET	R0H, @ER1
		INC.L	#1, ER1
		BSET	R0H, @ER1
		JMP	@VRAM_SET_3SEQ_E
VRAM_SET_3SEQ_1BITONLY:				; ページ内に1ドットのみ入る場合
		BSET	R0H, @ER1
		INC.L	#1, ER1
		BSET	R0H, @ER1
		INC.L	#1, ER1
		BSET	R0H, @ER1

		ADD.L	#62, ER1		; ページ段下げ
		MOV.B	#0, R0H			; 一ドット目
		BSET	R0H, @ER1
		INC.B	R0H
		BSET	R0H, @ER1
		DEC.B	R0H

		INC.L	#1, ER1
		INC.B	R0H
		BSET	R0H, @ER1
		DEC.B	R0H

		INC.L	#1, ER1
		BSET	R0H, @ER1
		INC.B	R0H
		BSET	R0H, @ER1
VRAM_SET_3SEQ_E:
		POP.W	R2
		POP.L	ER1
		POP.W	R0
		RTS

;----------------------------------------------------
;	VRAMへページ幅イメージを重ね合わせ　縦8バイト、横は引数
;	WRAP処理しないので注意
;	IN	R1:VRAMアドレス
;		R2:IMAGEデータアドレス
;		R0L:イメージの横の長さ（PIXEL）
;	BREAK	R0L,R1,R2
;----------------------------------------------------
VRAM_BAND_IMG:	PUSH.W	R1
		PUSH.W	R2
		PUSH.W	R3
VRAM_BAND_IMG_L1:
		MOV.B	@R1, R3L
		MOV.B	@R2+, R3H
		OR.B	R3H, R3L
		MOV.B	R3L, @R1
		INC.W	#1,R1
		DEC.B	R0L
		BNE	VRAM_BAND_IMG_L1
		POP.W	R3
		POP.W	R2
		POP.W	R1
		RTS

;-------------------------------------------------
;	VRAMへ半角数字を重ね合わせ（CS1,CS2はK桁で判断）
;	WRAP処理しないので注意
;	IN	R0L:数字(0..F)
;		R1:(R1L/X:0-15,R1H/Y:0-7)
;-------------------------------------------------
VRAM_NUM:	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2

		MOV.W	#VRAM_X00Y00, R2
		BTST	#3, R1L
		BEQ	VRAM_NUM_L0
		MOV.W	#VRAM_X64Y00, R2
		AND.B	#7, R1L
VRAM_NUM_L0:
		PUSH.W	R1
		MOV.B	#0, R1L
		SHLR.W	R1
		SHLR.W	R1			; Y*64 (R1H >> 2)
		ADD.W	R1, R2			; R2 = VRAM_START + Y行*64
		POP.W	R1
		MOV.B	#0, R1H
		SHAL.W	R1
		SHAL.W	R1
		SHAL.W	R1
		ADD.W	R2, R1			; R1 = Y行*64 + X桁*8
		MOV.W	R0, R2
		AND.W	#H'0F, R2
		SHAL.W	R2
		SHAL.W	R2
		SHAL.W	R2
		ADD.W	#char_0, R2		; IMAGE DATA ADDRESS
		MOV.B	#8, R0L			; SIZE
		JSR	@VRAM_BAND_IMG

		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	VRAMへ半角文字を重ね合わせ（CS1,CS2はK桁で判断）
;	WRAP処理しないので注意
;	IN	R0L:文字
;		R1:(R1L/X:0-15,R1H/Y:0-7)
;-------------------------------------------------
VRAM_CHAR:	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2

		MOV.W	#VRAM_X00Y00, R2
		BTST	#3, R1L
		BEQ	VRAM_CHAR_L0
		MOV.W	#VRAM_X64Y00, R2
		AND.B	#7, R1L
VRAM_CHAR_L0:
		PUSH.W	R1
		MOV.B	#0, R1L
		SHLR.W	R1
		SHLR.W	R1			; Y*64 (R1H >> 2)
		ADD.W	R1, R2			; R2 = VRAM_START + Y行*64
		POP.W	R1
		MOV.B	#0, R1H
		SHAL.W	R1
		SHAL.W	R1
		SHAL.W	R1
		ADD.W	R2, R1			; R1 += X桁*8
		MOV.W	R0, R2			; 文字
		MOV.B	#0, R2H
		SUB.W	#H'20, R2
		SHAL.W	R2
		SHAL.W	R2
		SHAL.W	R2
		ADD.W	#char_SP, R2		; IMAGE DATA ADDRESS
		MOV.B	#8, R0L			; SIZE
		JSR	@VRAM_BAND_IMG

		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	VRAMへ半角文字列を重ね合わせ（CS1,CS2はK桁で判断）
;	WRAP処理しないので注意
;	IN	R0:文字列のポインタ。終端は、\0
;		R1:(R1L/X:0-15,R1H/Y:0-7)
;-------------------------------------------------
VRAM_STRING:	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2
		PUSH.W	R3

		MOV.W	R0, R3
		MOV.W	#VRAM_X00Y00, R2
		BTST	#3, R1L
		BEQ	VRAM_STRING_L0
		MOV.W	#VRAM_X64Y00, R2
		AND.B	#7, R1L
VRAM_STRING_L0:
		PUSH.W	R1
		MOV.B	#0, R1L
		SHLR.W	R1
		SHLR.W	R1			; Y*64 (R1H >> 2)
		ADD.W	R1, R2			; R2 = VRAM_START + Y行*64
		POP.W	R1
		MOV.B	#0, R1H
		SHAL.W	R1
		SHAL.W	R1
		SHAL.W	R1
		ADD.W	R2, R1			; R1 += X桁*8

VRAM_STRING_L1:	MOV.B	@R3+, R2L
		BEQ	VRAM_STRING_E
		MOV.B	#0, R2H
		SUB.W	#H'20, R2
		SHAL.W	R2
		SHAL.W	R2
		SHAL.W	R2
		ADD.W	#char_SP, R2		; IMAGE DATA ADDRESS
		MOV.B	#8, R0L			; SIZE
		JSR	@VRAM_BAND_IMG
		ADD.W	#8, R1
		JMP	@VRAM_STRING_L1

VRAM_STRING_E:	POP.W	R3
		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	VRAMへ半角文字を重ね合わせ（CS1,CS2はK桁で判断）
;	WRAP処理しないので注意
;	IN	R0:文字データアドレス
;		R1:(R1L/X:0-15,R1H/Y:0-7)
;-------------------------------------------------
VRAM_CH_IMAGE:	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2
		MOV.W	R0,R2
		MOV.W	#VRAM_X00Y00, R0
		BTST	#3, R1L
		BEQ	VRAM_CH_IMAGE_L0
		MOV.W	#VRAM_X64Y00, R0
VRAM_CH_IMAGE_L0:					; R0 = VRAM_START
		PUSH.W	R1
		MOV.B	#0, R1L
		SHLR.W	R1			; Y=256/2
		SHLR.W	R1			; Y=256/4
		ADD.W	R1, R0			; R0 = VRAM_START + Y行*64
		POP.W	R1
		AND.W	#7, R1
		SHAL.W	R1
		SHAL.W	R1
		SHAL.W	R1
		ADD.W	R0, R1			; R1 += X桁*8
		MOV.B	#8, R0L			; 文字データのサイズ
		JSR	@VRAM_BAND_IMG

		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	VRAMへ16進を重ね合わせ（CS1,CS2はK桁で判断）
;	WRAP処理しないので注意
;	IN	R0L
;		R1:(R1L/X:0-14,R1H/Y:0-7)
;-------------------------------------------------
VRAM_HEXDATA	PUSH.W	R0
		JSR	@HEX2ASCII
		PUSH.W	R0
		MOV.B	R0H, R0L
		BSR	VRAM_CHAR
		POP.W	R0
		INC.B	R0L
		BSR	VRAM_CHAR
		POP.W	R0
		RTS

;-------------------------------------------------
;	VRAMへ10進2桁を重ね合わせ。符号なし。最上位桁スペース
;	WRAP処理しないので注意（CS1,CS2はK桁で判断）
;	IN	R0L : 値
;		R1  : R1L/X:0-14,R1H/Y:0-7
;-------------------------------------------------
VRAM_DEC_B	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2
		MOV.B	#10, R2L
		MOV.B	#0, R0H
		DIVXU.B	R2L, R0
		PUSH.W	R0
		MOV.B	#0, R0H
		DIVXU.B	R2L, R0

		MOV.B	R0L, R2L		; 上位桁チェック用
		CMP.B	#H'0, R0L		; 上位０か？
		BEQ	VRAM_DEC_B_L1
		JSR	@VRAM_NUM
		JMP	@VRAM_DEC_B_L2
VRAM_DEC_B_L1:	MOV.B	#H'20, R0L
		JSR	@VRAM_CHAR
VRAM_DEC_B_L2:	INC.B	R1L
		MOV.B	R0H, R0L
		OR.B	R0L, R2L		; 上位桁チェック用 ORを取ることで、０以外かを確認
		CMP.B	#H'0, R2L
		BEQ	VRAM_DEC_B_L3
		JSR	@LCD_NUM
		JMP	@VRAM_DEC_B_L4
VRAM_DEC_B_L3:	MOV.B	#H'20, R0L
		JSR	@VRAM_CHAR
VRAM_DEC_B_L4:	INC.B	R1L
		POP.W	R0
		MOV.B	R0H, R0L
		JSR	@LCD_NUM

		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	VRAMへ10進2桁を重ね合わせ。符号あり(+はスペース)
;	WRAP処理しないので注意（CS1,CS2はK桁で判断）
;	IN	R0L : 値
;		R0H : R0Hが0以外は小数点あり
;		R1:(R0L/X:0-14,R0H/Y:0-7)
;-------------------------------------------------
VRAM_DEC_B_S	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2
		BTST	#7,R0L
		BNE	VRAM_DEC_B_MINUS
		JMP	@VRAM_DEC_B_U
VRAM_DEC_B_MINUS:
		PUSH.W	R0
		MOV.W	#char_hyrhen,R0
		JSR	@VRAM_CH_IMAGE
		INC.B	R0L
		POP.W	R0
		NEG.B	R0L
VRAM_DEC_B_U:
		MOV.B	R0H, R2H		;小数点フラグ
		MOV.B	#0, R0H
		MOV.B	#10, R2L
		DIVXU.B	R2L, R0
		PUSH.W	R0		; R0H LOWEST
		MOV.B	#0, R0H
		DIVXU.B	R2L, R0
		MOV.B	R0H, R0L
		JSR	@VRAM_NUM
		INC.B	R0L
		CMP.B	#0, R2H
		BEQ	VRAM_DEC_B_U1
		MOV.W	#char_period,R0
		JSR	@VRAM_CH_IMAGE
		INC.B	R0L
VRAM_DEC_B_U1:
		POP.W	R0
		MOV.B	R0H, R0L
		JSR	@VRAM_NUM

		POP.W	R1
		POP.W	R0
		RTS

;=================================================
;	LCD制御
;-------------------------------------------------
;	初期化処理 for SG12864
;-------------------------------------------------
LCD_INIT	PUSH.W	R0
		MOV.W	#30, R0
		JSR	@TIME_N
		NOP
		BCLR	LCD_RST
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		BSET	LCD_RST
		JSR	@TIME00
		NOP
		BSET	LCD_CS1
		NOP
		BSET	LCD_CS2
		NOP
		MOV.B	#H'C0, R0L
		JSR	@LCD_SET_CTRL
		NOP
		MOV.B	#H'3F, R0L
		JSR	@LCD_SET_CTRL

		POP.W	R0
		RTS

;-------------------------------------------------
;	BUSYチェック
;-------------------------------------------------
CHK_LCD_BUSY:	PUSH.W	R0
		MOV.B	#0, R0L			; P8*を入力に変更
		MOV.B	R0L,@PCR8
CHK_LCD_BUSY_l1:
		BCLR	LCD_DI			; 制御フラグ
		NOP
		BSET	LCD_RW			; 読み込み
		NOP				; 140ns必要　（NOP=100ns）
		NOP
		BSET	LCD_E			; LCDのTwh=450ns
		NOP
		NOP
		NOP
		NOP
		NOP
		BCLR	LCD_E			; シグナル
		NOP
		NOP
		NOP
		MOV.B	@PDR8, R0L		; データ読み込み
		BTST	#7, R0L			; BUSY CHECK
		BNE	CHK_LCD_BUSY_l1
		BTST	#4, R0L			; RESET CHECK
		BNE	CHK_LCD_BUSY_l1

		MOV.B	#H'FF, R0L		; P8*を出力に変更
		MOV.B	R0L,@PCR8
		POP.W	R0
		RTS

;-------------------------------------------------
;	CMD 書き込み
;-------------------------------------------------
LCD_SET_CTRL:	BSR	CHK_LCD_BUSY
		MOV.B	R0L,@PDR8		; 制御出力
		BCLR	LCD_DI			; 制御フラグ
		NOP
		BCLR	LCD_RW			; 書き込み
		NOP				; 140ns必要　（NOP=100ns）
		NOP
		BSET	LCD_E			; LCDのTwh=450ns
		NOP
		NOP
		NOP
		NOP
		NOP
		BCLR	LCD_E			; シグナル
		RTS

;-------------------------------------------------
;	データ書き込み
;-------------------------------------------------
LCD_SET_DATA:	BSR	CHK_LCD_BUSY
		MOV.B	R0L,@PDR8		; データ出力
		BSET	LCD_DI			; データフラグ (CTRLと違うので注意)
		NOP
		BCLR	LCD_RW			; 書き込み
		NOP				; 140ns必要　（NOP=100ns）
		NOP
		BSET	LCD_E			; LCDのTwh=450ns
		NOP
		NOP
		NOP
		NOP
		NOP
		BCLR	LCD_E			; シグナル
		RTS

;-------------------------------------------------
;	TOP MENU
;-------------------------------------------------
TOP_MENU:	PUSH.W	R0

		JSR	@LCD_CLR_CS1
		JSR	@LCD_CLR_CS2

		BSET	LCD_CS1
		NOP
		BCLR	LCD_CS2
		NOP
		MOV.W	#hayabua_1,R1
		JSR	@LCD_BITMAP

		MOV.W	#H'0108, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#TITL_MSG_L0, R0
		JSR	@LCD_STRING
		MOV.W	#H'0308, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#TITL_MSG_L1, R0
		JSR	@LCD_STRING
		MOV.W	#H'0508, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#TITL_MSG_L2, R0
		JSR	@LCD_STRING

		POP.W	R0
		RTS

TITL_MSG_L0	.SDATA		"GSX1300R"
		.DATA.B		0
TITL_MSG_L1	.SDATA		"PCII-GUI"
		.DATA.B		0
TITL_MSG_L2	.SDATA		"  V0.30"
		.DATA.B		0
		.ALIGN	2

;-------------------------------------------------
;	PCIIモニタ画面(CS2側)の表示
;-------------------------------------------------
LCD_PCII_MON:
		PUSH.W	R0
		JSR	@VRAM_PCII_CS2
		MOV.W	@M_REV, R0
		JSR	@VRAM_RPM_CS2
		MOV.B	@M_TP, R0L
		JSR	@VRAM_HCIR100_CS2
		JSR	@VRAM_TO_LCD_CS2

		MOV.W	#H'050C, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.B	@M_TP, R0L
		JSR	@LCD_DEC_B

		POP.W	R0
		RTS

;-------------------------------------------------
;	Gモニタ画面(CS1側)の表示
;-------------------------------------------------
LCD_G_MON:
		PUSH.W	R0
		JSR	@VRAM_XY_CS1
		JSR	@GET_G_XY
		ADD.B	#32,R0H
		ADD.B	#32,R0L
		JSR	@VRAM_SET_3SEQ
		JSR	@VRAM_TO_LCD_CS1
		POP.W	R0
		RTS

;-------------------------------------------------
;	Gの軌跡を画面(CS2側)に表示
;-------------------------------------------------
LCD_G_TRACK_CS2:
		PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2
		PUSH.W	R3
		JSR	@VRAM_X_CS2

		MOV.B	#64, R0L			; 横軸分
		MOV.W	#OFFSET_AX_LOG,R2
		MOV.W	#OFFSET_AY_LOG,R3
		MOV.B	@R2, R1H
		ADD.B	#32, R1H		; 横軸の真ん中を基準
		MOV.B	@R3, R1L
		ADD.B	#32, R1L		; 横軸の真ん中を基準
LCD_G_TRACK_CS2_PLOT_G;
		MOV.B	@R2+, R0H
		ADD.B	#32, R0H		; 横軸の真ん中を基準
		JSR	@VRAM_SET_VLINE
		MOV.B	R1L, R1H
		MOV.B	R0H, R1L

		MOV.B	@R3+, R0H
		ADD.B	#32, R0H		; 横軸の真ん中を基準
		JSR	@VRAM_SET_VLINE
		MOV.B	R1L, R1H
		MOV.B	R0H, R1L

		INC.B	R0L
		CMP.B	#128, R0L
		BNE	LCD_G_TRACK_CS2_PLOT_G

		MOV.W	#G_ACC_MSG, R0
		MOV.W	#H'000A, R1
		JSR	@VRAM_STRING
		JSR	@VRAM_TO_LCD_CS2
		POP.W	R3
		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

G_ACC_MSG		.SDATA	"G-MON"
			.DATA.B	0
		.ALIGN	2


;-------------------------------------------------
;	SUSの軌跡を画面に表示(CS1, CS2合わせた横軸)
;-------------------------------------------------
LCD_SUS_TRACK:
		PUSH.W	R0
		PUSH.W	R1
		PUSH.L	ER2
		PUSH.L	ER3
		MOV.B	@SUS_LOG_STATE, R0L
		BNE	LCD_G_TRACK_CS1_PLOT_L1		; データ変更なし
		JMP	@LCD_SUS_TRACK_E		; データ変更なし
LCD_G_TRACK_CS1_PLOT_L1:
		JSR	@VRAM_X_CS1
;		JSR	@VRAM_X_CS2
		MOV.B	#0, R0L				; 横軸分
		MOV.L	#SUS_LOG,ER3
		MOV.B	@ER3, R2L			; 下位８バイト
		ADD.L	#2, ER3
		MOV.B	@ER3, R2H
		AND.B	#H'0F, R2H			; 上位８バイト
		ADD.L	#1, ER3				; 次のデータ
		ADD.W	#32, R2				; 横軸の左側真ん中を基準
		MOV.B	R2L, R1H
LCD_G_TRACK_CS1_PLOT_G:
		MOV.B	@ER3, R2L			; 下位８バイト
		ADD.L	#2, ER3
		MOV.B	@ER3, R2H
		AND.B	#H'0F, R2H			; 上位８バイト
		ADD.L	#1, ER3				; 次のデータ
		ADD.W	#32, R2				; 横軸の左側真ん中を基準
		MOV.B	R2L, R0H
		JSR	@VRAM_SET_VLINE			; 縦線（<R0L, R0H>-<R0L, R1H>）
		MOV.B	R2L, R1H
		INC.B	R0L
		CMP.B	#64, R0L
		BNE	LCD_G_TRACK_CS1_PLOT_G

		MOV.W	#SUS1_MSG, R0
		MOV.W	#H'0, R1
		JSR	@VRAM_STRING
		JSR	@VRAM_TO_LCD_CS1

		MOV.W	#H'0008, R1
		MOV.W	#SUS1_MSG, R0
		JSR	@VRAM_STRING
		MOV.W	#H'0108, R1
		MOV.W	#SUS_MIN_MSG, R0
		JSR	@VRAM_STRING
		MOV.W	#H'0208, R1
		MOV.W	#SUS_MAX_MSG, R0
		JSR	@VRAM_STRING
		JSR	@VRAM_TO_LCD_CS2

		MOV.W	#H'000C, R0
		JSR	@LCD_TEXT_OFFSET
		JSR	@VL53L0X_SUS_MM
		MOV.W	E1, R0
		JSR	@LCD_DEC_0000

		MOV.W	#H'010C, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	E2, R0
		JSR	@LCD_DEC_0000
		
		MOV.W	#H'020C, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	R2, R0
		JSR	@LCD_DEC_0000

;;;		MOV.W	#SUS2_MSG, R0
;;;		MOV.W	#H'000A, R1
;;;		JSR	@VRAM_STRING
;;;		JSR	@VRAM_TO_LCD_CS2
LCD_SUS_TRACK_E:
		POP.L	ER3
		POP.L	ER2
		POP.W	R1
		POP.W	R0
		RTS

SUS1_MSG		.SDATA	"S-F "
			.DATA.B	0
		.ALIGN	2
SUS2_MSG		.SDATA	"S-R "
			.DATA.B	0
		.ALIGN	2
SUS_MIN_MSG		.SDATA	"max:"
			.DATA.B	0
		.ALIGN	2
SUS_MAX_MSG		.SDATA	"min:"
			.DATA.B	0
		.ALIGN	2



;-------------------------------------------------
;	RPMの円上にプロット
;	IN	R0= RPM
;-------------------------------------------------
VRAM_RPM_CS2:	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2
		PUSH.W	R3

		MOV.W	#rpm_deg_ad, R1
		MOV.W	R0, R2
VRAM_RPM_CS2_L1:
		SUB.W	#1000, R2
		BCS	VRAM_RPM_CS2_SEARCH
		ADD.W	#2, R1
		CMP.W	#rpm_deg, R1
		BNE	VRAM_RPM_CS2_L1
		SUB.W	#2, R1
VRAM_RPM_CS2_SEARCH:
		MOV.W	@R1, R2			; アドレス取得
		MOV.W	R2, R1
VRAM_RPM_CS2_SEARCH2:
		MOV.W	@R1, R2			; 実際の値
		ADD.W	#4, R1
		CMP.W	R2, R0
		BCC	VRAM_RPM_CS2_SEARCH2
		SUB.W	#2, R1			; Iつ戻す
		MOV.B	@R1+, R2L		; R2L = X (-100..100)
		MOV.B	@R1, R2H		; R2H = Y (-100..100)
		SHAR.B	R2L
		SHAR.B	R2L			; X (-25..25)
		SHAR.B	R2H
		SHAR.B	R2H			; Y (-25..25)
		ADD.B	#32,R2L			; X (7..57)
		ADD.B	#64,R2L			; CS2領域（右画面）
		ADD.B	#32,R2H			; Y (7..57)
		MOV.W	R2, R0
		JSR	@VRAM_SET_3SEQ

		POP.W	R3
		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

VRAM_STR_RPM_CS2
		MOV.W	#VRAM_X64Y32, R1
		ADD.W	#22, R1
		MOV.W	#str_RPM, R2
		MOV.B	#19, R0L
		JSR	@VRAM_BAND_IMG
		RTS

VRAM_STR_TP_CS2
		MOV.W	#VRAM_X64Y40, R1
		ADD.W	#14, R1
		MOV.W	#str_TP, R2
		MOV.B	#12, R0L
		JSR	@VRAM_BAND_IMG
		RTS

;-------------------------------------------------
;	100％を半円上にプロット
;	IN	R0L= ％
;-------------------------------------------------
VRAM_HCIR100_CS2:
		PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2

		MOV.W	#deg_100, R1
		MOV.B	#0, R0H
		ADD.W	R0, R1
		ADD.W	R0, R1
		MOV.B	@R1+, R2L		; R2L = X (-100..100)
		MOV.B	@R1, R2H		; R2H = Y (-100..100)
		SHAR.B	R2L
		SHAR.B	R2L			; X (-25..25)
		SHAR.B	R2L			; X (-12.5..12.5)
		SHAR.B	R2H
		SHAR.B	R2H			; Y (-25..25)
		SHAR.B	R2H			; Y (-12.5..12.5)
		MOV.W	R2, R0
		SHAR.B	R2L
		SHAR.B	R2L
		SHAR.B	R2H
		SHAR.B	R2H
		ADD.W	R2, R0
		ADD.B	#32,R0L			; X (7..57)
		ADD.B	#64,R0L			; CS2領域（右画面）
		ADD.B	#32,R0H			; Y (7..57)
		JSR	@VRAM_SET_3SEQ

		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	マルチモニタ画面の表示
;-------------------------------------------------
LCD_MULTI_MON:
		PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2

		JSR	@VRAM_CLR
		MOV.B	#2,R0L
		JSR	@VRAM_X_3L		; RPM /TP用
		MOV.B	#5,R0L
		JSR	@VRAM_X_3L		; 加速度センサ用

;;;;;;		JSR	@DISP_MULTI_PCII

		MOV.B	#0, R0L			; 横軸分
		MOV.W	#OFFSET_AX_LOG,R2
		MOV.B	@R2, R1H
		SHAR.B	R1H			; 符号付処理！
		SHAR.B	R1H			; /4
		ADD.B	#52, R1H		; 横軸の真ん中を基準
LCD_MULTI_MON_PLOT_X;
		MOV.B	@R2+, R0H
		SHAR.B	R0H			; 符号付処理！
		SHAR.B	R0H			; /4
		ADD.B	#52, R0H		; PAGE6の真ん中を基準
		JSR	@VRAM_SET_VLINE
		MOV.B	R0H, R1H

		INC.B	R0L
		CMP.B	#64, R0L
		BNE	LCD_MULTI_MON_PLOT_X

		MOV.W	#OFFSET_AY_LOG,R2
		MOV.B	@R2, R1H
		SHAR.B	R1H			; 符号付処理！
		SHAR.B	R1H			; /4
		ADD.B	#52, R1H		; 横軸の真ん中を基準
LCD_MULTI_MON_PLOT_Y;
		MOV.B	@R2+, R0H
		SHAR.B	R0H			; 符号付処理！
		SHAR.B	R0H			; /4
		ADD.B	#52, R0H		; PAGE6の真ん中を基準
		JSR	@VRAM_SET_VLINE
		MOV.B	R0H, R1H

		INC.B	R0L
		CMP.B	#128, R0L
		BNE	LCD_MULTI_MON_PLOT_Y

		MOV.W	#H'283F, R0
		MOV.B	#H'3F, R1H
		JSR	@VRAM_SET_VLINE

		MOV.B	#2, R0L
		JSR	@VRAM_TO_LCD_PAGE_CS1_CS2
		MOV.B	#3, R0L
		JSR	@VRAM_TO_LCD_PAGE_CS1_CS2
		MOV.B	#4, R0L
		JSR	@VRAM_TO_LCD_PAGE_CS1_CS2
		MOV.B	#5, R0L
		JSR	@VRAM_TO_LCD_PAGE_CS1_CS2
		MOV.B	#6, R0L
		JSR	@VRAM_TO_LCD_PAGE_CS1_CS2
		MOV.B	#7, R0L
		JSR	@VRAM_TO_LCD_PAGE_CS1_CS2
		
		JSR	@DISP_MULTI_TIME		; PCII_LAP.ASM

		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	I2C MEMORY MANAGEMENT MENU
;-------------------------------------------------
LCD_EEPROM_MEM_INFO:
		PUSH.W	R0
		JSR	@LCD_CLR_CS1
		JSR	@LCD_CLR_CS2
		MOV.W	#H'0000, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_VIEW_MSG_L0, R0
		JSR	@LCD_STRING
		MOV.W	#H'0008, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_VIEW_MSG_R0, R0
		JSR	@LCD_STRING

		MOV.W	#H'0200, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_VIEW_MSG_L2, R0
		JSR	@LCD_STRING
		MOV.W	#H'0208, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_VIEW_MSG_R2, R0
		JSR	@LCD_STRING
		MOV.W	#H'0300, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_VIEW_INFO_L3, R0
		JSR	@LCD_STRING
		MOV.W	#H'0400, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_VIEW_INFO_L4, R0
		JSR	@LCD_STRING
		MOV.W	#H'0500, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_VIEW_INFO_L5, R0
		JSR	@LCD_STRING
		MOV.W	#H'0600, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_VIEW_INFO_L6, R0
		JSR	@LCD_STRING
		MOV.W	#H'0700, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_VIEW_INFO_L7, R0
		JSR	@LCD_STRING

		MOV.W	#H'0308, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	@MODE1_PAGE_COUNT, R0
		MOV.B	R0H, R0L
		JSR	@LCD_HEXDATA
		MOV.W	@MODE1_PAGE_COUNT, R0
		JSR	@LCD_HEXDATA

		MOV.W	#H'0408, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	@MODE2_PAGE_COUNT, R0
		MOV.B	R0H, R0L
		JSR	@LCD_HEXDATA
		MOV.W	@MODE2_PAGE_COUNT, R0
		JSR	@LCD_HEXDATA

		MOV.W	#H'0508, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	@MODE3_PAGE_COUNT, R0
		MOV.B	R0H, R0L
		JSR	@LCD_HEXDATA
		MOV.W	@MODE3_PAGE_COUNT, R0
		JSR	@LCD_HEXDATA

		MOV.W	#H'0608, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	@MODE4_PAGE_COUNT, R0
		MOV.B	R0H, R0L
		JSR	@LCD_HEXDATA
		MOV.W	@MODE4_PAGE_COUNT, R0
		JSR	@LCD_HEXDATA

		MOV.W	#H'0708, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	@NULL_PAGE_COUNT, R0
		MOV.B	R0H, R0L
		JSR	@LCD_HEXDATA
		MOV.W	@NULL_PAGE_COUNT, R0
		JSR	@LCD_HEXDATA

		POP.W	R0
		RTS

LCD_I2C_FORMAT_MENU:
		PUSH.W	R0
		BSET	LCD_CS1
		NOP
		BSET	LCD_CS2
		MOV.B	#3,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#4,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#5,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#6,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#7,R0L
		JSR	@LCD_CLR_PAGE

		MOV.W	#H'0200, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_VIEW_MSG_L2, R0
		JSR	@LCD_STRING
		MOV.W	#H'0208, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_FORMAT_MSG_R2, R0
		JSR	@LCD_STRING

		POP.W	R0
		RTS

LCD_I2C_FORMAT_CONFIRM:
		PUSH.W	R0
		MOV.W	#H'0400, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_FORMAT_CONFIRM_L4, R0
		JSR	@LCD_STRING
		MOV.W	#H'0408, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_FORMAT_CONFIRM_R4, R0
		JSR	@LCD_STRING
		POP.W	R0
		RTS

LCD_I2C_FORMAT_DOING:
		PUSH.W	R0
		MOV.W	#H'0408, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_FORMAT_ING_R4, R0
		JSR	@LCD_STRING
		POP.W	R0
		RTS

LCD_I2C_FORMAT_DONE:
		PUSH.W	R0
		MOV.W	#H'0408, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#I2C_FORMAT_DONE_R4, R0
		JSR	@LCD_STRING
		POP.W	R0
		RTS

I2C_VIEW_MSG_L0		.SDATA		"I2C-MEMO"
			.DATA.B		0
I2C_VIEW_MSG_R0		.SDATA		"RY MENU"
			.DATA.B		0
I2C_VIEW_MSG_L2		.SDATA		"<MEMORY "
			.DATA.B		0
I2C_VIEW_MSG_R2		.SDATA		"INFO.>  "
			.DATA.B		0
I2C_VIEW_INFO_L3	.SDATA		"  PC2."
			.DATA.B		0
I2C_VIEW_INFO_L4	.SDATA		"  GSR."
			.DATA.B		0
I2C_VIEW_INFO_L5	.SDATA		"  LAP."
			.DATA.B		0
I2C_VIEW_INFO_L6	.SDATA		"  MIX."
			.DATA.B		0
I2C_VIEW_INFO_L7	.SDATA		"  ---."
			.DATA.B		0
I2C_FORMAT_MSG_R2	.SDATA		"FORMAT.>"
			.DATA.B		0
I2C_FORMAT_CONFIRM_L4	.SDATA		" FORMAT "
			.DATA.B		0
I2C_FORMAT_CONFIRM_R4	.SDATA		" <OK?>  "
			.DATA.B		0
I2C_FORMAT_ING_R4	.SDATA		"........"
			.DATA.B		0
I2C_FORMAT_DONE_R4	.SDATA		"FINISHED"
			.DATA.B		0
		.ALIGN	2


;-------------------------------------------------
;	PCIIデータのCS1側への表示
;-------------------------------------------------
LCD_PCII_DATA_CS1_INIT:
		PUSH.W	R0
		MOV.W	#H'00, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#PCII_DATA_MSG0, R0
		JSR	@LCD_STRING

		MOV.W	#H'0200, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#str_RPM, R1
		MOV.B	#17, R0L
		JSR	@LCD_BAND_IMG

		MOV.W	#H'0300, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#str_TP, R1
		MOV.B	#12, R0L
		JSR	@LCD_BAND_IMG

		MOV.W	#H'0400, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#str_TPd, R1
		MOV.B	#17, R0L
		JSR	@LCD_BAND_IMG

		MOV.W	#H'0500, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#str_MP, R1
		MOV.B	#13, R0L
		JSR	@LCD_BAND_IMG

		MOV.W	#H'0600, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#str_AAP, R1
		MOV.B	#17, R0L
		JSR	@LCD_BAND_IMG

		POP.W	R0
		RTS

LCD_PCII_DATA_CS1:
		PUSH.W	R0
		MOV.W	#H'0203, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	@M_REV, R0
		JSR	@LCD_DEC_W

		MOV.W	#H'0303, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.B	@M_TP, R0L
		JSR	@LCD_DEC_B

		MOV.W	#H'0403, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.B	#0, R0H			; 小数点フラグ
		MOV.B	@M_TPo, R0L
		JSR	@LCD_DEC_B_S

		MOV.W	#H'0503, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.B	#1, R0H			; 小数点フラグ
		MOV.B	@M_MP, R0L
		JSR	@LCD_DEC_B_S

		MOV.W	#H'0603, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.B	#0, R0H			; 小数点フラグ
		MOV.B	@M_AAP, R0L
		JSR	@LCD_DEC_B_S

		POP.W	R0
		RTS

PCII_DATA_MSG0	.SDATA		"PC2-MON"
		.DATA.B		0
		.ALIGN	2

;-------------------------------------------------
;	SG12864 へ表示
;-------------------------------------------------
;	SG12864 へ指定画像表示. 画面は指定しておく。
;	IN	R1:画像のアドレス：8x64バイト
;-------------------------------------------------
LCD_BITMAP:	MOV.B	#H'C0, R0L
		JSR	@LCD_SET_CTRL
		NOP
		PUSH.W	R1
		MOV.B	#0,R0L
		JSR	@LCD_SHOW_PAGE
		POP.W	R1
		ADD.W	#64, R1
		PUSH.W	R1
		MOV.B	#1,R0L
		JSR	@LCD_SHOW_PAGE
		POP.W	R1
		ADD.W	#64, R1
		PUSH.W	R1
		MOV.B	#2,R0L
		JSR	@LCD_SHOW_PAGE
		POP.W	R1
		ADD.W	#64, R1
		PUSH.W	R1
		MOV.B	#3,R0L
		JSR	@LCD_SHOW_PAGE
		POP.W	R1
		ADD.W	#64, R1
		PUSH.W	R1
		MOV.B	#4,R0L
		JSR	@LCD_SHOW_PAGE
		POP.W	R1
		ADD.W	#64, R1
		PUSH.W	R1
		MOV.B	#5,R0L
		JSR	@LCD_SHOW_PAGE
		POP.W	R1
		ADD.W	#64, R1
		PUSH.W	R1
		MOV.B	#6,R0L
		JSR	@LCD_SHOW_PAGE
		POP.W	R1
		ADD.W	#64, R1
		PUSH.W	R1
		MOV.B	#7,R0L
		JSR	@LCD_SHOW_PAGE
		POP.W	R1
		RTS

;-------------------------------------------------
;	SG12864のCS1へVRAMデータ転送。
;-------------------------------------------------
VRAM_TO_LCD_CS1	PUSH.W	R1
		BSET	LCD_CS1
		BCLR	LCD_CS2
		MOV.B	#H'C0, R0L
		JSR	@LCD_SET_CTRL
		NOP
		MOV.W	#VRAM_X00Y00, R1
		MOV.B	#0,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X00Y08, R1
		MOV.B	#1,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X00Y16, R1
		MOV.B	#2,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X00Y24, R1
		MOV.B	#3,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X00Y32, R1
		MOV.B	#4,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X00Y40, R1
		MOV.B	#5,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X00Y48, R1
		MOV.B	#6,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X00Y56, R1
		MOV.B	#7,R0L
		JSR	@LCD_SHOW_PAGE
		POP.W	R1
		RTS

;-------------------------------------------------
;	SG12864のCS2へVRAMデータ転送。
;-------------------------------------------------
VRAM_TO_LCD_CS2	PUSH.W	R1
		BCLR	LCD_CS1
		BSET	LCD_CS2
		MOV.B	#H'C0, R0L
		JSR	@LCD_SET_CTRL
		NOP
		MOV.W	#VRAM_X64Y00, R1
		MOV.B	#0,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X64Y08, R1
		MOV.B	#1,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X64Y16, R1
		MOV.B	#2,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X64Y24, R1
		MOV.B	#3,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X64Y32, R1
		MOV.B	#4,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X64Y40, R1
		MOV.B	#5,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X64Y48, R1
		MOV.B	#6,R0L
		JSR	@LCD_SHOW_PAGE
		MOV.W	#VRAM_X64Y56, R1
		MOV.B	#7,R0L
		JSR	@LCD_SHOW_PAGE
		POP.W	R1
		RTS

;-------------------------------------------------
;	SG12864のCS1,2へVRAMデータをページごとに転送。
;	IN	R0L:ページ 0..7
;-------------------------------------------------
VRAM_TO_LCD_PAGE_CS1_CS2:
		PUSH.W	R1
		PUSH.W	R2
		PUSH.W	R0
		MOV.W	#VRAM_X00Y00, R1
		MOV.W	#VRAM_X64Y00, R2
		MOV.B	R0L, R0H			; X256
		MOV.B	#0,R0L
		SHLR.W	R0				; X128
		SHLR.W	R0				; X 64
		ADD.W	R0, R1
		ADD.W	R0, R2
		BSET	LCD_CS1
		BCLR	LCD_CS2
		POP.W	R0
		JSR	@LCD_SHOW_PAGE
		BCLR	LCD_CS1
		BSET	LCD_CS2
		MOV.W	R2, R1
		JSR	@LCD_SHOW_PAGE
		POP.W	R2
		POP.W	R1
		RTS

;-------------------------------------------------
;	SG12864のCS1をクリア
;-------------------------------------------------
LCD_CLR_CS1	PUSH.W	R0
		PUSH.W	R1
		BSET	LCD_CS1
		NOP
		BCLR	LCD_CS2
;;;		MOV.B	#H'C0, R0L
;;;		JSR	@LCD_SET_CTRL
		NOP
		MOV.B	#0,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#1,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#2,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#3,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#4,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#5,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#6,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#7,R0L
		JSR	@LCD_CLR_PAGE
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	SG12864のCS2をクリア
;-------------------------------------------------
LCD_CLR_CS2	PUSH.W	R0
		PUSH.W	R1
		BCLR	LCD_CS1
		NOP
		BSET	LCD_CS2
		MOV.B	#H'C0, R0L
		JSR	@LCD_SET_CTRL
		NOP
		MOV.B	#0,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#129,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#2,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#3,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#4,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#5,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#6,R0L
		JSR	@LCD_CLR_PAGE
		MOV.B	#7,R0L
		JSR	@LCD_CLR_PAGE
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	SG12864 の一ページ表示（csはセットされていること）
;	IN	R0L:ページ 0..7
;		R1 :イメージデータアドレス
;-------------------------------------------------
LCD_SHOW_PAGE	PUSH.W	R0
		PUSH.W	R1
		AND.B	#H'07, R0L
		OR.B	#H'B8, R0L
		JSR	@LCD_SET_CTRL		; SET PAGE ADDRESS
		MOV.B	#H'40, R0L		; SET ADDRESS
		JSR	@LCD_SET_CTRL
		MOV.B	#H'40, R0H		; 64bytes/PAGE

LCD_SHOW_PAGE_L1:
		MOV.B	@R1+, R0L
		JSR	@LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_SHOW_PAGE_L1
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	SG12864 の一ページクリア（csはセットされていること）
;	IN	R0L:ページ 0..7
;-------------------------------------------------
LCD_CLR_PAGE	PUSH.W	R0
		AND.B	#H'07, R0L
		OR.B	#H'B8, R0L
		JSR	@LCD_SET_CTRL		; SET PAGE ADDRESS
		MOV.B	#H'40, R0L		; SET ADDRESS
		JSR	@LCD_SET_CTRL
		MOV.B	#H'40, R0H		; 64bytes/PAGE

LCD_CLR_PAGE_L1:
		MOV.B	#0, R0L
		JSR	@LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_CLR_PAGE_L1
		POP.W	R0
		RTS

;-------------------------------------------------
;	LOCATE X<0..15>,Y<0..8>  X=R0L, Y=R0H
;-------------------------------------------------
LCD_OFFSET:					;　これを使っているのはすべて修正すること
LCD_TEXT_OFFSET:
		PUSH.W	R0
		BTST	#3,R0L
		BEQ	LCD_TEXT_OFFSET_CS1
		BCLR	LCD_CS1
		NOP
		BSET	LCD_CS2
		AND.B	#7,R0L
		JMP	@LCD_TEXT_OFFSET_SET
LCD_TEXT_OFFSET_CS1:
		BSET	LCD_CS1
		NOP
		BCLR	LCD_CS2
LCD_TEXT_OFFSET_SET:
		SHAL.B	R0L
		SHAL.B	R0L
		SHAL.B	R0L
		OR.B	#H'40, R0L
		JSR	@LCD_SET_CTRL
		OR.B	#H'B8, R0H
		MOV.B	R0H, R0L
		JSR	@LCD_SET_CTRL
		POP.W	R0
		RTS

;-------------------------------------------------
;	8bytesデータ表示
;	IN	R0L: 0x20,,0x5F
;	すでにLCDのアドレスはセット済み
;-------------------------------------------------
LCD_CHAR:	PUSH.W	R0
		PUSH.W	R1
		MOV.W	R0, R1
		AND.W	#H'7F, R1
		SUB.W	#H'20, R1
		SHAL.W	R1
		SHAL.W	R1
		SHAL.W	R1
		ADD.W	#char_SP, R1		; IMAGE DATA ADDRESS
		MOV.B	#8, R0H			; SIZE
LCD_CHAR_L1:
		MOV.B	@R1+, R0L
		JSR	@LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_CHAR_L1
		POP.W	R1
		POP.W	R0
		RTS

LCD_CHAR_INV:	PUSH.W	R0
		PUSH.W	R1
		MOV.W	R0, R1
		AND.W	#H'7F, R1
		SUB.W	#H'20, R1
		SHAL.W	R1
		SHAL.W	R1
		SHAL.W	R1
		ADD.W	#char_SP, R1		; IMAGE DATA ADDRESS
		MOV.B	#8, R0H			; SIZE
LCD_CHAR_INV_L1:
		MOV.B	@R1+, R0L
		NOT.B	R0L
		JSR	@LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_CHAR_INV_L1
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	8bytesデータ表示
;	IN	R0: DATA ADDRESS
;	すでにLCDのアドレスはセット済み
;-------------------------------------------------
LCD_CH_IMAGE:	PUSH.W	R0
		PUSH.W	R1
		MOV.W	R0, R1
		MOV.B	#8, R0H
LCD_CH_IMAGE_L1:
		MOV.B	@R1+, R0L
		JSR	@LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_CH_IMAGE_L1
		POP.W	R1
		POP.W	R0
		RTS

LCD_CH_IMAGE_INV:
		PUSH.W	R0
		PUSH.W	R1
		MOV.W	R0, R1
		MOV.B	#8, R0H
LCD_CH_IMAGE_INV_L1:
		MOV.B	@R1+, R0L
		NOT.B	R0L
		JSR	@LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_CH_IMAGE_INV_L1
		POP.W	R1
		POP.W	R0
		RTS

;----------------------------------------------------
;	LCDへページ幅イメージ表示　縦8バイト、横は引数
;	WRAP処理しないので注意
;	IN	R1:IMAGEデータアドレス
;		R0L:イメージの横の長さ（PIXEL）
;	すでにLCDのアドレスはセット済み
;----------------------------------------------------
LCD_BAND_IMG:
		PUSH.W	R0
		PUSH.W	R1
		MOV.B	R0L, R0H
LCD_BAND_IMG_L1:
		MOV.B	@R1+, R0L
		JSR	@LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_BAND_IMG_L1
		POP.W	R1
		POP.W	R0
		RTS

LCD_BAND_IMG_INV:
		PUSH.W	R0
		PUSH.W	R1
		MOV.B	R0L, R0H
LCD_BAND_IMG_INV_L1:
		MOV.B	@R1+, R0L
		NOT.B	R0L
		JSR	@LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_BAND_IMG_INV_L1
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	8bytesデータクリア
;	IN	R0: DATA ADDRESS
;	すでにLCDのアドレスはセット済み
;-------------------------------------------------
LCD_CLR_CHAR:	PUSH.W	R0
		MOV.B	#8, R0H
LCD_CLR_CHAR_L1:
		BSR	CHK_LCD_BUSY
		MOV.B	#0, R0L
		MOV.B	R0L,@PDR8		; 制御データ出力
		BSET	LCD_DI			; 制御データフラグ
		NOP
		BCLR	LCD_RW			; 書き込み
		NOP				; 140ns必要　（NOP=100ns）
		NOP
		BSET	LCD_E			; LCDのTwh=450ns
		NOP
		NOP
		NOP
		NOP
		NOP
		BCLR	LCD_E			; シグナル
		DEC.B	R0H
		BNE	LCD_CLR_CHAR_L1
		POP.W	R0
		RTS

;-------------------------------------------------
;	数字を半角で表示
;	IN	R0L: 0-9
;	すでにLCDのアドレスはセット済み
;-------------------------------------------------
LCD_NUM:	PUSH.W	R0
		PUSH.W	R1
		MOV.W	R0, R1
		AND.W	#H'0F, R1
		SHAL.W	R1
		SHAL.W	R1
		SHAL.W	R1
		ADD.W	#char_0, R1
		MOV.B	#8, R0H
		CMP.B	#10, R0L
		BCS	LCD_NUM_L1
		ADD.W	#17, R1
LCD_NUM_L1:
		BSR	CHK_LCD_BUSY
		MOV.B	@R1+, R0L
		MOV.B	R0L,@PDR8		; 制御データ出力
		BSET	LCD_DI			; 制御データフラグ
		NOP
		BCLR	LCD_RW			; 書き込み
		NOP				; 140ns必要　（NOP=100ns）
		NOP
		BSET	LCD_E			; LCDのTwh=450ns
		NOP
		NOP
		NOP
		NOP
		NOP
		BCLR	LCD_E			; シグナル
		DEC.B	R0H
		BNE	LCD_NUM_L1
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	文字列表示
;	IN R0:文字列のポインタ。終端は、\0
;	すでにLCDのアドレスはセット済み
;-------------------------------------------------
LCD_STRING:	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2
		MOV.W	R0, R1
LCD_STRING_L1:	MOV.B	@R1+, R2L
		BEQ	LCD_STRING_E
		AND.W	#H'7F, R2
		SUB.W	#H'20, R2
		SHAL.W	R2
		SHAL.W	R2
		SHAL.W	R2
		ADD.W	#char_SP, R2		; IMAGE DATA ADDRESS
		MOV.B	#8, R0H			; SIZE
LCD_STRING_L2:
		MOV.B	@R2+, R0L
		JSR	@LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_STRING_L2
		JMP	@LCD_STRING_L1
LCD_STRING_E:	POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

LCD_STRING_INV:	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2
		MOV.W	R0, R1
LCD_STRING_INV_L1:
		MOV.B	@R1+, R2L
		BEQ	LCD_STRING_INV_E
		AND.W	#H'7F, R2
		SUB.W	#H'20, R2
		SHAL.W	R2
		SHAL.W	R2
		SHAL.W	R2
		ADD.W	#char_SP, R2		; IMAGE DATA ADDRESS
		MOV.B	#8, R0H			; SIZE
LCD_STRING_INV_L2:
		MOV.B	@R2+, R0L
		NOT.B	R0L
		JSR	@LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_STRING_INV_L2
		JMP	@LCD_STRING_INV_L1
LCD_STRING_INV_E:
		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	R0Lを16進で表示
;	IN	R0L
;	すでにLCDのアドレスはセット済み
;-------------------------------------------------
LCD_HEXDATA	PUSH.W	R0
		JSR	@HEX2ASCII
		PUSH.W	R0
		MOV.B	R0H, R0L
		BSR	LCD_CHAR
		POP.W	R0
		BSR	LCD_CHAR
		POP.W	R0
		RTS

;-------------------------------------------------
;	R0の10進表示。符号なし。最上位桁０詰めなし
;	すでにLCDのアドレスはセット済み
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
		CMP.B	#H'0, R1L
		BNE	LCD_DEC_W_L1
		JSR	@LCD_CLR_CHAR
		JMP	@LCD_DEC_W_L2
LCD_DEC_W_L1:	JSR	@LCD_NUM
LCD_DEC_W_L2:	POP.W	R0
		OR.B	R0L, R1L		; 上位桁チェック用 ORを取ることで、０以外かを確認
		CMP.B	#H'0, R1L
		BNE	LCD_DEC_W_L3
		JSR	@LCD_CLR_CHAR
		JMP	@LCD_DEC_W_L4
LCD_DEC_W_L3:	JSR	@LCD_NUM
LCD_DEC_W_L4:	POP.W	R0
		OR.B	R0L, R1L		; 上位桁チェック用 ORを取ることで、０以外かを確認
		CMP.B	#H'0, R1L
		BNE	LCD_DEC_W_L5
		JSR	@LCD_CLR_CHAR
		JMP	@LCD_DEC_W_L6
LCD_DEC_W_L5:	JSR	@LCD_NUM
LCD_DEC_W_L6:	POP.W	R0
		JSR	@LCD_NUM
		POP.W	R0
		JSR	@LCD_NUM
		POP.L	ER1
		POP.L	ER0
		RTS

;-------------------------------------------------
;	R0Lの10進2桁表示。符号なし。０埋めあり
;	すでにLCDのアドレスはセット済み
;-------------------------------------------------
LCD_DEC_B_0	PUSH.L	ER0
		PUSH.W	R1
		MOV.B	#10, R1L
		MOV.B	#0, R0H
		DIVXU.B	R1L, R0
		PUSH.W	R0
		MOV.B	#0, R0H
		DIVXU.B	R1L, R0
		MOV.B	R0H, R0L
		JSR	@LCD_NUM
		POP.W	R0
		MOV.B	R0H, R0L
		JSR	@LCD_NUM
		POP.W	R1
		POP.L	ER0
		RTS

;-------------------------------------------------
;	R0Lの10進表示。符号なし。最上位桁０詰めなし
;	すでにLCDのアドレスはセット済み
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
		CMP.B	#H'0, R1L
		BNE	LCD_DEC_B_L1
		JSR	@LCD_CLR_CHAR
		JMP	@LCD_DEC_B_L2
LCD_DEC_B_L1:	JSR	@LCD_NUM
LCD_DEC_B_L2:	POP.W	R0
		MOV.B	R0H, R0L
		OR.B	R0L, R1L		; 上位桁チェック用 ORを取ることで、０以外かを確認
		CMP.B	#H'0, R1L
		BNE	LCD_DEC_B_L3
		JSR	@LCD_CLR_CHAR
		JMP	@LCD_DEC_B_L4
LCD_DEC_B_L3:	JSR	@LCD_NUM
LCD_DEC_B_L4:	POP.W	R0
		MOV.B	R0H, R0L
		JSR	@LCD_NUM

		POP.L	ER1
		POP.L	ER0
		RTS

;-------------------------------------------------
;	R0Lの10進2桁表示。符号あり(+はスペース)
;	R0Hが０以外の時、小数点を付ける
;	すでにLCDのアドレスはセット済み
;-------------------------------------------------
LCD_DEC_B_S	PUSH.W	R0
		PUSH.L	ER1
		BTST	#7,R0L
		BNE	LCD_DEC_B_MINUS
		MOV.W	R0, R1
		JSR	@LCD_CLR_CHAR
		MOV.W	R1, R0
		JMP	@LCD_DEC_B_U
LCD_DEC_B_MINUS:
		MOV.W	R0, R1
		MOV.B	#H'2D,R0L
		JSR	@LCD_CHAR
		MOV.W	R1, R0
		NEG.B	R0L
LCD_DEC_B_U:
		MOV.B	R0H, R1H	;小数点フラグ
		MOV.B	#0, R0H
		MOV.B	#10, R1L
		DIVXU.B	R1L, R0
		PUSH.W	R0		; R0H LOWEST
		MOV.B	#0, R0H
		DIVXU.B	R1L, R0
		MOV.B	R0H, R0L
		JSR	@LCD_NUM
		CMP.B	#0, R1H
		BEQ	LCD_DEC_B_U1
		MOV.B	#H'2E, R0L
		JSR	@LCD_CHAR
LCD_DEC_B_U1:
		POP.W	R0
		MOV.B	R0H, R0L
		JSR	@LCD_NUM
		POP.L	ER1
		POP.W	R0
		RTS

;-------------------------------------------------
;	R0の10進3桁表示。UNSIGNED
;	IN	R0:３ケタ表示するデータ
;	すでにLCDのアドレスはセット済み
;-------------------------------------------------
LCD_DEC_000:	PUSH.W	R0
		PUSH.W	R1
		MOV.B	#100, R1L
		DIVXU.B	R1L, R0
		PUSH.W	R0
		JSR	@LCD_NUM
		POP.W	R0
		MOV.B	R0H, R0L
		JSR	@LCD_DEC_B_0
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	R0の10進4桁表示。UNSIGNED
;	IN	R0:4ケタ表示するデータ
;	すでにLCDのアドレスはセット済み
;-------------------------------------------------
LCD_DEC_0000:	PUSH.W	R0
		PUSH.W	R1
		MOV.B	#100, R1L
		DIVXU.B	R1L, R0
		PUSH.W	R0
		JSR	@LCD_DEC_B_0
		POP.W	R0
		MOV.B	R0H, R0L
		JSR	@LCD_DEC_B_0
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	16X10数字表示(文字間左右1BITは空白、行全体の左右4ビット空白)
;	IN R0L: 0..9
;	IN R1:  R1L:X桁(1..10),  R1H:Y開始行(0..6)
;-------------------------------------------------
LCD_LNUM:	PUSH.W	R0
		MOV.B	#0, R0H
		SHAL.W	R0
		SHAL.W	R0
		SHAL.W	R0
		SHAL.W	R0			; R0L*16
		ADD.W	#char_0w, R0
		BSR	LCD_LCHAR
		POP.W	R0
		RTS

;-------------------------------------------------
;	16X10文字表示(文字間左右1BITは空白、行全体の左右4ビット空白)
;	IN R0: 文字データアドレス（8bytes * 2行）
;	IN R1: R1L:X桁(1..10), R1H:Y開始行(0..6)
;-------------------------------------------------
LCD_LCHAR:	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2

		MOV.W	R0,R2
		CMP.B	#6, R1L
		BCS	LCD_LCHAR_L0
		BCLR	LCD_CS1
		BSET	LCD_CS2
		SUB.W	#6, R1			; SUB.Bでは直値はだめ
		MOV.B	#1, R0H			; CS2のときは文字先頭の1ビット分シフト
		JMP	@LCD_LCHAR_L1
LCD_LCHAR_L0:	BSET	LCD_CS1
		BCLR	LCD_CS2
		MOV.B	#5, R0H			; CS1のときはX軸4ビットと文字先頭の1ビット分シフト
LCD_LCHAR_L1:
		SHAL.B	R1L			; X*2
		ADD.B	R1L, R0H		; いったん保持
		SHAL.B	R1L
		SHAL.B	R1L
		ADD.B	R0H, R1L		; R1L = X*10 + シフト分
		AND.B	#H'07, R1H
		OR.B	#H'B8, R1H
		AND.B	#H'3F, R1L
		OR.B	#H'40, R1L		; SET ADDRESS
		PUSH.W 	R1
		MOV.B	R1L, R0L
		JSR	@LCD_SET_CTRL		; SET PAGE ADDRESS
		MOV.B	R1H, R0L
		JSR	@LCD_SET_CTRL
		MOV.B	#8, R0H			; 文字データのサイズ
LCD_LCHAR_L2:
		MOV.B	@R2+, R0L
		JSR	@LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_LCHAR_L2
		POP.W	R1
		INC.B	R1H			; PAGE++
		MOV.B	R1L, R0L
		JSR	@LCD_SET_CTRL		; SET PAGE ADDRESS
		MOV.B	R1H, R0L
		JSR	@LCD_SET_CTRL
		MOV.B	#8, R0H			; 文字データのサイズ
LCD_LCHAR_L3:
		MOV.B	@R2+, R0L
		JSR	@LCD_SET_DATA
		DEC.B	R0H
		BNE	LCD_LCHAR_L3

		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	R0Lの10進2桁表示。符号なし。０埋めあり
;	16X10文字表示(文字間左右1BITは空白、行全体の左右4ビット空白)
;	IN R0L: 数値
;	IN R1: R1L:X桁(1..10), R1H:Y開始行(0..6)
;-------------------------------------------------
LCD_LDEC_B_0	PUSH.L	ER0
		PUSH.W	R1
		PUSH.W	R2
		MOV.B	#10, R2L
		MOV.B	#0, R0H
		DIVXU.B	R2L, R0
		PUSH.W	R0
		MOV.B	#0, R0H
		DIVXU.B	R2L, R0
		MOV.B	R0H, R0L
		JSR	@LCD_LNUM
		POP.W	R0
		MOV.B	R0H, R0L
		INC.B	R1L
		JSR	@LCD_LNUM
		POP.W	R2
		POP.W	R1
		POP.L	ER0
		RTS

;-------------------------------------------------
;	R0Lの10進３桁表示。符号なし。０埋めあり
;	16X10文字表示(文字間左右1BITは空白、行全体の左右4ビット空白)
;	IN R0: ３ケタ表示するデータ
;	IN R1: R1L:X桁(1..10), R1H:Y開始行(0..6)
;-------------------------------------------------
LCD_LDEC_000:	PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2
		MOV.B	#100, R2L
		DIVXU.B	R2L, R0
		PUSH.W	R0
		JSR	@LCD_LNUM
		POP.W	R0
		MOV.B	R0H, R0L
		INC.B	R1L
		JSR	@LCD_LDEC_B_0
		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS


;=================================================
	.SECTION VRAM, DATA, ALIGN=2

VRAM_X00Y00	.RES.B	64
VRAM_X00Y08	.RES.B	64
VRAM_X00Y16	.RES.B	64
VRAM_X00Y24	.RES.B	64
VRAM_X00Y32	.RES.B	64
VRAM_X00Y40	.RES.B	64
VRAM_X00Y48	.RES.B	64
VRAM_X00Y56	.RES.B	64
VRAM_X64Y00	.RES.B	64
VRAM_X64Y08	.RES.B	64
VRAM_X64Y16	.RES.B	64
VRAM_X64Y24	.RES.B	64
VRAM_X64Y32	.RES.B	64
VRAM_X64Y40	.RES.B	64
VRAM_X64Y48	.RES.B	64
VRAM_X64Y56	.RES.B	64

	.END
