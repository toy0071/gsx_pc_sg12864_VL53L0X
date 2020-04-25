MENU_MAX	.EQU	12
MENU_TOP	.EQU	0
MENU_G_PCII_MON	.EQU	1	;1; G-�O���t   PCII-�O���t
MENU_PCII_MON	.EQU	2	;2; PCII-�ڍ�  PCII-�O���t �ڍׂ͕����E���ڐؑ�
MENU_G_MON	.EQU	3	; ; G-�O���t   G-�ڍׁ@�@�@�ڍׂ͐���
MENU_LAP_MON	.EQU	4	;4;
MENU_SUS_MON	.EQU	5	; ; G-�O���t   G-�ڍׁ@�@�@�ڍׂ͐���
MENU_MULTI	.EQU	6	;6;
MENU_G_PCII_PL	.EQU	7	;3; �O���t�Frpm/G/TP
MENU_PCII_PL	.EQU	8	; ; �O���t�Frpm/TP/TPd/MP/AAP
MENU_LAP_PL	.EQU	9	;5
MENU_SETTING	.EQU	10	;8
MENU_MEM	.EQU	11	;7
MENU_I2C_D	.EQU	12	;9
MENU_PCII_D	.EQU	13	;10

;------	I2C PAGE FORMAT -----
; �w�b�_�̈�8�o�C�g
HEADER_SIZE	.EQU	8
H_TYPE		.EQU	0	;�L�^��ʁi0:��, FF:����, 1:�p���[�R�}���_�[,2:�����x�Z���T�[, 3:���b�v, 4:�}���`�j
H_RESERVE	.EQU	1
H_PREV_PAGE	.EQU	2	;��A�̑O�y�[�W�ԍ��B�i�擪�̏ꍇ��0xffff�j
H_CONT_PAGE	.EQU	4	;��A�̎��y�[�W�ԍ��B�i�Ō�̏ꍇ��0xffff�j
H_RESERVE2	.EQU	6

;10�o�C�g��1���R�[�h
MULTI_1RECORD	.EQU	10
MULTI_SEC	.EQU	0	; �ŏ�ʂ�FF�ȊO
MULTI_MSEC	.EQU	2
MULTI_SEC1_MSEC	.EQU	4
MULTI_SEC2_MSEC	.EQU	6
MULTI_SEC3_MSEC	.EQU	8

MULTI_MARKER	.EQU	0	; FF
MULTI_MG	.EQU	1	; 1bytes: ���C�Z���T�[���
MULTI_G_X	.EQU	2	; 2bytes: �����xx,y
MULTI_G_Y	.EQU	4	;
MULTI_RPM	.EQU	6	; 2bytes: ��]��
MULTI_TP	.EQU	8	; 1bytes: �A�N�Z���J�x
MULTI_AIR	.EQU	9	;

;8�o�C�g��1���R�[�h
PC_1RECORD	.EQU	8
PC_RPM		.EQU	0	; 2bytes: ��]��
PC_TP		.EQU	2	; 1bytes: �A�N�Z���J�x
PC_AAP		.EQU	3	; 4bytes: ���̑�4��p���R���f�[�^
PC_TP0		.EQU	4	;
PC_IGN		.EQU	5	;
PC_AIR		.EQU	6	;
PC_RESERVE	.EQU	7	;


;6�o�C�g��1���R�[�h
G_1RECORD_SIZE	.EQU	6
G_X		.EQU	0	; �����xx
G_Y		.EQU	2	; �����xy
G_MAG_ID	.EQU	4	; ���C�Z���T�[���
G_RESERVE	.EQU	5	; Reserve

;10�o�C�g��1���R�[�h
LAP_1RECORD	.EQU	10
LAP_SEC		.EQU	0
LAP_MSEC	.EQU	2
SEC1_MSEC	.EQU	4
SEC2_MSEC	.EQU	6
SEC3_MSEC	.EQU	8

;------	BUFFERS -----
EEPROM_PAGE_SIZE	.EQU	128	; 24FC512 PAGE SIZE
