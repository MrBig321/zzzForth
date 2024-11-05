
;*************************************************
;	stdio.inc
;		- 32-bit Input/Output routines
;
;*************************************************

%ifndef __STDIO__
%define __STDIO__


bits 32


%define	STDIO_VIDMEM		0xB8000			; video memory
%define	STDIO_COLS			80				; width and height of screen
%define	STDIO_LINES			25
%define	STDIO_CHAR_ATTRIB 	0x02			; Green on Black (lower 4 bits: foreground(0: blue, 1:green, 2:red, 3:intensity), higher 4 bits: backgrnd(same as foregrnd))

; Block
;%define STDIO_BACKUP		0x1EF000
;%define	STDIO_LIST_ROWS		16
;%define	STDIO_LIST_COLS		64
;%define	STDIO_LIST_OFFS_X	4
;%define	STDIO_LIST_OFFS_Y	5


section .text

;**************************************************;
;	stdio_put_ch 
;		- Prints a character to screen
;	BL => Character to print
;**************************************************;
stdio_put_ch:
			pushad							; save registers
			mov	edi, STDIO_VIDMEM			; get pointer to video memory

			;-------------------------------;
			;   Get current position		;
			;-------------------------------;

			xor	eax, eax					; clear eax
	
			;--------------------------------
			; Remember: currentPos = x + y * STDIO_COLS! x and y are in stdio_cur_x and stdio_cur_y.
			; Because there are two bytes per character, STDIO_COLS=number of characters in a line.
			; We have to multiply this by 2 to get number of bytes per line. This is the screen width,
			; so multiply screen with * stdio_cur_y to get current line
			;--------------------------------

			mov	ecx, STDIO_COLS*2			; Mode 7 has 2 bytes per char, so its STDIO_COLS*2 bytes per line
			mov	al, byte [stdio_cur_y]		; get y pos
			mul	ecx							; multiply y*STDIO_COLS
			push eax						; save eax--the multiplication

			;--------------------------------
			; Now y * screen width is in eax. Now, just add stdio_cur_x. But, again remember that stdio_cur_x is relative
			; to the current character count, not byte count. Because there are two bytes per character, we
			; have to multiply stdio_cur_x by 2 first, then add it to our screen width * y.
			;--------------------------------

			mov	al, byte [stdio_cur_x]		; multiply stdio_cur_x by 2 because it is 2 bytes per char
			mov	cl, 2
			mul	cl
			pop	ecx							; pop y*STDIO_COLS result
			add	eax, ecx

			;-------------------------------
			; Now eax contains the offset address to draw the character at, so just add it to the base address
			; of video memory (Stored in edi)
			;-------------------------------

			xor	ecx, ecx
			add	edi, eax					; add it to the base address

			;-------------------------------;
			;   Watch for new line          ;
			;-------------------------------;

			cmp	bl, 0x0A					; is it a newline character?
			je	.Row						; yep--go to next row

			;-------------------------------;
			;   Print a character           ;
			;-------------------------------;

			mov	dl, bl						; Get character
			mov	dh, STDIO_CHAR_ATTRIB		; the character attribute
			mov	word [edi], dx				; write to video display

			;-------------------------------;
			;   Update next position        ;
			;-------------------------------;

			inc	byte [stdio_cur_x]			; go to next character
			cmp	byte [stdio_cur_x], STDIO_COLS	; are we at the end of the line?
			je	.Row						; yep-go to next row
			jmp	.done						; nope, bail out

			;-------------------------------;
			;   Go to next row              ;
			;-------------------------------;

.Row		mov	byte [stdio_cur_x], 0		; go back to col 0
			cmp BYTE [stdio_cur_y], STDIO_LINES-1	; in the last line of the screen?
			je	.Scroll
			inc	byte [stdio_cur_y]			; go to next row
			jmp .done
.Scroll		call stdio_scroll_scr

			;-------------------------------;
			;   Restore registers & return  ;
			;-------------------------------;

.done		popad							; restore registers and return
			ret

;**************************************************;
;	stdio_puts 
;		- Prints a null terminated string
;	parm\ EBX = address of string to print
;**************************************************;
stdio_puts:

			;-------------------------------;
			;   Store registers             ;
			;-------------------------------;

			pushad						; save registers
			push ebx					; copy the string address
			pop	edi

.loop:
			;-------------------------------;
			;   Get character               ;
			;-------------------------------;

			mov	bl, byte [edi]			; get next character
			cmp	bl, 0					; is it 0 (Null terminator)?
			je	.done					; yep-bail out

			;-------------------------------;
			;   Print the character         ;
			;-------------------------------;

			call stdio_put_ch			; Nope-print it out

			;-------------------------------;
			;   Go to next character        ;
			;-------------------------------;

			inc	edi						; go to next character
			jmp	.loop

.done:
			;-------------------------------;
			;   Update hardware cursor      ;
			;-------------------------------;

			; It's more efficient to update the cursor after displaying
			; the complete string because direct VGA is slow

;			mov	bh, byte [stdio_cur_y]	; get current position
;			mov	bl, byte [stdio_cur_x]
;			call stdio_mov_cur			; update cursor

			popad						; restore registers, and return
			ret

;**************************************************;
;	stdio_mov_cur 
;		- Update hardware cursor
;	parm/ bh = Y pos
;	parm/ bl = X pos
;**************************************************;
stdio_mov_cur:
			pushad

			;-------------------------------;
			;   Get current position        ;
			;-------------------------------;

			; Here, stdio_cur_x and stdio_cur_y are relative to the current position on screen, not in memory.
			; That is, we don't need to worry about the byte alignment we do when displaying characters,
			; so just follow the forumla: location = stdio_cur_x + stdio_cur_y * STDIO_COLS

			xor	eax, eax
			mov	ecx, STDIO_COLS
			mov	al, bh							; get y pos
			mul	ecx								; multiply y*STDIO_COLS
			xor ecx, ecx						; the next 3 lines are fix
			mov cl, bl
			add eax, ecx						; Now add x
			mov	ebx, eax

			;--------------------------------------;
			;   Set low byte index to VGA register ;
			;--------------------------------------;

;			xor	eax, eax						; my addition !?

			mov	al, 0x0f
			mov	dx, 0x03D4
			out	dx, al

			mov	al, bl
			mov	dx, 0x03D5
			out	dx, al							; low byte

			;---------------------------------------;
			;   Set high byte index to VGA register ;
			;---------------------------------------;

			xor	eax, eax

			mov	al, 0x0e
			mov	dx, 0x03D4
			out	dx, al

			mov	al, bh
			mov	dx, 0x03D5
			out	dx, al							; high byte

			popad
			ret

;**************************************************;
;	stdio_clrscr 
;		- Clears screen
;**************************************************;
stdio_clrscr:
			pushad
			cld
			mov	edi, STDIO_VIDMEM
			mov	cx, 2000
			mov	ah, STDIO_CHAR_ATTRIB
			mov	al, ' '	
			rep	stosw

			mov	byte [stdio_cur_x], 0
			mov	byte [stdio_cur_y], 0
;			std
			popad
			ret

;**************************************************;
;	stdio_goto_xy 
;		- Set current X/Y location
;	parm\	AL=X position
;	parm\	AH=Y position
;**************************************************;
stdio_goto_xy:
;			pushad
			mov	[stdio_cur_x], al					; just set the current position
			mov	[stdio_cur_y], ah
;			popad
			ret


;**************************************************;
;	stdio_scroll_scr
;	Scrolls the screen up a row
;**************************************************;
stdio_scroll_scr:
			pushad
			mov	edi, STDIO_VIDMEM ;+160				; +160 is second row (80 * 2) ; skips first row because of date and time
			mov	esi, STDIO_VIDMEM+160 ;+320			; +320 is third row (two times 80 * 2)
			mov	ecx, 2000 ;-160
			rep	movsw
			mov	edi, STDIO_VIDMEM+(2000-80)*2	; clear last row
			mov	ecx, 80
			mov	ah, STDIO_CHAR_ATTRIB
			mov	al, ' '	
			rep	stosw
			popad
			ret


;*************************************************;
; stdio_update_cur
;*************************************************;
stdio_update_cur:
			pushad
			mov	bh, byte [stdio_cur_y]				; get current position
			mov	bl, byte [stdio_cur_x]
			call stdio_mov_cur						; update cursor
			popad
			ret


;*************************************************;
; stdio_new_line
;*************************************************;
stdio_new_line:
			push ebx
			mov bl, 0x0A
			call stdio_put_ch
			call stdio_update_cur
			pop ebx
			ret


;*************************************************;
; stdio_prompt
;*************************************************;
stdio_prompt:
			push ebx
			mov	ebx, stdio_prompt_txt
			call stdio_puts
			call stdio_update_cur
			pop ebx
			ret


;*************************************************;
; stdio_bckspace
;*************************************************;
stdio_bckspace:
			push ebx
			cmp BYTE [stdio_cur_x], 0
			jnz .Dec
			mov BYTE [stdio_cur_x], STDIO_COLS-1
			dec BYTE [stdio_cur_y]
			jmp .Pr
.Dec		dec BYTE [stdio_cur_x]
.Pr			mov bl, ' '
			call stdio_put_ch
			cmp BYTE [stdio_cur_x], 0
			jnz .Dec2
			mov BYTE [stdio_cur_x], STDIO_COLS-1
			dec BYTE [stdio_cur_y]
			jmp .Upd
.Dec2		dec BYTE [stdio_cur_x]
.Upd		call stdio_update_cur
			pop ebx
			ret


;*************************************************;
;	stdio_put_chs
;	ESI : chars
;	ECX : number of chars to print
;************************************************;
stdio_put_chs:
			push ebx
.Next		mov	bl, [esi]	
			call stdio_put_ch
			inc esi
			loop .Next
			pop ebx
			ret		


;*************************************************;
;	stdio_put_bits
;	AL: byte
;	Prints the bits of a byte
;************************************************;
stdio_put_bits:
			pushad
			mov	cx, 8				; byte consists of eight bits
.Sub1		mov	bl, "0"
			shl	al, 1
			jnc	.Sub2
			mov	bl, "1"
.Sub2		call stdio_put_ch
			loop .Sub1
			popad
			ret


;*************************************************;
;	stdio_put_bcd 				;put_hex can also print a bcd! (bcd is a subset of hex)
;	AH (AX): digits to print
;	Prints BCD number
;************************************************; 
stdio_put_bcd:
			pushad
			mov cx, 2				; 2 digits
.NextNum	push cx
			mov cx, 4				; 4 bits per digit
			xor bl, bl				; zero out BL
.Rotate		shl ax, 1				; Rotate AH to BL
			rcl bl, 1
			loop .Rotate
			add bl, 48				; to char-code
			call stdio_put_ch
			pop cx
			loop .NextNum
			popad
			ret

			
;*************************************************;
;	stdio_put_dec
;	EAX: Number to Print
;	Prints Decimal number (e.g. dd 3457678)
;************************************************; 
stdio_put_dec:
			pushad
			mov edi, STDIO_NUMSTORAGE
			mov ebx, 10				; to divide with
			xor ecx, ecx
.Sub1		xor edx, edx
			div ebx
			mov [edi], dl			; save the low byte of the remainder of the divison
			inc ecx
			inc edi
			or eax, eax
			jnz .Sub1
			mov esi, edi			; load DI-1 to SI, this is the last digit
			dec esi
			xor edi, edi
.Sub2		mov bl, [esi]			; loads into AL the last digit, what is really the first
			add bl, 48				; "0"
			call stdio_put_ch
			dec esi
			loop .Sub2
			popad
			ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
stdio_put_dec64:
			ret


;*************************************************;
;	stdio_put_signed_dec
;	EAX: Number to Print ; dword should be passed (sign bit)!? or TEST will handle both!?
;	Prints decimal number (e.g. dd 3457678) with sign, if negative
;************************************************; 
stdio_put_signed_dec:
			pushad
			test eax, eax
			js .neg
			jmp .pos
.neg 		push eax
			mov bl, '-'
			call stdio_put_ch
			pop eax
			neg eax
.pos		call stdio_put_dec
			popad
			ret


;*************************************************;
;	stdio_put_hex
;	EDX: number
;	Prints hex number
;************************************************; 
stdio_put_hex:
			pushad
			mov ecx, 8
			mov esi, STDIO_HEXTABLE
.NextNum	push ecx
			mov ecx, 4			; A digit consists of 4 bits
			xor eax, eax
.Rotate		shl	edx, 1			; Rotating the upper 4 bits of EDX to AL
			rcl eax, 1
			loop .Rotate
			xor ebx, ebx
			mov bl, al
			mov al, BYTE [esi+ebx]
			mov bl, al
			call stdio_put_ch
			pop ecx
			loop .NextNum
			popad
			ret


;*************************************************;
;	stdio_put_hex16
;	DX: number
;	Prints hex number
;************************************************; 
stdio_put_hex16:
			pushad
			mov ecx, 4
			mov esi, STDIO_HEXTABLE
.NextNum	push ecx
			mov ecx, 4			; A digit consists of 4 bits
			xor eax, eax
.Rotate		shl	dx, 1			; Rotating the upper 4 bits of DX to AL
			rcl al, 1
			loop .Rotate
			xor ebx, ebx
			mov bl, al
			mov al, BYTE [esi+ebx]
			mov bl, al
			call stdio_put_ch
			pop ecx
			loop .NextNum
			popad
			ret


;*************************************************;
;	stdio_put_hex8
;	DH: number
;	Prints hex number
;************************************************; 
stdio_put_hex8:
			pushad
			mov ecx, 2
			mov esi, STDIO_HEXTABLE
.NextNum	push ecx
			mov ecx, 4			; A digit consists of 4 bits
			xor eax, eax
.Rotate		shl	dh, 1			; Rotating the upper 4 bits of DX to AL
			rcl al, 1
			loop .Rotate
			xor ebx, ebx
			mov bl, al
			mov al, BYTE [esi+ebx]
			mov bl, al
			call stdio_put_ch
			pop ecx
			loop .NextNum
			popad
			ret


;*************************************************;
;	stdio_put_hex4
;	DH: number (upper 4 bits)
;	Prints hex digit
;************************************************; 
stdio_put_hex4:
			pushad
			mov esi, STDIO_HEXTABLE
			mov ecx, 4			; A digit consists of 4 bits
			xor eax, eax
.Rotate		shl	dh, 1			; Rotating the upper 4 bits of DX to AL
			rcl al, 1
			loop .Rotate
			xor ebx, ebx
			mov bl, al
			mov bl, BYTE [esi+ebx]
			call stdio_put_ch
			popad
			ret


section .data


stdio_cur_x db 0							; current x/y location
stdio_cur_y db 0

STDIO_HEXTABLE		db	"0123456789ABCDEF"
STDIO_NUMSTORAGE	times 10 db 0
STDIO_NUMSTORAGE64	times 25 db 0

stdio_prompt_txt	db	"fos>", 0
STDIO_PROMPT_LEN	equ	$-stdio_prompt_txt


%endif

