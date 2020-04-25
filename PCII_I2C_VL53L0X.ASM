;===== I2C I/F ========================================
;	h8/3694
;				toya@v007.vaio.ne.jp
;	VL53L0X
;	REG FF: バンク番号?
;======================================================

	.FORM	COL=120
	.PRINT	LIST	
	.CPU 300HN	

	.INCLUDE "io.inc"
	.INCLUDE "vl53l0x.inc"

	.IMPORT		I2C_INIT
	.IMPORT		I2C_WRITE_DATA
	.IMPORT		I2C_START
	.IMPORT		I2C_STOP
	.IMPORT		I2C_BUSY_WAIT
	.IMPORT		I2C_MASTER_SEND
	.IMPORT		I2C_MASTER_RCV

	.IMPORT		LIFE_MS

	.EXPORT		VL53L0X_init
	.EXPORT		VL53L0X_DATA_init

	.EXPORT		VL53L0X_OFFSET
	.EXPORT		VL53L0X_GET_DATA1_Async
	.EXPORT		VL53L0X_GET_DATA1_Async_WD

	.EXPORT		VL53L0X_SUS
	.EXPORT		VL53L0X_SUS_MM
	.EXPORT		VL53L0X_GET_RATE
	.EXPORT		VL53L0X_RATE
	.EXPORT		SUS_LOG
	.EXPORT		SUS_LOG_STATE

RCVD		.EQU	6	; ICCR1
ACKBR		.EQU	1	; ICIER
ACKBT		.EQU	0	; ICIER
RDRF		.EQU	5	; ICSR

TIMEOUT_P	.EQU	200	; 200 x 1.638ms (3694)

SUS_LOGSIZE	.EQU	64

R_LED		.BEQU	1,PDR1
G_LED		.BEQU	2,PDR1

;=================================================
	.SECTION ROM, CODE, ALIGN=2

;------------------------------------------------
;	init
;	IN  R1L:2V8 MODE	0:1V8(DEFAULT), 1:2V8
;	    R0L:ADDRESS
;	BREAK  ER4
;------------------------------------------------
VL53L0X_DATA_init:
		PUSH.W	R0
		MOV.W	#0, R0
		MOV.B	R0L, @VL53L0X_STATE
		MOV.W	R0, @SUS1_OFFSET
		MOV.W	R0, @SUS2_OFFSET
		MOV.W	R0, @SUS1_MIN
		MOV.W	R0, @SUS2_MIN
		MOV.W	R0, @SUS1_MAX
		MOV.W	R0, @SUS2_MAX
		MOV.B	R0L, @SUS_RATE
		MOV.B	R0L, @SUS_LOG_STATE
		POP.W	R0
		RTS

VL53L0X_init:
		PUSH.W	R0
		PUSH.W	R1
		PUSH.W	R2

		MOV.B	R0L, @SLAVE_ADDRESS
		MOV.B	#0, R2L
		MOV.B	R2L, @ReadRSingleAsnycSem
		MOV.B	#1, R2L
		MOV.B	R2L, @VL53L0X_STATE

;---	// VL53L0X_DataInit() begin
		CMP.B	#0, R1L
		BEQ	VL53L0X_init_L1
		MOV.B	#VHV_CFG_PAD_SCL_SDA__EXTSUP_HV, R0H
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg
		BSET	#0, R1L
		MOV.B	#VHV_CFG_PAD_SCL_SDA__EXTSUP_HV, R0H
		JSR	@VL53L0X_writeReg
VL53L0X_init_L1:
;---	// "Set I2C standard mode"
		MOV.B	#H'88, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'80, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'91, R0H
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg 		; read = 3C
		MOV.B	R1L, @STOP_VARIABLE
		MOV.B	#H'00, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'80, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#MSRC_CFG_CONTROL, R0H		; H'60
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg  		; read = 00
		OR.B	#H'12, R1L
		MOV.B	#MSRC_CFG_CONTROL, R0H		; H'60
		JSR	@VL53L0X_writeReg		; 12

		MOV.W	#32,R1				; 0.25 * 128
		JSR	@VL53L0X_setSignalRateLimit

		MOV.B	#SYSTEM_SEQUENCE_CONFIG, R0H	; H'01
		MOV.B	#H'FF, R1L
		JSR	@VL53L0X_writeReg
;---	// VL53L0X_DataInit() end
;---	// VL53L0X_StaticInit() begin
		JSR	@VL53L0X_getSpadInfo

		MOV.B	#GLOBAL_CFG_SPAD_ENABLES_REF_0, R0H	; H'B0
		MOV.B	#6, R1L
		MOV.L	#SPAD_MAP, ER2
		JSR	@VL53L0X_readMulti

;---	// -- VL53L0X_set_reference_spads() begin (assume NVM values are valid)
		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#DYNAMIC_SPAD_REF_EN_START_OFFSET, R0H	; H'4F
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#DYNAMIC_SPAD_NUM_REQD_REF_SPAD, R0H	; H'4E
		MOV.B	#H'2C, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#GLOBAL_CFG_REF_EN_START_SELECT, R0H	; H'B6
		MOV.B	#H'B4, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#0, R3L			; FIRST_SPAD_ENABLED
		MOV.B	@SPAD_COUNT, R3H
		BTST	#7, R3H			; BIT7 -> C
		BEQ	VL53L0X_init_SPAD_L0
		MOV.B	#12, R3L		; R3L = FIRST_SPAD_ENABLED

VL53L0X_init_SPAD_L0:
		AND.B	#H'7F, R3H		; R3H = SPAD_COUNT
		MOV.B	#0, R2H			; LOCAL SPADS_ENABLED
		MOV.B	#0, R2L			; LOOP COUNTER I
VL53L0X_init_SPAD_L1:
		MOV.L	#SPAD_MAP, ER4
		MOV.L	#0, ER1
		MOV.B	R2L, R1L
		SHLR.B	R1L
		SHLR.B	R1L
		SHLR.B	R1L
		ADD.L	ER1, ER4		; @ER4 = SPAD_MAP[i / 8]

		CMP.B	R2L, R3L		; R2I < R2H (I < FIRST_SPAD_ENABLED ) --> THEN
		BHI	VL53L0X_init_SPAD_L2_TH
		CMP.B	R2H, R3H		; R2H == R3H (spads_enabled == spad_count) --> THEN
		BNE	VL53L0X_init_SPAD_L2_EL
VL53L0X_init_SPAD_L2_TH:
;	      ref_spad_map[i / 8] &= ~(1 << (i % 8));
		MOV.B	R2L, R1L		; I
		AND.B	#H'7, R1L
		MOV.B	#H'FF, R1H
		BCLR	R1L, R1H		; ~(1 << (i % 8));
		MOV.B	@ER4, R1L		; ref_spad_map[i / 8]
		AND.B	R1H, R1L
		MOV.B	R1L, @ER4		; ref_spad_map[i / 8] &=
		JMP	@VL53L0X_init_SPAD_L5
VL53L0X_init_SPAD_L2_EL:
;	else if ((ref_spad_map[i / 8] >> (i % 8)) & 0x1)
		MOV.B	@ER4, R1H		; ref_spad_map[i / 8]
		MOV.B	R2L, R1L		; I
		AND.B	#H'7, R1L		; %8
		BTST	R1L, R1H		; (ref_spad_map[i / 8] >> (i % 8)) & 0x1
		BEQ	VL53L0X_init_SPAD_L5
;	      spads_enabled++;
		INC.B	R2H			;
VL53L0X_init_SPAD_L5:
		INC.B	R2L			; I++
		CMP.B	#48, R2L
		BNE	VL53L0X_init_SPAD_L1

		MOV.B	#GLOBAL_CFG_SPAD_ENABLES_REF_0, R0H	; H'B0
		MOV.B	#6, R1L
		MOV.L	#SPAD_MAP, ER2
		JSR	@VL53L0X_writeMulti

;---	// -- VL53L0X_set_reference_spads() end
;---	// -- VL53L0X_load_tuning_settings() begin

		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'09, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'10, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'11, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'24, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'25, R0H
		MOV.B	#H'FF, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'75, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'4E, R0H
		MOV.B	#H'2C, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'48, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'30, R0H
		MOV.B	#H'20, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'30, R0H
		MOV.B	#H'09, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'54, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'31, R0H
		MOV.B	#H'04, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'32, R0H
		MOV.B	#H'03, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'40, R0H
		MOV.B	#H'83, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'46, R0H
		MOV.B	#H'25, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'60, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'27, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'50, R0H
		MOV.B	#H'06, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'51, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'52, R0H
		MOV.B	#H'96, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'56, R0H
		MOV.B	#H'08, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'57, R0H
		MOV.B	#H'30, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'61, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'62, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'64, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'65, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'66, R0H
		MOV.B	#H'A0, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'22, R0H
		MOV.B	#H'32, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'47, R0H
		MOV.B	#H'14, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'49, R0H
		MOV.B	#H'FF, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'4A, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'7A, R0H
		MOV.B	#H'0A, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'7B, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'78, R0H
		MOV.B	#H'21, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'23, R0H
		MOV.B	#H'34, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'42, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'44, R0H
  		MOV.B	#H'FF, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'45, R0H
  		MOV.B	#H'26, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'46, R0H
  		MOV.B	#H'05, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'40, R0H
		MOV.B	#H'40, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'0E, R0H
  		MOV.B	#H'06, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'20, R0H
  		MOV.B	#H'1A, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'43, R0H
		MOV.B	#H'40, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'34, R0H
  		MOV.B	#H'03, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'35, R0H
  		MOV.B	#H'44, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'31, R0H
  		MOV.B	#H'04, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'4B, R0H
  		MOV.B	#H'09, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'4C, R0H
  		MOV.B	#H'05, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'4D, R0H
  		MOV.B	#H'04, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'44, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'45, R0H
  		MOV.B	#H'20, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'47, R0H
  		MOV.B	#H'08, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'48, R0H
  		MOV.B	#H'28, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'67, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'70, R0H
  		MOV.B	#H'04, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'71, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'72, R0H
  		MOV.B	#H'FE, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'76, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'77, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'0D, R0H		; !!!
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'80, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
  		MOV.B	#H'01, R0H
  		MOV.B	#H'F8, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'8E, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'80, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg

;---	// -- VL53L0X_load_tuning_settings() end
;---	// -- VL53L0X_SetGpioConfig() begin
		MOV.B	#SYSTEM_INTERRUPT_CFG_GPIO, R0H		; H'0A
		MOV.B	#H'04,R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#GPIO_HV_MUX_ACTIVE_HIGH, R0H		; H'84
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg			; <- 1
		AND.B	#H'EF, R1L
		MOV.B	#GPIO_HV_MUX_ACTIVE_HIGH, R0H		; H'84
		JSR	@VL53L0X_writeReg
		MOV.B	#SYSTEM_INTERRUPT_CLEAR, R0H		; H'0B
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
;---	// -- VL53L0X_SetGpioConfig() end

		JSR	@getMeasurementTimingBudget
;		MOV.L	ER1, @M_TIMING_BUDGET_US		; DONE IN getMeasurementTimingBudget()

		MOV.B	#SYSTEM_SEQUENCE_CONFIG, R0H		; H'01
		MOV.B	#H'E8, R1L
		JSR	@VL53L0X_writeReg

		MOV.L	@M_TIMING_BUDGET_US, ER1
		JSR	@setMeasurementTimingBudget

		MOV.B	#SYSTEM_SEQUENCE_CONFIG, R0H		; H'01
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'40, R1L
		JSR	@VL53L0X_performSingle
		BCS	VL53L0X_init_ERR

		MOV.B	#SYSTEM_SEQUENCE_CONFIG, R0H		; H'01
		MOV.B	#H'02, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_performSingle
		BCS	VL53L0X_init_ERR

		MOV.B	#SYSTEM_SEQUENCE_CONFIG, R0H		; H'01
		MOV.B	#H'E8, R1L
		JSR	@VL53L0X_writeReg

		MOV.L	#STANDARD_SPEED, ER1
		JSR	@setMeasurementTimingBudget

		MOV.B	#2, R2L
		MOV.B	R2L, @VL53L0X_STATE			; INIT END
		JMP	@VL53L0X_init_END
VL53L0X_init_ERR:
		MOV.B	#0, R2L
		MOV.B	R2L, @VL53L0X_STATE			; INIT END
VL53L0X_init_END:
		POP.W	R2
		POP.W	R1
		POP.W	R0
		RTS

;------------------------------------------------
;	I2C_CHK_TIMEOUT
;	OUT	fLAG INDICATES MINUS = NOT TIMEOUT
;------------------------------------------------

;------------------------------------------------
;	VL53L0X_START_WATCHDOG
;------------------------------------------------
VL53L0X_START_WATCHDOG:
		PUSH.L	ER1
		MOV.L	@LIFE_MS, ER1			;   startTimeout();
		MOV.L	ER1, @VL53L0X_TIME_STAMP
		POP.L	ER1
		RTS

;------------------------------------------------
;	VL53L0X_CHK_WATCHDOG
;	OUT	VL53L0X_STATE
;------------------------------------------------
VL53L0X_CHK_WATCHDOG:
		PUSH.L	ER2
		PUSH.L	ER3
		MOV.L	@LIFE_MS, ER2
		MOV.L	@VL53L0X_TIME_STAMP, ER3
		SUB.L	ER3,ER2
		BPL	VL53L0X_CHK_WATCHDOG_L1
		NEG.L	ER2				; ER2 = ER2-ER3 + 1WRAP(0xFFFFFFFF
VL53L0X_CHK_WATCHDOG_L1:
		CMP.L	#TIMEOUT_P, ER2			; ER2 - MAX > 0 --> TIMEOUT
		BMI	VL53L0X_CHK_WATCHDOG_L2
		MOV.B	#0, R0L
		MOV.B	R0L, @VL53L0X_STATE
		BSET	R_LED
VL53L0X_CHK_WATCHDOG_L2:
		POP.L	ER3
		POP.L	ER2
		RTS

;------------------------------------------------
;	writeReg(uint8_t reg, uint8_t value)
;	IN  R1L:VALUE
;	    R0L:ADDRESS
;	    R0H:REGISTER
;------------------------------------------------
VL53L0X_writeReg:
		PUSH.L	ER0
		PUSH.W	R1
		MOV.W	R0, E0

		JSR	@I2C_BUSY_WAIT
		BCS	VL53L0X_writeReg_END
		JSR	@I2C_MASTER_SEND
		JSR	@I2C_START

		MOV.W	E0, R0				; R0L VL53L0X ADDRESS
		JSR	@I2C_WRITE_DATA			; ACK = OK(0) -> Z-flag = 1
		BCS	VL53L0X_writeReg_ERR		; Z-flag(1)=OK  -> BNE ERR
		MOV.B	R0H, R0L			; REGISTER
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_writeReg_ERR
		MOV.B	R1L, R0L			; VALUE
		JSR	@I2C_WRITE_DATA
VL53L0X_writeReg_ERR:
		JSR	@I2C_STOP
VL53L0X_writeReg_END:
		POP.W	R1
		POP.L	ER0
		RTS

;------------------------------------------------
;	writeReg16Bit(uint8_t reg, uint16_t value)
;	IN  R1:VALUE
;	    R0L:ADDRESS
;	    R0H:REGISTER
;------------------------------------------------
VL53L0X_writeReg16:
		PUSH.L	ER0
		PUSH.W	R1
		MOV.W	R0, E0

		JSR	@I2C_BUSY_WAIT
		BCS	VL53L0X_writeReg16_END
		JSR	@I2C_MASTER_SEND
		JSR	@I2C_START

		MOV.W	E0, R0				; R0L VL53L0X ADDRESS
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_writeReg16_ERR
		MOV.B	R0H, R0L			; REGISTER
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_writeReg16_ERR
		MOV.B	R1H, R0L			; VALUE
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_writeReg16_ERR
		MOV.B	R1L, R0L			; VALUE
		JSR	@I2C_WRITE_DATA
VL53L0X_writeReg16_ERR:
		JSR	@I2C_STOP
VL53L0X_writeReg16_END:
		POP.W	R1
		POP.L	ER0
		RTS

;------------------------------------------------
;	writeReg32Bit(uint8_t reg, uint32_t value)
;	IN  ER1:VALUE
;	    R0L:ADDRESS
;	    R0H:REGISTER
;------------------------------------------------
VL53L0X_writeReg32:

		PUSH.L	ER0
		PUSH.L	ER1
		MOV.W	R0, E0

		JSR	@I2C_BUSY_WAIT
		BCS	VL53L0X_writeReg32_END
		JSR	@I2C_MASTER_SEND
		JSR	@I2C_START

		MOV.W	E0, R0				; R0L VL53L0X ADDRESS
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_writeReg32_ERR
		MOV.B	R0H, R0L			; REGISTER
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_writeReg32_ERR
		MOV.W	E1, R0				; VALUE
		MOV.B	R0H, R0L			; VALUE
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_writeReg32_ERR
		MOV.W	E1, R0				; VALUE
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_writeReg32_ERR
		MOV.B	R1H, R0L			; VALUE
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_writeReg32_ERR
		MOV.B	R1L, R0L			; VALUE
		JSR	@I2C_WRITE_DATA
VL53L0X_writeReg32_ERR:
		JSR	@I2C_STOP
VL53L0X_writeReg32_END:
		POP.L	ER1
		POP.L	ER0
		RTS

;------------------------------------------------
;	readData(int length:1..4)
;	IN  R1L:length
;	OUT ER1:data (1byte:R1L ... 4bytes:ER1)
;------------------------------------------------
VL53L0X_readData:
		PUSH.W	R0
		PUSH.W	R2
		PUSH.W	R3

VL53L0X_readData_READ:
		CMP.B	#1, R1L
		BEQ	VL53L0X_readData_LAST

		MOV.B	@ICCR1, R0L
		BCLR	#RCVD, R0L		; 受信を継続
		MOV.B	R0L,@ICCR1
		MOV.B	@ICIER, R0L
		BCLR	#ACKBT, R0L		; 受信を継続するときは、ACK=0
		MOV.B	R0L,@ICIER
		JMP	@VL53L0X_readData_READ_START
VL53L0X_readData_LAST:
		MOV.B	@ICCR1, R0L
		BSET	#RCVD, R0L		; 次のデータ受信で停止
		MOV.B	R0L,@ICCR1
		MOV.B	@ICIER, R0L
		BSET	#ACKBT, R0L		; 受信を終了するときは、ACK=1
		MOV.B	R0L,@ICIER
		NOP
VL53L0X_readData_READ_START
		JSR	@I2C_MASTER_RCV
		MOV.B	@ICDRR, R0L		; DUMMY READ

VL53L0X_readData_READ2:
		CMP.B	#1, R1L
		BEQ	VL53L0X_readData_LAST2

		MOV.B	@ICCR1, R0L
		BCLR	#RCVD, R0L		; 受信を継続
		MOV.B	R0L,@ICCR1
		MOV.B	@ICIER, R0L
		BCLR	#ACKBT, R0L		; 受信を継続するときは、ACK=0
		MOV.B	R0L,@ICIER
		JMP	@VL53L0X_readData_BYTE
VL53L0X_readData_LAST2:
		MOV.B	@ICCR1, R0L
		BSET	#RCVD, R0L		; 次のデータ受信で停止
		MOV.B	R0L,@ICCR1
		MOV.B	@ICIER, R0L
		BSET	#ACKBT, R0L		; 受信を終了するときは、ACK=1
		MOV.B	R0L,@ICIER
		NOP


VL53L0X_readData_BYTE:
		JSR	@VL53L0X_START_WATCHDOG
VL53L0X_readData_BYTE_L1:
		JSR	@VL53L0X_CHK_WATCHDOG
		MOV.B	@VL53L0X_STATE, R0H
		BEQ	VL53L0X_readData_END
		MOV.B	@ICSR, R0L
		BTST	#RDRF, R0L		; RDRF(5)
		BEQ	VL53L0X_readData_BYTE_L1

		MOV.B	@ICDRR, R0L
		MOV.B	R3L, R3H
		MOV.B	R2H, R3L
		MOV.B	R2L, R2H
		MOV.B	R0L, R2L
		DEC.B	R1L
		BNE	VL53L0X_readData_READ

VL53L0X_readData_END:
		JSR	@I2C_STOP
		MOV.B	@ICCR1, R0L
		BCLR	#RCVD, R0L
		MOV.B	R0L,@ICCR1

		MOV.W	R3, E1
		MOV.W	R2, R1
		POP.W	R3
		POP.W	R2
		POP.W	R0
		RTS

;;;VL53L0X_readData:
;;;		PUSH.W	R0
;;;		PUSH.W	R2
;;;		PUSH.W	R3
;;;
;;;		MOV.B	@ICCR1, R0L
;;;		BCLR	#RCVD, R0L		; 受信を継続
;;;		MOV.B	R0L,@ICCR1
;;;		MOV.B	@ICIER, R0L
;;;		BCLR	#ACKBT, R0L		; 受信を継続するときは、ACK=0
;;;		MOV.B	R0L,@ICIER
;;;		JSR	@I2C_MASTER_RCV
;;;		MOV.B	@ICDRR, R0L		; DUMMY READ
;;;
;;;VL53L0X_readData_BYTE:
;;;		MOV.B	@ICSR, R0L
;;;		BTST	#RDRF, R0L		; RDRF(5)
;;;		BEQ	VL53L0X_readData_BYTE
;;;
;;;		CMP.B	#1, R1L
;;;		BEQ	VL53L0X_readData_LAST
;;;		MOV.B	@ICCR1, R0L
;;;		BCLR	#RCVD, R0L		; 受信を継続
;;;		MOV.B	R0L,@ICCR1
;;;		MOV.B	@ICIER, R0L
;;;		BCLR	#ACKBT, R0L		; 受信を継続するときは、ACK=0
;;;		MOV.B	R0L,@ICIER
;;;		JMP	@VL53L0X_readData_READ
;;;VL53L0X_readData_LAST:
;;;		MOV.B	@ICCR1, R0L
;;;		BSET	#RCVD, R0L		; 次のデータ受信で停止
;;;		MOV.B	R0L,@ICCR1
;;;		MOV.B	@ICIER, R0L
;;;		BSET	#ACKBT, R0L		; 受信を終了するときは、ACK=1
;;;		MOV.B	R0L,@ICIER
;;;		NOP
;;;VL53L0X_readData_READ:
;;;		MOV.B	@ICDRR, R0L
;;;		MOV.B	R3L, R3H
;;;		MOV.B	R2H, R3L
;;;		MOV.B	R2L, R2H
;;;		MOV.B	R0L, R2L
;;;		DEC.B	R1L
;;;		BNE	VL53L0X_readData_BYTE
;;;
;;;		JSR	@I2C_STOP
;;;		MOV.B	@ICCR1, R0L
;;;		BCLR	#RCVD, R0L
;;;		MOV.B	R0L,@ICCR1
;;;
;;;		MOV.W	R3, E1
;;;		MOV.W	R2, R1
;;;		POP.W	R3
;;;		POP.W	R2
;;;		POP.W	R0
;;;		RTS

;------------------------------------------------
;	readReg(ADDRESS, REGISTER, LENGTH)
;	IN  R0L:ADDRESS
;	    R0H:REGISTER
;	    R1L:LENGTH
;	OUT ER1:VALUE
;------------------------------------------------
VL53L0X_readReg:
		PUSH.L	ER0
		PUSH.W	R2
		MOV.W	R0, E0

		JSR	@I2C_BUSY_WAIT
		BCS	VL53L0X_readReg_END
		JSR	@I2C_MASTER_SEND
		JSR	@I2C_START

		MOV.W	E0, R0			; R0L VL53L0X ADDRESS
		MOV.W	R0, R2			; COPY ADDRESS
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_readReg_ERR_STOP
		MOV.B	R0H, R0L		; REGISTER
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_readReg_ERR_STOP
		JSR	@I2C_START
		MOV.W	R2, R0			; COPY ADDRESS
		OR.B	#H'01, R0L		; READ ADDRESS
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_readReg_ERR_STOP
		JSR	@VL53L0X_readData	; R1l length
		JMP	@VL53L0X_readReg_END
VL53L0X_readReg_ERR_STOP:
		JSR	@I2C_STOP
VL53L0X_readReg_END:
		POP.W	R2
		POP.L	ER0
		RTS

;------------------------------------------------
;	writeMulti(uint8_t reg, uint8_t const * src, uint8_t count)
;	IN  R0L:ADDRESS
;	    R0H:REGISTER
;	    R1L:LENGTH
;	    ER2:MEMORY ADDRESS
;------------------------------------------------
VL53L0X_writeMulti:
		PUSH.L	ER0
		PUSH.W	R1
		PUSH.L	ER2
		MOV.W	R0, E0

		JSR	@I2C_BUSY_WAIT
		BCS	VL53L0X_writeMulti_END2
		JSR	@I2C_MASTER_SEND
		JSR	@I2C_START

		MOV.W	E0, R0			; R0L VL53L0X ADDRESS
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_writeMulti_END
		MOV.B	R0H, R0L		; REGISTER
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_writeMulti_END

VL53L0X_writeMulti_BYTE:
		MOV.B	@ER2+, R0L
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_writeMulti_END
		DEC.B	R1L
		BNE	VL53L0X_writeMulti_BYTE
VL53L0X_writeMulti_END:
		JSR	@I2C_STOP
VL53L0X_writeMulti_END2:
		POP.L	ER2
		POP.W	R1
		POP.L	ER0
		RTS

;------------------------------------------------
;	readMulti(uint8_t reg, uint8_t * dst, uint8_t count)
;	IN  R0L:ADDRESS
;	    R0H:REGISTER
;	    R1L:LENGTH
;	    ER2:MEMORY ADDRESS
;------------------------------------------------
VL53L0X_readMulti:
		PUSH.L	ER0
		PUSH.W	R1
		PUSH.W	R3
		PUSH.L	ER2
		MOV.W	R0, E0

		JSR	@I2C_BUSY_WAIT
		BCC	VL53L0X_readMulti_L1
		JMP	@VL53L0X_readMulti_ERR
VL53L0X_readMulti_L1:
		JSR	@I2C_MASTER_SEND
		JSR	@I2C_START

		MOV.W	E0, R0			; R0L VL53L0X ADDRESS
		MOV.W	R0, R3			; COPY ADDRESS
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_readMulti_END
		MOV.B	R0H, R0L		; REGISTER
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_readMulti_END

		JSR	@I2C_START
		MOV.W	R3, R0			; COPY ADDRESS
		OR.B	#H'01, R0L		; READ ADDRESS
		JSR	@I2C_WRITE_DATA
		BCS	VL53L0X_readMulti_END

		MOV.W	R1, R0			; SIZE

		MOV.B	@ICCR1, R0L
		BCLR	#RCVD, R0L		; 受信を継続
		MOV.B	R0L,@ICCR1
		MOV.B	@ICIER, R0L
		BCLR	#ACKBT, R0L		; 受信を継続するときは、ACK=0
		MOV.B	R0L,@ICIER
		JSR	@I2C_MASTER_RCV
		MOV.B	@ICDRR, R0L		; DUMMY READ

VL53L0X_readMulti_BYTE:
		MOV.B	@ICSR, R0L
		BTST	#RDRF, R0L		; RDRF(5)
		BEQ	VL53L0X_readMulti_BYTE

		CMP.B	#1, R1L
		BEQ	VL53L0X_readMulti_LAST
		MOV.B	@ICCR1, R0L
		BCLR	#RCVD, R0L		; 受信を継続
		MOV.B	R0L,@ICCR1
		MOV.B	@ICIER, R0L
		BCLR	#ACKBT, R0L		; 受信を継続するときは、ACK=0
		MOV.B	R0L,@ICIER
		JMP	@VL53L0X_readMulti_READ
VL53L0X_readMulti_LAST:
		MOV.B	@ICCR1, R0L
		BSET	#RCVD, R0L		; 次のデータ受信で停止
		MOV.B	R0L,@ICCR1
		MOV.B	@ICIER, R0L
		BSET	#ACKBT, R0L		; 受信を終了するときは、ACK=1
		MOV.B	R0L,@ICIER
		NOP
VL53L0X_readMulti_READ:
		MOV.B	@ICDRR, R0L
		MOV.B	R0L, @ER2
		INC.L	#1, ER2
		DEC.B	R1L
		BNE	VL53L0X_readMulti_BYTE
VL53L0X_readMulti_END:
		JSR	@I2C_STOP
VL53L0X_readMulti_ERR:
		POP.L	ER2
		POP.W	R3
		POP.W	R1
		POP.L	ER0
		RTS

;------------------------------------------------
;	setSignalRateLimit(float limit_Mcps)
;	VL53L0X.CPPのコードに対して、元から7ビット左シフトしておくこと
;	IN  R0L:ADDRESS
;	    R1:limit_Mcps
;------------------------------------------------
VL53L0X_setSignalRateLimit
		PUSH.W	R0
		MOV.B	#FIN_RANGE_CFG_MIN_C_RATE_RTN_LMT, R0H	; H'44
		JSR	@VL53L0X_writeReg16
		POP.W	R0
		RTS

;------------------------------------------------
;	getSignalRateLimit(void)
;	IN     R0L:ADDRESS
;	OUT    ER1
;	VL53L0X.CPPのコードに対して、7ビット左シフトされた値
;------------------------------------------------
VL53L0X_getSignalRateLimit
		PUSH.W	R0
		MOV.B	#FIN_RANGE_CFG_MIN_C_RATE_RTN_LMT, R0H	; H'44
		MOV.B	#2, R1L
		JSR	@VL53L0X_readReg
		POP.W	R0
		RTS

;------------------------------------------------
;	setMeasurementTimingBudget(uint32_t budget_us)
;	IN ER1 : M_TIMING_BUDGET_US or BUDGET_US
;	BROKEN  ER5
;------------------------------------------------
StartOverhead_SET	.EQU	1320
StartOverhead_GET	.EQU	1910
EndOverhead		.EQU	960
MsrcOverhead		.EQU	660
TccOverhead		.EQU	590
DssOverhead		.EQU	690
PreRangeOverhead	.EQU	660
FinalRangeOverhead	.EQU	550
MinTimingBudget		.EQU	20000
HIGH_SPEED		.EQU	20000
STANDARD_SPEED		.EQU	25000
HIGH_ACCURACY		.EQU	200000

;ENABLES_TCC	.BEQU	4, R1L	; enables->tcc          = (sequence_config >> 4) & 0x1;
;ENABLES_DSS	.BEQU	3, R1L	; enables->dss          = (sequence_config >> 3) & 0x1;
;ENABLES_MSRC	.BEQU	2, R1L	; enables->msrc         = (sequence_config >> 2) & 0x1;
;ENABLES_PRE_R	.BEQU	6, R1L	; enables->pre_range    = (sequence_config >> 6) & 0x1;
;ENABLES_FINAL_R	.BEQU	7, R1L	; enables->final_range  = (sequence_config >> 7) & 0x1;

setMeasurementTimingBudget:
		PUSH.W	R0
		PUSH.L	ER1
		PUSH.L	ER2
		PUSH.L	ER3	; used_budget_us
		PUSH.L	ER4	; final_range_timeout_us
;;;		PUSH.L	ER5

;	if (budget_us < MinTimingBudget) { return FALSE; }
		CMP.L	#MinTimingBudget, ER1
		BCC	setMeasurementTimingBudget_L0
		MOV.L	#MinTimingBudget, ER1

setMeasurementTimingBudget_L0:	
		MOV.L	ER1, ER5		; ER5 : budget_us
;	  used_budget_us = StartOverhead + EndOverhead;
		MOV.L	#StartOverhead_SET, ER3		; ER3 = used_budget_us
		ADD.L	#EndOverhead, ER3		; ER3 = used_budget_us

;	  VL53L0X_getSequenceStepEnables(&enables);
		MOV.B	#SYSTEM_SEQUENCE_CONFIG, R0H	; H'01
		MOV.B	#1, R1L				; BROKEN R1
		JSR	@VL53L0X_readReg  		; R1L  <-E8
		MOV.B	R1L, @ENABLES

;	  VL53L0X_getSequenceStepTimeouts(&enables, &timeouts);
		JSR	@VL53L0X_getSequenceStepTimeouts

;	  if (enables.tcc)
;	  {
;		used_budget_us += (timeouts.msrc_dss_tcc_us + TccOverhead);
;	  }

		MOV.B	@ENABLES, R1L
		BTST	#4, R1L	; enables->tcc          = (sequence_config >> 4) & 0x1;
		BEQ	setMeasurementTimingBudget_L1
		MOV.L	@MSRC_DSS_TCC_US, ER2
		ADD.L	ER2, ER3
		ADD.L	#TccOverhead, ER3		; ER3 = used_budget_us

setMeasurementTimingBudget_L1:
;	  if (enables.dss)
;	  {
;		used_budget_us += 2 * (timeouts.msrc_dss_tcc_us + DssOverhead);
;	  }
;	  else if (enables.msrc)
;	  {
;		used_budget_us += (timeouts.msrc_dss_tcc_us + MsrcOverhead);
;	  }
		MOV.B	@ENABLES, R1L
		BTST	#3, R1L	; enables->dss          = (sequence_config >> 3) & 0x1;
		BEQ	setMeasurementTimingBudget_L2
		MOV.L	@MSRC_DSS_TCC_US, ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
		MOV.L	#DssOverhead, ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
setMeasurementTimingBudget_L2:
		BTST	#2, R1L	; enables->msrc         = (sequence_config >> 2) & 0x1;
		BEQ	setMeasurementTimingBudget_L3
		MOV.L	@MSRC_DSS_TCC_US, ER2
		ADD.L	ER2, ER3
		ADD.L	#MsrcOverhead, ER3

setMeasurementTimingBudget_L3:
;	  if (enables.pre_range)
;	  {
;		used_budget_us += (timeouts.pre_range_us + PreRangeOverhead);
;	  }
		BTST	#6, R1L	; enables->pre_range    = (sequence_config >> 6) & 0x1;
		BEQ	setMeasurementTimingBudget_L4
		MOV.L	@PRE_R_US, ER2
		ADD.L	ER2, ER3
		ADD.L	#PreRangeOverhead, ER3

setMeasurementTimingBudget_L4:
;	  if (enables.final_range)
		BTST	#7, R1L	; enables->final_range  = (sequence_config >> 7) & 0x1;
		BEQ	setMeasurementTimingBudget_E
;	  {
;		used_budget_us += FinalRangeOverhead;
		ADD.L	#FinalRangeOverhead, ER3
;
;		// "Note that the final range timeout is determined by the timing
;		// budget and the sum of all other timeouts within the sequence.
;		// If there is no room for the final range timeout, then an error
;		// will be set. Otherwise the remaining time will be applied to
;		// the final range."
;
;		if (used_budget_us > budget_us)
;		{
;		  // "Requested timeout too big."
;		  return FALSE;
;		}
		CMP.L	ER3, ER5		; ER3:used_budget_us, ER5:budget_us
		BCS	setMeasurementTimingBudget_EE
;
;		final_range_timeout_us = budget_us - used_budget_us;
		MOV.L	ER5, ER4
		SUB.L	ER3, ER4		; ER4 =final_range_timeout_us

;   final_range_timeout_mclks =
;		VL53L0X_timeoutMicrosecondsToMclks(final_range_timeout_us,
;                                timeouts.final_range_vcsel_period_pclks);
		PUSH.L	ER1
		MOV.L	ER4, ER1
		MOV.W	@FINAL_R_VCSEL_PP, R2
		JSR	@_timeoutMicrosecondsToMclks	; RESULT : R1 = final_range_timeout_mclks
		MOV.W	R1, R2					; R2 = final_range_timeout_mclks
		POP.L	ER1

;    if (enables.pre_range)
;    {
;      final_range_timeout_mclks += timeouts.pre_range_mclks;
;    }
		BTST	#6, R1L	; enables->pre_range    = (sequence_config >> 6) & 0x1;
		BEQ	setMeasurementTimingBudget_L5
		MOV.W	@PRE_R_MCLKS, R1
		ADD.W	R1, R2

setMeasurementTimingBudget_L5:
;   VL53L0X_writeReg16Bit(FINAL_RANGE_CONFIG_TIMEOUT_MACROP_HI,
;		VL53L0X_encodeTimeout(final_range_timeout_mclks));
		MOV.W	R2, R1
		JSR	@VL53L0X_encodeTimeout
		MOV.B	#FIN_RANGE_CFG_TIMEOUT_MACROP_HI, R0H	; H'71		!!!
		JSR	@VL53L0X_writeReg16			; H'1CB / H'2A5

;    measurement_timing_budget_us = budget_us; // store for internal reuse
		MOV.L	ER5, @M_TIMING_BUDGET_US

setMeasurementTimingBudget_E:
setMeasurementTimingBudget_EE:
;;;		POP.L	ER5
		POP.L	ER4
		POP.L	ER3
		POP.L	ER2
		POP.L	ER1
		POP.W	R0
		RTS

;------------------------------------------------
; uint32_t VL53L0X_getMeasurementTimingBudget(void)
;	OUT NONE: 	BEFORE RETURN, THE DATA IS WRITTEN IN THE MEMORY.
;------------------------------------------------
getMeasurementTimingBudget:
		PUSH.W	R0
		PUSH.W	R1
		PUSH.L	ER2
		PUSH.L	ER3	; budget_us

;  uint32_t budget_us = StartOverhead + EndOverhead;
		MOV.L	#StartOverhead_GET, ER3
		ADD.L	#EndOverhead, ER3

;  VL53L0X_getSequenceStepEnables(&enables);
;;  uint8_t sequence_config = VL53L0X_readReg(SYSTEM_SEQUENCE_CONFIG);

		MOV.B	#SYSTEM_SEQUENCE_CONFIG, R0H	; H'01
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg  		; R1L <- F8
		MOV.B	R1L, @ENABLES
;   VL53L0X_getSequenceStepTimeouts(&enables, &timeouts);
		JSR	@VL53L0X_getSequenceStepTimeouts

; if (enables.tcc)
;  {
;    budget_us += (timeouts.msrc_dss_tcc_us + TccOverhead);
;  }

		MOV.B	@ENABLES, R1L
		BTST	#4, R1L	; enables->tcc          = (sequence_config >> 4) & 0x1;
		BEQ	getMeasurementTimingBudget_L1
		MOV.L	@MSRC_DSS_TCC_US, ER2
		ADD.L	ER2, ER3
		ADD.L	#TccOverhead, ER3

getMeasurementTimingBudget_L1:
;  if (enables.dss)
;  {
;    budget_us += 2 * (timeouts.msrc_dss_tcc_us + DssOverhead);
;  }
;  else if (enables.msrc)
;  {
;    budget_us += (timeouts.msrc_dss_tcc_us + MsrcOverhead);
;  }
		MOV.B	@ENABLES, R1L
		BTST	#3, R1L	; enables->dss          = (sequence_config >> 3) & 0x1;
		BEQ	getMeasurementTimingBudget_L2
		MOV.L	@MSRC_DSS_TCC_US, ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
		MOV.L	#DssOverhead, ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
getMeasurementTimingBudget_L2:
		BTST	#2, R1L	; enables->msrc         = (sequence_config >> 2) & 0x1;
		BEQ	getMeasurementTimingBudget_L3
		MOV.L	@MSRC_DSS_TCC_US, ER2
		ADD.L	ER2, ER3
		ADD.L	#MsrcOverhead, ER3

getMeasurementTimingBudget_L3:
;  if (enables.pre_range)
;  {
;    budget_us += (timeouts.pre_range_us + PreRangeOverhead);
;  }
		BTST	#6, R1L	; enables->pre_range    = (sequence_config >> 6) & 0x1;
		BEQ	getMeasurementTimingBudget_L4
		MOV.L	@PRE_R_US, ER2
		ADD.L	ER2, ER3
		ADD.L	#PreRangeOverhead, ER3

getMeasurementTimingBudget_L4:
;  if (enables.final_range)
;  {
;    budget_us += (timeouts.final_range_us + FinalRangeOverhead);
;  }
		BTST	#7, R1L	; enables->final_range  = (sequence_config >> 7) & 0x1;
		BEQ	getMeasurementTimingBudget_L5
		MOV.L	@FINAL_R_US, ER2
		ADD.L	ER2, ER3
		ADD.L	#FinalRangeOverhead, ER3

getMeasurementTimingBudget_L5:
;  measurement_timing_budget_us = budget_us; // store for internal reuse
;  return budget_us;
		MOV.L	ER3, @M_TIMING_BUDGET_US

		POP.L	ER3
		POP.L	ER2
		POP.W	R1
		POP.W	R0
		RTS

;------------------------------------------------
; uint8_t VL53L0X_getVcselPulsePeriod(enum vcselPeriodType type)
;	getVcselPulsePeriod(vcselPeriodType type)
;	IN  R0L:ADDRESS
;	    R1L:vcselPeriodType type
;------------------------------------------------

; enum vcselPeriodType { VcselPeriodPreRange, VcselPeriodFinalRange };
VcselPeriodPreRange	.EQU	0
VcselPeriodFinalRange	.EQU	1

VL53L0X_getVcselPulsePeriod:
		PUSH.W	R0
		PUSH.W	R2
		PUSH.W	R1

		MOV.B	#PRE_RANGE_CFG_VCSEL_PERIOD, R0H	; H'50
		CMP.B	#VcselPeriodPreRange, R1L
		BEQ	_getVcselPulsePeriod_READREG
		MOV.B	#FIN_RANGE_CFG_VCSEL_PERIOD, R0H	; H'70
		CMP.B	#VcselPeriodFinalRange, R1L
		BEQ	_getVcselPulsePeriod_READREG
		MOV.B	#255, R2L
		JMP	@_getVcselPulsePeriod_E
_getVcselPulsePeriod_READREG:
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg		; h'50->06 h'70->4
		INC.B	R1L			; decodeVcselPeriod: (((reg_val) + 1) << 1)
		ADD.B	R1L, R1L	
		MOV.B	R1L, R2L
_getVcselPulsePeriod_E:
		POP.W	R1
		MOV.B	R2L, R1L
		POP.W	R2
		POP.W	R0
		RTS

;------------------------------------------------
;	startCont(uint32_t period_ms)
;	IN  R0L:ADDRESS
;	    ER1:period_ms
;------------------------------------------------
VL53L0X_startCont:
		PUSH.W	R0
		PUSH.W	R1
		PUSH.L	ER2
		PUSH.L	ER1
		
		MOV.B	#H'80, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'91, R0H
		MOV.B	@STOP_VARIABLE, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'80, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg

		POP.L	ER2		; INSTED OF ER1
		CMP.L	#0, ER2
		BEQ	VL53L0X_startCont_BTB
		
		MOV.B	#OSC_CALIBRATE_VAL, R0H		; H'F8
		MOV.B	#2, R1L
		JSR	@VL53L0X_readReg
		CMP.W	#0, R1
		BEQ	VL53L0X_startCont_L1
		MULXU.W	R1, ER2			; ER1 = R1 * R0
VL53L0X_startCont_L1:
		MOV.L	ER2, ER1
		MOV.B	#SYSTEM_INTERMEASUREMENT_PERIOD, R0H	; H'04
		JSR	@VL53L0X_writeReg32
		MOV.B	#SYSRANGE_START, R0H		; H'00
		MOV.B	#H'04, R1L
		JSR	@VL53L0X_writeReg
		JMP	@VL53L0X_startCont_END
VL53L0X_startCont_BTB:
		MOV.B	#SYSRANGE_START, R0H		; H'00
		MOV.B	#H'02, R1L
		JSR	@VL53L0X_writeReg

VL53L0X_startCont_END:
		POP.L	ER2
		POP.W	R1
		POP.W	R0
		RTS

;------------------------------------------------
;	stopCont(void)
;	IN  R0L:ADDRESS
;------------------------------------------------
VL53L0X_stopCont:
		PUSH.W	R0
		PUSH.W	R1

		MOV.B	#SYSRANGE_START, R0H	; H'00
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'91, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		POP.W	R1
		POP.W	R0
		RTS

;------------------------------------------------
;	readRangeContMillimeters(void)
;	IN	R0L:ADDRESS
;	OUT	R1: DATA
;------------------------------------------------
VL53L0X_readRangeCont:
		PUSH.W	R0
		JSR	@VL53L0X_START_WATCHDOG

VL53L0X_readRangeCont_L1:
		MOV.B	#RS_INTERRUPT_STATUS, R0H	; H'13
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg		; h'40
		AND.B	#7, R1L
		BNE	VL53L0X_readRangeCont_L3

		JSR	@VL53L0X_CHK_WATCHDOG
		MOV.B	@VL53L0X_STATE, R0H
		BNE	VL53L0X_readRangeCont_L1
		MOV.W	#-1, R1
		JMP	@VL53L0X_readRangeCont_END
VL53L0X_readRangeCont_L3:
		MOV.B	#RS_RANGE_STATUS, R0H		; H'14
		ADD.B	#10, R0H
		MOV.B	#2, R1L
		JSR	@VL53L0X_readReg

		PUSH.W	R1				; DATA
		MOV.B	#SYSTEM_INTERRUPT_CLEAR, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		POP.W	R1
VL53L0X_readRangeCont_END:
		POP.W	R0
		RTS

;------------------------------------------------
;	readRangeSingleMillimeters(void)
;	IN	R0L:ADDRESS
;	OUT	R1: DATA
;------------------------------------------------
VL53L0X_readRangeSingleMi:
		PUSH.W	R0

		MOV.B	#H'80, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'91, R0H
		MOV.B	@STOP_VARIABLE, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'80, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#SYSRANGE_START, R0H	; H'00
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg

;---	// "Wait until start bit has been cleared"
		JSR	@VL53L0X_START_WATCHDOG

VL53L0X_readRangeSingle_L1:
		MOV.B	#SYSRANGE_START, R0H	; H'00
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg
		BTST	#0, R1L
		BEQ	VL53L0X_readRangeSingle_GET
		JSR	@VL53L0X_CHK_WATCHDOG
		MOV.B	@VL53L0X_STATE, R0H
		BNE	VL53L0X_readRangeSingle_L1
		MOV.W	#-1, R1
		JMP	@VL53L0X_readRangeSingle_END
VL53L0X_readRangeSingle_GET
		JSR	@VL53L0X_readRangeCont
VL53L0X_readRangeSingle_END:
		POP.W	R0
		RTS

;------------------------------------------------
;	readRangeSingleMillimeters(void)の非同期版
;	IN	R0L:ADDRESS
;	OUT	R1: DATA    (-1:RUNNING, -2:ERR)
;------------------------------------------------
VL53L0X_readRangeSingleMi2:
		PUSH.W	R0
		PUSH.L	ER2
		PUSH.L	ER3

		MOV.B	@ReadRSingleAsnycSem, R1L
		BNE	VL53L0X_readRangeSingleMi2_CONT		; 0なら、動作していない

		MOV.B	#H'80, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'91, R0H
		MOV.B	@STOP_VARIABLE, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'80, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#SYSRANGE_START, R0H	; H'00
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg

;---	// "Wait until start bit has been cleared"
VL53L0X_readRangeSingleMi2_L1:
		MOV.B	#SYSRANGE_START, R0H	; H'00
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg
		BTST	#0, R1L
		BEQ	VL53L0X_readRangeSingleMi2_GET
		MOV.W	#-2, R1
		JMP	@VL53L0X_readRangeSingleMi2_END
VL53L0X_readRangeSingleMi2_GET:
		MOV.B	#H'01, R1L
		MOV.B	R1L, @ReadRSingleAsnycSem
VL53L0X_readRangeSingleMi2_CONT:
		MOV.B	#RS_INTERRUPT_STATUS, R0H	; H'13
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg		; h'40
		AND.B	#7, R1L
		BNE	VL53L0X_readRangeSingleMi2_L2
		MOV.W	#-1, R1
		JMP	@VL53L0X_readRangeSingleMi2_END
VL53L0X_readRangeSingleMi2_L2:
		MOV.B	#RS_RANGE_STATUS, R0H		; H'14
		ADD.B	#10, R0H
		MOV.B	#2, R1L
		JSR	@VL53L0X_readReg
		PUSH.W	R1				; DATA
		MOV.B	#SYSTEM_INTERRUPT_CLEAR, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'0, R1L
		MOV.B	R1L, @ReadRSingleAsnycSem
		POP.W	R1

VL53L0X_readRangeSingleMi2_END:
		POP.L	ER3
		POP.L	ER2
		POP.W	R0
		RTS


VL53L0X_readRangeSingleMi2_WD:
		PUSH.W	R0
		PUSH.L	ER2
		PUSH.L	ER3

		MOV.B	@ReadRSingleAsnycSem, R1L
		BEQ	VL53L0X_readRangeSingleMi2_WD_E		; 0なら、動作していない

		MOV.B	#RS_INTERRUPT_STATUS, R0H	; H'13
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg		; h'40
		AND.B	#7, R1L
		BNE	VL53L0X_readRangeSingleMi2_WD_L2
		MOV.W	#-1, R1
		JMP	@VL53L0X_readRangeSingleMi2_WD_E
VL53L0X_readRangeSingleMi2_WD_L2:
		MOV.B	#RS_RANGE_STATUS, R0H		; H'14
		ADD.B	#10, R0H
		MOV.B	#2, R1L
		JSR	@VL53L0X_readReg
		PUSH.W	R1				; DATA
		MOV.B	#SYSTEM_INTERRUPT_CLEAR, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'0, R1L
		MOV.B	R1L, @ReadRSingleAsnycSem
		POP.W	R1

VL53L0X_readRangeSingleMi2_WD_E:
		POP.L	ER3
		POP.L	ER2
		POP.W	R0
		RTS





;------------------------------------------------
;	getSpadInfo(uint8_t * count, bool * type_is_aperture)
;	IN   R0L:ADDRESS
;	OUT  @SPAD_COUNT	 (BIT7:BOOLEAN, 1:OVER)
;------------------------------------------------
VL53L0X_getSpadInfo:
		PUSH.W	R0
		PUSH.W	R1
		PUSH.L	ER2
		PUSH.L	ER3

		MOV.B	#H'80, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'06, R1L
		JSR	@VL53L0X_writeReg

		MOV.B	#H'83, R0H
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg	; 1
		OR.B	#H'04, R1L
		MOV.B	#H'83, R0H
		JSR	@VL53L0X_writeReg	; 5
		MOV.B	#H'FF, R0H
		MOV.B	#H'07, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'81, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'80, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'94, R0H
		MOV.B	#H'6B, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'83, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg

		JSR	@VL53L0X_START_WATCHDOG

VL53L0X_getSpadInfo_L1:
		MOV.B	#H'83, R0H
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg		; 10
		CMP.B	#0, R1L
		BNE	VL53L0X_getSpadInfo_L3
		JSR	@VL53L0X_CHK_WATCHDOG
		MOV.B	@VL53L0X_STATE, R0H
		BNE	VL53L0X_getSpadInfo_L1
		JMP	@VL53L0X_getSpadInfo_END

VL53L0X_getSpadInfo_L3:
		MOV.B	#H'83, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'92, R0H
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg		; 6
;  *count = tmp & 0x7f;
;  *type_is_aperture = (tmp >> 7) & 0x01;
;	@SPAD_COUNT has 2 data.
		MOV.B	R1L, @SPAD_COUNT

		MOV.B	#H'81, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'06, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'83, R0H
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg		; 5
		AND.B	#H'FB, R1L
		MOV.B	#H'83, R0H
		JSR	@VL53L0X_writeReg		; 1
		MOV.B	#H'FF, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'00, R0H
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'FF, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#H'80, R0H
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
VL53L0X_getSpadInfo_END:
		POP.L	ER3
		POP.L	ER2
		POP.W	R1
		POP.W	R0
		RTS

;------------------------------------------------
;	getSequenceStepTimeouts(SequenceStepEnables const * enables, SequenceStepTimeouts * timeouts)
;	IN	R1L  : ENABLES
;	OUT	NONE : (MEMORY timeouts)
;------------------------------------------------
VL53L0X_getSequenceStepTimeouts:
		PUSH.W	R1
		PUSH.L	ER2
		PUSH.L	ER3
		PUSH.W	R1

; timeouts->pre_range_vcsel_period_pclks = VL53L0X_getVcselPulsePeriod(VcselPeriodPreRange);
		MOV.B	#VcselPeriodPreRange, R1L
		JSR	@VL53L0X_getVcselPulsePeriod
		MOV.B	#0, R1H
		MOV.W	R1, @PRE_R_VCSEL_PP	; H'14

; timeouts->msrc_dss_tcc_mclks = VL53L0X_readReg(MSRC_CONFIG_TIMEOUT_MACROP) + 1;
		MOV.B	#MSRC_CFG_TIMEOUT_MACROP, R0H	; H'46
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg	;H'25
		INC.B	R1L
		MOV.B	#0, R1H
		MOV.W	R1, @MSRC_DSS_TCC_MCLKS	; H'26

;  timeouts->msrc_dss_tcc_us =
;    VL53L0X_timeoutMclksToMicroseconds(timeouts->msrc_dss_tcc_mclks, timeouts->pre_range_vcsel_period_pclks);
		MOV.W	@MSRC_DSS_TCC_MCLKS, R1
		MOV.W	@PRE_R_VCSEL_PP, R2
		MOV.B	R2L, R1H
		JSR	@_timeoutMclksToMicroseconds
		MOV.L	ER1, @MSRC_DSS_TCC_US

;  timeouts->pre_range_mclks =
;    VL53L0X_decodeTimeout(VL53L0X_readReg16Bit(PRE_RANGE_CONFIG_TIMEOUT_MACROP_HI));
		MOV.B	#PRE_RANGE_CFG_TIMEOUT_MACROP_HI, R0H	; H'51
		MOV.B	#2, R1L
		JSR	@VL53L0X_readReg  		; H'4B  / H'1CB
		JSR	@VL53L0X_decodeTimeout
		MOV.W	R1, @PRE_R_MCLKS

;  timeouts->pre_range_us =
;    VL53L0X_timeoutMclksToMicroseconds(timeouts->pre_range_mclks,
;                               timeouts->pre_range_vcsel_period_pclks);
		MOV.W	@PRE_R_MCLKS, R1
		MOV.W	@PRE_R_VCSEL_PP, R2
		MOV.B	R2L, R1H
		JSR	@_timeoutMclksToMicroseconds
		MOV.L	ER1, @PRE_R_US

;  timeouts->final_range_vcsel_period_pclks = VL53L0X_getVcselPulsePeriod(VcselPeriodFinalRange);
		MOV.B	#VcselPeriodFinalRange, R1L
		JSR	@VL53L0X_getVcselPulsePeriod
		MOV.B	#0, R1H
		MOV.W	R1, @FINAL_R_VCSEL_PP	; H'10

;  timeouts->final_range_mclks =
;    VL53L0X_decodeTimeout(VL53L0X_readReg16Bit(FINAL_RANGE_CONFIG_TIMEOUT_MACROP_HI));
		MOV.B	#FIN_RANGE_CFG_TIMEOUT_MACROP_HI, R0H	; H'71
		MOV.B	#2, R1L
		JSR	@VL53L0X_readReg	; H'1FE
		JSR	@VL53L0X_decodeTimeout
		MOV.W	R1, @FINAL_R_MCLKS

;  if (enables->pre_range)
;  {
;    timeouts->final_range_mclks -= timeouts->pre_range_mclks;
;  }
		POP.W	R1
		BTST	#6, R1L	; enables->pre_range    = (sequence_config >> 6) & 0x1;
		BEQ	_getSequenceStepTimeouts_L1
		MOV.W	@FINAL_R_MCLKS, R3
		MOV.W	@PRE_R_MCLKS, R2
		SUB.W	R2, R3
		MOV.W	R3, @FINAL_R_MCLKS

_getSequenceStepTimeouts_L1:
;  timeouts->final_range_us =
;    VL53L0X_timeoutMclksToMicroseconds(timeouts->final_range_mclks,
;                               timeouts->final_range_vcsel_period_pclks);
		MOV.B	@FINAL_R_MCLKS, R1L
		MOV.B	@FINAL_R_VCSEL_PP, R1H
		JSR	@_timeoutMclksToMicroseconds
		MOV.L	ER1, @FINAL_R_US

		POP.L	ER3
		POP.L	ER2
		POP.W	R1
		RTS

;------------------------------------------------
;	uint16_t VL53L0X_decodeTimeout(uint16_t reg_val)
;	IN  R1 : reg_val
;	OUT R1 : DECODE
;------------------------------------------------
VL53L0X_decodeTimeout:
		PUSH.W	R2
;  return (uint16_t)((reg_val & 0x00FF) <<
;        (uint16_t)((reg_val & 0xFF00) >> 8)) + 1;
		MOV.W	#0, R2
		MOV.B	R1H, R2L
		MOV.B	#0, R1H
		CMP.B	#0, R2L
		BEQ	VL53L0X_decodeTimeout_L2
VL53L0X_decodeTimeout_L1:
		SHAL.W	R1
		DEC.B	R2L
		BNE	VL53L0X_decodeTimeout_L1
VL53L0X_decodeTimeout_L2:
		ADD.W	#2, R1
		POP.W	R2
		RTS

;------------------------------------------------
;	uint16_t VL53L0X_encodeTimeout(uint16_t timeout_mclks)
;	IN  R1 : timeout_mclks
;	OUT R1 : ENCODE
;------------------------------------------------
VL53L0X_encodeTimeout:		;  // format: "(LSByte * 2^MSByte) + 1"
		PUSH.W	R2
		CMP.W	#0, R1
		BEQ	VL53L0X_encodeTimeout_E

		DEC.W	#1, R1
		MOV.B	#0, R2L
VL53L0X_encodeTimeout_L2:
		AND.B	#H'FF, R1H
		BEQ	VL53L0X_encodeTimeout_L3
		INC.B	R2L
		SHLR.W	R1
		JMP	@VL53L0X_encodeTimeout_L2
VL53L0X_encodeTimeout_L3:
		MOV.B	R2L, R1H
VL53L0X_encodeTimeout_E:
		POP.W	R2
		RTS

;------------------------------------------------
;	uint32_t VL53L0X_timeoutMclksToMicroseconds(uint16_t timeout_period_mclks, uint8_t vcsel_period_pclks)
;	IN  R1L : timeout_period_mclks
;	    R1H : vcsel_period_pclks
;	OUT ER1
;------------------------------------------------
; #define calcMacroPeriod(vcsel_period_pclks) ((((uint32_t)2304 * (vcsel_period_pclks) * 1655) + 500) / 1000)
; (2304 * 1655 * X + 500) / 1000
; (3813120 * X + 500) / 1000
; (3904635 * X + 512) / 1024
; 3904635 = 11 1011 1001 0100 0111 1011
_timeoutMclksToMicroseconds:
		PUSH.L	ER2
		PUSH.L	ER3
		PUSH.L	ER4
;   uint32_t macro_period_ns = calcMacroPeriod(vcsel_period_pclks);
		MOV.L	#0, ER2
		MOV.L	#0, ER3
		MOV.B	R1H, R2L		; calcMacroPeriod(vcsel_period_pclks);
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		SHAL.L	ER2
		SHAL.L	ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		SHAL.L	ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		ADD.L	#512, ER3

		SHAR.L	ER3
		SHAR.L	ER3		; 4
		SHAR.L	ER3
		SHAR.L	ER3		; 16
		SHAR.L	ER3
		SHAR.L	ER3		; 64
		SHAR.L	ER3
		SHAR.L	ER3		; 256
		SHAR.L	ER3
		SHAR.L	ER3		; 1024

;  ((timeout_period_mclks * macro_period_ns) + (macro_period_ns / 2)) / 1000;
		PUSH.L	ER3
		MOV.L	#0, ER2
		MOV.L	#0, ER4
		MOV.B	R1L, R2L	; timeout_period_mclks
		MOV.W	E3, R4
		MOV.W	#0, E3
		MULXU.W	R2, ER3
		MULXU.W	R2, ER4
		MOV.W	R4,E4
		MOV.W	#0, R4
		ADD.L	ER4, ER3
		POP.L	ER4
		SHAR.L	ER4
		ADD.L	ER4, ER3	; ER3 += ER4 * 1/2
		MOV.L	ER3, ER4
		SHAR.L	ER4
		SHAR.L	ER4
		SHAR.L	ER4
		SHAR.L	ER4
		SHAR.L	ER4
		SHAR.L	ER4
		SHAR.L	ER4
		SHAR.L	ER4
		SHAR.L	ER4
		ADD.L	ER4, ER3	; ER3 *= 1.024
		SHAR.L	ER3
		SHAR.L	ER3
		SHAR.L	ER3
		SHAR.L	ER3
		SHAR.L	ER3
		SHAR.L	ER3
		SHAR.L	ER3
		SHAR.L	ER3
		SHAR.L	ER3
		SHAR.L	ER3
		MOV.L	ER3, ER1	; ER3 /= 1024
		POP.L	ER4
		POP.L	ER3
		POP.L	ER2
		RTS

;------------------------------------------------
;	uint32_t VL53L0X_timeoutMicrosecondsToMclks(uint32_t timeout_period_us, uint8_t vcsel_period_pclks)
;	IN  ER1 : timeout_period_us
;	    R2 : vcsel_period_pclks
;	OUT R1  : 
;------------------------------------------------
_timeoutMicrosecondsToMclks:
		PUSH.L	ER2
		PUSH.L	ER3

;  uint32_t macro_period_ns = calcMacroPeriod(vcsel_period_pclks);
; ((((uint32_t)2304 * (vcsel_period_pclks) * 1655) + 500) / 1000)
; (3813120 * X + 500) / 1000
; (3904635 * X + 512) / 1024
; 3904635 = 11 1011 1001 0100 0111 1011
		MOV.W	#0, E2
		MOV.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		SHAL.L	ER2
		SHAL.L	ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		SHAL.L	ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		SHAL.L	ER2
		ADD.L	ER2, ER3
		ADD.L	#512, ER3

		SHAR.L	ER3
		SHAR.L	ER3		; 4
		SHAR.L	ER3
		SHAR.L	ER3		; 16
		SHAR.L	ER3
		SHAR.L	ER3		; 64
		SHAR.L	ER3
		SHAR.L	ER3		; 256
		SHAR.L	ER3
		SHAR.L	ER3		; ER3 : macro_period_ns = (3904635 * vcsel_period_pclks + 512) / 1024;

;  return (((timeout_period_us * 1000) + (macro_period_ns / 2)) / macro_period_ns);
		SHAL.L	ER1
		SHAL.L	ER1
		SHAL.L	ER1
		SHAL.L	ER1
		SHAL.L	ER1
		SHAL.L	ER1
		SHAL.L	ER1
		SHAL.L	ER1
		SHAL.L	ER1
		SHAL.L	ER1		; ER1 = ER1 * 1024
		PUSH.L	ER3
		MOV.L	ER1, ER3
		SHAR.L	ER3
		SHAR.L	ER3
		SHAR.L	ER3
		SHAR.L	ER3
		SHAR.L	ER3
		SHAR.L	ER3
		SUB.L	ER3, ER1
		SHAR.L	ER3
		SUB.L	ER3, ER1	; ER1 = ER1 - ER1 * 0.023
		POP.L	ER3
		PUSH.L	ER3
		SHAR.L	ER3
		ADD.L	ER3, ER1	; ER1 = ER1 + ER3 / 2
		POP.L	ER3
		DIVXU.W	R3, ER1		; ER1 = (ER1 * 1000 + ER3/2) / ER3
		MOV.W	#0, E1

		POP.L	ER3
		POP.L	ER2
		RTS
		
;------------------------------------------------
;	uint8_t VL53L0X_performSingleRefCalibration(uint8_t vhv_init_byte)
;	IN   R0L:ADDRESS
;	     R1L:vhv_init_byte
;	OUT  FLAG[C]
;------------------------------------------------
VL53L0X_performSingle:
		PUSH.W	R0
		PUSH.W	R1
		MOV.B	#SYSRANGE_START, R0H		; H'00
		OR.B	#H'01, R1L
		JSR	@VL53L0X_writeReg

		JSR	@VL53L0X_START_WATCHDOG
VL53L0X_performSingle_L1:
		MOV.B	#RS_INTERRUPT_STATUS, R0H	; H'13
		MOV.B	#1, R1L
		JSR	@VL53L0X_readReg		; H'40
		AND.B	#7, R1L
		BNE	VL53L0X_performSinglef_L3

		JSR	@VL53L0X_CHK_WATCHDOG
		MOV.B	@VL53L0X_STATE, R0H
		BNE	VL53L0X_performSingle_L1
		ORC	#1,CCR
		JMP	@VL53L0X_performSingle_END
VL53L0X_performSinglef_L3:
		MOV.B	#SYSTEM_INTERRUPT_CLEAR, R0H	; H'0B
		MOV.B	#H'01, R1L
		JSR	@VL53L0X_writeReg
		MOV.B	#SYSRANGE_START, R0H		; H'00
		MOV.B	#H'00, R1L
		JSR	@VL53L0X_writeReg
		ANDC	#H'FE,CCR
VL53L0X_performSingle_END:
		POP.W	R1
		POP.W	R0
		RTS

;=================================================
;-------------------------------------------------
;	計測
;-------------------------------------------------
VL53L0X_GET_DATA1:
		PUSH.W	R0
		PUSH.W	R1
		ORC	#h'1, CCR				; C-Flag = 1 FOR ERROR RETURN
		MOV.B	@VL53L0X_STATE, R0L			;I2C ERR
		BEQ	VL53L0X_GET_DATA1_END
VL53L0X_GET_DATA1_L2:
		MOV.B	@SLAVE_ADDRESS, R0L
		JSR	@VL53L0X_readRangeSingleMi
		MOV.W	R1, @SUS1_POS
		JSR	@SET_LOG1
		ANDC	#h'FE, CCR				; C-Flag = 1 FOR ERROR RETURN
VL53L0X_GET_DATA1_END:
		POP.W	R1
		POP.W	R0
		RTS

VL53L0X_GET_DATA1_Async:
		PUSH.W	R0
		PUSH.W	R1
		PUSH.L	ER2
		PUSH.L	ER3
		MOV.B	@VL53L0X_STATE, R0L
		CMP.B	#2, R0L
		BNE	VL53L0X_GET_DATA1_Async_END
		MOV.B	@SLAVE_ADDRESS, R0L
		JSR	@VL53L0X_readRangeSingleMi2
		ORC	#h'1, CCR				; C-Flag = 1 FOR ERROR RETURN
		CMP.W	#-2, R1
		BEQ	VL53L0X_GET_DATA1_Async_END		; ERR
		ANDC	#h'FE, CCR				; C-Flag = 0 FOR NOERR RETURN
		CMP.W	#-1, R1
		BNE	VL53L0X_GET_DATA1_Async_SET
		MOV.B	#3, R0L					; RUNNING
		MOV.B	R0L, @VL53L0X_STATE
		JMP	@VL53L0X_GET_DATA1_Async_END
VL53L0X_GET_DATA1_Async_SET:
		MOV.W	R1, @SUS1_POS

		MOV.W	@SUS1_MIN, R0
		BEQ	VL53L0X_GET_DATA1_Async_MIN
		CMP.W	R0, R1
		BCC	VL53L0X_GET_DATA1_Async_L1
VL53L0X_GET_DATA1_Async_MIN:
		MOV.W	R1, @SUS1_MIN
VL53L0X_GET_DATA1_Async_L1:
		MOV.W	@SUS1_MAX, R0
		BEQ	VL53L0X_GET_DATA1_Async_MAX
		CMP.W	R1, R0
		BCC	VL53L0X_GET_DATA1_Async_LOG
VL53L0X_GET_DATA1_Async_MAX:
		MOV.W	R1, @SUS1_MAX
VL53L0X_GET_DATA1_Async_LOG:
		JSR	@SET_LOG1
		ANDC	#h'FE, CCR				; C-Flag = 1 FOR ERROR RETURN
VL53L0X_GET_DATA1_Async_END:

		POP.L	ER3
		POP.L	ER2
		POP.W	R1
		POP.W	R0
		RTS

VL53L0X_GET_DATA1_Async_WD:
		PUSH.W	R0
		PUSH.W	R1
		PUSH.L	ER2
		PUSH.L	ER3

		MOV.B	@VL53L0X_STATE, R0L
		CMP.B	#3, R0L					; RUNNING?
		BNE	VL53L0X_GET_DATA1_Async_WD_END
		MOV.B	@ReadRSingleAsnycSem, R1L
		BEQ	VL53L0X_GET_DATA1_Async_WD_END		; 0なら、動作していない
		MOV.B	@SLAVE_ADDRESS, R0L
		JSR	@VL53L0X_readRangeSingleMi2_WD
		CMP.W	#-1, R1
		BEQ	VL53L0X_GET_DATA1_Async_WD_END
		MOV.W	R1, @SUS1_POS

		MOV.W	@SUS1_MIN, R0
		BEQ	VL53L0X_GET_DATA1_Async_WD_MIN
		CMP.W	R0, R1
		BCC	VL53L0X_GET_DATA1_Async_WD_L1
VL53L0X_GET_DATA1_Async_WD_MIN:
		MOV.W	R1, @SUS1_MIN
VL53L0X_GET_DATA1_Async_WD_L1:
		MOV.W	@SUS1_MAX, R0
		BEQ	VL53L0X_GET_DATA1_Async_WD_MAX
		CMP.W	R1, R0
		BCC	VL53L0X_GET_DATA1_Async_WD_LOG
VL53L0X_GET_DATA1_Async_WD_MAX:
		MOV.W	R1, @SUS1_MAX
VL53L0X_GET_DATA1_Async_WD_LOG:
		JSR	@SET_LOG1
		MOV.B	#2, R0L					; OK
		MOV.B	R0L, @VL53L0X_STATE
		ANDC	#h'FE, CCR				; C-Flag = 1 FOR ERROR RETURN

VL53L0X_GET_DATA1_Async_WD_END:
		POP.L	ER3
		POP.L	ER2
		POP.W	R1
		POP.W	R0
		RTS

SET_LOG1:						; ログは３バイトづつ（メモリ削減のため）
		PUSH.W	R0
		PUSH.W	R1
		PUSH.L	ER2
		PUSH.L	ER3
		MOV.L	#SUS_LOG, ER3			; SUS1のLOW8bits, SUS2のLOW8bits, SUS1のHIGH4bits+SUS2のHIGH4bits
		MOV.L	ER3, ER2
		ADD.L	#3, ER2				; R2はコピー元で、３バイト先
		MOV.B	#SUS_LOGSIZE, R1L
		DEC.B	R1L
SET_LOG1_L1:
		MOV.B	@ER2, R0L
		MOV.B	R0L, @ER3			; SUS1の下位８ビットは、１バイト目のログ
		ADD.L	#2, ER2
		ADD.L	#2, ER3
		MOV.B	@ER2, R0L			; SUS1の上位４ビットは、3バイト目の上位４ビット
		AND.B	#H'F0, R0L
		MOV.B	@ER3, R0H
		AND.B	#H'0F, R0H
		OR.B	R0L, R0H
		MOV.B	R0H, @ER3
		ADD.L	#1, ER2
		ADD.L	#1, ER3
		DEC.B	R1L
		BNE	SET_LOG1_L1
		JSR	@VL53L0X_SUS
		MOV.B	R0L, @ER3
		INC.L	#2, ER3
		MOV.B	@ER3, R1L
		AND.B	#H'0F, R1L
		SHAL.B	R0L
		SHAL.B	R0L
		SHAL.B	R0L
		SHAL.B	R0L
		OR.B	R0L, R1L
		MOV.B	R1L, @ER3
		MOV.B	#1, R0L
		MOV.B	R0L, @SUS_LOG_STATE		
		POP.L	ER3
		POP.L	ER2
		POP.W	R1
		POP.W	R0
		RTS

;--------------------------------------------------
;	サスの伸縮を返す：オフセットされた後の値
;	OUT	R0:SUS1
;		R1:SUS2
;--------------------------------------------------
VL53L0X_SUS:	PUSH.W	R2
		MOV.W	@SUS1_POS, R0
		MOV.W	@SUS1_OFFSET, R1
		SUB.W	R1, R0
		MOV.W	@SUS2_POS, R2
		MOV.W	@SUS2_OFFSET, R1
		SUB.W	R2, R1
		MOV.B	@SUS_RATE, R2L
		BEQ	VL53L0X_SUS_END
VL53L0X_SUS_L1:
		SHAR.W	R0
		SHAR.W	R1
		DEC.B	R2L
		BNE	VL53L0X_SUS_L1
VL53L0X_SUS_END:
		POP.W	R2
		RTS

;--------------------------------------------------
;	サスの伸縮、最小値、最大値を返す：絶対値
;	OUT	E1:SUS1_POS
;		R1:SUS2_POS
;		E2:SUS1_MAX
;		R2:SUS1_MIN
;		E3:SUS2_MAX
;		R3:SUS2_MIN
;--------------------------------------------------
VL53L0X_SUS_MM:
		MOV.W	@SUS1_POS, E1
		MOV.W	@SUS2_POS, R1
		MOV.W	@SUS1_MIN, R2
		MOV.W	@SUS1_MAX, E2
		MOV.W	@SUS2_MIN, R3
		MOV.W	@SUS2_MAX, E3
		RTS

;--------------------------------------------------
;	サスの現在位置をオフセット値にする
;--------------------------------------------------
VL53L0X_OFFSET:
		PUSH.W	R0
		MOV.W	@SUS1_POS, R0
		MOV.W	R0, @SUS1_OFFSET
		MOV.W	@SUS2_POS, R0
		MOV.W	R0, @SUS2_OFFSET

		MOV.W	#0, R0
		MOV.W	R0, @SUS1_MIN
		MOV.W	R0, @SUS2_MIN
		MOV.W	R0, @SUS1_MAX
		MOV.W	R0, @SUS2_MAX

		POP.W	R0
		RTS

;--------------------------------------------------
;	サスの伸縮数値のレートを変える
;	１回呼ぶと1/2になる。4回で０に戻る
;--------------------------------------------------
VL53L0X_RATE:
		PUSH.W	R2
		MOV.B	@SUS_RATE, R2L
		INC.B	R2L
		AND.B	#03, R2L
		MOV.B	R2L, @SUS_RATE
		POP.W	R2
		RTS

VL53L0X_GET_RATE:
		MOV.B	@SUS_RATE, R0L
		RTS

;=================================================
	.SECTION PDATA, DATA, ALIGN=2


SUS1_OFFSET		.RES.W	1
SUS2_OFFSET		.RES.W	1
SUS1_POS		.RES.W	1
SUS2_POS		.RES.W	1
SUS1_MIN		.RES.W	1		; 絶対値、縮尺なし
SUS2_MIN		.RES.W	1
SUS1_MAX		.RES.W	1
SUS2_MAX		.RES.W	1

			.ALIGN	2
VL53L0X_TIME_STAMP	.RES.L	1

VL53L0X_STATE		.RES.B	1		; 0:ERR, 1:INIT, 2:OK, 3:RUNNING
SUS_RATE		.RES.B	1	; 0:等倍, 1:1/2, 2:1/4, 3:1/8
SUS_LOG			.RES.B	SUS_LOGSIZE	; メモリ削減のため、1.5バイトづつ
			.RES.B	SUS_LOGSIZE	; 1バイト目=SUS1_LOW,2バイト目=SUS2_LOW
			.RES.B	SUS_LOGSIZE	; 3バイト目の下位４ビットがSUS1の上位４ビット
SUS_LOG_STATE		.RES.B	1

SLAVE_ADDRESS		.RES.B	1
STOP_VARIABLE		.RES.B	1

ENABLES			.RES.B	1

			.ALIGN	2
M_TIMING_BUDGET_US	.RES.L	1

; struct SequenceStepTimeouts
PRE_R_VCSEL_PP		.RES.W	1
FINAL_R_VCSEL_PP	.RES.W	1
MSRC_DSS_TCC_MCLKS	.RES.W	1
PRE_R_MCLKS		.RES.W	1
FINAL_R_MCLKS		.RES.W	1
MSRC_DSS_TCC_US		.RES.L	1
PRE_R_US		.RES.L	1
FINAL_R_US		.RES.L	1

SPAD_MAP		.RES.B	6
SPAD_COUNT		.RES.B	1	; COUNT = BIT0-6, BIT7 = TYPE

ReadRSingleAsnycSem	.RES.B	1	; 非同期版のセマフォ １の時、動作中
	.END
