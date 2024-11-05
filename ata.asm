;********************************************
;	ATA Hard Disk Routines
;
;	Can read/write ATA/PATA disks on Primary or secondary bus
;********************************************

;DISK INFO:
; BIOS:
; 	int 13h AH=48h Extended Read Drive Params see "int 13h wikipedia"
;	retrives info about (C, H, S), max sectornum, bytes/sector

; No BIOS:
;	Detecting if there is no Drive on bus(Floating Bus): Before sending any data to the I/O ports read the status byte. 0xFF indicates that there is no drive on the bus. (The definitive method is the IDENTIFY cmd). There is a third method on osdever.net (LBA HDD Access via PIO)
;
;	IDENTIFY cmd (see: ATA_PIO_Mode wikipedia). BIOSes use IDENTIFY !
;	Retrieves info if it's a HD or not and CHS, LBA28 or LBA48 mode is available. UDMA modes. Max number of 48-bit addressable sectors on drive.

; Addressing modes: CHS, LBA28, LBA48. CHS is obsolete. LBA28 can address max 128GB, so it's also obsolete for bigger drives. However LBA28-PIO is faster than 48-bit. Bit 6 (sent to 0x1F6) needs to be set if LBA-mode (otherwise it's CHS).

; REGISTERS for primary HD
;	0x1F0-0x1F7 and 0x3F6 (Device control register(DCR): nIEN, SRST, HOB bits)
;	DCR cannot be read just written.
;	CHS: Port3, 4, 5: sector, cylinder Low, cylinder High
;	LBA: Port3, 4, 5: LBAlo, mid, hi
;	0x1F0-0x1F7:
;		Port Offs	Function 						Description
;		0			Data Port 						Read/Write PIO data bytes on this port.
;		1 			Features / Error Information 	Usually used for ATAPI devices.
;		2 			Sector Count 					Number of sectors to read/write (0 is a special value).
;		3 			Sector Number / LBAlo 			This is CHS / LBA28 / LBA48 specific.
;		4 			Cylinder Low / LBAmid 			Partial Disk Sector address.
;		5 			Cylinder High / LBAhi 			Partial Disk Sector address.
;		6 			Drive / Head Port 				Used to select a drive and/or head. May supports extra address/flag bits.
;		7 			Command port / Regular Status port 	Used to send commands or read the current status.
;	0x3F6 (bits):
;		1	nIEN	Disable IRQ sending
;		2	SRST	Software Reset if 1 on all ATA drives on a bus
;		7	HOB		Set this to read back the high-order-byte of the last LBA48 value sent to an I/O port.

; Status byte (0x1F7)
;	Bit 	Abbreviation 	Function
;	0		ERR 			Indicates an error occurred. Send a new command to clear it (or nuke it with a Software Reset).
;	1		IDX				Set to 1 each revolution (Index)
;	2		DDRC			Disk Data Read Corrected
;	3 		DRQ 			Set when the drive has PIO data to transfer, or is ready to accept PIO data.
;	4 		SRV 			Overlapped Mode Service Request.
;	5 		DF 				Drive Fault Error (does not set ERR).
;	6 		RDY 			Bit is clear when drive is spun down, or after an error. Set otherwise.
;	7 		BSY 			Indicates the drive is preparing to send/receive data (wait for it to clear). In case of 'hang' (it never clears), do a software reset. 

; IRQ
;	Not necessary for a SingleTask OS. Better polling. Set nIEN to disable IRQ. Also, bit10 need to be set in PCI-command register to disable IRQs.
;	How to poll (waiting for the drive to be ready to transfer data): Read the Regular Status port until bit 7 (BSY, value = 0x80) clears, and bit 3 (DRQ, value = 8) sets -- or until bit 0 (ERR, value = 1) or bit 5 (DF, value = 0x20) sets. If neither error bit is set, the device is ready right then. 
;	The standard IRQ for the Primary-bus is IRQ14 and IRQ15 for the secondary bus.

; slavebit in the tutorials: 0 for master and 1 for slave. Shifted to the left by 4 means the 5th bit set in 0x1F6 !!!

; "rep insw" works but "rep outsw" is too fast on some hw. Use loop and a little delay

; all these routines should have an OS-specific timeout!

%ifndef __ATA__
%define __ATA__


%include "pci.asm"
%include "pit.asm"
%include "gstdio.asm"
;%ifdef MULTITASKING_DEF
	%include "forth/core.asm"		;_pause
;%endif

; register-offsets (Primary bus: 0x1F0- ; for secondary: 0x170- )
%define ATA_PORT_DATA		0
%define ATA_PORT_ERROR		1
%define ATA_PORT_SECT_COUNT	2
%define ATA_PORT_SECT_NUM	3
%define ATA_PORT_CYL_LOW	4
%define ATA_PORT_CYL_HIGH	5
%define	ATA_PORT_DRV_HEAD	6
%define ATA_PORT_STATUS		7
%define ATA_PORT_COMMAND	7


; status-reg's bits
%define	ATA_ST_ERR	0x01
%define	ATA_ST_IDX	0x02
%define	ATA_ST_DDRC	0x04
%define	ATA_ST_DRQ	0x08
%define	ATA_ST_SRV	0x10
%define	ATA_ST_DF	0x20
%define	ATA_ST_RDY	0x40
%define	ATA_ST_BSY	0x80

; drive-head-reg's bits  (also used for selecting HD)
;	bits 3-0:	head number
;	bit4:		HD0(=0), HD1(=1)
;	bits 7-5:	101b for master (0xA0) or 1011b (0xB0) for slave. ORed  (0xE0 and 0xF0 for LBA28; 0x40 and 0x50 for LBA48)

; Device Control Register (0x3F6)
;	bit 1:	nIEN	Disable IRQ sending
;	bit 2:	SRST	Software Reset if 1 on all ATA drives on a bus
;	bit 7:	HOB		Set this to read back the high-order-byte of the last LBA48 value sent to an I/O port.
;	all other bits are reserved and should always be clear.
%define ATA_DCR_NIEN	0x02
%define ATA_DCR_SRST	0x04
%define ATA_DCR_HOB		0x80

; HD ids
%define ATA_CHS_MASTER		0xA0		;(0xB0 is slave; i.e. 0xA0 | slave_bit)  
%define ATA_LBA28_MASTER	0xE0		;(0xF0 is slave)
%define ATA_LBA48_MASTER	0x40		;(0x50 is slave)


; HD commands
%define	ATA_CMD_NOP				0x0
%define ATA_CMD_READ			0x20
%define ATA_CMD_READ_EXT		0x24	; LBA48
%define ATA_CMD_WRITE			0x30
%define ATA_CMD_WRITE_EXT		0x34	; LBA48
%define	ATA_CMD_READ_VRFY		0x40	; sectors
%define	ATA_CMD_DIAG			0x90	; execute device diagnostics
%define	ATA_CMD_STANDBY_IMM		0xE0
%define	ATA_CMD_IDLE_IMM		0xE1
%define	ATA_CMD_STANDBY			0xE2
%define	ATA_CMD_IDLE			0xE3
%define	ATA_CMD_CHK_PWR_MODE	0xE5
%define	ATA_CMD_SLEEP			0xE6
%define	ATA_CMD_FLUSH_CACHE		0xE7
%define	ATA_CMD_FLUSH_CACHE_EXT	0xEA
%define	ATA_CMD_IDENTIFY		0xEC

%define	ATA_CMD_DMA_READ_28		0xC8
%define	ATA_CMD_DMA_WRITE_28	0xCA
%define	ATA_CMD_DMA_READ_48		0x25
%define	ATA_CMD_DMA_WRITE_48	0x35
; there are many DMA-related cmds in the spec too!

; cmd results
%define	ATA_OK			0
%define	ATA_NO_DRIVE	1
%define	ATA_ERR			2
%define	ATA_LOCKED		3
%define	ATA_TIMEOUT		4

%define ATA_BMR_CMD_OFFS	0
%define ATA_BMR_STATUS_OFFS	1
%define ATA_BMR_PRDT_OFFS	2

; DMA-stuff
ATA_PCI_BAR4			equ	0x20		; DWORD	; holds the base address of Bus Master Register (BMR)
ATA_BMR_CMD_START		equ 1
ATA_BMR_CMD_READ		equ (1 << 3)
ATA_BMR_STATUS_ACTIVE	equ	1
ATA_BMR_STATUS_ERR		equ	(1 << 1)
ATA_BMR_STATUS_IRQ		equ	(1 << 2)

ATA_DMA_PRDT				equ	0x14E000	; Address of "Physical Region Descriptor Table"
ATA_DMA_BUFF				equ	0x150000	; 64Kb, right after HDAudio


section .text

; identifies HD
; OUT: AL
ata_identify:
			mov BYTE [ata_lock], 0				; HDINSTALL copies the OS from RAM, and ata_lock is set to 1 during that time !!
			xor eax, eax
			;send 0xA0 to 0x1F6  (This is CHS-mode. LBA28 and 48 ?)
			mov al, ATA_CHS_MASTER
			mov bl, [ata_slave_bit]
			shl bl, 4
			or	al, bl
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DRV_HEAD
			out dx, al
			;set 0 to 0x1F2 to 0x1F5
			mov al, 0
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_COUNT
			out dx, al
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_NUM
			out dx, al
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_LOW
			out dx, al
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_HIGH
			out dx, al
			;send 0xEC to 0x1F7
			mov al, ATA_CMD_IDENTIFY
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
			;read 0x1F7 (Status) if it is 0 then the drive doesn't exist
;			in al, dx
;			cmp al, 0
;			jnz	.ChkDrv
;			mov al, ATA_NO_DRIVE
;			jmp	.Back
			; check if ATA drive (maybe should be done before reading STATUS!?)
.ChkDrv		mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_LOW
			in al, dx
			cmp al, 0						; Maybe a SATA hd emulating ATA will send 0x3C and 0xC3 !?
			jnz	.ChkSATA
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_HIGH
			in al, dx
			cmp al, 0
			jz	.MPoll
			jmp	.NoDrv
.ChkSATA	cmp al, 0x3C
			jnz .NoDrv
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_HIGH
			in al, dx
			cmp al, 0xC3
			jz	.MPoll
.NoDrv		mov al, ATA_NO_DRIVE
			jmp	.Back
.MPoll		mov dx, [ata_port_base]
			add dx, ATA_PORT_STATUS
.Poll		in al, dx
			test al, ATA_ST_BSY				; wait for BUSY bit to clear
			jnz	.Poll
			test al, ATA_ST_ERR+ATA_ST_DF
			jz	.Read
			mov al, ATA_ERR
			jmp	.Back
			; Read 256 words from ATA_PORT_DATA
.Read		push edi
			mov edi, DWORD [ata_id_arr]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DATA
			mov ecx, 256
			rep insw
			push esi
			; copy data
			mov esi, DWORD [ata_id_arr]
			add esi, 2*1
			mov cx, WORD [esi]
			mov WORD [ata_iden_maxcyl], cx
			mov esi, DWORD [ata_id_arr]
			add esi, 2*3
			mov cx, WORD [esi]
			mov WORD [ata_iden_maxhead], cx
			mov esi, DWORD [ata_id_arr]
			add esi, 2*6
			mov cx, WORD [esi]
			mov WORD [ata_iden_maxsect], cx

			mov ecx, 10
			mov esi, DWORD [ata_id_arr]
			add esi, 2*10
			mov edi, ata_iden_sn
			rep movsw
			mov ecx, 4
			mov esi, DWORD [ata_id_arr]
			add esi, 2*23
			mov edi, ata_iden_fv
			rep movsw
			mov ecx, 20
			mov esi, DWORD [ata_id_arr]
			add esi, 2*27
			mov edi, ata_iden_mn
			rep movsw
			mov esi, DWORD [ata_id_arr]
			test WORD [esi], 0x8000
			jz	.SetATA
			mov BYTE [ata_iden_ata], 0
			jmp .ChkLBA
.SetATA		mov BYTE [ata_iden_ata], 1
.ChkLBA		mov esi, DWORD [ata_id_arr]
			add esi, 2*49
			test WORD [esi], 0x0200
			jnz	.SetLBA
			mov BYTE [ata_iden_lba], 0
			; here should cmd 0x91 execute and then read words54-56 for CHS
			; also should calculate MAXLBA here from CHS
			jmp .ChkDMA
.SetLBA		mov BYTE [ata_iden_lba], 1
.ChkLBA48	mov esi, DWORD [ata_id_arr]
			add esi, 2*83
			test WORD [esi], 0x0400
			jnz	.SetLBA48
			mov BYTE [ata_iden_lba48], 0
			jmp .MaxLBA28
.SetLBA48	mov BYTE [ata_iden_lba48], 1
.MaxLBA28	mov ecx, 2
			mov esi, DWORD [ata_id_arr]
			add esi, 2*60
			mov edi, ata_iden_maxlba28
			rep movsw
			mov ecx, 4
			mov esi, DWORD [ata_id_arr]
			add esi, 2*100
			mov edi, ata_iden_maxlba48
			rep movsw
			; DMA
.ChkDMA		mov esi, DWORD [ata_id_arr]
			add esi, 2*49
			test WORD [esi], 0x0100
			jnz	.SetDMA
			mov BYTE [ata_iden_dma], 0
			jmp .SetMDMA
.SetDMA		mov BYTE [ata_iden_dma], 1
.SetMDMA	mov esi, DWORD [ata_id_arr]
			add esi, 2*63
			mov cx, WORD [esi]
			and cx, 0x0007
			mov [ata_iden_mdma], cl
			mov esi, DWORD [ata_id_arr]
			add esi, 2*88
			mov cx, WORD [esi]
			and cx, 0x007F
			mov [ata_iden_udma], cl
			mov esi, DWORD [ata_id_arr]
			add esi, 2*47
			mov cx, WORD [esi]
			and cx, 0x007F
			mov [ata_iden_maxlsn], cl
			mov esi, DWORD [ata_id_arr]
			add esi, 2*59
			mov cx, WORD [esi]
			and cx, 0x007F
			mov [ata_iden_currlsn], cl
			mov esi, DWORD [ata_id_arr]
			add esi, 2*106
			mov cx, WORD [esi]
			mov ax, cx
			and ax, 0xC000
			cmp ax, 0x4000
			jz	.Valid
			jmp .Sect512
.Valid		mov esi, DWORD [ata_id_arr]
			add esi, 2*106
			test WORD [esi], 0x2000 
			jz	.LogSectS
			and cl, 0x0F
			mov [ata_iden_logperphys], cl
.LogSectS	test WORD [esi], 0x1000
			jz	.Sect512
			mov esi, DWORD [ata_id_arr]
			add esi, 2*117
			mov ecx, [esi]
			mov DWORD [ata_iden_logsectsize], ecx
			jmp .Capacity
.Sect512	mov ecx, 512
			mov DWORD [ata_iden_logsectsize], ecx
			; Capacity computation (Gb)	
.Capacity	mov ecx, 11 ;21	; if sector=512 byte then shift 2^11 to get Gb (512=2^9 ; Mb=1024*1024byte i.e. 2^20; so shift 20-9 to the right to get Mb)
			cmp DWORD [ata_iden_logsectsize], 1024
			jnz .Chk2048
			mov ecx, 10 ;20
			jmp .GetLBA
.Chk2048	cmp DWORD [ata_iden_logsectsize], 2048
			jnz .Chk4096
			mov ecx, 9 ;19
			jmp .GetLBA
.Chk4096	cmp DWORD [ata_iden_logsectsize], 4096
			jnz .GetLBA
			mov ecx, 8 ;18
.GetLBA		cmp BYTE [ata_iden_lba48], 1
			jz	.GetLBA48
			mov edx, [ata_iden_maxlba28]
			mov [ata_maxlba], edx
			shr edx, cl
			mov [ata_capacity], edx
			jmp .Ok
.GetLBA48	push ecx
			mov ecx, 8
			mov esi, ata_iden_maxlba48
			mov edi, ata_iden_maxlba48tmp
			rep movsb
			pop ecx
			mov edx, DWORD [ata_iden_maxlba48tmp]
			mov [ata_maxlba], edx
			shr edx, cl
			mov [ata_capacity], edx
.Ok			mov al, ATA_OK
			pop esi
			pop edi
.Back		mov [ata_identify_res], al
			ret


ata_info:
			push esi
			; serial number
			mov ebx, SerialNumtxt
			call gstdio_draw_text
			mov ecx, 10
			mov esi, ata_iden_sn
			xor ebx, ebx
.NextSN		mov ax, WORD [esi]			
			mov bl, ah
			call gstdio_draw_char
			mov bl, al
			call gstdio_draw_char
			add esi, 2
			loop .NextSN
			call gstdio_new_line
			; firmware version
			mov ebx, FirmwareVertxt
			call gstdio_draw_text
			mov ecx, 4
			mov esi, ata_iden_fv
			xor ebx, ebx
.NextFV		mov ax, WORD [esi]
			mov bl, ah
			call gstdio_draw_char
			mov bl, al
			call gstdio_draw_char
			add esi, 2
			loop .NextFV
			call gstdio_new_line
			; model number
			mov ebx, ModelNumtxt
			call gstdio_draw_text
			mov ecx, 20
			mov esi, ata_iden_mn
			xor ebx, ebx
.NextMN		mov ax, WORD [esi]			
			mov bl, ah
			call gstdio_draw_char
			mov bl, al
			call gstdio_draw_char
			add esi, 2
			loop .NextMN
			call gstdio_new_line
			; ATA?
			cmp BYTE [ata_iden_ata], 1
			jnz .PrLBA
;			mov ebx, ATAtxt
;			call gstdio_draw_text
;			call gstdio_new_line
			mov ebx, Supportedtxt
			call gstdio_draw_text
			; LBA?
.PrLBA		cmp BYTE [ata_iden_lba], 1
			jnz .PrDMA
			mov ebx, LBAtxt
			call gstdio_draw_text
			; LBA48?
			cmp BYTE [ata_iden_lba48], 1
			jnz .PrDMA
			mov ebx, LBA48txt
			call gstdio_draw_text
			; DMA?
.PrDMA		cmp BYTE [ata_iden_dma], 1
			jnz .PrMaxLBA28
			mov ebx, DMAtxt
			call gstdio_draw_text
			; Max sector-number of LBA28
.PrMaxLBA28	call gstdio_new_line
			cmp BYTE [ata_iden_lba], 1
			jnz .PrCHS
			mov ebx, MaxLBA28txt
			call gstdio_draw_text
			mov eax, [ata_iden_maxlba28]
			call gstdio_draw_dec
			call gstdio_new_line
			; Max sector-number of LBA48
			cmp BYTE [ata_iden_lba48], 1
			jnz .PrMaxSctPW
			mov ebx, MaxLBA48txt
			call gstdio_draw_text
			mov eax, DWORD [ata_iden_maxlba48]			;;;;;;
			mov edx, DWORD [ata_iden_maxlba48+4]
			call gstdio_draw_dec64
			call gstdio_new_line
			jmp .PrMaxSctPW
.PrCHS		mov ebx, MaxCHStxt
			call gstdio_draw_text
			xor eax, eax
			mov ax, [ata_iden_maxcyl]
			call gstdio_draw_dec
			mov ebx, DWORD ' '
			call gstdio_draw_char
			xor eax, eax
			mov ax, [ata_iden_maxhead]
			call gstdio_draw_dec
			mov ebx, DWORD ' '
			call gstdio_draw_char
			xor eax, eax
			mov ax, [ata_iden_maxsect]
			call gstdio_draw_dec
			call gstdio_new_line
			; Max number of Logical Sectors per Read/Write Multiple Commands
.PrMaxSctPW	mov ebx, MaxNumSectPerMultiCmdtxt
			call gstdio_draw_text
			xor eax, eax
			mov al, BYTE [ata_iden_maxlsn]
			call gstdio_draw_dec
			call gstdio_new_line
			cmp BYTE [ata_iden_logperphys], 0
			jz	.PrLogSctSi
			mov ebx, LogSectsPerPhysSecttxt
			call gstdio_draw_text
			xor eax, eax
			mov al, BYTE [ata_iden_logperphys]
			call gstdio_draw_dec
			call gstdio_new_line
.PrLogSctSi	mov ebx, LogicalSectorSizetxt
			call gstdio_draw_text
			mov eax, DWORD [ata_iden_logsectsize]
			call gstdio_draw_dec
			call gstdio_new_line
			; Capacity
			mov ebx, Capacitytxt
			call gstdio_draw_text
			mov eax, [ata_capacity]
			call gstdio_draw_dec
			mov ebx, CapacityUnittxt
			call gstdio_draw_text		
			call gstdio_new_line
			; Primary or Secondary Bus, Master or Slave
			cmp WORD [ata_port_base], 0x1F0
			jnz	.SecondaryB
			mov ebx, PrimaryBustxt
			call gstdio_draw_text	
			jmp .MasterSl
.SecondaryB	cmp WORD [ata_port_base], 0x170
			jnz	.MasterSl
			mov ebx, SecondaryBustxt
			call gstdio_draw_text	
.MasterSl	cmp BYTE [ata_slave_bit], 0
			jnz .Slave
			mov ebx, Mastertxt
			call gstdio_draw_text	
			jmp .End
.Slave		mov ebx, Slavetxt
			call gstdio_draw_text	
.End		pop esi
			ret


; Not used!?
ata_reset:
			push eax
			mov dx, WORD [ata_port_ctrl]		; does a reset on the bus
			mov al, ATA_DCR_SRST
			out dx, al			; do a "software reset" on the bus
			xor eax, eax
			out dx, al			; reset the bus to normal operation
			in al, dx			; it might take 4 tries for status bits to reset
			in al, dx			; ie. do a 400ns delay
			in al, dx
			in al, dx			; do we really need these 4 in-s ?
			mov dx, [ata_port_base]
			add dx, ATA_PORT_STATUS
.rdylp		in al, dx
			and al, ATA_ST_BSY+ATA_ST_RDY		; check BSY and RDY
			cmp al, ATA_ST_RDY			; want BSY clear and RDY set
			jne short .rdylp
			pop eax
			ret


; IN: ECX: lbaLo, EBP: lbaHi, EBX: sectorcnt, EAX: memaddr, EDX(1 if write)
; OUT: AL (0 indicates success)
ata_rw:
			cmp BYTE [ata_lock], 1
			jnz	.ChkMaxLBA
			mov al, ATA_LOCKED					; ata_locked be a system variable!?
			ret
.ChkMaxLBA	push esi
			push edi
			; check given LBA against MaxLBA
			cmp BYTE [ata_iden_lba48], 1
			jz	.ChkMax48
			cmp ecx, [ata_iden_maxlba28]
			jnc	.Back
			mov esi, ecx
			add esi, ebx
			jo	.Back
			cmp esi, [ata_iden_maxlba28]
			jnc	.Back
			jmp .Start
.ChkMax48	cmp ebp, [ata_iden_maxlba48+4]
			ja	.Back
			cmp ebp, [ata_iden_maxlba48+4]
			jne	.Start
			cmp ecx, [ata_iden_maxlba48]
			jnc	.Back
			mov esi, ecx
			add esi, ebx
			jo	.Back
			cmp esi, [ata_iden_maxlba48]
			jnc	.Back
.Start		mov BYTE [ata_lock], 1
			mov [ata_mem_addr], eax
			mov [ata_sector_cnt], ebx
			mov [ata_new_lba], ecx
			mov [ata_new_lbahi], ebp
			cmp BYTE [ata_iden_lba48], 1
			jz	.LBA48Lim
			mov DWORD [ata_limit], 0xFF
			jmp .ChkLim
.LBA48Lim	mov DWORD [ata_limit], 0xFFFF
.ChkLim		cmp ebx, [ata_limit]
			jna	.Decr
			mov ebx, [ata_limit]
.Decr		sub [ata_sector_cnt], ebx
			mov [ata_curr_sector_cnt], ebx
			cmp BYTE [ata_iden_lba], 1
			jnz	.CHS
			cmp BYTE [ata_iden_lba48], 1
			jz	.LBA48
			call ata_rw_lba28
			cmp al, ATA_OK
			jnz	.Back
			jmp .ChkRem
.LBA48		mov [ata_lba48], ecx
			mov [ata_lba48+4], ebp
			call ata_rw_lba48
			cmp al, ATA_OK
			jnz	.Back
			jmp .ChkRem
.CHS		call ata_rwchs
			cmp al, ATA_OK
			jnz	.Back
			; Check if there are more sectors
.ChkRem		cmp DWORD [ata_sector_cnt], 0
			je	.Ok
			; Next iteration ; IN: ECX(lbaLo), EBP(lbaHi), EBX(sectorcnt), EAX(memaddr)
			mov ebx, [ata_sector_cnt]
			mov ecx, [ata_new_lba]
			add ecx, [ata_curr_sector_cnt]
			mov ebp, [ata_new_lbahi]
			mov eax, [ata_curr_sector_cnt]
			shl	eax, 9									; *512
			add eax, [ata_mem_addr]
			jmp .ChkLim
.Ok			mov al, ATA_OK
.Back		pop edi
			pop esi
			mov BYTE [ata_lock], 0
			ret


; IN: 28-bit LBA in ECX; sector-count in BL; memory-address in ata_mem_addr; R/W (read=0) in EDX 
; OUT: AL 0 is ok
; sector-count of 0 means 256 sectors (128Kb) !?
ata_rw_lba28:
			; send 0xE0 for the master or 0xF0 for the slave ORed with the highest 4 bits of the LBA to port DRV_HEAD
			push esi
			push edi
			push edx
			push ecx
			push ebx
			mov al, ATA_LBA28_MASTER
			mov bl, [ata_slave_bit]
			shl bl, 4
			or	al, bl
			pop ebx
			shr ecx, 24
			and cl, 0x0F
			or al, cl
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DRV_HEAD
			out dx, al

			; send a NULL byte to port ERROR, if you like (it's ignored)
			mov al, 0
			mov dx, [ata_port_base]
			add dx, ATA_PORT_ERROR
			out dx, al
			; send sectorcount to port SECT_COUNT
			mov al, bl
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_COUNT
			out dx, al
			; send the low 8 bits of the LBA to port SECT_NUM
			pop eax				; pop ecx in eax
			push eax
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_NUM
			out dx, al
			; send the next low 8 bits of the LBA to port CYL_LOW
			pop eax
			push eax
			shr ax, 8
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_LOW
			out dx, al
			; send the next low 8 bits of the LBA to port CYL_HIGH
			pop eax
			shr eax, 16
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_HIGH
			out dx, al
			; check if read or write
			pop edx
			cmp dl, 1
			jz	.SendWrite
			; Read
			; send r/w cmd to port COMMAND
			mov al, ATA_CMD_READ
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
			mov ecx, 4
.ChkR		in al, dx								; COMMAND and STATUS share the same port
			test al, ATA_ST_BSY
			jne	.RetryR
			test al, ATA_ST_DRQ
			jne	.Read
.RetryR		dec ecx
			jg	.ChkR
.ChkRBSY	in	al, dx
			test al, ATA_ST_BSY
			jne	.ChkRBSY
			test al, ATA_ST_ERR+ATA_ST_DF
			jnz	.Err
			; sect_count times
			; Read SectSize/2 words from PORT_DATA
.Read		mov ecx, DWORD [ata_iden_logsectsize]
			shr ecx, 1					; to get word instead of byte (divide by 2)
			mov edi, DWORD [ata_mem_addr]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DATA
			rep insw
			mov dx, [ata_port_base]
			add dx, ATA_PORT_STATUS
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			cmp bx, 1
			jne	.StillData
			test al, ATA_ST_ERR+ATA_ST_DF
			jnz	.Err
			jmp .Ok
.StillData	dec ebx
			mov ecx, DWORD [ata_iden_logsectsize]
			add DWORD [ata_mem_addr], ecx
%ifdef MULTITASKING_DEF
			mov DWORD [pit_task_ticks], 0					; clear pit-ticks
%endif
			jmp .ChkRBSY
			; Write
			; send r/w cmd to port COMMAND
.SendWrite	mov al, ATA_CMD_WRITE
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
			mov ecx, 4
.ChkW		in al, dx								; COMMAND and STATUS share the same port
			test al, ATA_ST_BSY
			jne	.RetryW
			test al, ATA_ST_DRQ
			jne	.Write
.RetryW		dec ecx
			jg	.ChkW
.ChkWBSY	in	al, dx
			test al, ATA_ST_BSY
			jne	.ChkWBSY
			test al, ATA_ST_ERR+ATA_ST_DF
			jnz	.Err
			; sect_count times
			; Write SectSize/2 words to PORT_DATA
.Write		mov ecx, DWORD [ata_iden_logsectsize]
			shr ecx, 1					; to get word instead of byte (divide by 2)
			mov esi, DWORD [ata_mem_addr]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DATA		; Don't use rep outsw, because it's too fast!
.NextR		outsw
			xor eax, eax				; delay
			xor eax, eax				; delay
			loop .NextR
			mov dx, [ata_port_base]
			add dx, ATA_PORT_STATUS
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			cmp bx, 1
			jne	.StillDataW
			test al, ATA_ST_ERR+ATA_ST_DF
			jnz	.Err
			jmp .Flush
.StillDataW	dec ebx
			mov ecx, DWORD [ata_iden_logsectsize]
			add DWORD [ata_mem_addr], ecx
%ifdef MULTITASKING_DEF
			mov DWORD [pit_task_ticks], 0					; clear pit-ticks
%endif
			jmp .ChkWBSY
			; flush (0xE7) after each write (maybe in the loop after every cycle!?)
.Flush		mov al, ATA_CMD_FLUSH_CACHE_EXT
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
.ChkFBSY	in	al, dx
			test al, ATA_ST_BSY
			jne	.ChkFBSY
.Ok			mov al, ATA_OK
			jmp .Back
.Err		mov al, ATA_ERR
.Back		pop edi
			pop esi
			ret


; IN: 48-bit LBA in [ata_lba48]; sector-count in BX; memory-address in ata_mem_addr; R/W (read=0) in EDX 
; OUT: AL 0 is ok
; sector-count of 0 means 65536 sectors (32Mb) !?
; Since FOS is a 32-bit OS, 48-bit LBA cannot be entered in the command line!? (with LO and HI 32-bits on pstack it is possible).
ata_rw_lba48:
			; send 0x40 for the master or 0x50 for the slave
			push esi
			push edi
			push edx
			push ebx
			mov al, ATA_LBA48_MASTER
			mov bl, [ata_slave_bit]
			shl bl, 4
			or	al, bl
			pop ebx
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DRV_HEAD
			out dx, al
			; send sectorcount high-byte to port SECT_COUNT
			mov al, bh
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_COUNT
			out dx, al
			; send LBA4 to port SECT_NUM
			mov al, [ata_lba48+3]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_NUM
			out dx, al
			; send LBA5 to port CYL_LOW
			mov al, [ata_lba48+4]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_LOW
			out dx, al
			; send LBA6 to port CYL_HI
			mov al, [ata_lba48+5]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_HIGH
			out dx, al
			; send sectorcount low-byte to port SECT_COUNT
			mov al, bl
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_COUNT
			out dx, al
			; send LBA1 to port SECT_NUM
			mov al, [ata_lba48]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_NUM
			out dx, al
			; send LBA2 to port CYL_LOW
			mov al, [ata_lba48+1]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_LOW
			out dx, al
			; send LBA3 to port CYL_HI
			mov al, [ata_lba48+2]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_HIGH
			out dx, al
			; check if read or write
			pop edx
			cmp dl, 1
			jz	.SendWrite
			; Read
			; send r/w cmd to port COMMAND
			mov al, ATA_CMD_READ_EXT
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
			mov ecx, 4
.ChkR		in al, dx								; COMMAND and STATUS share the same port
			test al, ATA_ST_BSY
			jne	.RetryR
			test al, ATA_ST_DRQ
			jne	.Read
.RetryR		dec ecx
			jg	.ChkR
.ChkRBSY	in	al, dx
			test al, ATA_ST_BSY
			jne	.ChkRBSY
			test al, ATA_ST_ERR+ATA_ST_DF
			jne	.Err
			; sect_count times
			; Read SectSize/2 words from PORT_DATA
.Read		mov ecx, DWORD [ata_iden_logsectsize]
			shr ecx, 1					; to get word instead of byte (divide by 2)
			mov edi, DWORD [ata_mem_addr]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DATA
			rep insw
			mov dx, [ata_port_base]
			add dx, ATA_PORT_STATUS
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			cmp bx, 1
			jne	.StillData
			test al, ATA_ST_ERR+ATA_ST_DF
			jnz	.Err
			jmp .Ok
.StillData	dec ebx
			mov ecx, DWORD [ata_iden_logsectsize]
			add DWORD [ata_mem_addr], ecx
%ifdef MULTITASKING_DEF
			mov DWORD [pit_task_ticks], 0					; clear pit-ticks
%endif
			jmp .ChkRBSY
			; Write
			; send r/w cmd to port COMMAND
.SendWrite	mov al, ATA_CMD_WRITE_EXT
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
			mov ecx, 4
.ChkW		in al, dx								; COMMAND and STATUS share the same port
			test al, ATA_ST_BSY
			jne	.RetryW
			test al, ATA_ST_DRQ
			jne	.Write
.RetryW		dec ecx
			jg	.ChkW
.ChkWBSY	in	al, dx
			test al, ATA_ST_BSY
			jne	.ChkWBSY
			test al, ATA_ST_ERR+ATA_ST_DF
			jnz	.Err
			; sect_count times
			; Write SectSize/2 words to PORT_DATA
.Write		mov ecx, DWORD [ata_iden_logsectsize]
			shr ecx, 1					; to get word instead of byte (divide by 2)
			mov esi, DWORD [ata_mem_addr]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DATA		; Don't use rep outsw, because it's too fast!
.NextR		outsw
			xor eax, eax				; delay
			xor eax, eax				; delay
			loop .NextR
			mov dx, [ata_port_base]
			add dx, ATA_PORT_STATUS
			in	al, dx
			in	al, dx
			in	al, dx
			in	al, dx
			cmp bx, 1
			jne	.StillDataW
			test al, ATA_ST_ERR+ATA_ST_DF
			jnz	.Err
			jmp .Flush
.StillDataW	dec ebx
			mov ecx, DWORD [ata_iden_logsectsize]
			add DWORD [ata_mem_addr], ecx
%ifdef MULTITASKING_DEF
			mov DWORD [pit_task_ticks], 0					; clear pit-ticks
%endif
			jmp .ChkWBSY
			; flush (0xE7) after each write (maybe in the loop after every cycle!?)
.Flush		mov al, ATA_CMD_FLUSH_CACHE_EXT
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
.ChkFBSY	in	al, dx
			test al, ATA_ST_BSY
			jne	.ChkFBSY
.Ok			mov al, ATA_OK
			jmp .Back
.Err		mov al, ATA_ERR
.Back		pop edi
			pop esi
			ret


; CHS-mode (i.e. non-LBA)
; IN: lba ECX
; OUT: cyl head sect to tmp storage
ata_lba2chs:
			push eax
			push ebx
			push ecx
			push edx
			xor eax, eax
			xor ebx, ebx
			mov ax, [ata_iden_maxhead]
			mov bx, [ata_iden_maxsect]
			mul ebx
			xor edx, edx		; we throw away the EDX-part (division can't use it)
			mov ebx, eax
			mov eax, ecx
			div ebx
			; cylinder
			mov [ata_cyl], ax
			xor edx, edx
			mov eax, ecx
			xor ebx, ebx
			mov bx, [ata_iden_maxsect]
			div ebx
			xor edx, edx
			xor ebx, ebx
			mov bx, [ata_iden_maxhead]
			div ebx
			; head
			mov [ata_head], dx
			mov eax, ecx
			xor ebx, ebx
			xor edx, edx
			mov bx, [ata_iden_maxsect]
			div ebx
			inc edx
			; sector
			mov [ata_sect], dx
			pop edx
			pop ecx
			pop ebx
			pop eax
			ret


; IN: LBA in ECX; sector-count in BL; memory-address in ata_mem_addr; R/W (read=0) in EDX 
; OUT: AL (0 indicates success)
ata_rwchs:
%ifdef MULTITASKING_DEF
			mov DWORD [pit_task_ticks], 0					; clear pit-ticks
%endif
			call ata_lba2chs		; result in: ata_cyl, _head, _sect
			push edx
			push ebx
			mov al, ATA_CHS_MASTER
			mov bl, [ata_slave_bit]
			shl bl, 4
			or	al, bl
			mov bx, [ata_head]
			or	al, bl				; head < 256 !?
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DRV_HEAD
			out dx, al
			; send sectorcount to port SECT_COUNT
			pop ebx
			mov al, bl
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_COUNT
			out dx, al
			; send S to port SECT_NUM
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_NUM
			mov ax, [ata_sect]
			out dx, al
			; send C-low to port CYL_LOW
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_LOW
			mov ax, [ata_cyl]
			out dx, al
			; send C-high to port CYL_HIGH
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_HIGH
			mov ax, [ata_cyl]
			shr ax, 8
			out dx, al
			; check if read or write
			pop edx
			cmp dl, 1
			jz	.WriteCMD
			; Read
			; send r/w cmd to port COMMAND
			mov al, ATA_CMD_READ
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
.Poll		in al, dx
			test al, ATA_ST_BSY				; wait for BUSY bit to clear
			jnz	.Poll
			test al, ATA_ST_ERR+ATA_ST_DF
			jz	.Read
			mov al, ATA_ERR
			jmp	.Back
			; sect_count times
			; Read SectSize/2 words from PORT_DATA
.Read		mov eax, DWORD [ata_iden_logsectsize]
			shr eax, 1					; to get word instead of byte (divide by 2)
			mul ebx
			mov ecx, eax				; EDX not important
			push edi
			mov edi, DWORD [ata_mem_addr]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DATA
			rep insw
			pop edi
			xor eax, eax
			mov al, ATA_OK
			jmp .Back
			; Write
			; send r/w cmd to port COMMAND
.WriteCMD	mov al, ATA_CMD_WRITE
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
.Poll2		in al, dx
			test al, ATA_ST_BSY				; wait for BUSY bit to clear
			jnz	.Poll2
			test al, ATA_ST_ERR+ATA_ST_DF
			jz	.Write
			mov al, ATA_ERR
			jmp	.Back
			; sect_count times
			; Write SectSize/2 words to PORT_DATA
.Write		mov eax, DWORD [ata_iden_logsectsize]
			shr eax, 1					; to get word instead of byte (divide by 2)
			mul ebx
			mov ecx, eax				; EDX not important
			push esi
			mov esi, DWORD [ata_mem_addr]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DATA		; Don't use rep outsw, because it's too fast!
.NextR		outsw
			xor eax, eax				; delay
			loop .NextR
			pop esi
			; flush (0xE7) after each write (maybe in the loop after every cycle!?)
			mov al, ATA_CMD_FLUSH_CACHE
			mov dx, [ata_port_base]
.Back		ret


%ifdef MULTITASKING_DEF
; ************************** DMA *********************************

; IN: ECX(lbaLo), EBP(lbaHi), EBX(sectorcnt), EAX(memaddr), EDX(1 if write)
; OUT: AL (0 indicates success)
ata_rw_dma:
			cmp BYTE [ata_lock], 1
			jnz	.Start
			mov al, ATA_LOCKED					; ata_locked be a system variable!?
			ret
.Start		mov BYTE [ata_lock], 1
			push ebx
			push ecx
			push edx
			push ebp
			mov [ata_dma_write], dl
			mov [ata_dma_dword_sector_cnt], ebx
			cmp BYTE [ata_iden_lba48], 1
			jz	.LBA48Lim
			mov DWORD [ata_dma_limit], 0xFF
			jmp .ChkLim
.LBA48Lim	mov DWORD [ata_dma_limit], 0xFFFF
.ChkLim		cmp ebx, [ata_dma_limit]
			jna	.Do
			mov ebx, [ata_dma_limit]
.Do			sub [ata_dma_dword_sector_cnt], ebx
			mov BYTE [ata_irq_ready], 0
			cmp BYTE [ata_iden_lba], 1
			jnz	.Err
.Again		mov [ata_dma_mem_addr], eax
			cmp BYTE [ata_iden_lba48], 1
			jz	.LBA48
			mov [ata_dma_new_lba], ecx
			mov DWORD [ata_dma_new_lbahi], 0
			call ata_rw_dma_lba28
			cmp al, ATA_OK
			jnz	.Back
			jmp .PauseInit
.LBA48		mov [ata_dma_lba], ecx
			mov [ata_dma_lbahi], ebp
			mov [ata_dma_new_lba], ecx
			mov [ata_dma_new_lbahi], ebp
			call ata_rw_dma_lba48
			cmp al, ATA_OK
			jnz	.Back
.PauseInit	mov ecx, 1000000							; Timeout
.Pause		push ecx
			call _pause
			pop ecx
			cmp BYTE [ata_irq_ready], 0
			jnz	.Out
			loop .Pause
			jmp .Err
.Out		cmp BYTE [ata_irq_ready], -1
			je	.Err
			mov BYTE [ata_irq_ready], 0
			; Check if there are more sectors, if yes ==> start new DMA
			cmp WORD [ata_dma_sector_cnt], 0
			jnz	.Next
			cmp DWORD [ata_dma_dword_sector_cnt], 0
			jz	.Back
			mov ebx, [ata_dma_dword_sector_cnt]
			cmp ebx, [ata_dma_limit]
			jna	.Decr
			mov ebx, [ata_dma_limit]
.Decr		sub [ata_dma_dword_sector_cnt], ebx
			mov [ata_dma_sector_cnt], bx
	; IN: ECX(lbaLo), EBP(lbaHi), EBX(sectorcnt), EAX(memaddr)
.Next		mov ecx, [ata_dma_new_lba]
			mov ebp, [ata_dma_new_lbahi]
			xor ebx, ebx
			mov bx, [ata_dma_sector_cnt]
			mov eax, [ata_dma_mem_addr]
			jmp .Again
.Err		call ata_stop_dma
			mov al, ATA_ERR	
.Back		pop ebp
			pop edx
			pop ecx
			pop ebx
			mov BYTE [ata_lock], 0
			ret


ata_start_dma:
			mov edx, [pci_bus_master_reg]				; its lowest bit determines if memmapped or port
			mov ebx, [ata_master_offs]	
			xor eax, eax
			mov al, [ebx]
			add edx, eax		; command-reg in EDX
			in	al, dx
			or	al, ATA_BMR_CMD_START
			out dx, al
			ret


ata_stop_dma:
			mov edx, [pci_bus_master_reg]				; its lowest bit determines if memmapped or port
			mov ebx, [ata_master_offs]	
			xor eax, eax
			mov al, [ebx]
			add edx, eax		; command-reg in EDX
			in	al, dx
			and	al, ~ATA_BMR_CMD_START
			out dx, al
			ret


; IN: sector-count in BX; memory-address in ata_mem_addr; R/W (read=0) in ata_dma_write
; OUT: AL (ATA_OK on success), EBX(changed sectorcnt, if > 128)
ata_init_dma:
			push eax
			push edx
			push edi
;			call ata_stop_dma
;			push ebx
;			mov ebx, 1
;			call pit_delay
;			pop ebx
			; SET PRDT
			mov eax, ATA_DMA_PRDT
			mov edi, ATA_DMA_BUFF
			mov [eax], edi
			mov DWORD [eax+4], 0x80000000	; 0 means 64Kb
			cmp bx, 128						; 64Kb ?
			ja	.Full
			cmp ebx, 128
			je	.Skip
			push ebx
			shl	ebx, 9
			mov DWORD [eax+4], ebx			; if less than 128 sectors (i.e. 64kb), then store the bytesnum
			or	DWORD [eax+4], 0x80000000
			pop ebx
.Skip		mov WORD [ata_dma_sector_cnt], 0
			mov [ata_dma_sectors_copied], ebx
			add [ata_dma_new_lba], ebx		; we don't care about higher 32-bits (EBP)
			jmp .Do
.Full		mov [ata_dma_sector_cnt], bx
			sub WORD [ata_dma_sector_cnt], 128
			mov ebx, 128
			mov [ata_dma_sectors_copied], ebx
			add [ata_dma_new_lba], ebx		; we don't care about higher 32-bits (EBP)
.Do			push ebx
			; clear status-Err(bit1 and -IRQ(bit2) bits, set R/W (bit3), prdt address, RUN-bit in BMR-cmd
			mov edx, [pci_bus_master_reg] ; its lowest bit determines if memmapped or port
			mov ebx, [ata_master_offs]	
			; Status (clear Err and IRQ bits)
			add ebx, ATA_BMR_STATUS_OFFS
			xor eax, eax
			mov al, [ebx]
			add edx, eax		; status-reg in EDX	 (status is WC)
			in	al, dx
			or	al, 6			; clear Err and IRQ bits (WC !?)
			out dx, al
			; Set addr
			mov edx, [pci_bus_master_reg] ; its lowest bit determines if memmapped or port
			mov ebx, [ata_master_offs]	
			add ebx, ATA_BMR_PRDT_OFFS
			xor eax, eax
			mov al, [ebx]
			add edx, eax		; PRDT in EDX
			mov eax, ATA_DMA_PRDT
			out dx, eax
			; Cmd (set R/W bit(bit3))
			mov edx, [pci_bus_master_reg]
			mov ebx, [ata_master_offs]	
			xor eax, eax
			mov al, [ebx]
			add edx, eax		; command-reg in EDX
			in	al, dx
			cmp BYTE [ata_dma_write], 1			; write ?
			je	.W
			or	al, ATA_BMR_CMD_READ
			jmp .Send
.W			and	al, ~ATA_BMR_CMD_READ
.Send		out dx, al
			mov dx, [ata_port_base]
			add dx, ATA_PORT_STATUS
.Poll		in al, dx
			test al, ATA_ST_BSY				; wait for BUSY bit to clear
			jnz	.Poll
			mov al, ATA_OK
			pop ebx
			pop edi
			pop edx
			pop eax
			ret


; IN: 28-bit LBA in ECX; sector-count in BL; memory-address in ata_mem_addr; R/W (read=0) in ata_dma_write 
; OUT: AL 0 is ok
ata_rw_dma_lba28:
			push esi
			push edi
			call ata_init_dma
			cmp al, ATA_OK
			jnz	.Back
			push ebx
			; SET LBA VIA PIO
			mov al, ATA_LBA28_MASTER
			mov bl, [ata_slave_bit]
			shl bl, 4
			or	al, bl
			pop ebx	
			shr ecx, 24
			and cl, 0x0F
			or al, cl
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DRV_HEAD
			out dx, al

			; send a NULL byte to port ERROR, if you like (it's ignored)
			mov al, 0
			mov dx, [ata_port_base]
			add dx, ATA_PORT_ERROR
			out dx, al
			; send sectorcount to port SECT_COUNT
			mov al, bl
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_COUNT
			out dx, al
			; send the low 8 bits of the LBA to port SECT_NUM
			pop eax				; pop ecx in eax
			push eax
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_NUM
			out dx, al
			; send the next low 8 bits of the LBA to port CYL_LOW
			pop eax
			push eax
			shr ax, 8
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_LOW
			out dx, al
			; send the next low 8 bits of the LBA to port CYL_HIGH
			pop eax
			shr eax, 16
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_HIGH
			out dx, al
			mov dx, [ata_port_base]
			add dx, ATA_PORT_STATUS

			mov BYTE [ata_irq], 1

			; check if read or write
			cmp BYTE [ata_dma_write], 1
			jz	.SendWrite
			; Read
			; send r/w cmd to port COMMAND
			mov al, ATA_CMD_DMA_READ_28
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
			jmp .Out
.SendWrite	mov esi, [ata_dma_mem_addr]
			mov edi, ATA_DMA_BUFF
			mov ecx, [ata_dma_sectors_copied]
			shl	ecx, 9						; *512 to get bytes			
			shr	ecx, 2
			rep movsd
			mov al, ATA_CMD_DMA_WRITE_28
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
.Out		call ata_start_dma
			mov al, ATA_OK
			jmp .Back
.Err		mov al, ATA_ERR
.Back		pop edi
			pop esi
			ret


; IN: 48-bit LBA in [ata_dma_lba] [...hi]; sector-count in BX; memory-address in ata_dma_mem_addr; R/W (read=0) in ata_dma_write  
; OUT: AL 0 is ok
ata_rw_dma_lba48:
			push esi
			push edi
			call ata_init_dma
			cmp al, ATA_OK
			jnz	.Back
			push ebx
			; SET LBA VIA PIO
			mov al, ATA_LBA48_MASTER
			mov bl, [ata_slave_bit]
			shl bl, 4
			or	al, bl
			pop ebx	
			mov dx, [ata_port_base]
			add dx, ATA_PORT_DRV_HEAD
			out dx, al
			; send sectorcount high-byte to port SECT_COUNT
			mov al, bh
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_COUNT
			out dx, al
			; send LBA4 to port SECT_NUM
			mov al, [ata_dma_lbahi]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_NUM
			out dx, al
			; send LBA5 to port CYL_LOW
			mov al, [ata_dma_lbahi+1]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_LOW
			out dx, al
			; send LBA6 to port CYL_HI
			mov al, [ata_dma_lbahi+2]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_HIGH
			out dx, al
			; send sectorcount low-byte to port SECT_COUNT
			mov al, bl
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_COUNT
			out dx, al
			; send LBA1 to port SECT_NUM
			mov al, [ata_dma_lba]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_SECT_NUM
			out dx, al
			; send LBA2 to port CYL_LOW
			mov al, [ata_dma_lba+1]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_LOW
			out dx, al
			; send LBA3 to port CYL_HI
			mov al, [ata_dma_lba+2]
			mov dx, [ata_port_base]
			add dx, ATA_PORT_CYL_HIGH
			out dx, al

			mov BYTE [ata_irq], 1
			; check if read or write
			cmp BYTE [ata_dma_write], 1
			jz	.SendWrite
			; Read
			; send r/w cmd to port COMMAND
			mov al, ATA_CMD_DMA_READ_48
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
			jmp .Out
.SendWrite	mov esi, [ata_dma_mem_addr]
			mov edi, ATA_DMA_BUFF
			mov ecx, [ata_dma_sectors_copied]
			shl	ecx, 9						; *512 to get bytes			
			shr	ecx, 2
			rep movsd
			mov al, ATA_CMD_DMA_WRITE_48
			mov dx, [ata_port_base]
			add dx, ATA_PORT_COMMAND
			out dx, al
.Out		call ata_start_dma
			mov al, ATA_OK
			jmp .Back
.Err		mov al, ATA_ERR
.Back		pop edi
			pop esi
			ret


ata_irq_handler:
			pushad
			cmp BYTE [pci_ide_ctrlr_found], 0
			jz	.Back
			cmp BYTE [ata_irq], 0				; Are we waiting for an IRQ from HD ?
			jz	.Back
			mov BYTE [ata_irq], 0
			mov edx, [pci_bus_master_reg] ; its lowest bit determines if memmapped or port
			mov ebx, [ata_master_offs]	
			; Status
			add ebx, ATA_BMR_STATUS_OFFS
			xor eax, eax
			mov al, [ebx]
			add edx, eax						; status-reg in EDX	 (status is WC)
			in al, dx
			test al, ATA_BMR_STATUS_IRQ
			jz	.Back							; not the IDE controller sent the IRQ
			push eax
			push edx
			; clear run-bit
			call ata_stop_dma
			pop edx
			pop eax
			test al, ATA_BMR_STATUS_ERR
			jnz	.Err
			or	al, ATA_BMR_STATUS_IRQ			; clear IRQ-bit (write-clear)
			out dx, al

			cmp BYTE [ata_dma_write], 1
			je	.Ready
			; copy data, if read
			mov esi, ATA_DMA_BUFF
			mov edi, [ata_dma_mem_addr]
			mov ecx, [ata_dma_sectors_copied]
			shl	ecx, 9				; *512
			shr	ecx, 2
			rep movsd
.Ready		mov ecx, [ata_dma_sectors_copied]
			shl	ecx, 9				; *512
			add [ata_dma_mem_addr], ecx			; increment memory-address
			mov BYTE [ata_irq_ready], 1
			jmp .Back
.Err		or	al, ATA_BMR_STATUS_ERR			; clear ERR-bit (write-clear)
			or	al, ATA_BMR_STATUS_IRQ			; clear IRQ-bit (write-clear)
			out dx, al
			mov BYTE [ata_irq_ready], -1
.Back		popad
			ret

%endif 	; MULTITASKING_DEF


section .data

ata_port_ctrl dw	0	; 0x3F6	; Device Control Register (secondary: 0x376)
ata_port_base dw	0 	; can be 0x1F0 (primary bus) or 0x170 (secondary)
ata_slave_bit	db	0	; change this to 1 if not the master but the slave drive need to be used on the bus

; Disk Geometry (CHS-mode; i.e. non-LBA mode; old winchesters are non-LBA).
; 28-bit LBA was introduced in 1994. Most hard drives released after 1996 implement LBA.
; Sector begins with 1. There is no sector 0. So MBR: CHS=(0, 0, 1); LBA=0
ata_iden_maxcyl		dw	0
ata_iden_maxhead	dw	0
ata_iden_maxsect	dw	0
ata_cyl				dw	0
ata_head			dw	0
ata_sect			dw	0
MaxCHStxt	db "C H S: ", 0
; End of CHS-mode data

ata_id_arr dd 0x14D000	; Pointer to 512byte memory for IDENTIFY (just temporary memory)


ata_prim_master_offs		db 0x00, 0x02, 0x04, 0		; cmd(BYTE), status(BYTE), prdt(DWORD)
ata_sec_master_offs			db 0x08, 0x0A, 0x0C, 0
ata_master_offs				dd 0
%ifdef MULTITASKING_DEF
	ata_dma_dword_sector_cnt	dd 0
	ata_dma_mem_addr			dd 0			; copy the data here from the DMA buffer
	ata_dma_sectors_copied		dd 0
	ata_irq 					db 0			; interrupt from hard disk if set to 1
	ata_irq_ready				db 0
	ata_dma_lba					dd 0
	ata_dma_lbahi				dd 0
	ata_dma_sector_cnt			dw 0
	ata_dma_new_lba				dd 0
	ata_dma_new_lbahi			dd 0
	ata_dma_write				db 0
	ata_dma_limit				dd 0
%endif

ata_sector_cnt		dd 0
ata_curr_sector_cnt	dd 0
ata_new_lba			dd 0
ata_new_lbahi		dd 0
ata_limit			dd 0

; IDENTIFY data
; SerialNum	word10-19 (20bytes). Words are big endian ("abcdefg" is stored as "badcfe g") (chars)
ata_iden_sn	times 20 db 0
SerialNumtxt db "Serial number: ", 0
; Firmware version	word23-26 (chars)
ata_iden_fv	times 8 db 0
FirmwareVertxt db "Firmware version: ", 0
; ModelNumber word 27-46 (40bytes). (chars)
ata_iden_mn	times 40 db 0
ModelNumtxt db "Model number: ", 0
Supportedtxt db "Supported: ", 0
; ATA?	word0, bit15 0: ATA
ata_iden_ata	db 0	; 1 is ATA			; do we need this?
ATAtxt db "ATA device", 0
; LBA?	word49 bit9 (1 if LBA supported)
ata_iden_lba	db 0
LBAtxt db "LBA ", 0
; LBA48 word83 bit10
ata_iden_lba48	db 0
LBA48txt db "LBA48 ", 0
; LBA28	word60-61 max 28-bit-LBA num (if nonzero: supports LBA28)
ata_iden_maxlba28	dd 0
MaxLBA28txt db "MaxLBA28: ", 0
; LBA48	word100-103 max 48-bit-LBA num
ata_iden_maxlba48	times 8 db 0
ata_iden_maxlba48tmp	times 8 db 0
MaxLBA48txt db "MaxLBA48: ", 0
; DMA?	word49 bit8 (1 if DMA supported)
ata_iden_dma	db 0
DMAtxt db "DMA ", 0
; MDMA	word63	(supported MultiDMA modes)	bit2-0
ata_iden_mdma	db 0
; UDMA	word88	(supported UDMA modes)	bit6-0
ata_iden_udma	db 0
; MaxLogicalSectorNumPerRead/WriteMultipleCmds word47 bit7-0
ata_iden_maxlsn db 0
MaxNumSectPerMultiCmdtxt db "Max number of logical sectors per r/w multiple cmds: ", 0
; Current number of logicals sectors/DRQblock on R/W Multiple cmds. word59 bits7-0
ata_iden_currlsn db 0
; PhysicalSectorSize/LogicalSectorSize word106 see bits
;	if bit14=1 and bit15=0 then info is valid in this word
;	if bit13 is set then info in bits3-0 is valid (number of logsects/physsects)
;	if bit12 is set, then this device has been formatted with logical sector size larger than 256 (see words117-118)
ata_iden_logperphys db 0
LogSectsPerPhysSecttxt db "Logical sectors per physical sector: ", 0
; LogicalSectorSize word117-118 (value is valid if bit12 of word106 is set) >256
ata_iden_logsectsize dd 0
LogicalSectorSizetxt db "Logical sectorsize: ", 0
Capacitytxt db "Capacity: ", 0
;CapacityUnittxt db " GiB", 0
CapacityUnittxt db " MiB", 0
ata_capacity dd 0 ; in GB

ata_maxlba dd 0

ata_identify_res db 0	; result of IDENTIFY

PrimaryBustxt	db "Primary bus, ", 0
SecondaryBustxt	db "Secondary bus, ", 0
Mastertxt		db "Master", 0
Slavetxt		db "Slave", 0


ata_mem_addr dd 0	; for R/W

ata_lba48	times 8 db 0		; for R/W LBA48

ata_lock	db 0


%endif

