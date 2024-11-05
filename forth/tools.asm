%ifndef __FORTH_TOOLS__
%define __FORTH_TOOLS__


%include "forth/common.asm"
%include "forth/rts.asm"
%include "forth/core.asm"
%include "gutil.asm"
%include "gstdio.asm"


section .text

;*********************************************
; _dot_s			.S
;	( n1 n2 ... -- n1 n2 ...)
;	Copies and displays the values currently 
;	on the stack (without destroying them)
;*********************************************
_dot_s:
			mov eax, [_pstack0]
			sub eax, esi
			shr eax, 2
			mov ecx, eax
			mov ebx, '<'
			call gstdio_draw_char
			call gstdio_draw_dec
			mov ebx, '>'
			call gstdio_draw_char
			call _space
			cmp ecx, 0
			jz	.Back

			mov ebx, [_pstack0]
			sub ebx, CELL_SIZE
.Next		mov eax, [ebx]
			PUSH_PS(eax)
			push ebx
			push ecx
			call _dot
			pop ecx
			pop ebx
			sub ebx, CELL_SIZE
			loop .Next
.Back		ret


;*********************************************
; _question			?
;	( addr -- )
;	Displays the value stored at addr
;*********************************************
_question:
			call _fetch
			call _dot
			ret


;*********************************************
; _dump				DUMP
;	( addr n -- )
;	Displays the contents of n consecutive 
;	addresses, starting at addr. 
;	(now n lines!)
;*********************************************
_dump:
			call _c_r
			push eax
			push ecx
			POP_PS(ecx)
			POP_PS(eax)
			push esi
			mov esi, eax			; POP_PS(esi) would add CELL_SIZE to esi!!
			call gutil_mem_dump
			pop esi
			pop ecx
			pop eax
			ret


;*********************************************
; _forget				FORGET
;	( -- )
;	Resets the state of the dictionary to the 
;	state prior to adding the forget-to-be word.
;	Also removes word(s) from Hash-table
; NOTE: 
;	We add words(in forth_init and mark_word) 
;   to the hash-table from left to right (to first zero).
;	In _find we search for a word from 
;	right to left (first non-zero).
;	This can be a problem if we FORGET a word:
;	If a Slot (of course, contains ptrs to words of the same hash-value) contains:
;	ptrToDog ptrToTest 0 0 0 0 0 0 0 0 0 0 0 0 0 0
;	Let's pretend that words "dog" and "test" have the same hash-value.
;	Here if we forget "dog" we get:
;	0 ptrToTest 0 0 0 0 0 0 0 0 0 0 0 0 0 0
;	Now next time we add a new definition of "test", 
;	it will be inserted to the first zero from the left:
;	ptrToTest(New) ptrToTest 0 0 0 0 0 0 0 0 0 0 0 0 0 0
;	The problem is that FIND will find the old "test", 
;	because it searches from the right.
;	The solution is to move the items in the list 
;	(that belongs to a slot) to the left by one 
;	after we have forgotten a word.
;*********************************************
_forget:
			call _b_l
			mov BYTE [check_max_name_len], 1
			call _word
			mov ebx, [esi]
			cmp BYTE [ebx], 0
			jnz	.Find
			POP_PS(ebx)
			jmp .Back
.Find		call _find
			POP_PS(ebx)				; flags|len
			POP_PS(eax)				; dptoxt
			cmp eax, 0				; word not found?
			jz	.Err
			PUSH_PS(eax)
			and	bl, LENGTH_MASK
			PUSH_PS(ebx)
			call _to_link			; ( dptoxt len -- dptolink )
			POP_PS(ebx)
			cmp ebx, [_last_builtin_word]
			ja	.USER
			mov DWORD [_error], E_COREWORD	; check if core word ==> it cannot be forgotten
			jmp	.Back
.USER		mov [_last_tmp], ebx	; link of forget-to-be word in [_last_tmp]
%ifdef MULTITASKING_DEF
			call kill_tasks
%endif
			mov ebx, [_last]
%ifdef MULTITASKING_DEF
			call set_user_offs		; set user_offs if variables created by USER gets forgotten
%endif
%ifdef HASHTABLE_DEF
.NextWord	add ebx, CELL_SIZE
		; find in Hash-table
			call fhash
			sub ebx, CELL_SIZE
			shl eax, HASHSHIFT
			shl eax, CELL_SIZE_SHIFT	; to bytes
			add eax, HASHTABLE
			; find pointer to given word in the list
			mov ecx, HASHLISTLEN-1
			push ecx
			shl ecx, CELL_SIZE_SHIFT	; to bytes
			add eax, ecx
			pop ecx
.ChkPtr		cmp [eax], ebx
			jz	.Remove
.NextSlot	sub eax, CELL_SIZE
			dec ecx
			cmp ecx, 0
			jge	.ChkPtr
			jmp .Err
.Remove		mov DWORD [eax], 0
			call hash_table_move
			mov ebx, [ebx]	
			cmp ebx, [_last_tmp]
			jnc	.NextWord
%endif
			mov ebx, [_last_tmp]
			mov [_dp], ebx				; set dictionary-ptr to the link of the forget-to-be word
			mov ebx, [ebx]
			mov [_last], ebx
			jmp .Back
.Err		mov DWORD [_error], E_NOWORD
.Back		ret


%ifdef MULTITASKING_DEF
; IN: EBX (_last);  _last_tmp(link of forget-to-be word)
; set user_offs if variables created by USER get forgotten
set_user_offs:
			pushad
.Next		mov eax, ebx
			PUSH_PS(eax)
			call _to_body
			POP_PS(eax)
			cmp eax, _paren_user_paren	; is it a USER-var?
			jne	.ChkEnd
			add eax, CELL_SIZE
			mov eax, [eax]
			mov [user_offs], eax
.ChkEnd		cmp ebx, [_last_tmp]
			je	.Back
			mov ebx, [ebx]
			jmp .Next
.Back		popad
			ret

%endif


;*************************************************
; _outp				OUTP
;	( -- )
;	Displays the output of the last word (max GSTDIO_OUTBUFF_SCRS screens)
;	PGUP, PGDN, HOME, END, Up-cursor, Down-cursor
;*************************************************
_outp:
			call gstdio_output
			ret


;*************************************************
; _txt_view				TXTVW
;	( addr len -- )
;	Displays text from addr, len is in bytes 
;	Press a key to see next screen, or quit if no more screens
;*************************************************
_txt_view:
			POP_PS(ecx)
			POP_PS(ebx)
			call gstdio_txt_view
			ret


;*********************************************
;	_words				WORDS
; 	( -- )   
;	Prints all the words of the dictionary/vocabulary
;*********************************************
_words:	
			call _c_r
			xor ecx, ecx					; col-cnt
			mov ebx, [_last]
.Chk		cmp ebx, 0
			jz	.End
			push ebx
			add ebx, CELL_SIZE
			xor eax, eax
			mov al, [ebx]
			and al, LENGTH_MASK
			inc ebx
			PUSH_PS(ebx)
			PUSH_PS(eax)
			add ecx, eax
			inc ecx							; SPACE
			push eax
			xor eax, eax
			mov al, [gstdio_col_cnt]
			dec eax
			cmp ecx, eax
			pop eax
			jc	.Write
			call _c_r
			mov ecx, eax
.Write		push ecx
	;	( caddr u -- )
			call _type
			call _b_l		; pushes DELIM on pstack
			call _emit		; displays char
			pop ecx
			pop ebx
			mov ebx, [ebx]
			jmp .Chk
.End		ret


;*********************************************
; _words_question			WORDS?
;	( -- ) 
;	Displays the number of words currently 
;	in the dictionary
;*********************************************
_words_question:
			xor ecx, ecx
			mov ebx, [_last]
.Chk		cmp ebx, 0
			jz	.Print
			inc ecx
			mov ebx, [ebx]
			jmp .Chk
.Print		mov eax, ecx
			call _c_r
			call gstdio_draw_dec
			call _c_r
			ret


;print_hashtable:
;			pushad
;			xor ecx, ecx				; from 0 to HASLEN
;			xor edi, edi				; the count of the printed lines
;.NextSlot	mov ebp, ecx
;			shl ebp, HASHSHIFT			; *8
;			shl ebp, CELL_SIZE_SHIFT	; to bytes
;			add ebp, HASHTABLE
;			cmp DWORD [ebp], 0			; check if slot is empty
;			jz	.Next
;			call gstdio_new_line
;			inc edi
;			mov eax, ecx
;			call gstdio_draw_dec
;			mov ebx, ':'
;			call gstdio_draw_char
;			xor eax, eax
;.NextList	mov ebx, ' '
;			call gstdio_draw_char
;			mov edx, [ebp]
;			call gstdio_draw_hex
;			inc eax
;			cmp eax, HASHLISTLEN
;			jz	.Next
;			add ebp, CELL_SIZE
;			cmp DWORD [ebp], 0			; check if slot is empty
;			jnz	.NextList
;.Next		inc ecx
;			push eax
;			xor eax, eax
;			mov al, [gstdio_row_cnt]
;			sub eax, 2
;			cmp edi, eax		; -1 is NEWLINE after printing PRESSAKEY
;			pop eax
;			jc .Chk
;			call gstdio_new_line
;			call gutil_press_a_key
;			xor edi, edi
;.Chk		cmp ecx, HASHLEN
;			jnz	.NextSlot
;			popad
;			ret


;print_hashtable_name:
;			pushad
;			xor ecx, ecx				; from 0 to HASHLEN
;			xor edi, edi				; the count of the printed lines
;.NextSlot	mov ebp, ecx
;			shl ebp, HASHSHIFT			; *8
;			shl ebp, CELL_SIZE_SHIFT	; to bytes
;			add ebp, HASHTABLE
;			cmp DWORD [ebp], 0			; check if slot is empty
;			jz	.Next
;			call gstdio_new_line
;			inc edi
;			mov eax, ecx
;			call gstdio_draw_dec
;			mov ebx, ':'
;			call gstdio_draw_char
;			xor eax, eax
;.NextList	mov ebx, ' '
;			call gstdio_draw_char
;			mov esi, [ebp]
;			add esi, CELL_SIZE
;			push ecx
;			xor ecx, ecx
;			mov cl, [esi]
;			and ecx, LENGTH_MASK
;			inc esi
;			call gstdio_draw_chars
;			pop ecx
;			inc eax
;			cmp eax, HASHLISTLEN
;			jz	.Next
;			add ebp, CELL_SIZE
;			cmp DWORD [ebp], 0			; check if slot is empty
;			jnz	.NextList
;.Next		inc ecx
;			push eax
;			xor eax, eax
;			mov al, [gstdio_row_cnt]
;			sub eax, 2
;			cmp edi, eax		; -1 is NEWLINE after printing PRESSAKEY
;			pop eax
;			jc .Chk
;			call gstdio_new_line
;			call gutil_press_a_key
;			xor edi, edi
;.Chk		cmp ecx, HASHLEN
;			jnz	.NextSlot
;			popad
;			ret


;TOOLS-EXT

;*********************************************
; _ahead			AHEAD
;	( -- orig)
;	Marks the origin of a forward 
;	unconditional branch
;*********************************************
_ahead:
			mov eax, [rtbranch]
			COMPILE_CELL(eax)
			PUSH_PS(ebp)
			COMPILE_CELL(0)
			ret


;*********************************************
; _see				SEE
;	( "<spaces>name"-- ) 
;	Displays a human-readable representation 
;	of the named word's definition, if a colon-def.
;	Otherwise a memdump
;	CURRENTLY ONLY a memdump
;*********************************************
_see:	; can be done only if colon-defs have dptoname or dptolink as xts
			call _b_l
			mov BYTE [check_max_name_len], 1
			call _word
			mov ebx, [esi]
			cmp BYTE [ebx], 0
			jnz	.Find
			POP_PS(ebx)
			jmp .Back
.Find		call _find
			POP_PS(ebx)			; flags|len
			POP_PS(ecx)			; dptoxt
			cmp ecx, 0			; word not found?
			jz	.Err
			PUSH_PS(ecx)
			and bl, LENGTH_MASK
			PUSH_PS(ebx)
			call _to_link		; ( dptoxt len -- dptolink )	
			PUSH_PS(160)
			call _dump
			jmp .Back
.Err		mov DWORD [_error], E_NOWORD
.Back		ret


; ;CODE missing

; ASSEMBLER missing

; BYE missing (closes file)

; CODE missing

; CS-PICK missing

; CS-ROLL missing

; EDITOR missing

; STATE missing

; [ELSE] missing 

; [IF] missing

; [THEN] missing 


%endif

