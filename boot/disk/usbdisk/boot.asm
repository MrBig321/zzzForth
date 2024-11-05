
;*********************************************
;	boot.asm
;		A Simple Bootloader (Volume Boot Record, VBR)
;		Loads the kernel-loader from Fat32
;
;	A one-sector VBR Fat32-bootloader needs to be simplified 
;	(only checks ShortFilename-entries, file needs to be in the first cluster) 
;	in order to fit into 512-bytes.
;*********************************************

bits 16

org	0	

;%define DEBUG

FILE_BUFF_SEG			equ	0x0900
SECTOR_BUFF_SEG			equ	0x0810			; for FAT-table-sector

END_OF_CLUSTER_MARKER	equ 0x0FFFFFF8		; 0x0FFFFFF7 bad sector !?
DELETED_ENTRY			equ	0xE5
LFN_MASK				equ	0x0F

DIR_ENTRY_LEN	equ 32	; bytes

; Short Filename-entry (SFN)
SFN_NAME		equ	0
SFN_ATTRIB		equ	11
SFN_TIME10		equ	13
SFN_TIME		equ	14
SFN_DATE		equ	16	; Create
SFN_LA_DATE		equ 18	; Last access
SFN_CLUSTER_HI	equ 20
SFN_LA_MOD_TIM	equ 22
SFN_LA_MOD_DAT	equ 24	; Last Modify
SFN_CLUSTER_LO	equ 26
SFN_FILESIZE	equ 28

; Attribs
ATTRIB_READONLY		equ	0	; bit0
ATTRIB_HIDDEN		equ	1
ATTRIB_SYSTEM		equ	2
ATTRIB_VOLUMEID		equ	3
ATTRIB_DIRECTORY	equ	4
ATTRIB_ARCHIVE		equ	5

; dataarea
drive_num					equ	data_area+0
partition_lba_begin			equ	data_area+1
;	fat_begin_lba(DWORD)			= Partition_LBA_begin + Number_Of_Reserved_Sectors
;	cluster_begin_lba(DWORD)		= Partition_LBA_begin + Number_Of_Reserved_Sectors + (Number_Of_FATs * Sectors_Per_FAT)
;	sectors_per_cluster(BYTE)		= Sectors Per Cluster
;	root_dir_first_cluster(DWORD)	= Root Dir First Cluster
fat_begin_lba				equ	data_area+5
cluster_begin_lba			equ	data_area+9
root_dir_lba				equ	data_area+13
dir_entries_per_cluster_num	equ	data_area+17
cluster_num					equ	data_area+21
file_size					equ	data_area+25		; NOT USED
memaddr_seg					equ	data_area+29
memaddr_offs				equ	data_area+31
buff						equ	data_area+33


start:	jmp	main

;*********************************************
;	BIOS Parameter Block	(from the first sector of the partition (Volume Boot Record, VBR))
;*********************************************

; BPB Begins 3 bytes from start. We do a far jump, which is 3 bytes in size.
; If you use a short jump, add a "nop" after it to offset the 3rd byte.
; IN ORDER TO BE A FAR JUMP PUT THE FUNCTIONS BEFORE MAIN !!
nop	; !!

bpbOEM					db "mkfs.fat"		; 8 chars
bpbBytesPerSector		dw 0x0200			; 8
bpbSectorsPerCluster	db 0x08				; 10
bpbReservedSectors		dw 0x0020			; 11
bpbNumberOfFATs			db 0x02				; 13
bpbRootEntries			dw 0x0000			; 14
bpbTotalSectors			dw 0x0000			; 16
bpbMedia				db 0xF8				; 18
bpbSectorsPerFATW		dw 0x0000			; 19
bpbSectorsPerTrack		dw 0x003E			; 21
bpbHeadsPerCylinder		dw 0x007C			; 23
bpbHiddenSectors		dd 0x00000800		; 25
bpbLargeTotalSectors	dd 0x0077F800		; 29
bpbSectorsPerFAT		dd 0x00001DF0		; 33
bpbMirroringFlags		dw 0x0000			; 37
bpbVersion				dw 0x0000			; 39
bpbRootDirCluster		dd 0x00000002		; 41
bpbLocationFSInfSector	dw 0x0001			; 45
bpbLocationBackupSector	dw 0x0006			; 47
bpbReservedBootFName	times 12 db 0x00	; 49
bpbPhysDriveNum			db 0x80				; 61
bpbFlags				db 0x01				; 62
bpbExtendedBootSig		db 0x29				; 63
bpbVolumeSerialNum		dd 0x762e0af2		; 64
; DOS 7.1 Extended BPB (79 bytes, without bpbOEM)
bpbVolumeLabel			db "DISK4G     "	; 11 chars	; 68
bpbFSType				db "FAT32   "		; 8 chars	; 79

;*********************************************
;	Bootloader Entry Point
;*********************************************

main:
			cli						; disable interrupts
	;----------------------------------------------------
	; MBR passes partition-entry in DS:SI, and drivenum in DL, save them to a temporary location
	;----------------------------------------------------
			mov bx, ds
			mov cx, si

	;----------------------------------------------------
	; Adjust segment registers
	;----------------------------------------------------
     
			mov ax, 0x07C0			; setup registers to point to our segment
			mov ds, ax

%ifdef DEBUG
			mov ax,0xb800
			mov gs, ax
			mov BYTE [gs:80*24*2], '1'
%endif

	;----------------------------------------------------
	; create stack
	;----------------------------------------------------
     
			mov ax, 0x0000			; set the stack
			mov ss, ax
			mov sp, 0xFFF0			; they say 0 is correct, 0xFFFF would be decremented to 0xFFFD (!?) (maybe sp, 0x0000 ?)
			sti						; restore interrupts

	;----------------------------------------------------
	; Save values from MBR to variables
	;----------------------------------------------------

			mov [drive_num], dl
			mov es, bx
			mov di, cx
			mov eax, [es:di+8]
%ifdef BOCHS
			xor eax, eax		; in BOCHS
%endif
			mov [partition_lba_begin], eax

	;----------------------------------------------------
	; Init FAT32-related variables
	;----------------------------------------------------

			; calc fat_begin_lba and cluster_begin_lba
			mov ecx, [partition_lba_begin]
			movzx ebx, WORD [bpbReservedSectors]
			add ecx, ebx
			mov [fat_begin_lba], ecx
			movzx eax, BYTE [bpbNumberOfFATs]
			mov ebx, [bpbSectorsPerFAT]
			mul ebx
			add ecx, eax
			mov [cluster_begin_lba], ecx
				; root_dir_lba
			mov ebx, [bpbRootDirCluster]
			call Cluster2LBA
			mov [root_dir_lba], eax
				; dir_entries_per_cluster_num
%ifndef DEBUG
			movzx eax, BYTE [bpbSectorsPerCluster]
			shl	eax, 4										; *16, (512/32=16 (number of dir-entries per sector))
			mov [dir_entries_per_cluster_num], eax
%endif
	;----------------------------------------------------
	; Load  file
	;----------------------------------------------------
			mov ax, FILE_BUFF_SEG
			mov es, ax
			mov di, 0
			call ReadFile
			cmp bp, 1
			je	.Loader
%ifdef DEBUG
			mov BYTE [gs:80*24*2+2], 'F'
%endif
			jmp $						; Failed
			; pass on the values to loader
.Loader		mov dl, [drive_num]
			mov ebx, [partition_lba_begin]
%ifdef DEBUG
			mov BYTE [gs:80*24*2], '3'
%endif

			jmp FILE_BUFF_SEG:0



;************************************************
; Reads a series of sectors
; IN: 	EAX (Starting sector)
;		CX (Number of sectors to read)
;		BX:DI (Buffer to read to)
;************************************************
ReadSectors:
			pusha
;			mov dh, 0x0005				; max. 5 retries
.Again		mov dl, [drive_num]
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
;			dec dh			; BIOS overwrites!? it was bp
;			jnz	.Again
%ifdef DEBUG
			mov BYTE [gs:80*24*2+2], 'R'
%endif
			jmp $
;			int 0x18
.Ok			popa
			ret


; IN: ES:DI(memaddr)
; OUT: BP=1 if success;		file_size(size of file in bytes)
ReadFile:
			mov bp, 0
			mov [memaddr_seg], es
			mov [memaddr_offs], di
			; read root directory
;			mov eax, [bpbRootDirCluster]
;			mov [cluster_num], eax
			mov eax, [root_dir_lba]
;			and eax, 0x0FFFFFFF								; upper 4 bits of a cluster-number are reserved
.Read		movzx cx, BYTE [bpbSectorsPerCluster]
			mov bx, FILE_BUFF_SEG							; we read the directory-cluster to FILE_BUFF too
			mov di, 0
			call ReadSectors
			mov ax, FILE_BUFF_SEG
			mov es, ax
			mov di, 0					; also
.GetEntry	cmp BYTE [es:di], 0								; end of dir-entries?
			jz	.Back
			; compare strings, if not found ==> Inc	; (LODR    .SYS)
			cmp DWORD [es:di], 'LODR'
			jnz	.Inc
			cmp WORD [es:di+8], 'SY'
			jnz	.Inc
%ifdef DEBUG
			mov BYTE [gs:80*24*2], '2'
%endif
			mov bx, [es:di+SFN_CLUSTER_HI]
			shl	ebx, 16
			mov bx, [es:di+SFN_CLUSTER_LO]
			and ebx, 0x0FFFFFFF								; upper 4 bits of a cluster-number are reserved
			; read file from its cluster
				; read cluster, then from FAT the next ones
.NextClus	mov [cluster_num], ebx
			call Cluster2LBA		; fills EAX
			movzx cx, BYTE [bpbSectorsPerCluster]
			mov bx, [memaddr_seg]
			mov di, [memaddr_offs]
			call ReadSectors
			mov bl, [bpbSectorsPerCluster]
			shl bx, 9		; *512	; bpbBytesPerSector is always 512 !?
;64 sectorspercluster!?
;64*512=0x8000 ok
			add [memaddr_offs], bx							; hdfat3216_incmemaddr!?
			call GetNextCluster		; ES, DS
			cmp ebx, END_OF_CLUSTER_MARKER
			jnc	.Ok
			jmp .NextClus
.Inc		add di, DIR_ENTRY_LEN	
%ifndef DEBUG
			xor ebx, ebx
			mov bx, di
			shr	ebx, 5										; /32
			cmp ebx, [dir_entries_per_cluster_num]
			jnz	.GetEntry
		jmp .Back		; we read only the first cluster of the directory
%endif
%ifdef DEBUG
		jmp .GetEntry
%endif
;			call GetNextCluster		; ES, DS
;			cmp ebx, END_OF_CLUSTER_MARKER
;			jnc	.Back
;			mov [cluster_num], ebx
;			call Cluster2LBA
;			jmp .Read
.Ok			mov bp, 1
.Back		ret


; IN:
; OUT: EBX(clusternum)
GetNextCluster:
			mov eax, [cluster_num]
			mov esi, eax
			and esi, 0x007F									; lower 7 bits is the offset within the sector
			shl esi, 2										; the offset is in dwords
			shr eax, 7										; EBX: sectornumber in FAT
			add eax, [fat_begin_lba]
			; read 1 sector from FAT
			mov cx, 1
			mov bx, SECTOR_BUFF_SEG
			mov di, 0
			call ReadSectors
			mov ax, SECTOR_BUFF_SEG
			mov es, ax
			mov di, si
			mov ebx, [es:di]
			and ebx, 0x0FFFFFFF								; upper 4 bits of a cluster-number are reserved
			ret


; IN: EBX(clusternum)
; OUT: EAX
Cluster2LBA:
			sub ebx, 2
			movzx eax, BYTE [bpbSectorsPerCluster]
			mul ebx
			add eax, [cluster_begin_lba]
			ret


;txt times 50 db 0	; to see how many bytes left from 512

times 510-($-$$) db 0
dw 0xAA55


data_area:


