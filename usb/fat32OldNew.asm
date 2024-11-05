;********************************************
; USBFAT32
;	Reading from a FAT32 filesystem on a USB-drive
;********************************************

; Can read longfilename-entries too. Can only write shortfilename-entries.

; FAT32
;	In the MBR from byte 446 (0x01BE) there are four 16-byte partition entries. 
;	A partition-entry:
;	BootFlag(byte0), CHSBegin(byte1-3), TypeCode(byte4), CHSEnd(byte5-7), LBABegin(byte8-11), NumberOfSectors(byte12-15)
;	Type code indicates the type of the filesystem (0x0B and 0x0C are used for FAT32). 
;	LBABegin tells us where the FAT32 filesystem begins on the disk. This first sector is called the VolumeID.
;	The VolumeID contains info about the physical layout of the FAT32 filesystem.
;	VolumeID (name, offset, size(bits), value):
;		Bytes Per Sector		- 0x0B - 16 - Always 512
;		Sectors Per Cluster		- 0x0D -  8 - 1,2,4,8,16,32,64,128
;		Num of Reserved Sectors - 0x0E - 16 - Usually 0x20
;		Number of FATs			- 0x10 -  8 - Always 2
;		Sectors Per FAT			- 0x24 - 32 - Depends on disk size
;		Root Dir 1st Cluster	- 0x2C - 32 - Usually 0x00000002
;		Signature				- 0x1FE - 16 - Always 0xAA55
;	Check BytesPerSectors, NumberOfFATs and the Signiture to see if it's really a FAT32.
;
;	fat_begin_lba(DWORD)			= Partition_LBA_begin + Number_Of_Reserved_Sectors
;	cluster_begin_lba(DWORD)		= Partition_LBA_begin + Number_Of_Reserved_Sectors + (Number_Of_FATs * Sectors_Per_FAT)
;	sectors_per_cluster(BYTE)		= Sectors Per Cluster
;	root_dir_first_cluster(DWORD)	= Root Dir First Cluster
;
;	So, there is the VolumeID followed by the ReservedSectors and then do the 2 FATs come. 
;	Next come the Clusters(Files and Dirs) perhaps followed by a small UnusedSpace. The clusters begin their numbering at 2 (no 0 and 1).
;
;	lba_addr = cluster_begin_lba + (cluster_number - 2) * sectors_per_clusters
;
;	The RootDir reveals the names and the first cluster location of the files and subdirs (filelength, time, etc. is also included).
;	FAT contains the rest of the cluster addresses.
;	Directory data is organized in 32-byte records. There are 4 types:
;		1. Normal record with short filename (Attrib is normal)
;		2. Long filename text (Attrib has all four type-bits set)
;		3. Unused (first byte is 0xE5) ; result of deletion
;		4. End of directory (first byte is zero)
;	Record-structure (field, offset, size):
;		Short Filename	- 0x00 - 11 bytes	[8.3]
;		AttribByte		- 0x0B -  1 byte
;		Reserved		- 0x0C -  1 byte
;		CreatTime(1/10)	- 0x0D -  1 byte  	[1/10 of a second]
;		FileCreatTime	- 0x0E -  2 bytes	[Hour(5), Min(6), Secs(5)]
;		FileCreatDate	- 0x10 -  2 bytes	[Year(7), Mon(4), Day(5)]
;		LastAccessDate	- 0x12 -  2 bytes	[same as creation]
;		First ClusterHI	- 0x14 -  2 bytes
;		LastModifTime	- 0x16 -  2 bytes	[same as creation]
;		LastModifDate	- 0x18 -  2 bytes	[same as creation]
;		First ClusterLO	- 0x1A -  2 bytes
;		File Size		- 0x1C -  4 bytes
;	The Record-structure above are also valid for Longfilenames but the chars of the name are in the records that precede this ShortFileName 
;	record. 
;	The structure of a LongFileName entry (before the normal ShortFileName-record) (OffsetInBytes, Length):
;		 0	-	 1		[e.g. if 0x41, then this is the first(0x01) record of the longfname and the last one(0x40) (i.e.0x4x means the last)]
;		 1	-	10		[The first 5, 2-byte chars]
;		0B	-	 1		[Attribute, always 0x0F (the long filename-attrib)]
;		0C	-	 1		[Long entry type, zero for name entries]
;		0D	-	 1		[Checksum]
;		0E	-	12		[The next 6, 2-byte chars]
;		1A	-	 2		[Always zero]
;		1C	-	 4		[The final 2, 2-byte chars]
;		The name is null terminated (00 00) and FF's are at the end for padding
;
;	Attrib-byte:
;		0	-	Read-only	(not allow writing)		[LSB]
;		1	-	Hidden		(don't show)
;		2	-	System		(fille is OS)
;		3	-	VolumeID	(Filename is VolumeID)
;		4	-	Directory	(it's a subdir)
;		5	-	Archive		(changed since last backup)
;		6	-	Unused		(should be zero)
;		7	-	Unused		(should be zero)
;		In case of a LongFilename attrib-byte=00xx1111b
;
;	Following Cluster Chains:
;		The directory entry tells us only the first cluster of each file (or subdir). To access all the other clusters of a file 
;		beyond the first cluster, you need to use the FAT. Each entry in the FAT is 32-bits.
;		Every sector holds 128 32-bit entries in the FAT. Bits 7-31 of the current cluster tell you which sectors to read from the FAT, 
;		and bits 0-6 tell you which of the 128 entries in that sector is the number of the next cluster of the file.
;		For example a file has the cluster number 0x00000002 in the directory record. We look at the 3rd (0, 1, 2) entry in the FAT and 
;		find 0x00000009. The 10th entry contains 0x0000000A. The 11th entry is 0x0000000B, the 12th is 0x00000011. The 18th is 0xFFFFFFF8.
;		So the file consist of clusters 2, 9, A, B, 11. End of file maker: greater or equal to 0xFFFFFFF8.
;		According to the specs, the cluster numbers use only the lower 28-bits, the remaining 4 bits are reserved and should be masked.
;		Files that have zero length, have cluster 0 in the directory-record. Zeros in the FAT mark clusters that are free space.
;		
;	In every folder(i.e. directory) except the root, there are '.' and '..' (pointer to itself; pointer to the parent)
;		
;	FSInfo (Offs, Len):
;		0x0000	4		FS information sector signature (0x52 0x52 0x61 0x41 = "RRaA")  
;		0x0004	480		Reserved (byte values should be set to 0x00 during format, but not be relied upon and never changed later on) 
;		0x01E4	4		FS information sector signature (0x72 0x72 0x41 0x61 = "rrAa") 
;		0x01E8	4		Last known number of free data clusters on the volume, or 0xFFFFFFFF if unknown. 
;						Should be set to 0xFFFFFFFF during format and updated by the operating system later on. 
;						Must not be absolutely relied upon to be correct in all scenarios. Before using this value, 
;						the operating system should sanity check this value to be less than or equal to the volume's count of clusters. 	
;		0x01EC	4		NOTE! Unlike wikipedia, FAT32-specification says next-free-cluster!
;						But it is OK, because the search will start from this last allocated clusternum!!
;						Number of the most recently known to be allocated data cluster. Should be set to 0xFFFFFFFF during format 
;						and updated by the operating system later on. With 0xFFFFFFFF the system should start at cluster 0x00000002. 
;						Must not be absolutely relied upon to be correct in all scenarios. Before using this value, the operating system 
;						should sanity check this value to be a valid cluster number on the volume. 
;		0x01F0	12		Reserved (byte values should be set to 0x00 during format, but not be relied upon and never changed later on) 
;		0x01FC	4		FS information sector signature (0x00 0x00 0x55 0xAA) (All four bytes should match before the contents of this 
;						sector should be assumed to be in valid format.) 


%ifndef __USBFAT32__
%define __USBFAT32__


%include "usb/usb.asm"
%include "gstdio.asm"
%include "gutil.asm"


; Something overwrites the memory-region below!? (USBFSINIT fails(DIVISIONBYZERO exception)):
;%define USBFAT32_PATH_BUFF		0x68E800
;%define USBFAT32_NAME_BUFF		0x690800
;%define USBFAT32_SECTOR_BUFF	0x69E800						; for reading/writing sectors from/to FAT
;%define USBFAT32_CLUSTER_BUFF	0x6AE800
;this works:
;%define USBFAT32_PATH_BUFF		0x690000
%define USBFAT32_NAME_BUFF		0x692000
%define USBFAT32_SECTOR_BUFF	0x6A0000						; for reading/writing sectors from/to FAT
%define USBFAT32_CLUSTER_BUFF	0x6B0000

; partition
%define	USBFAT32_PARTITION_TABLE_OFFS	0x01BE	; 446
;%define	USBFAT32_TYPE_CODE1				0x0B
;%define	USBFAT32_TYPE_CODE2				0x0C

; VolumeID
%define	USBFAT32_BYTES_PER_SECTOR_OFFS			0x0B
;%define	USBFAT32_SECTORS_PER_CLUSTER_OFFS	0x0D
;%define	USBFAT32_RESERVED_SECTORS_NUM_OFFS	0x0E
;%define	USBFAT32_FATS_NUM_OFFS				0x10
%define	USBFAT32_SECTORS_PER_FAT_OFFS			0x24
%define	USBFAT32_ROOT_DIR_CLUSTER_OFFS			0x2C
%define	USBFAT32_FSINFO_SECTOR_OFFS				0x30
%define	USBFAT32_COPY_BOOTSECTOR_CLUSTER_OFFS	0x32
%define	USBFAT32_SIGNATURE_OFFS					0X1FE

%define USBFAT32_DIR_ENTRY_LEN	32	; bytes

%define	USBFAT32_BYTES_SECTOR	512

;%define USBFAT32_END_OF_CLUSTER_MARKER	0x0FFFFFF8				; I always got 0x0FFFFFFF (before clearing the topmost 4 bits) from FAT
;%define USBFAT32_BAD_SECTOR				0x0FFFFFF7
%define USBFAT32_END_OF_CLUSTER_MARKER	0x0FFFFFF7				; I always got 0x0FFFFFFF (before clearing the topmost 4 bits) from FAT
%define USBFAT32_DELETED_ENTRY			0xE5

; Masks(FAT-table)
%define USBFAT32_CLUSTER_NUM_MASK			0x0FFFFFFF			; upper 4 bits of a cluster-number are reserved
%define USBFAT32_OFFSET_WITHIN_SECTOR_MASK	0x0000007F			; lower 7 bits is the offset within sector in the FAT

%define USBFAT32_MAX_NAME_LEN	256

; Short Filename-entry (SFN)
%define	USBFAT32_SFN_NAME		0
%define	USBFAT32_SFN_ATTRIB		11
%define	USBFAT32_SFN_TIME10		13
%define	USBFAT32_SFN_TIME		14
%define	USBFAT32_SFN_DATE		16	; Create
%define	USBFAT32_SFN_LA_DATE	18	; Last access
%define	USBFAT32_SFN_CLUSTER_HI	20
%define	USBFAT32_SFN_LA_MOD_TIM	22
%define	USBFAT32_SFN_LA_MOD_DAT	24	; Last Modify
%define	USBFAT32_SFN_CLUSTER_LO	26
%define	USBFAT32_SFN_FILESIZE	28

; Long Filename-entry (LFN)
%define USBFAT32_ENTRY_IND		0
%define USBFAT32_ENTRY_NAME1	1		; first 5, 2-byte chars
%define USBFAT32_ENTRY_ATTRIB	11
%define USBFAT32_ENTRY_LE_TYPE	12
%define USBFAT32_ENTRY_CHECKSUM	13
%define USBFAT32_ENTRY_NAME2	14		; next 6, 2-byte chars
%define USBFAT32_ENTRY_ZERO		26
%define USBFAT32_ENTRY_NAME3	28		; final 2, 2-byte chars

; Attrib
;%define USBFAT32_ATTR_READONLY	1
;%define USBFAT32_ATTR_HIDDEN	2
;%define USBFAT32_ATTR_SYSTEM	4
;%define USBFAT32_ATTR_VOLUMEID	8
;%define USBFAT32_ATTR_DIRECTORY	16
;%define USBFAT32_ATTR_ARCHIVE	32

; Attrib bits
;%define USBFAT32_ATTR_READONLY_BIT		0
;%define USBFAT32_ATTR_HIDDEN_BIT		1
;%define USBFAT32_ATTR_SYSTEM_BIT		2
;%define USBFAT32_ATTR_VOLUMEID_BIT		3
;%define USBFAT32_ATTR_DIRECTORY_BIT	4
;%define USBFAT32_ATTR_ARCHIVE_BIT		5

%define USBFAT32_ATTR_DIRECTORY_MASK	0x10


%define USBFAT32_LFN_MASK			0x0F	; long filename
%define USBFAT32_LFN_LAST_ENTRY_BIT	6		; last LFN-entry, if 1

%define USBFAT32_CHARS_MAX_NUM	13*2

%define USBFAT32_DATE_SEPARATOR_CHAR		'/'
%define USBFAT32_UNICODE_SUBSTITUTE_CHAR	'X'

; FSInfo
%define	USBFAT32_FSINFO_LEADSIG					0x41615252
%define	USBFAT32_FSINFO_STRUCSIG				0x61417272
%define	USBFAT32_FSINFO_TRAILSIG				0xAA550000
%define	USBFAT32_FSINFO_LEADSIG_OFFS			0
%define	USBFAT32_FSINFO_STRUCSIG_OFFS			484
%define	USBFAT32_FSINFO_FREECLUSTERCNT_OFFS		488
%define	USBFAT32_FSINFO_NEXTFREECLUSTERNUM_OFFS	492			; in reality this is the lastwritten-clusternum (the search starts from)
%define	USBFAT32_FSINFO_TRAILSIG_OFFS			508
%define	USBFAT32_FSINFO_UNKNOWN					0xFFFFFFFF


section .text

; reads partition-table in MBR, and VolumeID-lba from it.
; Fills variables from VolumeID
; IN: -
; OUT: usbfat32_res (0 faliure)
usbfat32_init:
			pushad
			mov DWORD [usbfat32_res], 0
			mov BYTE [usbfat32_fs_inited], 0
			mov DWORD [usbfat32_curr_sector_num], -1
			mov DWORD [usbfat32_free_clusters_cnt], USBFAT32_FSINFO_UNKNOWN
			mov DWORD [usbfat32_next_free_cluster_num], USBFAT32_FSINFO_UNKNOWN
			; read MBR (and partition-table from it)
	; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
			xor eax, eax
			xor ebx, ebx
			mov ecx, USBFAT32_SECTOR_BUFF
			mov edx, 1
			call usb_read_msd
			cmp DWORD [usb_res], 1
			jz	.PType
			mov ebx, usbfat32_DiskReadErrTxt
			call gstdio_draw_text
			jmp	.Back
.PType		mov esi, USBFAT32_SECTOR_BUFF
			add esi, USBFAT32_PARTITION_TABLE_OFFS
			add	esi, 4
			mov bl, [esi]
			mov [usbfat32_partition_type_code], bl
;			cmp bl, USBFAT32_TYPE_CODE1					; fails if checked
;			jz	.ReadLBA
;			cmp bl, USBFAT32_TYPE_CODE2					; fails if checked
;			jnz	.Back
.ReadLBA	add esi, 4
			mov ebx, [esi]
			mov [usbfat32_partition_lba_begin], ebx
			add esi, 4
			mov ebx, [esi]
			mov [usbfat32_partition_sectors_cnt], ebx
			; read VolumeID
	; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
			xor eax, eax
			mov ebx, [usbfat32_partition_lba_begin]
			mov ecx, USBFAT32_SECTOR_BUFF
			mov edx, 1
			call usb_read_msd
			cmp DWORD [usb_res], 1
			jz	.Copy
			mov ebx, usbfat32_DiskReadErrTxt
			call gstdio_draw_text
			jmp	.Back
.Copy		mov esi, USBFAT32_SECTOR_BUFF
			add esi, USBFAT32_BYTES_PER_SECTOR_OFFS
			mov edi, usbfat32_bytes_per_sector
			mov ecx, 6
			rep	movsb
			mov esi, USBFAT32_SECTOR_BUFF
			add esi, USBFAT32_SECTORS_PER_FAT_OFFS
			mov ebx, [esi]
			mov [usbfat32_sectors_per_fat], ebx
			sub esi, USBFAT32_SECTORS_PER_FAT_OFFS
			add esi, USBFAT32_ROOT_DIR_CLUSTER_OFFS
			mov ebx, [esi]
			mov [usbfat32_root_dir_cluster], ebx
			sub esi, USBFAT32_ROOT_DIR_CLUSTER_OFFS
			add esi, USBFAT32_FSINFO_SECTOR_OFFS
			xor ebx, ebx
			mov bx, [esi]
			mov [usbfat32_fsinfo_sector], ebx
			sub esi, USBFAT32_FSINFO_SECTOR_OFFS
			add esi, USBFAT32_COPY_BOOTSECTOR_CLUSTER_OFFS
			xor ebx, ebx
			mov bx, [esi]
			mov [usbfat32_copy_boot_sector], ebx

			; calculate number of clusters per word (i.e. 16bits); 65535/sectors_per_cluster
			xor edx, edx
			mov eax, 0xFFFF
			xor ebx, ebx
			mov bl, [usbfat32_sectors_per_cluster]
			div ebx
			mov [usbfat32_max_clusters_num_per_word], ax

			; check the validity of USBFAT32
			cmp WORD [usbfat32_bytes_per_sector], USBFAT32_BYTES_SECTOR
			jz	.ChkFATs
			mov ebx, usbfat32_SectorByteCntErrTxt
			call gstdio_draw_text
			jmp	.Back
.ChkFATs	cmp BYTE [usbfat32_fats_num], 2
			jz	.ChkSig
			mov ebx, usbfat32_FATCntErrTxt
			call gstdio_draw_text
			jmp	.Back
.ChkSig		mov esi, USBFAT32_SECTOR_BUFF
			add esi, USBFAT32_SIGNATURE_OFFS
			cmp WORD [esi], 0xAA55
			jz	.Calc
			mov ebx, usbfat32_SigErrTxt
			call gstdio_draw_text
			jmp	.Back
			; calc fat_begin_lba and cluster_begin_lba
.Calc		mov ecx, [usbfat32_partition_lba_begin]
			xor ebx, ebx
			mov bx, [usbfat32_reserved_sectors_num]
			add ecx, ebx
			mov [usbfat32_fat_begin_lba], ecx
			xor eax, eax
			mov al, [usbfat32_fats_num]
			mov ebx, [usbfat32_sectors_per_fat]
			mul ebx
			add ecx, eax
			mov [usbfat32_cluster_begin_lba], ecx
				; root_dir_lba
			mov ebx, [usbfat32_root_dir_cluster]
	; IN: EBX(clusternum)
	; OUT: EAX
			call usbfat32_cluster2lba
			mov [usbfat32_root_dir_lba], eax
				; dir_entries_per_cluster_num
			xor eax, eax
			mov al, [usbfat32_sectors_per_cluster]
			shl	eax, 4										; *16, (512/32=16 (number of dir-entries per sector))
			mov [usbfat32_dir_entries_per_cluster_num], eax

			call usbfat32_read_fsinfo
			cmp DWORD [usbfat32_res], 1
			jz	.Ok
			mov ebx, usbfat32_ReadFSInfoErrTxt
			call gstdio_draw_text
			jmp	.Back

.Ok			mov BYTE [usbfat32_fs_inited], 1
			mov DWORD [usbfat32_res], 1
.Back		popad
			ret


; IN: -
; OUT: usbfat32_res (0 faliure)
usbfat32_fsinfo:
			pushad
			mov DWORD [usbfat32_res], 0
			cmp BYTE [usbfat32_fs_inited], 1
			jz	.Print
			mov ebx, usbfat32_FSNotInitedErrTxt
			call gstdio_draw_text
			jmp	.Back
.Print		call gstdio_new_line
			mov ebx, usbfat32_FSInfoTxt
			call gstdio_draw_text
			mov ebx, usbfat32_TotalSectorsTxt
			call gstdio_draw_text
			mov edx, [ata_maxlba]	
			call gstdio_draw_hex
			call gstdio_new_line
			mov ebx, usbfat32_FATBeginLBATxt
			call gstdio_draw_text
			mov edx, [usbfat32_fat_begin_lba]
			call gstdio_draw_hex
			call gstdio_new_line
			mov ebx, usbfat32_SectorsPerFATTxt
			call gstdio_draw_text
			mov edx, [usbfat32_sectors_per_fat]
			call gstdio_draw_hex
			call gstdio_new_line
			mov ebx, usbfat32_ClustersBeginLBATxt
			call gstdio_draw_text
			mov edx, [usbfat32_cluster_begin_lba]
			call gstdio_draw_hex
			call gstdio_new_line
			mov ebx, usbfat32_SectorsPerClusterTxt
			call gstdio_draw_text
			;xor edx, edx
			mov dh, [usbfat32_sectors_per_cluster]
			call gstdio_draw_hex8
			call gstdio_new_line
			mov ebx, usbfat32_FreeClustersCountTxt
			call gstdio_draw_text
			mov edx, [usbfat32_free_clusters_cnt]
			call gstdio_draw_hex
			call gstdio_new_line
			mov ebx, usbfat32_FirstFreeClusterNumTxt
			call gstdio_draw_text
			mov edx, [usbfat32_next_free_cluster_num]
			call gstdio_draw_hex
			call gstdio_new_line
			mov DWORD [usbfat32_res], 1
.Back		popad
			ret


; Updates the FSInfo-structure on disk (FreeClusterCount)
; It doesn't update the NextFreeClusterNum because NextFreeClusterNum is 
; the most recently allocated clusternum, but we don't know that now.
; NextFreeClusterNum is the clusternum the search for free cluster starts from.
; If we wrote to the filesystem and forgot to call USBFSREM right before removing the disk, 
; the FSInfo-structure on disk didn't get updated.
; Call USBFSINFOUPD to fix it.
; Note: this may take some time depending on the size of the drive, 
; because it scans the FAT-table
; IN: -
; OUT: usbfat32_res (0 faliure)
usbfat32_fsinfoupd:
			pushad
			mov DWORD [usbfat32_res], 0
			cmp BYTE [usbfat32_fs_inited], 1
			jz	.Inited
			mov ebx, usbfat32_FSNotInitedErrTxt
			call gstdio_draw_text
			jmp	.Back
			; calculate number of free clusters
.Inited		mov DWORD [usbfat32_free_clusters_cnt], 0
			xor ebx, ebx
	; IN: EBX(lbaLo)
	; OUT: usb_res(1 if ok)
.NextSect	call usbfat32_read_fat							; IN: ECX(lbaLO)
			cmp DWORD [usb_res], 1
			jz	.ClearPIT
			mov ebx, usbfat32_ReadFATErrTxt
			call gstdio_draw_text
			jmp	.Back
.ClearPIT	mov DWORD [pit_task_ticks], 0					; clear pit-ticks 
			; find first 0 in buffer
			mov esi, USBFAT32_SECTOR_BUFF
			; if first sector of FAT, then skip first two cluster-numbers
			cmp ebx, 0
			jnz	.Read
			add esi, 8	
.Read		cmp DWORD [esi], 0
			je	.Inc
			cmp BYTE [esi], USBFAT32_DELETED_ENTRY	
			jne	.Next
.Inc		inc DWORD [usbfat32_free_clusters_cnt]
.Next		add esi, 4
			cmp esi, USBFAT32_SECTOR_BUFF+USBFAT32_BYTES_SECTOR
			jne	.Read
			inc ebx
			cmp ebx, [usbfat32_sectors_per_fat]
			jc	.NextSect
			mov DWORD [usbfat32_next_free_cluster_num], USBFAT32_FSINFO_UNKNOWN	; OR LAST NON 0 OR 0xE5 ENTRY !?
			call usbfat32_write_fsinfo
.Back		popad
			ret


; IN: EAX(1 if long list)
; OUT: usbfat32_res (0 faliure)
usbfat32_ls:
			pushad
			mov DWORD [usbfat32_res], 0
			mov DWORD [usbfat32_curr_sector_num], -1
			; check if FS initialized
			cmp BYTE [usbfat32_fs_inited], 1
			jz	.Inited
			mov ebx, usbfat32_FSNotInitedErrTxt
			call gstdio_draw_text
			jmp	.Back
.Inited		mov BYTE [usbfat32_long_list], al
			call gstdio_new_line
	; IN: 
	; OUT: EBX(clusternum), USBFAT32_CLUSTER_BUFF, usb_res
			call usbfat32_read_curr_dir
.ChkRes		cmp DWORD [usb_res], 1
			jz	.Start
			mov ebx, usbfat32_ReadClusErrTxt
			call gstdio_draw_text
			jmp	.Back
.Start		mov esi, USBFAT32_CLUSTER_BUFF
.GetEntry	cmp BYTE [esi], 0								; end of dir-entries?
			jz	.Ok
			cmp BYTE [esi], USBFAT32_DELETED_ENTRY
			jz	.Inc
			; read and print entry
			cmp BYTE [esi+USBFAT32_ENTRY_ATTRIB], USBFAT32_LFN_MASK
			jnz	.SFN										; to Short FileName
			mov al, [esi]
			and al, USBFAT32_LFN_LAST_ENTRY_BIT
			jz	.CpLFN
			mov BYTE [usbfat32_name_entries_num], 0
.CpLFN		call usbfat32_copy_lfn_entry
			jmp .Inc
.SFN		mov al, [esi+USBFAT32_SFN_ATTRIB]
			and	al, USBFAT32_ATTR_DIRECTORY_MASK
			jnz	.Inc										; we skip directories
			cmp BYTE [usbfat32_name_entries_num], 0
			jz	.PrSFN	
			call usbfat32_print_lfn
			mov BYTE [usbfat32_name_entries_num], 0			; clear LFN (there can be an LFN with an SFN, but then only an SFN!?)
			jmp .ChkLong
.PrSFN		call usbfat32_copy_sfn
			call usbfat32_print_sfn
			; print dir, date, length
.ChkLong	cmp BYTE [usbfat32_long_list], 1
			jne	.Inc
.LongLis:
;			mov ebp, USBFAT32_SFN_DATE
;			call usbfat32_print_date
			mov ebp, USBFAT32_SFN_LA_DATE
			call usbfat32_print_date
			mov ebp, USBFAT32_SFN_LA_MOD_DAT
			call usbfat32_print_date
			mov eax, [esi+USBFAT32_SFN_FILESIZE]
			call gstdio_draw_dec
			call gstdio_new_line
.Inc		add esi, USBFAT32_DIR_ENTRY_LEN
			mov edx, esi
			sub edx, USBFAT32_CLUSTER_BUFF
			shr	edx, 5										; /32
			cmp edx, [usbfat32_dir_entries_per_cluster_num]
			jc	.GetEntry
	; IN: EBX(clusternum)
	; OUT: usbfat32_res, EBX(clusternum)
			call usbfat32_get_next_cluster_num
			cmp DWORD [usbfat32_res], 1
			jz	.ChkEOM
			mov ebx, usbfat32_GetNextClusNumErrTxt
			call gstdio_draw_text
			jmp	.Back
.ChkEOM		cmp ebx, USBFAT32_END_OF_CLUSTER_MARKER
			jnc	.Ok
	; IN: EBX(clusternum)
	; OUT: EAX
			call usbfat32_cluster2lba
	; IN: ECX(LBALo)
	; OUT: USBFAT32_CLUSTER_BUF (data)
			mov ecx, eax
			call usbfat32_read_clus
			jmp .ChkRes
.Ok			mov DWORD [usbfat32_res], 1
.Back		call gstdio_new_line
			popad
			ret


; IN: EAX(memaddr), EBX(addrofname, first byte is length)
; OUT: usbfat32_res (0 faliure), ECX(size of file in bytes)
usbfat32_read:
			pushad
			mov DWORD [usbfat32_res], 0
			mov DWORD [usbfat32_curr_sector_num], -1
			; check if FS initialized
			cmp BYTE [usbfat32_fs_inited], 1
			jz	.Inited
			mov ebx, usbfat32_FSNotInitedErrTxt
			call gstdio_draw_text
			jmp	.Back
.Inited		mov [usbfat32_memaddr], eax
			call usbfat32_copy_name							; copy name from dictionary to an array in this file
	; IN: 
	; OUT: EBX(clusternum), USBFAT32_CLUSTER_BUFF, usb_res
			call usbfat32_read_curr_dir
.ChkRes		cmp DWORD [usb_res], 1
			jz	.Get
			mov ebx, usbfat32_ReadCurrDirErrTxt
			call gstdio_draw_text
			jmp	.Back
.Get		mov esi, USBFAT32_CLUSTER_BUFF
.GetEntry	cmp BYTE [esi], 0								; end of dir-entries?
			jz	.Back
			cmp BYTE [esi], USBFAT32_DELETED_ENTRY
			jz	.Inc
			; check entry
			cmp BYTE [esi+USBFAT32_ENTRY_ATTRIB], USBFAT32_LFN_MASK
			jnz	.SFN										; to Short FileName
			mov al, [esi]
			and al, USBFAT32_LFN_LAST_ENTRY_BIT
			jz	.CpLFN
			mov BYTE [usbfat32_name_entries_num], 0
.CpLFN		call usbfat32_copy_lfn_entry
			jmp .Inc
.SFN		mov al, [esi+USBFAT32_SFN_ATTRIB]
			and	al, USBFAT32_ATTR_DIRECTORY_MASK			; is it a directory?
			jnz	.Inc										; we skip directories
			cmp BYTE [usbfat32_name_entries_num], 0
			jnz	.CompareLFN
			call usbfat32_copy_sfn
			call usbfat32_compare_sfn
			mov BYTE [usbfat32_name_entries_num], 0			; clear LFN (there can be an LFN with an SFN, but then only an SFN!?)
			jmp .Chk
.CompareLFN	call usbfat32_compare_lfn
			mov BYTE [usbfat32_name_entries_num], 0			; clear LFN (there can be an LFN with an SFN, but then only an SFN!?)
.Chk		cmp DWORD [usbfat32_res], 1		; Found?
			jnz	.Inc
			xor ebx, ebx
			mov bx, [esi+USBFAT32_SFN_CLUSTER_HI]
			shl	ebx, 16
			mov bx, [esi+USBFAT32_SFN_CLUSTER_LO]
			and ebx, USBFAT32_CLUSTER_NUM_MASK
			mov eax, [esi+USBFAT32_SFN_FILESIZE]
			mov [usbfat32_filesize], eax
			;check if length of file is zero
			cmp ebx, 0
			je	.Ok
			cmp eax, 0
			je	.Ok
			; read file from its cluster
			; read cluster, then from FAT the next ones
	; IN: EBX(clusternum to read)
	; OUT: ECX(number of consecutive clusters); EDX(the next clusternumber after the consecutive ones)
.NextClus	call usbfat32_get_consec_cluster_num
			cmp DWORD [usbfat32_res], 1
			jz	.ToLBA
			mov ebx, usbfat32_GetConsecClusNumErrTxt
			call gstdio_draw_text
			jmp	.Back
	; IN: EBX(clusternum)
	; OUT: EAX
.ToLBA		mov [usbfat32_next_clusnum], edx
			call usbfat32_cluster2lba
			push ebx
			push eax
			mov eax, ecx
			xor ebx, ebx
			mov bl, [usbfat32_sectors_per_cluster]
			mul ebx
			mov edx, eax										; sectorcnt in EDX
			pop eax
			push edx
	; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
			mov ebx, eax
			xor eax, eax
			mov ecx, [usbfat32_memaddr]
			call usb_read_msd
			cmp DWORD [usb_res], 1
			pop edx
			pop ebx
			jz	.ChkEOM
			mov ebx, usbfat32_DiskReadErrTxt
			call gstdio_draw_text
			jmp	.Back
.ChkEOM:	mov ebx, [usbfat32_next_clusnum]
			cmp ebx, USBFAT32_END_OF_CLUSTER_MARKER
			jnc	.Ok
			mov DWORD [pit_task_ticks], 0						; clear pit-counter
			; increment memaddr
			xor eax, eax
			mov	ax, [usbfat32_bytes_per_sector]
			push ebx
			mov ebx, edx										; EDX(sectorcnt)
			mul ebx
			pop ebx
			add [usbfat32_memaddr], eax
			; end of increment
			jmp .NextClus
.Inc		add esi, USBFAT32_DIR_ENTRY_LEN
			mov edx, esi
			sub edx, USBFAT32_CLUSTER_BUFF
			shr	edx, 5										; /32
			cmp edx, [usbfat32_dir_entries_per_cluster_num]
			jc	.GetEntry
	; IN: EBX(clusternum)
	; OUT: usbfat32_res, EBX(clusternum)
			call usbfat32_get_next_cluster_num	
			cmp DWORD [usbfat32_res], 1
			jnz	.Back
			cmp ebx, USBFAT32_END_OF_CLUSTER_MARKER
			jnc	.Ok
	; IN: EBX(clusternum)
	; OUT: EAX
			call usbfat32_cluster2lba
			mov ecx, eax
			call usbfat32_read_clus
			jmp .ChkRes
.Ok			mov DWORD [usbfat32_res], 1
.Back		popad
			mov ecx, [usbfat32_filesize]
			ret


; IN: EAX(memaddr), ECX(size in bytes), EBX(addrofname, first byte is length)
; OUT: usbfat32_res (0 faliure)
usbfat32_write:
			pushad
			mov DWORD [usbfat32_res], 0
			mov DWORD [usbfat32_curr_sector_num], -1
			; check if FS initialized
			cmp BYTE [usbfat32_fs_inited], 1
			jz	.Inited
			mov ebx, usbfat32_FSNotInitedErrTxt
			call gstdio_draw_text
			jmp	.Back
.Inited		mov [usbfat32_memaddr], eax
			mov [usbfat32_file_size], ecx
			; calculate how many clusters we need
			xor edx, edx
			mov eax, [usbfat32_file_size]
			cmp eax, 0
			je	.NoRem
			push ebx
			xor ebx, ebx
			mov bl, [usbfat32_sectors_per_cluster]
			shl ebx, 9										; *512 to get bytes
			div ebx
			cmp edx, 0
			pop ebx
			je	.NoRem
			inc eax
.NoRem		mov [usbfat32_clusters_cnt], eax
			cmp DWORD [usbfat32_free_clusters_cnt], USBFAT32_FSINFO_UNKNOWN
			jne	.ChkCnt
			mov ebx, usbfat32_FreeClusCntUnkTxt
			call gstdio_draw_text
			jmp .Back
.ChkCnt		cmp eax, [usbfat32_free_clusters_cnt]
			jna	.Copy
			mov ebx, usbfat32_NoFreeClusErrTxt
			call gstdio_draw_text
			jmp .Back
	; IN: EBX(addrofname, first byte is length)
	; OUT: ECX(len), usbfat32_name_buff (zero at the end)
.Copy		call usbfat32_copy_name							; copy name from dictionary to an array in this file
;			call usbfat32_filter_name						; LFN (not important, but later it will be useful when LFN will be supported)
			cmp ecx, 0
			je	.Back
	; IN: usbfat32_name_buff
	; OUT: usbfat32_sfn_buff
			call usbfat32_create_sfn
;			call usbfat32_check_sfn	
;			cmp eax, 1
;			jne	.Back

	; IN: 
	; OUT: EBX(clusternum), USBFAT32_CLUSTER_BUFF, usb_res
			call usbfat32_read_curr_dir	
			cmp DWORD [usb_res], 1
			jz	.ChkName
			mov ebx, usbfat32_ReadCurrDirErrTxt
			call gstdio_draw_text
			jmp	.Back
	; IN: usbfat32_sfn_buff, USBFAT32_CLUSTER_BUFF
	; OUT: usbfat32_res(1 if available, so the name doesn't exist in the current dir)
.ChkName	call usbfat32_is_name_available
			cmp DWORD [usbfat32_res], 1
			jz	.Avail
			mov ebx, usbfat32_NameAlreadyExistsErrTxt
			call gstdio_draw_text
			jmp	.Back
.Avail:		mov BYTE [usbfat32_add_dir_end], 0		; !!!???
	; IN: 
	; OUT: EBX(clusternum), USBFAT32_CLUSTER_BUFF, usb_res
			call usbfat32_read_curr_dir
.ChkRes		cmp DWORD [usb_res], 1
			jz	.Set
			mov ebx, usbfat32_ReadCurrDirErrTxt
			call gstdio_draw_text
			jmp	.Back
.Set		mov esi, USBFAT32_CLUSTER_BUFF
.FindFree	cmp BYTE [esi], USBFAT32_DELETED_ENTRY
			je	.Fnd
			cmp BYTE [esi], 0								; end of dir-entries?
			jnz	.Inc
			mov BYTE [usbfat32_add_dir_end], 1					; zero needs to be written in the next dir-entry
	; IN: ESI(addr of entry), EBX(clusternum), ECX(filesizeinbytes), usbfat32_sfn_buff, usbfat32_add_dir_end
	; OUT: EBX(cluster_num (adds first cluster of file (if filesize is not zero), or directory), usbfat32_res
.Fnd:		mov ecx, [usbfat32_file_size]
			call usbfat32_create_dir_entry	
			cmp DWORD [usbfat32_res], 1
			jz	.ChkClus
			mov ebx, usbfat32_CreateDirEntryErrTxt
			call gstdio_draw_text
			jmp	.Back
.ChkClus	cmp DWORD [usbfat32_file_size], 0					; if file was created with size of zero, then nothing to write
			je	.Ok
			xor ecx, ecx
			; write file to cluster
	; IN: EBX(clusternum)
	; OUT: EAX
.Write:		call usbfat32_cluster2lba
			push ecx
	; usb_write_msd IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
			push ebx
			mov ebx, eax
			xor eax, eax
			mov ecx, [usbfat32_memaddr]
			xor edx, edx
			mov dl, [usbfat32_sectors_per_cluster]
			call usb_write_msd
			cmp DWORD [usb_res], 1
			pop ebx
			pop ecx
			jz	.UpdFree
			mov ebx, usbfat32_DiskWriteErrTxt
			call gstdio_draw_text
			jmp	.Back
.UpdFree	mov [usbfat32_next_free_cluster_num], ebx		; update NextFreeClusNum
			; increment address, then find new cluster, then repeat
			xor eax, eax
			mov al, [usbfat32_sectors_per_cluster]
			shl	eax, 9								; *512
			add [usbfat32_memaddr], eax
			sub [usbfat32_file_size], eax				; !?
			inc ecx
			cmp ecx, [usbfat32_clusters_cnt]
			je	.Ok
	; IN: EBX(clusternum; eg. 2 for RootDir)
	; OUT: EBX(new clusternum)
			; add new cluster
			call usbfat32_add_new_cluster	
			cmp DWORD [usbfat32_res], 1
			jz	.Write
			mov ebx, usbfat32_AddNewClusterErrTxt
			call gstdio_draw_text
			jmp	.Back
.Inc		mov DWORD [pit_task_ticks], 0						; clear pit-counter
			add esi, USBFAT32_DIR_ENTRY_LEN
			mov edx, esi
			sub edx, USBFAT32_CLUSTER_BUFF
			shr	edx, 5										; /32
			cmp edx, [usbfat32_dir_entries_per_cluster_num]
			jc	.FindFree									; jump if unsigned smaller
	; IN: EBX(clusternum)
	; OUT: usbfat32_res, EBX(clusternum)
			call usbfat32_get_next_cluster_num
			cmp DWORD [usbfat32_res], 1
			jz	.ChkEOM
			mov ebx, usbfat32_GetNextClusNumErrTxt
			call gstdio_draw_text
			jmp	.Back
.ChkEOM		cmp ebx, USBFAT32_END_OF_CLUSTER_MARKER
			jc	.Read2										; jump if unsigned less
			mov ebx, usbfat32_EndOfClusMarkerFndTxt
			call gstdio_draw_text
			jmp	.Back
	; IN: EBX(clusternum)
	; OUT: EAX
.Read2		call usbfat32_cluster2lba
	; IN: ECX(LBALo)
	; OUT: USBFAT32_CLUSTER_BUF (data)
			mov ecx, eax
			call usbfat32_read_clus
			jmp .ChkRes
.Ok			mov DWORD [usbfat32_res], 1
			mov eax, [usbfat32_clusters_cnt]
			sub [usbfat32_free_clusters_cnt], eax
.Back		popad
			ret


; Remove Filesystem (if we wrote to the filesystem, this needs to be called before we unplug the usb-disk)
; writes FSInfo sector to disk
; IN: -
; OUT: usbfat32_res (0 faliure)
usbfat32_rem:
			pushad
			mov DWORD [usbfat32_res], 0
			cmp BYTE [usbfat32_fs_inited], 1
			jnz	.Back
			call usbfat32_write_fsinfo
			cmp DWORD [usbfat32_res], 1
			jnz	.Back
			mov BYTE [usbfat32_fs_inited], 0
.Back		popad
			ret


; Writes FSInfo sector to disk
;	Should be called before turning of the computer, if we wrote to the filesystem
; IN: -
; OUT: usbfat32_res (0 faliure)
; Should be done automatically at shutdown!
usbfat32_wr_fsinfo:
			pushad
			mov DWORD [usbfat32_res], 0
			cmp BYTE [usbfat32_fs_inited], 1
			jz	.Inited
			mov ebx, usbfat32_FSNotInitedErrTxt
			call gstdio_draw_text
			jmp	.Back
.Inited		call usbfat32_write_fsinfo
			cmp DWORD [usbfat32_res], 1
;			jz	.Rem
			jz	.Back
			mov ebx, usbfat32_WriteFSInfoErrTxt
			call gstdio_draw_text
			jmp	.Back
;.Rem		mov BYTE [usbfat32_fs_inited], 0
.Back		popad
			ret


; IN: 
; OUT: EBX(clusternum), USBFAT32_CLUSTER_BUFF, usb_res
usbfat32_read_curr_dir:
			mov ebx, [usbfat32_root_dir_cluster]
			mov ecx, [usbfat32_root_dir_lba]
; IN: ECX(LBALo)
; OUT: USBFAT32_CLUSTER_BUF (data)
usbfat32_read_clus:
			push eax
			push ebx
			push edx
			mov ebx, ecx
	; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
			xor eax, eax
			mov ecx, USBFAT32_CLUSTER_BUFF
			xor edx, edx
			mov dl, [usbfat32_sectors_per_cluster]
			call usb_read_msd
			pop edx
			pop ebx
			pop eax
			ret


; IN: usbfat32_sfn_buff, USBFAT32_CLUSTER_BUFF
; OUT: usbfat32_res(1 if available, so the name doesn't exist in the current dir)
; checks if the given name exists in the current directory
usbfat32_is_name_available:
			pushad
			mov DWORD [usbfat32_res], 1
.Start		mov esi, USBFAT32_CLUSTER_BUFF
.Chk		cmp BYTE [esi], 0
			jz	.Back
			cmp BYTE [esi+USBFAT32_ENTRY_ATTRIB], USBFAT32_DELETED_ENTRY
			jz	.Inc
			cmp BYTE [esi+USBFAT32_ENTRY_ATTRIB], USBFAT32_LFN_MASK
			jz	.Inc
			mov edi, usbfat32_sfn_buff
			mov ecx, 11
			call gutil_strcmp
			cmp eax, 0
			jz	.Found
.Inc		add esi, USBFAT32_DIR_ENTRY_LEN
			mov ebx, esi
			sub ebx, USBFAT32_CLUSTER_BUFF
			shr	ebx, 5										; /32
			cmp ebx, [usbfat32_dir_entries_per_cluster_num]
			jc	.Chk										; jump if unsigned smaller
	; IN: EBX(clusternum)
	; OUT: usbfat32_res, EBX(clusternum)
			call usbfat32_get_next_cluster_num
			cmp DWORD [usbfat32_res], 1
			jz	.ChkEOM
			mov ebx, usbfat32_GetNextClusNumErrTxt
			call gstdio_draw_text
			jmp	.Back
.ChkEOM		cmp ebx, USBFAT32_END_OF_CLUSTER_MARKER
			jnc	.Back			; error
	; IN: EBX(clusternum)
	; OUT: EAX
			call usbfat32_cluster2lba
			mov ecx, eax
			call usbfat32_read_clus
			cmp DWORD [usb_res], 1
			jz	.Start
			mov ebx, usbfat32_ReadClusErrTxt
			call gstdio_draw_text
			jmp	.Back
.Found		mov DWORD [usbfat32_res], 0
.Back		popad
			ret


; Adds Dir-entry for the given file. If filesize is not zero, then gets-free-cluster (just one) and sets it to Dir-entry.
; If end-of-dir marker (i.e. zero) was overwritten, then adds end-of-dir marker in the next Dir-entry, 
; adding a new cluster to the chain of directory clusters, if necessary. Writes directory cluster(s) to disk.
; IN: ESI(addr of entry), EBX(directory-clusternum), ECX(filesizeinbytes), usbfat32_sfn_buff, usbfat32_add_dir_end
; OUT: EBX(cluster_num (adds first cluster of file (if filesize is not zero), or directory), usbfat32_res
;!?In case of error: clear FAT-entry!? And fix dir-entry!?
usbfat32_create_dir_entry:
			pushad
			mov DWORD [usbfat32_res], 0
			push ecx
			; copy Short-entry
			mov eax, esi
			mov esi, usbfat32_sfn_buff
			mov edi, eax
			mov ecx, 11
			rep movsb
			mov esi, eax
.Attrib		pop ecx
			mov BYTE [esi+USBFAT32_SFN_ATTRIB], 0
			mov BYTE [esi+USBFAT32_SFN_TIME10], 0
			push ebx
			call gutil_get_time	
			mov WORD [esi+USBFAT32_SFN_TIME], bx
			mov WORD [esi+USBFAT32_SFN_LA_MOD_TIM], bx
			call gutil_get_date	
			mov WORD [esi+USBFAT32_SFN_DATE], bx
			mov WORD [esi+USBFAT32_SFN_LA_DATE], bx
			mov WORD [esi+USBFAT32_SFN_LA_MOD_DAT], bx
			pop ebx
		;if filesize is zero ---> don't allocate free cluster!
			cmp ecx, 0
			jne	.AddClus
			mov WORD [esi+USBFAT32_SFN_CLUSTER_LO], 0
			mov WORD [esi+USBFAT32_SFN_CLUSTER_HI], 0
			mov DWORD [esi+USBFAT32_SFN_FILESIZE], 0
			mov DWORD [usbfat32_cluster_num1], 0			; save new
			jmp .ChkEnd
	; IN: usbfat32_next_free_cluster_num (if UNKNOWN --> search starts from zero)
	; OUT: EBX, usbfat32_res
	; writes ENDCLUS to FAT
			; find a free cluster in FAT
.AddClus	push ebx							; save current clusternum (i.e. the directory's cluster)
			call usbfat32_get_free_cluster			; gets new cluster for the new directory or new file
			mov [usbfat32_cluster_num1], ebx		; save new
			pop ebx								; EBX is the current clusternum (i.e. the directory's cluster)
			cmp DWORD [usbfat32_res], 1
			jz	.SetClus
			mov ebx, usbfat32_GetFreeClusErrTxt
			call gstdio_draw_text
			jmp	.Back
.SetClus	mov DWORD [usbfat32_res], 0
			mov eax, [usbfat32_cluster_num1]
			mov WORD [esi+USBFAT32_SFN_CLUSTER_LO], ax
			shr	eax, 16
			mov WORD [esi+USBFAT32_SFN_CLUSTER_HI], ax
			mov [esi+USBFAT32_SFN_FILESIZE], ecx
.ChkEnd		cmp BYTE [usbfat32_add_dir_end], 1		; end of directory was overwritten?
			jnz	.Write
			add esi, USBFAT32_DIR_ENTRY_LEN
			mov edx, esi
			sub edx, USBFAT32_CLUSTER_BUFF
			shr	edx, 5										; /32
			cmp edx, [usbfat32_dir_entries_per_cluster_num]	; do we need a new cluster?
			jc	.SetEnd							; jump if smaller			(unsigned)
		; write current cluster to disk before we add a new one (i.e. cluster) for the current directory
	; IN: EBX(clusternum)
	; OUT: EAX
			call usbfat32_cluster2lba
			push ebx
	; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
			mov ebx, eax
			xor eax, eax
			xor edx, edx
			mov dl, [usbfat32_sectors_per_cluster]
			mov ecx, USBFAT32_CLUSTER_BUFF
			call usb_write_msd
			pop ebx
			cmp DWORD [usb_res], 1
			jz	.AddClus2
			mov ebx, usbfat32_DiskWriteErrTxt
			call gstdio_draw_text
			jmp	.Back
	; IN: EBX(clusternum; eg. 2 for RootDir)
	; OUT: EBX(new clusternum)
			; add new cluster
.AddClus2	call usbfat32_add_new_cluster	
			cmp DWORD [usbfat32_res], 1
			jz	.ReadClus
			mov ebx, usbfat32_AddNewClusterErrTxt
			call gstdio_draw_text
			jmp	.Back
		; read new cluster
	; IN: EBX(clusternum)
	; OUT: EAX
.ReadClus	call usbfat32_cluster2lba
	; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
			push ebx
			mov ebx, eax
			xor eax, eax
			mov ecx, USBFAT32_CLUSTER_BUFF
			xor edx, edx
			mov dl, [usbfat32_sectors_per_cluster]
			call usb_read_msd
			pop ebx
			cmp DWORD [usb_res], 1
			jz	.Set
			mov ebx, usbfat32_DiskReadErrTxt
			call gstdio_draw_text
			jmp	.Back
.Set		mov esi, USBFAT32_CLUSTER_BUFF			; why?
.SetEnd		mov BYTE [esi], 0					; End of directory entries
	; IN: EBX(clusternum)
	; OUT: EAX
.Write		call usbfat32_cluster2lba
	; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
			mov ebx, eax
			xor eax, eax
			mov ecx, USBFAT32_CLUSTER_BUFF
			xor edx, edx
			mov dl, [usbfat32_sectors_per_cluster]
			call usb_write_msd
			cmp DWORD [usb_res], 1
			jz	.Ok
			mov ebx, usbfat32_DiskWriteErrTxt
			call gstdio_draw_text
			jmp	.Back
.Ok			mov DWORD [usbfat32_res], 1
.Back		popad
			mov ebx, [usbfat32_cluster_num1]		; the new cluster of the dir or file
			ret

; IN: EBX(clusternum; eg. 2 for RootDir)
; OUT: EBX(new clusternum)
; 1.finds free cluster in FAT
; 2.reads 1 sector from FAT (which contains the current cluster)
; 3.adds new cluster to chain
; 4.writes sector to disk
usbfat32_add_new_cluster:
			pushad
			mov DWORD [usbfat32_res], 0
			mov [usbfat32_cluster_num2], ebx					 ; save current clusternum
	; IN: usbfat32_next_free_cluster_num (if UNKNOWN --> search starts from zero)
	; OUT: EBX, usbfat32_res
	; writes ENDCLUS to FAT
			call usbfat32_get_free_cluster						; new clusternum in EBX
			cmp DWORD [usbfat32_res], 1
			jz	.Calc
			mov ebx, usbfat32_GetFreeClusErrTxt
			call gstdio_draw_text
			jmp	.Back
.Calc		mov DWORD [usbfat32_res], 0
			mov edi, ebx									; new clusternum in EDI
			mov ebx, [usbfat32_cluster_num2]
			mov ebp, ebx
			and ebp, USBFAT32_OFFSET_WITHIN_SECTOR_MASK
			shl ebp, 2										; the offset is in DWORDS
			shr ebx, 7										; EBX: sectornumber in FAT
	; IN: EBX(lbaLo)
	; OUT: usb_res(0 if ok)
			call usbfat32_read_fat	
			cmp DWORD [usb_res], 1
			jz	.Wr
			mov ebx, usbfat32_ReadFATErrTxt
			call gstdio_draw_text
			jmp	.Back
.Wr			mov esi, USBFAT32_SECTOR_BUFF
			add esi, ebp
			mov [esi], edi									; set new clusternum in FAT-table
	; IN: EBX(lbaLo)
	; OUT: usb_res(0 if ok)
			call usbfat32_write_fat
			cmp DWORD [usb_res], 1
			jz	.Ok
			mov ebx, usbfat32_WriteFATErrTxt
			call gstdio_draw_text
			jmp	.Back
.Ok			mov [usbfat32_cluster_num2], edi					 ; set new clusternum
			mov DWORD [usbfat32_res], 1
.Back		popad
			mov ebx, [usbfat32_cluster_num2]					; set new clusternum
			ret


; IN: usbfat32_next_free_cluster_num (if UNKNOWN --> search starts from zero)
; OUT: EBX, usbfat32_res
; finds free(i.e. 0) in FAT, and writes EndOfClusterMarker to it
usbfat32_get_free_cluster:	
			push edx
			push esi
			mov DWORD [usbfat32_res], 0
			mov ebx, [usbfat32_next_free_cluster_num]
			cmp ebx, USBFAT32_FSINFO_UNKNOWN
			jne	.Find
	; IN: EBX(cluster-num to start the search from); EDX(sectornum to end the search)
	; OUT: EBX(first free cluster-num); ESI(ptr to cluster-num in sector), usb_res
			mov ebx, 3							; skip first two unused clusternum and rootdirclusternum
.Find		mov edx, [usbfat32_sectors_per_fat]
			call usbfat32_find_free_cluster_num
			cmp DWORD [usb_res], 1
			jz	.Comp
			mov ebx, usbfat32_FindFreeClusErrTxt
			call gstdio_draw_text
			jmp	.Back
.Comp		cmp ebx, edx	;[usbfat32_sectors_per_fat]
			jc	.Write						; jump if unsigned smaller
			cmp DWORD [usbfat32_next_free_cluster_num], USBFAT32_FSINFO_UNKNOWN
			jne	.SearchBeg
			mov ebx, usbfat32_NextFreeClusNumUnkErrTxt
			call gstdio_draw_text
			jmp	.Back
	;!!!???
		; Search from the beginning of FAT till next_free_cluster_num, if no free was found and search not started from the beginning
	; IN: EBX(cluster-num to start the search from); EDX(sectornum to end the search)
	; OUT: EBX(first free cluster-num); ESI(ptr to cluster-num in sector), usbfat32_res
.SearchBeg	mov ebx, 3							; skip first two unused clusternum and rootdirclusternum
			mov edx, [usbfat32_next_free_cluster_num]
			call usbfat32_find_free_cluster_num
			cmp DWORD [usb_res], 1
			jz	.Comp2
			mov ebx, usbfat32_FindFreeClusErrTxt
			call gstdio_draw_text
			jmp	.Back
.Comp2		cmp ebx, edx	;[usbfat32_next_free_cluster_num]
			je	.Back
.Write		mov DWORD [esi], USBFAT32_END_OF_CLUSTER_MARKER
			push ebx
			shr	ebx, 7										; to get sector-number
	; IN: EBX(lbaLo)
	; OUT: usb_res(0 if ok)
			call usbfat32_write_fat
			pop ebx
			cmp DWORD [usb_res], 1
			jz	.Ok
			mov ebx, usbfat32_WriteFATErrTxt
			call gstdio_draw_text
			jmp	.Back
.Ok			mov DWORD [usbfat32_res], 1
.Back		pop esi
			pop edx
			ret


; IN: EBX(cluster-num to start the search from); EDX(sectornum to end the search)
; OUT: EBX(first free cluster-num); ESI(ptr to cluster-num in sector), usb_res
usbfat32_find_free_cluster_num:
			push edx
			push ebp
			mov ebp, ebx
			and ebp, USBFAT32_OFFSET_WITHIN_SECTOR_MASK
			shl ebp, 2										; the offset is in DWORDS
			shr	ebx, 7										; to get sector-number
			mov esi, USBFAT32_SECTOR_BUFF
			add esi, ebp
			cmp ebx, 0										; 0th sectorNum?
			jnz	.NextSect
			cmp ebp, 8										; if in the 0th sector, check if greater than the two unused sectorNums
			jnc	.NextSect									; jump if unsigned greater or equal
			push eax										; this makes search from the rootdirclusnum, if <2 was given
			mov eax, 8
			sub eax, ebp
			add esi, eax
			pop eax
	; IN: EBX(lbaLo)
	; OUT: usb_res(0 if ok)
.NextSect	call usbfat32_read_fat
			cmp DWORD [usb_res], 1
			jz	.ClearPIT
			mov ebx, usbfat32_ReadFATErrTxt
			call gstdio_draw_text
			jmp	.Back
.ClearPIT	mov DWORD [pit_task_ticks], 0					; clear pit-ticks 
.Read		cmp DWORD [esi], 0
			je	.Fnd
			add esi, 4
			cmp esi, USBFAT32_SECTOR_BUFF+USBFAT32_BYTES_SECTOR
			jne	.Read
			mov esi, USBFAT32_SECTOR_BUFF
			inc ebx
			cmp ebx, edx
			jc	.NextSect
			jmp .Back
.Fnd		shl ebx, 7						; *128 (clusternumbers per sector)
			mov edx, esi
			sub edx, USBFAT32_SECTOR_BUFF
			shr edx, 2						; /4 to get DWORDs
			add ebx, edx					; ebx contains the cluster_num to be set
.Back		pop ebp
			pop edx
			ret


; IN: EBX(clusternum to read)
; OUT: ECX(number of consecutive clusters); EDX(the next clusternumber after the consecutive ones)
; i.e. in case of clusters: 3,4,5,6,9,10	(3 is from the dir-entry, the rest are in FAT)
;	calling this func with clusnum 3, it returns with ECX(4) and EDX(9)
usbfat32_get_consec_cluster_num:
			push eax
			push ebx
			mov eax, ebx						; save orig clusternum
			xor ecx, ecx
	; IN: EBX(clusternum)
	; OUT: usbfat32_res, EBX(clusternum)
.Next		call usbfat32_get_next_cluster_num	
			cmp DWORD [usbfat32_res], 1
			jz	.Inc
			mov ebx, usbfat32_GetNextClusNumErrTxt
			call gstdio_draw_text
			jmp	.Back
.Inc		inc ecx
			cmp ebx, USBFAT32_END_OF_CLUSTER_MARKER
			je	.Back
			cmp cx, [usbfat32_max_clusters_num_per_word]		; == 65535/sectors_per_cluster ? (only 16-bit sectorcnt is used)
			je	.Back
			push ecx
			add ecx, eax
			cmp ebx, ecx
			pop ecx
			je	.Next
.Back		mov edx, ebx
			pop ebx
			pop eax
			ret


; IN: EBX(clusternum)
; OUT: EAX
usbfat32_cluster2lba:
			push ebx
			push edx
			sub ebx, 2
			xor eax, eax
			mov al, [usbfat32_sectors_per_cluster]
			mul ebx
			add eax, [usbfat32_cluster_begin_lba]
			pop edx
			pop ebx
			ret


; IN: EBX(clusternum)
; OUT: usbfat32_res, EBX(clusternum)
usbfat32_get_next_cluster_num:
			mov DWORD [pit_task_ticks], 0					; clear pit-ticks (Or call PAUSE!?)
			push eax
			push ecx
			push edx
			push ebp
			push esi
			mov DWORD [usbfat32_res], 0
			mov ebp, ebx
			and ebp, USBFAT32_OFFSET_WITHIN_SECTOR_MASK
			shl ebp, 2										; the offset is in DWORDS
			shr ebx, 7										; EBX: sectornumber in FAT
	; IN: EBX(lbaLo)
	; OUT: usb_res(0 if ok)
			call usbfat32_read_fat
			cmp DWORD [usb_res], 1
			jz	.Calc
			mov ebx, usbfat32_ReadFATErrTxt
			call gstdio_draw_text
			jmp	.Back
.Calc		mov esi, USBFAT32_SECTOR_BUFF
			add esi, ebp
			mov ebx, [esi]
			mov DWORD [usbfat32_res], 1
.Back		pop esi
			pop ebp
			pop edx
			pop ecx
			pop eax
			ret


; IN: EBX(lbaLo)
; OUT: usb_res(1 if ok)
usbfat32_read_fat:
			mov DWORD [usb_res], 0
			cmp ebx, [usbfat32_curr_sector_num]				; Sector already in memory? If yes don't read. Note that we don't check lbaHI
			je	.Ok
			mov [usbfat32_curr_sector_num], ebx				; Note that we don't save lbaHI
			push eax
			push ebx
			push ecx
			push ebp
	; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
			add ebx, [usbfat32_fat_begin_lba]
			xor eax, eax
			mov ecx, USBFAT32_SECTOR_BUFF
			mov edx, 1
			call usb_read_msd
			sub ebx, [usbfat32_fat_begin_lba]			; !?
			pop ebp
			pop ecx
			pop ebx
			pop eax
			jmp .Back
.Ok			mov DWORD [usb_res], 1
.Back		ret


; IN: EBX(lbaLo)
; OUT: usb_res(1 if ok)
usbfat32_write_fat:
			push eax
			push ebx
			push ecx
			push ebp
	; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
			add ebx, [usbfat32_fat_begin_lba]
			xor eax, eax
			mov ecx, USBFAT32_SECTOR_BUFF
			mov edx, 1
			call usb_write_msd
			sub ebx, [usbfat32_fat_begin_lba]			; !?
			pop ebp
			pop ecx
			pop ebx
			pop eax
			ret


usbfat32_read_fsinfo:
			pushad
			mov DWORD [usbfat32_res], 0
	; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
			xor eax, eax
			mov ebx, [usbfat32_partition_lba_begin]
			add ebx, [usbfat32_fsinfo_sector]
			mov ecx, USBFAT32_SECTOR_BUFF
			mov edx, 1
			call usb_read_msd
			cmp DWORD [usb_res], 1
			jz	.Prep
			mov ebx, usbfat32_DiskReadErrTxt
			call gstdio_draw_text
			jmp	.Back
.Prep		mov [usbfat32_curr_sector_num], ebx					; Note that we don't save lbaHI
			mov esi, USBFAT32_SECTOR_BUFF
			add esi, USBFAT32_FSINFO_LEADSIG_OFFS
			cmp DWORD [esi], USBFAT32_FSINFO_LEADSIG
			jne	.Back
			sub esi, USBFAT32_FSINFO_LEADSIG_OFFS
			add esi, USBFAT32_FSINFO_STRUCSIG_OFFS
			cmp DWORD [esi], USBFAT32_FSINFO_STRUCSIG
			jne	.Back
			sub esi, USBFAT32_FSINFO_STRUCSIG_OFFS
			add esi, USBFAT32_FSINFO_TRAILSIG_OFFS
			cmp DWORD [esi], USBFAT32_FSINFO_TRAILSIG
			jne	.Back
			sub esi, USBFAT32_FSINFO_TRAILSIG_OFFS
			add esi, USBFAT32_FSINFO_FREECLUSTERCNT_OFFS
			mov eax, [esi]
			mov [usbfat32_free_clusters_cnt], eax				; should we check the value aginst disk size?
			sub esi, USBFAT32_FSINFO_FREECLUSTERCNT_OFFS
			add esi, USBFAT32_FSINFO_NEXTFREECLUSTERNUM_OFFS
			mov eax, [esi]
			; check value
			cmp eax, USBFAT32_FSINFO_UNKNOWN
			je	.StoreCN
			mov ebx, [usbfat32_sectors_per_fat]					; check
			shl	ebx, 7											; *128 to get number of clusters
			cmp eax, ebx
			jnc	.Back
.StoreCN	mov [usbfat32_next_free_cluster_num], eax
			mov DWORD [usbfat32_res], 1
.Back		popad
			ret


usbfat32_write_fsinfo:
			pushad
			mov DWORD [usbfat32_res], 0
			mov eax, [usbfat32_free_clusters_cnt]
			mov ebx, [usbfat32_next_free_cluster_num]
			call usbfat32_read_fsinfo
			cmp DWORD [usbfat32_res], 1
			jz	.Prep
			mov ebx, usbfat32_ReadFSInfoErrTxt
			call gstdio_draw_text
			jmp	.Back
.Prep		mov DWORD [usbfat32_res], 0
			mov [usbfat32_free_clusters_cnt], eax
			mov [usbfat32_next_free_cluster_num], ebx
			mov esi, USBFAT32_SECTOR_BUFF
			add esi, USBFAT32_FSINFO_FREECLUSTERCNT_OFFS
			mov [esi], eax
			sub esi, USBFAT32_FSINFO_FREECLUSTERCNT_OFFS
			add esi, USBFAT32_FSINFO_NEXTFREECLUSTERNUM_OFFS
			mov [esi], ebx
			; write
	; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
			xor eax, eax
			mov ebx, [usbfat32_partition_lba_begin]
			add ebx, [usbfat32_fsinfo_sector]
			mov ecx, USBFAT32_SECTOR_BUFF
			mov edx, 1
			call usb_write_msd
			cmp DWORD [usb_res], 1
			jz	.Wr
			mov ebx, usbfat32_DiskWriteErrTxt
			call gstdio_draw_text
			jmp	.Back
			; write copy of FSInfo-sector
	; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
.Wr			xor eax, eax
			mov ebx, [usbfat32_partition_lba_begin]
			add ebx, [usbfat32_copy_boot_sector]
			inc ebx
			mov ecx, USBFAT32_SECTOR_BUFF
			mov edx, 1
			call usb_write_msd
			cmp DWORD [usb_res], 1
			jz	.Ok
			mov ebx, usbfat32_DiskWriteErrTxt
			call gstdio_draw_text
			jmp	.Back
.Ok			mov DWORD [usbfat32_res], 1
.Back		popad
			ret


; IN: EBX(addrofname, first byte is length)
; OUT: ECX(len), usbfat32_name_buff (zero at the end)
usbfat32_copy_name:
			push ebx
			push esi
			push edi
			xor ecx, ecx
			mov cl, [ebx]
			push ecx
			inc ebx
			mov esi, ebx
			mov edi, usbfat32_name_buff
			rep movsb
			pop ecx
			mov BYTE [edi], 0						; put a zero at the end
			pop edi
			pop esi
			pop ebx
			ret


; IN: ECX(len), usbfat32_name_buff
; OUT: ECX(len, 0 if error), usbfat32_name_buff
; removes trailing spaces and/or dots (LFN).
;usbfat32_filter_name:
;.Next		cmp BYTE [usbfat32_name_buff+ecx-1], '.'
;			je	.Change
;			cmp BYTE [usbfat32_name_buff+ecx-1], ' '
;			jne	.Back
;.Change		mov BYTE [usbfat32_name_buff+ecx-1], 0
;			loop .Next
;.Back		ret


; IN: usbfat32_name_buff
; OUT: usbfat32_sfn_buff
; creates short-filename (8.3) from given filename
;1. A SFN filename can have at most 8 characters before the dot. If it has more than that, you should write the first 6, then 
;   put a tilde ~ as the seventh character and a number (usually 1) as the eighth. The number distinguishes it from other files with 
;   both the same first six letters and the same extension.
;2. Dots are important and must be used even for folder names (if there is a dot in the folder name). If there are multiple dots 
;   in the long file/directory name, only the last one is used. The preceding dots should be ignored. If there are more characters 
;   than three after the final dot, only the first three are used.
;3. Generally:
; - Any spaces in the filenames should be ignored when converting to SFN.
; - Ignore all periods except the last one. Do not include any other periods, just like the spaces. Use the last period if any, 
;   and the next characters (up to 3). For instance, for .manifest you would use .man only.
; - Commas, square brackets, semi colons, = signs and + signs are changed to underscores.
; - Case is not important, upper case and lower case characters are treated equally.
usbfat32_create_sfn:
			pushad
			mov ebp, -1								; EBP is the place of the last dot
			xor ecx, ecx
			; find last dot
.NextD		cmp BYTE [usbfat32_name_buff+ecx], 0
			je	.OutD
			cmp BYTE [usbfat32_name_buff+ecx], '.'
			jne	.IncD
			mov ebp, ecx
.IncD		inc ecx
			jmp .NextD
			; calc length till dot, or if no dot then till 0 (without space or dots)
.OutD		mov ebx, ecx
			xor ecx, ecx
			xor esi, esi								; ESI will be the length
			cmp ebp, -1
			je	.NextL
			mov ebx, ebp
.NextL		cmp BYTE [usbfat32_name_buff+ecx], ' '
			je	.IncL
			cmp BYTE [usbfat32_name_buff+ecx], '.'
			je	.IncL
			inc	esi
.IncL		inc ecx
			cmp ecx, ebx
			jne .NextL
			; copy name
.Copy		xor eax, eax
			xor ecx, ecx
			xor edx, edx
			mov ebx, 8
.Next		cmp BYTE [usbfat32_name_buff+ecx], 0
			je	.Fill
			cmp BYTE [usbfat32_name_buff+ecx], '.'
			je	.ChkDot
			cmp BYTE [usbfat32_name_buff+ecx], ' '
			je	.IncN
			mov al, [usbfat32_name_buff+ecx]
			cmp al, ','
			je	.Change
			cmp al, '['
			je	.Change
			cmp al, ']'
			je	.Change
			cmp al, ';'
			je	.Change
			cmp al, '='
			je	.Change
			cmp al, '+'
			jne	.Store
.Change		mov al, '_'
.Store		call gutil_toupper
			mov [usbfat32_sfn_buff+edx], al
			inc	edx
.IncN		inc	ecx
			cmp edx, ebx
			jne	.Next
			cmp ebx, 11
			je	.Close
			cmp esi, 8
			jng	.Ext
			mov BYTE [usbfat32_sfn_buff+6], '~'
			mov BYTE [usbfat32_sfn_buff+7], 0x31			; '1'
.Ext		cmp ebp, -1
			je	.Close
			mov ecx, ebp
			inc ecx
			mov ebx, 11
			jmp .Next
.ChkDot		cmp ecx, ebp		; last dot?
			jne	.IncN
.Fill		cmp edx, ebx		; fill with spaces
			je	.Done
			mov BYTE [usbfat32_sfn_buff+edx], ' '
			inc	edx
			jmp	.Fill
.Done		cmp ebx, 8
			jne	.Close
			cmp ebp, -1
			jne	.Ext
			mov ebx, 11
			jmp .Fill
.Close		mov BYTE [usbfat32_sfn_buff+11], 0
			popad
			ret


; IN: usbfat32_sfn_buff
; OUT: usbfat32_sfn_buff
; Changes commas, square brackets, semi colons, = signs and + signs to underscores.
;usbfat32_filter_sfn:
;			push esi
;			mov esi, usbfat32_sfn_buff
;.Next		cmp BYTE [esi], ','
;			je	.Change
;			cmp BYTE [esi], '['
;			je	.Change
;			cmp BYTE [esi], ']'
;			je	.Change
;			cmp BYTE [esi], ';'
;			je	.Change
;			cmp BYTE [esi], '='
;			je	.Change
;			cmp BYTE [esi], '+'
;			jne	.Inc
;.Change	mov BYTE [esi], '_'
;.Inc		inc esi
;			cmp	BYTE [esi], 0
;			jne	.Next
;			pop esi
;			ret


; IN: ESI(address of entry (32-bytes)), usbfat32_name_buff(address of chars of the name)
; OUT: usbfat32_res(1 is match)
usbfat32_compare_sfn:
			pushad
			mov DWORD [usbfat32_res], 0
			mov edi, usbfat32_sfn_buff
			call gutil_strlen
			mov ebp, ecx
			mov edi, usbfat32_name_buff
			call gutil_strlen
			cmp ecx, ebp
			jnz	.Back
			mov esi, usbfat32_sfn_buff
			mov edi, usbfat32_name_buff
			call gutil_strcmp
			cmp eax, 0
			jnz	.Back
			mov DWORD [usbfat32_res], 1
.Back		popad
			ret


; IN: USBFAT32_NAME_BUFF, USBFAT32_CHARS_MAX_NUM, usbfat32_name_buff(address of chars of the name)
; OUT: usbfat32_res(1 is match)
usbfat32_compare_lfn:
			pushad	
			mov DWORD [usbfat32_res], 0
			mov eax, USBFAT32_CHARS_MAX_NUM
			shr	eax, 1
			xor ebx, ebx
			mov bl, [usbfat32_name_entries_num]
			mul ebx										; number of max. chars in EAX (is there always a 0000h at the end?)
			mov edi, USBFAT32_NAME_BUFF
			call usbfat32_unistrlen
			mov ebp, ecx
			mov edi, usbfat32_name_buff
			call gutil_strlen
			cmp ecx, ebp
			jnz	.Back
			mov esi, USBFAT32_NAME_BUFF
			mov edi, usbfat32_name_buff
.Next		mov bl, [edi]
			cmp bl, 0
			jz	.Match
			cmp BYTE [esi+1], 0
			jnz	.Skip									; skip unicode char
			cmp BYTE [esi], 126
			ja	.Skip									; skip charASCII > 126
			cmp [esi], bl
			jnz	.Back
.Skip		add esi, 2
			inc edi
			jmp .Next
.Match		mov DWORD [usbfat32_res], 1
.Back		popad
			ret			



; IN: EDI(addr of 2-byte chars), EAX(max. charnum; because there is not always a 0x0000 terminator !?)
; OUT: ECX(length)
usbfat32_unistrlen:
			push edi
			xor ecx, ecx
.Next		cmp WORD [edi], 0
			jz	.Back
			add edi, 2
			inc ecx
			cmp ecx, eax
			jnz	.Next
.Back		pop edi
			ret


; IN: ESI(address of entry (32-bytes))
; OUT: usbfat32_sfn_buff
usbfat32_copy_sfn:
			pushad
			xor ecx, ecx
.Next		mov al, [esi+ecx]
			mov BYTE [usbfat32_sfn_buff+ecx], al
			inc ecx
			cmp BYTE [esi+ecx], 32						; space?
			jz	.Ext
			cmp ecx, 8
			jz	.Ext
			jmp .Next
			; extension
.Ext		cmp BYTE [esi+8], 32						; is there an extension?
			je	.Back
			mov BYTE [usbfat32_sfn_buff+ecx], '.'
			mov edx, 8
			inc ecx
.NextExt	mov al, [esi+edx]
			mov BYTE [usbfat32_sfn_buff+ecx], al
			inc ecx
			inc edx
			cmp edx, 11
			je	.Back
			cmp BYTE [esi+edx], 32
			jne	.NextExt
.Back		mov BYTE [usbfat32_sfn_buff+ecx], 0
			popad
			ret


; IN: ESI(address of LFN-entry)
; OUT: USBFAT32_NAME_BUFF
usbfat32_copy_lfn_entry:
			pushad
			xor eax, eax
			mov al, [esi+USBFAT32_ENTRY_IND]
			and al, 0x0F
			dec eax
			mov ebx, USBFAT32_CHARS_MAX_NUM
			mul	ebx
			add eax, USBFAT32_NAME_BUFF
			mov edi, eax
			; copy chars to name-buffer (at the idx given in AL)
				; first chars
			push esi
			add esi, USBFAT32_ENTRY_NAME1
			mov ecx, 5
			rep movsw
			pop esi
				; next  chars
			push esi
			add esi, USBFAT32_ENTRY_NAME2
			mov ecx, 6
			rep movsw
			pop esi
				; next  chars
			push esi
			add esi, USBFAT32_ENTRY_NAME3
			mov ecx, 2
			rep movsw
			pop esi
			inc BYTE [usbfat32_name_entries_num]
			popad
			ret


; IN: usbfat32_sfn_buff
usbfat32_print_sfn:
			pushad
			xor ecx, ecx
			xor ebx, ebx
			mov esi, usbfat32_sfn_buff
.Next		mov bl, [esi]
			cmp bl, 0
			jz	.Sepa
			cmp bl, 126
			jna	.Draw
			mov bl, USBFAT32_UNICODE_SUBSTITUTE_CHAR		; substitute ASCII > 126 (FOS has char '~' as the last char)
.Draw		call gstdio_draw_char
			inc esi
			jmp .Next
.Sepa		xor ebx, ebx
			mov bl, ' '
			call gstdio_draw_char
.Back		popad
			ret


; IN: USBFAT32_NAME_BUFF
usbfat32_print_lfn:
			pushad
			xor ebx, ebx
			mov esi, USBFAT32_NAME_BUFF
			mov eax, USBFAT32_CHARS_MAX_NUM
			shr	eax, 1
			mov bl, [usbfat32_name_entries_num]
			mul ebx
			xor ebx, ebx
.Next		cmp WORD [esi], 0
			jz	.Fin
			mov bl, [esi]
			cmp BYTE [esi+1], 0
			jnz	.Subs										; Substitute unicode char
			cmp bl, 126
			ja	.Subs										; substitute ASCII > 126 (FOS has char '~' as the last char)
			jmp .Draw
.Subs		mov bl, USBFAT32_UNICODE_SUBSTITUTE_CHAR
.Draw		call gstdio_draw_char
			dec eax
			add esi, 2
			cmp eax, 0
			jnz .Next
.Fin		xor ebx, ebx
			mov bl, ' '
			call gstdio_draw_char
.Back		popad
			ret


; IN: ESI(ptr to entry), EBP(date-offset in record)
usbfat32_print_date:
			pushad
			xor eax, eax
			mov ax, [esi+ebp]
			shr ax, 9
			add eax, 1980
			call gstdio_draw_dec
			xor ebx, ebx
			mov bl, USBFAT32_DATE_SEPARATOR_CHAR
			call gstdio_draw_char
			mov ax, [esi+ebp]
			and ax, 0x01E0
			shr ax, 5
			call gstdio_draw_dec
			mov bl, USBFAT32_DATE_SEPARATOR_CHAR
			call gstdio_draw_char
			mov ax, [esi+ebp]
			and ax, 0x001F
			call gstdio_draw_dec
			mov ebx, ' '
			call gstdio_draw_char
			popad
			ret


section .data

; partition
usbfat32_partition_type_code	db	0
usbfat32_partition_lba_begin	dd	0
usbfat32_partition_sectors_cnt	dd	0

; VolumeID
usbfat32_bytes_per_sector		dw	0		; these variables(6 bytes) will be filled by "rep movsb"
usbfat32_sectors_per_cluster	db	0
usbfat32_reserved_sectors_num	dw	0
usbfat32_fats_num				db	0

usbfat32_sectors_per_fat	dd	0
usbfat32_root_dir_cluster	dd	0
usbfat32_fsinfo_sector		dd	0
usbfat32_copy_boot_sector	dd	0

usbfat32_max_clusters_num_per_word	dw	0

;	fat_begin_lba(DWORD)			= Partition_LBA_begin + Number_Of_Reserved_Sectors
;	cluster_begin_lba(DWORD)		= Partition_LBA_begin + Number_Of_Reserved_Sectors + (Number_Of_FATs * Sectors_Per_FAT)
;	sectors_per_cluster(BYTE)		= Sectors Per Cluster
;	root_dir_first_cluster(DWORD)	= Root Dir First Cluster
usbfat32_fat_begin_lba			dd	0
usbfat32_cluster_begin_lba		dd	0
usbfat32_root_dir_lba			dd	0
;lba_addr = cluster_begin_lba + (cluster_number - 2) * sectors_per_clusters

usbfat32_dir_entries_per_cluster_num	dd	0

usbfat32_cluster_num1	dd	0			; to store clusternum temporarily
usbfat32_cluster_num2	dd	0			; to store clusternum temporarily

usbfat32_next_clusnum	dd 0

usbfat32_name_entries_num	db	0		; number of entries in the name-array (1 entry is 13, 2-byte chars)
usbfat32_fs_inited	db	0

usbfat32_memaddr		dd 0
usbfat32_filesize		dd 0

usbfat32_long_list	db 0

usbfat32_name_buff	times USBFAT32_MAX_NAME_LEN db 0

usbfat32_sfn_buff	times 13 db	0		; the name+'.'+extension will be copied here (spaces skipped) with a zero put at the end

usbfat32_file_size		dd 0
usbfat32_clusters_cnt	dd 0

usbfat32_curr_sector_num	dd -1						; we don't want to load the same sector several times

usbfat32_res		dd	0			; holds result

usbfat32_add_dir_end	db 0

; FSInfo structure (sector 1 and its copy is in sector 7)
usbfat32_free_clusters_cnt		dd 0
usbfat32_next_free_cluster_num	dd USBFAT32_FSINFO_UNKNOWN

; for usbfat32_fsinfo
usbfat32_FSInfoTxt				db "FSInfo(data in hex):", 0x0A, 0
usbfat32_TotalSectorsTxt		db "Total sectors: ", 0
usbfat32_FATBeginLBATxt			db "FAT begin LBA: ", 0
usbfat32_ClustersBeginLBATxt	db "Clusters begin LBA: ", 0
usbfat32_SectorsPerFATTxt		db "Sectors per FAT: ", 0
usbfat32_SectorsPerClusterTxt	db "Sectors per cluster: ", 0
usbfat32_FreeClustersCountTxt	db "Free clusters count: ", 0
usbfat32_FirstFreeClusterNumTxt	db "Most recently allocated clusternum: ", 0

; errors
usbfat32_DiskReadErrTxt			db "USBFAT32: Disk read error!", 0x0A, 0
usbfat32_DiskWriteErrTxt		db "USBFAT32: Disk write error!", 0x0A, 0
usbfat32_SectorByteCntErrTxt	db "USBFAT32: Sector byte-count error!", 0x0A, 0
usbfat32_FATCntErrTxt			db "USBFAT32: FAT count error!", 0x0A, 0
usbfat32_SigErrTxt				db "USBFAT32: Signature error!", 0x0A, 0
usbfat32_ReadFSInfoErrTxt		db "USBFAT32: ReadFSInfo error!", 0x0A, 0
usbfat32_FSNotInitedErrTxt		db "USBFAT32: FS not inited error!", 0x0A, 0
usbfat32_ReadFATErrTxt			db "USBFAT32: Read FAT error!", 0x0A, 0
usbfat32_ReadClusErrTxt			db "USBFAT32: Read Cluster error!", 0x0A, 0
usbfat32_GetNextClusNumErrTxt	db "USBFAT32: Get next cluster number error!", 0x0A, 0
usbfat32_ReadCurrDirErrTxt		db "USBFAT32: Read current directory error!", 0x0A, 0
usbfat32_GetConsecClusNumErrTxt	db "USBFAT32: Get consec cluster num error!", 0x0A, 0
usbfat32_NameAlreadyExistsErrTxt	db "USBFAT32: Name already exists error!", 0x0A, 0
usbfat32_CreateDirEntryErrTxt	db "USBFAT32: Create directory entry error!", 0x0A, 0
usbfat32_AddNewClusterErrTxt	db "USBFAT32: Add new cluster error!", 0x0A, 0
usbfat32_WriteFSInfoErrTxt		db "USBFAT32: Write FSInfo error!", 0x0A, 0
usbfat32_GetFreeClusErrTxt		db "USBFAT32: Get free cluster error!", 0x0A, 0
usbfat32_FindFreeClusErrTxt		db "USBFAT32: Find free cluster error!", 0x0A, 0
usbfat32_FreeClusCntUnkTxt		db "USBFAT32: Free clusters-count unknown, error!", 0x0A, 0
usbfat32_NoFreeClusErrTxt		db "USBFAT32: No free cluster error!", 0x0A, 0
usbfat32_EndOfClusMarkerFndTxt	db "USBFAT32: End of cluster marker found error!", 0x0A, 0
usbfat32_WriteFATErrTxt			db "USBFAT32: Write FAT error!", 0x0A, 0
usbfat32_NextFreeClusNumUnkErrTxt	db "USBFAT32: NextFreeClusterNumber is unknown error!", 0x0A, 0


%endif


