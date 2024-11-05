%ifndef __VGA__
%define	__VGA__ 

 
%include "stdio16.asm"
%include "defs.asm"


bits 16	

%define FRAMEBUFF	0x8FF0

%define VGA_SMALLRES	0x111		; for eee pc (640*480*16)
%define VGA_NORMALRES	0x117		; 1024*768*16

%ifdef NORMALRES_DEF
	%define VGA_RES		0x117		; 1024*768*16
	%define	VGA_RES_W	1024
	%define	VGA_RES_H	768
%else
	%define VGA_RES		0x111		; for eee pc (640*480*16)
	%define	VGA_RES_W	640
	%define	VGA_RES_H	480
%endif

VGA_MODE_SUPPORTED	equ	0x0001
VGA_MODE_COLOR		equ	0x0008	; !? is this necessary (Monochrome or color)
VGA_MODE_GRAPHICAL	equ	0x0010
VGA_MODE_VGA_COMPAT	equ	0x0020
							; bit 6: VGA compatWindowed, would be necessary!?
VGA_MODE_LFB		equ	0x0080


section .text

;****************************************************
; vga_get_framebuff
;	OUT: EAX (LFB or zero)
;****************************************************
vga_get_framebuff:
			push cx
			push di
 
			; get vga2_mode_info
			mov ax, 0x4F01
			mov di, vga_info_arr
			mov cx, VGA_RES
			int 10h						; result in ES:DI
			cmp ax, 0x004F				; if AL != 4F then the mode doesn't exist; AH == 0 function call successful
			jz	.Exists			
			jmp .NotFound

.Exists		mov cx, WORD [es:di]		; check ModeAttributes
			test cx, VGA_MODE_SUPPORTED
			jnz .Attr2
			jmp .NotFound
.Attr2		test cx, VGA_MODE_COLOR
			jnz .Attr3
			jmp .NotFound
.Attr3		test cx, VGA_MODE_GRAPHICAL
			jnz .Attr4
			jmp .NotFound
.Attr4		test cx, VGA_MODE_LFB
			jnz .AttribsOk
			jmp .NotFound
.AttribsOk	mov ax, WORD [es:di+18]	; X Resolution
			cmp ax, VGA_RES_W
			jnz .NotFound
			mov ax, WORD [es:di+20]	; Y Resolution
			cmp ax, VGA_RES_H
			jnz .NotFound
			mov al, BYTE [es:di+25]	; BPP
			cmp al, 16
			jnz .NotFound
			xor eax, eax
			mov ax, WORD [es:di+42]	; LinearFrameBuffer
			shl	eax, 16
			mov ax, WORD [es:di+40]
			mov DWORD [FRAMEBUFF], eax
			jmp .Back
.NotFound	xor eax, eax
.Back		pop di
			pop cx
			ret



;***************************************************
; vga_switch_to_mode
; BX: mode (bits0-8)
;***************************************************
vga_switch_to_mode:
			pusha
			mov ax, 4F02h				; Set VBE mode
			or bx, 0100000000000000b	; Use Linear FrameBuffer (LFB) instead of VGA framebuffer (needs banking) ; bit 15th is zero: clear memory 
			int 10h						; LFB is from e.g. 0xE0000000
								; The 7th bit of modeattributes of the modeinfoblock is set if there is an LFB
			popa
			ret


section .data

vga_info_arr		times 512 db 0	; VBEInfoBlock


%endif

