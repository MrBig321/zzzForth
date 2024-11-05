%ifndef __RAM__
%define __RAM__

%include "stdio16.asm"
;%include "util16.asm"

bits 16


; Memory from BIOS

; the same as in loader.asm, hdloader.asm, hdfsloader.asm, forth/hd.asm, ram.asm, kernel.asm (and MemMap in forth/common.asm)
%define	RAM_MAP_ENT_LOC		0x6FFE
%define	RAM_MAP_LOC			0x7000
%define	RAM_MAP_LINE_LEN	24


section .text

;*********************************************************************
; ram_get
;	OUT: ram_size_hi(upper 32-bits), ram_size_lo(lower 32-bits)
;*********************************************************************
ram_get:
			pusha
			mov di, ram_map
			call ram_get_map
			cmp DWORD [ram_map_ent], 0
			jz	.End
			cmp DWORD [ram_map_ent], 1		; if only 1 entry, then skip sorting and checking overlaping
			jz	.Adder
			; sorting (Bubble Sort)
			mov si, ram_map
.Again		mov dl, 0						; clear swapped
			mov cx, [ram_map_ent]
			dec cx
			xor bx, bx
.NextChk	mov eax, DWORD [ds:si+bx]
			cmp eax, DWORD [ds:si+bx+RAM_MAP_LINE_LEN]
			ja	.Swap						; unsigned jump!
			jmp .Next
.Swap		push cx
			add si, bx						; copy RAM_MAP_LINE_LEN bytes to temp. storage
			mov di, ram_map_tmp
			mov cx, RAM_MAP_LINE_LEN
			rep movsb
			mov si, ram_map					; copy RAM_MAP_LINE_LEN bytes from (x+1)th row to xth
			add si, bx
			add si, RAM_MAP_LINE_LEN
			mov di, ram_map
			add di, bx
			mov cx, RAM_MAP_LINE_LEN
			rep movsb
			mov si, ram_map_tmp				; copy RAM_MAP_LINE_LEN bytes from temp. storage
			mov di, ram_map
			add di, bx
			add di, RAM_MAP_LINE_LEN
			mov cx, RAM_MAP_LINE_LEN
			rep movsb
			pop cx
			mov si, ram_map
			mov dl, 1						; there was a swap
.Next		add bx, RAM_MAP_LINE_LEN
			loop .NextChk
			cmp dl, 1
			jz	.Again

			; checking overlaps  (check equal bases first: remove the line that has a shorter-length)
			; ...

			; adding regions (using the higher 32-bits of Length-field)
.Adder		xor edx, edx
			xor bx, bx
			mov si, ram_map+12
			mov cx, [ram_map_ent]
.AddHi		cmp BYTE [ds:si+bx+4], 1				; USABLE memory?
			jne	.NextRowHi
			add edx, DWORD [ds:si+bx]
.NextRowHi	add bx, RAM_MAP_LINE_LEN
			loop .AddHi
			mov DWORD [ram_size_hi], edx

			; adding regions (using the lower 32-bits of Length-field), updating upper 32-bits if overflow
			xor eax, eax
			xor bx, bx
			mov si, ram_map+8
			mov cx, [ram_map_ent]
.AddLo		cmp BYTE [ds:si+bx+8], 1				; USABLE memory?
			jne	.NextRowLo
			mov edx, 0xFFFFFFFF
			sub edx, eax
			cmp	DWORD [ds:si+bx], edx
			jna	.Inc
			mov eax, DWORD [ds:si+bx]
			sub eax, edx
			inc	DWORD [ram_size_hi]
			jmp	.NextRowLo
.Inc		add eax, DWORD [ds:si+bx]
.NextRowLo	add bx, RAM_MAP_LINE_LEN
			loop .AddLo
			mov DWORD [ram_size_lo], eax
.End		popa
			ret


;*********************************************************************
; ram_show		; call ram_get first
;*********************************************************************
ram_show:
			pusha

			mov si, ram_txt
			call stdio16_puts
			mov dx, [ram_size_hi+2]
			mov cx, 4
			call stdio16_put_hex		
			mov dx, [ram_size_hi]
			mov cx, 4
			call stdio16_put_hex		
			mov dx, [ram_size_lo+2]
			mov cx, 4
			call stdio16_put_hex		
			mov dx, [ram_size_lo]
			mov cx, 4
			call stdio16_put_hex		
			call stdio16_new_line

			mov di, ram_map
			call ram_show_map

;			mov di, ram_map
;			mov cx, 10
;			call util16_mem_dump

			popa
			ret


; Getting an E820 Memory Map
; from http://wiki.osdev.org/Detecting_Memory_(x86)
; Basic Usage:
; For the first call to the function, point ES:DI at the destination buffer for the list. Clear EBX. Set EDX to the magic number 0x534D4150. Set EAX to 0xE820 (note that the upper word of EAX should be set to 0). Set ECX to RAM_MAP_LINE_LEN. Do an INT 0x15.

; If the first call to the function is successful, EAX will be set to 0x534D4150, and the Carry flag will be clear. EBX will be set to some non-zero value, which must be preserved for the next call to the function. CL will contain the number of bytes actually stored at ES:DI (probably 20).

; For the subsequent calls to the function: increment DI by your list entry size, reset EAX to 0xE820, and ECX to RAM_MAP_LINE_LEN. When you reach the end of the list, EBX may reset to 0. If you call the function again with EBX = 0, the list will start over. If EBX does not reset to 0, the function will return with Carry set when you try to access the entry after the last valid entry. 

;*********************************************************************
; ram_get_map
; use the INT 0x15, eax= 0xE820 BIOS function to get a memory map
; inputs: es:di -> destination buffer for RAM_MAP_LINE_LEN byte entries
; outputs: bp = entry count, trashes all registers except esi  (I added pusha and popa and a memory-location for bp)
;*********************************************************************
ram_get_map:
			pusha
			xor ebx, ebx				; ebx must be 0 to start
			xor bp, bp					; keep an entry count in bp
			mov edx, 0x0534D4150		; Place "SMAP" into edx
			mov eax, 0xe820
			mov [es:di + 20], dword 1	; force a valid ACPI 3.X entry
			mov ecx, RAM_MAP_LINE_LEN	; ask for RAM_MAP_LINE_LEN bytes
			int 0x15
			jc short .failed			; carry set on first call means "unsupported function"
			mov edx, 0x0534D4150		; Some BIOSes apparently trash this register?
			cmp eax, edx				; on success, eax must have been reset to "SMAP"
			jne short .failed
			test ebx, ebx				; ebx = 0 implies list is only 1 entry long (worthless)
			je short .failed
			jmp short .jmpin
.e820lp:		
			mov eax, 0xe820				; eax, ecx get trashed on every int 0x15 call
			mov [es:di + 20], dword 1	; force a valid ACPI 3.X entry
			mov ecx, RAM_MAP_LINE_LEN	; ask for RAM_MAP_LINE_LEN bytes again
			int 0x15
			jc short .e820f				; carry set means "end of list already reached"
			mov edx, 0x0534D4150		; repair potentially trashed register
.jmpin:
			jcxz .skipent				; skip any 0 length entries
			cmp cl, 20					; got a RAM_MAP_LINE_LEN byte ACPI 3.X response?
			jbe short .notext
			test byte [es:di + 20], 1	; if so: is the "ignore this data" bit clear?
			je short .skipent
.notext:
			mov ecx, [es:di + 8]		; get lower dword of memory region length
			or ecx, [es:di + 12]		; "or" it with upper dword to test for zero
			jz .skipent					; if length qword is 0, skip entry
			inc bp						; got a good entry: ++count, move to next storage spot
			add di, RAM_MAP_LINE_LEN
.skipent:
			test ebx, ebx				; if ebx resets to 0, list is complete
			jne short .e820lp
.e820f:
			mov [ram_map_ent], bp		; store the entry count   ; why not store the count in cx!?***************
			clc							; there is "jc" on end of list to this point, so the carry must be cleared
			popa
			ret
.failed:
			stc							; "function unsupported" error exit
			popa
			ret


;*********************************************************************
; ram_show_map
; Needs to be called after ram_get_map
; ES:DI --> buffer RAM_MAP_LINE_LEN-byte entries
;*********************************************************************
; First qword = Base address
; Second qword = Length of "region" (if this value is 0, ignore the entry)
; Next dword = Region "type"
;	Type 1: Usable (normal) RAM
;	Type 2: Reserved - unusable
;	Type 3: ACPI reclaimable memory
;	Type 4: ACPI NVS memory
;	Type 5: Area containing bad memory 
; Next dword = ACPI 3.0 Extended Attributes bitfield (if 24 bytes are returned, instead of 20)
;	Bit 0 of the Extended Attributes indicates if the entire entry should be ignored (if the bit is clear). This is going to be a huge compatibility problem because most current OSs won't read this bit and won't ignore the entry.
;	Bit 1 of the Extended Attributes indicates if the entry is non-volatile (if the bit is set) or not. The standard states that "Memory reported as non-volatile may require characterization to determine its suitability for use as conventional RAM."
;	The remaining 30 bits of the Extended Attributes are currently undefined. 

ram_show_map:
			pusha
			mov si, ram_caption_txt
			call stdio16_puts
			call stdio16_new_line

			mov cx, [ram_map_ent]
			; Base Address
.NextEntry	push cx
			call ram_map_line
			call stdio16_new_line

			add di, RAM_MAP_LINE_LEN
			pop cx
			loop .NextEntry

			popa
			ret


;***********************************
; ram_map_line
;***********************************
ram_map_line:
			mov dx, [es:di+6]
			mov cx, 4
			call stdio16_put_hex
			mov dx, [es:di+4]
			mov cx, 4
			call stdio16_put_hex
			mov dx, [es:di+2]
			mov cx, 4
			call stdio16_put_hex
			mov dx, [es:di]
			mov cx, 4
			call stdio16_put_hex
			mov al, ' '
			call stdio16_put_ch
			mov al, '|'
			call stdio16_put_ch
			mov al, ' '
			call stdio16_put_ch
			; Length
			mov dx, [es:di+14]
			mov cx, 4
			call stdio16_put_hex
			mov dx, [es:di+12]
			mov cx, 4
			call stdio16_put_hex
			mov dx, [es:di+10]
			mov cx, 4
			call stdio16_put_hex
			mov dx, [es:di+8]
			mov cx, 4
			call stdio16_put_hex
			mov al, ' '
			call stdio16_put_ch
			mov al, '|'
			call stdio16_put_ch
			mov al, ' '
			call stdio16_put_ch
			; Type
			xor bx, bx
			mov bl, BYTE [es:di+16]		; this is a dword. can it be a problem?
			cmp bl, 3					; if bx > 3 then treat it as undefined
			jng .Defined
			mov bl, 5
.Defined	shl	bl, 1					; multiply with 2 (WORD)
			mov si, [ram_type_arr+bx]
			call stdio16_puts
			ret


;*********************************************
; ram_get_gt_64mb
;	Get memory size for >64M configuations
;	ret\ ax=KB between 1MB and 16MB
;	ret\ bx=number of 64K blocks above 16MB
;	ret\ bx=0 and ax= -1 on error
;*********************************************
ram_get_gt_64mb:
	push	ecx
	push	edx
	xor		ecx, ecx
	xor		edx, edx
	mov		ax, 0xe801
	int		0x15	
	jc		.error
	cmp		ah, 0x86		;unsupported function
	je		.error
	cmp		ah, 0x80		;invalid command
	je		.error
	jcxz	.use_ax			;bios may have stored it in ax,bx or cx,dx. test if cx is 0
	mov		ax, cx			;its not, so it should contain mem size; store it
	mov		bx, dx

.use_ax:
	pop		edx				;mem size is in ax and bx already, return it
	pop		ecx
	ret

.error:
	mov		ax, -1
	mov		bx, 0
	pop		edx
	pop		ecx
	ret


;*********************************************
; ram_get_low
;	Get amount of contiguous KB from addr 0
;	ret\ ax=KB size from address 0
;*********************************************
ram_get_low:
	int	0x12
	ret


;*********************************************
;	Get (only) contiguous extended memory size
;	ret\ ax=KB size above 1MB; ax= -1 on error
;*********************************************
ram_BiosGetExtendedMemorySize:
	mov		ax, 0x88
	int		0x15
	jc		.error
	test	ax, ax		; if size=0
	je		.error
	cmp		ah, 0x86	;unsupported function
	je		.error
	cmp		ah, 0x80	;invalid command
	je		.error
	ret
.error:
	mov		ax, -1
	ret


;*********************************************************************
; ram_copy_memmap
;	Copies data from ram_map to RAM_MAP_LOC for forth word RAMMAP
;	Also copies number of ram-map-entries to RAM_MAP_ENT_LOC
;	Should be called after ram_get
;*********************************************************************
ram_copy_memmap:
			pusha
			mov si, ram_map
			xor ecx, ecx
			mov	es, cx
			mov di, RAM_MAP_LOC
			mov cx, 50*RAM_MAP_LINE_LEN
			rep movsb
			mov cx, [ram_map_ent]
			mov [es:RAM_MAP_ENT_LOC], cx
			popa
			ret


section .data

ram_map			times 50*RAM_MAP_LINE_LEN db 0
ram_map_tmp		times RAM_MAP_LINE_LEN db	0 	; for sorting
ram_map_ent		dw	0
ram_caption_txt	db	"Base Address     | Length           | Type", 0
ram_type0_txt	db	"Unknown", 0
ram_type1_txt	db	"Usable (normal) RAM", 0
ram_type2_txt	db	"Reserved - unusable", 0
ram_type3_txt	db	"ACPI reclaimable memory", 0
ram_type4_txt	db	"ACPI NVS memory", 0
ram_type5_txt	db	"Area containing bad memory", 0
ram_type6_txt	db	"Undefined", 0
ram_type_arr	dw	ram_type0_txt, ram_type1_txt, ram_type2_txt, ram_type3_txt, ram_type4_txt, ram_type5_txt, ram_type6_txt 

ram_size_hi		dd	0	; in bytes
ram_size_lo		dd	0	; in bytes

ram_txt			db	"RAM: ", 0


%endif

