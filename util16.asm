%ifndef __UTIL16__
%define __UTIL16__

%include "stdio16.asm"

bits 16


UTIL16_BYTESPERROW		equ	16


section .text

;*************************************************;
;	util16_mem_dump
;	ES: segment of memory-address to print
;	DI: offset of memory-address to print
;	CX: number of rows to print (BYTESPERROW bytes will be printed per line)
;
; e.g. 07C0:0000: FF 3F 12 54 ... 20 F3 ReadableChars
;************************************************; 
; Couldn't we use DS:SI instead of ES:DI!? Maybe if we changed DS then the data of the program couldn't be found!
util16_mem_dump:
			pusha
			cmp cx, 0
			jz .Back
			; here there could be a check: CX > e.g. 512 then end

.NextLine	push cx
			mov cx, 4					; print 4 digits
			mov dx, es
			call stdio16_put_hex
			mov al, ':'
			call stdio16_put_ch			; modifies AH
			mov cx, 4
			mov dx, di
			call stdio16_put_hex
			mov al, ':'
			call stdio16_put_ch
			mov al, ' '
			call stdio16_put_ch

;			push di ;
			mov cx, UTIL16_BYTESPERROW
.NextByte	push cx
			mov bx, UTIL16_BYTESPERROW
			sub bx, cx
			mov dh, [es:di+bx]			; only BX can appear in [] (out of AX, CX, DX)
;			mov dh, [es:di] ;
			mov cx, 2
			call stdio16_put_hex
			mov al, ' '
			call stdio16_put_ch

;			inc di ;
			pop cx
			loop .NextByte

;			pop di ;
			; print chars
			mov cx, UTIL16_BYTESPERROW
.NextChar	cmp BYTE [es:di], 32
			jge .PChar
			mov al, '.'
			call stdio16_put_ch
			jmp .Skip
.PChar		mov al, BYTE [es:di]
			call stdio16_put_ch

.Skip		inc di
			loop .NextChar

			call stdio16_new_line

			pop cx
			loop .NextLine
.Back		popa
			ret


;*************************************************;
;	util16_reg_dump
;	Registers Dump
;************************************************; 
util16_reg_dump:
			pushf
			push sp						; push sp bp di ... also works
			push bp
			push di
			push si
			push ss
			push es
			push ds
			push cs
			push dx
			push cx
			push bx
			push ax
			
			mov cx, 13
			mov	si, util16_txts
.Next		pop dx
			push cx
			mov cx, 4
			call stdio16_put_chs

			mov cx, 4
			call stdio16_put_hex

			call stdio16_new_line

			pop cx
			loop .Next

			ret


;*************************************************;
; util16_ascii_hex_to_num
; ES:DI:	Chars (Ascii)
; CX:		Number of chars (max 4, i.e. 16 bits)
; AX:		Number ; Out
; Skisp wrong chars
;*************************************************;
util16_ascii_hex_to_num:
			pusha
			xor ax, ax
			xor bx, bx
.Next		shl ax, 4					; multiply with 16
			cmp BYTE [es:di+bx], '0'
			jge .Chk9
			jmp .Skip
.Chk9		cmp BYTE [es:di+bx], '9'
			jng .Set0
			jmp .ChkA
.Set0		mov si, '0'
			jmp .Add
.ChkA		cmp BYTE [es:di+bx], 'A'
			jge .ChkF
			jmp .Skip
.ChkF		cmp BYTE [es:di+bx], 'F'
			jng .SetA
			jmp .Chka
.SetA		mov si, 'A'-10				; 10 is the numbers from 0 to 9
			jmp .Add
.Chka		cmp BYTE [es:di+bx], 'a'
			jge .Chkf
			jmp .Skip
.Chkf		cmp BYTE [es:di+bx], 'f'
			jng .Seta
			jmp .Skip
.Seta		mov si, 'a'-10				; 10 is the numbers from 0 to 9
			jmp .Add
.Add		xor dx, dx
			mov dl, [es:di+bx]
			sub dx, si
			add ax, dx
.Skip		inc bx
			loop .Next
			mov [UTIL16_NUMSTORAGE], ax
			popa
			mov ax, [UTIL16_NUMSTORAGE]
			ret


;*************************************************;
; util16_ascii_dec_to_num
; ES:DI:	Chars (Ascii)
; CX:		Number of chars  (max 5, i.e. 16 bits)
; AX:		Number ; Out
;*************************************************;
util16_ascii_dec_to_num:
			pusha
			xor ax, ax
			xor bx, bx
.Next		mov dx, 10
			mul dx					; ax*10 in ax; could be: ax << 8 + ax << 1
			xor dx, dx
			mov dl, [es:di+bx]
			sub dl, '0'
			add ax, dx 
			inc bx
			loop .Next
			mov [UTIL16_NUMSTORAGE], ax
			popa
			mov ax, [UTIL16_NUMSTORAGE]
			ret


;*************************************************;
; util16_bubble_sort
; DS:SI --> address of array
; CX: # of items (words)
;*************************************************;
; 2 means that it's a word size array
util16_bubble_sort:
			pusha
.Again		mov dl, 0						; clear swapped
			push cx
			dec cx
			xor bx, bx
.NextChk	mov ax, WORD [ds:si+bx]
			cmp ax, WORD [ds:si+bx+2]
			ja	.Swap						; unsigned jump!
			jmp .Next
.Swap		mov di, ax
			mov ax, WORD [ds:si+bx+2]
			mov WORD [ds:si+bx], ax
			mov WORD [ds:si+bx+2], di
			mov dl, 1						; there was a swap
.Next		add bx, 2
			loop .NextChk
			pop cx
			cmp dl, 1
			jz	.Again
			popa
			ret


;*************************************************;
; util16_seed_random2 	; 0x46c : 18.2 hz system clock 
;				(timer-ticks can be converted to time).
;				; 18 times faster then SeedRandom
;*************************************************;
util16_seed_random2:
			push ax
			push es
			push di
			mov ax, 0x0040
			mov es, ax
			mov di, 0x006c
			mov ax, WORD [es:di]
			mov WORD [util16_random_seed], ax
			pop di
			pop es
			pop ax
			ret

;*************************************************;
; util16_seed_random -- Seed the random number generator based on clock
; IN: Nothing; OUT: Nothing (registers preserved)
;*************************************************;
util16_seed_random:
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

	mov word [util16_random_seed], bx	; Seed will be something like 0x4435 (if it
									; were 44 minutes and 35 seconds after the hour)
	pop ax
	pop bx
	ret


;*************************************************;
; util16_get_random -- Return a random integer between low and high (inclusive) (wait at least a second between two calls!)
; IN: AX = low integer, BX = high integer
; OUT: CX = random integer
;*************************************************;
util16_get_random:
	push dx
	push bx
	push ax

	sub bx, ax				; We want a number between 0 and (high-low)
	call util16_gen_random
	mov dx, bx
	add dx, 1
	mul dx
	mov cx, dx

	pop ax
	pop bx
	pop dx
	add cx, ax				; Add the low offset back
	ret


;*************************************************;
; util16_gen_random
;*************************************************;
util16_gen_random:
	push dx
	push bx

	mov ax, [util16_random_seed]
	mov dx, 0x7383			; The magic number (random.org)
	mul dx					; DX:AX = AX * DX
	mov [util16_random_seed], ax

	pop bx
 	pop dx
	ret


;*************************************************;
; util16_wait_key
;*************************************************;
util16_wait_key:
			pusha
.Wait		mov ax, 0x100		; Is there a key pressed?
			int 0x16
			jz .Wait
			popa
			ret


section .data

util16_txts				db "AX: BX: CX: DX: CS: DS: ES: SS: SI: DI: BP: SP: FL: "
;flag(pushf & pop ax)
;NLCRtxt db 13, 10
;Floating : ST0 ...
;Control: CR0 ...
util16_random_seed		dw	0
UTIL16_NUMSTORAGE	times 5 db 0


%endif

