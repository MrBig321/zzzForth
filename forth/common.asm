%ifndef __FORTH_COMMON__
%define __FORTH_COMMON__


%define	TRUE		-1
%define	FALSE		0

%define CHAR_SIZE	1
%define CELL_SIZE	4		; power of 2
%define CELL_SIZE_SHIFT	2	; for multiplications/divisions

%define FLOAT_CHAR	'.'		; if a number contains a dot, --> DCELL

%define SPACE_AFTER_WORDNAME		; if defined, a SPACE will be put after the name of the word in the dictionary
%define MAX_WORD_NAME_LEN	31		; (NOTE: TASK-name can be max 31 chars)

;%define FLOORED_DIVISION

%define DELIM	' '

%define BLOCK_BUFF_LEN 1024

%define INTERPRET			0
%define COMPILE				-1

; Length-byte (upper 4 bits: IMMEDIATE, COMP_ONLY, EXEC_ONLY)
%define COMP_ONLY	0x20
%define EXEC_ONLY	0x40
%define IMMEDIATE	0x80

%define	FLAGS_MASK	0xE0
%define	LENGTH_MASK	0x1F

; Errors
%define E_OK					0	; no error
%define E_NOINPUT				1	; no input available
%define E_NOWORD				2	; unknown word
%define E_NOCOMP				3	; word must be compiled
%define E_NOEXEC				4	; word must be executed
%define E_PSTK_UNDER			5	; parameter-stack underflow
%define E_PSTK_OVER				6	; parameter-stack overflow
%define E_RSTK_UNDER			7	; return-stack underflow
%define E_RSTK_OVER				8	; return-stack overflow
%define E_DSPACE_UNDER			9	; dictionary-space underflow
%define E_DSPACE_OVER			10	; dictionary-space overflow
%define E_NOPRIM				11	; primitive not implemented
%define E_COREWORD				12	; it's a core word
%ifdef HASHTABLE_DEF
	%define E_HASHTABLE_LISTFULL 	13	; List is full in hash-table
%endif

%define	DICT		0x300000		

%define PAD			(DICT+0x40000)

%define TIB			(PAD+0x1000)

%define DEF_TIB_SIZE	240

%define BLOCK_BUFF	0x220000

%ifdef HASHTABLE_DEF
	%define HASHTABLE		0x230000
	%define HASHLEN			10000
	%define HASHLISTLEN		16		; 8 Cells in slot (slot + 7 list) Must be power of 2 (faster multiplication)
	%define HASHSHIFT		4		; 2 to the power of 4 is HASHLISTLEN	
	%define HASHSIZE		(HASHLEN)*(HASHLISTLEN)	; in DWORDs
%endif

; Indices of System variables in the system-table:
; NOTE: PAD should also be a system-variable/constant but its value is computed
%define SYSTEM_SCRBUFF		0
%define SYSTEM_BKGFGCLR		1
%define SYSTEM_CHBKGCURRCLR	2
%define SYSTEM_OPAQUE		3
%ifndef MULTITASKING_DEF
	%define SYSTEM_SP0			4
	%define SYSTEM_SP			5
	%define SYSTEM_RSP0			6
	%define SYSTEM_RSP			7
	%define SYSTEM_BASE			8
	%define SYSTEM_SOURCEID		9
	%define SYSTEM_INPBUFF		10
	%define SYSTEM_ININPBUFF	11
	%define SYSTEM_TOIN			12
	%define SYSTEM_IP			13
	%define SYSTEM_BLK			14
	%define SYSTEM_SCR			15
	%define SYSTEM_ERROR		16
	%define SYSTEM_TMPBUFF		17
%endif

; Indices of System constants in the system-constants-table:
; NOTE: PAD should also be a system-variable/constant but its value is computed
%define SYSTEM_DP0			0
%define SYSTEM_SCRW			1
%define SYSTEM_SCRH			2
%define SYSTEM_FRAMEBUFF	3

%ifdef MULTITASKING_DEF
; USER vars
; A real user variable is e.g. "USER UARRAY" with INCUSER INCUSER ... we can have room for every CELL of the array!
; NOTE: _pstack should also be a USER-variable but a register has no address (see SP@)
; NOTE: SOURCE( -- inpbuff ininpbuff) supersedes #TIB !
	%define USER_SP0			0
	%define USER_SP				1
	%define USER_RSP0			2
	%define USER_RSP			3
	%define USER_BASE			4
	%define USER_SOURCEID		5
	%define USER_INPBUFF		6
	%define USER_ININPBUFF		7
	%define USER_TOIN			8
	%define USER_IP				9
	%define USER_BLK			10
	%define USER_SCR			11
	%define USER_ERROR			12
	%define USER_TMPBUFF		13
	%define USER_NUM			33	; !?			; s_tmp_buff is 80 bytes (i.e. 20 DWORDS)
%endif

%ifdef MULTITASKING_DEF
	%define TASKBUFF	(GSTDIO_OUTPBUFF+0xA000)	; address of taskbuff of TASK_MAX_NUM
	%define TASKLEN		4096		; length of task-struct
	%define PSTACKLEN	4096		; length of pstack
	%define RSTACKLEN	4096		; length of rstack
	%define STACKLEN	4096		; length of stack
	%define PSTACKBUFF	(TASKBUFF+TASKLEN*TASK_MAX_NUM)			; beginning of TASK_MAX_NUM pstacks
	%define RSTACKBUFF	(PSTACKBUFF+PSTACKLEN*TASK_MAX_NUM)		; beginning of TASK_MAX_NUM rstacks
	%define STACKBUFF	(RSTACKBUFF+RSTACKLEN*TASK_MAX_NUM)		; beginning of TASK_MAX_NUM stacks
%else
	%define PSTACKLEN	4096		; length of pstack
	%define RSTACKLEN	4096		; length of rstack
	%define STACKLEN	4096		; length of stack
	%define PSTACKBUFF	(GSTDIO_OUTPBUFF+0xA000)
	%define RSTACKBUFF	(PSTACKBUFF+PSTACKLEN)
	%define STACKBUFF	(RSTACKBUFF+RSTACKLEN)
%endif

; Subroutine-threaded code
; FOS is case-insensitive

;stacks(boot) not included
;Forth Memory map:
; 0x6FFE-	RAM_MAP_ENT_LOC	
; 0x7000-	RAM_MAP_LOC	
; 0x8100-	SECTOR_BUFF in boot.asm, boot/fat32.asm, hdfsboot, hdfsfat3216.asm (for reading 1 sector from FAT)
;; 0x8FEC-	hdfsloader.asm writes in 16-bit-mode a signature(DWORD) for kernel.asm to call fat32_init
; 0x8FF0-	FRAMEBUFF		from vga.asm
; 0x8FF4-	RAM_SIZE_LO_LOC	
; 0x8FF8-	RAM_SIZE_HI_LOC	
; 0x8FFC-	KERNEL_SIZE_LOC	
; 0x9000-	16-bit loader by boot.asm (loader.asm)
; 0xD000-	KernelIMAGEINREALMODEBASE(copy from in PM) (588KB space till 0xA0000) (enough space from 0x9000 for the loading proc)
; 0x100000- HDAudio Buffers (0x44000) (extra 0x1000 !?)
; 0x14D000-	ATA-driver uses 512 bytes for IDENTIFY and PCI uses 256 bytes 
; 0x14E000- ATA DMA PRDT
; 0x150000- DMA buffers for ATA (64kb)
; 0x170000- EHCI (0x30000 long !?)
; 0x200000-	Kernel
; 0x220000-	Block buffer (BLOCK_BUFF)
; 0x230000-	Hash-Table	(HASHLEN with a HASHLISTLEN list for each slot)
; 0x300000-	Dictionary	(DICT)
; DICT+0x40000-        Pad		(PAD) 
; PAD+0x1000-          Tib		(TIB)
; TIB+0x1000-   ScreenBuff in gstdio.asm	(1024*768*2 is bytenum) or (640*480*2 is bytenum)  (0x180000)
; ScreenBuff+0x180000- TextBuff	(1 screen)
; TextBuff+0x800-      OutpBuff	(20 screens for cmd-line)
; OutPBuff+A000-       Taskbuff	(TASKBUFF)		; Task-buffers (_tasklen*TASK_MAX_NUM) 
;  right after taskbuff starts the buffer of stacks (PSTACKBUFF, RSTACKBUFF)	; param, return for TASK_MAX_NUM tasks
;	after that the TASK_MAX_NUM stacks (all together 1638400 bytes [0x190000])
; 0x4CC800- FREE (142kB) 
; 0x4F0000- USBFAT32 PATH_BUFF
; 0x4F2000- USBFAT32 NAME_BUFF
; 0x4F3000- USBFAT32 SECTOR_BUFF
; 0x4F4000- USBFAT32 CLUSTER_BUFF
; .....   - FREE (depending on sectors/cluster)
; 0x600000- XHCI Heap
; 0xA00000- FREE (from 10MB)
; Address of FRAMEBUFFER at high memory


;Structure of a dictionary-entry (a word):
; dword(link)  [ALIGNED]
; byte(flags|length) bytes(chars(name)	[flags|length-byte is aligned]
; Code ptr (or execution token (xt)) [DWORD, Aligned]
; Parameter [DWORD, Aligned]	(in case of e.g. variable)

;Structure of a colon-definition dictionary-entry:  ( ':' )
; dword(link)  [ALIGNED]
; byte(flags|length) bytes(chars(name) [flags|length-byte is aligned]
; Code ptr (or execution token (xt)) [DWORD, Aligned]
; dptoxt-of-word1
; dptoxt-of-word2
;	...
; dptoxt-of-wordX
; dptoxt-of-Runtime-of-semi-colon i.e. (EXIT)

; dptoxt means dictionary pointer to xt. It's an indirection.


;Run-time(RT) words (begining end ending with paren) e.g.(colon) is the runtime code for colon-definition
;Note that the RT of a colon-def (i.e. (colon) ) will mean its xt. Only the definitions below it will be dptoxt-s!


;Task-struct (max TASK_MAX_NUM tasks):
; id, parentid, name(1byte(length)+31bytes), priority, state, dp, stackptr, user-vars  ; (length of a struct: _tasklen)
; Taskids are from 1-100. The main task has id 1, its parentid is 0 and its name is "Main".
; There is a dummy-task with id 2. This dummy-task just calls PAUSE. If the Main-task calls SLEEP, and there are no more tasks, 
; we can switch to the dummy-task.
; Currently parentid is updated but not used, i.e. if a task is killed, the tasks it created won't be killed.
; Currently priority is not used.
; dp is the dictionary-pointer (i.e. EBP). FORGET needs it. It kills the tasks that have greater dict-ptrs.


; parameter-stack
%macro PUSH_PS 1
		sub esi, CELL_SIZE
		mov DWORD [esi], %1
%endmacro

%macro POP_PS 1 
		mov %1, DWORD [esi]
		add esi, CELL_SIZE
%endmacro

; return-stack
%macro PUSH_RS 1
		sub edi, CELL_SIZE
		mov DWORD [edi], %1
%endmacro

%macro POP_RS 1 
		mov %1, DWORD [edi]
		add edi, CELL_SIZE
%endmacro

;//char*, aligns to int boundary (4 bytes)
;#define ALIGN_PTR(n)    	((((int)(n))+3) & ~ 0x03)
%macro ALIGN_PTR 1
		mov eax, %1
		add eax, DWORD CELL_SIZE-1
		mov ebx, DWORD CELL_SIZE-1
		not ebx
		and eax, ebx
%endmacro

%macro COMPILE_CELL 1
		mov DWORD [ebp], %1
		add ebp, CELL_SIZE
%endmacro

; gets dptoxt from name
%macro GET_DP_TO_XT 1
		mov eax, %1
		PUSH_PS(eax)
		call _find
		POP_PS(eax)		; drop flags|len
		POP_PS(eax)
%endmacro


; In: dptoFlags|Length-byte, Out: Next cell after chars of WORD.
; Adjusts dp so it will skip len-byte and 
; chars of the word
%macro WORD_PTR 1
		mov ebx, %1
		xor eax, eax
		mov al, BYTE [ebx]
		and al, LENGTH_MASK
		inc ebx				; to start of name
		add ebx, eax
%ifdef SPACE_AFTER_WORDNAME
		inc ebx				; skip DELIM
%endif
%endmacro

; We read a sentence in ." , (.") , S" and (S") and we use WORD.
; WORD_PTR applies LENGTH_MASK that is for a word, but we use WORD_PTR2 
; for reading a sentence or a text.
%macro WORD_PTR2 1
		mov ebx, %1
		xor eax, eax
		mov al, BYTE [ebx]
		inc ebx				; to start of name
		add ebx, eax
%ifdef SPACE_AFTER_WORDNAME
		inc ebx				; skip DELIM
%endif
%endmacro

%endif

