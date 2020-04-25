MENU_MAX	.EQU	12
MENU_TOP	.EQU	0
MENU_G_PCII_MON	.EQU	1	;1; G-グラフ   PCII-グラフ
MENU_PCII_MON	.EQU	2	;2; PCII-詳細  PCII-グラフ 詳細は文字・推移切替
MENU_G_MON	.EQU	3	; ; G-グラフ   G-詳細　　　詳細は推移
MENU_LAP_MON	.EQU	4	;4;
MENU_SUS_MON	.EQU	5	; ; G-グラフ   G-詳細　　　詳細は推移
MENU_MULTI	.EQU	6	;6;
MENU_G_PCII_PL	.EQU	7	;3; グラフ：rpm/G/TP
MENU_PCII_PL	.EQU	8	; ; グラフ：rpm/TP/TPd/MP/AAP
MENU_LAP_PL	.EQU	9	;5
MENU_SETTING	.EQU	10	;8
MENU_MEM	.EQU	11	;7
MENU_I2C_D	.EQU	12	;9
MENU_PCII_D	.EQU	13	;10

;------	I2C PAGE FORMAT -----
; ヘッダ領域8バイト
HEADER_SIZE	.EQU	8
H_TYPE		.EQU	0	;記録種別（0:空, FF:続き, 1:パワーコマンダー,2:加速度センサー, 3:ラップ, 4:マルチ）
H_RESERVE	.EQU	1
H_PREV_PAGE	.EQU	2	;一連の前ページ番号。（先頭の場合は0xffff）
H_CONT_PAGE	.EQU	4	;一連の次ページ番号。（最後の場合は0xffff）
H_RESERVE2	.EQU	6

;10バイトで1レコード
MULTI_1RECORD	.EQU	10
MULTI_SEC	.EQU	0	; 最上位がFF以外
MULTI_MSEC	.EQU	2
MULTI_SEC1_MSEC	.EQU	4
MULTI_SEC2_MSEC	.EQU	6
MULTI_SEC3_MSEC	.EQU	8

MULTI_MARKER	.EQU	0	; FF
MULTI_MG	.EQU	1	; 1bytes: 磁気センサー情報
MULTI_G_X	.EQU	2	; 2bytes: 加速度x,y
MULTI_G_Y	.EQU	4	;
MULTI_RPM	.EQU	6	; 2bytes: 回転数
MULTI_TP	.EQU	8	; 1bytes: アクセル開度
MULTI_AIR	.EQU	9	;

;8バイトで1レコード
PC_1RECORD	.EQU	8
PC_RPM		.EQU	0	; 2bytes: 回転数
PC_TP		.EQU	2	; 1bytes: アクセル開度
PC_AAP		.EQU	3	; 4bytes: その他4種パワコンデータ
PC_TP0		.EQU	4	;
PC_IGN		.EQU	5	;
PC_AIR		.EQU	6	;
PC_RESERVE	.EQU	7	;


;6バイトで1レコード
G_1RECORD_SIZE	.EQU	6
G_X		.EQU	0	; 加速度x
G_Y		.EQU	2	; 加速度y
G_MAG_ID	.EQU	4	; 磁気センサー情報
G_RESERVE	.EQU	5	; Reserve

;10バイトで1レコード
LAP_1RECORD	.EQU	10
LAP_SEC		.EQU	0
LAP_MSEC	.EQU	2
SEC1_MSEC	.EQU	4
SEC2_MSEC	.EQU	6
SEC3_MSEC	.EQU	8

;------	BUFFERS -----
EEPROM_PAGE_SIZE	.EQU	128	; 24FC512 PAGE SIZE

