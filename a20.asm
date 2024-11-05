
;********************************************
;	Enable A20 address line
;
;********************************************

%ifndef __A20__
%define __A20__

bits 16


section .text

;********************************************
; a20_enable_kybrd
; Enables a20 line through keyboard controller
;********************************************
a20_enable_kybrd:
			cli
			push ax
			mov	al, 0xdd		; send enable a20 address line command to controller
			out	0x64, al
			pop	ax
			ret


;********************************************
; a20_enable_kybrd_out
; Enables a20 line through output port
;********************************************
a20_enable_kybrd_out:
			cli
			pusha

	        call a20_wait_input
	        mov	al, 0xAD
			out 0x64, al		; disable keyboard
			call a20_wait_input

			mov al, 0xD0
			out 0x64, al		; tell controller to read output port
			call a20_wait_output

			in al, 0x60
			push eax			; get output port data and store it
			call a20_wait_input

			mov al, 0xD1
			out 0x64, al		; tell controller to write output port
			call a20_wait_input

			pop eax
			or al, 2			; set bit 1 (enable a20)
			out 0x60, al		; write out data back to the output port

			call a20_wait_input
			mov al, 0xAE		; enable keyboard
			out 0x64, al

			call a20_wait_input
			popa
			sti
			ret


;********************************************
; a20_wait_input
; wait for input buffer to be clear
;********************************************
a20_wait_input:
			in al, 0x64
			test al, 2
			jnz a20_wait_input
			ret


;********************************************
; a20_wait_output
; wait for output buffer to be clear
;********************************************
a20_wait_output:
			in al, 0x64
			test al, 1
			jz a20_wait_output
			ret


;********************************************
; a20_enable_bios
; Enables a20 line through bios
;********************************************
; Not used!?
a20_enable_bios:
			pusha
			mov	ax, 0x2401
			int	0x15
			popa
			ret


;********************************************
; a20_enable_syscontrol_a
; Enables a20 line through system control port A
;********************************************
; Not used!?
a20_enable_syscontrol_a:
			push ax
			mov	al, 2
			out	0x92, al
			pop	ax
			ret


%endif

