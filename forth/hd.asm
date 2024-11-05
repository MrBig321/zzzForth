;************************
; HARD DISK
;************************

%ifndef __FORTH_HD__
%define __FORTH_HD__


%include "hd.asm"
%include "forth/common.asm"
%include "forth/core.asm"


;Boot form hard disk
%define IMAGE_PMODE_BASE 0x200000
; the same as in loader.asm, hdloader.asm, hdfsloader.asm, forth/hd.asm, ram.asm, kernel.asm (and MemMap in forth/common.asm)
%define KERNEL_SIZE_LOC	0x8FFC


section .text

;*************************************************
; _hd_info				HDINFO
;	( -- )
;	Displays info-block about detected winchester
;*************************************************
_hd_info:
			call _c_r
			call hd_info
.Back		ret


;*************************************************
; _hd_read				HDREAD
;	( memaddr sectcnt lbaHi lbaLo -- f )
;	Reads sectcnt sectors from sector given in lbaHi and lbaLo 
;	to memaddr
;	f is true on success, false otherwise
;*************************************************
_hd_read:
			push ebp
			POP_PS(ecx)
			POP_PS(ebp)
			POP_PS(ebx)
			POP_PS(eax)
			call hd_read
			cmp al, 0
			jnz .Err
			PUSH_PS(TRUE)
			jmp .Back
.Err		PUSH_PS(FALSE)
.Back		pop ebp
			ret


%ifdef MULTITASKING_DEF
;*************************************************
; _hd_read_dma			HDREADDMA
;	( memaddr sectcnt lbaHi lbaLo -- f )
;	Reads sectcnt sectors from sector given in lbaHi and lbaLo 
;	to memaddr
;	f is true on success, false otherwise
;*************************************************
_hd_read_dma:
			push ebp
			POP_PS(ecx)
			POP_PS(ebp)
			POP_PS(ebx)
			POP_PS(eax)
			call hd_read_dma
			cmp al, 0
			jnz .Err
			PUSH_PS(TRUE)
			jmp .Back
.Err		PUSH_PS(FALSE)
.Back		pop ebp
			ret

%endif


;*************************************************
; _hd_write				HDWRITE
;	( memaddr sectcnt lbaHi lbaLo -- f )
;	Writes sectcnt sectors from sector given in 
;	lbaHi and lbaLo from memaddr
;	f is true on success, false otherwise
;*************************************************
_hd_write:
			push ebp
			POP_PS(ecx)
			POP_PS(ebp)
			POP_PS(ebx)
			POP_PS(eax)
			call hd_write
			cmp al, 0
			jnz .Err
			PUSH_PS(TRUE)
			jmp .Back
.Err		PUSH_PS(FALSE)
.Back		pop ebp
			ret


%ifdef MULTITASKING_DEF
;*************************************************
; _hd_write_dma			HDWRITEDMA
;	( memaddr sectcnt lbaHi lbaLo -- f )
;	Writes sectcnt sectors from sector given in 
;	lbaHi and lbaLo from memaddr
;	f is true on success, false otherwise
; CURRENTLY sectcnt HAS TO BE MULTIPLIES OF 128, 
; OTHERWISE NO IRQ COMES FOR THE MODULO-PART
;*************************************************
_hd_write_dma:
			push ebp
			POP_PS(ecx)
			POP_PS(ebp)
			POP_PS(ebx)
			POP_PS(eax)
			call hd_write_dma
			cmp al, 0
			jnz .Err
			PUSH_PS(TRUE)
			jmp .Back
.Err		PUSH_PS(FALSE)
.Back		pop ebp
			ret

%endif


%ifdef HDINSTALL_DEF
;*************************************************
; _hd_install			HDINSTALL
;	( -- f )
;	Writes MBR to sector 0, loader to the next sectors 
;	and finally the bytes of FOS to the next sectors of 
;	the hard disk
;	f is true on success, false otherwise
;*************************************************
_hd_install:
			PUSH_PS(hdbootdata)
			PUSH_PS(1)
			PUSH_PS(0)
			PUSH_PS(0)
			call _hd_write
			mov eax, [esi]
			cmp eax, FALSE
			jz	.Back					; error
			POP_PS(eax)					; drop flag
			PUSH_PS(hdloderdata)
			PUSH_PS(7)
			PUSH_PS(0)
			PUSH_PS(1)
			call _hd_write
			mov eax, [esi]
			cmp eax, FALSE
			jz	.Back					; error
			POP_PS(eax)					; drop flag
		   	mov eax, IMAGE_PMODE_BASE
			PUSH_PS(eax)
			mov eax, DWORD [KERNEL_SIZE_LOC]
			shr	eax, 9					; /512 to get sectors
			inc eax						; add remainder
			PUSH_PS(eax)
			PUSH_PS(0)
			PUSH_PS(8)
			call _hd_write
.Back		ret
%endif


section .data


%ifdef HDINSTALL_DEF
; Used by HDINSTALL to be able to boot from winchester without a filesystem (if we use BLOCKs instead)
	%include "output/hdbootbytes.inc"
	%include "output/hdloaderbytes.inc"
%endif 


%endif

