
%ifndef __KEYBD__
%define __KEYBD__

%include "idt.asm"
%include "pic.asm"

bits 32

; NOTE
; The following keys are mapped to ASCII (decimal values):
; F1-F6:  from 1 to 6
; F7-F12: from 16 to 21
; Cursor:
; 	Up: 22, Down: 23, Left: 24, Right: 25
; PGUP: 28
; PGDN: 29
; INSERT: 14
; DELETE: 15
; HOME: 30
; END: 31

;enum KEYCODE (ascii codes)
KEY_SPACE	equ	' '
KEY_0		equ	'0'
KEY_1		equ	'1'
KEY_2		equ	'2'
KEY_3		equ	'3'
KEY_4		equ	'4'
KEY_5		equ	'5'
KEY_6		equ	'6'
KEY_7		equ	'7'
KEY_8 		equ	'8'
KEY_9		equ	'9'

KEY_A		equ	'a'
KEY_B		equ	'b'
KEY_C		equ	'c'
KEY_D		equ	'd'
KEY_E		equ	'e'
KEY_F		equ	'f'
KEY_G		equ	'g'
KEY_H		equ	'h'
KEY_I		equ	'i'
KEY_J		equ	'j'
KEY_K		equ	'k'
KEY_L		equ	'l'
KEY_M		equ	'm'
KEY_N		equ	'n'
KEY_O		equ	'o'
KEY_P		equ	'p'
KEY_Q		equ	'q'
KEY_R		equ	'r'
KEY_S		equ	's'
KEY_T		equ	't'
KEY_U		equ	'u'
KEY_V		equ	'v'
KEY_W		equ	'w'
KEY_X		equ	'x'
KEY_Y		equ	'y'
KEY_Z		equ	'z'

KEY_RETURN		equ	`\n` ; (0x0A) it was '\r' (0x0D)		; backquotes!
KEY_ESCAPE		equ	0x1001
KEY_BACKSPACE 	equ	`\b`									; backquotes!

;// Arrow keys ////////////////////////

KEY_UP		equ	0x1100
KEY_DOWN	equ	0x1101
KEY_LEFT	equ	0x1102
KEY_RIGHT	equ	0x1103

;// Function keys /////////////////////

KEY_F1		equ	0x1201
KEY_F2		equ	0x1202
KEY_F3		equ	0x1203
KEY_F4		equ	0x1204
KEY_F5		equ	0x1205
KEY_F6		equ	0x1206
KEY_F7		equ	0x1207
KEY_F8		equ	0x1208
KEY_F9		equ	0x1209
KEY_F10		equ	0x120a
KEY_F11		equ	0x120b
KEY_F12		equ	0x120c
KEY_F13		equ	0x120c
KEY_F14		equ	0x120d
KEY_F15		equ	0x120e

KEY_DOT					equ	'.'
KEY_COMMA				equ	','
KEY_COLON				equ	':'
KEY_SEMICOLON			equ	';'
KEY_SLASH				equ	'/'
KEY_BACKSLASH			equ	`\\`		; backquotes!
KEY_PLUS				equ	'+'
KEY_MINUS				equ	'-'
KEY_ASTERISK			equ	'*'
KEY_EXCLAMATION			equ	'!'
KEY_QUESTION			equ	'?'
KEY_QUOTEDOUBLE			equ	'"'
KEY_QUOTE				equ	"'"
KEY_EQUAL				equ	'='
KEY_HASH				equ	'#'
KEY_PERCENT				equ	'%'
KEY_AMPERSAND			equ	'&'
KEY_UNDERSCORE			equ	'_'
KEY_LEFTPARENTHESIS		equ	'('
KEY_RIGHTPARENTHESIS	equ	')'
KEY_LEFTBRACKET			equ	'['
KEY_RIGHTBRACKET		equ	']'
KEY_LEFTCURL			equ	'{'
KEY_RIGHTCURL			equ	'}'
KEY_DOLLAR				equ	'$'
KEY_POUND				equ	'£'
KEY_EURO				equ	'$'
KEY_LESS				equ	'<'
KEY_GREATER				equ	'>'
KEY_BAR					equ	'|'
KEY_GRAVE				equ	'`'
KEY_TILDE				equ	'~'
KEY_AT					equ	'@'
KEY_CARRET				equ	'^'

;// Numeric keypad //////////////////////

KEY_KP_0			equ	'0'
KEY_KP_1			equ	'1'
KEY_KP_2			equ	'2'
KEY_KP_3			equ	'3'
KEY_KP_4			equ	'4'
KEY_KP_5			equ	'5'
KEY_KP_6			equ	'6'
KEY_KP_7			equ	'7'
KEY_KP_8			equ	'8'
KEY_KP_9			equ	'9'
KEY_KP_PLUS			equ	'+'
KEY_KP_MINUS		equ	'-'
KEY_KP_DECIMAL		equ	'.'
KEY_KP_DIVIDE		equ	'/'
KEY_KP_ASTERISK		equ	'*'
KEY_KP_NUMLOCK		equ	0x300f
KEY_KP_ENTER		equ	0x3010

;KEY_TAB				equ	0x4000
KEY_TAB				equ	0x09
KEY_CAPSLOCK		equ	0x4001

;// Modify keys ////////////////////////////

KEY_LSHIFT		equ	0x4002
KEY_LCTRL		equ	0x4003
KEY_LALT		equ	0x4004
KEY_LWIN		equ	0x4005
KEY_RSHIFT		equ	0x4006
KEY_RCTRL		equ	0x4007
KEY_RALT		equ	0x4008
KEY_RWIN		equ	0x4009

KEY_INSERT		equ	0x400a				; these are also KEY_KP_XXXX keys
KEY_DELETE		equ	0x400b
KEY_HOME		equ	0x400c				; KEY_KP_7
KEY_END			equ	0x400d
KEY_PAGEUP		equ	0x400e
KEY_PAGEDOWN	equ	0x400f
KEY_SCROLLLOCK	equ	0x4010
KEY_PAUSE		equ	0x4011

KEY_UNKNOWN		equ	0x4012
KEY_NUMKEYCODES	equ 0x4013


; from kybrd.cpp

;enum KYBRD_ENCODER_IO {

KYBRD_ENC_INPUT_BUF	equ	0x60
KYBRD_ENC_CMD_REG	equ	0x60


;enum KYBRD_ENC_CMDS {
KYBRD_ENC_CMD_SET_LED				equ	0xED
KYBRD_ENC_CMD_ECHO					equ	0xEE
KYBRD_ENC_CMD_SCAN_CODE_SET			equ	0xF0
KYBRD_ENC_CMD_ID					equ	0xF2
KYBRD_ENC_CMD_AUTODELAY				equ	0xF3
KYBRD_ENC_CMD_ENABLE				equ	0xF4
KYBRD_ENC_CMD_RESETWAIT				equ	0xF5
KYBRD_ENC_CMD_RESETSCAN				equ	0xF6
KYBRD_ENC_CMD_ALL_AUTO				equ	0xF7
KYBRD_ENC_CMD_ALL_MAKEBREAK			equ	0xF8
KYBRD_ENC_CMD_ALL_MAKEONLY			equ	0xF9
KYBRD_ENC_CMD_ALL_MAKEBREAK_AUTO	equ	0xFA
KYBRD_ENC_CMD_SINGLE_AUTOREPEAT		equ	0xFB
KYBRD_ENC_CMD_SINGLE_MAKEBREAK		equ	0xFC
KYBRD_ENC_CMD_SINGLE_BREAKONLY		equ	0xFD
KYBRD_ENC_CMD_RESEND				equ	0xFE
KYBRD_ENC_CMD_RESET					equ	0xFF

;// keyboard controller ---------------------------------------

;enum KYBRD_CTRL_IO {

KYBRD_CTRL_STATS_REG	equ	0x64
KYBRD_CTRL_CMD_REG		equ	0x64


;enum KYBRD_CTRL_STATS_MASK {

KYBRD_CTRL_STATS_MASK_OUT_BUF	equ	1		; 00000001
KYBRD_CTRL_STATS_MASK_IN_BUF	equ	2		; 00000010
KYBRD_CTRL_STATS_MASK_SYSTEM	equ	4		; 00000100
KYBRD_CTRL_STATS_MASK_CMD_DATA	equ	8		; 00001000
KYBRD_CTRL_STATS_MASK_LOCKED	equ	0x10	; 00010000
KYBRD_CTRL_STATS_MASK_AUX_BUF	equ	0x20	; 00100000
KYBRD_CTRL_STATS_MASK_TIMEOUT	equ	0x40	; 01000000
KYBRD_CTRL_STATS_MASK_PARITY	equ	0x80	; 10000000


;enum KYBRD_CTRL_CMDS {

KYBRD_CTRL_CMD_READ				equ	0x20
KYBRD_CTRL_CMD_WRITE			equ	0x60
KYBRD_CTRL_CMD_SELF_TEST		equ	0xAA
KYBRD_CTRL_CMD_INTERFACE_TEST	equ	0xAB
KYBRD_CTRL_CMD_DISABLE			equ	0xAD
KYBRD_CTRL_CMD_ENABLE			equ	0xAE
KYBRD_CTRL_CMD_READ_IN_PORT		equ	0xC0
KYBRD_CTRL_CMD_READ_OUT_PORT	equ	0xD0
KYBRD_CTRL_CMD_WRITE_OUT_PORT	equ	0xD1
KYBRD_CTRL_CMD_READ_TEST_INPUTS	equ	0xE0
KYBRD_CTRL_CMD_SYSTEM_RESET		equ	0xFE
KYBRD_CTRL_CMD_MOUSE_DISABLE	equ	0xA7
KYBRD_CTRL_CMD_MOUSE_ENABLE		equ	0xA8
KYBRD_CTRL_CMD_MOUSE_PORT_TEST	equ	0xA9
KYBRD_CTRL_CMD_MOUSE_WRITE		equ	0xD4


;// scan error codes ------------------------------------------

;enum KYBRD_ERROR {

KYBRD_ERR_BUF_OVERRUN			equ	0
KYBRD_ERR_ID_RET				equ	0x83AB
KYBRD_ERR_BAT					equ	0xAA	;//note: can also be L. shift key make code
KYBRD_ERR_ECHO_RET				equ	0xEE
KYBRD_ERR_ACK					equ	0xFA
KYBRD_ERR_BAT_FAILED			equ	0xFC
KYBRD_ERR_DIAG_FAILED			equ	0xFD
KYBRD_ERR_RESEND_CMD			equ	0xFE
KYBRD_ERR_KEY					equ	0xFF


KYBRD_IRQ_NUM		equ	33
;//! invalid scan code. Used to indicate the last scan code is not to be reused
KYBRD_INVALID_SCANCODE	equ	0
KYBRD_SCROLLLOCK	equ	0x01			; or define!?
KYBRD_NUMLOCK		equ	0x02
KYBRD_CAPSLOCK		equ	0x04
KYBRD_SHIFT			equ	0x10
KYBRD_ALT			equ	0x20
KYBRD_CTRL			equ	0x40

KYBRD_SHIFTCAPS		equ	(KYBRD_CAPSLOCK+KYBRD_SHIFT)

KYBRD_LOCK_MASK		equ	0x07
KYBRD_SAC_MASK		equ	0x70

KYBRD_BAT_RES		equ	0x01
KYBRD_DIAG_RES		equ	0x02
KYBRD_RESEND_RES	equ	0x04
KYBRD_DISABLE		equ	0x08


section .text

;***************************************************
; kybrd_ctrl_send_cmd
; send command byte to keyboard controller
; AL: command
;***************************************************
kybrd_ctrl_send_cmd:
			mov bl, al
.Read		in al, KYBRD_CTRL_STATS_REG
			and al, KYBRD_CTRL_STATS_MASK_IN_BUF
			cmp al, 0
			jnz .Read
			mov al, bl
			out KYBRD_CTRL_CMD_REG, al
			ret


;***************************************************
; kybrd_enc_send_cmd
; send command byte to keyboard encoder
; AL: command
;***************************************************
kybrd_enc_send_cmd:
			mov bl, al
.Read		in al, KYBRD_CTRL_STATS_REG
			and al, KYBRD_CTRL_STATS_MASK_IN_BUF
			cmp al, 0
			jnz .Read
			mov al, bl
			out KYBRD_ENC_CMD_REG, al
			ret


;***************************************************
; kybrd_irq
;***************************************************
kybrd_irq:
			cli
			pushad						;!?
			in	al, KYBRD_CTRL_STATS_REG
			test al, KYBRD_CTRL_STATS_MASK_OUT_BUF
			jz	.Back
			in	al, KYBRD_ENC_INPUT_BUF				; read scan code
			cmp al, 0xE0							; Is this an extended code?
			jz	.Extended
			cmp al, 0xE1
			jz	.Extended							; Is this an extended code?
			jmp	.Normal
.Extended	mov [kybrd_extended], WORD 1
			jmp .ChkErrs
.Normal		mov [kybrd_extended], WORD 0
			test al, 0x80							; Key released?
			jnz	.Released
			jmp .Pressed
.Released	sub al, 0x80							; convert to normal code
			xor ebx, ebx
			mov bl, al
			mov cx, [kybrd_scancode_std+ebx*2]
			cmp cx, KEY_LCTRL						; test if a special key was released and set it
			jz	.Ctrl
			cmp cx, KEY_RCTRL
			jz	.Ctrl
			cmp cx, KEY_LSHIFT
			jz	.Shift
			cmp cx, KEY_RSHIFT
			jz	.Shift
			cmp cx, KEY_LALT
			jz	.Alt
			cmp cx, KEY_RALT
			jz	.Alt
			jmp .ChkErrs
.Ctrl		mov bl, KYBRD_CTRL
			not bl
			and [kybrd_state], bl
			jmp .ChkErrs
.Shift		mov bl, KYBRD_SHIFT
			not bl
			and [kybrd_state], bl
			jmp .ChkErrs
.Alt		mov bl, KYBRD_ALT
			not bl
			and [kybrd_state], bl
			jmp .ChkErrs
.Pressed	mov [kybrd_scancode], al
			xor ebx, ebx
			mov bl, al
			mov cx, [kybrd_scancode_std+ebx*2] 		; It's a WORD array 2*CH
			cmp cx, KEY_LCTRL
			jz .CtrlPr
			cmp cx, KEY_RCTRL
			jz .CtrlPr
			cmp cx, KEY_LSHIFT
			jz .ShiftPr
			cmp cx, KEY_RSHIFT
			jz .ShiftPr
			cmp cx, KEY_LALT
			jz .AltPr
			cmp cx, KEY_RALT
			jz .AltPr
			cmp cx, KEY_CAPSLOCK
			jz .CapsPr
			cmp cx, KEY_KP_NUMLOCK
			jz .NumPr
			cmp cx, KEY_SCROLLLOCK
			jz .ScrollPr
			jmp .ChkErrs
.CtrlPr		or	[kybrd_state], BYTE KYBRD_CTRL
			jmp .ChkErrs
.ShiftPr	or	[kybrd_state], BYTE KYBRD_SHIFT
			jmp .ChkErrs
.AltPr		or	[kybrd_state], BYTE KYBRD_ALT
			jmp .ChkErrs
.CapsPr		test [kybrd_state], BYTE KYBRD_CAPSLOCK
			jz	.CapsPr1
			mov bl, KYBRD_CAPSLOCK
			not bl
			and [kybrd_state], bl
			call kybrd_set_leds
			jmp .ChkErrs
.CapsPr1	or [kybrd_state], BYTE KYBRD_CAPSLOCK
			call kybrd_set_leds
			jmp .ChkErrs
.NumPr		test [kybrd_state], BYTE KYBRD_NUMLOCK
			jz	.NumPr1
			mov bl, KYBRD_NUMLOCK
			not bl
			and [kybrd_state], bl
			call kybrd_set_leds
			jmp .ChkErrs
.NumPr1		or [kybrd_state], BYTE KYBRD_NUMLOCK
			call kybrd_set_leds
			jmp .ChkErrs
.ScrollPr	test [kybrd_state], BYTE KYBRD_SCROLLLOCK
			jz	.ScrollPr1
			mov bl, KYBRD_SCROLLLOCK
			not bl
			and [kybrd_state], bl
			call kybrd_set_leds
			jmp .ChkErrs
.ScrollPr1	or [kybrd_state], BYTE KYBRD_SCROLLLOCK
			call kybrd_set_leds
			jmp .ChkErrs
.ChkErrs	cmp al, KYBRD_ERR_BAT_FAILED
			jnz	.Diag
			mov bl, KYBRD_BAT_RES
			not bl
			and [kybrd_state2], bl
			jmp .Back
.Diag		cmp al, KYBRD_ERR_DIAG_FAILED
			jnz	.Resend
			mov bl, KYBRD_DIAG_RES
			not bl
			and [kybrd_state2], bl
			jmp .Back
.Resend		cmp al, KYBRD_ERR_RESEND_CMD
			jnz	.Back
			or	[kybrd_state2], BYTE KYBRD_RESEND_RES
.Back		mov al, 0 ;!?							; EOI
			call pic_interrupt_done
			popad						;!?
			sti
			iret


;//============================================================================
;//    INTERFACE FUNCTIONS
;//============================================================================
;***************************************************
; kybrd_get_scroll_lock
; AL: 1 if set
;***************************************************
kybrd_get_scroll_lock:
			mov al, [kybrd_state]
			and al, KYBRD_SCROLLLOCK
			ret


;***************************************************
; kybrd_get_numlock
; AL: 1 if set
;***************************************************
kybrd_get_num_lock:
			mov al, [kybrd_state]
			and al, KYBRD_NUMLOCK
			shr al, 1
			ret


;***************************************************
; kybrd_get_capslock
; AL: 1 if set
;***************************************************
kybrd_get_caps_lock:
			mov al, [kybrd_state]
			and al, KYBRD_CAPSLOCK
			shr al, 2
			ret


;***************************************************
; kybrd_get_ctrl
; AL: 1 if set
;***************************************************
kybrd_get_ctrl:
			mov al, [kybrd_state]
			and al, KYBRD_CTRL
			shr al, 6
			ret


;***************************************************
; kybrd_get_alt
; AL: 1 if set
;***************************************************
kybrd_get_alt:
			mov al, [kybrd_state]
			and al, KYBRD_ALT
			shr al, 5
			ret


;***************************************************
; kybrd_get_shift
; AL: 1 if set
;***************************************************
kybrd_get_shift:
			mov al, [kybrd_state]
			and al, KYBRD_SHIFT
			shr al, 4
			ret


;***************************************************
; kybrd_ignore_resend
;***************************************************
kybrd_ignore_resend:
			mov al, KYBRD_RESEND_RES
			not al
			and [kybrd_state2], al
			ret


;***************************************************
; kybrd_get_resend
; return if system should redo last commands
; AL: 1 if resend ; Out
;***************************************************
kybrd_get_resend:
			mov al, [kybrd_state2]
			and al, KYBRD_RESEND_RES
			shr al, 2
			ret

;***************************************************
; kybrd_get_diagnostic_res
; return diagnostics test result
; AL: 1 if diag_res ; Out
;***************************************************
kybrd_get_diagnostic_res:
			mov al, [kybrd_state2]
			and al, KYBRD_DIAG_RES
			shr al, 1
			ret


;***************************************************
; kybrd_get_bat_res
; return BAT test result
; AL: 1 if bat_res ; Out
;***************************************************
kybrd_get_bat_res:
			mov al, [kybrd_state2]
			and al, KYBRD_BAT_RES
			ret


;***********************************************
; kybrd_set_leds
;***********************************************
kybrd_set_leds:
			mov al, KYBRD_ENC_CMD_SET_LED
			call kybrd_enc_send_cmd
			mov al, [kybrd_state]
			and	al, KYBRD_LOCK_MASK
			call kybrd_enc_send_cmd
			ret


;***********************************************
; kybrd_get_last_key
; AX: last key ; Out
;***********************************************
kybrd_get_last_key:
			cmp [kybrd_scancode], BYTE KYBRD_INVALID_SCANCODE
			jnz .Known
			mov ax, KEY_UNKNOWN
			jmp .End
.Known		push ebx
			xor ebx, ebx
			mov bl, BYTE [kybrd_scancode]
			mov ax, WORD [kybrd_scancode_std+ebx*2]
			pop ebx
.End		ret


;***********************************************
; kybrd_discard_last_key
;***********************************************
kybrd_discard_last_key:
			mov [kybrd_scancode], BYTE KYBRD_INVALID_SCANCODE
			ret


;***********************************************
; kybrd_key_to_ascii
; AX: key		; In 		; call kybrd_get_last_key first to get key
; BL: ascii		; Out
;***********************************************
kybrd_key_to_ascii:
			push ecx
			xor ebx, ebx
			mov bx, ax
			cmp bx, WORD 0x7F
			jng	.Ascii
			cmp bx, KEY_ESCAPE
			jnz	.CurUp
			xor ebx, ebx
			mov bl, 27
			jmp .Back
.CurUp		cmp bx, KEY_UP
			jnz	.CurDown
			xor ebx, ebx
			mov bl, 22
			jmp .Back
.CurDown	cmp bx, KEY_DOWN
			jnz	.CurLeft
			xor ebx, ebx
			mov bl, 23
			jmp .Back
.CurLeft	cmp bx, KEY_LEFT
			jnz	.CurRight
			xor ebx, ebx
			mov bl, 24
			jmp .Back
.CurRight	cmp bx, KEY_RIGHT
			jnz	.F1
			xor ebx, ebx
			mov bl, 25
			jmp .Back
.F1			cmp bx, KEY_F1
			jnz	.F2
			xor ebx, ebx
			mov bl, 1
			jmp .Back
.F2			cmp bx, KEY_F2
			jnz	.F3
			xor ebx, ebx
			mov bl, 2
			jmp .Back
.F3			cmp bx, KEY_F3
			jnz	.F4
			xor ebx, ebx
			mov bl, 3
			jmp .Back
.F4			cmp bx, KEY_F4
			jnz	.F5
			xor ebx, ebx
			mov bl, 4
			jmp .Back
.F5			cmp bx, KEY_F5
			jnz	.F6
			xor ebx, ebx
			mov bl, 5
			jmp .Back
.F6			cmp bx, KEY_F6
			jnz	.F7
			xor ebx, ebx
			mov bl, 6
			jmp .Back
.F7			cmp bx, KEY_F7
			jnz	.F8
			xor ebx, ebx
			mov bl, 16
			jmp .Back
.F8			cmp bx, KEY_F8
			jnz	.F9
			xor ebx, ebx
			mov bl, 17
			jmp .Back
.F9			cmp bx, KEY_F9
			jnz	.F10
			xor ebx, ebx
			mov bl, 18
			jmp .Back
.F10		cmp bx, KEY_F10
			jnz	.F11
			xor ebx, ebx
			mov bl, 19
			jmp .Back
.F11		cmp bx, KEY_F11
			jnz	.F12
			xor ebx, ebx
			mov bl, 20
			jmp .Back
.F12		cmp bx, KEY_F12
			jnz	.PGUP
			xor ebx, ebx
			mov bl, 21
			jmp .Back
.PGUP		cmp bx, KEY_PAGEUP
			jnz	.PGDN
			xor ebx, ebx
			mov bl, 28
			jmp .Back
.PGDN		cmp bx, KEY_PAGEDOWN
			jnz	.INSERT
			xor ebx, ebx
			mov bl, 29
			jmp .Back
.INSERT		cmp bx, KEY_INSERT
			jnz	.DELETE
			xor ebx, ebx
			mov bl, 14
			jmp .Back
.DELETE		cmp bx, KEY_DELETE
			jnz	.HOME
			xor ebx, ebx
			mov bl, 15
			jmp .Back
.HOME		cmp bx, KEY_HOME
			jnz	.END
			xor ebx, ebx
			mov bl, 30
			jmp .Back
.END		cmp bx, KEY_END
			jnz	.Clear
			xor ebx, ebx
			mov bl, 31
			jmp .Back
.Clear		mov bx, 0
			jmp .Back
.Ascii		cmp bl, 'a'							; bl >= 'a' ?
			jge .CheckZ
			jmp	.Shift
.CheckZ		cmp bl, 'z'							; bl <= 'z' ?
			jng .ShCaps
			jmp .Shift
.ShCaps		test [kybrd_state], BYTE KYBRD_SHIFTCAPS
			jz	.Shift
			sub	bl, 32							; if shift is down or caps is on, make the key uppercase
.Shift		test [kybrd_state], BYTE KYBRD_SHIFT		; check '0' <= bl <= '9' and , . ; ' [ ] - = \ ` with shift
			jz	.Back
			mov ecx, 0
.Next		cmp bl, [kybrd_ch_arr+ecx]
			jz .Up
			inc ecx
			cmp ecx, 22
			jnz	.Next
			jmp .Back
.Up			mov bl, [kybrd_ch_arr_sh+ecx]
.Back		pop ecx
			ret



;***************************************************
; kybrd_disable
;***************************************************
kybrd_disable:
			mov al, KYBRD_CTRL_CMD_DISABLE
			call kybrd_ctrl_send_cmd
			or [kybrd_state2], BYTE KYBRD_DISABLE
			ret


;***************************************************
; kybrd_enable
;***************************************************
kybrd_enable:
			mov al, KYBRD_CTRL_CMD_ENABLE
			call kybrd_ctrl_send_cmd
			mov al, KYBRD_DISABLE
			not al
			and [kybrd_state2], al
			ret


;***************************************************
; kybrd_get_disabled
; AL: 1 if disabled ; Out
;***************************************************
kybrd_get_disabled:
			mov al, [kybrd_state2]
			and al, KYBRD_DISABLE
			shr al, 3
			ret


;***************************************************
; kybrd_reset_system
;***************************************************
kybrd_reset_system:
			; writes 11111110 to the output port (sets reset system line low)
			mov al, KYBRD_CTRL_CMD_WRITE_OUT_PORT
			call kybrd_ctrl_send_cmd
			mov al, 0xFE
			call kybrd_enc_send_cmd
			ret


;***************************************************
; kybrd_self_test
; run self test
; AL: 1 (true), 0 (false) ; Out
;***************************************************
kybrd_self_test:
			mov al, KYBRD_CTRL_CMD_SELF_TEST
			call kybrd_ctrl_send_cmd
.Read		in al, KYBRD_CTRL_STATS_REG
			and al, KYBRD_CTRL_STATS_MASK_OUT_BUF
			cmp al, 0
			jnz .Read

			in al, KYBRD_ENC_INPUT_BUF
			cmp al, 0x55
			jz .Passed
			mov al, 0
			jmp .Back
			; if output buffer == 0x55, test passed
.Passed		mov al, 1
.Back		ret



;***********************************************
; kybrd_init
;***********************************************
kybrd_init:
			mov ebx, KYBRD_IRQ_NUM
			mov edx, kybrd_irq
			call idt_install_irh
			mov [kybrd_state2], BYTE 0
			or	[kybrd_state2], BYTE KYBRD_BAT_RES
			mov [kybrd_scancode], BYTE 0
			mov [kybrd_state], BYTE 0
			call kybrd_set_leds
			ret


section .data

;//! original xt scan code set. Array index==make code
;//! change what keys the scan code correspond to if your scan code set is different
; scancodes from 0x0 to 0x58
kybrd_scancode_std  dw KEY_UNKNOWN, KEY_ESCAPE, KEY_1,	KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL
					dw KEY_BACKSPACE, KEY_TAB, KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P, KEY_LEFTBRACKET
					dw KEY_RIGHTBRACKET, KEY_RETURN, KEY_LCTRL, KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON
					dw KEY_QUOTE, KEY_GRAVE, KEY_LSHIFT, KEY_BACKSLASH, KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M, KEY_COMMA, KEY_DOT
					dw KEY_SLASH, KEY_RSHIFT, KEY_KP_ASTERISK, KEY_RALT, KEY_SPACE, KEY_CAPSLOCK, KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6
					dw KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_KP_NUMLOCK, KEY_SCROLLLOCK, KEY_HOME, KEY_UP, KEY_PAGEUP, KEY_KP_MINUS, KEY_LEFT
					dw KEY_KP_5, KEY_RIGHT, KEY_KP_PLUS, KEY_END, KEY_DOWN, KEY_PAGEDOWN, KEY_INSERT, KEY_DELETE, KEY_UNKNOWN, KEY_UNKNOWN
					dw KEY_UNKNOWN, KEY_F11, KEY_F12


kybrd_scancode		db	0				; last scan code

kybrd_state			db	0				; bits

kybrd_error			db	0

kybrd_state2		db	0				;bits

kybrd_extended		db	0

; Note! the first byte is a zero (dummy) because for some reason SHIFT+0 always prints '0' instead of ')'
kybrd_ch_arr		db	0, KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_COMMA, KEY_DOT, KEY_SLASH, KEY_SEMICOLON, KEY_QUOTE, KEY_LEFTBRACKET, KEY_RIGHTBRACKET, KEY_GRAVE, KEY_MINUS, KEY_EQUAL, KEY_BACKSLASH
kybrd_ch_arr_sh	db	0, KEY_RIGHTPARENTHESIS, KEY_EXCLAMATION, KEY_AT, KEY_HASH, KEY_DOLLAR, KEY_PERCENT, KEY_CARRET, KEY_AMPERSAND, KEY_ASTERISK, KEY_LEFTPARENTHESIS, KEY_LESS, KEY_GREATER, KEY_QUESTION, KEY_COLON, KEY_QUOTEDOUBLE, KEY_LEFTCURL, KEY_RIGHTCURL, KEY_TILDE, KEY_UNDERSCORE, KEY_PLUS, KEY_BAR


%endif

