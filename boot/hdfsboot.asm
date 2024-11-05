
;*********************************************
;	hdboot.asm
;		A Simple Bootloader (Volume Boot Record, VBR)
;		Loads the kernel-loader from Fat32
;
;	A one-sector VBR Fat32-bootloader needs to be simplified 
;	(only checks ShortFilename-entries, file needs to be in the first cluster) 
;	in order to fit into 512-bytes.
;
;	Modified FAT32: the Dir-entry is different! (see fat32.asm)
;*********************************************

bits 16

org	0	

;%define DEBUG

;%define BOCHS

HDBOOT_FILE_BUFF_SEG			equ	0x0900
HDBOOT_SECTOR_BUFF_SEG			equ	0x0810

HDBOOT_END_OF_CLUSTER_MARKER	equ 0xFFFFFFFF
HDBOOT_DELETED_ENTRY			equ	0xE5

HDBOOT_DIR_ENTRY_LEN	equ 32	; bytes

; Dir-Entry (DE)
HDBOOT_DE_NAME_LEN	equ	0	; 17 bytes (1st byte is length)
HDBOOT_DE_ATTRIB	equ	17	; 1 byte
HDBOOT_DE_DATE_CR	equ	18	; 2 bytes
HDBOOT_DE_LAST_ACC	equ	20	; 2 bytes
HDBOOT_DE_DATE_WR	equ	22	; 2 bytes
HDBOOT_DE_CLUS_NUM	equ	24	; 4 bytes
HDBOOT_DE_FILE_SIZE	equ	28	; 4 bytes

; Attribs
%define FAT32_ATTR_READONLY		1
%define FAT32_ATTR_HIDDEN		2
%define FAT32_ATTR_SYSTEM		4
%define FAT32_ATTR_VOLUMEID		8
%define FAT32_ATTR_DIRECTORY	16
%define FAT32_ATTR_ARCHIVE		32

; dataarea
hdboot_drive_num					equ	hdboot_data_area+0
hdboot_partition_lba_begin			equ	hdboot_data_area+1
;	hdboot_fat_begin_lba(DWORD)			= Partition_LBA_begin + Number_Of_Reserved_Sectors
;	hdboot_cluster_begin_lba(DWORD)		= Partition_LBA_begin + Number_Of_Reserved_Sectors + (Number_Of_FATs * Sectors_Per_FAT)
;	hdboot_sectors_per_cluster(BYTE)		= Sectors Per Cluster
;	hdboot_root_dir_first_cluster(DWORD)	= Root Dir First Cluster
hdboot_fat_begin_lba				equ	hdboot_data_area+5
hdboot_cluster_begin_lba			equ	hdboot_data_area+9
hdboot_root_dir_lba					equ	hdboot_data_area+13
hdboot_dir_entries_per_cluster_num	equ	hdboot_data_area+17
hdboot_cluster_num					equ	hdboot_data_area+21
hdboot_file_size					equ	hdboot_data_area+25		; NOT USED
hdboot_memaddr_seg					equ	hdboot_data_area+29
hdboot_memaddr_offs					equ	hdboot_data_area+31
hdboot_buff							equ	hdboot_data_area+33


start:	jmp	main

;*********************************************
;	BIOS Parameter Block	(from the first sector of the partition (Volume Boot Record, VBR))
;*********************************************

; BPB Begins 3 bytes from start. We do a far jump, which is 3 bytes in size.
; If you use a short jump, add a "nop" after it to offset the 3rd byte.
; IN ORDER TO BE A FAR JUMP PUT THE FUNCTIONS BEFORE MAIN !!!!
nop	; !!!!!

hdboot_bpbOEM					db "GFOS    "		; 0 (8 chars)
hdboot_bpbBytesPerSector		dw 0x0200			; 8
hdboot_bpbSectorsPerCluster		db 0x20				; 10		; FILLED by FSFORMAT
hdboot_bpbReservedSectors		dw 0x0010			; 11
hdboot_bpbNumberOfFATs			db 0x01				; 13
hdboot_bpbRootEntries			dw 0x0000			; 14
hdboot_bpbTotalSectors			dw 0x0000			; 16
hdboot_bpbMedia					db 0xF8				; 18
hdboot_bpbSectorsPerFATW		dw 0x0000			; 19
hdboot_bpbSectorsPerTrack		dw 0x0000			; 21
hdboot_bpbHeadsPerCylinder		dw 0x0000			; 23
hdboot_bpbHiddenSectors			dd 0x00000020		; 25
hdboot_bpbLargeTotalSectors		dd 0x1D1C5970		; 29		; FILLED by FSFORMAT
hdboot_bpbSectorsPerFAT			dd 0x0001D1A8		; 33		; FILLED by FSFORMAT
hdboot_bpbMirroringFlags		dw 0x0000			; 37
hdboot_bpbVersion				dw 0x0000			; 39
hdboot_bpbRootDirCluster		dd 0x00000002		; 41
hdboot_bpbLocationFSInfSector	dw 0x0001			; 45
hdboot_bpbLocationBackupSector	dw 0x0006			; 47
hdboot_bpbReservedBootFName		times 12 db 0x00	; 49
hdboot_bpbPhysDriveNum			db 0x80				; 61
hdboot_bpbFlags					db 0x01				; 62
hdboot_bpbExtendedBootSig		db 0x29				; 63
hdboot_bpbVolumeSerialNum		dd 0x762e0af2		; 64
; DOS 7.1 Extended BPB (79 bytes, without bpbOEM)
hdboot_bpbVolumeLabel			db "DISK       "	; 11 chars	; 68
hdboot_bpbFSType				db "FAT32   "		; 8 chars	; 79

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

			mov [hdboot_drive_num], dl
			mov es, bx
			mov di, cx
			mov eax, [es:di+8]
%ifdef BOCHS
			xor eax, eax		; in BOCHS
%endif
			mov [hdboot_partition_lba_begin], eax

	;----------------------------------------------------
	; Init FAT32-related variables
	;----------------------------------------------------

			; calc fat_begin_lba and cluster_begin_lba
			mov ecx, [hdboot_partition_lba_begin]
			movzx ebx, WORD [hdboot_bpbReservedSectors]
			add ecx, ebx
			mov [hdboot_fat_begin_lba], ecx
			movzx eax, BYTE [hdboot_bpbNumberOfFATs]
			mov ebx, [hdboot_bpbSectorsPerFAT]
			mul ebx
			add ecx, eax
			mov [hdboot_cluster_begin_lba], ecx
				; root_dir_lba
			mov ebx, [hdboot_bpbRootDirCluster]
			call hdboot_cluster2LBA
			mov [hdboot_root_dir_lba], eax
				; dir_entries_per_cluster_num
%ifndef DEBUG
			movzx eax, BYTE [hdboot_bpbSectorsPerCluster]
			shl	eax, 4										; *16, (512/32=16 (number of dir-entries per sector))
			mov [hdboot_dir_entries_per_cluster_num], eax
%endif
	;----------------------------------------------------
	; Load  file
	;----------------------------------------------------
			mov ax, HDBOOT_FILE_BUFF_SEG
			mov es, ax
			mov di, 0
			call hdboot_readfile
			cmp bp, 1
			je	.Loader
%ifdef DEBUG
			mov BYTE [gs:80*24*2+2], 'F'
%endif
			jmp $						; Failed
			; pass on the values to loader
.Loader		mov dl, [hdboot_drive_num]
			mov ebx, [hdboot_partition_lba_begin]
%ifdef DEBUG
			mov BYTE [gs:80*24*2], '3'
%endif

			jmp HDBOOT_FILE_BUFF_SEG:0



;************************************************
; Reads a series of sectors
; IN: 	EAX (Starting sector)
;		CX (Number of sectors to read)
;		BX:DI (Buffer to read to)
;************************************************
hdboot_readsectors:
			pusha
;			mov dh, 0x0005				; max. 5 retries
.Again		mov dl, [hdboot_drive_num]
			mov BYTE [hdboot_buff], 0x10		; size of this structure (1 byte)
			mov BYTE [hdboot_buff+1], 0		; always zero (1 byte)
			mov WORD [hdboot_buff+2], cx		; number of sectors to read (2 bytes)
			mov WORD [hdboot_buff+4], di		; segment:offset ptr to memory to read to (4 bytes) 
			mov WORD [hdboot_buff+6], bx 
			mov DWORD [hdboot_buff+8], eax		; read from sector (8 bytes)
			mov DWORD [hdboot_buff+12], 0 
			mov ah, 0x42
			mov si, hdboot_buff 
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
hdboot_readfile:
			mov bp, 0
			mov [hdboot_memaddr_seg], es
			mov [hdboot_memaddr_offs], di
			; read root directory
;			mov eax, [hdboot_bpbRootDirCluster]
;			mov [hdboot_cluster_num], eax
			mov eax, [hdboot_root_dir_lba]
;			and eax, 0x0FFFFFFF								; upper 4 bits of a cluster-number are reserved
.Read		movzx cx, BYTE [hdboot_bpbSectorsPerCluster]
			mov bx, HDBOOT_FILE_BUFF_SEG					; we read the directory-cluster to FILE_BUFF too
			mov di, 0
			call hdboot_readsectors
			mov ax, HDBOOT_FILE_BUFF_SEG
			mov es, ax
			mov di, 0					; also
.GetEntry	cmp BYTE [es:di], 0								; end of dir-entries?
			jz	.Back
			; compare strings, if not found ==> Inc	; (LODR.SYS)
			cmp BYTE [es:di+HDBOOT_DE_NAME_LEN], 8						; first byte is size
			jnz	.Inc		
			cmp DWORD [es:di+HDBOOT_DE_NAME_LEN+1], 'LODR'
			jnz	.Inc
			cmp DWORD [es:di+HDBOOT_DE_NAME_LEN+1+4], '.SYS'
			jnz	.Inc
%ifdef DEBUG
			mov BYTE [gs:80*24*2], '2'
%endif
			mov ebx, [es:di+HDBOOT_DE_CLUS_NUM]
			; read file from its cluster
				; read cluster, then from FAT the next ones
.NextClus	mov [hdboot_cluster_num], ebx
			call hdboot_cluster2LBA		; fills EAX
			movzx cx, BYTE [hdboot_bpbSectorsPerCluster]
			mov bx, [hdboot_memaddr_seg]
			mov di, [hdboot_memaddr_offs]
			call hdboot_readsectors
			mov bl, [hdboot_bpbSectorsPerCluster]
			shl bx, 9		; *512	; hdboot_bpbBytesPerSector is always 512 !?
			add [hdboot_memaddr_offs], bx
			call hdboot_getnextcluster		; ES, DS
			cmp ebx, HDBOOT_END_OF_CLUSTER_MARKER
			jnc	.Ok
			jmp .NextClus
.Inc		add di, HDBOOT_DIR_ENTRY_LEN	
%ifndef DEBUG
			xor ebx, ebx
			mov bx, di
			shr	ebx, 5										; /32
			cmp ebx, [hdboot_dir_entries_per_cluster_num]
			jnz	.GetEntry
		jmp .Back		; we read only the first cluster of the directory
%endif
%ifdef DEBUG
		jmp .GetEntry
%endif
;			call hdboot_getnextcluster		; ES, DS
;			cmp ebx, HDBOOT_END_OF_CLUSTER_MARKER
;			jnc	.Back
;			mov [hdboot_cluster_num], ebx
;			call hdboot_cluster2LBA
;			jmp .Read
.Ok			mov bp, 1
.Back		ret


; IN:	hdboot_cluster_num, hdboot_fat_begin_lba
; OUT: EBX(clusternum)
hdboot_getnextcluster:
			mov eax, [hdboot_cluster_num]
			mov esi, eax
			and esi, 0x007F									; lower 7 bits is the offset within the sector
			shl esi, 2										; the offset is in dwords
			shr eax, 7										; EBX: sectornumber in FAT
			add eax, [hdboot_fat_begin_lba]
			; read 1 sector from FAT
			mov cx, 1
			mov bx, HDBOOT_SECTOR_BUFF_SEG
			mov di, 0
			call hdboot_readsectors
			mov ax, HDBOOT_SECTOR_BUFF_SEG
			mov es, ax
			mov di, si
			mov ebx, [es:di]
			ret


; IN: EBX(clusternum)
; OUT: EAX
hdboot_cluster2LBA:
			sub ebx, 2
			movzx eax, BYTE [hdboot_bpbSectorsPerCluster]
			mul ebx
			add eax, [hdboot_cluster_begin_lba]
			ret


;txt times 50 db 0	; to see how many bytes left from 512

times 510-($-$$) db 0
dw 0xAA55


hdboot_data_area:


