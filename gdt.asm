;*************************************************
;	gdt.inc
;		-GDT Routines
;
;*************************************************

%ifndef __GDT__
%define __GDT__

bits 16


%define GDT_NULL_DESC 0
%define GDT_CODE_DESC 0x8
%define GDT_DATA_DESC 0x10


section .text

;*******************************************
; gdt_init
;	- Init our GDT
;*******************************************

gdt_init:
			cli					; clear interrupts
			pusha				; save registers
			lgdt [gdt_toc]		; load GDT into GDTR
			sti					; enable interrupts
			popa				; restore registers
			ret


section .data

;*******************************************
; Global Descriptor Table (GDT)
;*******************************************

gdt_data:
		dd 0				; null descriptor
		dd 0

; gdt code:					; code descriptor
		dw 0FFFFh			; limit low
		dw 0				; base low
		db 0				; base middle
		db 10011010b		; access
		db 11001111b		; granularity
		db 0				; base high

; gdt data:					; data descriptor
		dw 0FFFFh			; limit low (Same as code)
		dw 0				; base low
		db 0				; base middle
		db 10010010b		; access
		db 11001111b		; granularity
		db 0				; base high
	
end_of_gdt:
gdt_toc: 
		dw end_of_gdt - gdt_data - 1 	; limit (Size of GDT)
		dd gdt_data 					; base of GDT

; give the descriptor offsets names


%endif

