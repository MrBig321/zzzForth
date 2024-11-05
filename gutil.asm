%ifndef __GUTIL__
%define __GUTIL__


%include "pit.asm"
%include "gstdio.asm"

bits 32


GUTIL_BYTESPERROW	equ	12


section .text

;*************************************************;
;	gutil_mem_dump
;	ESI: offset of memory-address to print
;	ECX: number of bytes to print (BYTESPERROW bytes will be printed per line)
;
; e.g. D0000000: FF 3F 12 54 ... 20 F3 ReadableChars
;************************************************; 
gutil_mem_dump:
			pushad
.Next		cmp ecx, 0
			jz	.Back
			mov edx, esi
			call gstdio_draw_hex
			mov ebx, DWORD ':'
			call gstdio_draw_char
			mov ebx, ' '
			call gstdio_draw_char
			xor edx, edx
.NextByte	push ecx
			sub ecx, edx
			pop ecx
			jg	.PrBytes
			mov ebx, ' '
			call gstdio_draw_char
			mov ebx, ' '
			call gstdio_draw_char
			mov ebx, ' '
			call gstdio_draw_char
			jmp .Inc
.PrBytes	push edx
			mov dh, [esi+edx]
			call gstdio_draw_hex8
			mov ebx, ' '
			call gstdio_draw_char
			pop edx
.Inc		inc edx
			cmp edx, GUTIL_BYTESPERROW
			jnge .NextByte
			; chars
			xor edx, edx
.NextChar	mov bl, BYTE [esi+edx]	
			cmp bl, 32
			jge	.ChkUpper
			jmp .Dot
.ChkUpper	cmp bl, 127
			jnge .Put
.Dot		mov ebx, DWORD '.'
.Put		call gstdio_draw_char
			inc edx
			cmp edx, GUTIL_BYTESPERROW
			jnge .Chk
			jmp .NewLine
.Chk		push ecx
			sub ecx, edx
			pop ecx
			jg	.NextChar
.NewLine	call gstdio_new_line
			sub ecx, edx
			add esi, edx
%ifdef MULTITASKING_DEF
			mov DWORD [pit_task_ticks], 0					; clear pit-ticks (Or call PAUSE!?)
%endif
			jmp  .Next
.Back		popad
			ret


;*************************************************;
;	gutil_reg_dump
;	Registers Dump
;*************************************************; 
gutil_reg_dump:
			pushf
			push esp
			push ebp
			push edi
			push esi
			push ss
			push es
			push ds
			push cs
			push edx
			push ecx
			push ebx
			push eax
			
			mov ecx, 13
			mov	esi, gutil_reg_txts
.Next		pop edx
			push ecx
			mov ecx, 5
			call gstdio_draw_chars
			call gstdio_draw_hex
			call gstdio_new_line
			pop ecx
			loop .Next

			ret


;*************************************************;
; gutil_ascii_hex_to_num			(gutil_toupper should have been used!)
; EDI:		Chars (Ascii)
; ECX:		Number of chars (max 8, i.e. 32 bits)
; EAX:		Number ; Out
; Skips wrong chars
;*************************************************;
gutil_ascii_hex_to_num:
			pushad
			xor eax, eax
			xor ebx, ebx
.Next		shl eax, 4				; multiply with 16
			cmp BYTE [edi+ebx], '0'
			jge .Chk9
			jmp .Skip
.Chk9		cmp BYTE [edi+ebx], '9'
			jng .Set0
			jmp .ChkA
.Set0		mov esi, '0'
			jmp .Add
.ChkA		cmp BYTE [edi+ebx], 'A'
			jge .ChkF
			jmp .Skip
.ChkF		cmp BYTE [edi+ebx], 'F'
			jng .SetA
			jmp .Chka
.SetA		mov esi, 'A'-10				; 10 is the numbers from 0 to 9
			jmp .Add
.Chka		cmp BYTE [edi+ebx], 'a'
			jge .Chkf
			jmp .Skip
.Chkf		cmp BYTE [edi+ebx], 'f'
			jng .Seta
			jmp .Skip
.Seta		mov esi, 'a'-10				; 10 is the numbers from 0 to 9
			jmp .Add
.Add		xor edx, edx
			mov dl, [edi+ebx]
			sub edx, esi
			add eax, edx
.Skip		inc ebx
			loop .Next
			mov [GUTIL_NUMSTORAGE], eax
			popad
			mov eax, [GUTIL_NUMSTORAGE]
			ret


;*************************************************;
; gutil_ascii_dec_to_num
; EDI:		Chars (Ascii)
; ECX:		Number of chars  (max 10, i.e. 32 bits)
; EAX:		Number ; Out
;*************************************************;
gutil_ascii_dec_to_num:
			pushad
			xor eax, eax
			xor ebx, ebx
.Next		mov edx, 10
			mul edx					; eax*10 in eax; could be: eax << 3 + eax << 1
			xor edx, edx
			mov dl, [edi+ebx]
			sub dl, '0'
			add eax, edx 
			inc ebx
			loop .Next
			mov [GUTIL_NUMSTORAGE], eax
			popad
			mov eax, [GUTIL_NUMSTORAGE]
			ret


;*************************************************;
; gutil_bcd2dec
;	IN: AL
;	OUT: AL
; convert from BCD to decimal
;*************************************************;
gutil_bcd2dec:
			push edx
			; upper 4 bits of year: *10
			mov dl, al
			mov dh, al
			shr dl, 4
			shr dh, 4
			shl dl, 3	; *8
			shl dh, 1	; *2
			add dl, dh
			and al, 0x0F
			add	al, dl
			pop edx
			ret

;*************************************************;
; gutil_get_date  (for FAT32)
;	OUT: BX (7:4:5 Y:M:D)
;*************************************************;
gutil_get_date:
			push eax

			xor ebx, ebx
			xor eax, eax
			mov al, 0x09			; Year
			out 0x70, al
			in al, 0x71
			call gutil_bcd2dec
			add al, 20 		; from 1980 in Fat32 !?

			mov bl, al
			shl	ebx, 9

			mov al, 0x08			; Month
			out 0x70, al
			in al, 0x71
			shl eax, 5
			or	ebx, eax

			xor eax, eax
			mov al, 0x07			; Day of Month
			out 0x70, al
			in al, 0x71
			call gutil_bcd2dec

			or	ebx, eax

			pop eax
			ret


;*************************************************;
; gutil_print_date
;*************************************************;
;gutil_print_date:
;			pushad
;
;			mov ah, 0x20			; "20" of the year
;			mov dx, ax
;			call gstdio_draw_hex8
;
;			mov al, 0x09			; Year
;			out 0x70, al
;			in al, 0x71
;			shl ax, 8
;			mov dx, ax
;			call gstdio_draw_hex8
;
;			mov ebx, DWORD '/'
;			call gstdio_draw_char
;
;			mov al, 0x08			; Month
;			out 0x70, al
;			in al, 0x71
;			shl ax, 8
;			mov dx, ax
;			call gstdio_draw_hex8
;
;			mov ebx, DWORD '/'
;			call gstdio_draw_char
;
;			mov al, 0x07			; Day of Month
;			out 0x70, al
;			in al, 0x71
;			shl ax, 8
;			mov dx, ax
;			call gstdio_draw_hex8
;
;			mov ebx, ' '
;			call gstdio_draw_char
;
;			mov al, 0x06			; Day of Week
;			out 0x70, al
;			in al, 0x71
;;			shl ax, 8
;;			call gstdio_draw_hex8
;			xor ebx, ebx
;			mov bl, al
;			mov ebx, [gutil_day_of_week_arr+(ebx-1)*4]
;			mov edx, ebp
;			call gstdio_draw_text
;
;			popad
;			ret


;*************************************************;
; gutil_get_time  (for FAT32)
;	OUT: BX (5:6:5 H:M:S)
;*************************************************;
gutil_get_time:
			push eax

			xor ebx, ebx
			xor eax, eax
			mov al, 0x04			; Hour
			out 0x70, al
			in al, 0x71
			call gutil_bcd2dec

			mov bl, al
			shl	ebx, 11

			mov al, 0x02			; Minute
			out 0x70, al
			in al, 0x71
			call gutil_bcd2dec

			shl eax, 5
			or	ebx, eax

			xor eax, eax
			mov al, 0x00			; Second
			out 0x70, al
			in al, 0x71
			call gutil_bcd2dec

			or	ebx, eax

			pop eax
			ret


;*************************************************;
; gutil_print_time
;*************************************************;
;gutil_print_time:
;			pushad
;
;			mov al, 0x04			; Hour
;			out 0x70, al
;			in al, 0x71
;			shl ax, 8
;			mov dx, ax
;			call gstdio_draw_hex8
;
;			mov ebx, DWORD ':'
;			call gstdio_draw_char
;
;			mov al, 0x02			; Minute
;			out 0x70, al
;			in al, 0x71
;			shl ax, 8
;			mov dx, ax
;			call gstdio_draw_hex8
;
;			mov ebx, DWORD ':'
;			call gstdio_draw_char
;
;			mov al, 0x00			; Second
;			out 0x70, al
;			in al, 0x71
;			shl ax, 8
;			mov dx, ax
;			call gstdio_draw_hex8
;
;			popad
;			ret


;*************************************************;
; gutil_bubble_sort
; ESI --> address of array
; ECX: # of items (dwords)
;	+4 is a DWORD
;*************************************************;
gutil_bubble_sort:
			pushad
			cmp ecx, 1
			jna	.Back
.Again		mov edx, 0						; clear swapped
			push ecx
			dec ecx
			xor ebx, ebx
.NextChk	mov eax, [esi+ebx]
			cmp eax, [esi+ebx+4]
			ja	.Swap						; unsigned jump!
			jmp .Next
.Swap		mov edi, eax
			mov eax, [esi+ebx+4]
			mov [esi+ebx], eax
			mov [esi+ebx+4], edi
			mov edx, 1						; there was a swap
.Next		add ebx, 4
			loop .NextChk
			pop ecx
			cmp edx, 1
			je	.Again
.Back		popad
			ret


;*************************************************;
; gutil_seed_random2 	; 0x46c : 18.2 hz system clock 
;				(timer-ticks can be converted to time).
;				; 18 times faster then SeedRandom
;*************************************************;
gutil_seed_random2:
			push ax
			push es
			push di
			mov ax, 0x0040
			mov es, ax
			mov di, 0x006c
			mov ax, WORD [es:di]
			mov WORD [gutil_random_seed], ax
			pop di
			pop es
			pop ax
			ret

;*************************************************;
; gutil_seed_random -- Seed the random number generator based on clock
; IN: Nothing; OUT: Nothing (registers preserved)
;*************************************************;
gutil_seed_random:
	push bx
	push ax

	mov bx, 0
	mov al, 0x02					; Minute
	out 0x70, al
	in al, 0x71

	mov bl, al
	shl bx, 8
	mov al, 0						; Second
	out 0x70, al
	in al, 0x71
	mov bl, al

	mov word [gutil_random_seed], bx	; Seed will be something like 0x4435 (if it
									; were 44 minutes and 35 seconds after the hour)
	pop ax
	pop bx
	ret


;*************************************************;
; gutil_get_random -- Return a random integer between low and high (inclusive) (wait at least a second between two calls!)
; IN: AX = low integer, BX = high integer
; OUT: CX = random integer
;*************************************************;
gutil_get_random:
	push dx
	push bx
	push ax

	sub bx, ax			; We want a number between 0 and (high-low)
	call gutil_gen_random
	mov dx, bx
	add dx, 1
	mul dx
	mov cx, dx

	pop ax
	pop bx
	pop dx
	add cx, ax			; Add the low offset back
	ret


;*************************************************;
; gutil_gen_random
;*************************************************;
gutil_gen_random:
	push dx
	push bx

	mov ax, [gutil_random_seed]
	mov dx, 0x7383				; The magic number (random.org)
	mul dx						; DX:AX = AX * DX
	mov [gutil_random_seed], ax

	pop bx
 	pop dx
	ret


;***********************************************
; gutil_beep  (Bochs doesn't want to make a sound!) 0x43 is PIT !!
;***********************************************
;Prg_8255 equ 61h			; speaker (they say that it doesn't exist on newer 80286 > motherboards)
;Prg_timer equ 43h
;Timer equ 42h

; timer interrupt already programmed in pit.inc; rewrite with delay!?
;gutil_beep:
;			pushad
;			mov al, 10110110b
;			out Prg_timer, al
;			mov ax, 1193					; set the divison-ratio to about 1khz
;			out Timer, al
;			mov al, ah
;			out Timer, al
;			in al, Prg_8255
;			or al, 00000011b
;			out Prg_8255, al
;			mov cx, 0ffffh
;.Wait		loop .Wait
;			in al, Prg_8255
;			and al, 11111100b
;			out Prg_8255, al
;			popad
;			ret

;gutil_beep2:	; check Mike-OS too
;			pushad
;			in al, 61h						; turn on note
;			or	al, 00000011b
;			out 61h, al

;			mov ebx, 1000
;			call pit_delay

;			in al, 61h
;			and al, 11111100b
;			out 61h, al
;			popad
;			ret


;*************************************************;
; gutil_strlen  (should be put to string.inc)
;	EDI: addr of string; In
;	ECX: length; Out
;*************************************************;
gutil_strlen:
			xor ecx, ecx
.Next		cmp BYTE [edi], 0
			jz	.Ready
			inc edi
			inc ecx
			jmp .Next
.Ready		ret


;*************************************************;
; gutil_strcmp  (should be put to string.inc)
;	ESI: addr of string1; In
;	EDI: addr of string2; In
;	ECX: length; In
;	EAX: <0 if s1 < s2; 0 if s1 == s2; >0 if s1 > s2 ; Out
;*************************************************;
gutil_strcmp:
			push ebx
			push edx
			xor eax, eax
			mov ebx, 0
.Next		mov al, BYTE [edi+ebx]
			call gutil_toupper
			mov dl, al
			mov al, BYTE [esi+ebx]
			call gutil_toupper
			cmp al, dl
			jnz	.Sub
			inc ebx
			cmp ebx, ecx
			jge	.Equ
			jmp .Next
.Equ		mov eax, 0		
			jmp .Back
.Sub		sub al, BYTE [edi+ebx]
.Back		pop edx
			pop ebx
			ret


;*************************************************;
; gutil_strcmp_case_sensitive  (should be put to string.inc)
;	ESI: addr of string1; In
;	EDI: addr of string2; In
;	ECX: length; In
;	EAX: <0 if s1 < s2; 0 if s1 == s2; >0 if s1 > s2 ; Out
;	skips chars in ESI that are > 126 ( greater then ASCII of '~' )
;*************************************************;
gutil_strcmp_case_sensitive:
			push ebx
			push edx
			xor eax, eax
			xor ebx, ebx
.Next		mov al, BYTE [esi+ebx]
			mov dl, BYTE [edi+ebx]
			cmp al, 126
			ja	.Inc					; skip chars > 126
			cmp al, dl
			jnz	.Sub
.Inc		inc ebx
			cmp ebx, ecx
			jge	.Sub
			jmp .Next
.Sub		sub al, dl
.Back		pop edx
			pop ebx
			ret


;*************************************************
; gutil_toupper	(should be put to string.inc)
;	EAX: char; In		(AL would be enough)
;	EAX: char; Out
;*************************************************
gutil_toupper:
			cmp eax, 97			; 'a'
			jge	.Ch_z
			jmp .Back
.Ch_z		cmp eax, 122		; 'z'
			jng	.Conv
			jmp .Back
.Conv		sub eax, 32
.Back		ret


;*************************************************
; gutil_tolower	(should be put to string.inc)
;	EAX: char; In		(AL would be enough)
;	EAX: char; Out
;*************************************************
gutil_tolower:
			cmp eax, 65			; 'A'
			jge	.Ch_Z
			jmp .Back
.Ch_Z		cmp eax, 90			; 'Z'
			jng	.Conv
			jmp .Back
.Conv		add eax, 32
.Back		ret


;*************************************************
; gutil_string_tolower
; IN: EBX (ptr to flags|length-byte)
;*************************************************
gutil_string_tolower:
			pushad
			xor eax, eax
			xor ecx, ecx
			mov cl, [ebx]			; cnt in ECX
			cmp ecx, 0
			jz	.Back
.NextCh		inc ebx
			mov al, [ebx]
			call gutil_tolower
			mov [ebx], al
			dec ecx
			jnz	.NextCh
.Back		popad
			ret


;*************************************************
; gutil_press_a_key
;*************************************************
gutil_press_a_key:
			pushad
			mov ebx, gutil_PressAKeyTxt
			call gstdio_draw_text
.Key		call kybrd_get_last_key
			call kybrd_key_to_ascii
%ifdef MULTITASKING_DEF
			mov DWORD [pit_task_ticks], 0					; clear pit-ticks (Or call PAUSE!?)
%endif
			cmp bl, 0
			jz .Key
			call kybrd_discard_last_key
			popad
			ret


;*************************************************
; gutil_press_a_key_notxt
;*************************************************
gutil_press_a_key_notxt:
			pushad
.Key		call kybrd_get_last_key
			call kybrd_key_to_ascii
%ifdef MULTITASKING_DEF
			mov DWORD [pit_task_ticks], 0					; clear pit-ticks (Or call PAUSE!?)
%endif
			cmp bl, 0
			jz .Key
			call kybrd_discard_last_key
			popad
			ret




section .data

gutil_PressAKeyTxt	db "Press a Key", 0x0A, 0

GUTIL_NUMSTORAGE		times 10 db 0
gutil_reg_txts		db "EAX: EBX: ECX: EDX: CS:  DS:  ES:  SS:  ESI: EDI: EBP: ESP: EFL: "
;flag(pushf & pop eax)
;NLCRtxt db 13, 10
;Floating : ST0 ...
;Control: CR0 ...
gutil_random_seed	dw	0

gutil_sunday_txt		db "Sunday", 0
gutil_monday_txt		db "Monday", 0
gutil_tuesday_txt		db "Tuesday", 0
gutil_wednesday_txt		db "Wednesday", 0
gutil_thursday_txt		db "Thursday", 0
gutil_friday_txt		db "Friday", 0
gutil_saturday_txt		db "Saturday", 0

gutil_day_of_week_arr dd gutil_sunday_txt, gutil_monday_txt, gutil_tuesday_txt, gutil_wednesday_txt, gutil_thursday_txt, gutil_friday_txt, gutil_saturday_txt


%endif

