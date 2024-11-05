
;*******************************************************
;
;	loader.asm
;		Stage2 Bootloader
;
;	OS Development Series
;*******************************************************

bits 16

; We are loaded at 0x9000 (0x900:0)

org 0x9000

jmp	main				; go to start

;*******************************************************
;	Preprocessor directives
;*******************************************************

%include "gdt.asm"				; Gdt routines
%include "a20.asm"				; A20 enabling
%include "boot/fat12.asm"		; FAT12 driver
%include "defs.asm"
%include "ram.asm"
%include "vga.asm"
;%include "vga2.asm"
%include "stdio16.asm"

bits 16							; may be necessary if an include contains "bits 32"


;*******************************************************
;	Data Section
;*******************************************************

; where the kernel is to be loaded to in protected mode
%define IMAGE_PMODE_BASE 0x200000

; where the kernel is to be loaded to in real mode
;%define IMAGE_RMODE_BASE 0x20000
%define IMAGE_RMODE_BASE 0xD000

; the same as in loader.asm, hdloader.asm, hdfsloader.asm, forth/hd.asm, ram.asm, kernel.asm (and MemMap in forth/common.asm)
;%define	RAM_MAP_ENT_LOC	0x6FFE
;%define	RAM_MAP_LOC		0x7000
%define RAM_SIZE_LO_LOC	0x8FF4
%define RAM_SIZE_HI_LOC	0x8FF8
%define KERNEL_SIZE_LOC	0x8FFC

; kernel name (Must be 11 bytes)
ImageName	db "KRNL    SYS"

LoadingMsg db 0x0D, 0x0A, "Searching for Operating System...", 0x00
%ifdef NORMALRES_DEF
	GUINotAvail db 0x0D, 0x0A, "1024*768*16 with linear framebuffer not available", 0x00
%else
	GUINotAvail db 0x0D, 0x0A, "640*480*16 with linear framebuffer not available", 0x00
%endif
msgFailure db 0x0D, 0x0A, "*** FATAL: MISSING OR CURRUPT KRNL.SYS. Press Any Key to Reboot", 0x0D, 0x0A, 0x0A, 0x00
;PressSpace db "Press SPACE To Continue", 0x0D, 0x0A, 0


;*******************************************************
;	STAGE 2 ENTRY POINT
;
;		-Store BIOS information
;		-Load Kernel
;		-Install GDT; go into protected mode (pmode)
;		-Jump to Stage 3
;*******************************************************

main:
			;-------------------------------;
			;   Setup segments and stack	;
			;-------------------------------;

			cli					; clear interrupts
			xor	ax, ax			; null segments
			mov	ds, ax
			mov	es, ax
			mov	ax, 0x0700
			mov	ss, ax
			mov	sp, 0x1000
			sti					; enable interrupts

			;-------------------------------;
			;   Install our GDT				;
			;-------------------------------;

			call gdt_init		; install our GDT

			;-------------------------------;
			;   Enable A20					;
			;-------------------------------;

			call a20_enable_kybrd_out

			;-------------------------------;
			; Calculate RAM
			;-------------------------------;
			call ram_get
			call ram_copy_memmap
;			call ram_show				; will show it in protected mode
;.WaitForKey	mov ax, 0x100		; Is there a key pressed?
;			int 0x16
;			jz .WaitForKey
			mov eax, [ram_size_hi]
			mov	[RAM_SIZE_HI_LOC], eax			; save size of kernel
			mov eax, [ram_size_lo]
			mov	[RAM_SIZE_LO_LOC], eax
			mov ax, [ram_map_ent]
			mov	[RAM_MAP_ENT_LOC], ax			; save number of RAM-Map entries

			;-------------------------------;
			; VGAInfo
			;-------------------------------;
;			call vga2_info
;			call vga2_modes
;			mov	si, PressSpace
;			call stdio16_puts
;.WaitForKey	mov ax, 0x100		; Is there a key pressed?
;			int 0x16
;			jz .WaitForKey

;			xor	ax, ax			; clear ax
;			int 0x16			; Read key, if there is
;			cmp ah, 0x39		; SPACE?
;			jnz .WaitForKey

			call vga_get_framebuff
			cmp eax, 0
			jnz	.Msg
			mov	si, GUINotAvail
			call stdio16_puts
			jmp $			

			;-------------------------------;
			;   Print loading message		;
			;-------------------------------;

.Msg		mov	si, LoadingMsg
			call stdio16_puts

			;-------------------------------;
			; Initialize filesystem			;
			;-------------------------------;

			call LoadRoot				; Load root directory table

			;-------------------------------;
			; Load Kernel					;
			;-------------------------------;

			mov	ebx, IMAGE_RMODE_BASE	; BX:BP points to buffer to load to
			shr ebx, 4
		    mov	bp, 0 
			mov	si, ImageName			; our file to load
			call LoadFile				; load our file
			shl ecx, 9					; to bytes from sectors
			mov	[KERNEL_SIZE_LOC], ecx		; save size of kernel
			cmp	ax, 0					; Test for success
			je	EnterStage3				; yep--onto Stage 3!
			mov	si, msgFailure			; Nope--print error
			call stdio16_puts
			mov	ah, 0
			int 0x16					; await keypress
			int 0x19					; warm boot computer
			cli							; If we get here, something really went wong
			hlt

			;-------------------------------;
			;   Go into pmode				;
			;-------------------------------;

EnterStage3:
%ifdef NORMALRES_DEF
			; switch to 1024*768*16
			mov bx, VGA_NORMALRES
%else
			; switch to 640*480*16
			mov bx, VGA_SMALLRES
%endif
			call vga_switch_to_mode

			cli						; clear interrupts
			mov	eax, cr0			; set bit 0 in cr0--enter pmode
			or eax, 1
			mov	cr0, eax

			jmp	GDT_CODE_DESC:Stage3	; far jump to fix CS. Remember that the code selector is 0x8!

			; Note: Do NOT re-enable interrupts! Doing so will triple fault! (because of Timer!)
			; We will fix this in Stage 3.

;******************************************************
;	ENTRY POINT FOR STAGE 3
;******************************************************

bits 32

Stage3:
			;-------------------------------;
			;   Set registers				;
			;-------------------------------;

			mov	ax, GDT_DATA_DESC		; set data segments to data selector (0x10)
			mov	ds, ax
			mov	ss, ax
			mov	es, ax
			mov	esp, 90000h			; stack begins from 90000h

			;-------------------------------;
			; Copy kernel to 1MB			;
			;-------------------------------;

CopyImage:
			mov ecx, [KERNEL_SIZE_LOC]
			shr ecx, 2			; /4
			inc	ecx				; remainder
			cld
			mov esi, IMAGE_RMODE_BASE
			mov edi, IMAGE_PMODE_BASE
			rep movsd				; copy image to its protected mode address

			;---------------------------------------;
			;   Execute Kernel						;
			;---------------------------------------;

			jmp	GDT_CODE_DESC:IMAGE_PMODE_BASE	; jump to our kernel! Note: This assumes Kernel's entry point is at 1 MB

			;---------------------------------------;
			;   Stop execution						;
			;---------------------------------------;

			cli
			hlt





