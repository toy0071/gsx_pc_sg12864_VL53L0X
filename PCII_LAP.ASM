;===== PCII_LAP.ASM ========================================
;	LAP TIMER処理
;				toya@v007.vaio.ne.jp
;	CPU H8/3694
;-------------------------------------------------

	.FORM	COL=120
	.PRINT	LIST		;アセンブル時にリストファイルを出力する
	.CPU 300HN		;ＣＰＵの指定

	.INCLUDE "PCII.INC"
	.INCLUDE "CONST.INC"

	.IMPORT		LCD_NUM
	.IMPORT		LCD_CHAR
	.IMPORT		LCD_CH_IMAGE
	.IMPORT		LCD_STRING
	.IMPORT		LCD_LCHAR
	.IMPORT		LCD_OFFSET
	.IMPORT		LCD_TEXT_OFFSET
	.IMPORT		LCD_CLR_CS1
	.IMPORT		LCD_CLR_CS2
	.IMPORT		LCD_HEXDATA
	.IMPORT		LCD_LDEC_B_0
	.IMPORT		LCD_LDEC_000
	.IMPORT		LCD_DEC_B_0
	.IMPORT		LCD_DEC_000

	.IMPORT		GET_DATA_FROM_MEMORY

	.IMPORT		TIMEV_CNT

	.IMPORT		SET_MEM_LAP_DATA

	.EXPORT		LAP_DATA_INIT
	.EXPORT		LAP_MON
	.EXPORT		LAP_MON_SW1
	.EXPORT		LAP_VIEW_INIT
	.EXPORT		LAP_VIEW

	.EXPORT		DISP_TIME
	.EXPORT		DISP_MULTI_TIME

	.EXPORT		LAP_SETTING_SECTOR
	.EXPORT		GET_SECTORS

	.EXPORT		TOTAL_CNT

MAX_SECTOR	.EQU	4		; MAX+1

;=================================================
	.SECTION ROM, CODE, ALIGN=2
;-------------------------------------------------
;	初期化処理
;	IN	R0L:INIT CMD_TYPE
;-------------------------------------------------
LAP_DATA_INIT:	PUSH.L	ER0
		MOV.L	#0, ER0
		MOV.L	ER0, @TIMEV_CNT
		MOV.L	ER0, @TOTAL_CNT
		MOV.L	ER0, @CHECK_CNT
		MOV.W	#1, R0
		MOV.B	R0L, @SECTORS
		MOV.B	R0L, @SECTOR
		MOV.W	R0, @LAP_NUM
		POP.L	ER0
		RTS

;=================================================
;	時刻計算と表示
;-------------------------------------------------
;	0.8msで1カウント
;	*4/5 で1msとなる。2BITシフトして、5で割る。
;	1250で割ると、1sとなる。
;	7500で割ると、1mとなる。
;-------------------------------------------------
;-------------------------------------------------
;	時間補正
;	ER0 := ER0 * 129/128 * 4095/4096 : クロック補正（微妙なずれ）
;	ER0 := ER0 * 4/5 : 0.8ms/CLICK を 1ms/CLICKに
;	IN  ER0: 0.8ms/click
;	OUT E0 : 秒単位
;	    R0 : ms単位
;-------------------------------------------------
CALC_TIME_ADJUST:
		MOV.L	ER0, ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		ADD.L	ER1, ER0
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SUB.L	ER1, ER0
		MOV.W	#1250,R1
		DIVXU.W	R1, ER0
		PUSH.W	R0
		MOV.W	E0, R0
		MOV.W	#0, E0
		SHAL.L	ER0
		SHAL.L	ER0
		MOV.W	#5,R1
		DIVXU.W	R1, ER0
		POP.W	E0
		RTS

;-------------------------------------------------
;	TOTAL_CNT-CHECK_CNT から、直接 0.000-60.000(1WORD)に変換
;	OUT R0 : ms単位
;-------------------------------------------------
CALC_SECTOR:	PUSH.W	E0
		PUSH.L	ER1
		PUSH.L	ER2
		MOV.L	@TOTAL_CNT, ER1
		MOV.L	@CHECK_CNT, ER2
		SUB.L	ER2, ER1
		MOV.L	ER1, ER0
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		ADD.L	ER1, ER0
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SHLR.L	ER1
		SUB.L	ER1, ER0
		CMP.L	#H'124F8, ER0
		BLS	CALC_SECTOR_L1
		MOV.W	#59999,R0
		JMP	@CALC_SECTOR_E
CALC_SECTOR_L1:
		SHAL.L	ER0
		SHAL.L	ER0
		MOV.W	#5,R1
		DIVXU.W	R1, ER0

		MOV.W	#0, E0
		MOV.W	#60000,R1
		DIVXU.W	R1, ER0
		MOV.W	E0, R0
CALC_SECTOR_E:
		POP.L	ER2
		POP.L	ER1
		POP.W	E0
		RTS

;-------------------------------------------------
;	秒単位(1WORD):秒単位(1WORD) → 0.000-60.000(1WORD)に変換
;	IN  E0 : 秒単位
;	    R0 : ms単位
;	OUT R0 : ms単位
;-------------------------------------------------
CHANGE2SECTOR:	PUSH.W	R1
		MOV.W	E0, R0
		MOV.W	#0, E0
		MOV.W	#60,R1
		DIVXU.W	R1, ER0
		PUSH.W	E0			; 0..59s
		MOV.W	#1000, R1
		MULXU.W	R1, ER0
		POP.W	R1
		ADD.W	R1,R0
		POP.W	R1
		RTS

;=================================================
;	キー入力処理
;-------------------------------------------------
LAP_MON:	PUSH.W	R0
		MOV.W	#0, R0
		MOV.B	R0L, @SW1_MODE
		MOV.B	R0L, @SW2_MODE

		MOV.W	R0, @CURRENT_SEC
		MOV.W	R0, @CURRENT_MSEC
		MOV.W	R0, @CURRENT_S1
		MOV.W	R0, @CURRENT_S2
		MOV.W	R0, @CURRENT_S3
		MOV.W	R0, @LAST_SEC
		MOV.W	R0, @LAST_MSEC
		MOV.W	R0, @LAST_S1
		MOV.W	R0, @LAST_S2
		MOV.W	R0, @LAST_S3
		MOV.W	R0, @BEST_SEC
		MOV.W	R0, @BEST_MSEC
		MOV.W	R0, @BEST_S1
		MOV.W	R0, @BEST_S2
		MOV.W	R0, @BEST_S3
		MOV.W	R0, @S1_BEST
		MOV.W	R0, @S2_BEST
		MOV.W	R0, @S3_BEST
		JSR	@LCD_LAP_PAGE_INIT
		POP.W	R0
		RTS

;-------------------------------------------------
;	キーSW1入力処理
;	IN R0L: MENU MODE
;	表示処理も含んでいるため、LAP MENU, MULTI MENUで分岐している。
;-------------------------------------------------
LAP_MON_SW1:
SET_LAP_MARK:	PUSH.L	ER2
		PUSH.W	R3			; USE R3 TO KEEP R0L(MENU_MODE)
		MOV.W	R0, R3
		MOV.L	@TIMEV_CNT, ER0
		MOV.L	ER0, @TOTAL_CNT
		JSR	@CALC_SECTOR
		MOV.B	@SECTOR, R2L
		CMP.B	#1, R2L
		BNE	SET_LAP_MARK_S2
		MOV.W	R0, @CURRENT_S1
		MOV.W	@S1_BEST, E0			; SECTOR 1の最速チェック
		BEQ	SET_LAP_MARK_L11
		CMP.W	E0,R0
		BCC	SET_LAP_MARK_L12
SET_LAP_MARK_L11:
		MOV.W	R0, @S1_BEST
SET_LAP_MARK_L12:
		MOV.W	@LAST_S2, R0			; 表示用
		MOV.W	@S2_BEST, E0			; 表示用
		JMP	@SET_LAP_MARK_ALL
SET_LAP_MARK_S2:
		CMP.B	#2, R2L
		BNE	SET_LAP_MARK_S3
		MOV.W	R0, @CURRENT_S2
		MOV.W	@S2_BEST, E0			; SECTOR 2の最速チェック
		BEQ	SET_LAP_MARK_L21
		CMP.W	E0,R0
		BCC	SET_LAP_MARK_L22
SET_LAP_MARK_L21:
		MOV.W	R0, @S2_BEST
SET_LAP_MARK_L22:
		MOV.W	@LAST_S3, R0			; 表示用
		MOV.W	@S3_BEST, E0			; 表示用
		JMP	@SET_LAP_MARK_ALL
SET_LAP_MARK_S3:
		CMP.B	#3, R2L
		BNE	SET_LAP_MARK_S_E
		MOV.W	R0, @CURRENT_S3
		MOV.W	@S3_BEST, E0			; SECTOR 3の最速チェック
		BEQ	SET_LAP_MARK_L31
		CMP.W	E0,R0
		BCC	SET_LAP_MARK_L32
SET_LAP_MARK_L31:
		MOV.W	R0, @S3_BEST
SET_LAP_MARK_L32:
		MOV.W	@LAST_S1, R0			; 表示用
		MOV.W	@S1_BEST, E0			; 表示用
SET_LAP_MARK_ALL:
		MOV.B	@SECTORS, R2H
		CMP.B	R2H, R2L
		BNE	SET_LAP_MARK_NEXT
		JMP	@SET_LAP_MARK_LAP
SET_LAP_MARK_NEXT:
		INC.B	R2L
		MOV.B	R2L, @SECTOR
		CMP.B	#MENU_LAP_MON, R3L
		BEQ	SET_LAP_MARK_DISP_LAP
SET_LAP_MARK_DISP_MULTI:				; MULTI MENUの時の表示
;;;		PUSH.W	R0
;;;		MOV.W	#H'0008, R0			; SECTOR
;;;		JSR	@LCD_OFFSET
;;;		POP.W	R0
;;;		JSR	@DISP_SECTOR
;;;		MOV.L	@TOTAL_CNT, ER0
;;;		MOV.L	ER0, @CHECK_CNT
SET_LAP_MARK_S_E:
		JMP	@SET_LAP_MARK_E
SET_LAP_MARK_DISP_LAP:					; SECTOR 更新の表示
		PUSH.W	E0
		PUSH.W	R0
		MOV.W	#H'0601, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.B	R2L, R0L
		JSR	@LCD_NUM
		MOV.W	#H'060A, R0
		JSR	@LCD_TEXT_OFFSET
		POP.W	R0
		JSR	@DISP_SECTOR
		MOV.W	#H'070A, R0
		JSR	@LCD_TEXT_OFFSET
		POP.W	R0
		JSR	@DISP_SECTOR
		MOV.L	@TOTAL_CNT, ER0
		MOV.L	ER0, @CHECK_CNT
		JMP	@SET_LAP_MARK_E
SET_LAP_MARK_LAP:
		MOV.L	@TOTAL_CNT, ER0
		JSR	@CALC_TIME_ADJUST		; E0:秒単位, R0:ms単位
		MOV.W	E0, @LAST_SEC
		MOV.W	R0, @LAST_MSEC
		MOV.W	@CURRENT_S1, R0
		MOV.W	R0, @LAST_S1
		MOV.W	@CURRENT_S2, R0
		MOV.W	R0, @LAST_S2
		MOV.W	@CURRENT_S3, R0
		MOV.W	R0, @LAST_S3
		MOV.W	#LAST_SEC, R0
		JSR	@SET_MEM_LAP_DATA
		MOV.W	@BEST_SEC, E0
		MOV.W	@BEST_MSEC, R0
		CMP.L	#0, ER0
		BEQ	SET_LAP_MARK_BEST
		MOV.W	@LAST_SEC, E2
		MOV.W	@LAST_MSEC, R2
		CMP.L	ER0, ER2			; LAST < BEST
		BHI	SET_LAP_MARK_CLEAR
SET_LAP_MARK_BEST:
		MOV.W	@LAST_SEC, R0
		MOV.W	R0, @BEST_SEC
		MOV.W	@LAST_MSEC, R0
		MOV.W	R0, @BEST_MSEC
		MOV.W	@LAST_S1, R0
		MOV.W	R0, @BEST_S1
		MOV.W	@LAST_S2, R0
		MOV.W	R0, @BEST_S2
		MOV.W	@LAST_S3, R0
		MOV.W	R0, @BEST_S3

SET_LAP_MARK_CLEAR:
		MOV.L	#0, ER0
		MOV.L	ER0, @TIMEV_CNT
		MOV.L	ER0, @TOTAL_CNT
		MOV.L	ER0, @CHECK_CNT
		MOV.W	R0, @CURRENT_S1
		MOV.W	R0, @CURRENT_S2
		MOV.W	R0, @CURRENT_S3
		MOV.B	#1, R0L
		MOV.B	R0L, @SECTOR
		MOV.W	@LAP_NUM, R0
		INC.W	#1,R0
		MOV.W	R0, @LAP_NUM
		CMP.B	#MENU_LAP_MON, R3L
		BEQ	SET_LAP_MARK_CLEAR_DISP_LAP
SET_LAP_MARK_CLEAR_DISP_MULTI:
		MOV.W	#H'0108, R0
		JSR	@LCD_OFFSET
		MOV.W	@LAST_SEC, E0
		MOV.W	@LAST_MSEC, R0
		JSR	@DISP_LAP_TIME
		JMP	@SET_LAP_MARK_E
SET_LAP_MARK_CLEAR_DISP_LAP:
		JSR	@DISP_LAP_PAGE
		JMP	@SET_LAP_MARK_E
SET_LAP_MARK_ERR:
		MOV.W	#H'0012, R0
		JSR	@LCD_OFFSET
		MOV.B	#H'45, R0L
		JSR	@LCD_CHAR
SET_LAP_MARK_E:
		POP.W	R3
		POP.L	ER2
		RTS

LAP_SETTING_SECTOR:
		PUSH.W	R0
		MOV.B	@SECTORS, R0L
		INC.B	R0L
		CMP.B	#MAX_SECTOR, R0L
		BNE	LAP_SETTING_SECTOR_L1
		MOV.B	#1, R0L
LAP_SETTING_SECTOR_L1:
		MOV.B	R0L, @SECTORS
		POP.W	R0
		RTS

GET_SECTORS:	MOV.B	@SECTORS, R0L
		RTS

;-------------------------------------------------
;	LCDへ直接表示
;-------------------------------------------------
;	LAP 計測画面表示
;-------------------------------------------------
;	表示は、上側3行は倍角の数字で、12桁。
;	        下側2行は通常の数字で、16桁。
;		+012345678901
;		+----------+-+
;		|C) 0'00"XXX |		現在のラップ
;		|L) 0'00"XXX |		前周のラップ
;		|B) 0'00"XXX |		ベストラップ
;		|S1-3>    L)00"xxx|	セクタ番号）現セクタタイム 前周セクタタイム　
;		| 00"000  B)00"XXX|	                           ベストセクタタイム　
;		+-------||-------+
;		+0123456789012345
;-------------------------------------------------
;	LAP 計測画面初期化
;-------------------------------------------------
LCD_LAP_PAGE_INIT:
		PUSH.W	R0
		PUSH.W	R1
		JSR	@LCD_CLR_CS1
		JSR	@LCD_CLR_CS2
LCD_LAP_PAGE:
		MOV.W	#char_Cw, R0
		MOV.W	#H'0000, R1
		JSR	@LCD_LCHAR
		MOV.W	#char_cirBEw, R0
		MOV.W	#H'0001, R1
		JSR	@LCD_LCHAR
		MOV.W	#char_Lw, R0
		MOV.W	#H'0200, R1
		JSR	@LCD_LCHAR
		MOV.W	#char_cirBEw, R0
		MOV.W	#H'0201, R1
		JSR	@LCD_LCHAR
		MOV.W	#char_Bw, R0
		MOV.W	#H'0400, R1
		JSR	@LCD_LCHAR
		MOV.W	#char_cirBEw, R0
		MOV.W	#H'0401, R1
		JSR	@LCD_LCHAR
		MOV.W	#H'0600, R0
		JSR	@LCD_TEXT_OFFSET	; 1行表示の時はオフセット設定
		MOV.B	#H'53, R0L		; 'S'
		JSR	@LCD_CHAR
		MOV.B	@SECTOR, R0L
		JSR	@LCD_NUM
		MOV.B	#H'2D, R0L		; '-'
		JSR	@LCD_CHAR
		MOV.B	@SECTORS, R0L
		JSR	@LCD_NUM
		MOV.W	#H'3E, R0		; '>'
		JSR	@LCD_CHAR
		MOV.W	#H'0608, R0
		JSR	@LCD_TEXT_OFFSET	; 1行表示の時はオフセット設定
		MOV.B	#H'4C, R0L		; 'L'
		JSR	@LCD_CHAR
		MOV.B	#H'29, R0L		; ')'
		JSR	@LCD_CHAR
		MOV.W	#H'0708, R0
		JSR	@LCD_TEXT_OFFSET	; 1行表示の時はオフセット設定
		MOV.B	#H'42, R0L		; 'B'
		JSR	@LCD_CHAR
		MOV.B	#H'29, R0L		; ')'
		JSR	@LCD_CHAR
		JSR	@DISP_LAP_PAGE
		POP.W	R1
		POP.W	R0
		RTS

;-------------------------------------------------
;	LAP 計測画面、定期更新
;-------------------------------------------------
DISP_TIME:	PUSH.L	ER0
		PUSH.L	ER1
		PUSH.L	ER2
		MOV.L	@TIMEV_CNT, ER0
		MOV.L	ER0, @TOTAL_CNT
		JSR	@CALC_TIME_ADJUST
		MOV.W	#H'0002, R1
		JSR	@DISP_LLAP_TIME

		MOV.W	#H'0701, R0
		JSR	@LCD_TEXT_OFFSET
		JSR	@CALC_SECTOR
		JSR	@DISP_SECTOR
		POP.L	ER2
		POP.L	ER1
		POP.L	ER0
		RTS

;-------------------------------------------------
;	LAP 計測画面、計測時更新
;-------------------------------------------------
DISP_LAP_PAGE:
		PUSH.L	ER0
		PUSH.W	R1

		MOV.W	#H'0601, R0		; セクタ番号表示
		JSR	@LCD_TEXT_OFFSET
		MOV.B	@SECTOR, R0L
		JSR	@LCD_NUM

		MOV.W	#H'060A, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	@LAST_S1, R0
		JSR	@DISP_SECTOR
		MOV.W	#H'070A, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	@S1_BEST, R0
		JSR	@DISP_SECTOR
DISP_LAP_PAGE_TOTAL:
		MOV.W	#H'0202, R1
		MOV.W	@LAST_SEC, E0
		MOV.W	@LAST_MSEC, R0
		JSR	@DISP_LLAP_TIME
		MOV.W	#H'0402, R1
		MOV.W	@BEST_SEC, E0
		MOV.W	@BEST_MSEC, R0
		JSR	@DISP_LLAP_TIME
		POP.W	R1
		POP.L	ER0
		RTS

;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;-------------------------------------------------
;	MULTI 計測画面表示
;-------------------------------------------------
DISP_MULTI_TIME:
		PUSH.L	ER0
		PUSH.L	ER1
		MOV.L	@TIMEV_CNT, ER0
		MOV.L	ER0, @TOTAL_CNT
		MOV.W	#H'0008, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.L	@TOTAL_CNT, ER0
		JSR	@CALC_TIME_ADJUST
		JSR	@DISP_LAP_TIME
		POP.L	ER1
		POP.L	ER0
		RTS

;-------------------------------------------------
;	LAP 記録表示画面
;-------------------------------------------------
;	表示は、16x8。
;		+0123456789012345
;		+----------------+
;		|LAP-XXX    P----|
;		|   LAP  0'00"000|
;		|   LAST 0'00.000|
;		|   BEST 0'00.000|
;		|     S1   00.000|
;		|     S2   00.000|
;		|     S3   00.000|
;		+----------------+

LAP_VIEW_INIT:	PUSH.W	R0
		JSR	@LCD_CLR_CS1
		JSR	@LCD_CLR_CS2
		MOV.W	#H'0000, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_L0, R0
		JSR	@LCD_STRING
		MOV.W	#H'0100, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_L1, R0
		JSR	@LCD_STRING
		MOV.W	#H'0200, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_L2, R0
		JSR	@LCD_STRING
		MOV.W	#H'0300, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_L3, R0
		JSR	@LCD_STRING
		MOV.W	#H'0400, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_L4, R0
		JSR	@LCD_STRING
		MOV.W	#H'0500, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_L5, R0
		JSR	@LCD_STRING
		MOV.W	#H'0600, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_L6, R0
		JSR	@LCD_STRING
		MOV.W	#H'0008, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_R0, R0
		JSR	@LCD_STRING
		MOV.W	#H'0108, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_R1, R0
		JSR	@LCD_STRING
		MOV.W	#H'0208, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_R1, R0
		JSR	@LCD_STRING
		MOV.W	#H'0308, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_R1, R0
		JSR	@LCD_STRING
		MOV.W	#H'0408, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_R3, R0
		JSR	@LCD_STRING
		MOV.W	#H'0508, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_R3, R0
		JSR	@LCD_STRING
		MOV.W	#H'0608, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_MSG_R3, R0
		JSR	@LCD_STRING
		POP.W	R0
		RTS

LAPV_MSG_L0	.SDATA		"LAP-### "
		.DATA.B		0
LAPV_MSG_L1	.SDATA		"   LAP  "
		.DATA.B		0
LAPV_MSG_L2	.SDATA		"   LAST "
		.DATA.B		0
LAPV_MSG_L3	.SDATA		"   BSET "
		.DATA.B		0
LAPV_MSG_L4	.SDATA		"   SC1> "
		.DATA.B		0
LAPV_MSG_L5	.SDATA		"   SC2> "
		.DATA.B		0
LAPV_MSG_L6	.SDATA		"   SC3> "
		.DATA.B		0
LAPV_MSG_R0	.SDATA		" P-.... "
		.DATA.B		0
LAPV_MSG_R1	.SDATA		"-'--.---"
		.DATA.B		0
LAPV_MSG_R3	.SDATA		"  --.---"
		.DATA.B		0
		.ALIGN	2

;-------------------------------------------------
;	表示処理
;	IN	R1:IIC NO - XXXXの表示用
;		R0H:RECORD NO.
;		R0L:PLAY/ DEL
;	OUT	R0L:0=OK FF=EOF
;-------------------------------------------------
LAP_VIEW:	PUSH.W	R0
		PUSH.W	R1
		CMP.B	#0, R0L
		BNE	LAP_VIEW_DEL

		JSR	@LAP_VIEW_INIT
		MOV.W	#H'000B, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.B	R1H, R0L
		JSR	@LCD_HEXDATA
		MOV.B	R1L, R0L
		JSR	@LCD_HEXDATA

		MOV.W	#MEM_SEC, R1
		MOV.W	#LAP_1RECORD, R0
		JSR	@GET_DATA_FROM_MEMORY

		MOV.W	#H'0108, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	@MEM_SEC, E0
		MOV.W	@MEM_MSEC, R0
		JSR	@DISP_LAP_TIME
		MOV.W	#H'040A, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	@MEM_S1, R0
		JSR	@DISP_SECTOR
		MOV.W	#H'050A, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	@MEM_S2, R0
		JSR	@DISP_SECTOR
		MOV.W	#H'060A, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	@MEM_S3, R0
		JSR	@DISP_SECTOR
		JMP	@LAP_VIEW_E

LAP_VIEW_DEL:
		JSR	@LCD_CLR_CS1
		JSR	@LCD_CLR_CS2
		MOV.W	#H'0000, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_DEL_MSG1, R0
		JSR	@LCD_STRING
		MOV.W	#H'0008, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#LAPV_DEL_MSG2, R0
		JSR	@LCD_STRING
		MOV.W	#H'0009, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.B	R1H, R0L
		JSR	@LCD_HEXDATA
		MOV.B	R1L, R0L
		JSR	@LCD_HEXDATA

LAP_VIEW_E:
		POP.W	R1
		POP.W	R0
		RTS

LAPV_DEL_MSG1	.SDATA		"DEL <LAP"
		.DATA.B		0
LAPV_DEL_MSG2	.SDATA		" P--->? "
		.DATA.B		0
		.ALIGN	2


;-------------------------------------------------
;	ラップタイムの表示
;	IN  E0 : 秒単位
;	    R0 : ms単位
;-------------------------------------------------
DISP_LAP_TIME:	PUSH.L	ER1

		CMP.W	#H'FFFF, R0		; NO DATA
		BEQ	DISP_LAP_TIME_NODATA
		PUSH.W	R0			; m秒単位
		MOV.W	E0, R0			; 秒単位
		MOV.W	#0, E0
		MOV.W	#60, R1
		DIVXU.W	R1, ER0
		PUSH.W	E0			; E0 : <60.  0..59s
		MOV.W	#0, E0
		MOV.W	#10, R1
		DIVXU.W	R1, ER0
		MOV.W	E0, R0
		ADD.B	#H'30, R0L
		JSR	@LCD_CHAR

		MOV.B	#H'3A, R0L		; ':'秒の表示
		JSR	@LCD_CHAR
		POP.W	R0			; R0: 0..59s
		JSR	@LCD_DEC_B_0

		MOV.B	#H'2E, R0L		; '.'m秒の表示
		JSR	@LCD_CHAR
		POP.W	R0			; m秒単位
		JSR	@LCD_DEC_000
		JMP	@DISP_LAP_TIME_E
DISP_LAP_TIME_NODATA:
		MOV.B	#H'2D, R0L
		JSR	@LCD_CHAR
		MOV.B	#H'3A, R0L		; ':'秒の表示
		JSR	@LCD_CHAR
		MOV.B	#H'2D, R0L
		JSR	@LCD_CHAR
		MOV.B	#H'2D, R0L
		JSR	@LCD_CHAR
		MOV.B	#H'2E, R0L		; '.'m秒の表示
		JSR	@LCD_CHAR
		MOV.B	#H'2D, R0L
		JSR	@LCD_CHAR
		MOV.B	#H'2D, R0L
		JSR	@LCD_CHAR
		MOV.B	#H'2D, R0L
		JSR	@LCD_CHAR

DISP_LAP_TIME_E:
		POP.L	ER1
		RTS

;-------------------------------------------------
;	ラップタイムの表示
;	IN  E0 : 秒単位
;	    R0 : ms単位
;	    R1 : R1L:X桁(1..10), R1H:Y開始行(0..6)
;-------------------------------------------------
DISP_LLAP_TIME:	PUSH.L	ER2

		CMP.W	#H'FFFF, R0		; NO DATA
		BEQ	DISP_LLAP_TIME_NODATA
		PUSH.W	R0			; m秒単位
		MOV.W	E0, R0			; 秒単位
		MOV.W	#0, E0
		MOV.W	#60, R2
		DIVXU.W	R2, ER0
		PUSH.W	E0			; E0 : <60.  0..59s
		MOV.W	#0, E0
		MOV.W	#10, R2
		DIVXU.W	R2, ER0
		MOV.W	E0, R0
		MOV.B	#0, R0H
		SHAL.W	R0
		SHAL.W	R0
		SHAL.W	R0
		SHAL.W	R0
		ADD.W	#char_0w, R0
		JSR	@LCD_LCHAR

		INC.B	R1L			; X桁シフト
		MOV.W	#char_ap1w, R0		; [']秒の表示
		JSR	@LCD_LCHAR

		POP.W	R0			; R0: 0..59s
		INC.B	R1L			; X桁シフト
		JSR	@LCD_LDEC_B_0

		ADD.B	#2,R1L			; X桁シフト
		MOV.W	#char_ap2w, R0		; ["]秒の表示
		JSR	@LCD_LCHAR

		POP.W	R0			; m秒単位
		INC.B	R1L			; X桁シフト
		JSR	@LCD_LDEC_000
		JMP	@DISP_LLAP_TIME_E
DISP_LLAP_TIME_NODATA:
		MOV.W	#char_hyrhenw, R0	; [-]の表示
		JSR	@LCD_LCHAR
		INC.B	R1L			; X桁シフト
		MOV.W	#char_ap1w, R0		; [']秒の表示
		JSR	@LCD_LCHAR
		INC.B	R1L			; X桁シフト
		MOV.W	#char_hyrhenw, R0	; [-]の表示
		JSR	@LCD_LCHAR
		INC.B	R1L			; X桁シフト
		MOV.W	#char_hyrhenw, R0	; [-]の表示
		JSR	@LCD_LCHAR
		INC.B	R1L			; X桁シフト
		MOV.W	#char_ap2w, R0		; ["]秒の表示
		JSR	@LCD_LCHAR
		INC.B	R1L			; X桁シフト
		MOV.W	#char_hyrhenw, R0	; [-]の表示
		JSR	@LCD_LCHAR
		INC.B	R1L			; X桁シフト
		MOV.W	#char_hyrhenw, R0	; [-]の表示
		JSR	@LCD_LCHAR
		INC.B	R1L			; X桁シフト
		MOV.W	#char_hyrhenw, R0	; [-]の表示
		JSR	@LCD_LCHAR
DISP_LLAP_TIME_E:
		POP.L	ER2
		RTS

;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;-------------------------------------------------
;	セクタータイムの表示
;	IN  R0 : 0.000-59.999
;	すでにLCDのアドレスはセット済み
;-------------------------------------------------
DISP_SECTOR:	PUSH.W	R1
		CMP.W	#H'FFFF, R0		; NO DATA
		BEQ	DISP_SECTOR_NODATA
		MOV.W	#0, E0
		MOV.W	#1000,R1
		DIVXU.W	R1, ER0
		PUSH.W	E0			; 0.999
		JSR	@LCD_DEC_B_0
		MOV.W	#char_ap2, R0		; ["]m秒の表示
		JSR	@LCD_CH_IMAGE
		POP.W	R0			; m秒単位
		JSR	@LCD_DEC_000
		JMP	@DISP_SECTOR_E
DISP_SECTOR_NODATA:
		MOV.W	#SECTOR_TIME_F, R0
		JSR	@LCD_STRING
DISP_SECTOR_E:
		POP.W	R1
		RTS

SECTOR_TIME_F	.SDATA		"--.---"
		.DATA.B		0

;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

;=================================================
	.SECTION PDATA, DATA, ALIGN=2

SW1_MODE	.RES.B	1
SW2_MODE	.RES.B	1

CHECK_CNT	.RES.L	1
TOTAL_CNT	.RES.L	1

CURRENT_SEC	.RES.W	1
CURRENT_MSEC	.RES.W	1
CURRENT_S1	.RES.W	1		; SECTION 0-1 TIME: 0.000 - 60.000
CURRENT_S2	.RES.W	1		; SECTION 0-1 TIME: 0.000 - 60.000
CURRENT_S3	.RES.W	1		; SECTION 0-1 TIME: 0.000 - 60.000

LAST_SEC	.RES.W	1
LAST_MSEC	.RES.W	1
LAST_S1		.RES.W	1		; SECTION 0-1 TIME: 0.000 - 60.000
LAST_S2		.RES.W	1		; SECTION 1-2 TIME: 0.000 - 60.000
LAST_S3		.RES.W	1		; SECTION 2-3 TIME: 0.000 - 60.000

BEST_SEC	.RES.W	1		; BESTラップのタイム
BEST_MSEC	.RES.W	1
BEST_S1		.RES.W	1		; SECTION 0-1 TIME: 0.000 - 60.000
BEST_S2		.RES.W	1		; SECTION 1-2 TIME: 0.000 - 60.000
BEST_S3		.RES.W	1		; SECTION 2-3 TIME: 0.000 - 60.000

S1_BEST		.RES.W	1		; SECTION 1 だけでのベストタイム
S2_BEST		.RES.W	1		; SECTION 2 だけでのベストタイム
S3_BEST		.RES.W	1		; SECTION 3 だけでのベストタイム

SECTORS		.RES.B	1
SECTOR		.RES.B	1
LAP_NUM		.RES.W	1

MEM_SEC		.RES.W	1
MEM_MSEC	.RES.W	1
MEM_S1		.RES.W	1		; SECTION 0-1 TIME: 0.000 - 60.000
MEM_S2		.RES.W	1		; SECTION 1-2 TIME: 0.000 - 60.000
MEM_S3		.RES.W	1		; SECTION 2-3 TIME: 0.000 - 60.000

		.ALIGN	2

	.END
