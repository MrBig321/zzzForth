%ifndef __FORTH_FACILITY__
%define __FORTH_FACILITY__


%include "forth/common.asm"
;%include "gstdiodefs.asm"
%include "gstdio.asm"
%include "kybrd.asm"


; same as in loader.asm, hdloader.asm, hdfsloader.asm, forth/hd.asm, ram.asm, kernel.asm (and MemMap in forth/common.asm)
%define	RAM_MAP_ENT_LOC		0x6FFE
%define	RAM_MAP_LOC			0x7000
%define RAM_SIZE_LO_LOC		0x8FF4
%define RAM_SIZE_HI_LOC		0x8FF8
%define	RAM_MAP_LINE_LEN	24


section .text

;*********************************************
; _page				PAGE
;	( -- )
;*********************************************
_page:
			mov ebx, 1
			call gstdio_clrscr
			ret


;*********************************************
; _page_n				PAGEN
;	( -- )
; No invalidating the screen is done.
; We need to call INVSCR after PAGEN
;*********************************************
_page_n:
			xor ebx, ebx
			call gstdio_clrscr
			ret


;*********************************************
; _date				DATE			called TIME&DATE in ANSI
;	( -- dow d m y )
;	day of week(zero is Sunday), day, month, year
;	Should be printed as hex (because it's BCD)
;*********************************************
_date:
			xor eax, eax
			mov al, 0x06			; Day of Week
			out 0x70, al
			in al, 0x71
			PUSH_PS(eax)

			xor eax, eax
			mov al, 0x07			; Day of Month
			out 0x70, al
			in al, 0x71
			PUSH_PS(eax)

			xor eax, eax
			mov al, 0x08			; Month
			out 0x70, al
			in al, 0x71
			PUSH_PS(eax)

			xor eax, eax
			mov al, 0x09			; Year
			out 0x70, al
			in al, 0x71
			PUSH_PS(eax)

			ret


;*********************************************
; _at_x_y			AT-XY
;	( x y -- )
;	Moves cursor to x, y on the screen
;*********************************************
_at_x_y:
			POP_PS(ebx)
			POP_PS(ecx)
			mov al, cl
			mov ah, bl
			call gstdio_goto_xy
			ret


;*********************************************
; _get_x_y			GET-XY
;	( -- x y )
;	Retrievs cursor position
;*********************************************
_get_x_y:
			xor eax, eax
			mov al, [gstdio_cur_x]
			PUSH_PS(eax)
			mov al, [gstdio_cur_y]
			PUSH_PS(eax)
			ret


;*********************************************
; _time				TIME			called TIME&DATE in ANSI
;	( -- s, m, h )
;	Should be printed as hex (because it's BCD)
;*********************************************
_time:
			xor eax, eax
			mov al, 0x00			; Second
			out 0x70, al
			in al, 0x71
			PUSH_PS(eax)

			xor eax, eax
			mov al, 0x02			; Minute
			out 0x70, al
			in al, 0x71
			PUSH_PS(eax)

			xor eax, eax
			mov al, 0x04			; Hour
			out 0x70, al
			in al, 0x71
			PUSH_PS(eax)

			ret


;*********************************************************************
; _ram_map			RAMMAP
;	( -- )
;	Prints RAM-map, got from BIOS in real-mode
;*********************************************************************
_ram_map:
			call gstdio_new_line
			mov	ebx, ram_txt
			call gstdio_draw_text
			mov edx, [RAM_SIZE_HI_LOC]
			call gstdio_draw_hex		
			mov edx, [RAM_SIZE_LO_LOC]
			call gstdio_draw_hex		
			call gstdio_new_line
			push edi
			mov	edi, RAM_MAP_LOC
			call show_ram_map
			pop edi
			ret


; show_ram_map
; EDI --> buffer RAM_MAP_LINE_LEN-byte entries
; First qword = Base address
; Second qword = Length of "region" (if this value is 0, ignore the entry)
; Next dword = Region "type"
;	Type 1: Usable (normal) RAM
;	Type 2: Reserved - unusable
;	Type 3: ACPI reclaimable memory
;	Type 4: ACPI NVS memory
;	Type 5: Area containing bad memory 
; Next dword = ACPI 3.0 Extended Attributes bitfield (if 24 bytes are returned, instead of 20)
;	Bit 0 of the Extended Attributes indicates if the entire entry should be ignored (if the bit is clear). This is going to be a huge compatibility problem because most current OSs won't read this bit and won't ignore the entry.
;	Bit 1 of the Extended Attributes indicates if the entry is non-volatile (if the bit is set) or not. The standard states that "Memory reported as non-volatile may require characterization to determine its suitability for use as conventional RAM."
;	The remaining 30 bits of the Extended Attributes are currently undefined. 
show_ram_map:
			mov ebx, ram_caption_txt
			call gstdio_draw_text
			call gstdio_new_line
			xor ecx, ecx
			mov cx, [RAM_MAP_ENT_LOC]
			; Base Address
.NextEntry	push ecx
			call ram_map_line
			call gstdio_new_line
			add edi, RAM_MAP_LINE_LEN
			pop ecx
			loop .NextEntry
			ret


; ram_map_line (EDI ptr to data)
ram_map_line:
			mov edx, [edi+4]
			call gstdio_draw_hex
			mov edx, [es:di]
			call gstdio_draw_hex
			mov ebx, ' '
			call gstdio_draw_char
			mov ebx, '|'
			call gstdio_draw_char
			mov ebx, ' '
			call gstdio_draw_char
			; Length
			mov edx, [edi+12]
			call gstdio_draw_hex
			mov edx, [es:di+8]
			call gstdio_draw_hex
			mov ebx, ' '
			call gstdio_draw_char
			mov ebx, '|'
			call gstdio_draw_char
			mov ebx, ' '
			call gstdio_draw_char
			; Type
			xor ebx, ebx
			mov ebx, [edi+16]
			cmp ebx, 3					; if ebx > 3 then treat it as undefined
			jng .Defined
			mov ebx, 5
.Defined	shl	ebx, 2					; multiply with 2 (DWORD)
			mov ebx, [ram_type_arr+ebx]
			call gstdio_draw_text
			ret


;*********************************************
; _reboot			REBOOT
;	( -- )
;	Reboots comp by using the 8042 keyboard 
;	controller to pulse the CPU's reset pin
;*********************************************
_reboot:
			cli
.Next		in	al, KYBRD_CTRL_CMD_REG		; empty user data
			mov bl, al
			test al, 1
			jz	.Skip
			in	al, KYBRD_ENC_INPUT_BUF		; empty keyboard buff
.Skip		test bl, 2
			jnz .Next
			mov al, 0xFE
			out KYBRD_CTRL_CMD_REG, al		; pulse CPU reset
			ret


;*********************************************
; _key_ctrl_question		KCTRL?
;	( -- flag )
;	flag is true if the Control-key is pressed
;*********************************************
_key_ctrl_question:
			call kybrd_get_ctrl
			cmp al, 1
			je	.Pressed
			PUSH_PS(FALSE)
			jmp .Back
.Pressed	PUSH_PS(TRUE)
.Back		ret


;*********************************************
; _key_shift_question		KSHIFT?
;	( -- flag )
;	flag is true if the Shift-key is pressed
;*********************************************
_key_shift_question:
			call kybrd_get_shift
			cmp al, 1
			je	.Pressed
			PUSH_PS(FALSE)
			jmp .Back
.Pressed	PUSH_PS(TRUE)
.Back		ret


;*********************************************
; _key_alt_question		KALT?
;	( -- flag )
;	flag is true if the Alt-key is pressed
;*********************************************
_key_alt_question:
			call kybrd_get_alt
			cmp al, 1
			je	.Pressed
			PUSH_PS(FALSE)
			jmp .Back
.Pressed	PUSH_PS(TRUE)
.Back		ret


;*********************************************
; _key_scroll_lock_question		KSCROLL?
;	( -- flag )
;	flag is true if the ScrollLock-key is pressed
;*********************************************
_key_scroll_lock_question:
			call kybrd_get_scroll_lock
			cmp al, 1
			je	.Pressed
			PUSH_PS(FALSE)
			jmp .Back
.Pressed	PUSH_PS(TRUE)
.Back		ret


;*********************************************
; _key_caps_lock_question		KCAPS?
;	( -- flag )
;	flag is true if the CapsLock-key is pressed
;*********************************************
_key_caps_lock_question:
			call kybrd_get_caps_lock
			cmp al, 1
			je	.Pressed
			PUSH_PS(FALSE)
			jmp .Back
.Pressed	PUSH_PS(TRUE)
.Back		ret


; Missing:
;EKEY 		(EXT)
;EKEY>CHAR 	(EXT)
;EKEY? 		(EXT)
;EMIT?		(EXT)
;KEY?
;MS			(EXT)		;delay, (pit_sleep)

section .data

ram_txt			db	"RAM: ", 0
ram_caption_txt	db	"Base Address     | Length           | Type", 0
ram_type0_txt	db	"Unknown", 0
ram_type1_txt	db	"Usable (normal) RAM", 0
ram_type2_txt	db	"Reserved - unusable", 0
ram_type3_txt	db	"ACPI reclaimable memory", 0
ram_type4_txt	db	"ACPI NVS memory", 0
ram_type5_txt	db	"Area containing bad memory", 0
ram_type6_txt	db	"Undefined", 0
ram_type_arr	dd	ram_type0_txt, ram_type1_txt, ram_type2_txt, ram_type3_txt, ram_type4_txt, ram_type5_txt, ram_type6_txt 


%endif

