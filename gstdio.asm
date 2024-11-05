
;*************************************************
;	gstdio.inc
;		- Graphical standard i/o routines
;
;*************************************************

%ifndef __GSTDIO__
%define __GSTDIO__

%include "defs.asm"
%include "gstdiodefs.asm"
%include "pit.asm"
;%include "forth/core.asm"	; _discard
%include "gutil.asm"


bits 32


section .text

;***************************
; gstdio_draw_char_pix
;	EBX:	char to print
;	ECX:	x
;	EAX:	y
;	EDX:	bkgclr (lower 16 bits)
;	EDX:	fgclr (higher 16 bits)
;	gstdio_opaque:	memloc (but could be with [esp+4] like the color in drawLine)
;***************************
gstdio_draw_char_pix:
			pushad
			mov esi, DWORD [gstdio_scrbuff]
			push ebx
			mov ebx, ecx
			shl ebx, 1				; A pixel is 2 bytes: x1*2 is the xoffset
			add esi, ebx
			push edx
			mov ebx, [gstdio_row_byte_cnt]
			mul ebx
			add esi, eax
			pop edx
			pop ebx
			mov eax, ebx
			sub eax, 32				; char-array is from SPACE, so subtract it
			mov ebx, eax
%ifdef GSTDIO_NORMAL_FONT
			shl	eax, 4				; a char contains 48 bytes: *16 + *32
			shl ebx, 5
			add ebx, eax
%else
			shl	ebx, 5				; a char contains 30 bytes: *32 - *2	(640*480*16)
			shl eax, 1
			sub ebx, eax
%endif
			add ebx, gfont_charr
			mov ecx, GSTDIO_CHAR_HEIGHT
.NextRow	push ecx
			xor edi, edi			; first byte or second one (width)
			xor ecx, ecx			; current pixel number
			mov al, BYTE [ebx]
.NextPixel	shl al, 1
			jnc .Bkg
			push edi
			mov edi, edx
			shr edi, 16
			mov bp, di
			pop edi
			jmp .Set
.Bkg		cmp WORD [gstdio_opaque], 1
			jnz	.Next
			mov bp, dx
.Set		shl	ecx, 1
			mov WORD [esi+ecx], bp
			shr ecx, 1
.Next		inc ecx
			cmp ecx, 8
			jc	.NextPixel
			cmp edi, 1
			jz	.ChkRowEnd
			inc ebx
			mov al, BYTE [ebx]
			mov edi, 1
.ChkRowEnd	cmp ecx, GSTDIO_CHAR_WIDTH
			jc	.NextPixel
			inc ebx	
			add esi, [gstdio_row_byte_cnt]
			pop ecx
			loop .NextRow
			cmp BYTE [gstdio_cp_to_fbuff_on], 1
            jnz	.Back
		; copy to FRAMEBUFFER
			popad
			pushad
			mov esi, DWORD [gstdio_scrbuff]
			mov edi, DWORD [gstdio_framebuff]
			shl ecx, 1				; a pixel is two bytes
			add esi, ecx
			add edi, ecx
			mov ebx, GSTDIO_XRES
			shl ebx, 1
			mul ebx
			add esi, eax
			add edi, eax
			mov ecx, GSTDIO_CHAR_HEIGHT
.NextLFB	push ecx
			mov ecx, (GSTDIO_CHAR_WIDTH / 2)	; a pixel is two bytes and a char is GSTDIO_CHAR_WIDTH pixels wide (GSTDIO_CHAR_WIDTH *2/4)
			rep	movsd
			pop ecx
			sub esi, GSTDIO_CHAR_WIDTH * 2		; a pixel is two bytes
			sub edi, GSTDIO_CHAR_WIDTH * 2
			add esi, ebx
			add edi, ebx
			loop .NextLFB
.Back		popad
			ret


;***************************
; gstdio_draw_char
;	EBX:	char to print
;	colors:	memory locations
;***************************
gstdio_draw_char:
			pushad

			cmp bl, KEY_TAB
			jnz	.ChkRec
			mov ebx, 32

.ChkRec		cmp BYTE [gstdio_skip_recording], 1
			je	.ChkNL

			; draw char to output-buff
			cmp BYTE [gstdio_outp_recording], 1
			jne	.ChkNL
			; ignore initial newline
			cmp	DWORD [gstdio_outpbuff_pos], 0
			jnz	.ToOutp
			cmp bl, KEY_RETURN
			jz	.NewLine
.ToOutp		mov eax, [gstdio_outpbuff]
			add eax, [gstdio_outpbuff_pos]
			mov [eax], bl
			inc	DWORD [gstdio_outpbuff_pos]

			; check overflow
			cmp	DWORD [gstdio_outpbuff_pos], GSTDIO_OUTPBUFF_LEN 
			jc	.ChkNL
			mov	DWORD [gstdio_outpbuff_pos], 0

.ChkNL		cmp bl, KEY_RETURN
			jz	.NewLine

			cmp BYTE [gstdio_skip_txtbuff], 1
			je	.DrawChar

			; draw char to text-buff
			push ebx
			xor eax, eax
			mov al, [gstdio_cur_y]			; here we omit adding gstdio_col_beg
			xor ebx, ebx
			mov bl, [gstdio_col_cnt]
			mul ebx
			xor ebx, ebx
			mov bl, [gstdio_cur_x]			; here we omit adding gstdio_row_beg
			add eax, ebx
			pop ebx
			add eax, [gstdio_txtbuff]
			mov [eax], bl

			; draw char
.DrawChar	call gstdio_drawchar_sized
			mov al, [gstdio_col_cnt]
			dec al
			cmp BYTE [gstdio_cur_x], al
			jz .NewLine
			inc	byte [gstdio_cur_x]	
			jmp .Back
.NewLine	mov al, [gstdio_row_cnt]
			dec al
			cmp BYTE [gstdio_cur_y], al
			je	.Scroll
			mov	BYTE [gstdio_cur_x], 0
			inc	byte [gstdio_cur_y]
			jmp .Back
.Scroll		cmp BYTE [gstdio_skip_scroll], 1
			je	.Back
			mov	BYTE [gstdio_cur_x], 0
			call gstdio_scroll_screen
.Back		popad
			ret


; Draws the chars from text-buff to screen-buff (then gstdio_invalidate will copy the contents of screen-buff to the frame-buffer)
gstdio_draw_chars_from_txtbuff:
			pushad
			mov BYTE [gstdio_cur_x], 0
			mov BYTE [gstdio_cur_y], 0
			mov ebp, [gstdio_txtbuff]
			mov esi, [gstdio_txtbuff]
			add esi, GSTDIO_COLS_NUM*GSTDIO_ROWS_NUM
.NextCh		xor ebx, ebx
			mov bl, [ebp]
			call gstdio_drawchar_sized
			cmp BYTE [gstdio_cur_x], GSTDIO_COLS_NUM-1
			jz .NewLine
			inc	byte [gstdio_cur_x]			; inc cursor
			jmp .Inc
.NewLine	mov	BYTE [gstdio_cur_x], 0		; go back to col 0
			inc	byte [gstdio_cur_y]			; go to next row
.Inc		inc ebp
			cmp ebp, esi
			jne	.NextCh
.Back		popad
			ret


;***************************
; gstdio_draw_cursor
;	EBX:	Char under the cursor
;	BP:	Cursor's color (put or remove it)
;	colors:	memory locations
;***************************
gstdio_draw_cursor:
			pushad
			xor ecx, ecx
			mov cl, BYTE [gstdio_cur_x]
		add cl, [gstdio_col_beg]
%ifdef GSTDIO_NORMAL_FONT
			shl ecx, 4						; *16
			xor eax, eax
			mov al, BYTE [gstdio_cur_y]
		add al, [gstdio_row_beg]
			mov edx, eax
			shl eax, 4						; *16
			shl edx, 3						; *8
			add eax, edx					; *24
%else
			mov eax, ecx					; below: for 640*480*16 (10*15 char)
			shl ecx, 3
			shl eax, 1
			add ecx, eax					; *10  (*8 + *2)
			xor eax, eax
			mov al, BYTE [gstdio_cur_y]
		add al, [gstdio_row_beg]
			mov edx, eax
			shl eax, 4						; *16
			sub eax, edx					; *15	(*16 - *1)
%endif
			mov dx, WORD [gstdio_fgclr]
			shl edx, 16
			mov dx, bp
			mov bp, WORD [gstdio_opaque]
			mov WORD [gstdio_opaque], 1
			call gstdio_draw_char_pix
			mov WORD [gstdio_opaque], bp
			popad
			ret


;***************************
; gstdio_draw_text
;	EBX:	address of chars to print	
;	colors memory locations
;***************************
gstdio_draw_text:
			push edi
			push ebx
			mov edi, ebx
			xor ebx, ebx
.Next		mov bl, BYTE [edi]
			cmp bl, 0
			je	.Done
			call gstdio_draw_char
			inc edi
			jmp .Next
.Done		pop ebx
			pop edi
			ret


;**************************************************;
; gstdio_goto_xy 
;	Sets current X/Y location of cursor
;	AL:	X position
;	AH:	Y position
;**************************************************;
; NOTE: X, Y is from zero, because gstdio_col_beg and gstdio_row_beg will be added in gstdio_drawchar_sized. So they are relative
gstdio_goto_xy:
			cmp al, [gstdio_col_cnt]
			jnc	.Fix						; also handles negative X
			cmp ah, [gstdio_row_cnt]
			jc .Store						; also handles negative Y
.Fix		mov	ax, 0
.Store		mov	[gstdio_cur_x], al
			mov	[gstdio_cur_y], ah
			ret


;**************************************************;
; gstdio_remove_cursor
;	EBX:	Char under the cursor
;**************************************************;
gstdio_remove_cursor:
			push ebp
			mov bp, WORD [gstdio_bkgclr]
			call gstdio_draw_cursor
			pop ebp
			ret


;**************************************************;
; gstdio_put_cursor
;	EBX:	Char under the cursor
;**************************************************;
gstdio_put_cursor:
			push ebp
			mov bp, WORD [gstdio_currclr]
			call gstdio_draw_cursor
			pop ebp
			ret


; fills text-buff with spaces
gstdio_clr_txtbuff:
			pushad
			mov edi, [gstdio_txtbuff]
			mov	ecx, GSTDIO_COLS_NUM*GSTDIO_ROWS_NUM
			shr ecx, 2						; divide by 4 to get DWORD
			mov eax, 0x20202020
			rep	stosd
			popad
			ret


; clears screen-buffer
; IN: EBX(if 1, invalidates screen)
gstdio_clr_scrbuff:
			pushad
			mov edi, [gstdio_scrbuff]
			cmp BYTE [gstdio_full_row], 1			; we can use "rep"
			jne	.ByRow
			add edi, [gstdio_rect_offs]
			mov	ecx, [gstdio_rect_bytes]
			shr ecx, 1	
			mov ax, WORD [gstdio_bkgclr]
			rep	stosw
			jmp .PutCur
.ByRow		xor edx, edx
			add edi, [gstdio_row_offs]
.NextPxRow	push edi							; Here a row means a row of pixels, not chars!
			mov ecx, [gstdio_pxrow_bytes]
			shr ecx, 1					
			mov ax, WORD [gstdio_bkgclr]
			rep stosw
			inc edx
			pop edi
			add edi, GSTDIO_ROW_BYTE_NUM
			cmp edx, [gstdio_pxrow_cnt]
			jc	.NextPxRow
.PutCur		mov ax, 0
			call gstdio_goto_xy
			cmp ebx, 1
			jne	.Back
			call gstdio_invalidate
.Back		popad
			ret


;**************************************************;
; gstdio_clrscr
;	
;**************************************************;
gstdio_clrscr:
			cmp BYTE [gstdio_skip_txtbuff], 1
			je	.DoScr
			call gstdio_clr_txtbuff
.DoScr		call gstdio_clr_scrbuff
			ret


;**************************************************;
; gstdio_output
;
;	Displays output of last word (max GSTDIO_OUTBUFF_SCRS screens)
;	addr ([gstdio_outpbuff]) needs to be 64-byte aligned	!? NOT SURE ABOUT THAT!!
;**************************************************;
gstdio_output:
			mov ebx, [gstdio_outpbuff]
			mov ecx, [gstdio_outpbuff_pos]
			PUSH_PS(ebx)
			PUSH_PS(ecx)
			PUSH_PS(gstdio_txtvwtxt)
			call _find
			POP_PS(eax)		; drop flags|len
			call _execute
			ret


; Displays text,one page at a time. Press a key for next page
; This can be overridden, if we load TXTVW from FORTH-source
; IN: EBX(addr), ECX(len)
gstdio_txt_view:
			push esi
			push ebp
		; init
			; cursor
			mov al, [gstdio_cur_x]
			mov [gstdio_cur_x_saved], al
			mov al, [gstdio_cur_y]
			mov [gstdio_cur_y_saved], al

			cmp ecx, 0
			jnz	.Do
			mov ebx, 1
			call gstdio_clrscr
			call gutil_press_a_key_notxt
			jmp .Back2

.Do			mov al, [gstdio_skip_recording]
			mov [gstdio_skip_recording_saved], al
			mov al, [gstdio_skip_txtbuff]
			mov [gstdio_skip_txtbuff_saved], al
			mov al, [gstdio_skip_scroll]
			mov [gstdio_skip_scroll_saved], al
			mov BYTE [gstdio_skip_recording], 1
			mov BYTE [gstdio_skip_txtbuff], 1
			mov BYTE [gstdio_skip_scroll], 1
		; end of init
			mov esi, ebx
			mov eax, [gstdio_row_cnt]
			mov ebx, [gstdio_col_cnt]
			mul ebx
			mov ebp, eax							; EBP contains char-count of the screen
.NextPage	mov ebx, 1
			call gstdio_clrscr						; also inits cursor's position
			xor edx, edx							; number of characters drawn
			xor ebx, ebx
.NextCh		mov bl, [esi]
			call gstdio_is_printable_char
			cmp eax, 1
			jz	.Draw
			cmp bl, 0x09							; TAB
			jnz	.ChkENTER
			mov bl, 0x20							; Draw SPACE if TAB
			jmp .Draw
.ChkENTER	cmp bl, 0x0A
			jnz .Inc2
			mov al, [gstdio_row_cnt]
			dec al
			cmp [gstdio_cur_y], al
			jc	.CalcCnt
			mov edx, ebp
			jmp .Inc2
		; calc #chars till end of row 
.CalcCnt	xor eax, eax
			mov al, [gstdio_col_cnt]
			sub al, [gstdio_cur_x]
			add edx, eax
.Draw		call gstdio_draw_char
			inc edx
.Inc2		inc esi
			cmp edx, ebp
			jc	.Loop
			call gutil_press_a_key_notxt
			cmp ecx, 1
			je	.Loop			; or .Out !?
			dec ecx
			jmp .NextPage
.Loop		loop .NextCh
.Out		call gutil_press_a_key_notxt
		; restore
.Back		mov al, [gstdio_skip_scroll_saved]
			mov BYTE [gstdio_skip_scroll], al
			mov ebx, 1
			call gstdio_clr_scrbuff
			call gstdio_draw_chars_from_txtbuff
			mov al, [gstdio_skip_recording_saved]
			mov BYTE [gstdio_skip_recording], al
			mov al, [gstdio_skip_txtbuff_saved]
			mov BYTE [gstdio_skip_txtbuff], al
			; cursor
.Back2		mov al, BYTE [gstdio_cur_x_saved]
			mov BYTE [gstdio_cur_x], al
			mov al, BYTE [gstdio_cur_y_saved]
			mov BYTE [gstdio_cur_y], al
			pop ebp
			pop	esi
			ret


; IN: EBX(char)
; OUT: EAX(1 if printable)
gstdio_is_printable_char:
			xor eax, eax
			cmp ebx, 32
			jc	.Back
			cmp ebx, 127
			jnc	.Back
			mov eax, 1
.Back		ret


;**************************************************;
; gstdio_new_line
;	
;**************************************************;
gstdio_new_line:
			push ebx
			mov ebx, KEY_RETURN
			call gstdio_draw_char
			pop ebx
			ret


;**************************************************;
; gstdio_scroll_screen
;	Scrolls the screen up a row
;**************************************************;
gstdio_scroll_screen:
			pushad
			cmp BYTE [gstdio_skip_txtbuff], 1
			jz	.DoScr
			; text-buff
			mov edi, [gstdio_txtbuff]
			mov esi, [gstdio_txtbuff]
			add esi, GSTDIO_COLS_NUM
			mov	ecx, GSTDIO_COLS_NUM*GSTDIO_ROWS_NUM
			sub ecx, GSTDIO_COLS_NUM
			shr	ecx, 2
			rep	movsd
			; clear last row
			mov edi, [gstdio_txtbuff]
			add	edi, GSTDIO_COLS_NUM*GSTDIO_ROWS_NUM
			sub	edi, GSTDIO_COLS_NUM
			mov	ecx, GSTDIO_COLS_NUM
			shr ecx, 2
			mov eax, 0x20202020
			rep	stosd

			; screen-buff
.DoScr		cmp BYTE [gstdio_full_row], 1			; we can use "rep"
			jne	.ByRow
			mov edi, [gstdio_scrbuff]
			add edi, [gstdio_rect_offs]
			mov esi, edi
			add esi, GSTDIO_ROW_BYTES
			mov	ecx, [gstdio_rect_bytes]
			sub ecx, GSTDIO_ROW_BYTES
			shr	ecx, 2
			rep	movsd
			; clear last row
			mov edi, [gstdio_scrbuff]
			add edi, [gstdio_rect_offs]
			add edi, [gstdio_rect_bytes]
			sub	edi, GSTDIO_ROW_BYTES
			mov	ecx, GSTDIO_ROW_BYTES
			shr ecx, 2
			mov ax, [gstdio_bkgclr]
			shl eax, 16
			mov ax, [gstdio_bkgclr]
			rep	stosd
			jmp .Inv
.ByRow		mov edi, [gstdio_scrbuff]
			add edi, [gstdio_row_offs]
			xor eax, eax
.NextRow	xor edx, edx
			mov esi, edi
			add esi, GSTDIO_CHAR_HEIGHT * GSTDIO_ROW_BYTE_NUM
			push edi
			push esi
.NextPxRow	push edi
			push esi
			mov	ecx, [gstdio_pxrow_bytes]
			shr	ecx, 1	
			rep movsw
			pop esi
			pop edi
			add edi, GSTDIO_ROW_BYTE_NUM
			add esi, GSTDIO_ROW_BYTE_NUM
			inc edx
			cmp edx, GSTDIO_CHAR_HEIGHT
			jc	.NextPxRow
			pop esi
			pop edi
			add edi, GSTDIO_CHAR_HEIGHT * GSTDIO_ROW_BYTE_NUM
			add esi, GSTDIO_CHAR_HEIGHT * GSTDIO_ROW_BYTE_NUM
			inc eax
			cmp al, [gstdio_row_cnt]
			jc	.NextRow
			; clear last row
			mov edi, [gstdio_scrbuff]
			add edi, [gstdio_row_offs]
			xor eax, eax
			mov al, [gstdio_row_cnt]
			dec al
			mov	ebx, GSTDIO_ROW_BYTES
			mul ebx
			add edi, eax
			xor edx, edx
.NextPxRow2	push edi							; Here a row means a row of pixels, not chars!
			mov ecx, [gstdio_pxrow_bytes]
			shr ecx, 1					
			mov ax, WORD [gstdio_bkgclr]
			rep stosw
			inc edx
			pop edi
			add edi, GSTDIO_ROW_BYTE_NUM
			cmp edx, GSTDIO_CHAR_HEIGHT
			jc	.NextPxRow2
.Inv		call gstdio_invalidate
			popad
			ret


;*************************************************;
; gstdio_prompt
;*************************************************;
gstdio_prompt:
			push ebx
			mov	ebx, gstdio_prompt_txt
			call gstdio_draw_text
			pop ebx
			ret


;*************************************************;
; gstdio_bckspace
;*************************************************;
gstdio_bckspace:
			push ebx
			cmp BYTE [gstdio_cur_x], 0
			jnz .Dec
			mov bl, [gstdio_col_cnt]
			dec bl
			mov BYTE [gstdio_cur_x], bl
			dec BYTE [gstdio_cur_y]
			jmp .Pr
.Dec		dec BYTE [gstdio_cur_x]
.Pr			mov ebx, ' '
			call gstdio_draw_char
			cmp BYTE [gstdio_cur_x], 0
			jnz .Dec2
			mov bl, [gstdio_col_cnt]
			dec bl
			mov BYTE [gstdio_cur_x], bl
			dec BYTE [gstdio_cur_y]
			jmp .Back
.Dec2		dec BYTE [gstdio_cur_x]
.Back		pop ebx
			ret


;*************************************************;
; gstdio_draw_chars
;	ESI :	chars
;	ECX :	number of chars to print
;	colors memory locations
;************************************************;
gstdio_draw_chars:
			push ebx
			push esi
			xor ebx, ebx
.Next		mov	bl, [esi]	
			call gstdio_draw_char
			inc esi
			loop .Next
			pop esi
			pop ebx
			ret		


;*************************************************;
; gstdio_draw_bits
;	AL:		byte
;	colors memory locations
;	Prints the bits of a byte
;************************************************;
gstdio_draw_bits:
			pushad
			xor ebx, ebx
			mov	cx, 8				; byte consists of eight bits
.Sub1		mov	bl, "0"
			shl	al, 1
			jnc	.Sub2
			mov	bl, "1"
.Sub2		call gstdio_draw_char
			loop .Sub1
			popad
			ret


;*************************************************;
; gstdio_draw_dec
;	EAX:	Number to Print
;	colors memory locations
;	Prints Decimal number (e.g. dd 3457678)
;************************************************; 
gstdio_draw_dec:
			pushad
			mov edi, GSTDIO_NUMSTORAGE
			mov ebx, 10				; to divide with
			xor ecx, ecx
.Sub1		xor edx, edx
			div ebx
			mov [edi], dl			; save the low byte of the remainder of the divison
			inc ecx
			inc edi
			or eax, eax
			jnz .Sub1
			dec edi
			xor ebx, ebx
.Sub2		mov bl, [edi]			; loads into AL the last digit, what is really the first
			add bl, 48				; "0"
			call gstdio_draw_char
			dec edi
			loop .Sub2
			popad
			ret


;*************************************************;
; gstdio_draw_dec64
;	EDX:EAX: Number to Print
;	colors memory locations
;	Prints Decimal number (e.g. dq 3457678)
;************************************************; 
gstdio_draw_dec64:
			pushad
			mov edi, GSTDIO_NUMSTORAGE64
			mov ebx, 10				; to divide with
			push edx
			xor ecx, ecx
.SubLow		xor edx, edx
			div ebx
			mov [edi], dl			; save the low byte of the remainder of the divison
			inc ecx
			inc edi
			or eax, eax
			jnz .SubLow
			pop eax					; edx to eax
.SubHi		xor edx, edx
			div ebx
			mov [edi], dl			; save the low byte of the remainder of the divison
			inc ecx
			inc edi
			or eax, eax
			jnz .SubHi
			dec edi
			xor ebx, ebx
.Print		mov bl, [edi]			; loads into AL the last digit, what is really the first
			add bl, 48				; "0"
			call gstdio_draw_char
			dec edi
			loop .Print
			popad
			ret


;*************************************************;
; gstdio_draw_signed_dec
;	EAX:	Number to Print ; dword should be passed (sign bit)!? or TEST will handle both!?
;	colors memory locations
;	Prints decimal number (e.g. dd 3457678) with sign, if negative
;************************************************; 
gstdio_draw_signed_dec:
			pushad
			test eax, eax
			js .neg
			jmp .pos
.neg 		push eax
			xor ebx, ebx
			mov bl, '-'
			call gstdio_draw_char
			pop eax
			neg eax
.pos		call gstdio_draw_dec
			popad
			ret


;*************************************************;
; gstdio_draw_hex
;	EDX: 	number
;	colors memory locations
;	Prints hex number and also BCD
;************************************************; 
gstdio_draw_hex:
			pushad
			mov ecx, 8
			mov esi, GSTDIO_HEXTABLE
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
			call gstdio_draw_char
			pop ecx
			loop .NextNum
			popad
			ret


;*************************************************;
; gstdio_draw_hex16
;	DX:		number
;	colors memory locations
;	Prints hex number
;************************************************; 
gstdio_draw_hex16:
			pushad
			mov ecx, 4
			mov esi, GSTDIO_HEXTABLE
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
			call gstdio_draw_char
			pop ecx
			loop .NextNum
			popad
			ret


;*************************************************;
; gstdio_draw_hex8
;	DH:		number
;	colors memory locations
;	Prints hex number
;************************************************; 
gstdio_draw_hex8:
			pushad
			mov ecx, 2
			mov esi, GSTDIO_HEXTABLE
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
			call gstdio_draw_char
			pop ecx
			loop .NextNum
			popad
			ret


;*************************************************;
; gstdio_draw_hex4
;	DH:		number (upper 4 bits)
;	colors memory locations
;	Prints hex digit
;************************************************; 
gstdio_draw_hex4:
			pushad
			mov esi, GSTDIO_HEXTABLE
			mov ecx, 4			; A digit consists of 4 bits
			xor eax, eax
.Rotate		shl	dh, 1			; Rotating the upper 4 bits of DX to AL
			rcl al, 1
			loop .Rotate
			xor ebx, ebx
			mov bl, al
			mov bl, BYTE [esi+ebx]
			call gstdio_draw_char
			popad
			ret


;*************************************************;
; gstdio_invalidate
;	copy whole screenbuffer to FRAMEBUFFER
;*************************************************;
gstdio_invalidate:
			pushad
			mov esi, DWORD [gstdio_scrbuff]
			mov edi, DWORD [gstdio_framebuff]
			mov	ecx, GSTDIO_SCREEN_BYTES
			shr	ecx, 2
			rep	movsd
			popad
			ret


;*************************************************;
; gstdio_invalidate_rect
;	EAX: x
;	EBX: y
;	ECX: w
;	EDX: h
;	copy the given part of the screenbuffer to FRAMEBUFFER
;*************************************************;
gstdio_invalidate_rect:
			pushad
			cmp eax, GSTDIO_XRES
			jnc	.Back
			cmp ebx, GSTDIO_YRES
			jnc	.Back							; negative coords will also be ignored
			cmp ecx, 0
			je	.Back
			cmp edx, 0
			je	.Back
			mov ebp, eax
			add ebp, ecx
			cmp ebp, GSTDIO_XRES
			jnc	.Back
			mov ebp, ebx
			add ebp, edx
			cmp ebp, GSTDIO_YRES
			jnc	.Back
			mov esi, DWORD [gstdio_scrbuff]
			mov edi, DWORD [gstdio_framebuff]
			mov ebp, eax
			shl ebp, 1
			add esi, ebp
			add edi, ebp
			push edx
			mov eax, GSTDIO_XRES*2
			mul ebx
			pop edx
			add esi, eax
			add edi, eax
			xor ebp, ebp
.Line		push esi
			push edi
			push ecx
			shr	ecx, 2
			rep	movsd
			pop ecx
			pop edi
			pop esi
			add esi, GSTDIO_XRES*2
			add edi, GSTDIO_XRES*2
			inc ebp
			cmp ebp, edx
			jnz	.Line
.Back		popad
			ret


; IN: EBX(char to print), gstdio_cur_x, gstdio_cur_y, gstdio_fgclr, gstdio_chbkgclr
gstdio_drawchar_sized:
			push eax
			xor eax, eax
			mov al, [gstdio_col_beg]
			add [gstdio_cur_x], al
			mov al, [gstdio_row_beg]
			add [gstdio_cur_y], al
%ifdef GSTDIO_NORMAL_FONT
			call gstdio_drawchar_normal
%else
			call gstdio_drawchar_small
%endif
			xor eax, eax
			mov al, [gstdio_col_beg]
			sub [gstdio_cur_x], al
			mov al, [gstdio_row_beg]
			sub [gstdio_cur_y], al
			pop eax
			ret


; IN: EBX(char to print), gstdio_cur_x, gstdio_cur_y, gstdio_fgclr, gstdio_chbkgclr
;char 10*15 (640*480*16)
gstdio_drawchar_small:
			xor ecx, ecx
			mov cl, BYTE [gstdio_cur_x]
			mov eax, ecx					; below: for 640*480*16 (10*15 char)
			shl ecx, 3
			shl eax, 1
			add ecx, eax					; *10  (*8 + *2)
			xor eax, eax
			mov al, BYTE [gstdio_cur_y]
			mov edx, eax
			shl eax, 4						; *16
			sub eax, edx					; *15	(*16 - *1)
			mov dx, WORD [gstdio_fgclr]
			shl edx, 16
			mov dx, WORD [gstdio_chbkgclr]
			call gstdio_draw_char_pix
			ret


; IN: EBX(char to print), gstdio_cur_x, gstdio_cur_y, gstdio_fgclr, gstdio_chbkgclr
;char 16*24 (1024*768*16)
gstdio_drawchar_normal:
			xor ecx, ecx
			mov cl, BYTE [gstdio_cur_x]
			shl ecx, 4						; *16
			xor eax, eax
			mov al, BYTE [gstdio_cur_y]
			mov edx, eax
			shl eax, 4						; *16
			shl edx, 3						; *8
			add eax, edx					; *24
			mov dx, WORD [gstdio_fgclr]
			shl edx, 16
			mov dx, WORD [gstdio_chbkgclr]
			call gstdio_draw_char_pix
			ret

; *** Character-related ***

gstdio_os_pars_off:
			mov BYTE [gstdio_skip_txtbuff], 1
			mov BYTE [gstdio_skip_recording], 1
			ret


gstdio_os_pars_on:
			mov BYTE [gstdio_skip_txtbuff], 0
			mov BYTE [gstdio_skip_recording], 0
			ret


gstdio_scroll_off:
			mov BYTE [gstdio_skip_scroll], 1
			ret


gstdio_scroll_on:
			mov BYTE [gstdio_skip_scroll], 0
			ret


gstdio_from_main_scr:
			; check
			cmp BYTE [gstdio_row_beg], GSTDIO_ROWS_NUM-20 
			jna	.Do
			cmp BYTE [gstdio_col_beg], GSTDIO_COLS_NUM-20 
			jna	.Do
			mov al, [gstdio_row_beg]
			add al, [gstdio_row_cnt]
			cmp al, GSTDIO_ROWS_NUM
			jna	.Do
			mov al, [gstdio_col_beg]
			add al, [gstdio_col_cnt]
			cmp al, GSTDIO_COLS_NUM
			jna	.Do
			call gstdio_init_pars
			jmp .Back
.Do			mov BYTE [gstdio_full_row], 0
			mov DWORD [gstdio_rect_offs], 0
			mov DWORD [gstdio_rect_bytes], 0
			mov DWORD [gstdio_row_offs], 0
			cmp BYTE [gstdio_col_beg], 0
			jne	.ByRow
			cmp BYTE [gstdio_col_cnt], GSTDIO_COLS_NUM
			jne	.ByRow
			mov BYTE [gstdio_full_row], 1
			cmp BYTE [gstdio_row_beg], 0
			jz	.CalcBytes
			mov eax, GSTDIO_ROW_BYTES					; 2* is already applied
			xor ebx, ebx
			mov bl, [gstdio_row_beg]
			mul ebx
			mov [gstdio_rect_offs], eax
.CalcBytes	mov eax, GSTDIO_ROW_BYTES					; 2* is already applied
			xor ebx, ebx
			mov bl,	[gstdio_row_cnt]
			mul ebx
			mov [gstdio_rect_bytes], eax
			jmp .Back
.ByRow		cmp BYTE [gstdio_row_beg], 0
			jz	.CalcBytes2
			mov eax, GSTDIO_ROW_BYTES					; 2* is already applied
			xor ebx, ebx
			mov bl, [gstdio_row_beg]
			mul ebx
			mov [gstdio_row_offs], eax
			cmp BYTE [gstdio_col_beg], 0
			jz	.CalcBytes2
			mov eax, (GSTDIO_CHAR_WIDTH * 2)
			xor ebx, ebx
			mov bl, [gstdio_col_beg]				; row_offs = GSTDIO_CHAR_WIDTH*[gstdio_col_beg]*2
			mul ebx
			add [gstdio_row_offs], eax
.CalcBytes2	mov eax, (GSTDIO_CHAR_WIDTH * 2)
			xor ebx, ebx
			mov bl, [gstdio_col_cnt]				; row_bytes = GSTDIO_CHAR_WIDTH*2*[gstdio_col_cnt] ; PIXEL-row !! (not character!)
			mul ebx
			mov [gstdio_pxrow_bytes], eax
		; pxrow_cnt
			xor eax, eax
			mov al, [gstdio_row_cnt]
			mov ebx, GSTDIO_CHAR_HEIGHT
			mul ebx
			mov [gstdio_pxrow_cnt], eax
.Back		ret


gstdio_to_main_scr:
			call gstdio_init_pars
			xor ebx, ebx
			call gstdio_clr_scrbuff
			; text-buff
			call gstdio_draw_chars_from_txtbuff
			ret


gstdio_init_pars:
			mov BYTE [gstdio_skip_recording], 0
			mov BYTE [gstdio_skip_txtbuff], 0
			mov BYTE [gstdio_skip_scroll], 0
			mov BYTE [gstdio_row_beg], 0
			mov BYTE [gstdio_col_beg], 0
			mov BYTE [gstdio_row_cnt], GSTDIO_ROWS_NUM
			mov BYTE [gstdio_col_cnt], GSTDIO_COLS_NUM
			mov BYTE [gstdio_full_row], 1
			mov DWORD [gstdio_rect_bytes], GSTDIO_SCREEN_BYTES
			mov DWORD [gstdio_rect_offs], 0
			mov DWORD [gstdio_pxrow_bytes], 0
			mov DWORD [gstdio_row_offs], 0
			mov DWORD [gstdio_pxrow_cnt], 0
			ret


gstdio_tmp_init_pars:
			mov BYTE [gstdio_row_beg], 0
			mov BYTE [gstdio_col_beg], 0
			mov BYTE [gstdio_row_cnt], GSTDIO_ROWS_NUM
			mov BYTE [gstdio_col_cnt], GSTDIO_COLS_NUM
			mov BYTE [gstdio_full_row], 1
			mov DWORD [gstdio_rect_bytes], GSTDIO_SCREEN_BYTES
			mov DWORD [gstdio_rect_offs], 0
			mov DWORD [gstdio_pxrow_bytes], 0
			mov DWORD [gstdio_row_offs], 0
			mov DWORD [gstdio_pxrow_cnt], 0
			ret


gstdio_tmp_to_main_scr:
			mov al, [gstdio_cur_x]
			mov [gstdio_tsaved_x], al
			mov al, [gstdio_cur_y]
			mov [gstdio_tsaved_y], al
			mov al, [gstdio_row_beg]
			mov [gstdio_row_beg_saved], al
			mov al, [gstdio_col_beg]
			mov [gstdio_col_beg_saved], al
			mov al, [gstdio_row_cnt]
			mov [gstdio_row_cnt_saved], al
			mov al, [gstdio_col_cnt]
			mov [gstdio_col_cnt_saved], al
			mov al, [gstdio_full_row]
			mov [gstdio_full_row_saved], al
			mov eax, [gstdio_rect_bytes]
			mov [gstdio_rect_bytes_saved], eax
			mov eax, [gstdio_rect_offs]
			mov [gstdio_rect_offs_saved], eax
			call gstdio_tmp_init_pars
			ret


gstdio_tmp_from_main_scr:
			mov al, [gstdio_tsaved_x]
			mov [gstdio_cur_x], al
			mov al, [gstdio_tsaved_y]
			mov [gstdio_cur_y], al
			mov al, [gstdio_row_beg_saved]
			mov [gstdio_row_beg], al
			mov al, [gstdio_col_beg_saved]
			mov [gstdio_col_beg], al
			mov al, [gstdio_row_cnt_saved]
			mov [gstdio_row_cnt], al
			mov al, [gstdio_col_cnt_saved]
			mov [gstdio_col_cnt], al
			mov al, [gstdio_full_row_saved]
			mov [gstdio_full_row], al
			mov eax, [gstdio_rect_bytes_saved]
			mov [gstdio_rect_bytes], eax
			mov eax, [gstdio_rect_offs_saved]
			mov [gstdio_rect_offs], eax
			ret

; *** End of Character-related ***

; *** Graphics-related ***

; IN: MemAddr(EAX), MemRectWidth(EBX), MemRectHeight(ECX)
gstdio_to_gmem:
			mov edx, [gstdio_scrbuff]
			mov [gstdio_scrbuff_saved], edx
			mov edx, [_scrw]
			mov [gstdio_scrw_saved], edx
			mov edx, [_scrh]
			mov [gstdio_scrh_saved], edx
			mov [gstdio_scrbuff], eax
			mov [_scrw], ebx
			mov [_scrh], ecx
			shl ebx, 1
			mov DWORD [gstdio_row_byte_cnt], ebx
			mov BYTE [gstdio_cp_to_fbuff_on], 0
			ret

; restore/init
gstdio_from_gmem:
			mov ecx, [gstdio_scrbuff_saved]
			mov [gstdio_scrbuff], ecx
			mov ecx, [gstdio_scrw_saved]
			mov [_scrw], ecx
			mov ecx, [gstdio_scrh_saved]
			mov [_scrh], ecx
			mov DWORD [gstdio_row_byte_cnt], (GSTDIO_XRES*2)
			mov BYTE [gstdio_cp_to_fbuff_on], 1
			ret

; *** End of Graphics-related ***


section .data

%include "gfont.inc"

gstdio_framebuff	dd 0
gstdio_scrbuff		dd	GSTDIO_SCRBUFF	; this is the screenbuff, let it be the mainscreen or the list(editor)

; When we write to the main-screen, chars get saved to txtbuff 
; in order to be able to restore the contents of the main-screen 
; when we exit e.g. from LIST
gstdio_txtbuff		dd	GSTDIO_TXTBUFF

gstdio_outpbuff			dd GSTDIO_OUTPBUFF
gstdio_outpbuff_pos		dd 0

; there is recording: the output of a word gets recorded 
; and can be viewed with OUTP
gstdio_outp_recording	db 0

gstdio_OutpTxt	db "      PGUP PGDN HOME END ", 127, 32, 128, "                  ESC to Quit", 0

gstdio_cur_x	db 0				; current x/y location of cursor
gstdio_cur_y	db 0
gstdio_cur_x_saved	db 0
gstdio_cur_y_saved	db 0

gstdio_opaque	dw	0					; is the character-drawing opaque or transparent 
gstdio_dummy	dw	0					; in the system_table in core.asm, two WORDs form a DWORD, so opaque needs a dummy 16-bit (i.e. WORD)
gstdio_bkgclr	dw	GSTDIO_BKGCLR		; background color
gstdio_fgclr	dw	GSTDIO_FGCLR		; foreground color
gstdio_chbkgclr	dw	GSTDIO_CHBKGCLR		; character background color
gstdio_currclr	dw	GSTDIO_CURRCLR		; the color of the cursor

; opaque How-To: set opaque to 1; save chbkgclr; write bkgclr to chbkgclr; then draw chars
;		to undo: set opaque to 0; write the saved vale back to chbkgclr; then draw chars

GSTDIO_HEXTABLE		db	"0123456789ABCDEF"
GSTDIO_NUMSTORAGE	times 10 db 0
GSTDIO_NUMSTORAGE64	times 25 db 0

gstdio_prompt_txt	db	"fos>", 0
GSTDIO_PROMPT_LEN	equ	$-gstdio_prompt_txt		; !?

; A rudimentary text-view.
; Displays screens of a text given by address and length (see gstdio_txt_view)
; It can be overridden by loading TXTVW from FORTH-source
gstdio_txtvwtxt		db 5, "txtvw"
gstdio_skip_recording_saved	db 0
gstdio_skip_txtbuff_saved	db 0
gstdio_skip_scroll_saved	db 0

; *** Character-related ***
; Writing chars on character positions
; The main-screen has GSTDIO_ROWS_NUM rows and GSTDIO_COLS_NUM columns.
; In gstdio_draw_char, we record the printed chars of the last word for OUTP; we write chars to txtbuff 
;            (e.g. we exit from LIST or TXTVW or TXTED, we restore the chars that were on the screen from txtbuff)
;            there is scrolling
; In LIST (i.e. the editor), we don't need recording, writing to txtbuff and scrolling.
;         We have different screen-size (64, 16). There is a frame, but the text will be displayed on a 64*16 screen.
; If we change the variables below, than we can use EMIT and ." " from the code of LIST (or from the code of other WORDs with different screen-parameters).
; rect is the whole screen or a part of it.
gstdio_skip_recording	db 0
gstdio_skip_txtbuff		db 0
gstdio_skip_scroll		db 0
gstdio_row_beg			db 0
gstdio_col_beg			db 0
gstdio_row_cnt			db GSTDIO_ROWS_NUM		; from col_beg, because that means zero (cur_y=0)
gstdio_col_cnt			db GSTDIO_COLS_NUM		; from row_beg, because that means zero (cur_x=0)
gstdio_full_row			db 1					; if col_beg=0 and col_cnt=GSTDIO_COLS_NUM, then we can use "rep stosd"
gstdio_rect_bytes		dd GSTDIO_SCREEN_BYTES	
gstdio_rect_offs		dd 0				
gstdio_pxrow_bytes		dd 0					; if not full_row, we have to write/copy row by row; this is pixelrow!
gstdio_row_offs			dd 0					; if not full_row, offset of the first row+col 
gstdio_pxrow_cnt		dd 0

; for TMPTOMSCR and TMPRESTORE
gstdio_row_beg_saved	db 0
gstdio_col_beg_saved	db 0
gstdio_row_cnt_saved	db 0
gstdio_col_cnt_saved	db 0
gstdio_full_row_saved	db 0
gstdio_rect_bytes_saved	dd 0
gstdio_rect_offs_saved	dd 0				

gstdio_tsaved_x	db 0				; saving temporarily, for >TMSCR and TMSCR>
gstdio_tsaved_y	db 0

; *** Graphics related ***
; graphical functions in memory (not scrbuff)  (writing chars on pixel positions and drawing shapes)
; skips copying to framebuff in gstdio_draw_char_pix
;>gmem(scrw, scrh, rowbytecnt)  gmem>(calls gstdio_gmem_init)
gstdio_cp_to_fbuff_on	db 1
gstdio_row_byte_cnt		dd (GSTDIO_XRES*2)
gstdio_scrbuff_saved	dd 0
gstdio_scrw_saved		dd 0
gstdio_scrh_saved		dd 0


%endif

