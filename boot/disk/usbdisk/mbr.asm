
;*********************************************
;	mbr.asm
;		Master Boot Record
;		Relocates itself to 0x600
;		Loads the VBR from LBABegin(partition-entry)
;		Passes drive-number in DL and 
;		pointer in DS:SI to partition-entry
;		to VBR
;*********************************************

bits 16

org	0x0600

%define BOOT_SIG	0xAA55

main:
; at 0x7C00
			cli
			xor cx, cx
			mov si, 0x7C00
			mov di, 0x0600
			mov ss, cx
			mov sp, si
			mov es, cx
			mov ds, cx
			mov ch, 0x01
			cld
			rep movsw					; relocates from 0x7C00 to 0x0600
			jmp 0x0000:.Here			; far jump, sets CS to 0 and IP to ...

.Here		sti
			mov	[bdi], dl				; save BIOS-Drive-Index

			mov bx, pe1
			mov cx, 4
.CKPEloop	mov al, BYTE [bx]
			test al, 0x80
			jnz .CKPEFound
			add bx, 0x10
			dec cx
			jnz .CKPEloop
			mov si, PEErrTxt
			call puts
			jmp $
.CKPEFound	mov WORD [peoff], bx
			add bx, 8					; Increment Base to LBA Address
			; read VBR
			mov eax, [bx]
			mov cx, 1
			mov bx, 0x07C0
			mov di, 0
			call ReadSectors

			cmp WORD [0x7DFE], BOOT_SIG	; Check Boot Signature
			je	.ToVBR
			mov si, VBEErrTxt
			call puts
			jmp $
.ToVBR		mov dl, [bdi]				; BIOS stores the Boot-Drive-Index(BDI) in DL
			xor ax, ax
			mov ds, ax
			mov si, [peoff]				; pass on pointer to partition-entry
			jmp 0x07C0:0000				; jump to VBR


;************************************************
; Reads a series of sectors
; IN: 	EAX (Starting sector)
;		CX (Number of sectors to read)
;		BX:DI (Buffer to read to)
;************************************************
ReadSectors:
			pusha
			mov bp, 0x0005				; max. 5 retries
.Again		mov dl, [bdi]				; maybe BIOS overwrites dl!?
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
			dec bp						; BIOS overwrites!?
			jnz	.Again
			mov si, RSErrTxt
			call puts
			int 0x18
.Ok			popa
			ret


;*************************************************;
;	puts
;	DS=>SI : 0 terminated string
;	Prints a string
;************************************************;
puts:
			pusha
.Next		lodsb						; load next byte from string from SI to AL
			cmp al, 0					; AL=0?
			jz	.Done
			mov	ah,	0eh	
			int	10h
			jmp	.Next
.Done		popa
			ret

bdi	db	0								; BIOS-Drive-index

peoff dw 0								; partition entry offset

buff times 16 db 0

PEErrTxt	db "Partition-entry error", 0x0D, 0x0A, 0
RSErrTxt 	db "ReadSectors error", 0x0D, 0x0A, 0
VBEErrTxt	db "VBE error", 0x0D, 0x0A, 0

times 446-($-$$) db 0

pe1	db 0x80, 0x20, 0x21, 0x00, 0x0b, 0x87, 0x5e, 0xe9, 0x00, 0x08, 0x00, 0x00, 0x00, 0xF8, 0x77, 0x00	; 1st Partition Entry
pe2 times 16 db	0						; 2nd Partition Entry
pe3 times 16 db	0						; 3rd Partition Entry
pe4 times 16 db 0						; 4th Partition Entry

times 510-($-$$) db 0
dw BOOT_SIG




