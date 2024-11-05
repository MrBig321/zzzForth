;************************
; USB
;************************

%ifndef __FORTH_USB__
%define __FORTH_USB__


%include "forth/common.asm"
%include "usb/usb.asm"


;*************************************************
; _usb_devinfo			USBDEVINFO
;	( devaddr idx -- flag )
; idx=0: print nothing
; idx=1: print device-descriptor only
; idx=2: print all the descriptors to screen
;*************************************************
_usb_devinfo:
			POP_PS(edx)
			POP_PS(eax)
			call usb_dev_info
			cmp eax, 0
			jnz	.True
			PUSH_PS(FALSE)
			jmp .Back
.True		PUSH_PS(TRUE)
.Back			ret


;*************************************************
; _usb_ehci				USBEHCI
;	( -- )
;*************************************************
_usb_ehci:
			call usb_ehci
			ret


;*************************************************
; _usb_xhci				USBXHCI
;	( -- )
;*************************************************
_usb_xhci:
			call usb_xhci
			ret


;*************************************************
; _usb_driver			USBDRIVER
;	( -- n )
;  n is 0 for EHCI
;  n is 1 for XHCI
;*************************************************
_usb_driver:
			call usb_driver
			PUSH_PS(eax)
			ret


;*************************************************
; _usb_enum				USBENUM
;	( -- flag )
;*************************************************
_usb_enum:
			call usb_enum
			cmp eax, 0
			jnz	.True
			PUSH_PS(FALSE)
			jmp .Back
.True		PUSH_PS(TRUE)
.Back		ret


;*************************************************
; _usb_init_msd				USBINITMSD
;	( devaddr -- lbaHI lbaLO Sectorsize flag )
;	First call USBENUM, then USBDEVINFO, then call 
;	this word with the device address of the pen-drive
;	Puts the lba and the sectorsize 
;	of the drive on the pstack
;*************************************************
_usb_init_msd:
			POP_PS(eax)
			call usb_init_msd
			cmp eax, 0
			jz	.Err
			PUSH_PS(ebx)
			PUSH_PS(ecx)
			PUSH_PS(edx)
			PUSH_PS(TRUE)
			jmp .Back
.Err		PUSH_PS(0)
			PUSH_PS(0)
			PUSH_PS(0)
			PUSH_PS(FALSE)
.Back		ret


;*************************************************
; _usb_read				USBREAD
;	( lbaHI lbaLO memaddr #sectors -- flag )
;	First call USBENUM, USBDEVINFO, USBINITMSD, 
;	then call USBREAD
;	memaddr need to be page-aligned (last 3 digits zero)
;	The code aligns it for us if we don't
;	e.g. 200023 will be aligned to 201000
;*************************************************
_usb_read:
			POP_PS(edx)
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			call usb_read_msd
			cmp eax, 0
			jnz	.True
			PUSH_PS(FALSE)
			jmp .Back
.True		PUSH_PS(TRUE)
.Back		ret



;*************************************************
; _usb_write				USBWRITE
;	( lbaHI lbaLO memaddr #sectors -- flag )
;	First call USBENUM, USBDEVINFO, USBINITMSD, 
;	then call USBWRITE
;	memaddr need to be page-aligned (last 3 digits zero)
;	The code aligns it for us if we don't
;	e.g. 200023 will be aligned to 201000
;*************************************************
_usb_write:
			POP_PS(edx)
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			call usb_write_msd
			cmp eax, 0
			jnz	.True
			PUSH_PS(FALSE)
			jmp .Back
.True		PUSH_PS(TRUE)
.Back		ret


;*************************************************
; _usb_fs_init				USBFSINIT
;	( deviceaddress-- lbaHI lbaLO SectorSize flag )
;	Calls USBDEVINFO and USBINITMSD first, then
;	reads usb-filesystem data to variables
;*************************************************
_usb_fs_init:
			call _dup
			PUSH_PS(0)
			call _usb_devinfo
			POP_PS(eax)
			cmp eax, 0
			jz	.Err
			call _usb_init_msd
			cmp DWORD [esi], FALSE
			jz	.Back
			POP_PS(eax)
			call usb_fs_init
			cmp eax, 0
			jz	.False
			PUSH_PS(TRUE)
			jmp .Back
.Err		call _drop
			PUSH_PS(0)
			PUSH_PS(0)
			PUSH_PS(0)
.False		PUSH_PS(FALSE)
.Back		ret


;*************************************************
; _usb_fs_info					USBFSINFO
;	( -- flag )
;	Prints info about the filesystem on disk (FreeClusterCount and FirstFreeClusterNum).
;*************************************************
_usb_fs_info:
			call usb_fs_info
			cmp eax, 0
			jnz	.True
			PUSH_PS(FALSE)
			jmp .Back
.True		PUSH_PS(TRUE)
.Back		ret


;*************************************************
; _usb_fs_info_upd				USBFSINFOUPD
;	( -- flag )
; Updates the FSInfo-structure on disk (FreeClusterCount)
; It doesn't update the NextFreeClusterNum because NextFreeClusterNum is 
; the most recently allocated clusternum, but we don't know that now.
; NextFreeClusterNum is the clusternum the search for free cluster starts from.
; If we wrote to the filesystem and forgot to call USBFSREM right before removing the disk, 
; the FSInfo-structure on disk didn't get updated.
; Call USBFSINFOUPD to fix it.
; Note: this may take some time depending on the size of the drive, 
; because it scans the FAT-table	
;*************************************************
_usb_fs_info_upd:
			call usb_fs_info_upd
			cmp eax, 0
			jnz	.True
			PUSH_PS(FALSE)
			jmp .Back
.True		PUSH_PS(TRUE)
.Back		ret


;*************************************************
; _usb_fs_ls				USBFSLS
;	( flagIn -- flag )
;	Lists directory
;	If flgIn is True, long list will be printed 
;		(name, createdate, lastaccessdate, 
;			lastmodifdate, lengthInBytes)
;*************************************************
_usb_fs_ls:
			POP_PS(eax)
			cmp eax, TRUE
			jnz	.Skip
			mov eax, 1
.Skip		call usb_fs_ls
			cmp eax, 0
			jnz	.True
			PUSH_PS(FALSE)
			jmp .Back
.True		PUSH_PS(TRUE)
.Back		ret


;*************************************************
; _usb_fs_cd				USBFSCD
;	( "<spaces>name" -- flag ) 
;	changes to directory given by name
;	NOTE: " is the endofName character
;	e.g. if name is 3DProg , then 3DProg" need to 
;	be entered
;*************************************************
_usb_fs_cd:
			mov eax, '"'		; end of file/directory name character
			PUSH_PS(eax)
			call _word
			POP_PS(ebx)
			call usb_fs_cd
			cmp eax, 0
			jnz	.True
			PUSH_PS(FALSE)
			jmp .Back
.True		PUSH_PS(TRUE)
.Back		ret


;*************************************************
; _usb_fs_pwd				USBFSPWD
;	( -- flag ) 
; Prints path to current directory
;*************************************************
_usb_fs_pwd:
			call usb_fs_pwd
			cmp eax, 0
			jnz	.True
			PUSH_PS(FALSE)
			jmp .Back
.True		PUSH_PS(TRUE)
.Back		ret


;*************************************************
; _usb_fs_read			USBFSREAD
;	( memaddr "<spaces>name" -- lengthInBytes flag ) 
;	Reads a file from USB-FAT32 to memaddr (RAM)
;	NOTE: " is the endofName character
;	e.g. if name is boot.asm , then boot.asm" need to 
;	be entered
;	memaddr need to be page-aligned (last 3 digits zero)
;	The code aligns it for us if we don't
;	e.g. 200023 will be aligned to 201000
; HEX
; 20000000 USBFSREAD Astronomy.py" . .
;*************************************************
_usb_fs_read:
			mov eax, '"'		; end of file/directory name character
			PUSH_PS(eax)
			call _word
			POP_PS(ebx)
			POP_PS(eax)
			call usb_fs_read
			PUSH_PS(ecx)
			cmp eax, 0
			jnz	.True
			PUSH_PS(FALSE)
			jmp .Back
.True		PUSH_PS(TRUE)
.Back		ret


;*************************************************
; _usb_fs_write			USBFSWRITE
;	( memaddr sizeinbytes "<spaces>name" -- flag ) 
;	Writes bytes from memaddr to USB-FAT32.
;	NOTE: " is the endofName character
;	e.g. if name is boot.asm , then boot.asm" need to 
;	be entered
;	Name must be <= 8.3
;	memaddr need to be page-aligned (last 3 digits zero)
;	The code aligns it for us if we don't
;	e.g. 200023 will be aligned to 201000
; HEX
; 200000 1000 USBFSWRITE Test1234.txt" .
;*************************************************
_usb_fs_write:
			mov eax, '"'		; end of file/directory name character
			PUSH_PS(eax)
			call _word
			POP_PS(ebx)
			POP_PS(ecx)
			POP_PS(eax)
			call usb_fs_write
			cmp eax, 0
			jnz	.True
			PUSH_PS(FALSE)
			jmp .Back
.True		PUSH_PS(TRUE)
.Back		ret


;*************************************************
; _usb_fs_rem			USBFSREM
;	Updates FSInfo structure on the usb-disk
;	We need to call this function before we unplug the usb-disk
;	if we wrote to the filesystem (updates free-clustercnt and next-free-clusternum)
;*************************************************
_usb_fs_rem:
			call usb_fs_rem
			cmp eax, 0
			jnz	.True
			PUSH_PS(FALSE)
			jmp .Back
.True		PUSH_PS(TRUE)
.Back		ret


%endif


