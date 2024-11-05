;********************************************
;	Hard Disk
;
;	Detects hard disk and provides interface for ATA/PATA or SATA(AHCI) disks
;********************************************

; SATA vs ATA (or PATA):
;	SATA has two modes: PATA (legacy) and AHCI. If SATA drive doesn't support PATA(i.e. ATA) then AHCI need to be used
;	Currently this file contains ATA only.


%ifndef __HD__
%define __HD__


%include "ata.asm"


%define HD_PRIMARY_PORT			0x1F0
%define HD_SECONDARY_PORT		0x170
%define HD_PRIMARY_CTRL_PORT	0x3F6
%define HD_SECONDARY_CTRL_PORT	0x376

;%define HD_THIRD_PORT			0x1E8
;%define HD_FOURTH_PORT			0x168
;%define HD_THIRD_CTRL_PORT		0x3E6
;%define HD_FOURTH_CTRL_PORT		0x366

%define HD_DCR_NIEN	0x02

; Device-types
;%define	HD_DEV_UNKNOWN	0
;%define	HD_DEV_PATA		1
;%define	HD_DEV_SATA		2
;%define	HD_DEV_PATAPI	3
;%define	HD_DEV_SATAPI	4


section .text

; _hd_info
hd_info:
			cmp BYTE [hd_detected], 0
			jz	.Back
			; here we should check hd_ahci and call ahci_info if set (TODO)
			call ata_info
.Back		ret


; hd_read
; IN: 
;	ECX: lbaLo, EBP: lbaHi, EBX: sectorcnt, EAX: memaddr
; OUT: AL (0 indicates success)
hd_read:
			cmp BYTE [hd_detected], 0
			jz	.Err
			cmp ebx, 0
			jnz	.Do
			mov al, 0
			jmp	.Back
			; here we should check hd_ahci and call ahci_rw if set (TODO)
.Do			mov edx, 0
			call ata_rw
			jmp .Back
.Err		mov al, 1					; NO_DRIVE
.Back		ret


%ifdef MULTITASKING_DEF
; hd_read_dma
; IN: 
;	ECX: lbaLo, EBP: lbaHi, EBX: sectorcnt, EAX: memaddr
; OUT: AL (0 indicates success)
hd_read_dma:
			cmp BYTE [hd_detected], 0
			jz	.Err
			cmp ebx, 0
			jnz	.Do
			mov al, 0
			jmp	.Back
			; here we should check hd_ahci and call ahci_rw if set (TODO)
.Do			mov edx, 0
			call ata_rw_dma
			jmp .Back
.Err		mov al, 1					; NO_DRIVE
.Back		ret

%endif


; hd_write
; IN: 
;	ECX: lbaLo, EBP: lbaHi, EBX: sectorcnt, EAX: memaddr
; OUT: AL (0 indicates success)
hd_write:
			cmp BYTE [hd_detected], 0
			jz	.Err
			cmp ebx, 0
			jnz	.Do
			mov al, 0
			jmp	.Back
			; here we should check hd_ahci and call ahci_rw if set (TODO)
.Do			mov edx, 1
			call ata_rw
			jmp .Back
.Err		mov al, 1					; NO_DRIVE
.Back		ret


%ifdef MULTITASKING_DEF
; hd_write_dma
; IN: 
;	ECX: lbaLo, EBP: lbaHi, EBX: sectorcnt, EAX: memaddr
; OUT: AL (0 indicates success)
hd_write_dma:
			cmp BYTE [hd_detected], 0
			jz	.Err
			cmp ebx, 0
			jnz	.Do
			mov al, 0
			jmp	.Back
			; here we should check hd_ahci and call ahci_rw if set (TODO)
.Do			mov edx, 1
			call ata_rw_dma
			jmp .Back
.Err		mov al, 1					; NO_DRIVE
.Back		ret

%endif


; The main harddisk-detection function
; Detects first available harddisk on primary and secondary bus (master or slave)
; Sets variables (portbase, slavebit) accordingly
; Executes IDENTIFY cmd
hd_detect:
			pushad
			mov BYTE [hd_detected], 0
			mov ecx, 0
.Next		mov dx, WORD [hd_val_arr+ecx]
			mov [ata_port_base], dx
			mov dx, WORD [hd_val_arr+ecx+2]
			mov [ata_port_ctrl], dx
			mov dx, WORD [hd_val_arr+ecx+4]
			mov [ata_slave_bit], dl
			push ecx
			call ata_identify
			pop ecx
			cmp al, ATA_OK				; in case ATA_NO_DRIVE we should try to identify drive as SATA
			jz	.Found
			add cx, 3*2
			cmp cx, 24
			jnz	.Next
			jmp .End
.Found		mov BYTE [hd_detected], 1
			cmp WORD [ata_port_base], 0x1F0			; Primary Bus?
			jnz	.Sec
			mov DWORD [ata_master_offs], ata_prim_master_offs
			jmp .End
.Sec		mov DWORD [ata_master_offs], ata_sec_master_offs
.End		popad
			ret


; called from idt.asm
hd_irq_handler:
%ifdef MULTITASKING_DEF
			cmp BYTE [hd_detected], 0
			jz	.Back
			call ata_irq_handler
%endif
.Back		ret



section .data

hd_ahci db  0		; ATA hard disk if 0, otherwise SATA(AHCI)

hd_detected	db 0

hd_val_arr		dw HD_PRIMARY_PORT, HD_PRIMARY_CTRL_PORT, 0
				dw HD_PRIMARY_PORT, HD_PRIMARY_CTRL_PORT, 1
				dw HD_SECONDARY_PORT, HD_SECONDARY_CTRL_PORT, 0
				dw HD_SECONDARY_PORT, HD_SECONDARY_CTRL_PORT, 1


%endif

