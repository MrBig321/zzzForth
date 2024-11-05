
;*******************************************************
;
;	hdloader.asm
;		Stage2 Loader from Hard Disk
;		The FORTH word HDINSTALL should copy the bytes to Hard Disk
;
;*******************************************************

bits 16

; We are loaded at 0x9000 (0x900:0)

org 0x9000

jmp	main				; go to start

;*******************************************************
;	Preprocessor directives
;*******************************************************

%include "defs.asm"
%include "gdt.asm"				; Gdt routines
%include "a20.asm"				; A20 enabling
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
%define IMAGE_RMODE_BASE 0x20000

%define SECTOR_CNT	199		; number of sectors of the kernel  (hexdump -C KRNL.SYS, and length/512)

%define BYTES_PER_SECTOR 512

; the same as in loader.asm, hdloader.asm, hdfsloader.asm, forth/hd.asm, ram.asm, kernel.asm (and MemMap in forth/common.asm)
;%define	RAM_MAP_ENT_LOC	0x6FFE
;%define	RAM_MAP_LOC		0x7000
%define RAM_SIZE_LO_LOC	0x8FF4
%define RAM_SIZE_HI_LOC	0x8FF8
%define KERNEL_SIZE_LOC	0x8FFC

drivenum			db 0
partition_lba_begin	dd 0
buff 	times 16 db 0
memaddr_seg		dw 0
memaddr_offs	dw 0

msgErrReadSector	db "Error reading sector", 0x0D, 0x0A, 0
LoadingMsg		db 0x0D, 0x0A, "Loading Operating System ", 0x00
msgProgress		db ".", 0
;GUINotAvail		db 0x0D, 0x0A, "1024*768*16 with linear framebuffer not available", 0x00
GUINotAvail		db 0x0D, 0x0A, "640*480*16 with linear framebuffer not available", 0x00
;PressSpace		db "Press SPACE To Continue", 0x0D, 0x0A, 0


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
			mov	sp, 0x1000		; sp will be decremented first, then value stored in it (0xFFFE)
			sti					; enable interrupts

			mov [drivenum], dl
			mov [partition_lba_begin], ebx

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
			mov eax, DWORD [ram_size_hi]
			mov	dword [RAM_SIZE_HI_LOC], eax	; save size of kernel (RAMSize doesn't want to get written!)
			mov eax, DWORD [ram_size_lo]
			mov	dword [RAM_SIZE_LO_LOC], eax	; save size of kernel (RAMSize doesn't want to get written!)
			mov ax, [ram_map_ent]
			mov	[RAM_MAP_ENT_LOC], ax			; save number of RAM-Map entries

			;-------------------------------;
			; VGAInfo
			;-------------------------------;
;			call vga_info
;			call vga_modes
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
			; Load Kernel					;
			;-------------------------------;
			mov DWORD [KERNEL_SIZE_LOC], SECTOR_CNT*512  ; sectors*sectorsize to get bytes
			mov cx, SECTOR_CNT					
			mov eax, 8					; sector number of the start of the kernel
			mov ebx, IMAGE_RMODE_BASE
			shr ebx, 4
			mov di, 0
			mov [memaddr_seg], bx
			mov [memaddr_offs], di
.Next		push eax
			push cx
			mov cx, 1							; why not SECTOR_CNT!? And not in cycles ...
			mov bx, [memaddr_seg]
			mov di, [memaddr_offs]
			call ReadSectors
			pop cx
			mov ax, 512
			call incmemaddr
			pop eax
			inc eax
			loop .Next

			;-------------------------------;
			;   Go into pmode				;
			;-------------------------------;

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


;************************************************
; Reads a series of sectors
; IN: 	EAX (Starting sector)
;		CX (Number of sectors to read)
;		BX:DI (Buffer to read to)
;************************************************
ReadSectors:
			pusha
			mov bp, 0x0005					; max. 5 retries
.Again		mov dl, [drivenum]
			mov BYTE [buff], 0x10			; size of this structure (1 byte)
			mov BYTE [buff+1], 0			; always zero (1 byte)
			mov WORD [buff+2], cx			; number of sectors to read (2 bytes)
			mov WORD [buff+4], di			; segment:offset ptr to memory to read to (4 bytes) 
			mov WORD [buff+6], bx 
			mov DWORD [buff+8], eax			; read from sector (8 bytes)
			mov DWORD [buff+12], 0 
			mov ah, 0x42
			mov si, buff					; DS:SI ptr to DAP (buff)
			int 0x13
			jnc	.Ok
			dec bp
			jnz	.Again
			mov si, msgErrReadSector
			call stdio16_puts
		jmp $
			int 0x18
.Ok			mov si, msgProgress
			call stdio16_puts
			popa
			ret


; IN: AX(value)
;	handles overflow (segment:offset)
;	add offset to segment to avoid overflow (segment*16+offset and zero to offset) 
;	Example(overflow): 
;		07E0:F000 + 10F3 (i.e. AX=10F3)
;		7E00+F000 = 16E00
;		16E00+10F3 = 17EF3
;		17EF:0003 !?
incmemaddr:
			pushad
			movzx ebx, WORD [memaddr_seg]
			mov di, [memaddr_offs]
			add di, ax
			mov dx, [memaddr_offs]
			mov cx, 0xFFFF
			sub cx, dx
			inc cx
			cmp ax, cx
			jc	.Ok									; jump if unsigned less
			; overflow
			movzx edi, WORD [memaddr_offs]
			shl	ebx, 4	
			add ebx, edi
			mov edi, ebx
			and edi, 0x0000000F
			add di, ax
			shr ebx, 4
.Ok			mov [memaddr_seg], bx
			mov [memaddr_offs], di
			popad
			ret


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
			mov ecx, dword [KERNEL_SIZE_LOC]
			shr	ecx, 2								; /4
			inc ecx									; remainder
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





