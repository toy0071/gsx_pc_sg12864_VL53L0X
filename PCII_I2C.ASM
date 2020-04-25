;===== I2C I/F ========================================
;	h8/3694
;				toya@v007.vaio.ne.jp
;	24FC512
;	１バイト書き込みか、連続書き込み可能
;	連続書き込みは、ページ単位。
;	ページの途中からでも書き込めるが、ページ単位でラップしてしまう。
;	１ページは、128バイト
;	
;======================================================

	.FORM	COL=120
	.PRINT	LIST		;アセンブル時にリストファイルを出力する
	.CPU 300HN		;ＣＰＵの指定

	.INCLUDE "io.inc"

	.IMPORT		LIFE_MS

	.EXPORT		I2C_INIT
	.EXPORT		I2C_WRITE_DATA
	.EXPORT		I2C_START
	.EXPORT		I2C_STOP
	.EXPORT		I2C_BUSY_WAIT
	.EXPORT		I2C_MASTER_SEND
	.EXPORT		I2C_MASTER_RCV

R_LED		.BEQU	1,PDR1
G_LED		.BEQU	2,PDR1

WD_TIME	.EQU	50	;  x 1.638ms (3694)

;------	I2C用 シンボル -----
ICE	.EQU	7	; ICCR1
RCVD	.EQU	6	; ICCR1
MST	.EQU	5	; ICCR1
TRS	.EQU	4	; ICCR1

BBSY	.EQU	7	; ICCR2
SCP	.EQU	6	; ICCR2
SDAO	.EQU	5	; ICCR2
SDAOP	.EQU	4	; ICCR2
SCLO	.EQU	3	; ICCR2
IICRST	.EQU	1	; ICCR2

MLS	.EQU	7	; ICMR
WAIT	.EQU	6	; ICMR
BCWP	.EQU	3	; ICMR

TIE	.EQU	7	; ICIER
TEIE	.EQU	6	; ICIER
RIE	.EQU	5	; ICIER
NAKIE	.EQU	4	; ICIER
STIE	.EQU	3	; ICIER
ACKE	.EQU	2	; ICIER
ACKBR	.EQU	1	; ICIER
ACKBT	.EQU	0	; ICIER

TDRE	.EQU	7	; ICSR
TEND	.EQU	6	; ICSR
RDRF	.EQU	5	; ICSR
NACKF	.EQU	4	; ICSR
STOP	.EQU	3	; ICSR
AL	.EQU	2	; ICSR
OVE	.EQU	2	; ICSR
AAS	.EQU	1	; ICSR
ADZ	.EQU	0	; ICSR

;=================================================
	.SECTION ROM, CODE, ALIGN=2
;-------------------------------------------------
;	初期化処理
;-------------------------------------------------
I2C_INIT:	PUSH.L	ER0
		MOV.B	#B'00001110, R0L	; スレーブ=7,I2Cバスフォーマット
		MOV.B	R0L, @SAR
;;;		MOV.B	#B'00110000, R0L	; MLS=0, WAIT=0, BCWP=0, BC2..0=000(9bit)
		MOV.B	#B'00110111, R0L	; MLS=0, WAIT=0, BCWP=0, BC2..0=111(8bit)
		MOV.B	R0L, @ICMR
		MOV.B	#B'10110100, R0L	; ICE=1, RCVD=0, MST=1, TRS=1, CKS=0100(250kHz)
		MOV.B	R0L, @ICCR1
		MOV.B	@ICCR2, R0L
		AND.B	#H'3F, R0L		; 停止条件 BBSY=0, SCP=0
		MOV.B	R0L, @ICCR2		; MOV命令で行うこと

		MOV.B	@ICCR2, R0L
		BSET	#IICRST, R0L		; RESET
		MOV.B	R0L, @ICCR2		; MOV命令で行うこと
		NOP
		NOP
		NOP
		MOV.B	@ICCR2, R0L
		BCLR	#IICRST, R0L		; 
		MOV.B	R0L, @ICCR2		; MOV命令で行うこと
		POP.L	ER0
		RTS

;------------------------------------------------
;	送信DATA	IN/  R0L:DATA
;			OUT/ C-FLAG:1=ERR, O=OK
;------------------------------------------------
I2C_WRITE_DATA:
		PUSH.W	R0
		JSR	@I2C_START_WATCHDOG
I2C_WRITE_DATA_L:
		JSR	@I2C_CHK_WATCHDOG
		BCS	I2C_WRITE_DATA_END
		MOV.B	@ICSR, R0L
		BTST	#TDRE, R0L		; 7:TDRE
		BEQ	I2C_WRITE_DATA_L
		POP.W	R0
		PUSH.W	R0
		MOV.B	R0L, @ICDRT
I2C_WRITE_CHK:
		JSR	@I2C_CHK_WATCHDOG
		BCS	I2C_WRITE_DATA_END
		NOP
		MOV.B	@ICSR, R0L
		BTST	#TEND, R0L		; 6:TEND
		BEQ	I2C_WRITE_CHK
		MOV.B	@ICIER, R0L
		BLD	#ACKBR, R0L		; C-Flag = ACKBR / 0 = OK
I2C_WRITE_DATA_END:
		POP.W	R0
		RTS

;------------------------------------------------
;	IICコマンド処理
;	NOTE: Every function break R0.
;------------------------------------------------
I2C_START:	MOV.B	@ICCR2, R0L
		BCLR	#SCP, R0L		; 開始条件 7:BBSY=1, 6:SCP=0
		NOP
		BSET	#BBSY, R0L
		NOP
		MOV.B	R0L, @ICCR2		; MOV命令で行うこと
		RTS

I2C_STOP:
		PUSH.W	R0
		JSR	@I2C_START_WATCHDOG

		MOV.B	@ICCR2, R0L
		AND.B	#H'3F, R0L		; 停止条件 BBSY=0, SCP=0
		MOV.B	R0L, @ICCR2		; MOV命令で行うこと
I2C_STOP_CHK:
		MOV.B	@ICSR, R0L
		ANDC	#H'FE, CCR
		BTST	#STOP, R0L
		BNE	I2C_STOP_END

		JSR	@I2C_CHK_WATCHDOG
		BCC	I2C_STOP_CHK
		ORC	#1, CCR
I2C_STOP_END:
		POP.W	R0
		RTS

I2C_BUSY_WAIT:
		PUSH.W	R0
		JSR	@I2C_START_WATCHDOG
I2C_BUSY_WAIT_L1:
		MOV.B	@ICCR2, R0L
		ANDC	#H'FE, CCR
		BTST	#BBSY, R0L
		BEQ	I2C_BUSY_WAIT_END

		JSR	@I2C_CHK_WATCHDOG
		BCC	I2C_BUSY_WAIT_L1
		ORC	#1, CCR
I2C_BUSY_WAIT_END:
		POP.W	R0
		RTS

I2C_MASTER_SEND:				; MST=1, TRS=1 : マスタ送信モード
		MOV.B	@ICCR1, R0L
		OR.B	#H'30,R0L		; 5:MST=1, 4:TRS=1
		MOV.B	R0L,@ICCR1
		RTS

I2C_MASTER_RCV:					; MST=1, TRS=0 : マスタ受信モード
		MOV.B	@ICSR, R0L
		BCLR	#TEND, R0L
		MOV.B	R0L, @ICSR

		MOV.B	@ICCR1, R0L
		BSET	#MST, R0L
		NOP
		BCLR	#TRS, R0L
		NOP
		MOV.B	R0L,@ICCR1

		MOV.B	@ICSR, R0L
		BCLR	#TDRE, R0L
		MOV.B	R0L, @ICSR
		RTS

;------------------------------------------------
;	I2C_START_WATCHDOG
;------------------------------------------------
I2C_START_WATCHDOG:
		PUSH.L	ER1
		MOV.L	@LIFE_MS, ER1			;   startTimeout();
		MOV.L	ER1, @TIME_STAMP
		POP.L	ER1
		RTS

;------------------------------------------------
;	I2C_CHK_WATCHDOG
;	OUT	C-FLAG : 1:TIME OUT
;------------------------------------------------
I2C_CHK_WATCHDOG:
		PUSH.L	ER2
		PUSH.L	ER3
		MOV.L	@LIFE_MS, ER2
		MOV.L	@TIME_STAMP, ER3
		SUB.L	ER3,ER2
		BPL	I2C_CHK_WATCHDOG_L1
		NEG.L	ER2				; ER2 = ER2-ER3 + 1WRAP(0xFFFFFFFF
I2C_CHK_WATCHDOG_L1:
		CMP.W	#WD_TIME, R2			; ER2 - MAX > 0 --> TIMEOUT
		ANDC	#H'FE, CCR
		BMI	I2C_CHK_WATCHDOG_L2
		BSET	R_LED
		ORC	#1, CCR
I2C_CHK_WATCHDOG_L2:
		POP.L	ER3
		POP.L	ER2
		RTS

;=================================================
	.SECTION PDATA, DATA, ALIGN=2

TIME_STAMP	.RES.L	1

	.END
