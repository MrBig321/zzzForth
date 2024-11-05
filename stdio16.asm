%ifndef __STDIO16__
%define __STDIO16__


bits 16


section .text

;*************************************************;
;	stdio16_put_ch
;	AL: char
;	Prints a char
;************************************************;
stdio16_put_ch:
			mov	ah,	0eh	
			int	10h
			ret


;*************************************************;
;	stdio16_put_bits
;	BL: byte
;	Prints bits of a byte
;************************************************;
stdio16_put_bits:
			pusha
			mov	cx, 8			; byte consists of eight bits
.Sub1		mov	al, "0"
			shl	bl, 1
			jnc	.Sub2
			mov	al, "1"
.Sub2		call stdio16_put_ch
			loop .Sub1
			popa
			ret


;*************************************************;
;	stdio16_put_chs
;	DS=>SI : chars
;	CX : number of chars to print
;	Prints chars
;************************************************;
 stdio16_put_chs:
			pusha
.Next		mov	al, [si]	
			call stdio16_put_ch
			inc si
			loop .Next
			popa
			ret		


;*************************************************;
;	stdio16_puts
;	DS=>SI : 0 terminated string
;	Prints a string
;************************************************;
; maybe pass the terminal char!?
stdio16_puts:
			pusha
.Next		lodsb				; load next byte from string from SI to AL
			cmp al, 0			; AL=0?
			jz	.PrintDone		; Yep, null terminator found-bail out
			call stdio16_put_ch	; Nope-Print the character
			jmp	.Next			; Repeat until null terminator found (max 255 char!?)
.PrintDone:
			popa
			ret		; we are done, so return


;*************************************************;
;	stdio16_put_bcd
;	BH (BX): digits to print
;	Prints BCD number
;************************************************; 
stdio16_put_bcd:
			pusha
			mov cx, 2		; 2 digits
.NextNum	push cx
			mov cx, 4		; 4 bits per digit
			xor al, al		; zero out AL
.Rotate		shl bx, 1		; Rotate BH to AL
			rcl al, 1
			loop .Rotate
			add al, 48		; to char-code
			call stdio16_put_ch
			pop cx
			loop .NextNum
			popa
			ret

			
;*************************************************;
;	stdio16_put_dec
;	AX: Number to Print
;	Prints Decimal number (e.g. dw 34576)
;************************************************; 
stdio16_put_dec:
			pusha
			mov di, STDIO16_NUMSTORAGE
			mov bx, 10		; to divide with
			xor cx, cx
.Sub1		xor dx, dx
			div bx
			mov [di], dl	; save the low byte of the remainder of the divison
			inc cx
			inc di
			or ax, ax
			jnz .Sub1
			mov si, di		; load DI-1 to SI, this is the last digit
			dec si
			xor di, di
.Sub2		mov al, [si]	; loads into AL the last digit, what is really the first
			add al, 48		; "0"
			call stdio16_put_ch
			dec si
			loop .Sub2
			popa
			ret


;*************************************************;
;	stdio16_put_signed_dec
;	AX: Number to Print ; word should be passed (sign bit)!? or TEST will handle both!?
;	Prints decimal number (e.g. dw 34576) with sign, if negative
;************************************************; 
stdio16_put_signed_dec:
			pusha
			test ax, ax
			js .neg
			jmp .pos
.neg 		push ax
			mov al, '-'
			call stdio16_put_ch
			pop ax
			neg ax
.pos		call stdio16_put_dec
			popa
			ret


;*************************************************;
;	stdio16_put_hex
;	DX: number (Dx word; DH byte)
;	CX: number of digits to print (isn't it always 4!?)
;	Prints hex number
;************************************************; 
stdio16_put_hex:
			pusha
			mov bx, STDIO16_HEXTABLE
.NextNum	push cx
			mov cx, 4	; A digit consists of 4 bits
			xor al, al
.Rotate		shl	dx, 1	; Rotating the upper 4 bits of DX to AL
			rcl al, 1
			loop .Rotate
			xlat		; BX+AL (BX: table, the AL-th cell) the data from this address will be loaded to AL
			call stdio16_put_ch
			pop cx
			loop .NextNum
			popa
			ret


;*************************************************;
;	stdio16_put_hex32
;	EDX: number
;	Prints hex number
;************************************************; 
stdio16_put_hex32:
			pusha
			mov bx, STDIO16_HEXTABLE
			mov cx, 8	; 8 digits
.NextNum	push cx
			mov cx, 4	; A digit consists of 4 bits
			xor al, al
.Rotate		shl	edx, 1	; Rotating the upper 4 bits of DX to AL
			rcl al, 1
			loop .Rotate
			xlat		; BX+AL (BX: table, the AL-th cell) the data from this address will be loaded to AL
			call stdio16_put_ch
			pop cx
			loop .NextNum
			popa
			ret


;*************************************************;
; stdio16_new_line
;*************************************************;
stdio16_new_line:
			pusha
			mov al, 13
			call stdio16_put_ch
			mov al, 10
			call stdio16_put_ch
			popa
			ret


;*************************************************;
; stdio16_put_h
;*************************************************;
stdio16_put_h:
			mov al, 'h'
			call stdio16_put_ch
			mov al, ' '
			call stdio16_put_ch
			ret


section .data

STDIO16_HEXTABLE	db	"0123456789ABCDEF"
STDIO16_NUMSTORAGE	times 5 db 0


%endif

