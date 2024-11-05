%ifndef __UTIL__
%define __UTIL__


%include "pit.asm"
%include "stdio.asm"

bits 32


UTIL_BYTESPERROW	equ	16
UTIL_BYTESPERROW2	equ	8


section .text

;*************************************************;
;	util_mem_dump2
;	ESI: offset of memory-address to print
;	ECX: number of rows to print (BYTESPERROW bytes will be printed per line)
;
; e.g. D0000000: FF 3F 12 54 ... 20 F3 ReadableChars
;************************************************; 
util_mem_dump2:
			pushad
			cmp ecx, 0
			jz .Back

.NextLine	push ecx
			mov edx, esi
			call stdio_put_hex
			mov bl, ':'
			call stdio_put_ch
			mov bl, ' '
			call stdio_put_ch

			mov ecx, UTIL_BYTESPERROW
.NextByte	mov ebx, UTIL_BYTESPERROW
			sub ebx, ecx
			mov dh, [esi+ebx]		; only(!?) BX can appear in [] (out of AX, CX, DX)
			call stdio_put_hex8
			mov bl, ' '
			call stdio_put_ch
			loop .NextByte

			; print chars
			mov ecx, UTIL_BYTESPERROW
.NextChar	cmp BYTE [esi], 32
			jge .PChar
			mov bl, '.'
			call stdio_put_ch
			jmp .Skip
.PChar		mov bl, BYTE [esi]
			call stdio_put_ch

.Skip		inc esi
			loop .NextChar

			call stdio_new_line

			pop ecx
			loop .NextLine
.Back		popad
			ret


;*************************************************;
;	util_mem_dump
;	ESI: offset of memory-address to print
;	ECX: number of bytes to print (BYTESPERROW bytes will be printed per line)
;
; e.g. D0000000: FF 3F 12 54 ... 20 F3 ReadableChars
;************************************************; 
util_mem_dump:
			pushad
.Next		cmp ecx, 0
			jz	.Back
			mov edx, esi
			call stdio_put_hex
			mov bl, ':'
			call stdio_put_ch
			mov bl, ' '
			call stdio_put_ch
			xor edx, edx
.NextByte	push ecx
			sub ecx, edx
			pop ecx
			jg	.PrBytes
			mov bl, ' '
			call stdio_put_ch
			mov bl, ' '
			call stdio_put_ch
			mov bl, ' '
			call stdio_put_ch
			jmp .Inc
.PrBytes	push edx
			mov dh, [esi+edx]
			call stdio_put_hex8
			mov bl, ' '
			call stdio_put_ch
			pop edx
.Inc		inc edx
			cmp edx, UTIL_BYTESPERROW
			jnge .NextByte
			; chars
			xor edx, edx
.NextChar	mov bl, BYTE [esi+edx]	
			cmp bl, 32
			jge	.Put
			mov bl, '.'
.Put		call stdio_put_ch
			inc edx
			cmp edx, UTIL_BYTESPERROW
			jnge .Chk
			jmp .NewLine
.Chk		push ecx
			sub ecx, edx
			pop ecx
			jg	.NextChar
.NewLine	call stdio_new_line
			sub ecx, edx
			add esi, edx
			jmp  .Next
.Back		popad
			ret


;*************************************************;
;	util_reg_dump
;	Registers Dump
;*************************************************; 
util_reg_dump:
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
			mov	esi, util_reg_txts
.Next		pop edx
			push ecx
			mov ecx, 5
			call stdio_put_chs

			call stdio_put_hex

			call stdio_new_line

			pop ecx
			loop .Next

			ret


;*************************************************;
; util_ascii_hex_to_num			(util_toupper should have been used!)
; EDI:		Chars (Ascii)
; ECX:		Number of chars (max 8, i.e. 32 bits)
; EAX:		Number ; Out
; Skips wrong chars
;*************************************************;
util_ascii_hex_to_num:
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
			mov [UTIL_NUMSTORAGE], eax
			popad
			mov eax, [UTIL_NUMSTORAGE]
			ret


;*************************************************;
; util_ascii_dec_to_num
; EDI:		Chars (Ascii)
; ECX:		Number of chars  (max 10, i.e. 32 bits)
; EAX:		Number ; Out
;*************************************************;
util_ascii_dec_to_num:
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
			mov [UTIL_NUMSTORAGE], eax
			popad
			mov eax, [UTIL_NUMSTORAGE]
			ret


;*************************************************;
; util_print_date
;*************************************************;
util_print_date:
			pushad
			mov eax, DWORD [stdio_cur_x]
			push eax
			mov eax, DWORD [stdio_cur_y]
			push eax

			mov [stdio_cur_x], BYTE 49
			mov [stdio_cur_y], BYTE 0

			mov ah, 0x20			; "20" of the year
			call stdio_put_bcd

			mov al, 0x09			; Year
			out 0x70, al
			in al, 0x71
			shl ax, 8
			call stdio_put_bcd

			mov bl, '/'
			call stdio_put_ch

			mov al, 0x08			; Month
			out 0x70, al
			in al, 0x71
			shl ax, 8
			call stdio_put_bcd

			mov bl, '/'
			call stdio_put_ch

			mov al, 0x07			; Day of Month
			out 0x70, al
			in al, 0x71
			shl ax, 8
			call stdio_put_bcd

			mov bl, ' '
			call stdio_put_ch

			mov al, 0x06			; Day of Week
			out 0x70, al
			in al, 0x71
;			shl ax, 8
;			call stdio_put_bcd
			xor ebx, ebx
			mov bl, al
			mov ebx, [util_day_of_week_arr+(ebx-1)*4]
			call stdio_puts

			pop eax
			mov [stdio_cur_y], al
			pop eax
			mov [stdio_cur_x], al
			popad
			ret


;*************************************************;
; util_print_time
;*************************************************;
util_print_time:
			pushad
			mov eax, DWORD [stdio_cur_x]
			push eax
			mov eax, DWORD [stdio_cur_y]
			push eax

			mov [stdio_cur_x], BYTE 71
			mov [stdio_cur_y], BYTE 0

			mov al, 0x04			; Hour
			out 0x70, al
			in al, 0x71
			shl ax, 8
			call stdio_put_bcd

			mov bl, ':'
			call stdio_put_ch

			mov al, 0x02			; Minute
			out 0x70, al
			in al, 0x71
			shl ax, 8
			call stdio_put_bcd

			mov bl, ':'
			call stdio_put_ch

			mov al, 0x00			; Second
			out 0x70, al
			in al, 0x71
			shl ax, 8
			call stdio_put_bcd

			pop eax
			mov [stdio_cur_y], al
			pop eax
			mov [stdio_cur_x], al
			popad
			ret


;*************************************************;
; util_bubble_sort
; ESI --> address of array
; ECX: # of items (dwords)
;*************************************************;
; 4 means that it's a dword size array
util_bubble_sort:
			pushad
.Again		mov edx, 0						; clear swapped
			push ecx
			dec ecx
			xor ebx, ebx
.NextChk	mov eax, DWORD [esi+ebx]
			cmp eax, DWORD [esi+ebx+4]
			ja	.Swap						; unsigned jump!
			jmp .Next
.Swap		mov edi, eax
			mov eax, DWORD [esi+ebx+4]
			mov DWORD [esi+ebx], eax
			mov DWORD [esi+ebx+4], edi
			mov edx, 1						; there was a swap
.Next		add ebx, 4
			loop .NextChk
			pop ecx
			cmp edx, 1
			jz	.Again
			popad
			ret


;*************************************************;
; util_seed_random2 	; 0x46c : 18.2 hz system clock 
;				(timer-ticks can be converted to time).
;				; 18 times faster then SeedRandom
;*************************************************;
util_seed_random2:
			push ax
			push es
			push di
			mov ax, 0x0040
			mov es, ax
			mov di, 0x006c
			mov ax, WORD [es:di]
			mov WORD [util_random_seed], ax
			pop di
			pop es
			pop ax
			ret

;*************************************************;
; util_seed_random -- Seed the random number generator based on clock
; IN: Nothing; OUT: Nothing (registers preserved)
;*************************************************;
util_seed_random:
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

	mov word [util_random_seed], bx	; Seed will be something like 0x4435 (if it
									; were 44 minutes and 35 seconds after the hour)
	pop ax
	pop bx
	ret


;*************************************************;
; util_get_random -- Return a random integer between low and high (inclusive) (wait at least a second between two calls!)
; IN: AX = low integer, BX = high integer
; OUT: CX = random integer
;*************************************************;
util_get_random:
	push dx
	push bx
	push ax

	sub bx, ax			; We want a number between 0 and (high-low)
	call util_gen_random
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
; util_gen_random
;*************************************************;
util_gen_random:
	push dx
	push bx

	mov ax, [util_random_seed]
	mov dx, 0x7383				; The magic number (random.org)
	mul dx						; DX:AX = AX * DX
	mov [util_random_seed], ax

	pop bx
 	pop dx
	ret


;***********************************************
; util_beep  (Bochs doesn't want to make a sound!) 0x43 is PIT !!
;***********************************************
Prg_8255 equ 61h			; speaker (they say that it doesn't exist on newer 80286 > motherboards)
Prg_timer equ 43h
Timer equ 42h

; timer interrupt already programmed in pit.inc; rewrite with delay!?
util_beep:
			pushad
			mov al, 10110110b
			out Prg_timer, al
			mov ax, 1193					; set the divison-ratio to about 1khz
			out Timer, al
			mov al, ah
			out Timer, al
			in al, Prg_8255
			or al, 00000011b
			out Prg_8255, al
			mov cx, 0ffffh
.Wait		loop .Wait
			in al, Prg_8255
			and al, 11111100b
			out Prg_8255, al
			popad
			ret

util_beep2:	; check Mike-OS too
			pushad
			in al, 61h						; turn on note
			or	al, 00000011b
			out 61h, al

			mov ebx, 1000
			call pit_delay

			in al, 61h
			and al, 11111100b
			out 61h, al
			popad
			ret


;*************************************************;
; util_strlen  (should be put to string.inc)
;	EDI: addr of string; In
;	ECX: length; Out
;*************************************************;
util_strlen:
			xor ecx, ecx
.Next		cmp BYTE [edi], 0
			jz	.Ready
			inc edi
			inc ecx
			jmp .Next
.Ready		ret


;*************************************************;
; util_strcmp  (should be put to string.inc)
;	ESI: addr of string1; In
;	EDI: addr of string2; In
;	ECX: length; In
;	EAX: <0 if s1 < s2; 0 if s1 == s2; >0 if s1 > s2 ; Out
;*************************************************;
util_strcmp:
			push ebx
			push edx
			xor eax, eax
			mov ebx, 0
.Next		mov al, BYTE [edi+ebx]
			call util_toupper
			mov dl, al
			mov al, BYTE [esi+ebx]
			call util_toupper
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


;*************************************************
; util_toupper	(should be put to string.inc)
;	EAX: char; In		(AL would be enough)
;	EAX: char; Out
;*************************************************
util_toupper:
			cmp eax, 97			; 'a'
			jge	.Ch_z
			jmp .Back
.Ch_z		cmp eax, 122		; 'z'
			jng	.Conv
			jmp .Back
.Conv		sub eax, 32
.Back		ret


section .data

UTIL_NUMSTORAGE		times 10 db 0
util_reg_txts		db "EAX: EBX: ECX: EDX: CS:  DS:  ES:  SS:  ESI: EDI: EBP: ESP: EFL: "
;flag(pushf & pop eax)
;NLCRtxt db 13, 10
;Floating : ST0 ...
;Control: CR0 ...
util_random_seed	dw	0

util_sunday_txt		db "Sunday", 0
util_monday_txt		db "Monday", 0
util_tuesday_txt	db "Tuesday", 0
util_wednesday_txt	db "Wednesday", 0
util_thursday_txt	db "Thursday", 0
util_friday_txt		db "Friday", 0
util_saturday_txt	db "Saturday", 0

util_day_of_week_arr dd util_sunday_txt, util_monday_txt, util_tuesday_txt, util_wednesday_txt, util_thursday_txt, util_friday_txt, util_saturday_txt


%endif

