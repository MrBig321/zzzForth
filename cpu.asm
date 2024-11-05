;*************************************************
;	cpu.inc
;		-CPU Routines
;
; The availability of CPUID instruction is not checked, so only 
; Pentium or higher CPU is supported
;*************************************************

%ifndef __CPU__
%define __CPU__

%include "gstdio.asm"

bits 32  ; !?


;To identify the processor using the CPUID instructions, software should follow the following steps.
;	1. Determine if the CPUID instruction is supported by modifying the ID flag in the EFLAGS register. If the ID flag cannot be modified, the processor cannot be identified using the CPUID instruction.
;	2. Execute the CPUID instruction with EAX equal to 80000000h. CPUID function 80000000h is used to determine if Brand String is supported. If the CPUID function 80000000h returns a value in EAX greater than or equal to 80000004h the Brand String feature is supported and software should use CPUID functions 80000002h through 80000004h to identify the processor.
;	3. If the Brand String feature is not supported, execute CPUID with EAX equal to 1. CPUID function 1 returns the processor signature in the EAX register, and the Brand ID in the EBX register bits 0 through 7. If the EBX register bits 0 through 7 contain a non-zero value, the Brand ID is supported. Software should scan the list of Brand IDs (see Table 7-1) to identify the processor.
;	4. If the Brand ID feature is not supported, software should use the processor signature (see Table 5-3 and Table 5-4) in conjunction with the cache descriptors (see Section 5.1.3) to identify the processor.

; see processor-identification-cpuid-instruction-note.pdf

; EAX=0 CPUID		(vendor string)

; EAX=1	CPUID		(cpu info will be returned in eax and features in ecx and edx and additional feature info in ebx)
CPUID_INFO_EAX_STEPPING_MASK	equ 0x0000000F	; Stepping
CPUID_INFO_EAX_MODEL_MASK		equ 0x000000F0	; Model
CPUID_INFO_EAX_FAMILY_MASK		equ 0x00000F00	; Family
CPUID_INFO_EAX_TYPE_MASK		equ 0x00003000	; Cpu Type (00b Original OEM CPU; 01b Intel OverDrive CPU; 10b Dual CPU; 11b Intel Reserved (maybe Quad CPU))
CPUID_INFO_EAX_EXT_MODELL_MASK	equ 0x000F0000	; Extended Model
CPUID_INFO_EAX_EXT_FAMILY_MASK	equ 0x0FF00000	; Extended Family


CPUID_FEAT_ECX_SSE3			equ 0x00000001	;0
CPUID_FEAT_ECX_PCLMUL		equ 0x00000002	;1
CPUID_FEAT_ECX_DTES64		equ 0x00000004	;2
CPUID_FEAT_ECX_MONITOR		equ 0x00000008 	;3
CPUID_FEAT_ECX_DS_CPL		equ 0x00000010 	;4
CPUID_FEAT_ECX_VMX			equ 0x00000020	;5
CPUID_FEAT_ECX_SMX			equ 0x00000040	;6
CPUID_FEAT_ECX_EST			equ 0x00000080	;7
CPUID_FEAT_ECX_TM2			equ 0x00000100 	;8
CPUID_FEAT_ECX_SSSE3		equ 0x00000200 	;9
CPUID_FEAT_ECX_CID			equ 0x00000400 	;10
;	bit 11 is reserved
CPUID_FEAT_ECX_FMA			equ 0x00001000	;12
CPUID_FEAT_ECX_CX16			equ 0x00002000 	;13
CPUID_FEAT_ECX_XTPR			equ 0x00004000 	;14
CPUID_FEAT_ECX_PDCM			equ 0x00008000 	;15
;	bit 16 is reserved
CPUID_FEAT_ECX_PCID			equ 0x00020000	;17
CPUID_FEAT_ECX_DCA			equ 0x00040000	;18
CPUID_FEAT_ECX_SSE4_1		equ 0x00080000	;19
CPUID_FEAT_ECX_SSE4_2		equ 0x00100000	;20
CPUID_FEAT_ECX_x2APIC		equ 0x00200000	;21
CPUID_FEAT_ECX_MOVBE		equ 0x00400000	;22
CPUID_FEAT_ECX_POPCNT		equ 0x00800000	;23
CPUID_FEAT_ECX_TSCDEAD		equ 0x01000000	;24
CPUID_FEAT_ECX_AES			equ 0x02000000	;25
CPUID_FEAT_ECX_XSAVE		equ 0x04000000	;26
CPUID_FEAT_ECX_OSXSAVE		equ 0x08000000	;27
CPUID_FEAT_ECX_AVX			equ 0x10000000	;28
CPUID_FEAT_ECX_F16C			equ 0x20000000	;29
CPUID_FEAT_ECX_RDRND		equ 0x40000000	;30
CPUID_FEAT_ECX_HYPERV		equ 0x80000000	;31
 
CPUID_FEAT_EDX_FPU			equ 0x00000001	;0  
CPUID_FEAT_EDX_VME			equ 0x00000002	;1  
CPUID_FEAT_EDX_DE			equ 0x00000004	;2  
CPUID_FEAT_EDX_PSE			equ 0x00000008	;3  
CPUID_FEAT_EDX_TSC			equ 0x00000010	;4  
CPUID_FEAT_EDX_MSR			equ 0x00000020	;5  
CPUID_FEAT_EDX_PAE			equ 0x00000040	;6  
CPUID_FEAT_EDX_MCE			equ 0x00000080	;7  
CPUID_FEAT_EDX_CX8			equ 0x00000100	;8  
CPUID_FEAT_EDX_APIC			equ 0x00000200	;9  
;	bit 10 is reserved
CPUID_FEAT_EDX_SEP			equ 0x00000800	;11 
CPUID_FEAT_EDX_MTRR			equ 0x00001000	;12 
CPUID_FEAT_EDX_PGE			equ 0x00002000	;13 
CPUID_FEAT_EDX_MCA			equ 0x00004000	;14 
CPUID_FEAT_EDX_CMOV			equ 0x00008000	;15 
CPUID_FEAT_EDX_PAT			equ 0x00010000	;16 
CPUID_FEAT_EDX_PSE36		equ 0x00020000	;17 
CPUID_FEAT_EDX_PSN			equ 0x00040000	;18 
CPUID_FEAT_EDX_CLF			equ 0x00080000	;19 
;	bit 20 is reserved
CPUID_FEAT_EDX_DTES			equ 0x00200000	;21 
CPUID_FEAT_EDX_ACPI			equ 0x00400000	;22 
CPUID_FEAT_EDX_MMX			equ 0x00800000	;23 
CPUID_FEAT_EDX_FXSR			equ 0x01000000	;24 
CPUID_FEAT_EDX_SSE			equ 0x02000000	;25 
CPUID_FEAT_EDX_SSE2			equ 0x04000000	;26 
CPUID_FEAT_EDX_SS			equ 0x08000000	;27 
CPUID_FEAT_EDX_HTT			equ 0x10000000	;28 
CPUID_FEAT_EDX_TM1			equ 0x20000000	;29 
CPUID_FEAT_EDX_IA64			equ 0x40000000	;30
CPUID_FEAT_EDX_PBE			equ 0x80000000	;31


; For MTRR
CPU_MEM_TYPE_UC	equ	0	; UnCached
CPU_MEM_TYPE_WC	equ	1	; WriteCombined
CPU_MEM_TYPE_WB	equ	6	; WriteBack


; EAX=2 CPUID			(Cache and TLB description in EAX, EBX, ECX and EDX)

; EAX=3 CPUID			(cpu serial number in EDX:ECX (Intel Pentium III), EBX:EAX (Transmeta Efficeon), EBX Transmeta Crusoe)

; EAX=80000000h CPUID	(Get highest Extended Function Supported returned in eax)

; EAX=80000001h CPUID	(Extended CPU Info and Feature Bits) in EDX and ECX

; 48-byte null-terminated string (call in order to get the result in EAX, EBX, ECX and EDX). First check if this feature is supported by the CPU by issuing CPUID with EAX=80000000h first and checking if the returned value is >= to 80000004h.
; EAX=80000002h CPUID	(CPU Brand String)
; EAX=80000003h CPUID	(CPU Brand String)
; EAX=80000004h CPUID	(CPU Brand String)

; EAX=80000005h	CPUID	(L1 Chache and TLB Identifiers)

; EAX=80000006h	CPUID	(Extended L2 Chache Features)

; EAX=80000007h	CPUID	(Advanced Power Management Information)

; EAX=80000008h	CPUID	(Virtual and Physical Address Sizes; returnes the largets virt. and phys. address sizez in EAX)


section .text

;*************************************************
; cpu_show_info
;*************************************************
cpu_show_info:
			pushad
			mov	ebx, cpu_txt
			call gstdio_draw_text
			cmp BYTE [cpu_brand_string], 0
			jz	.BrandId
			mov	ebx, cpu_brand_string
			call gstdio_draw_text
			jmp	.End
.BrandId	cmp BYTE [cpu_brand_id_str], 0
			jz	.Vendor
			mov	ebx, cpu_brand_id_str
			call gstdio_draw_text	
			jmp	.End
.Vendor		mov esi, cpu_vendor
			mov ecx, 12
			call gstdio_draw_chars
.End		call gstdio_new_line
			popad
			ret


;*************************************************
; cpu_get_info
;*************************************************
cpu_get_info:	
			pushad
			call cpu_get_vendor
			; BrandStr
			call cpu_get_brand_string
			cmp BYTE [cpu_brand_string], 0
			jz	.BrandID	
			jmp .End
.BrandID	mov eax, [cpu_intel_txt]			; check if Intel cpu
			cmp	eax, [cpu_vendor]
			jnz	.End
			call cpu_get_brand_id
.End		popad
			ret



;*************************************************
; cpu_get_brand_string
;*************************************************
cpu_get_brand_string:
			pushad
			mov eax, 0x80000000
			cpuid
			cmp eax, 0x80000000
			jge	.Supported
			jmp .End
.Supported	mov edi, cpu_brand_string
			mov eax, 0x80000002
			cpuid
			mov [edi], eax
			mov [edi+4], ebx
			mov [edi+8], ecx
			mov [edi+12], edx
			mov eax, 0x80000003
			cpuid
			mov [edi+16], eax
			mov [edi+20], ebx
			mov [edi+24], ecx
			mov [edi+28], edx
			mov eax, 0x80000004
			cpuid
			mov [edi+32], eax
			mov [edi+36], ebx
			mov [edi+40], ecx
			mov [edi+44], edx
.End		popad
			ret


;*************************************************
; cpu_get_brand_id	(from Pentium III) ; What if not an Intel processor?
;*************************************************
cpu_get_brand_id:
			pushad
			mov eax, 1
			cpuid
			test ebx, 0x000F
			jnz	.Scan
			jmp .End
.Scan		cmp bl, 5					; check special cases
			jz	.End
			cmp bl, 0x0D
			jz	.End
			cmp bl, 0x10
			jz	.End
			cmp bl, 3
			jnz	.Next11
			cmp eax, 0x000006B1
			jnz .Normal
			mov DWORD [cpu_brand_id_str], cpu_bid3_2txt
			jmp .End
.Next11		cmp bl, 0x0B
			jnz	.Next14
			cmp eax, 0x00000F13
			jnz .Normal
			mov DWORD [cpu_brand_id_str], cpu_bid11_2txt
			jmp .End
.Next14		cmp bl, 0x0E
			jnz	.Normal
			cmp eax, 0x00000F13
			jnz	.Normal
			mov DWORD [cpu_brand_id_str], cpu_bid14_2txt
			jmp .End
.Normal		mov edi, cpu_bid_txt_ar		; normal cases
			and ebx, 0x000000FF
			mov eax, [edi+ebx]
			mov [cpu_brand_id_str], eax
.End		popad
			ret


;*************************************************
; cpu_get_vendor
;*************************************************
cpu_get_vendor:
			pushad
			; It should be checked if cpuid available? see http://wiki.osdev.org/CPUID 
			mov eax, 0
			cpuid
			mov	DWORD [cpu_vendor], ebx
			mov	DWORD [cpu_vendor+4], edx
			mov	DWORD [cpu_vendor+8], ecx
			mov BYTE [cpu_max_calling_param], al			; eax
			popad
			ret


;*************************************************
; cpu_is_fpu_avail
; AL: 1 if FPU available ; Out
;*************************************************
cpu_is_fpu_avail:
			mov eax, 1
			cpuid
			test edx, CPUID_FEAT_EDX_FPU
			jnz	.FPU
			mov al, 0
			jmp .End
.FPU		mov al, 1
.End		ret


;*************************************************
; cpu_init
;*************************************************
cpu_init:
;			call gdt_init			; this should be done in Real Mode (16-bits)
;			all the code that puts the proc to PM should be put here
;			call idt_init			; this wouldn't work because idt should be initiated after switching to Protected Mode (32-bits)
			ret


;*************************************************
; cpu_shutdown
;*************************************************
cpu_shutdown:
			ret


;*************************************************
; cpu_flush_caches
;*************************************************
cpu_flush_caches:
;			pushad
			cli
			invd
			sti
;			popad
			ret


;*************************************************
; cpu_flush_caches_write
;*************************************************
cpu_flush_caches_write:
;			pushad
			cli
			wbinvd
			sti
;			popad
			ret


;*************************************************
; cpu_flush_tlb_entry
; EDX: address
;*************************************************
cpu_flush_tlb_entry:
;			pushad
;			cli
;			invlpg edx
;			sti
;			popad
			ret


;*************************************************
; cpu_set_mtrr
;	IN: EBP(baseAddress) e.g. LFBAddr
;		ESI(size) e.g. LFBSIZE
;		EDI(memType) e.g. WriteCombined
;
;	cr0:
;		Bit29 	NW 	Not-write through 	Globally enables/disable write-through caching
;		Bit30 	CD 	Cache disable 	Globally enables/disable the memory cache
;
; Interrupts have to be disabled!
;
; SHOULD BE PUT TO MEMORY.ASM !?
;*************************************************
cpu_set_mtrr:
			mov BYTE [cpu_mtrr], 0
			xor edx, edx
			mov eax, 1	; 0x80000001 (if EAX=1, EDX=BFEBFBFF; if EAX=0x80000001, EDX=0x20100000 on DELLD820)
			cpuid
			test edx, (1 << 12)		; is MTRR available?
			jz	.Back
			; find unused register
			mov	ecx, 0x201
.Again		rdmsr
			dec	ecx
			test ah, 8
			jz	.found
			rdmsr
			mov	al, 0				; clear memory type field
			cmp	eax, ebp
			jz	.Back				; no free registers, ignore the call
			add ecx, 3
			cmp ecx, 0x210
			jb	.Again
			jmp .Back
.found		mov BYTE [cpu_mtrr], 1
			mov eax, cr0
			or	eax, 0x60000000		; disable caching
			mov cr0, eax
			wbinvd					; invalidate cache
			xor edx, edx
			mov eax, ebp
			or eax, edi
			wrmsr
			mov ebx, esi
			dec ebx
			mov eax, 0xFFFFFFFF
			mov edx, 0x0000000F
			sub eax, ebx
			sbb edx, 0
			or eax, 0x800
			inc ecx
			wrmsr
			wbinvd					; again invalidate
			mov eax, cr0
			and eax, ~0x60000000
			mov cr0, eax			; enable caching
.Back		ret


section .data

;BrandIDTxts:
cpu_bid1_txt	db	"Intel Celeron processor", 0
cpu_bid2_txt	db	"Intel Pentium III processor", 0
cpu_bid3_txt	db	"Intel Pentium III Xeon processor", 0	; 2 types!
cpu_bid4_txt	db	"Intel Pentium III processor", 0
cpu_bid5_txt	db	"", 0
cpu_bid6_txt	db	"Mobile Intel Pentium III processor-M", 0
cpu_bid7_txt	db	"Mobile Intel Celeron processor", 0
cpu_bid8_txt	db	"Intel Pentium 4 processor", 0
cpu_bid9_txt	db	"Intel Pentium 4 processor", 0
cpu_bid10_txt	db	"Intel Celeron processor", 0
cpu_bid11_txt	db	"Intel Xeon processor", 0 				; 2 types!
cpu_bid12_txt	db	"Intel Xeon processor MP", 0
cpu_bid13_txt	db	"", 0
cpu_bid14_txt	db	"Mobile Intel Pentium 4 processor-M", 0	; 2 types!
cpu_bid15_txt	db	"Mobile Intel Celeron processor", 0
cpu_bid16_txt	db	"", 0
cpu_bid17_txt	db	"Mobile Genuine Intel processor", 0
cpu_bid18_txt	db	"Intel Celeron M processor", 0
cpu_bid19_txt	db	"Mobile Intel Celeron processor", 0
cpu_bid20_txt	db	"Intel Celeron processor", 0
cpu_bid21_txt	db	"Mobile Genuine Intel processor", 0
cpu_bid22_txt	db	"Intel Pentium M processor", 0
cpu_bid23_txt	db	"Mobile Intel Celeron processor", 0

cpu_bid3_2txt	db	"Intel Pentium Celeron processor", 0
cpu_bid11_2txt	db	"Intel Xeon processor MP", 0
cpu_bid14_2txt	db	"Intel Xeon processor", 0

cpu_bid_txt_ar	dd	cpu_bid1_txt, cpu_bid2_txt, cpu_bid3_txt, cpu_bid4_txt, cpu_bid5_txt, cpu_bid6_txt, cpu_bid7_txt, cpu_bid8_txt, cpu_bid9_txt, cpu_bid10_txt, cpu_bid11_txt, cpu_bid12_txt, cpu_bid13_txt, cpu_bid14_txt, cpu_bid15_txt, cpu_bid16_txt, cpu_bid17_txt, cpu_bid18_txt, cpu_bid19_txt, cpu_bid20_txt, cpu_bid21_txt, cpu_bid22_txt, cpu_bid23_txt 


cpu_txt					db	"CPU: ", 0
cpu_intel_txt			db	"GenuineIntel", 0
cpu_vendor	 			times 12 db 0	; 12 chars
cpu_max_calling_param	db	0
cpu_brand_string		times 48 db 0	; 48 bytes null-terminated string
cpu_brand_id_str		dd	0

cpu_mtrr db 0


%endif

