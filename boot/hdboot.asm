
;*********************************************
;	HDBoot.asm
;		- The VBR on hard disk. Loads hdloader.bin(second loader) from sectors
;		The FORTH word HDINSTALL should copy the bytes to Hard Disk
;		Used with Bootfloppy
;
;*********************************************

bits 16								; we are in 16 bit real mode

org	0								; we will set regisers later

start:	jmp	main					; jump to start of bootloader

drive_num					db 0
partition_lba_begin			dd 0
buff 						times 16 db 0

msgLoading		db 0x0D, 0x0A, "Loading Boot Image ", 0x0D, 0x0A, 0x00
msgCRLF			db 0x0D, 0x0A, 0x00
msgProgress		db ".", 0x00


main:
	;----------------------------------------------------
	; code located at 0000:7C00, adjust segment registers
	;----------------------------------------------------
     
			cli						; disable interrupts
			mov ax, 0x07C0			; setup registers to point to our segment
			mov ds, ax
			mov es, ax				; es: segment to put loaded data into (bx: offset)
			mov fs, ax
			mov gs, ax

	;----------------------------------------------------
	; create stack
	;----------------------------------------------------
     
			mov ax, 0x0000			; set the stack
			mov ss, ax
			mov sp, 0xFFF0
			sti						; restore interrupts

			mov BYTE [drive_num], dl
			mov DWORD [partition_lba_begin], 0

	; Ensure 80*25
			mov ax, 3				; mode 80*25, clearscreen
			int 10h

	;----------------------------------------------------
	; Display loading message
	;----------------------------------------------------
     
			mov si, msgLoading
			call Print

	; read 2nd loader into memory (0900:0000)
     
			mov si, msgCRLF
			call Print

			mov bx, 0x0900							; where to read
			mov di, 0x0000
			mov eax, 1								; since MBR is sector 0, the 2nd loader is from sector 1
			mov cx, 7								; number of sectors of 2nd loader ("hexdump -C hdloader.bin" and lastbyteindecimal/512)
			call ReadSectors
          
			mov si, msgCRLF
			call Print

			mov dl, [drive_num]
			mov ebx, [partition_lba_begin]

			push WORD 0x0900
			push WORD 0x0000
			retf



;************************************************;
;	Prints a string
;	DS=>SI: 0 terminated string
;************************************************;
Print:		lodsb				; load next byte from string from SI to AL
			or al, al			; Does AL=0?
			jz .PrintDone		; Yep, null terminator found-bail out
			mov	ah, 0eh			; Nope-Print the character
			int	10h
			jmp	Print			; Repeat until null terminator found
.PrintDone:	ret					; we are done, so return


;************************************************
; Reads a series of sectors
; IN: 	EAX (Starting sector)
;		CX (Number of sectors to read)
;		BX:DI (Buffer to read to)
;************************************************
ReadSectors:
			pusha
			mov bp, 0x0005				; max. 5 retries
.Again		mov dl, [drive_num]		; Bochs doesn't set it to 0x80 !?
			mov BYTE [buff], 0x10		; size of this structure (1 byte)
			mov BYTE [buff+1], 0		; always zero (1 byte)
			mov WORD [buff+2], cx		; number of sectors to read (2 bytes)
			mov WORD [buff+4], di		; segment:offset ptr to memory to read to (4 bytes) 
			mov WORD [buff+6], bx 
			mov DWORD [buff+8], eax		; read from sector (8 bytes)
			mov DWORD [buff+12], 0 
			mov ah, 0x42
			mov si, buff 
			int 0x13
			jnc	.Ok
			dec bp
			jnz	.Again
			int 0x18
.Ok			popa
			ret


     
     
TIMES 510-($-$$) DB 0
dw 0xAA55


