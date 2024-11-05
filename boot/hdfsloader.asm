
;*******************************************************
;
;	loader.asm
;		Stage2 Bootloader
;
;*******************************************************

bits 16


org  0x9000	; Entering PMode (jump to Stage3) reboots with "org 0" (because boot.asm loads it to 0x9000, and base in GDT-table is zero)

jmp	main				; go to start

;*******************************************************
;	Preprocessor directives
;*******************************************************

%include "gdt.asm"				; Gdt routines
%include "a20.asm"				; A20 enabling
%include "boot/hdfsfat3216.asm"
%include "defs.asm"
%include "ram.asm"
%include "vga.asm"
;%include "vga2.asm"
%include "stdio16.asm"

bits 16

; the same as in loader.asm, hdloader.asm, hdfsloader.asm, forth/hd.asm, ram.asm, kernel.asm (and MemMap in forth/common.asm)
;%define	RAM_MAP_ENT_LOC	0x6FFE
;%define	RAM_MAP_LOC		0x7000
%define RAM_SIZE_LO_LOC	0x8FF4
%define RAM_SIZE_HI_LOC	0x8FF8
%define KERNEL_SIZE_LOC	0x8FFC

; hdfsloader.asm writes in 16-bit-mode a signature(DWORD) for kernel.asm to call fat32_init
%define HDFSLOADER_SIGNATURE_LOC	0x8FEC
%define HDFSLOADER_SIGNATURE		0xAABBCCDD


section .text

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
			mov	ax, 0x0700		; stack at 0x7000-7FFE
			mov	ss, ax
			mov	sp, 0x1000		; sp will be decremented first, then will the value be stored in it
			sti					; enable interrupts

			mov [hdldr_drivenum], dl
			mov [hdldr_partition_lba_begin], ebx
mov [0x1FF7], dl
mov [0x1FF8], ebx
mov DWORD [HDFSLOADER_SIGNATURE_LOC], HDFSLOADER_SIGNATURE

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
;			mov	si, hdldr_msgPressSpace
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
			mov	si, hdldr_msgGUINotAvail
			call stdio16_puts
			jmp $			

			;-------------------------------;
			;   Print loading message		;
			;-------------------------------;

.Msg		mov	si, hdldr_msgLoading
			call stdio16_puts

			;-------------------------------;
			; Initialize filesystem			;
			;-------------------------------;

			mov dl, [hdldr_drivenum]
			mov eax, [hdldr_partition_lba_begin]
			call hdfat3216_init

			;-------------------------------;
			; Load Kernel					;
			;-------------------------------;

			mov eax, HDLDR_IMAGE_RMODE_BASE
			shr eax, 4
			mov es, ax
			mov di, 0
			mov	bx, hdldr_filename			; our file to load
			xor ecx, ecx
			mov cl, HDLDR_FILENAME_SIZE
			call hdfat3216_readfile				; load our file
			mov	[KERNEL_SIZE_LOC], ecx		; save size of kernel
			cmp	ecx, 0					; Test for success
			jne	EnterStage3				; yep--onto Stage 3!
			mov	si, hdldr_msgFailure			; Nope--print error
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
			shr ecx, 2				; /4
			inc ecx					; reaminder
			cld
			mov esi, HDLDR_IMAGE_RMODE_BASE
			mov edi, HDLDR_IMAGE_PMODE_BASE
			rep movsd				; copy image to its protected mode address

			;---------------------------------------;
			;   Execute Kernel						;
			;---------------------------------------;
;	mov ebx, 0xb8000
;	mov BYTE [ebx], 'Y'
;	jmp $
			jmp	GDT_CODE_DESC:HDLDR_IMAGE_PMODE_BASE	; jump to our kernel! Note: This assumes Kernel's entry point is at 1 MB

			;---------------------------------------;
			;   Stop execution						;
			;---------------------------------------;

			cli
			hlt


section .data

hdldr_drivenum				db 0		; the drive we booted from
hdldr_partition_lba_begin	dd 0

; where the kernel is to be loaded to in protected mode
HDLDR_IMAGE_PMODE_BASE 	equ		0x200000

; where the kernel is to be loaded to in real mode
HDLDR_IMAGE_RMODE_BASE 	equ		0x20000

; the same as in loader.asm, ram.asm, kernel.asm and forth/core.asm
;HDLDR_RAM_MAP_ENT_LOC		equ	0x6FFE
;HDLDR_RAM_MAP_LOC			equ	0x7000
HDLDR_RAM_SIZE_LO_LOC		equ	0x8FF4
HDLDR_RAM_SIZE_HI_LOC		equ	0x8FF8
HDLDR_KERNEL_SIZE_LOC		equ	0x8FFC

; kernel name
hdldr_filename		db "KRNL.SYS"
HDLDR_FILENAME_SIZE equ ($-hdldr_filename)

hdldr_msgLoading		db 0x0D, 0x0A, "Searching for Operating System...", 0
%ifdef NORMALRES_DEF
	hdldr_msgGUINotAvail	db 0x0D, 0x0A, "1024*768*16 with linear framebuffer not available", 0
%else
	hdldr_msgGUINotAvail	db 0x0D, 0x0A, "640*480*16 with linear framebuffer not available", 0
%endif
hdldr_msgFailure		db 0x0D, 0x0A, "*** FATAL: MISSING OR CORRUPT KRNL.SYS. Press Any Key to Reboot", 0x0D, 0x0A, 0x0A, 0
;hdldr_msgPressSpace	db "Press SPACE To Continue", 0x0D, 0x0A, 0



