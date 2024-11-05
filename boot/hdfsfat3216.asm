
;*********************************************
;	hdfat32.asm
;		In real mode reads a file from FAT32
;
;	Modified FAT32: the Dir-entry is different! (see fat32.asm)
;*********************************************

%ifndef __HDFAT3216__
%define __HDFAT3216__


bits 16

;%define HDFAT3216_DBG_LOAD

%ifdef HDFAT3216_DBG_LOAD
	%include "util16.asm"
	%include "stdio16.asm"
%endif

; BPB from: 0x7C00 +3 (BOOT-sector was loaded to 0x7C00)
HDFAT3216_BPB_LOC					equ 0x7C03
HDFAT3216_BPBBYTESPERSECTOR_LOC		equ (HDFAT3216_BPB_LOC+8)	;dw
HDFAT3216_BPBSECTORSPERCLUSTER_LOC	equ (HDFAT3216_BPB_LOC+10)	;db
HDFAT3216_BPBRESERVEDSECTORS_LOC	equ (HDFAT3216_BPB_LOC+11)	;dw
HDFAT3216_BPBNUMBEROFFATS_LOC		equ (HDFAT3216_BPB_LOC+13)	;db
HDFAT3216_BPBSECTORSPERFAT_LOC		equ (HDFAT3216_BPB_LOC+33)	;dd
HDFAT3216_BPBROOTDIRCLUSTER_LOC		equ (HDFAT3216_BPB_LOC+41)	;dd

HDFAT3216_SECTOR_BUFF_SEG			equ	0x0810
HDFAT3216_OFFSET_WITHIN_SECTOR_MASK	equ	0x0000007F			; lower 7 bits is the offset within sector in the FAT
HDFAT3216_END_OF_CLUSTER_MARKER		equ 0xFFFFFFFF
HDFAT3216_DELETED_ENTRY				equ	0xE5

HDFAT3216_DIR_ENTRY_LEN	equ 32	; bytes

; Dir-Entry (DE)
HDFAT3216_DE_NAME		equ	0	; 17 bytes (1st byte is length)
HDFAT3216_DE_ATTRIB		equ	17	; 1 byte
HDFAT3216_DE_DATE_CR	equ	18	; 2 bytes
HDFAT3216_DE_LAST_ACC	equ	20	; 2 bytes
HDFAT3216_DE_DATE_WR	equ	22	; 2 bytes
HDFAT3216_DE_CLUS_NUM	equ	24	; 4 bytes
HDFAT3216_DE_FILE_SIZE	equ	28	; 4 bytes

; Attribs
%define HDFAT3216_ATTR_READONLY		1
%define HDFAT3216_ATTR_HIDDEN		2
%define HDFAT3216_ATTR_SYSTEM		4
%define HDFAT3216_ATTR_VOLUMEID		8
%define HDFAT3216_ATTR_DIRECTORY	16
%define HDFAT3216_ATTR_ARCHIVE		32

section .text

; IN: DL(drivenumber), EAX(LBABegin)
hdfat3216_init:
			mov [hdfat3216_drivenum], dl
			mov [hdfat3216_partition_lba_begin], eax

			; copy data from BPB
			xor ebx, ebx
			mov	es, bx
			mov bx, [es:HDFAT3216_BPBBYTESPERSECTOR_LOC]
			mov [hdfat3216_bpbBytesPerSector], bx
			mov bl, [es:HDFAT3216_BPBSECTORSPERCLUSTER_LOC]
			mov [hdfat3216_bpbSectorsPerCluster], bl
			mov bx, [es:HDFAT3216_BPBRESERVEDSECTORS_LOC]
			mov [hdfat3216_bpbReservedSectors], bx
			mov bl, [es:HDFAT3216_BPBNUMBEROFFATS_LOC]
			mov [hdfat3216_bpbNumberOfFATs], bl
			mov ebx, [es:HDFAT3216_BPBSECTORSPERFAT_LOC]
			mov [hdfat3216_bpbSectorsPerFAT], ebx
			mov ebx, [es:HDFAT3216_BPBROOTDIRCLUSTER_LOC]
			mov [hdfat3216_bpbRootDirCluster], ebx
%ifdef HDFAT3216_DBG_LOAD
		pusha
		call stdio16_new_line
		mov ax, [hdfat3216_bpbBytesPerSector]
		call stdio16_put_dec
		call stdio16_new_line
		xor ax, ax
		mov al, [hdfat3216_bpbSectorsPerCluster]
		call stdio16_put_dec
		call stdio16_new_line
		mov ax, [hdfat3216_bpbReservedSectors]
		call stdio16_put_dec
		call stdio16_new_line
		xor ax, ax
		mov al, [hdfat3216_bpbNumberOfFATs]
		call stdio16_put_dec
		call stdio16_new_line
		mov edx, [hdfat3216_bpbSectorsPerFAT]
		call stdio16_put_hex32
		call stdio16_put_h
		call stdio16_new_line
		mov edx, [hdfat3216_bpbRootDirCluster]
		call stdio16_put_hex32
		call stdio16_put_h
		call stdio16_new_line
		popa
		call util16_wait_key
%endif

			mov DWORD [hdfat3216_curr_sector_num], -1

			; calc fat_begin_lba and cluster_begin_lba
			mov ecx, [hdfat3216_partition_lba_begin]
			movzx ebx, WORD [hdfat3216_bpbReservedSectors]
			add ecx, ebx
			mov [hdfat3216_fat_begin_lba], ecx
;			xor eax, eax
			movzx eax, BYTE [hdfat3216_bpbNumberOfFATs]
			mov ebx, [hdfat3216_bpbSectorsPerFAT]
			mul ebx
			add ecx, eax
			mov [hdfat3216_cluster_begin_lba], ecx
				; root_dir_lba
			mov ebx, [hdfat3216_bpbRootDirCluster]
			call hdfat3216_cluster2lba
			mov [hdfat3216_root_dir_lba], eax
				; dir_entries_per_cluster_num
			movzx eax, BYTE [hdfat3216_bpbSectorsPerCluster]
			shl	eax, 4										; *16, (512/32=16 (number of dir-entries per sector))
			mov [hdfat3216_dir_entries_per_cluster_num], eax

			ret


; IN: BX(filename), ECX,CL(length), ES:DI(memaddr)
; OUT: ECX(size of file in bytes)
hdfat3216_readfile:
			mov DWORD [hdfat3216_curr_sector_num], -1
			mov DWORD [hdfat3216_filesize], 0
			mov [hdfat3216_memaddr_seg], es
			mov [hdfat3216_memaddr_offs], di
			push ds
			pop es
			; copy filename
			mov [hdfat3216_fname_len], cl
			mov si, bx
			mov di, hdfat3216_fname
			rep movsb
			; read root directory
			mov eax, [hdfat3216_bpbRootDirCluster]
			mov [hdfat3216_cluster_num], eax
			mov eax, [hdfat3216_root_dir_lba]
.Read		movzx cx, BYTE [hdfat3216_bpbSectorsPerCluster]
			mov bx, [hdfat3216_memaddr_seg]					; we read the directory-cluster to FILE_BUFF too
			mov di, [hdfat3216_memaddr_offs]
			call hdfat3216_readsectors
%ifdef HDFAT3216_DBG_LOAD
		pusha
		push es
		call stdio16_new_line
		mov ax, [hdfat3216_memaddr_seg]	
		mov es, ax
		mov di, [hdfat3216_memaddr_offs]
;		mov cx, 32
		mov cx, 16
		call util16_mem_dump
		call stdio16_new_line
;		call util16_wait_key
		pop es
		popa
%endif
			mov ax, [hdfat3216_memaddr_seg]					; we read the directory-cluster to FILE_BUFF too
			mov es, ax
			mov di, [hdfat3216_memaddr_offs]
.GetEntry	cmp BYTE [es:di], 0								; end of dir-entries?
			jz	.Back
			cmp BYTE [es:di], HDFAT3216_DELETED_ENTRY
			jz	.Inc
			; check entry
			xor ax, ax
			mov al, [es:di+HDFAT3216_DE_ATTRIB]
			bt	ax, HDFAT3216_ATTR_DIRECTORY						; is it a directory?
			jc	.Inc
%ifdef HDFAT3216_DBG_LOAD
		pusha
		call stdio16_new_line
		mov si, hdfat3216_fname
		xor cx, cx
		mov cl, [hdfat3216_fname_len]
		call stdio16_put_chs	; DS:SI chars, CX number
		mov al, 32				; space
		call stdio16_put_ch
		push ds
		push es
		pop ds
		mov si, di	
		inc si
		xor cx, cx
		mov cl, [es:di+HDFAT3216_DE_NAME]
		call stdio16_put_chs
		pop ds
		call util16_wait_key
		call stdio16_new_line
		popa
%endif
	;	DS:SI: addr of string1; In
	;	ES:DI: addr of string2; In
	;	CX: length; In
	;	AX: <0 if s1 < s2; 0 if s1 == s2; >0 if s1 > s2 ; Out
	;	skips chars in DS:SI that are > 126 ( greater then ASCII of '~' )
			; compare strings, if not found ==> Inc
			xor cx, cx
			mov cl, [hdfat3216_fname_len]
			cmp cl, [es:di+HDFAT3216_DE_NAME]
			jne	.Inc
			mov si, hdfat3216_fname
			inc di
			call hdfat3216_strcmp		; AX, CX
			dec di
			cmp ax, 0
			jnz	.Inc
			mov ebx, [es:di+HDFAT3216_DE_CLUS_NUM]
			mov eax, [es:di+HDFAT3216_DE_FILE_SIZE]
			mov [hdfat3216_filesize], eax
			; Note: we don't check here if the size of the file is zero (clusternum=0; filesize=0)
			; read file from its cluster
				; read cluster, then from FAT the next ones
.NextClus	mov [hdfat3216_cluster_num], ebx
			call hdfat3216_cluster2lba		; fills EAX
			movzx cx, BYTE [hdfat3216_bpbSectorsPerCluster]
			mov bx, [hdfat3216_memaddr_seg]
			mov di, [hdfat3216_memaddr_offs]
			call hdfat3216_readsectors
			mov	ax, [hdfat3216_bpbBytesPerSector]	
			movzx bx, BYTE [hdfat3216_bpbSectorsPerCluster]
			mul bx
			call hdfat3216_incmemaddr
			call hdfat3216_get_next_cluster		; ES, DS
			cmp ebx, HDFAT3216_END_OF_CLUSTER_MARKER
			jnc	.Back
			jmp .NextClus
.Inc		add di, HDFAT3216_DIR_ENTRY_LEN	
			xor ebx, ebx
			mov bx, di
			shr	ebx, 5										; /32
			cmp ebx, [hdfat3216_dir_entries_per_cluster_num]
			jnz	.GetEntry
			call hdfat3216_get_next_cluster		; ES, DS
			cmp ebx, HDFAT3216_END_OF_CLUSTER_MARKER
			jnc	.Back
			mov [hdfat3216_cluster_num], ebx
			call hdfat3216_cluster2lba
			jmp .Read
.Back		mov ecx, [hdfat3216_filesize]
			ret


; IN: AX(value)
;	handles overflow (segment:offset)
;	add offset to segment to avoid overflow (segment*16+offset and zero to offset) 
;	Example(overflow): 
;		07E0:F000 + 10F3 (i.e. AX=10F3)
;		7E00+F000 = 16E00
;		16E00+10F3 = 17EF3
;		17EF:0003 !?
hdfat3216_incmemaddr:
			pushad
			movzx ebx, WORD [hdfat3216_memaddr_seg]
			mov di, [hdfat3216_memaddr_offs]
			add di, ax
			mov dx, [hdfat3216_memaddr_offs]
			mov cx, 0xFFFF
			sub cx, dx
			inc cx
			cmp ax, cx
			jc	.Ok									; jump if unsigned less
			; overflow
			movzx edi, WORD [hdfat3216_memaddr_offs]
			shl	ebx, 4	
			add ebx, edi
			mov edi, ebx
			and edi, 0x0000000F
			add di, ax
			shr ebx, 4
.Ok			mov [hdfat3216_memaddr_seg], bx
			mov [hdfat3216_memaddr_offs], di
			popad
			ret


; IN: EBX(clusternum)
; OUT: EAX
hdfat3216_cluster2lba:
			push ebx
			push edx
			sub ebx, 2
			xor eax, eax
			mov al, [hdfat3216_bpbSectorsPerCluster]
			mul ebx
			add eax, [hdfat3216_cluster_begin_lba]
			pop edx
			pop ebx
			ret


; IN:
; OUT: EBX(clusternum)
hdfat3216_get_next_cluster:
			mov eax, [hdfat3216_cluster_num]
			mov esi, eax
			and esi, HDFAT3216_OFFSET_WITHIN_SECTOR_MASK		; lower 7 bits is the offset within the sector
			shl esi, 2										; the offset is in dwords
			shr eax, 7										; EAX: sectornumber in FAT
			cmp eax, [hdfat3216_curr_sector_num]				; Sector already in memory? If yes don't read.
			je	.Check
			mov [hdfat3216_curr_sector_num], eax
			add eax, [hdfat3216_fat_begin_lba]
			; read 1 sector from FAT
			mov cx, 1
			mov bx, HDFAT3216_SECTOR_BUFF_SEG
			mov di, 0
			call hdfat3216_readsectors
.Check		mov ax, HDFAT3216_SECTOR_BUFF_SEG
			mov es, ax
			mov di, si
			mov ebx, [es:di]
			ret


;************************************************
; Reads a series of sectors
; IN: 	EAX (Starting sector)
;		CX (Number of sectors to read)
;		BX:DI (Buffer to read to)
;************************************************
hdfat3216_readsectors:
			pusha
			mov bp, 0x0005						; max. 5 retries
.Again		mov dl, [hdfat3216_drivenum]
			mov BYTE [hdfat3216_buff], 0x10			; size of this structure (1 byte)
			mov BYTE [hdfat3216_buff+1], 0			; always zero (1 byte)
			mov WORD [hdfat3216_buff+2], cx			; number of sectors to read (2 bytes)
			mov WORD [hdfat3216_buff+4], di			; segment:offset ptr to memory to read to (4 bytes) 
			mov WORD [hdfat3216_buff+6], bx 
			mov DWORD [hdfat3216_buff+8], eax		; read from sector (8 bytes)
			mov DWORD [hdfat3216_buff+12], 0 
			mov ah, 0x42
			mov si, hdfat3216_buff 
			int 0x13
			jnc	.Ok
			dec bp
			jnz	.Again
			mov si, hdfat3216_msgErrReadSector
			call hdfat3216_print
		jmp $
			int 0x18
.Ok			mov si, hdfat3216_msgProgress
 			call hdfat3216_print
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
hdfat3216_strcmp:
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
hdfat3216_print:
			pusha
.Next		lodsb				; load next byte from string from SI to AL
			or	al, al			; Does AL=0?
			jz .Back			; Yep, null terminator found-bail out
			mov	ah, 0x0E		; Nope-Print the character
			int	0x10
			jmp	.Next			; Repeat until null terminator found
.Back		popa
			ret					; we are done, so return


section .data

hdfat3216_bpbBytesPerSector 	dw 0
hdfat3216_bpbSectorsPerCluster	db 0
hdfat3216_bpbReservedSectors	dw 0
hdfat3216_bpbNumberOfFATs		db 0
hdfat3216_bpbSectorsPerFAT		dd 0
hdfat3216_bpbRootDirCluster		dd 0

hdfat3216_curr_sector_num	dd -1

hdfat3216_drivenum				db 0		; the drive we booted from
hdfat3216_partition_lba_begin	dd 0

;	fat_begin_lba(DWORD)			= Partition_LBA_begin + Number_Of_Reserved_Sectors
;	cluster_begin_lba(DWORD)		= Partition_LBA_begin + Number_Of_Reserved_Sectors + (Number_Of_FATs * Sectors_Per_FAT)
;	sectors_per_cluster(BYTE)		= Sectors Per Cluster
;	root_dir_first_cluster(DWORD)	= Root Dir First Cluster
hdfat3216_fat_begin_lba			dd 0
hdfat3216_cluster_begin_lba		dd 0
hdfat3216_root_dir_lba			dd 0
;lba_addr = cluster_begin_lba + (cluster_number - 2) * sectors_per_clusters (See usbfat32.asm for more details)
hdfat3216_dir_entries_per_cluster_num	dd	0

hdfat3216_cluster_num		dd 0

hdfat3216_fname			times 17 db 0		; in Modified-FAT32 17 is the max charnum
hdfat3216_fname_len		db 0
hdfat3216_filesize		dd 0
hdfat3216_memaddr_seg	dw 0
hdfat3216_memaddr_offs	dw 0

hdfat3216_buff 	times 16 db 0

hdfat3216_msgProgress		db ".", 0
hdfat3216_msgErrReadSector	db "Error reading sector", 0x0D, 0x0A, 0


%endif

