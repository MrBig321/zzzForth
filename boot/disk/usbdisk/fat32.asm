
;*********************************************
;	fat32.asm
;		In real mode reads a file from FAT32
;		only checks ShortName-entries, so 
;		filename must be 8.3
;*********************************************

%ifndef __FAT32__
%define __FAT32__


bits 16

;%define FAT32_DBG_LOAD

%ifdef FAT32_DBG_LOAD
	%include "util16.asm"
	%include "stdio16.asm"
%endif

; copied from boot.asm	(USB-pendrive's or Bochs')
;*********************************************
;	BIOS Parameter Block
;*********************************************
;fat32_bpbOEM					db "mkfs.fat"		; 8 chars
fat32_bpbBytesPerSector			dw 0x0200			; 8
fat32_bpbSectorsPerCluster		db 0x08				; 10
fat32_bpbReservedSectors		dw 0x0020			; 11
fat32_bpbNumberOfFATs			db 0x02				; 13
;fat32_bpbRootEntries			dw 0x0000			; 14
;fat32_bpbTotalSectors			dw 0x0000			; 16
;fat32_bpbMedia					db 0xF8				; 18
;fat32_bpbSectorsPerFAT16		dw 0x0000			; 19
;fat32_bpbSectorsPerTrack		dw 0x003E			; 21
;fat32_bpbHeadsPerCylinder		dw 0x007C			; 23
;fat32_bpbHiddenSectors			dd 0x00000800		; 25
;fat32_bpbLargeTotalSectors		dd 0x0077F800		; 29
fat32_bpbSectorsPerFat			dd 0x00001DF0		; 33
;fat32_bpbMirroringFlags		dw 0x0000			; 37
;fat32_bpbVersion				dw 0x0000			; 39
fat32_bpbRootDirCluster			dd 0x00000002		; 41
;fat32_bpbLocationFSInfSector	dw 0x0001			; 45
;fat32_bpbLocationBackupSector	dw 0x0006			; 47
;fat32_bpbReservedBootFName	times 12 db 0x00	; 49
;fat32_bpbPhysDriveNum			db 0x80				; 61
;fat32_bpbFlags					db 0x01				; 62
;fat32_bpbExtendedBootSig		db 0x29				; 63
;fat32_bpbVolumeSerialNum		dd 0x762e0af2		; 64
;; DOS 7.1 Extended BPB (79 bytes, without bpbOEM)
;fat32_bpbVolumeLabel			db "DISK4G     "	; 11 chars	; 68
;fat32_bpbFSType				db "FAT32   "		; 8 chars	; 79

fat32_curr_sector_num	dd -1


; IN: DL(drivenumber), EAX(LBABegin)
fat32_init:
			mov [fat32_drivenum], dl
			mov [fat32_partition_lba_begin], eax

			mov DWORD [fat32_curr_sector_num], -1

			; calc fat_begin_lba and cluster_begin_lba
			mov ecx, [fat32_partition_lba_begin]
			movzx ebx, WORD [fat32_bpbReservedSectors]
			add ecx, ebx
			mov [fat32_fat_begin_lba], ecx
;			xor eax, eax
			movzx eax, BYTE [fat32_bpbNumberOfFATs]
			mov ebx, [fat32_bpbSectorsPerFat]
			mul ebx
			add ecx, eax
			mov [fat32_cluster_begin_lba], ecx
				; root_dir_lba
			mov ebx, [fat32_bpbRootDirCluster]
			call fat32_cluster2lba
			mov [fat32_root_dir_lba], eax
				; dir_entries_per_cluster_num
			movzx eax, BYTE [fat32_bpbSectorsPerCluster]
			shl	eax, 4										; *16, (512/32=16 (number of dir-entries per sector))
			mov [fat32_dir_entries_per_cluster_num], eax

			ret


; IN: BX(filename), ES:DI(memaddr)
; OUT: ECX(size of file in bytes)
fat32_readfile:
			mov DWORD [fat32_curr_sector_num], -1
			mov DWORD [fat32_filesize], 0
			mov [fat32_memaddr_seg], es
			mov [fat32_memaddr_offs], di
			push ds
			pop es
			; copy filename
			mov ecx, 11			; !?
			mov si, bx
			mov di, fat32_fname
			rep movsb
			; read root directory
			mov eax, [fat32_bpbRootDirCluster]
			mov [fat32_cluster_num], eax
			mov eax, [fat32_root_dir_lba]
;			and eax, FAT32_CLUSTER_NUM_MASK
.Read		movzx cx, BYTE [fat32_bpbSectorsPerCluster]
			mov bx, [fat32_memaddr_seg]						; we read the directory-cluster to FILE_BUFF too
			mov di, [fat32_memaddr_offs]
			call fat32_readsectors
%ifdef FAT32_DBG_LOAD
		pusha
		push es
		call stdio16_new_line
		mov ax, [fat32_memaddr_seg]	
		mov es, ax
		mov di, [fat32_memaddr_offs]
;		mov cx, 32
		mov cx, 16
		call util16_mem_dump
		call stdio16_new_line
;		call util16_wait_key
		pop es
		popa
%endif
			mov ax, [fat32_memaddr_seg]					; we read the directory-cluster to FILE_BUFF too
			mov es, ax
			mov di, [fat32_memaddr_offs]
.GetEntry	cmp BYTE [es:di], 0								; end of dir-entries?
			jz	.Back
			cmp BYTE [es:di], FAT32_DELETED_ENTRY
			jz	.Inc
			; check entry
			cmp BYTE [es:di+FAT32_SFN_ATTRIB], FAT32_LFN_MASK
			jz	.Inc										; skip long FileName
			xor ax, ax
			mov al, [es:di+FAT32_SFN_ATTRIB]
			bt	ax, FAT32_ATTRIB_DIRECTORY						; is it a directory?
			jc	.Inc
%ifdef FAT32_DBG_LOAD
		pusha
		call stdio16_new_line
		mov si, fat32_fname
		mov cx, 11
		call stdio16_put_chs	; DS:SI chars, CX number
		mov al, 32				; space
		call stdio16_put_ch
		push ds
		push es
		pop ds
		mov si, di	
		mov cx, 11
		call stdio16_put_chs
		pop ds
		call util16_wait_key
		call stdio16_new_line
		popa
%endif
			; compare strings, if not found ==> Inc
			mov cx, 11										; max. length of Short File Name
			mov si, fat32_fname
			call fat32_strcmp		; AX, CX
			cmp ax, 0
			jnz	.Inc
			xor ebx, ebx
			mov bx, [es:di+FAT32_SFN_CLUSTER_HI]
			shl	ebx, 16
			mov bx, [es:di+FAT32_SFN_CLUSTER_LO]
			and ebx, FAT32_CLUSTER_NUM_MASK
			mov eax, [es:di+FAT32_SFN_FILESIZE]
			mov [fat32_filesize], eax
			; Note: we don't check here if the size of the file is zero (clusternum=0; filesize=0)
			; read file from its cluster
				; read cluster, then from FAT the next ones
.NextClus	mov [fat32_cluster_num], ebx
			call fat32_cluster2lba		; fills EAX
			movzx cx, BYTE [fat32_bpbSectorsPerCluster]
			mov bx, [fat32_memaddr_seg]
			mov di, [fat32_memaddr_offs]
			call fat32_readsectors
			mov	ax, [fat32_bpbBytesPerSector]	
			movzx bx, BYTE [fat32_bpbSectorsPerCluster]
			mul bx
			call fat32_incmemaddr
			call fat32_get_next_cluster		; ES, DS
			cmp ebx, FAT32_END_OF_CLUSTER_MARKER
			jnc	.Back
			jmp .NextClus
.Inc		add di, FAT32_DIR_ENTRY_LEN	
			xor ebx, ebx
			mov bx, di
			shr	ebx, 5										; /32
			cmp ebx, [fat32_dir_entries_per_cluster_num]
			jnz	.GetEntry
			call fat32_get_next_cluster		; ES, DS
			cmp ebx, FAT32_END_OF_CLUSTER_MARKER
			jnc	.Back
			mov [fat32_cluster_num], ebx
			call fat32_cluster2lba
			jmp .Read
.Back		mov ecx, [fat32_filesize]
			ret


; IN: AX(value)
;	handles overflow (segment:offset)
;	add offset to segment to avoid overflow (segment*16+offset and zero to offset) 
;	Example(overflow): 
;		07E0:F000 + 10F3 (i.e. AX=10F3)
;		7E00+F000 = 16E00
;		16E00+10F3 = 17EF3
;		17EF:0003 !?
fat32_incmemaddr:
			pushad
			movzx ebx, WORD [fat32_memaddr_seg]
			mov di, [fat32_memaddr_offs]
			add di, ax
			mov dx, [fat32_memaddr_offs]
			mov cx, 0xFFFF
			sub cx, dx
			inc cx
			cmp ax, cx
			jc	.Ok									; jump if unsigned less
			; overflow
			movzx edi, WORD [fat32_memaddr_offs]
			shl	ebx, 4	
			add ebx, edi
			mov edi, ebx
			and edi, 0x0000000F
			add di, ax
			shr ebx, 4
.Ok			mov [fat32_memaddr_seg], bx
			mov [fat32_memaddr_offs], di
			popad
			ret


; IN: EBX(clusternum)
; OUT: EAX
fat32_cluster2lba:
			push ebx
			push edx
			sub ebx, 2
			xor eax, eax
			mov al, [fat32_bpbSectorsPerCluster]
			mul ebx
			add eax, [fat32_cluster_begin_lba]
			pop edx
			pop ebx
			ret


; IN:
; OUT: EBX(clusternum)
fat32_get_next_cluster:
			mov eax, [fat32_cluster_num]
			mov esi, eax
			and esi, FAT32_OFFSET_WITHIN_SECTOR_MASK		; lower 7 bits is the offset within the sector
			shl esi, 2										; the offset is in dwords
			shr eax, 7										; EAX: sectornumber in FAT
			cmp eax, [fat32_curr_sector_num]				; Sector already in memory? If yes don't read.
			je	.Check
			mov [fat32_curr_sector_num], eax
			add eax, [fat32_fat_begin_lba]
			; read 1 sector from FAT
			mov cx, 1
			mov bx, FAT32_SECTOR_BUFF_SEG
			mov di, 0
			call fat32_readsectors
.Check		mov ax, FAT32_SECTOR_BUFF_SEG
			mov es, ax
			mov di, si
			mov ebx, [es:di]
			and ebx, FAT32_CLUSTER_NUM_MASK
			ret


;************************************************
; Reads a series of sectors
; IN: 	EAX (Starting sector)
;		CX (Number of sectors to read)
;		BX:DI (Buffer to read to)
;************************************************
fat32_readsectors:
			pusha
			mov bp, 0x0005						; max. 5 retries
.Again		mov dl, [fat32_drivenum]
			mov BYTE [fat32_buff], 0x10			; size of this structure (1 byte)
			mov BYTE [fat32_buff+1], 0			; always zero (1 byte)
			mov WORD [fat32_buff+2], cx			; number of sectors to read (2 bytes)
			mov WORD [fat32_buff+4], di			; segment:offset ptr to memory to read to (4 bytes) 
			mov WORD [fat32_buff+6], bx 
			mov DWORD [fat32_buff+8], eax		; read from sector (8 bytes)
			mov DWORD [fat32_buff+12], 0 
			mov ah, 0x42
			mov si, fat32_buff 
			int 0x13
			jnc	.Ok
			dec bp
			jnz	.Again
			mov si, fat32_msgErrReadSector
			call fat32_print
		jmp $
			int 0x18
.Ok			mov si, fat32_msgProgress
 			call fat32_print
			popa
			ret


;*************************************************;
; strcmp  (case sensitive) 
;	DS:SI: addr of string1; In
;	ES:DI: addr of string2; In
;	CX: length; In
;	AX: <0 if s1 < s2; 0 if s1 == s2; >0 if s1 > s2 ; Out
;	skips chars in DS:SI that are > 126 ( greater then ASCII of '~' )
;*************************************************;
fat32_strcmp:
			push bx
			push dx
			xor ax, ax
			xor bx, bx
.Next		mov al, BYTE [ds:si+bx]
			mov al, BYTE [es:di+bx]
			mov al, BYTE [ds:si+bx]
			mov dl, BYTE [es:di+bx]
			cmp al, dl
			jnz	.Sub
.Inc		inc bx
			cmp bx, cx
			je	.Sub
			jmp .Next
.Sub		sub al, dl
.Back		pop dx
			pop bx
			ret


; IN: DS:SI (0 terminated string)
fat32_print:
			pusha
.Next		lodsb				; load next byte from string from SI to AL
			or	al, al			; Does AL=0?
			jz .Back			; Yep, null terminator found-bail out
			mov	ah, 0x0E		; Nope-Print the character
			int	0x10
			jmp	.Next			; Repeat until null terminator found
.Back		popa
			ret					; we are done, so return


FAT32_SECTOR_BUFF_SEG			equ	0x0810
FAT32_CLUSTER_NUM_MASK			equ	0x0FFFFFFF			; upper 4 bits of a cluster-number are reserved
FAT32_OFFSET_WITHIN_SECTOR_MASK	equ	0x0000007F			; lower 7 bits is the offset within sector in the FAT
FAT32_END_OF_CLUSTER_MARKER		equ 0x0FFFFFF8			; I always got 0x0FFFFFFF (before clearing the topmost 4 bits) from FAT
FAT32_DELETED_ENTRY				equ	0xE5
FAT32_LFN_MASK					equ	0x0F

FAT32_DIR_ENTRY_LEN	equ 32	; bytes

; Short Filename-entry (SFN)
FAT32_SFN_NAME			equ	0
FAT32_SFN_ATTRIB		equ	11
FAT32_SFN_TIME10		equ	13
FAT32_SFN_TIME			equ	14
FAT32_SFN_DATE			equ	16	; Create
FAT32_SFN_LA_DATE		equ 18	; Last access
FAT32_SFN_CLUSTER_HI	equ 20
FAT32_SFN_LA_MOD_TIM	equ 22
FAT32_SFN_LA_MOD_DAT	equ 24	; Last Modify
FAT32_SFN_CLUSTER_LO	equ 26
FAT32_SFN_FILESIZE		equ 28

; Attribs
FAT32_ATTRIB_READONLY	equ	0	; bit0
FAT32_ATTRIB_HIDDEN		equ	1
FAT32_ATTRIB_SYSTEM		equ	2
FAT32_ATTRIB_VOLUMEID	equ	3
FAT32_ATTRIB_DIRECTORY	equ	4
FAT32_ATTRIB_ARCHIVE	equ	5

fat32_drivenum				db 0		; the drive we booted from
fat32_partition_lba_begin	dd 0

;	fat_begin_lba(DWORD)			= Partition_LBA_begin + Number_Of_Reserved_Sectors
;	cluster_begin_lba(DWORD)		= Partition_LBA_begin + Number_Of_Reserved_Sectors + (Number_Of_FATs * Sectors_Per_FAT)
;	sectors_per_cluster(BYTE)		= Sectors Per Cluster
;	root_dir_first_cluster(DWORD)	= Root Dir First Cluster
fat32_fat_begin_lba			dd 0
fat32_cluster_begin_lba		dd 0
fat32_root_dir_lba			dd 0
;lba_addr = cluster_begin_lba + (cluster_number - 2) * sectors_per_clusters (See usbfat32.asm for more details)
fat32_dir_entries_per_cluster_num	dd	0

fat32_cluster_num		dd 0

fat32_fname			times 11 db 0
fat32_filesize		dd 0
fat32_memaddr_seg	dw 0
fat32_memaddr_offs	dw 0

fat32_buff 	times 16 db 0

fat32_msgProgress		db ".", 0
fat32_msgErrReadSector	db "Error reading sector", 0x0D, 0x0A, 0


%endif

