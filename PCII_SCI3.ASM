;===== RS232C I/F ========================================
;	h8/3694
;				toya@v007.vaio.ne.jp
; 2400bps 8N1
; オーバーランエラー処理はなし。
; オーバーラン、受信バッファ制御は、HALOを参考にした方がよい

	.FORM	COL=120
	.PRINT	LIST		;アセンブル時にリストファイルを出力する
	.CPU 300HN		;ＣＰＵの指定

	.INCLUDE "io.inc"

	.IMPORT	TIME00

	.EXPORT	SCI3_PARAM_INIT
	.EXPORT	SCI3_RX_RESET
	.EXPORT	SCI3_INIT
	.EXPORT	SCI3_HOST_INIT
	.EXPORT	SCI3
	.EXPORT GET_CHAR
	.EXPORT SEND_CHAR
	.EXPORT SEND_BYTE
	.EXPORT SEND_WORD
	.EXPORT SEND_MSG

BUFF_SIZE	.EQU	16

;------	SCI用 シンボル -----
TIE	.BEQU	7,SCR3		; TX INTERRUPT ENABLE
RIE	.BEQU	6,SCR3		; RX INTERRUPT ENABLE
TE	.BEQU	5,SCR3		; TX ENABLE
RE	.BEQU	4,SCR3		; RX ENABLE
MPIE	.BEQU	3,SCR3		; MULTIPROCESSOR INTERRUPT ENABLE
TEIE	.BEQU	2,SCR3		; TX END INTERRUPT ENABLE
CKE1	.BEQU	1,SCR3		; CLOCK SELECT
CKE0	.BEQU	0,SCR3		; CLOCK SELECT

TDRE	.BEQU	7,SSR		; 送信データ空
RDRF	.BEQU	6,SSR		; 受信データフル
OER	.BEQU	5,SSR		; 受信オーバーラン
FER	.BEQU	4,SSR		; 受信フレームエラー
PER	.BEQU	3,SSR		; 受信パリティエラー
TEND	.BEQU	2,SSR		; 送信終了
MPBR	.BEQU	1,SSR		; Multi Processor Bit
MPBT	.BEQU	0,SSR		; Multi Processor Bit TR

;=================================================
	.SECTION ROM, CODE, ALIGN=2
;-------------------------------------------------
;	初期化処理
;-------------------------------------------------
SCI3_PARAM_INIT:
SCI3_RX_RESET:
		PUSH.L	ER0
		MOV.L	#RX_BUFF, ER0
		MOV.L	ER0, @RX_BUFF_SP
		MOV.L	ER0, @RX_BUFF_EP
		POP.L	ER0
		RTS

;------	I/O CONTROL ------
SCI3_INIT:	PUSH.L	ER0
		MOV.B	#H'00, R0L
		MOV.B	R0L, @SCR3		; TIE,RIE,TE,RE,MPIE,TEIE=OFF
		MOV.B	#H'01, R0L		; H8/3694
		MOV.B	R0L, @SMR		; 8bit,nop,1stop, clk=1
		MOV.B	#64, R0L		; H8/3694
		MOV.B	R0L, @BRR		; Select Bit rate 2400
		JSR	@TIME00			; Wait 1 cycle

		MOV.B	#B'01110000, R0L	; TIE=OFF,RIE=TE=RE=ON
		MOV.B	R0L, @SCR3
		MOV.L	#PMR1, ER0
		BSET	#1 ,@ER0		; TXD = 1
		MOV.B	@SSR, R0L		; DUMMY
		AND.B	#B'10000110, R0L
		MOV.B	R0L, @SSR		; SSR ALL Clear
		POP.L	ER0
		RTS

;------	I/O CONTROL ------
SCI3_HOST_INIT:	PUSH.L	ER0
		MOV.B	#H'00, R0L
		MOV.B	R0L, @SCR3		; TIE,RIE,TE,RE,MPIE,TEIE=OFF
		MOV.B	#H'0, R0L		; H8/3694
		MOV.B	R0L, @SMR		; 8bit,nop,1stop, clk=0
		MOV.B	#32, R0L		; H8/3694
		MOV.B	R0L, @BRR		; Select Bit rate 19200
		JSR	@TIME00			; Wait 1 cycle

		MOV.B	#B'01110000, R0L	; TIE=OFF,RIE=TE=RE=ON
		MOV.B	R0L, @SCR3
		MOV.L	#PMR1, ER0
		BSET	#1 ,@ER0		; TXD = 1
		MOV.B	@SSR, R0L		; DUMMY
		AND.B	#B'10000110, R0L
		MOV.B	R0L, @SSR		; SSR ALL Clear
		POP.L	ER0
		RTS

;------------------------------------------------
;	送信処理
;------------------------------------------------
;------	SEND CHAR DATA ----
SEND_CHAR:	BTST	TDRE
		BEQ	SEND_CHAR		; 本当は、バッファ処理が必要。
		MOV.B	R0L, @TDR
		RTS

;------	SEND HEX BYTE DATA ----
SEND_BYTE:	PUSH.W	R0
		PUSH.W	R0
		SHLR.B	R0L
		SHLR.B	R0L
		SHLR.B	R0L
		SHLR.B	R0L
		CMP.B	#H'09, R0L
		BLS	SEND_BYTE_L1
		ADD.B	#H'07, R0L
SEND_BYTE_L1:	ADD.B	#H'30, R0L
		BSR	SEND_CHAR
		POP.W	R0
		AND.B	#H'0F, R0L
		CMP.B	#H'09, R0L
		BLS	SEND_BYTE_L2
		ADD.B	#H'07, R0L
SEND_BYTE_L2:	ADD.B	#H'30, R0L
		BSR	SEND_CHAR
		POP.W	R0
		RTS

;------	SEND HEX WORD DATA ----
SEND_WORD:	PUSH.W	R0
		PUSH.W	R0
		MOV.B	R0H, R0L
		JSR	@SEND_BYTE
		POP.W	R0
		JSR	@SEND_BYTE
		POP.W	R0
		RTS

;------	SEND MSG ----
; IN : R0 = MESSAGE ADDRESS (NULL END)
;
SEND_MSG:	PUSH.L	ER0
		PUSH.L	ER1
		MOV.L	ER0, ER1
SHOW_MSG_L1:	MOV.B	@R1+, R0L
		BEQ	SHOW_MSG_END
		BSR	SEND_CHAR
		JMP	@SHOW_MSG_L1
SHOW_MSG_END:	POP.L	ER1
		POP.L	ER0
		RTS

;------------------------------------------------
;	受信バッファからの1文字取得
;  INPUT  : NONE
;  OUTPUT : R0L : DATA, R0H : (0)OK, (-1)NO DATA
;------------------------------------------------
GET_CHAR:	PUSH.L	ER1
		PUSH.L	ER2
		MOV.L	@RX_BUFF_SP, ER1
		MOV.L	@RX_BUFF_EP, ER2
		CMP.L	ER1, ER2
		BNE	GET_CHAR_L1
		MOV.B	#H'FF, R0H		; NO DATA
		JMP	@GET_CHAR_END
GET_CHAR_L1:
		MOV.B	#0, R0H			; GETTING CHAR IS SUCEED.
		MOV.B	@ER1+, R0L
		CMP.L	#RX_BUFF_END, ER1	; CHECK END OF BUFFER.
		BNE	GET_CHAR_L2		; NOT END OF BUFFER.
		MOV.L	#RX_BUFF, ER1		; SHIFT TO TOP OF LOOP BUFFER
GET_CHAR_L2:	MOV.L	ER1, @RX_BUFF_SP
GET_CHAR_END:	POP.L	ER2
		POP.L	ER1
		RTS

;------------------------------------------------
;	受信バッファに入っているデータ数取得
;  INPUT  : NONE
;  OUTPUT : R0L : COUNT OF DATA
;------------------------------------------------
GET_DATA_CNT:	PUSH.W	E0
		PUSH.L	ER1
		MOV.L	@RX_BUFF_SP, ER1
		MOV.L	@RX_BUFF_EP, ER0
		MOV.W	#0,E0
		MOV.W	E0,E1
		CMP.L	ER1, ER0		; CHK END POINTER - START POINTER
		BPL	GET_DATA_CNT_L1		; IF WRAP
		ADD.L	#BUFF_SIZE, ER0
GET_DATA_CNT_L1:
		SUB.L	ER1, ER0
		POP.L	ER1
		POP.W	E0
		RTS

;------------------------------------------------
;  受信処理：割り込み処理からの呼び出し
;------------------------------------------------
RXI1_START:	PUSH.W	R0
		PUSH.L	ER1
		PUSH.L	ER2

		MOV.L	@RX_BUFF_EP, ER1	; 受信バッファ文字列の終端
		MOV.B	@RDR, R0L		; GET 1 BTYE DATA
		MOV.B	R0L, @ER1

		INC.L	#1, ER1
		MOV.L	#RX_BUFF_END, ER2	; CHECK END OF VALID BUFFER
		CMP.L	ER1, ER2
		BNE	RXI1_L1			; NOT END OF LOOP BUFFER.
		MOV.L	#RX_BUFF, ER1		; WRAPPED.
RXI1_L1:	MOV.L	@RX_BUFF_SP, ER2	; CHECK OVER FLOW
		CMP.L	ER1, ER2		; CHECK RX_BUFF_SP == RX_BUFF_EP?
		BEQ	RXI1_END		; BUFFER OVER FLOW
		MOV.L	ER1, @RX_BUFF_EP	; SAVE END POINTER.
RXI1_END:	POP.L	ER2
		POP.L	ER1
		POP.W	R0
		RTS

;=================================================
	.SECTION INT_CODE, CODE, ALIGN=2
;-------------------------------------------------
;	割り込み処理
;-------------------------------------------------
SCI3:		PUSH.L	ER0			;レジスタの待避
		BCLR	RIE			; 受信割り込み禁止

		MOV.B	@SSR, R0L		; DUMMY

		BTST	OER			; OVER-RUN
		BEQ	SCI3_L1
		BCLR	OER
SCI3_L1:	BTST	FER			; FRAME ERR
		BEQ	SCI3_L2
		BCLR	FER
SCI3_L2:	BTST	PER			; PARITY ERR
		BEQ	SCI3_L3
		BCLR	PER
SCI3_L3:	BTST	RDRF
		BEQ	SCI3_L4
		BCLR	RDRF			; 受信バッファフルフラグクリア
		JSR	@RXI1_START		; 受信開始
SCI3_L4:	BTST	TEND			; TX EMPTY
		BEQ	SCI3_E
		BCLR	TEND
SCI3_E:
		BSET	RIE
		POP.L	ER0			;レジスタの復帰
		RTE				;割り込みからの復帰

;=================================================
	.SECTION PDATA, DATA, ALIGN=2

RX_BUFF_SP	.RES.L	1
RX_BUFF_EP	.RES.L	1
		.ALIGN 2
RX_BUFF		.RES.B	BUFF_SIZE
RX_BUFF_END

TX_BUFF_SP	.RES.L	1
TX_BUFF_EP	.RES.L	1
TX_BUFF		.RES.B	BUFF_SIZE
TX_BUFF_E
TX_BUFF_OVE_CNT	.RES.W	1

	.END
