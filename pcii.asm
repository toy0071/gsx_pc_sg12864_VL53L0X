;===== PCII_DISP.ASM ========================================
;	h8 / 3694
;	Power Commander �̃��A���^�C���\��
;				toya@v007.vaio.ne.jp
;
;	TX,RX��Power commander�ɐڑ�
;-------------------------------------------------
;	P50	: LCD CS1
;	P51	: LCD CS2
;	P52	: LCD RST
;	P74	: LCD RS    1:DATA/0:COMMAND
;	P75	: LCD R/W   1:R/0:W
;	P76	: LCD SIG   0:TRIG
;	P80-P87	: LCD-data
;	P11	: RED-LED
;	P12	: GR-LED
;	P14	: Y-SWITCH
;	P15	: B-SWITCH
;	P21,22	; RXD,TXD
;	PB0-PB7	: AN Sensor 1, not use this port, now.

	.FORM	COL=120
	.PRINT	LIST		;�A�Z���u�����Ƀ��X�g�t�@�C�����o�͂���
	.CPU 300HN		;�b�o�t�̎w��

	.INCLUDE "io.inc"
	.INCLUDE "PCII.INC"

	.IMPORT		SCI3_PARAM_INIT
	.IMPORT		SCI3_INIT
	.IMPORT		SCI3

	.IMPORT		I2C_INIT			; PCII_I2C.ASM
	.IMPORT 	EEPROM_CHECK_SW1		; PCII_I2C.ASM
	.IMPORT 	EEPROM_CHECK_SW2		; PCII_I2C.ASM

	.IMPORT		LOAD_PAGE_FROM_EEPROM		; PCII_I2C_EEPROM.ASM
	.IMPORT		EEPROM_FIND_PAGE		; PCII_I2C_EEPROM.ASM
	.IMPORT		EEPROM_INIT			; PCII_I2C_EEPROM.ASM
	.IMPORT		EEPROM_MEM_INFO			; PCII_I2C_EEPROM.ASM
	.IMPORT		EEPROM_FORMAT			; PCII_I2C_EEPROM.ASM
	.IMPORT		EEPROM_ERASE_PAGE		; PCII_I2C_EEPROM.ASM
	.IMPORT		EEPROM_REC_START		; PCII_I2C_EEPROM.ASM
	.IMPORT		EEPROM_REC_STOP			; PCII_I2C_EEPROM.ASM

	.IMPORT		PCII_DATA_INIT
	.IMPORT		PCII_DATA_OFFSET
	.IMPORT		SET_READ_MODE
	.IMPORT		GET_PCII_SIM		; forTEST
	.IMPORT		GET_PCII
	.IMPORT		MON_PCII_INIT
	.IMPORT		MON_PCII

	.IMPORT 	SEND_CHAR

	.IMPORT		IRQ_PARAM_INIT
	.IMPORT		IRQ_INIT
	.IMPORT		SW_CHATTERING_CHK
	.IMPORT		IRQ0_START
	.IMPORT		IRQ1_START
	.IMPORT		IRQ2_START
	.IMPORT		IRQ3_START
	.IMPORT		IRQ_KEEP
	.IMPORT		READ_SW0
	.IMPORT		READ_SW1
	.IMPORT		READ_SW2
	.IMPORT		READ_SW3

	.IMPORT		LAP_DATA_INIT
	.IMPORT		LAP_MON
	.IMPORT		LAP_VIEW_INIT
	.IMPORT		LAP_VIEW
	.IMPORT		LAP_MON_SW1
	.IMPORT		DISP_TIME
	.IMPORT		DISP_MULTI_TIME

	.IMPORT		LCD_INIT
	.IMPORT		LCD_CLR_CS1
	.IMPORT		LCD_CLR_CS2
	.IMPORT		TOP_MENU
	.IMPORT		LCD_PCII_MON
	.IMPORT		LCD_G_MON
	.IMPORT		LCD_G_TRACK_CS2
	.IMPORT		LCD_SUS_TRACK
	.IMPORT		LCD_MULTI_MON
	.IMPORT		LCD_EEPROM_MEM_INFO
	.IMPORT		LCD_I2C_FORMAT_MENU
	.IMPORT		LCD_I2C_FORMAT_CONFIRM
	.IMPORT		LCD_I2C_FORMAT_DOING
	.IMPORT		LCD_I2C_FORMAT_DONE
	.IMPORT		LCD_PCII_DATA_CS1_INIT
	.IMPORT		LCD_PCII_DATA_CS1
	.IMPORT		LCD_OFFSET
	.IMPORT		LCD_TEXT_OFFSET
	.IMPORT		LCD_CHAR
	.IMPORT		LCD_STRING
	.IMPORT		LCD_HEXDATA
	.IMPORT		LCD_LNUM
	.IMPORT		VRAM_CLR
	.IMPORT		VRAM_TO_LCD_CS1
	.IMPORT		VRAM_TO_LCD_CS2
	.IMPORT		VRAM_X_4L
	.IMPORT		VRAM_STRING

	.IMPORT		AD_PRE_INIT
	.IMPORT		AD_INIT
	.IMPORT		AD_INT
	.IMPORT		AD_DISP_PLAY
	.IMPORT		AD_ZERO

	.IMPORT		VL53L0X_init
	.IMPORT		VL53L0X_DATA_init
	.IMPORT		VL53L0X_OFFSET
	.IMPORT		VL53L0X_GET_DATA1_Async
	.IMPORT		VL53L0X_GET_DATA1_Async_WD
	.IMPORT		VL53L0X_RATE

	.IMPORT		SETTING_DISP
	.IMPORT		SETTING_SW1
	.IMPORT		SETTING_SW2

	.EXPORT		TIMEV_CNT
	.EXPORT		LIFE_MS

;-----�V���{���̐ݒ�-----
IENTA		.BEQU	6,IENR1		;�^�C�}�[�`�C�l�[�u���r�b�g
IRRTA		.BEQU	6,IRR1		;�^�C�}�[�`���荞�݃t���O�r�b�g

B_RDRF		.BEQU	6,SSR		; ��M�f�[�^�t��
B_OER		.BEQU	5,SSR		; ��M�I�[�o�[����
B_FER		.BEQU	4,SSR		; ��M�t���[���G���[
B_PER		.BEQU	3,SSR		; ��M�p���e�B�G���[

R_LED		.BEQU	1,PDR1
G_LED		.BEQU	2,PDR1

I2C_DISP_SW1_MAX .EQU	2

;------	���荞�݃x�N�^ -----------------------------
	.SECTION INT_VECT, DATA, ALIGN=2
	.DATA.L	INIT				; INT0 ���荞�݃x�N�^
	.ORG	H'001C
	.DATA.W	IRQ0_START			;
	.DATA.W	IRQ1_START
	.DATA.W	IRQ2_START
	.DATA.W	IRQ3_START
	.ORG	H'0026
	.DATA.W	TIME_A				; �^�C�}�[�`���荞�݃x�N�g��
	.ORG	H'002C
	.DATA.W	TIME_V				; �^�C�}�[�u���荞�݃x�N�g��
	.ORG	H'002e
	.DATA.W	SCI3				; INT23 SCI-3 ���荞��
	.ORG	H'0032
	.DATA.W	AD_INT				; INT23 SCI-3 ���荞��

;----- I/O �̏����ݒ� -----
	.SECTION ROM, CODE, ALIGN=2

INIT:		MOV.L	#S_START,ER7			; �X�^�b�N�|�C���^�ݒ�

		ORC.B	#B'10000000,CCR		; ���荞�݋֎~
		MOV.B	#0, R0L
		MOV.B	R0L, @IENR1		; �S���荞��DISABLE
		MOV.B	R0L, @IRR1		; �S���荞�݃t���O�N���A

		MOV.L	#0,ER0
		MOV.L	ER0,@LIFE_MS
		MOV.L	ER0,@TIMEV_CNT
		MOV.W	R0, @TIMER_PCII
		MOV.B	R0L,@PCII_DISP_MODE
		MOV.B	R0L,@PCII_SW1_MODE
		MOV.B	#01, R0L
		MOV.B	R0L, @TIMER_G_SENSOR
		MOV.B	R0L, @TIMER_SUS
		MOV.B	#H'3,R0L
		MOV.B	R0L,@PCII_INPUT_VALID
		MOV.B	#H'52,R0L
		MOV.B	R0L,@PCII_CMD

		JSR	@PCII_DATA_INIT			; PARAM : R0L
		JSR	@IRQ_PARAM_INIT
		JSR	@SCI3_PARAM_INIT
		JSR	@AD_PRE_INIT
		JSR	@VL53L0X_DATA_init

		JSR	@PORT_INIT
		JSR	@LCD_INIT
		JSR	@TIMEA_INIT
		JSR	@IRQ_INIT
		JSR	@SCI3_INIT		;

		JSR	@AD_INIT
		JSR	@I2C_INIT
		JSR	@EEPROM_INIT

		ANDC.B	#B'01111111,CCR			; ���荞�݃}�X�N�N���A

		JSR	@TIMEV_INIT
		JSR	@LAP_DATA_INIT			; PARAM : R0L

		BSET	G_LED
		BSET	R_LED

		MOV.B	#H'52, R0L
		MOV.B	#H'0, R1L
		JSR	@VL53L0X_init

		JSR	@READ_SW0			; �m�C�Y�̓ǂݎ̂�
		JSR	@READ_SW1			; �m�C�Y�̓ǂݎ̂�
		JSR	@READ_SW2			; �m�C�Y�̓ǂݎ̂�

		JSR	@TOP_MENU

MAIN:
MAIN_CHK_SW0:
		JSR	@READ_SW0			; SW0�������ꂽ��
		BCS	MAIN_CHK_SW0_ON
		JMP	@MAIN_CHK_SW1

MAIN_CHK_SW0_ON:
		BNOT	R_LED

		MOV.B	#3,R0L
		MOV.B	R0L,@PCII_INPUT_VALID		; RESET INPUT VALID/INVALID 
		MOV.B	#0, R0L
		MOV.B	R0L, @PCII_SW1_MODE
		MOV.B	R0L, @PCII_SW2_MODE
		JSR	@EEPROM_REC_STOP

		MOV.B	@PCII_DISP_MODE,R0L
		INC.B	R0L
		CMP.B	#MENU_MAX, R0L
		BNE	MAIN_CHK_SW0_MODE0
		MOV.B	#MENU_G_PCII_MON, R0L
MAIN_CHK_SW0_MODE0:					; TOP MENU
		MOV.B	R0L, @PCII_DISP_MODE
		BNE	MAIN_DISP_SW0_MODE1
		JSR	@TOP_MENU
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE1:					; PCII & �����x
		CMP.B	#MENU_G_PCII_MON, R0L
		BNE	MAIN_DISP_SW0_MODE2
		JSR	@LCD_CLR_CS1
		JMP	@MAIN_DISP			; ���񏑂�������̂ŁA�e���v���[�g�Ȃ�
MAIN_DISP_SW0_MODE2: 					; PCII �ڍו\��
		CMP.B	#MENU_PCII_MON, R0L
		BNE	MAIN_DISP_SW0_MODE3
		JSR	@LCD_CLR_CS1
		JSR	@LCD_PCII_DATA_CS1_INIT		; CS1:PCII�̏ڍׁACS2:���[�^�\���͖��񏑂�
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE3:					; G �\��
		CMP.B	#MENU_G_MON, R0L
		BNE	MAIN_DISP_SW0_MODE4
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE4:					; LAP
		CMP.B	#MENU_LAP_MON, R0L
		BNE	MAIN_DISP_SW0_MODE5
		JSR	@LAP_MON
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE5:					; SUS �O���t�\��
		CMP.B	#MENU_SUS_MON, R0L
		BNE	MAIN_DISP_SW0_MODE6
		JSR	@VRAM_CLR
		JSR	@LCD_CLR_CS1
		JSR	@LCD_CLR_CS2
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE6:					; MULTI MON
		CMP.B	#MENU_MULTI, R0L
		BNE	MAIN_DISP_SW0_MODE7
		JSR	@DISP_MULTI_INIT
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE7:					; G & PCII PLAY
		CMP.B	#MENU_G_PCII_PL, R0L
		BNE	MAIN_DISP_SW0_MODE8
		MOV.B	#MENU_PCII_MON, R0L		; DATA ID
		JSR	@PLAY_SW0
		CMP.B	#MENU_PCII_MON, R0L
		BNE	MAIN_DISP_SW0_MODE7_NO_DATA
		MOV.W	@PLAY_IIC_NO,R1
		MOV.B	@PLAY_EEPROM_MODE, R0L
		MOV.B	@PCII_SW2_MODE, R0H
;;;		JSR	@AD_DISP_PLAY
MAIN_DISP_SW0_MODE7_NO_DATA:
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE8:					; PCII PLAY GRAPH
		CMP.B	#MENU_PCII_PL, R0L
		BNE	MAIN_DISP_SW0_MODE9
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE9:					; LAP PLAY
		CMP.B	#MENU_LAP_PL, R0L
		BNE	MAIN_DISP_SW0_MODE10
		JSR	@LAP_VIEW_INIT
		
		MOV.B	#MENU_LAP_MON, R0L		; DATA ID
		JSR	@PLAY_SW0
		CMP.B	#MENU_LAP_MON, R0L
		BNE	MAIN_DISP_SW0_MODE9_NO_DATA
		MOV.W	@PLAY_IIC_NO,R1
		MOV.B	@PLAY_EEPROM_MODE, R0L
		MOV.B	@PCII_SW2_MODE, R0H
		JSR	@LAP_VIEW
MAIN_DISP_SW0_MODE9_NO_DATA:
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE10:					; SETTING
		CMP.B	#MENU_SETTING, R0L
		BNE	MAIN_DISP_SW0_MODE11
		JSR	@SETTING_DISP
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE11:					; I2C MEM
		CMP.B	#MENU_MEM, R0L
		BNE	MAIN_DISP_SW0_MODE12
		JSR	@EEPROM_MEM_INFO
		JSR	@LCD_EEPROM_MEM_INFO
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE12:					; I2C DEBUG
		CMP.B	#MENU_I2C_D, R0L
		BNE	MAIN_DISP_SW0_MODE13
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE13:					; PCII DEBUG
		CMP.B	#MENU_PCII_D, R0L
		BNE	MAIN_DISP_SW0_MODE14
		JSR	@MON_PCII_INIT
		JMP	@MAIN_DISP
MAIN_DISP_SW0_MODE14:

MAIN_CHK_SW1:
		JSR	@READ_SW1			; SW1�������ꂽ��
		BCC	MAIN_CHK_SW1_SS
		MOV.B	@PCII_INPUT_VALID, R0L
		BTST	#0,R0L
		BEQ	MAIN_CHK_SW1_SS

		MOV.B	#0, R0L
		MOV.B	R0L, @PCII_SW2_MODE

		MOV.B	@PCII_DISP_MODE, R0L
		BNE	MAIN_CHK_SW1_MODE1
		NOP					; NO ACTION ON MODE 0.
MAIN_CHK_SW1_SS:
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE1:					; PCII & �����x
		CMP.B	#MENU_G_PCII_MON, R0L
		BNE	MAIN_CHK_SW1_MODE2
		JSR	@PCII_DATA_OFFSET		; no action
		JSR	@AD_ZERO
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE2:					; PCII �ڍו\��
		CMP.B	#MENU_PCII_MON, R0L
		BNE	MAIN_CHK_SW1_MODE3
		JSR	@PCII_DATA_OFFSET		; no action ���j�^�؂�ւ��ɂ�����
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE3:					; G �\��
		CMP.B	#MENU_G_MON, R0L
		BNE	MAIN_CHK_SW1_MODE4
		JSR	@AD_ZERO
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE4:					; LAP
		CMP.B	#MENU_LAP_MON, R0L
		BNE	MAIN_CHK_SW1_MODE5
		JSR	@LAP_MON_SW1
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE5:					; SUS �O���t�\��
		CMP.B	#MENU_SUS_MON, R0L
		BNE	MAIN_CHK_SW1_MODE6
		JSR	@VL53L0X_OFFSET
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE6:					; MULTI MON
		CMP.B	#MENU_MULTI, R0L
		BNE	MAIN_CHK_SW1_MODE7
		JSR	@LAP_MON_SW1
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE7:					; G & PCII PLAY
		CMP.B	#MENU_G_PCII_PL, R0L
		BNE	MAIN_CHK_SW1_MODE8
		MOV.B	#MENU_PCII_MON, R0L		; DATA ID
		JSR	@PLAY_SW1
		MOV.W	@PLAY_IIC_NO, R1
		CMP.W	#H'FFFF, R1
		BEQ	MAIN_CHK_SW1_MODE7_L1		; NONE
		MOV.B	@PCII_SW2_MODE, R0H
		MOV.B	@PLAY_EEPROM_MODE, R0L
		JSR	@AD_DISP_PLAY
MAIN_CHK_SW1_MODE7_L1:
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE8:
		CMP.B	#MENU_PCII_PL, R0L
		BNE	MAIN_CHK_SW1_MODE9
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE9:
		CMP.B	#MENU_LAP_PL, R0L
		BNE	MAIN_CHK_SW1_MODE10
		MOV.B	#MENU_LAP_MON, R0L		; DATA TYPE
		JSR	@PLAY_SW1
		MOV.W	@PLAY_IIC_NO, R1
		CMP.W	#H'FFFF, R1
		BEQ	MAIN_CHK_SW1_MODE9_L1		; NONE
		MOV.B	@PCII_SW2_MODE, R0H
		MOV.B	@PLAY_EEPROM_MODE, R0L
		JSR	@LAP_VIEW
MAIN_CHK_SW1_MODE9_L1:
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE10:
		CMP.B	#MENU_SETTING, R0L
		BNE	MAIN_CHK_SW1_MODE11
		JSR	@SETTING_SW1
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE11:
		CMP.B	#MENU_MEM, R0L
		BNE	MAIN_CHK_SW1_MODE12
		JSR	@I2C_DISP_SW1
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE12:
		CMP.B	#MENU_I2C_D, R0L
		BNE	MAIN_CHK_SW1_MODE13
		JSR	@EEPROM_CHECK_SW1
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE13:
		CMP.B	#MENU_PCII_D, R0L
		BNE	MAIN_CHK_SW1_MODE14
		JSR	@PCII_DEBUG_SW1
		JMP	@MAIN_CHK_SW2
MAIN_CHK_SW1_MODE14:

MAIN_CHK_SW2:
		JSR	@READ_SW2			; SW2�������ꂽ��
		BCC	MAIN_CHK_SW2_SS
		MOV.B	@PCII_INPUT_VALID, R0L
		BTST	#1,R0L
		BNE	MAIN_CHK_SW2_MODE0
MAIN_CHK_SW2_SS:
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE0;
		MOV.B	@PCII_DISP_MODE, R0L
		BNE	MAIN_CHK_SW2_MODE1
		NOP
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE1:
		CMP.B	#MENU_G_PCII_MON, R0L
		BNE	MAIN_CHK_SW2_MODE2
		NOP
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE2:
		CMP.B	#MENU_PCII_MON, R0L
		BNE	MAIN_CHK_SW2_MODE3
		MOV.B	@PCII_DISP_MODE, R0L
		JSR	@EEPROM_REC_START
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE3:
		CMP.B	#MENU_G_MON, R0L
		BNE	MAIN_CHK_SW2_MODE4
		MOV.B	@PCII_DISP_MODE, R0L
		JSR	@EEPROM_REC_START
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE4:
		CMP.B	#MENU_LAP_MON, R0L
		BNE	MAIN_CHK_SW2_MODE5
		MOV.B	@PCII_DISP_MODE, R0L
		JSR	@EEPROM_REC_START
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE5:
		CMP.B	#MENU_SUS_MON, R0L
		BNE	MAIN_CHK_SW2_MODE6
		MOV.B	@PCII_DISP_MODE, R0L
;;;		JSR	@
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE6:
		CMP.B	#MENU_MULTI, R0L
		BNE	MAIN_CHK_SW2_MODE7
		MOV.B	@PCII_DISP_MODE, R0L
		JSR	@EEPROM_REC_START
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE7:					; G & PCII PLAY					; G & PCII PLAY
		CMP.B	#MENU_G_PCII_PL, R0L
		BNE	MAIN_CHK_SW2_MODE8
		MOV.W	#AD_DISP_PLAY, R2		; SUBROUTINE ADDRESS
		JSR	@PLAY_SW2
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE8:					; PCII PLAY GRAPH
		CMP.B	#MENU_PCII_PL, R0L
		BNE	MAIN_CHK_SW2_MODE9
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE9:
		CMP.B	#MENU_LAP_PL, R0L
		BNE	MAIN_CHK_SW2_MODE10
		MOV.W	#LAP_VIEW, R2			; SUBROUTINE ADDRESS
		JSR	@PLAY_SW2
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE10:
		CMP.B	#MENU_SETTING, R0L
		BNE	MAIN_CHK_SW2_MODE11
		JSR	@SETTING_SW2
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE11:
		CMP.B	#MENU_MEM, R0L
		BNE	MAIN_CHK_SW2_MODE12
		JSR	@I2C_DISP_SW2
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE12:
		CMP.B	#MENU_I2C_D, R0L
		BNE	MAIN_CHK_SW2_MODE13
		JSR	@EEPROM_CHECK_SW2
		JMP	@MAIN_CHK_SW3
MAIN_CHK_SW2_MODE13:

MAIN_CHK_SW3:						; ���C�Z���T����̓���
		JSR	@READ_SW3			; 12F675����̓���
		BCC	MAIN_DISP

		MOV.B	@PCII_DISP_MODE, R0L
		CMP.B	#MENU_LAP_MON, R0L
		BEQ	MAIN_CHK_SW3_LAP
		CMP.B	#MENU_MULTI, R0L
		BNE	MAIN_CHK_SW3_E
MAIN_CHK_SW3_LAP:
		JSR	@LAP_MON_SW1
MAIN_CHK_SW3_E:
MAIN_DISP:
		MOV.B	@PCII_DISP_MODE, R0L
		BNE	MAIN_DISP_L1
		JMP	@MAIN_DISP_LE
MAIN_DISP_L1:
		CMP.B	#MENU_G_PCII_MON, R0L
		BNE	MAIN_DISP_L2
		JSR	@LCD_G_MON
;;;		JSR	@GET_PCII_SIM
		JSR	@GET_PCII
		JSR	@LCD_PCII_MON
		JMP	@MAIN_DISP_LE
MAIN_DISP_L2:
		CMP.B	#MENU_PCII_MON, R0L
		BNE	MAIN_DISP_L3
		JSR	@GET_PCII
		JSR	@LCD_PCII_DATA_CS1
		JSR	@LCD_PCII_MON
		JMP	@MAIN_DISP_LE
MAIN_DISP_L3:
		CMP.B	#MENU_G_MON, R0L
		BNE	MAIN_DISP_L4
;;;		JSR	@AD_INT_SIM
		JSR	@LCD_G_MON
		JSR	@LCD_G_TRACK_CS2
		JMP	@MAIN_DISP_LE
MAIN_DISP_L4:
		CMP.B	#MENU_LAP_MON, R0L
		BNE	MAIN_DISP_L5
		JSR	@DISP_TIME
		JMP	@MAIN_DISP_LE
MAIN_DISP_L5:
		CMP.B	#MENU_SUS_MON, R0L
		BNE	MAIN_DISP_L6
		JSR	@LCD_SUS_TRACK
		JMP	@MAIN_DISP_LE
MAIN_DISP_L6:
		CMP.B	#MENU_MULTI, R0L
		BNE	MAIN_DISP_L7
		JSR	@DISP_MULTI_TIME
		JSR	@LCD_MULTI_MON
		JMP	@MAIN_DISP_LE
MAIN_DISP_L7:					; G & PCII PLAY
		CMP.B	#MENU_G_PCII_PL, R0L
		BNE	MAIN_DISP_L8
		JSR	@VRAM_X_4L
		MOV.W	#G_PCII_PLAY_MSG1, R0
		MOV.W	#H'0000, R1
		JSR	@VRAM_STRING
		MOV.W	#G_PCII_PLAY_MSG2, R0
		MOV.W	#H'0400, R1
		JSR	@VRAM_STRING
		JSR	@VRAM_TO_LCD_CS1
		JSR	@VRAM_TO_LCD_CS2
		JMP	@MAIN_DISP_LE
MAIN_DISP_L8:					; PCII PLAY GRAPH
		CMP.B	#MENU_PCII_PL, R0L
		BNE	MAIN_DISP_L9
		JSR	@VRAM_X_4L
		MOV.W	#PCII_PLAY_MSG1, R0
		MOV.W	#H'0000, R1
		JSR	@VRAM_STRING
		MOV.W	#PCII_PLAY_MSG2, R0
		MOV.W	#H'0400, R1
		JSR	@VRAM_STRING
		JSR	@VRAM_TO_LCD_CS1
		JSR	@VRAM_TO_LCD_CS2
		JMP	@MAIN_DISP_LE
MAIN_DISP_L9:
MAIN_DISP_L10:
MAIN_DISP_L11:
MAIN_DISP_L12:
		CMP.B	#MENU_PCII_D, R0L
		BNE	MAIN_DISP_L13
		JSR	@MON_PCII
;;;		JMP	@MAIN_DISP_LE
MAIN_DISP_L13:
MAIN_DISP_LE:
		JMP	@MAIN

SUS_MON_MSG1		.SDATA	"SUS-F"
			.DATA.B	0
SUS_MON_MSG2		.SDATA	"SUS-R"
			.DATA.B	0
G_PCII_PLAY_MSG1	.SDATA	"G-P"
			.DATA.B	0
G_PCII_PLAY_MSG2	.SDATA	"PCII-P"
			.DATA.B	0
PCII_PLAY_MSG1		.SDATA	"RPM/MP"
			.DATA.B	0
PCII_PLAY_MSG2		.SDATA	"TP/TPD"
			.DATA.B	0
		.ALIGN	2

;-------------------------------------------------
;	PCII DEBUG SW���͏���
;-------------------------------------------------
PCII_DEBUG_SW1:
		MOV.B	@PCII_CMD, R0L
		CMP.B	#H'44, R0L
		BNE	MAIN_CHK_SW1_CMD52
		MOV.B	#H'52, R0L
		JMP	@MAIN_CHK_SW1_CMD_E
MAIN_CHK_SW1_CMD52:
		CMP.B	#H'52, R0L
		BNE	MAIN_CHK_SW1_CMD_OTHER
		MOV.B	#H'44, R0L
		JMP	@MAIN_CHK_SW1_CMD_E
MAIN_CHK_SW1_CMD_OTHER:
		MOV.B	#H'44, R0L
MAIN_CHK_SW1_CMD_E:
		MOV.B	R0L,@PCII_CMD
		RTS

;-------------------------------------------------
;	PLAY SW���͏���
;-------------------------------------------------
;	IN	ROL : DATA ID
;	OUT	R0  : IIC DATA ID
;	SW0�́A�e����������
;	SW1�́A1�Đ�..n�Đ�.1�폜..n�폜
;	SW2�́A�Đ����́A���R�[�h����A�폜���͍폜�m�F
;-------------------------------------------------
PLAY_SW0:	PUSH.W	R2
		MOV.B	R0L, R2L

		MOV.W	#H'000F, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.B	#H'2A, R0L
		JSR	@LCD_CHAR

		MOV.W	#0, R1
		MOV.B	R1L, @PLAY_EEPROM_MODE		; PLAY/DELETE
		MOV.W	R1, @PLAY_IIC_NO
		MOV.B	R2L, R0L
		JSR	@EEPROM_FIND_PAGE
		MOV.W	R0, @PLAY_IIC_NO

		CMP.W	#H'FFFF, R0
		BEQ	PLAY_SW0_NO_DATA
		JSR	@LOAD_PAGE_FROM_EEPROM
		JMP	@PLAY_SW0_E
PLAY_SW0_NO_DATA:
		MOV.B	#0,R0L				; ID IS NOT MENU_PCII_MON
		MOV.B	R0L,@PCII_INPUT_VALID		; INVALID INPUT
		JSR	@PLAY_NO_DATA
		MOV.W	#0, R0
PLAY_SW0_E:
		PUSH.W	R0
		MOV.W	#H'000F, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.B	#H'20, R0L
		JSR	@LCD_CHAR
		POP.W	R0
		POP.W	R2
		RTS

;-------------------------------------------------
;	IN	ROL : DATA ID
;-------------------------------------------------
PLAY_SW1:	PUSH.W	R2
		MOV.B	R0L, R2L			; DATA ID
		MOV.B	#0, R0L
		MOV.B	R0L, @PCII_SW2_MODE

		MOV.W	#H'0007, R0
		JSR	@LCD_OFFSET
		MOV.B	#H'23, R0L
		JSR	@LCD_CHAR

		MOV.W	@PLAY_IIC_NO,R1
		INC.W	#1, R1
		MOV.B	R2L, R0L			; DATA ID
		JSR	@EEPROM_FIND_PAGE
		MOV.W	R0, @PLAY_IIC_NO
		CMP.W	#H'FFFF, R0
		BEQ	PLAY_SW1_WRAP			; END OF MEMORY?
		JSR	@LOAD_PAGE_FROM_EEPROM
		JMP	@PLAY_SW1_E
PLAY_SW1_WRAP:
		MOV.B	@PLAY_EEPROM_MODE, R0L
		BNOT	#0, R0L
		MOV.B	R0L, @PLAY_EEPROM_MODE
		MOV.W	#0, R1
		MOV.W	R1, @PLAY_IIC_NO
		MOV.B	R2L, R0L			; DATA ID
		JSR	@EEPROM_FIND_PAGE
		MOV.W	R0, @PLAY_IIC_NO
		CMP.W	#H'FFFF, R0
		BEQ	PLAY_SW1_NODATA			; END OF MEMORY?
		JSR	@LOAD_PAGE_FROM_EEPROM
		JMP	@PLAY_SW1_E
PLAY_SW1_NODATA:
		MOV.B	#0,R0L				; ID IS NOT MENU_PCII_MON
		MOV.B	R0L,@PCII_INPUT_VALID		; INVALID INPUT
		JSR	@PLAY_NO_DATA
PLAY_SW1_E:
		MOV.W	#H'0007, R0
		JSR	@LCD_OFFSET
		MOV.B	#H'20, R0L
		JSR	@LCD_CHAR
		POP.W	R2
		RTS

;-------------------------------------------------
;	IN	R2  : SUBROUTINE ADDRESS OF NEXT RECORD VIEW
;-------------------------------------------------
PLAY_SW2:
		MOV.B	@PLAY_EEPROM_MODE, R0L
		BNE	PLAY_SW2_ERASE
		MOV.B	@PCII_SW2_MODE, R0L
		INC.B	R0L
		MOV.B	R0L, @PCII_SW2_MODE

		MOV.W	@PLAY_IIC_NO,R1
		MOV.B	@PLAY_EEPROM_MODE, R0L
		MOV.B	@PCII_SW2_MODE, R0H
		JSR	@R2
		CMP.B	#H'0, R0L
		BEQ	PLAY_SW2_E
		MOV.W	@PLAY_IIC_NO,R0
		JSR	@LOAD_PAGE_FROM_EEPROM
		MOV.B	#H'FF, R0L
		MOV.B	R0L, @PCII_SW2_MODE
		JMP	@PLAY_SW2_E
PLAY_SW2_ERASE:
		MOV.B	@PCII_SW2_MODE, R0L
		BEQ	PLAY_SW2_ERASE_L1
		CMP.B	#1,R0L
		BNE	PLAY_SW2_E			; NO NEED ONE MORE.
		INC.B	R0L
		MOV.B	R0L, @PCII_SW2_MODE
		MOV.W	#H'0200, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#ERASE_MSG, R0
		JSR	@LCD_STRING
		MOV.W	#H'0208, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#ERASE_MSG, R0
		JSR	@LCD_STRING

		MOV.W	@PLAY_IIC_NO,R0
		JSR	@EEPROM_ERASE_PAGE
		JMP	@I2C_SW2_E
PLAY_SW2_ERASE_L1:
		INC.B	R0L
		MOV.B	R0L, @PCII_SW2_MODE
		MOV.W	#H'0200, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#ERASE_CONFIRM1, R0
		JSR	@LCD_STRING
		MOV.W	#H'0208, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#ERASE_CONFIRM2, R0
		JSR	@LCD_STRING
PLAY_SW2_E:
		RTS

PLAY_NO_DATA:
		PUSH.W	R0
		MOV.W	#H'0008, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#NO_DATA, R0
		JSR	@LCD_STRING
		POP.W	R0
		RTS


NO_DATA			.SDATA		"NO DATA."
			.DATA.B		0
ERASE_CONFIRM1		.SDATA		"= DELETE"
			.DATA.B		0
ERASE_CONFIRM2		.SDATA		" <OK?> ="
			.DATA.B		0
ERASE_MSG		.SDATA		"--------"
			.DATA.B		0
		.ALIGN	2

;-------------------------------------------------
;	I2C VIEW SW���͏���
;-------------------------------------------------
I2C_DISP_SW1:	MOV.B	#0, R0L
		MOV.B	R0L, @PCII_SW2_MODE

		MOV.B	@PCII_SW1_MODE,R0L
		INC.B	R0L
		CMP.B	#I2C_DISP_SW1_MAX, R0L
		BNE	I2C_DISP_SW1_0
		MOV.B	#0, R0L
I2C_DISP_SW1_0;
		MOV.B	R0L, @PCII_SW1_MODE

		MOV.B	@PCII_SW1_MODE, R0L
		BNE	I2C_DISP_SW1_1
		JSR	@EEPROM_MEM_INFO
		JSR	@LCD_EEPROM_MEM_INFO
		JMP	@I2C_DISP_SW1_E
I2C_DISP_SW1_1:
		CMP.B	#1, R0L
		BNE	I2C_DISP_SW1_E
		JSR	@LCD_I2C_FORMAT_MENU
;;;		JMP	@I2C_DISP_SW1_E
I2C_DISP_SW1_E:
		RTS

I2C_DISP_SW2:
		MOV.B	@PCII_SW1_MODE, R0L
		BNE	I2C_SW2_FORMAT
		NOP					; NO OPERATION AT VIEW MODE 
		JMP	@I2C_SW2_E
I2C_SW2_FORMAT:
		MOV.B	@PCII_SW2_MODE, R0L
		BEQ	I2C_SW2_L1
		CMP.B	#1,R0L
		BNE	I2C_SW2_E			; NO NEED ONE MORE.
		INC.B	R0L
		MOV.B	R0L, @PCII_SW2_MODE
		JSR	@LCD_I2C_FORMAT_DOING
		JSR	@EEPROM_FORMAT
		JSR	@LCD_I2C_FORMAT_DONE
		JMP	@I2C_SW2_E

I2C_SW2_L1:	INC.B	R0L
		MOV.B	R0L, @PCII_SW2_MODE
		JSR	@LCD_I2C_FORMAT_CONFIRM
I2C_SW2_E:
		RTS

;=================================================
;	�T�u���[�`��
;=================================================
;-------------------------------------------------
;	����������
;-------------------------------------------------
PORT_INIT:	PUSH.W	R0
PORT1:		MOV.B	#B'11110010,R0L		; P14-17��IRQ0-3�ɐݒ�,P22��TXD�|�[�g�ɐݒ�
		MOV.B	R0L, @PMR1		; P22�́APMR1�ɐݒ肷��̂ŁA�����ł悢�B
		MOV.B	#B'00001111,R0L		;P14-17:���́AP10-13:�o�̓|�[�g�ɐݒ�
		MOV.B	R0L,@PCR1
PORT5:		MOV.B	#B'00000000,R0L
		MOV.B	R0L,@PMR5		; P5*��ėp�|�[�g�ɐݒ� / I2C�͂����ł͊֌W�Ȃ�
		MOV.B	#B'00001111,R0L
		MOV.B	R0L,@PCR5		; P54-57����́AP50-53���o�̓|�[�g�ɐݒ�
		MOV.B	#B'00000000,R0L
		MOV.B	R0L,@PDR5

PORT7_8:	MOV.B	#H'FF,R0L
		MOV.B	R0L,@PCR7		; P7*���o�̓|�[�g�ɐݒ�
		MOV.B	R0L,@PCR8		; P8*���o�̓|�[�g�ɐݒ�
		MOV.B	#H'0,R0L
		MOV.B	R0L,@TIOR0		; P81-82 ��IO��
		MOV.B	R0L,@TIOR1		; P83-84 ��IO��
		MOV.B	R0L,@PDR7		; P74-76��L�o��
		MOV.B	R0L,@PDR8		; P8*��L�o��
PORT_INIT_E:	POP.W	R0
		RTS

TIMEA_INIT:	PUSH.L	ER0
		MOV.B	#B'00010101,R0L		; 1/16M * 256(TCA) * 128 = 2ms,
						; 1/20M * 256(TCA) * 128 = 1.64ms
		MOV.B	R0L,@TMA
		BSET	IENTA			;�^�C�}�[�`���荞�݂�����
		POP.L	ER0
		RTS

TIMEV_INIT:	PUSH.W	R0
						; 1/20M * 128 = 0.0064ms
		MOV.B	#B'01001011,R0L		; CMIEA=1, CCLR=01, CKS=011
		MOV.B	R0L, @TCRV0
		MOV.B	#B'00000001,R0L		; CKS0=1
		MOV.B	R0L, @TCRV1
		MOV.B	@TCSRV, R0L
		MOV.B	#B'00000000,R0L
		MOV.B	R0L, @TCSRV
		MOV.B	R0L, @TCNTV
		MOV.B	#125, R0L
		MOV.B	R0L, @TCORA		; 0.0064 *125 = O.8ms
		POP.W	R0
		RTS

;-------------------------------------------------
;	MULTI �v����ʕ\��
;-------------------------------------------------
;	�\���́A20x4�B
;		+0123456789012345
;		+----------------+
;		|      C)0'00"000|
;		|      L)0'00"000|
;		|  3�s RPM ����  |
;		|      TP�̐���  |
;		|  3�s G�� ����  |
;		|                |
;		+----------------+
DISP_MULTI_INIT:
		PUSH.W	R0
		PUSH.W	R1
		JSR	@LCD_CLR_CS1
		JSR	@LCD_CLR_CS2
		MOV.W	#H'0000, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.W	#MULTI_MON_MSG, R0
		JSR	@LCD_STRING
		MOV.W	#H'0006, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.B	#H'43, R0L
		JSR	@LCD_CHAR
		MOV.B	#H'29, R0L
		JSR	@LCD_CHAR
		MOV.W	#H'0106, R0
		JSR	@LCD_TEXT_OFFSET
		MOV.B	#H'4C, R0L
		JSR	@LCD_CHAR
		MOV.B	#H'29, R0L
		JSR	@LCD_CHAR
		POP.W	R1
		POP.W	R0
		RTS

MULTI_MON_MSG		.SDATA	"M-MON"
			.DATA.B	0
		.ALIGN	2

;-------------------------------------------------
;	TIMER PROCESS
;-------------------------------------------------
TIME_PCII:	PUSH.L	ER0
		MOV.W	@TIMER_PCII, R0
		INC.W	#1, R0
;;		CMP.B	#61, R0L			; 3694/ 1.638*61 = 100ms
		CMP.B	#122, R0L			; 3694/ 1.638*122 = 200ms
;;		CMP.B	#152, R0L			; 3694/ 1.638*152 = 250ms
;;		CMP.B	#48, R0L			; 3664/ 2.048*48 = 100ms
;;		CMP.B	#97, R0L			; 3664/ 2.048*97 = 200ms
;;		CMP.B	#122, R0L			; 3664/ 2.048*122 = 250ms
		BNE	TIME_PCII_E

		MOV.B	@PCII_DISP_MODE, R0L
		CMP.B	#MENU_SETTING, R0L
		BEQ	TIME_PCII_NO_CMD

		MOV.B	@PCII_CMD, R0L
		JSR	@SET_READ_MODE

TIME_PCII_L:	MOV.B	@PCII_CMD, R0L
		JSR	@SEND_CHAR
TIME_PCII_NO_CMD:
		MOV.W	#0, R0
TIME_PCII_E:	MOV.W	R0, @TIMER_PCII
		POP.L	ER0
		RTS

TIME_G_SENSOR:	PUSH.W	R0
		MOV.B	@TIMER_G_SENSOR, R0L
		DEC.B	R0L
		BNE	TIME_G_SENSOR_E
		BSET	#5, @ADCSR			; ADST �ϊ��J�n
		MOV.B	#61, R0L			; 3694/ 1.638*61 = 100ms
TIME_G_SENSOR_E:
		MOV.B	R0L, @TIMER_G_SENSOR
		POP.W	R0
		RTS

TIME_SUS:	PUSH.W	R0
		MOV.B	@PCII_DISP_MODE, R0L
		CMP.B	#MENU_SUS_MON, R0L
		BNE	TIME_SUS_E
		MOV.B	@TIMER_SUS, R0L
		DEC.B	R0L
		BNE	TIME_G_SUS_WATCH
		JSR	@VL53L0X_GET_DATA1_Async	; �񓯊��Ȃ̂ŁA���^�[�����ŏ������I����Ă���Ƃ�����Ȃ��B
		MOV.B	#20, R0L			; 3694/ 1.638*20 = 32.6ms
		MOV.B	R0L, @TIMER_SUS
		JMP	@TIME_SUS_E
TIME_G_SUS_WATCH:
		MOV.B	R0L, @TIMER_SUS
		JSR	@VL53L0X_GET_DATA1_Async_WD	; ���쒆�̏ꍇ������̂ŁA����R�[������B
TIME_SUS_E:
		POP.W	R0
		RTS

;=================================================
; ���荞�݃A�h���X�ɂ���ē������ςɂȂ�B(0180-018E�̃A�h���X)
; INT_CODE�́A0x7000�ɁAxxxx.SUB�t�@�C���Őݒ�BLNK�œǂݍ��݁B
; ���荞�݃A�h���X���ς���āA�����Ȃ��Ȃ�����A�A�h���X��ς��Ă݂�B
	.SECTION INT_CODE, CODE, ALIGN=2
;-------------------------------------------------
;	���荞�ݏ��� 2ms����
;-------------------------------------------------
TIME_A:		PUSH.L	ER0			;���W�X�^�̑Ҕ�
		BCLR	IENTA			;���荞�ݒ�~
		BCLR	IRRTA			;���荞�݃t���O���N���A

		JSR	@TIME_PCII
		JSR	@TIME_G_SENSOR
		JSR	@TIME_SUS
		JSR	@SW_CHATTERING_CHK
		JSR	@IRQ_KEEP

		MOV.L	@LIFE_MS, ER0
		INC.L	#1, ER0
		MOV.L	ER0, @LIFE_MS
		BSET	IENTA			;���荞�ݍĊJ
		POP.L	ER0			;���W�X�^�̕��A
		RTE				;���荞�݂���̕��A

;-------------------------------------------------
;	���荞�ݏ��� 0.8ms����
;-------------------------------------------------
TIME_V:		PUSH.L	ER0			;���W�X�^�̑Ҕ�
		MOV.L	@TIMEV_CNT,ER0
		INC.L	#1,ER0
		MOV.L	ER0, @TIMEV_CNT
		MOV.B	@TCSRV, R0L
		MOV.B	#B'00000000,R0L
		MOV.B	R0L, @TCSRV
		POP.L	ER0			;���W�X�^�̕��A
		RTE				;���荞�݂���̕��A

;=================================================
	.SECTION PDATA, DATA, ALIGN=2

DATA_AREA_S
TIMER_PCII		.RES.W	1
TIMER_G_SENSOR		.RES.B	1
TIMER_SUS		.RES.B	1

PLAY_IIC_NO		.RES.W	1
PLAY_EEPROM_MODE	.RES.B	1		; 0=PLAY, 1=DELETE
			.ALIGN	2

PCII_DISP_MODE		.RES.B	1
PCII_SW1_MODE		.RES.B	1
PCII_SW2_MODE		.RES.B	1		; O=DISP, PLAY, REC
PCII_INPUT_VALID	.RES.B	1

PCII_CMD		.RES.B	1
			.RES.B	1
			.ALIGN	2

LIFE_MS			.RES.L	1
TIMEV_CNT		.RES.L	1		; 0.8ms��1�J�E���g
						; *4/5 ��1ms�ƂȂ�B2BIT�V�t�g���āA5�Ŋ���B
						; 1250�Ŋ���ƁA1s�ƂȂ�B
						; 7500�Ŋ���ƁA1m�ƂȂ�B

;=================================================
	.SECTION STACK_END, STACK, LOCATE=H'FF80

S_START

	.END