%ifndef __FORTH_CORE__
%define __FORTH_CORE__


%include "defs.asm"
%include "forth/common.asm"
%ifdef MULTITASKING_DEF
	%include "forth/taskdefs.asm"
%endif
%include "forth/rts.asm"
%include "forth/errors.asm"
%include "gstdiodefs.asm"
%include "gstdio.asm"
%include "kybrd.asm"
%include "pic.asm"
%include "pit.asm"
%include "forth/facility.asm"
%include "forth/graphics.asm"
%ifdef HARDDISK_DEF
	%include "forth/hd.asm"
%endif
%include "forth/pci.asm"
%include "forth/string.asm"
%ifdef MULTITASKING_DEF
	%include "forth/task.asm"
%endif
%include "forth/tools.asm"
%include "gutil.asm"
%include "kernel.asm"	; if we jump to WarmStart in _throw, we need this
%ifdef AUDIO_DEF
	%include "forth/audio.asm"
%endif
%ifdef USB_DEF
	%include "forth/usb.asm"
%endif
%include "forth/double.asm"


section .text


;*********************************************
;	forth_init
;	sets stackptrs, dp, tib, last, base
;	and loads words
;*********************************************
forth_init:
%ifdef MULTITASKING_DEF
			mov DWORD [_taskbuff], TASKBUFF
			mov DWORD [_tasklen], TASKLEN
			mov DWORD [_taskid], MAIN_TASK_ID
%endif
			mov DWORD [_pstackbuff], PSTACKBUFF
			mov DWORD [_rstackbuff], RSTACKBUFF
			mov DWORD [_pstacklen], PSTACKLEN
			mov DWORD [_rstacklen], RSTACKLEN
			mov DWORD [_dp0], DICT
			mov ebx, PSTACKBUFF
			add ebx, PSTACKLEN
			mov [_pstack0], ebx
			mov ebx, RSTACKBUFF
			add ebx, RSTACKLEN
			mov [_rstack0], ebx
			mov DWORD [_tib], TIB
			mov DWORD [_tib_size], DEF_TIB_SIZE
			mov DWORD [_base], 10
			mov DWORD [_source_id], 0
			mov DWORD [_input_buffer], 0
			mov DWORD [_in_input_buffer], 0
			mov DWORD [_to_in], 0
			mov DWORD [_state], 0
			mov DWORD [in_colon], 0
			mov DWORD [_blk], 0
			mov DWORD [_scr], 0
			mov DWORD [_error], E_OK
			mov DWORD [dps_on_pstack], 0
			mov ebp, DWORD [_dp0]
			mov esi, DWORD [_pstack0]
			mov edi, DWORD [_rstack0]
%ifdef MULTITASKING_DEF
;			init Task-structs
			; set taskid, state and priority of TASK_MAX_NUM structs
			mov ecx, 1
			mov edx, [_taskbuff]
.NextTask	mov [edx], ecx
			mov ebx, edx
			add ebx, TASK_STATE_OFFS
			mov DWORD [ebx], TASK_UNUSED
			mov ebx, edx
			add ebx, TASK_COUNTER_OFFS
			mov DWORD [ebx], 0
			mov ebx, edx
			add ebx, TASK_PRIORITY_OFFS
			mov DWORD [ebx], TASK_PRIO_NORMAL
			add edx, [_tasklen]
			inc ecx
			cmp ecx, TASK_MAX_NUM+1			; +1 because ecx starts from 1
			jc	.NextTask
			; set Main-task's parentid to 0, its state to RUNNING, and its name to 4MAIN
			mov edx, [_taskbuff]
			mov ebx, edx
			add ebx, TASK_PARENTID_OFFS
			mov DWORD [ebx], 0
			mov ebx, edx
			add ebx, TASK_STATE_OFFS
			mov DWORD [ebx], TASK_RUNNING
			mov ebx, edx
			add ebx, TASK_NAME_OFFS
			inc ebx
			push esi
			mov esi, MainTaskName
			xor ecx, ecx
.NextChar	mov al, [esi]
			mov [ebx], al
			inc esi
			inc ebx
			inc ecx
			cmp BYTE [esi], 0
			jnz	.NextChar
			mov ebx, edx
			add ebx, TASK_NAME_OFFS
			mov [ebx], cl
			pop esi
			mov DWORD [tasks_cnt], 1
			mov eax, USER_NUM
			inc eax
			shl eax, 2
			mov DWORD [user_offs], eax
			; set Dummy-task's parentid to 0, its state to PAUSED, also save stack-ptr (ESP), set its name to 5Dummy
			push ebp
			push esi
			mov ebp, dummy_task
			mov esi, DummyTaskName
			call create_initial_task
			pop esi
			pop ebp
%endif
;			load words in dictionary
			mov DWORD [words_tmp], word_arr		; index in word_arr
			mov BYTE [is_system_or_user], 0
			mov DWORD [_last_tmp], 0
			call load_words

; 			load SYSTEM variables
			mov DWORD [words_tmp], system_arr	; index in system_arr
			mov BYTE [is_system_or_user], 1
			call load_words
			mov BYTE [is_system_or_user], 0

; 			load SYSTEM constants
			mov DWORD [words_tmp], system_const_arr	; index in system_const_arr
			mov BYTE [is_system_or_user], 1
			call load_words
			mov BYTE [is_system_or_user], 0

%ifdef MULTITASKING_DEF
;			load USER-variables in dictionary (startup ones)
			mov DWORD [words_tmp], user_arr		; index in user_arr
			mov BYTE [is_system_or_user], 1
			call load_words
			mov BYTE [is_system_or_user], 0
%endif

			; save pointer to the last word in the dictionary
			mov eax, [_last_tmp]
			mov [_last], eax
			mov [_last_builtin_word], eax

			mov [saved_dp], ebp					; save dict-ptr

%ifdef HASHTABLE_DEF
			; Clear Hash-Table
			push edi
			xor eax, eax
			mov ecx, HASHSIZE
			mov edi, HASHTABLE
			rep stosd
			pop edi
			mov ebx, [_last]
			; Fill Hash-Table
.NextWord	cmp ebx, 0
			jz	.FillRT
			add	ebx, CELL_SIZE			; EBX points to flags|length-byte
	; IN: EBX(pointer to lengthbyteofchars)
	; OUT: EAX(hash)
			call fhash
			sub ebx, CELL_SIZE
			call hash_table_add
			cmp DWORD [_error], E_HASHTABLE_LISTFULL
			jz	.Back
			mov ebx, [ebx]
			jmp .NextWord
%endif
			; fill dptoxts of RTs
.FillRT		GET_DP_TO_XT(rtliteraltxt)
			mov [rtliteral], eax
			GET_DP_TO_XT(rtbranchtxt)
			mov [rtbranch], eax
			GET_DP_TO_XT(rtzbranchtxt)
			mov [rtzbranch], eax
			GET_DP_TO_XT(rtdotxt)
			mov [rtdo], eax
			GET_DP_TO_XT(rtdoestxt)
			mov [rtdoes], eax
			GET_DP_TO_XT(rtdoes2txt)
			mov [rtdoes2], eax
			GET_DP_TO_XT(rtdotquotetxt)
			mov [rtdotquote], eax
			GET_DP_TO_XT(rtexittxt)
			mov [rtexit], eax
			GET_DP_TO_XT(rtlooptxt)
			mov [rtloop], eax
			GET_DP_TO_XT(rtplooptxt)
			mov [rtploop], eax
			GET_DP_TO_XT(rtpostponetxt)
			mov [rtpostpone], eax
			GET_DP_TO_XT(rtcolontxt)
			mov [rtcolon], eax
			GET_DP_TO_XT(rtcompilectxt)
			mov [rtcompilec], eax
			GET_DP_TO_XT(rtsquotetxt)
			mov [rtsquote], eax
			GET_DP_TO_XT(rtthrowtxt)
			mov [rtthrow], eax
			GET_DP_TO_XT(rtswaptxt)
			mov [rtswap], eax
			GET_DP_TO_XT(rtduptxt)
			mov [rtdup], eax
			GET_DP_TO_XT(rtrottxt)
			mov [rtrot], eax
			GET_DP_TO_XT(rtequalstxt)
			mov [rtequals], eax
			GET_DP_TO_XT(rtdroptxt)
			mov [rtdrop], eax
			GET_DP_TO_XT(rtvariabletxt)
			mov [rtvariable], eax
			GET_DP_TO_XT(rtoutptxt)
			mov [rtoutp], eax
.Back		ret
;			call print_hashtable_name
;			ret


; IN: _last_tmp, words_tmp, is_system_or_user, EBP(dictionary-pointer)
; loads words from words_tmp, also uses is_system_or_user
load_words:
			mov ebx, [words_tmp]
			; link
.Next		mov eax, [_last_tmp]
			mov [ebp], eax
			mov [_last_tmp], ebp
			add ebp, CELL_SIZE
			;length of name and flags
			push esi
			push edi
			mov edi, [ebx]
			add edi, CELL_SIZE
			call gutil_strlen				; length in ecx
		cmp ecx, MAX_WORD_NAME_LEN	
		jna	.StoreLen
	; IN: ESI, ECX
		call gstdio_new_line
		push ebx
		mov ebx, NameTooLongTxt
		call gstdio_draw_text
		pop ebx
		mov esi, [ebx]
		add esi, CELL_SIZE
		call gstdio_draw_chars
		jmp $
			; Flags|Length-byte
.StoreLen	mov BYTE [ebp], cl
			; copy name
			push ecx
			mov esi, [ebx]
			add esi, CELL_SIZE
			mov edi, ebp
			inc edi
			rep movsb
			pop ecx
%ifdef SPACE_AFTER_WORDNAME
			mov BYTE [ebp+1+ecx], DELIM 	; put DELIM at the end
%endif
			cmp BYTE [is_system_or_user], 1
			jz	.Adjust
			; flags
			inc esi
			mov dl, BYTE [esi]
			or	BYTE [ebp], dl
			; adjust DP (align)
.Adjust		push ebx
			WORD_PTR(ebp)
			mov ebp, ebx
			call _align
			pop ebx
			; code-ptr
			push ebx
			mov eax, [ebx]					; word_arr --> word_ (descr) --> _word
			mov ebx, eax
			mov eax, [ebx]
			mov [ebp], eax
			pop ebx
			add ebp, CELL_SIZE
			cmp BYTE [is_system_or_user], 1
			jnz	.SkipIdx
			; Index in SYSTEM or USER table
			mov eax, [ebx]
			add eax, CELL_SIZE
			add eax, ecx
			inc eax							; skip zero
			xor ecx, ecx
			mov cl, BYTE [eax]
			mov [ebp], ecx
			add ebp, CELL_SIZE
.SkipIdx	add ebx, CELL_SIZE				; next item in word_arr
			pop edi
			pop esi
			cmp DWORD [ebx], 0
			jnz .Next
			ret


%ifdef MULTITASKING_DEF
; IN: tasks_cnt, EBP(address of task), ESI(address of name of task)
create_initial_task:
			pushad
			mov eax, [tasks_cnt]
			mov ebx, [_tasklen]
			mul	ebx
			mov edi, [_taskbuff]
			add edi, eax
			mov ebx, edi
			add ebx, TASK_PARENTID_OFFS
			mov DWORD [ebx], 0
			mov ebx, edi
			add ebx, TASK_STATE_OFFS
			mov DWORD [ebx], TASK_PAUSED

			mov eax, [tasks_cnt]
			inc	eax
			mov ebx, [_tasklen]
			mul	ebx
			add	eax, STACKBUFF
			sub eax, CELL_SIZE

			mov ebx, edi
			add ebx, TASK_STACK_OFFS			; save ESP (stack ptr)
			mov DWORD [ebx], eax

			; put address of task to its stack (ret int PAUSE will read it and jump to it)
			mov [eax], ebp

			mov ebx, edi
			add ebx, TASK_NAME_OFFS
			inc ebx
			xor ecx, ecx
.NextChar	mov al, [esi]
			mov [ebx], al
			inc esi
			inc ebx
			inc ecx
			cmp BYTE [esi], 0
			jnz	.NextChar
			mov ebx, edi
			add ebx, TASK_NAME_OFFS
			mov [ebx], cl
			inc DWORD [tasks_cnt]
			popad
			ret

%endif	; MULTITASKING_DEF


;WORDS*************************************************


;*********************************************
; _abort			ABORT
;	( -- )
;	Empties the pstack and does a warmstart 
;
;	(to _quit) via throw
;*********************************************
_abort:
			PUSH_PS(-1)
			call _throw
			ret


;*********************************************
; _abort_quote		ABORT"
;	( flag -- )
;	If flag true then abort
;	Parses string and performs the operation of _abort
;	Prints the name of the last interpreted 
;	word(?) and the string given by the user
;*********************************************
_abort_quote:
			call _if
			call _s_quote
			mov eax, [rtliteral]
			COMPILE_CELL(eax)
			COMPILE_CELL(-2)
			mov eax, [rtthrow]
			COMPILE_CELL(eax)
			call _then
			ret


;*********************************************
; _abs				ABS
;	( n -- u )
;*********************************************
_abs:
			mov eax, [esi]
			cmp eax, 0
			jnge .Neg
			jmp .Back
.Neg		neg eax
			mov [esi], eax		
.Back		ret


;*********************************************
;	_accept			ACCEPT
;	( tib, tib_size -- #chars )
;	Reads from keyboard to the buffer
;*********************************************
_accept:
			POP_PS(eax)						; EAX: tib_size
			xor ecx, ecx					; ECX: #chars
.NextK		push eax
			push ecx
			call _keyw
			pop ecx
			pop eax
			call _discard
			POP_PS(ebx)
			cmp bl, KEY_TAB
			jnz	.ChkBckSp
			mov ebx, 32
.ChkBckSp	cmp bl, KEY_BACKSPACE			; BACKSPACE?
			jnz	.ChkReturn
			cmp ecx, 0
			jz	.NextK
			dec ecx
			mov ebx, ' '
			call gstdio_remove_cursor
			call gstdio_bckspace
			mov ebx, ' '
			call gstdio_put_cursor
			jmp .NextK
.ChkReturn	cmp bl, KEY_RETURN				; RETURN?
			jz	.Back
			cmp bl, 32						; < SPACE ?
			jc	.NextK
			cmp ecx, eax					; Greater or equal than tib_size?
			jnc .NextK
			mov edx, [esi]					; no stack-incr (i.e. no POP_PS)
			add edx, ecx
			mov [edx], bl
			inc ecx
			push ebx
			mov ebx, ' '
			call gstdio_remove_cursor
			pop ebx
			call gstdio_draw_char
			mov ebx, ' '
			call gstdio_put_cursor
			jmp .NextK
.Back		mov ebx, ' '
			call gstdio_remove_cursor
;			call _c_r 						; _c_r here immediately inserts a newline after pressing ENTER (ok also appears in newline)
			call _space
			mov [esi], ecx
			ret


;*********************************************
; _again			AGAIN
;	( -- )
;	begin again
;	appends run-time semantics below the 
;	current definition, resolving the backward
;	reference dest
;*********************************************
_again:								; CORE-EXT
			mov eax, [rtbranch]
			COMPILE_CELL(eax)
			POP_PS(eax)
			sub eax, ebp
			sub eax, CELL_SIZE
			COMPILE_CELL(eax)
			ret


;*********************************************
; _align			ALIGN
;	( -- )
;	aligns parameter(ebp is dp) to CELL_SIZE
;	boundary
;*********************************************
_align:		
			ALIGN_PTR(ebp)
			mov ebp, eax
			ret


;*********************************************
; _aligned			ALIGNED
;	( addr -- aligned-addr )
;*********************************************
_aligned:
			mov ecx, [esi]
			ALIGN_PTR(ecx)
			mov DWORD [esi], eax
			ret


;*********************************************
; _allot			ALLOT
;	( n -- )
;	Reserves n bytes in the dictionary
;*********************************************
_allot:
			POP_PS(eax)
			add ebp, eax
			ret


;*********************************************
; _and				AND
;	( n1 n2 -- n3)
;	n3 is the bit-by-bit logical and of 
;	n1 with n2
;*********************************************
_and:		mov eax, [esi]
			and [esi+CELL_SIZE], eax
			add esi, CELL_SIZE
			ret


;*********************************************
; _b_l				BL
;	(  -- c )
;	c is the char value for a space (delimiter)
;*********************************************
_b_l:
			mov eax, DELIM
			PUSH_PS(eax)
			ret


;*********************************************
; _begin			BEGIN
;	( -- addr )
;	Pushes the current location (dp) to the pstack
;*********************************************
_begin:
			PUSH_PS(ebp)
			ret


;*********************************************
; _block			BLOCK
;	( u -- addr )
;	u is blocknum, addr is the assigned buffer, 
;	but here both are zero. Sets BLK to zero,
;	in order to stop REFILL.
;	Dummy word called from REFILL, until we 
;	load BLOCK from FORTH-source
;*********************************************
_block:
			mov DWORD [_blk], 0
			POP_PS(eax)
			PUSH_PS(0)
			ret


;*********************************************
; _bracket_char		[CHAR]
;	( -- c )
;	At compile time, parses the word following 
;	[CHAR] in the input stream
;	At runtime, put the ascii value of the 
;	first char of this word on the pstack
;*********************************************
_bracket_char:
			call _char
			call _literal
			ret


;*********************************************
; _bracket_tick		[']
;	( -- )
;	Like tick (') but must be used in a 
;	colon definition.
;	['] finds the next word and compiles its 
;	execution token.
;*********************************************
_bracket_tick:
			call _tick
			call _literal
			ret


;*********************************************
; _bswap2			BSWAP2
;	( n1 -- n2 )
;	Reverses the byte order of a 16-bit value.
;	Useful in case of e.g. endian conversion
;*********************************************
_bswap2:
			POP_PS(eax)
			xchg ah, al
			PUSH_PS(eax)
			ret


;*********************************************
; _bswap4			BSWAP4
;	( n1 -- n2 )
;	Reverses the byte order of a 32-bit value.
;	Useful in case of e.g. endian conversion
;*********************************************
_bswap4:
			POP_PS(eax)
			bswap eax
			PUSH_PS(eax)
			ret


;*********************************************
; _c_fetch			C@
;	( caddr -- c )
;	fetch the character stored at caddr
;*********************************************
_c_fetch:
			mov ebx, [esi]
			xor eax, eax
			mov al, BYTE [ebx]
			mov [esi], eax
			ret


;*********************************************
; _c_comma			C,
;	( b -- )
;	Store byte to dictionary and advance dp
;*********************************************
_c_comma:
			POP_PS(eax)
			mov BYTE [ebp], al
			inc ebp
			ret


;*********************************************
; _c__plus_store	C+!
;	( c caddr -- )
;	Adds char c to char at caddr
;*********************************************
_c_plus_store:
			POP_PS(ebx)
			POP_PS(eax)
			add [ebx], al
			ret

;*********************************************
; _c_r				CR
;	( -- )
;	New line
;*********************************************
_c_r:
			call gstdio_new_line
			ret


;*********************************************
; _c_store			C!
;	( c caddr -- )
;	Stores char c at caddr
;*********************************************
_c_store:
			POP_PS(ebx)
			POP_PS(eax)
			mov BYTE [ebx], al
			ret


;*********************************************
; _case			CASE
;	( -- )
;	Begins case-of-endof-endcase
;	Clears variable that holds the number of 
;	dictionary-locations(EBP-s) by endof-s
;*********************************************
_case:	; endcase decreases it till zero, so this is not necessary
			mov DWORD [dps_on_pstack], 0
			ret


;*********************************************
; _cell_plus		CELL+
;	( addr1 -- addr2 )
;	Adds the size of a cell in bytes to addr1
;	giving addr2
;*********************************************
_cell_plus:
			add DWORD [esi], CELL_SIZE
			ret


;*********************************************
; _cells			CELLS
;	( n1 -- n2 )
;	n2 is the size in bytes of n1 cells
;*********************************************
_cells:
			mov eax, [esi]
			shl eax, CELL_SIZE_SHIFT
			mov [esi], eax
			ret


;*********************************************
; _char				CHAR
;	( "<spaces>name" -- c )
;	Parses the word following CHAR in the 
;	input stream. Puts the ASCII value of the 
;	first character of this word on the pstack
;*********************************************
_char:
			mov eax, DELIM
			PUSH_PS(eax)
			call _word
			mov ebx, [esi]
			inc ebx
			xor eax, eax
			mov al, BYTE [ebx]
			mov [esi], eax
			ret


;*********************************************
; _char_plus		CHAR+
;	( caddr1 -- caddr2 )
;	Adds the size of a character to caddr1 
;	giving caddr2
;*********************************************
_char_plus:
			add DWORD [esi], CHAR_SIZE
			ret


;*********************************************
; _chars			CHARS
;	( n1 -- n2 )
;	n2 is the size in bytes of n1 chars
;*********************************************
_chars:
			mov edx, 0
			mov eax, [esi]
			mov ebx, CHAR_SIZE		; it makes no sense to * with 1
			mul ebx
			mov [esi], eax
			ret


;*********************************************
; _chk_sys			CHKSYS
;	( -- )
;	Checks the system (under/overflow of stacks) 
;	and also the dictionary
;	The main task calls this in QUIT, but the other tasks 
;	need to call it if want to check the system.
;*********************************************
_chk_sys:
			cmp esi, [_pstack0]
			ja	.PStackUn
			mov eax, [_pstack0]
			sub eax, [_pstacklen]
			cmp esi, eax
			jc .PStackOv
			cmp edi, [_rstack0]
			ja	.RStackUn
			mov eax, [_rstack0]
			sub eax, [_rstacklen]
			cmp edi, eax
			jc .RStackOv
			cmp ebp, [_dp0]
			jc .DSpaceUn
			cmp ebp, PAD
			jnc .DSpaceOv
			jmp .Back
.PStackUn	mov DWORD [_error], E_PSTK_UNDER
			jmp .Back
.PStackOv	mov DWORD [_error], E_PSTK_OVER
			jmp .Back
.RStackUn	mov DWORD [_error], E_RSTK_UNDER
			jmp .Back
.RStackOv	mov DWORD [_error], E_RSTK_OVER
			jmp .Back
.DSpaceUn	mov DWORD [_error], E_DSPACE_UNDER
			jmp .Back
.DSpaceOv	mov DWORD [_error], E_DSPACE_OVER
			jmp .Back
.Back		ret


;*********************************************
; _colon			:	(colon definition)
;	( -- )
;	Creates a new entry (a definition) in the
;	dictionary under the name of the word 
;	following ':' and sets the state to COMPILE
;*********************************************
_colon:
			mov [tmpdp], ebp					; save current dp in order to be able to restore it in case of an error
%ifdef MULTITASKING_DEF
			mov eax, [user_offs]
			mov [tmpuser_offs], eax				; save current user_offs in order to be able to restore it in case of an error
%endif
			call create_definition
			COMPILE_CELL(_paren_colon_paren)
			mov DWORD [_state], COMPILE
			mov DWORD [in_colon], 1				; _state is not enough because '[' enters interpret-ation state in a colon-def
			; _semi_colon will call mark_word
			ret


create_definition:
			mov ebx, DELIM
			PUSH_PS(ebx)
			mov BYTE [check_max_name_len], 1
			call _word
			POP_PS(ebx)
			call gutil_string_tolower
			mov [_last_tmp], ebp	; addr of this entry to _last_tmp
			mov eax, [_last]
			mov [ebp], eax
			add ebp, CELL_SIZE		; advance with size of link
			WORD_PTR(ebp)
			mov ebp, ebx
			call _align
			ret

;copies _last_tmp to _last
; this way a new word will only be visible after ; (semi_colon)
;adds word to Hash-table
mark_word:
			push ebx
			mov ebx, [_last_tmp]
%ifdef HASHTABLE_DEF
			push eax
			; add to Hash-table
			add	ebx, CELL_SIZE			; EBX points to length-byte
			call fhash
			sub ebx, CELL_SIZE
			call hash_table_add
			pop eax
			cmp DWORD [_error], E_HASHTABLE_LISTFULL
			jz	.Back
%endif
			mov [_last], ebx			; set _last only if no error!
.Back		pop ebx
			ret


;*********************************************
; _comma			,
;	( n -- )
;	Reserves one cell of data space (dp) and 
;	stores n in the cell
;*********************************************
_comma:		POP_PS(eax)
			mov [ebp], eax
			add ebp, CELL_SIZE
			ret


;*********************************************
; _comp_only		COMPONLY
;	( -- )
;	Makes the most recent definition a 
;	componly word.
;*********************************************
_comp_only:
			mov ebx, [_last]
			add ebx, CELL_SIZE
			or	BYTE [ebx], COMP_ONLY
			ret


;*********************************************
; _compile_comma	COMPILE,
;	(dptoxt -- )
;	Append the execution behaviour of the 
;	definition represented by xt to the 
;	execution behaviour of the current definition.
;	The compilation equivalent of Execute
;*********************************************
; called by EXECUTE to compile the xt (of another word) to the dict
_compile_comma:						; CORE-EXT
			POP_PS(ebx)
			COMPILE_CELL(ebx)
			ret


;*********************************************
; _constant			CONSTANT
;	( n "<spaces>name" -- )
;	Defines a constant whose value is n
;*********************************************
_constant:
			call create_definition
			COMPILE_CELL(_paren_constant_paren)
			POP_PS(eax)
			COMPILE_CELL(eax)
			call mark_word
			ret


;*********************************************
; _count			COUNT
;	( addr1 -- addr2 n )
;	Returns the length n and addr2 of the text 
;	portion of a counted string at addr1
;	In other words:
;	addr1 is a (len,chars) counted string.
;	addr2 is addr1+1 and n is the len
;*********************************************
_count:
			POP_PS(ebx)
			xor ecx, ecx
			mov cl, BYTE [ebx]			; len
			cmp BYTE [use_length_mask], 0
			jz	.NoMask
			and ecx, LENGTH_MASK
			mov BYTE [use_length_mask], 0
.NoMask		inc ebx						; to first char
			PUSH_PS(ebx)
			PUSH_PS(ecx)
			ret


;*********************************************
; _create			CREATE
;	( "<spaces>name" -- )
;	Constructs a dictionary entry. 
;	Execution will return the address of its 
;	data space. No data space is allocated unlike
;	in case of a VARIABLE.
;	Used for creating initialized arrays 
;	(or arrays of consts)
;	Should be used with ,(comma) and ALLOT
;*********************************************
_create:
			call create_definition
			COMPILE_CELL(_paren_create_paren)
			call mark_word			
			ret


;*********************************************
; _decimal			DECIMAL
;	( -- )
;	Changes the number-base to 10.
;*********************************************
_decimal:
			mov DWORD [_base], 10
			ret


;*********************************************
; _depth			DEPTH
;	( -- n )
;	depth of param-stack
;*********************************************
_depth:
			mov eax, [_pstack0]
			sub eax, esi
			PUSH_PS(eax)
			ret


;*********************************************
; _discard			DISCARD
;	( -- )
;	Discards last key (character) in keyboard buffer.
;	Needs to be called after _key and its value used.
;*********************************************
_discard:
			call kybrd_discard_last_key
			ret


;*********************************************
; _do				DO
;	( n1 n2 -- )	Run-time
;	Loop. n2 is loop index and n1 is limit.
;*********************************************
_do:
			mov eax, [rtdo]
			COMPILE_CELL(eax)
			PUSH_PS(ebp)
			COMPILE_CELL(0)
			PUSH_PS(ebp)
			ret


;*********************************************
; _does				DOES>
;	( -- )
;	Begins runtime behaviour.
;*********************************************
_does:
			mov eax, [rtdoes]
			COMPILE_CELL(eax)
			call _exit
;			call mark_word
			ret


;DCELL
;*********************************************
; _dot				.
;	( n -- )
;	Removes the top of pstack and displays it 
;	as a signed integer followed by a space
;*********************************************
_dot:
			call _s_to_d
			call _d_dot
			ret


; if DOUBLE_DEF not defined
;*********************************************
; _dot				.
;	( n -- )
;	Removes the top of pstack and displays it 
;	as a signed integer followed by a space
;*********************************************
;_dot:
;			POP_PS(eax)
;			xor ecx, ecx			; will be 1 if number is negative
;			cmp eax, 0
;			jge .Pos
;			mov ecx, 1
;			neg eax
;.Pos		PUSH_PS(0)
;			PUSH_PS(eax)
;			call _less_number_sign
;			call _number_sign_s
;			cmp ecx, 1
;			jnz	.SkipNeg
;			xor ebx, ebx
;			mov bl, '-'
;			PUSH_PS(ebx)
;			call _hold
;.SkipNeg	call _number_sign_greater
;			call _type
;			call _space
;			ret



;*********************************************
; _dot_paren		.(
;	( -- )
;	Like ( , but begin a comment that will be 
;	sent to the display when encountered.
;	Terminated by )
;*********************************************
_dot_paren:							; CORE-EXT
			mov eax, ')'
			PUSH_PS(eax)
			call _word
			mov ebx, [esi]
			xor eax, eax
			mov al, [ebx]
			cmp al, 0
			jnz	.Ok
			POP_PS(ebx)
			jmp .Back
.Ok			call _count
			call _type
.Back		ret


;*********************************************
; _dot_quote		."
;	( -- )
;	Compiles string, which will be typed when 
;	the word that contains it is executed.
;	Ending: "
;*********************************************
_dot_quote:
			mov eax, '"'
			PUSH_PS(eax)
			call _word
			POP_PS(eax)					; throw away caddr
			mov eax, [rtdotquote]		; WORD skips Link (a CELL_SIZE)
			COMPILE_CELL(eax)
			WORD_PTR2(ebp)
			mov ebp, ebx
			ALIGN_PTR(ebp)
			mov ebp, eax
			ret


;*********************************************
; _dot_r			.R
;	( n1 n2 -- )
;	Display signed integer n1 with leading 
;	spaces to fill a field of n2, right-justified
;*********************************************
_dot_r:
			POP_PS(ebx)
			call _s_to_d
			PUSH_PS(ebx)
			call _d_dot_r
			ret


;*********************************************
; _dpw				DPW
;	( n -- )
;	Writes n to DP which is in EBP
;	It should be a system var, but it has no address
;*********************************************
_dpw:
			POP_PS(eax)
			mov ebp, eax
			ret


;*********************************************
; _drop				DROP
;	( n -- )
;	Drops the top of pstack
;*********************************************
_drop:
			add esi, CELL_SIZE
			ret


;*********************************************
; _dup				DUP
;	( n -- n n )
;	Duplicate the top entry on pstack
;*********************************************
_dup:
			mov eax, [esi]
			PUSH_PS(eax)
			ret


;*********************************************
; _else				ELSE
;	( -- )
;
;*********************************************
_else:
			call _ahead
			call _swap
			call _then
			ret


;*********************************************
; _emit				EMIT
;	( c -- )
;	Displays char c.
;*********************************************
_emit:
			POP_PS(ebx)
			call gstdio_draw_char
			ret


;*********************************************
; _end_of			ENDOF
;	( -- dp )
;	CT: Pushes dp (ebp) to pstack, compiles 0 ,
;		fills 0 compiled by _of and increments 
;		a variable for endcase to know how many 
;		dp-s (i.e. endof-s) are on pstacks
;	RT: 
;*********************************************
_end_of:
			call _ahead
			call _swap
			call _then
			inc DWORD [dps_on_pstack]
			ret


;*********************************************
; _end_case			ENDCASE
;	( n -- )
;	CT: Fills the 0-s by endof-s 
;		(dps_on_pstack variable) contains their 
;		number on pstack
;	RT: Drops n
;*********************************************
_end_case:
.Next		cmp DWORD [dps_on_pstack], 0
			jz	.Drop
			call _then
			dec DWORD [dps_on_pstack]
			jmp .Next
.Drop		mov eax, [rtdrop]
			COMPILE_CELL(eax)
			ret


;*********************************************
; _equals			=
;	( n1 n2 -- flag )
;	Returns flag, which is true if n1 is 
;	equal to n2
;*********************************************
_equals:
			POP_PS(eax)
			cmp eax, [esi]
			jz	.Equ	
			mov DWORD [esi], FALSE
			jmp .Back
.Equ		mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _erase			ERASE
;	( addr u -- )
;	Erases a region at addr of length u 
;*********************************************
_erase:
			PUSH_PS(0)
			call _fill
			ret


;*********************************************
; _evaluate			EVALUATE
;	( addr u -- )
;	Executes words from a string given by addr
;*********************************************
_evaluate:
			POP_PS(ecx)
			POP_PS(eax)
			push eax
			push ecx
			call save_input_specification
			pop ecx
			pop eax
			mov DWORD [_source_id], -1
			mov DWORD [_in_input_buffer], ecx
			mov DWORD [_input_buffer], eax
			mov DWORD [_to_in], 0
			mov DWORD [_blk], 0
			call _interpret
			call restore_input_specification
			ret


;*********************************************
; _exec_only		EXECONLY
;	( -- )
;	Makes the most recent definition an 
;	execonly word.
;*********************************************
_exec_only:
			mov ebx, [_last]
			add ebx, CELL_SIZE
			or	BYTE [ebx], EXEC_ONLY
			ret


;*********************************************
; _execute			EXECUTE
;	( dptoxt -- )
;	Removes dptoxt from top of pstack and 
;	executes it.
;	It also sets the _ip (e.g. in case of a 
;	VARIABLE its address field will be known 
;	from its dptoxt)
;*********************************************
_execute:
			push DWORD [_ip]	; save _ip
			POP_PS(ebx)
			; if the depth of rstack > 1 --> nested; ip = *ip	 (EXECUTE in a colon-def)
			cmp edi, [_rstack0]
			jz	.SkipDeref
			mov [tmpip], ebx
			mov DWORD [_ip], tmpip
			jmp .Call
.SkipDeref	mov [_ip], ebx		; set ip (ip=dptoxt)
.Call		call [ebx]
			pop DWORD [_ip]		; restore _ip 
			ret


;*********************************************
; _exit				EXIT
;	( -- )
;	Compiles (exit) to dictionary
;*********************************************
_exit:
			mov eax, [rtexit]
			COMPILE_CELL(eax)
			ret


;*********************************************
; _fact				FACT
;	( n1 -- n2 )
;	Returns factorial of n1
;*********************************************
_fact:
			POP_PS(ecx)	
			mov ebx, 0				; sign
			test ecx, (1 << 31)
			jz	.Skip
			neg ecx
			test ecx, 1
			jz	.Skip
			mov ebx, 1				; sign
.Skip		mov eax, 1
.Next		cmp ecx, 0
			jz .Ready
			mul ecx	
			dec ecx
			jmp .Next
.Ready		cmp ebx, 1
			jnz	.Push
			neg eax
.Push		PUSH_PS(eax)
			ret


;*********************************************
; _false			FALSE
;	( -- false )
;	Returns false-flag
;*********************************************
_false:								; CORE-EXT
			PUSH_PS(0)
			ret


;*********************************************
; _fetch			@
;	( addr -- n )
;	Replaces addr with the contents of the 
;	cell at addr
;*********************************************
_fetch:
			mov ebx, [esi]
			mov eax, [ebx]
			mov [esi], eax			
			ret


;*********************************************
; _fill				FILL
;	( addr u c -- )
;	Fills a region at addr of length u with c
;*********************************************
_fill:
			POP_PS(eax)
			POP_PS(ecx)
			POP_PS(ebx)
			cmp ecx, 0
			jz	.Back
			push edi
			mov edi, ebx
			rep stosb
			pop edi 
.Back		ret


;*********************************************
; _fill_w			FILLW
;	( addr u w -- )
;	Fills a region at addr of length u with word w
;*********************************************
_fill_w:
			POP_PS(eax)
			POP_PS(ecx)
			POP_PS(ebx)
			cmp ecx, 0
			jz	.Back
			push edi
			mov edi, ebx
			rep stosw
			pop edi 
.Back		ret


;*********************************************
; _find				FIND
;	( caddr -- dptoxt, flags|len-byte)
;	Tries to find the word whose name is a 
;	counted string at caddr. If not found 
;	then returns zeros
;	caddr is ptr-to-flags|length-byte (from _word)
;*********************************************
_find:
			POP_PS(ebx)
			call gutil_string_tolower
%ifdef HASHTABLE_DEF
			; find in Hash-table
	; IN: EBX(pointer to flags|length-byte)
	; OUT: EAX(hash)
			call fhash
			shl eax, HASHSHIFT
			shl eax, CELL_SIZE_SHIFT	; to bytes
			add eax, HASHTABLE
			; find last non-zero in the list
			mov ecx, HASHLISTLEN-1
			push ecx
			shl ecx, CELL_SIZE_SHIFT	; to bytes
			add eax, ecx
			pop ecx
.ChkSlot	cmp DWORD [eax], 0
			jnz .ChkName
.NextSlot	sub eax, CELL_SIZE
			dec ecx
			cmp ecx, 0
			jge	.ChkSlot
			PUSH_PS(0)
			PUSH_PS(0)
			jmp .Back
			; check len
.ChkName	mov edx, [eax]
			add edx, CELL_SIZE
			push ecx
			xor ecx, ecx
			mov cl, [edx]
			and cl, LENGTH_MASK
			cmp cl, [ebx]
			pop ecx
			jnz	.NextSlot
			; compare the two strings
			push ecx
			push esi
			push edi
			xor ecx, ecx
			mov cl, [ebx]
			inc ebx
			mov esi, ebx
			dec ebx
			inc edx
			mov edi, edx
			push eax
			call gutil_strcmp
			cmp eax, 0					; found?
			pop eax
			pop edi
			pop esi
			pop ecx
			jnz	.NextSlot
			; found in Hash-table
			sub edx, CELL_SIZE+1
			PUSH_PS(edx)		; linkptr to pstack
			call _to_body		; get dptoxt
			xor ecx, ecx
			mov cl, BYTE [edx+CELL_SIZE]
			PUSH_PS(ecx)		; flags|len to pstack
%else
			; find it in dictionary
			push ebp
			push edi
			mov ebp, [_last]
.NextW		mov eax, ebp
			add eax, CELL_SIZE
			xor ecx, ecx
			mov cl, [eax]
			and ecx, LENGTH_MASK	; ECX: length of word in dict
			cmp cl, [ebx]
			jnz	.IncW
			; compare chars
			mov edi, ebx
.NextCh		inc eax
			inc edi
			mov dl, [eax]
			cmp dl, [edi]
			jnz	.IncW
			dec ecx
			jnz	.NextCh
			; found
			mov edx, ebp
			pop edi
			pop ebp
			PUSH_PS(edx)		; linkptr to pstack
			call _to_body		; get dptoxt
			xor ecx, ecx
			mov cl, BYTE [edx+CELL_SIZE]
			PUSH_PS(ecx)		; flags|len to pstack
			jmp .Back
.IncW		mov ebp, [ebp]
			cmp ebp, 0
			jnz .NextW
			; not found
.NotFnd		pop edi
			pop ebp
			PUSH_PS(0)
			PUSH_PS(0)
%endif
.Back		ret


;*********************************************
; _greater_than		>
;	( n1 n2 -- flag )
;	Returns flag which is true if n1 > n2
;*********************************************
_greater_than:
			POP_PS(eax)
			cmp [esi], eax
			jg	.Gt	
			mov DWORD [esi], FALSE
			jmp .Back
.Gt			mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _greater_or_equal_than		>=
;	( n1 n2 -- flag )
;	Returns flag which is true if n1 >= n2
;*********************************************
_greater_or_equal_than:
			POP_PS(eax)
			cmp [esi], eax
			jge	.Gt
			mov DWORD [esi], FALSE
			jmp .Back
.Gt			mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _here				HERE						This is DP (or CP) USER variable
;	( -- addr )
;	Pushes the address of the next avaiable 
;	memory loaction in the dictionary to pstack
;*********************************************
_here:
			PUSH_PS(ebp)
			ret


;*********************************************
; _hex				HEX
;	( -- )
;	Changes the number-base to 16.
;*********************************************
_hex:
			mov DWORD [_base], 16
			ret


;*********************************************
; _hold				HOLD
;	( c-- )
;	Insert a character from the parameter-stack 
;	to PNO-String
;*********************************************
_hold:
			POP_PS(eax)
			sub DWORD [p_pnos], CHAR_SIZE
			mov ebx, [p_pnos]
			mov BYTE [ebx], al
			inc BYTE [in_pnos]
			ret


;*********************************************
; _i				I
;	( -- n )
;	Pushes a copy of the current value of the 
;	index onto pstack. R@ is the limit
;*********************************************
_i:
			mov eax, [edi+CELL_SIZE]
			PUSH_PS(eax)
			ret


;*********************************************
; _if				IF
;	( x -- )
;	
;*********************************************
_if:
			mov eax, [rtzbranch]
			COMPILE_CELL(eax)
			PUSH_PS(ebp)
			COMPILE_CELL(0)
			ret


;*********************************************
; _immediate		IMMEDIATE
;	( -- )
;	Makes the most recent definition an 
;	immediate word.
;*********************************************
_immediate:
			mov ebx, [_last]
			add ebx, CELL_SIZE
			or	BYTE [ebx], IMMEDIATE
			ret


;;;DCell
;*********************************************
; _interpret		INTERPRET
;	( -- )
;	
;*********************************************
_interpret:
.Next		mov eax, DELIM
			PUSH_PS(eax)
			mov BYTE [check_max_name_len], 1
			call _word
			POP_PS(ebx)					; caddr in EBX
			call gutil_string_tolower
			mov ecx, ebx
			cmp BYTE [ecx], 0			; if user entered only spaces (ENTER is handled in quit/refill/accept/...
			jz	.Chk
			push ebx
	;	( caddr -- dptoxt, flags|len-byte)
			PUSH_PS(ebx)
			call _find
			POP_PS(edx)					; flags|len
			POP_PS(eax)					; dptoxt in EAX
			pop ebx
			cmp eax, 0
			jnz	.Found
			; >NUMBER
			PUSH_PS(0)
			PUSH_PS(0)
			xor edx, edx
			mov dl, BYTE [ebx]			; Len in DL
			inc ebx
			PUSH_PS(ebx)
			PUSH_PS(edx)
			call _read_const
			POP_PS(eax)					; 0|1|2 (error, single-cell, double-cell)
			cmp eax, 0
			jnz	.ChkState
			mov DWORD [_error], E_NOWORD	; if not a number: _error=E_NOWORD  
; !!??
			mov esi, [_pstack0]			; empty data stack
			jmp	.Back
.ChkState	cmp eax, 1					; Single-cell?
			jnz .DCell
			mov edx, [esi]				; GET_DCELL, (EDX is Hi32bits)
			mov eax, [esi+CELL_SIZE]					
			cmp DWORD [_state], INTERPRET
			jnz	.SingleComp
			add esi, CELL_SIZE			; Throw away Hi32bits
			jmp .Again
.SingleComp	add esi, 2*CELL_SIZE		; Throw away DCELL
			mov ebx, [rtliteral]
			COMPILE_CELL(ebx)
			COMPILE_CELL(eax)			; Compile Lo32bits
			jmp .Again
.DCell		cmp DWORD [_state], COMPILE
			jnz	.Again
			mov edx, [esi]				; GET_DCELL, (EDX is Hi32bits)
			mov eax, [esi+CELL_SIZE]					
			add esi, 2*CELL_SIZE
			mov ebx, [rtliteral]
			COMPILE_CELL(ebx)
			COMPILE_CELL(eax)
			mov ebx, [rtliteral]
			COMPILE_CELL(ebx)
			COMPILE_CELL(edx)
.Again		jmp .Chk
.Found		xor ecx, ecx
			mov cl, dl
			and	dl, FLAGS_MASK			; flags in EDX
			and	cl, LENGTH_MASK			; length in ECX
			cmp DWORD [_state], INTERPRET
			jz	.Inter
			; compile
			test dl, EXEC_ONLY
			jz	.Comp
			mov DWORD [_error], E_NOEXEC
			jmp .Back
.Comp		PUSH_PS(eax)				; dptoxt to pstack
			test dl, IMMEDIATE
			jnz	.Exec
			call _compile_comma
			jmp .Chk
.Exec		call _execute
			jmp .Chk
			; execute
.Inter		test dl, COMP_ONLY
			jnz	.COErr
			PUSH_PS(eax)
%ifdef MULTITASKING_DEF
			PUSH_PS(ecx)
			push eax
			call _to_link				; ( dptoxt len -- dptolink )	
			POP_PS(eax)
			mov [act_dp], eax
			pop eax
			PUSH_PS(eax)				; dptoxt to pstack
%endif
			cmp eax, [rtoutp]
			je	.Exec2
			mov	DWORD [gstdio_outpbuff_pos], 0
			mov BYTE [gstdio_outp_recording], 1
.Exec2		call _execute
			mov BYTE [gstdio_outp_recording], 0
			jmp .Chk
.COErr		mov DWORD [_error], E_NOCOMP
			jmp .Back
.Chk		cmp DWORD [_error], E_OK		; while cycle
			jz	.ChkBuff
			jmp .Back
.ChkBuff	mov eax, [_to_in]
			cmp eax, [_in_input_buffer]
			jnge .Next
.Back		ret


;*********************************************
; _invert			INVERT
;	( n1 -- n2 )
;	Inverts all bits of n1 giving n2.
;*********************************************
_invert:
			mov eax, [esi]
			not eax
			mov [esi], eax
			ret


;*********************************************
; _j				J
;	( -- n )
;	Pushes a copy of the next outer-loop index 
;	onto pstack. (J is the 3rd item on rstack)
;*********************************************
_j:
			mov eax, [edi+3*CELL_SIZE]
			PUSH_PS(eax)
			ret


;*********************************************
; _key 				KEY
;	( -- c )
;	Reads a key from the keyboard. 
;	Doesn't wait for a key, useful if e.g. 
;	doing a cube-rotation and we wait for a 
;	Space-key to stop. We use KEY in a loop.
;*********************************************
_key:
			call kybrd_get_last_key
			call kybrd_key_to_ascii	
			cmp bl, 0
			jz	.ToStack
			call kybrd_get_ctrl
			cmp al, 1
			jnz	.Erase
			mov [last_key], bl				; PIT-IRQ will need the last-key (e.g. ctrl-c), but _accept function discards it
			jmp .ToStack
.Erase		mov BYTE [last_key], 0
.ToStack	PUSH_PS(ebx)
			ret


;*********************************************
; _keyw 				KEYW
;	( -- c )
;	Reads a key from the keyboard, waits for it
;*********************************************
_keyw:
.Next		call _key
			POP_PS(ebx)
			cmp bl, 0
			jnz	.Back
%ifdef MULTITASKING_DEF
			call _pause
%else
			push ebx
			mov ebx, 10
			call pit_delay
			pop ebx
%endif
			jmp .Next
.Back		PUSH_PS(ebx)
			ret


;*********************************************
; _leave			LEAVE
;	( -- )
;	Discards loop parameters and continues 
;	execution immediately following the 
;	innermost LOOP or +LOOP containing this LEAVE
;*********************************************
_leave:
			add edi, 2*CELL_SIZE
			mov eax, [rtloop]
			mov ecx, [rtploop]
.Whl		mov ebx, [_ip]
			cmp DWORD [ebx], eax
			jnz	.Ne1
			jmp .End
.Ne1		cmp DWORD [ebx], ecx
			jnz	.Ne2
			jmp .End
.Ne2		add DWORD [_ip], CELL_SIZE
			jmp .Whl
.End		add DWORD [_ip], CELL_SIZE
			ret


;*********************************************
; _left_bracket		[
;	( -- )
;	Enters interpretation state.
;*********************************************
_left_bracket:
			mov DWORD [_state], INTERPRET
			ret


;*********************************************
; _less_number_sign		<#
;	( -- )
;	Initializes PNO
;*********************************************
_less_number_sign:
			mov BYTE [in_pnos], 0
			mov eax, pnos
			xor ebx, ebx
			mov bl, [pnos_size]
			add eax, ebx
			mov [p_pnos], eax
			ret


;*********************************************
; _less_than		<
;	( n1 n2 -- flag )
;	Returns flag which is true if n1 < n2
;*********************************************
_less_than:
			POP_PS(eax)
			cmp [esi], eax
			jnge .Lt	
			mov DWORD [esi], FALSE
			jmp .Back
.Lt			mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _less_or_equal_than		<=
;	( n1 n2 -- flag )
;	Returns flag which is true if n1 <= n2
;*********************************************
_less_or_equal_than:
			POP_PS(eax)
			cmp [esi], eax
			jng .Lt	
			mov DWORD [esi], FALSE
			jmp .Back
.Lt			mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _literal			LITERAL
;	( n -- ) Compile-time
;	( -- n ) Run-time
;	Appends run-time semantics (pushing value
;	to the pstack) to the current definition
;*********************************************
_literal:
			mov eax, [rtliteral]
			COMPILE_CELL(eax)
			POP_PS(eax)
			COMPILE_CELL(eax)	
			ret


;*************************************************
; _loadm				LOADM
;	( addr length -- )
;	Loads the forth-code from memory (addr, length), otherwise 
;	LOADM follows the same logic as LOAD 
;
;	It can be inconvenient to write longer code with 
;	the Editor of GFOS.
;	The idea is to write the code on Linux (or Windows) 
;	and then copy it to a pendrive and load it to RAM in GFOS.
;*************************************************
_loadm:
			; Change chars that are < SPACE (32) and > 127 to DELIM
			; We want to remove newlines-s (0x0A, 0x0D), tab-s
			xor ecx, ecx
			mov edx, [esi]						; length in EDX
.NextCh		mov ebx, [esi+CELL_SIZE]			; addr in EBX
			cmp BYTE [ebx+ecx], 32
			jc	.Replace
			cmp BYTE [ebx], 127
			jnc	.Replace
.Inc		inc ecx
			cmp ecx, edx
			jna	.NextCh
			jmp .Do
.Replace	mov BYTE [ebx+ecx], DELIM
			jmp .Inc
.Do			call save_input_specification
			POP_PS(eax)
			POP_PS(ebx)
			mov [_input_buffer], ebx
			mov [_in_input_buffer], eax
			mov DWORD [_to_in], 0
			call _interpret
			call restore_input_specification
.Back		ret



;*********************************************
; _loop				LOOP
;	( -- )
;	Increments the index value by 1 and 
;	compares it with the limit. If equal then 
;	loop is terminated
;*********************************************
_loop:
			POP_PS(edx)			; dest
			sub edx, ebp		; will be in bytes
			sub edx, CELL_SIZE
			push eax
			push edx
			mov eax, [rtloop]
			COMPILE_CELL(eax)
			pop edx
			pop eax
			COMPILE_CELL(edx)
			POP_PS(ecx)
			mov eax, ebp
			sub eax, ecx
;			sub eax, CELL_SIZE
			mov [ecx], eax
.Back		ret


;*********************************************
; _l_shift			LSHIFT
;	( n1 u -- n2 )
;	Performs a logical shift of u bits on n1 
;	giving n2
;*********************************************
_l_shift:
			POP_PS(ecx)
			shl DWORD [esi], cl			; !!
			ret


;*********************************************
; _max				MAX
;	( n1 n2 -- n3 )
;	n3 is the greater of n1 and n2
;*********************************************
_max:
			POP_PS(eax)
			cmp eax, [esi]
			jg	.Gt
			jmp .Back
.Gt			mov [esi], eax
.Back		ret


;*********************************************
; _min				MIN
;	( n1 n2 -- n3 )
;	n3 is the lesser of n1 and n2
;*********************************************
_min:
			POP_PS(eax)
			cmp eax, [esi]
			jnge .Smaller
			jmp .Back
.Smaller	mov [esi], eax
.Back		ret


;*********************************************
; _minus			-
;	( n1 n2 -- n3 )
;	Subtracts n2 from n1 giving the diff n3
;*********************************************
_minus:
			POP_PS(eax)
			sub [esi], eax
			ret


;*********************************************
; _mod				MOD
;	( n1 n2 -- n3 )
;	Divides n1 by n2, giving reminder n3
;*********************************************
_mod:
			xor edx, edx
			POP_PS(ebx)
			mov eax, [esi]
			cdq					; converts signed 32-bit in EAX to 64-bit in EDX:EAX
			idiv ebx
			mov [esi], edx
			ret


;*********************************************
; _move				MOVE
;	( addr1 addr2 u -- )
;	Copies the contents of u consecutive 
;	address units at addr1 to that of addr2
;*********************************************
_move:
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			push esi
			push edi
			mov esi, eax		; POP_PS(esi) would add CELL_SIZE to esi
			mov edi, ebx
			rep movsd			; ecx==0 is not checked
			pop edi
			pop esi
			ret

;*********************************************
; _move_w				MOVEW
;	( addr1 addr2 u -- )
;	Copies the contents of u consecutive 
;	words at addr1 to that of addr2
;*********************************************
_move_w:
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			push esi
			push edi
			mov esi, eax		; POP_PS(esi) would add CELL_SIZE to esi
			mov edi, ebx
			rep movsw			; ecx==0 is not checked
			pop edi
			pop esi
			ret


;*********************************************
; _negate			NEGATE
;	( n1 -- n2 )
;	Negates n1, giving n2
;*********************************************
_negate:
			mov eax, [esi]
			neg eax
			mov [esi], eax
			ret


;*********************************************
; _nip				NIP
;	( n1 n2 -- n2)
;	Drops the first item below the top of the stack
;*********************************************
_nip:								; CORE-EXT
			mov eax, [esi]
			mov [esi+CELL_SIZE], eax
			add esi, CELL_SIZE
			ret


;*********************************************
; _not_equals		<>
;	( x1 x2 -- flag )
;	Flag is true if x1 is not the same as x2
;*********************************************
_not_equals:						; CORE-EXT
			POP_PS(eax)
			cmp eax, [esi]
			jnz	.NotEqu	
			mov DWORD [esi], FALSE
			jmp .Back
.NotEqu		mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _number_sign			#
;	( ud1 -- ud2 )
;	Divide ud1 by the number in BASE giving the 
;	quotient ud2 and the remainder n. 
;	(n is the least-significant digit of ud1.) 
;	Convert n to external form and add the resulting 
;	character to the beginning of the pictured numeric output string. 
;	An ambiguous condition exists if # 
;	executes outside of a <# #> delimited number conversion. 
;*********************************************
_number_sign:
			mov edx, [esi]
			mov eax, [esi+CELL_SIZE]
			mov ebx, [_base]
	; IN: EDX:EAX dividend, 64bit number, EBX 32bit number divisor
	; OUT: EDX:EAX 64bit result, ECX remainder
			call udiv64by32
			mov [esi], edx
			mov [esi+CELL_SIZE], eax
			cmp ecx, 10			; remainder
			jnge .LessTen
			sub cl, 10
			add cl, 'a'
			jmp .Store
.LessTen	add cl, '0'
.Store		sub DWORD [p_pnos], CHAR_SIZE
			mov ebx, [p_pnos]
			mov BYTE [ebx], cl
			inc BYTE [in_pnos]
			ret


;*********************************************
; _number_sign_greater		#>
;	( xd -- caddr u )
;	Ends PNO. Given a number on the parameter 
;	stack, address and size of the pno-string 
;	is the result.
;*********************************************
_number_sign_greater:
			mov ebx, [p_pnos]
			mov [esi+CELL_SIZE], ebx		; Drop number
			xor eax, eax
			mov al, BYTE [in_pnos]
			mov [esi], eax					; Drop number
			ret


;*********************************************
; _number_sign_s			#S
;	( ud1 -- ud2 )
;*********************************************
_number_sign_s:
.Next		call _number_sign
			cmp DWORD [esi], 0
			jnz	.Next
			cmp DWORD [esi+CELL_SIZE], 0
			jnz	.Next
			ret


;*********************************************
; _of				OF
;	( n n1 -- n flag )
;	CT: Compiles swap, dup rot and = .
;		and what _if does.
;	RT: Duplicates n and compares n and n1.
;		If not equal then jumps after ENDOF.
;		Otherwise continues after OF.
;*********************************************
_of:
			mov eax, [rtswap]
			COMPILE_CELL(eax)
			mov eax, [rtdup]
			COMPILE_CELL(eax)
			mov eax, [rtrot]
			COMPILE_CELL(eax)
			mov eax, [rtequals]
			COMPILE_CELL(eax)
			call _if
			ret


;*********************************************
; _one_plus			1+
;	( n1 -- n2 )
;	Adds 1 to n1, giving the sum n2
;*********************************************
_one_plus:
			inc DWORD [esi]
			ret


;*********************************************
; _one_minus		1-
;	( n1 -- n2 )
;	Subtracts 1 from n1, giving the diff n2
;*********************************************
_one_minus:
			dec DWORD [esi]
			ret


;*********************************************
; _or				OR
;	( n1 n2 -- n3 )
;	n3 is the bit-by-bit inclusive-or of 
;	n1 with n2
;*********************************************
_or:
			POP_PS(eax)
			or	[esi], eax
			ret


;*********************************************
; _over				OVER
;	( n1 n2 -- n1 n2 n1 )
;	Places a copy of n1 on the top of pstack
;*********************************************
_over:
			PUSH_PS(0)
			mov eax, [esi+2*CELL_SIZE]
			mov [esi], eax
			ret


;*********************************************
; _paren			(
;	( -- )
;	Begins a comment and ')' ends it
;*********************************************
_paren: 
.Prs		mov edx, [_to_in]
			cmp edx, [_in_input_buffer]
			jnge .Chk
			jmp .Skip
.Chk		mov ebx, [_input_buffer]
			add ebx, [_to_in]
			cmp BYTE [ebx], ')'
			jz .Skip
			inc DWORD [_to_in]
			jmp .Prs
.Skip		cmp edx, [_in_input_buffer]
			jnge .Incr
			jmp .Back
.Incr		inc DWORD [_to_in]
.Back		ret
		

;*********************************************
; _paren_branch_paren		(branch)
;	( -- )
;	The run-time procedure to unconditionally 
;	branch. A in-line offset is added to ip to 
;	branch ahead or back. 
;	(BRANCH) is compiled by ELSE, AGAIN and REPEAT plus AHEAD
;	ip += 1 + (Cell) *ip;
;*********************************************
_paren_branch_paren:
			add DWORD [_ip], CELL_SIZE		; skip RT
			mov ebx, [_ip]
			mov eax, [ebx]
			add [_ip], eax
			ret


;*********************************************
; _paren_colon_paren	(COLON)
;	( -- )
;	Runtime code of colon.
;	Saves ip to rstack and executes xts till 
;	ip is zero. Restores ip
;*********************************************
_paren_colon_paren:
			mov eax, [_ip]
;			add eax, CELL_SIZE		; after ';' ip is increased by CELL_SIZE in the nested (colon)
			PUSH_RS(eax)
			; if the depth of rstack > 1 --> nested; ip = *ip
			mov eax, [_rstack0]
			sub eax, 2*CELL_SIZE
			cmp edi, eax
			ja	.SkipDeref
			mov ebx, [_ip]					; ip = *ip
			mov eax, [ebx]
			mov [_ip], eax
.SkipDeref	add	DWORD [_ip], CELL_SIZE		; skip RT-code
.Next		mov ebx, [_ip]
			mov ecx, [ebx]
			call [ecx]
			cmp DWORD [_ip], 0
			jz	.End
			add DWORD [_ip], CELL_SIZE
			jmp .Next
.End		POP_RS(eax)
			mov [_ip], eax
			ret


;*********************************************
; _paren_compile_comma_paren	(COMPILE,)
;
;*********************************************
_paren_compile_comma_paren:
			call _compile_comma
			ret


;*********************************************
; _paren_constant_paren	(CONSTANT)
;	( -- n )
;	Runtime procedure compiled by CONSTANT, which 
;	pushes its value on pstack
;*********************************************
_paren_constant_paren:
			; if the depth of rstack is not zero --> called from a colon-def: ip = *ip
			cmp edi, [_rstack0]
			jz	.SkipDeref
			; dereference ip
			push DWORD [_ip]
			mov ebx, [_ip]					; ip = *ip
			mov eax, [ebx]
			mov [_ip], eax
.SkipDeref	mov ebx, [_ip]
			add ebx, CELL_SIZE
			mov eax, [ebx]
			PUSH_PS(eax)
			; restore ip if it was dereferenced
			cmp edi, [_rstack0]
			jz	.SkipUnref
			pop DWORD [_ip]
.SkipUnref	ret


;*********************************************
; _paren_create_paren	(CREATE)
;	( -- addr )
;	Runtime procedure compiled by CREATE, which 
;	pushes the address of its value on pstack
;	Same as (VARIABLE)
;*********************************************
_paren_create_paren:
			; if the depth of rstack is not zero --> called from a colon-def: ip = *ip
			cmp edi, [_rstack0]
			jz	.SkipDeref
			; dereference ip
			push DWORD [_ip]
			mov ebx, [_ip]					; ip = *ip
			mov eax, [ebx]
			mov [_ip], eax
.SkipDeref	mov ebx, [_ip]
			add ebx, CELL_SIZE
			PUSH_PS(ebx)
			; restore ip if it was dereferenced
			cmp edi, [_rstack0]
			jz	.SkipUnref
			pop DWORD [_ip]
.SkipUnref	ret


;*********************************************
; _paren_do_paren	(DO)	
;	( n1 n2 -- )
;	Runtime code of DO which moves the loop 
;	control parameters to the return stack
;	Pushes limit(n1) and index(n2) on rstack
;	Checks index and limit and if they are 
;	equal then skips code after do. ( ?DO )
;*********************************************
_paren_do_paren:
			mov ebx, [esi+CELL_SIZE]
			cmp [esi], ebx
			jz	.Equ
			POP_PS(eax)
			PUSH_RS(eax)
			POP_PS(eax)
			PUSH_RS(eax)
			add DWORD [_ip], CELL_SIZE			; skip branch
			jmp .Back
.Equ		mov ebx, [_ip]
			add ebx, CELL_SIZE
			mov eax, [ebx]
			add [_ip], eax
.Back		ret


;*********************************************
; _paren_does_paren	(DOES)	
;	( -- addr )
;	Runtime code of DOES>
;	Changes the runtime code of the Word to (COLON)
;	Moves the parameters down by 2 cells (increments EBP too)
;	and inserts (DOES2) and the address of the cell after (DOES) 
; 	For example: 
;	: CONSTANT  CREATE , DOES> @ ;
;	220 CONSTANT LIMIT 	( the compile time behaviour; adds to dictionary, uses last_arr)
;	LIMIT .	( run-time behaviour)
;*********************************************
_paren_does_paren:
			mov ebx, [_last]
			PUSH_PS(ebx)
			call _to_body
			POP_PS(ebx)				; dptoxt

			mov ecx, ebp			; move the parameters down
			sub ecx, ebx
			sub ecx, CELL_SIZE
			shr ecx, 2				; in order to use movsd
			push esi
			push edi
			mov esi, ebp
			sub esi, CELL_SIZE
			add ebp, CELL_SIZE		; inc EBP
			mov edi, ebp
			std
			rep movsd
			cld
			pop edi
			pop esi

			add ebp, CELL_SIZE		; inc EBP

			mov ecx, [rtcolon]		; overwrite RT with (COLON)
			mov eax, [ecx]			; INDIRECTION!?
			mov [ebx], eax

			add ebx, CELL_SIZE		; insert (DOES2)
			mov eax, [rtdoes2]
			mov [ebx], eax

			mov eax, [_ip]			; copy the address to jump to after the RT
			add eax, CELL_SIZE
			add ebx, CELL_SIZE
			mov [ebx], eax

			ret


;*********************************************
; _paren_does2_paren	(DOES2)	
;	( -- addr )
;	Used by the runtime code of DOES>
;	it pushes the address of the word's 
;	parameter on pstack and sets ip to the code 
;	after the runtime code of DOES, i.e. (DOES) 
;*********************************************
_paren_does2_paren:
			mov ebx, [_ip]
			add ebx, 2*CELL_SIZE
			PUSH_PS(ebx)
			sub ebx, CELL_SIZE
			mov ecx, [ebx]
			mov [_ip], ecx
			ret


;*********************************************
; _paren_dot_quote_paren	(.")
;	( -- )
;	Runtime code of ."
;*********************************************
_paren_dot_quote_paren:
			add DWORD [_ip], CELL_SIZE	; skip RT-code
			mov ebx, [_ip]
			PUSH_PS(ebx)			; addr of word to stack
			call _count
			call _type
			mov ebx, [_ip]
			WORD_PTR2(ebx)
			ALIGN_PTR(ebx)			
			sub eax, CELL_SIZE		; (colon) will add CELL_SIZE
			mov [_ip], eax
			ret


;*********************************************
; _paren_exit_paren		(EXIT) runtime of EXIT
;	( -- )
;	Returns control to the calling definition 
;	specified by nest-sys ( RSTACK: nest-sys)
;*********************************************
_paren_exit_paren:
			mov DWORD [_ip], 0
			ret


;*********************************************
; _paren_literal_paren		(LITERAL) runtime of LITERAL
;	( -- n )
;	Pushes n to pstack
;*********************************************
_paren_literal_paren:
			add DWORD [_ip], CELL_SIZE
			mov ebx, [_ip]
			mov eax, [ebx]
			PUSH_PS(eax)
;			add DWORD [_ip], CELL_SIZE			; (colon) will add CELL_SIZE
			ret


;*********************************************
; _paren_loop_paren		(LOOP)
;	( -- )
;	Runtime procedure compiled by LOOP which 
;	increments the loop index and tests for 
;	loop completion
;*********************************************
_paren_loop_paren:
			mov ebx, [edi]						; limit
			inc DWORD [edi+CELL_SIZE]
			mov ecx, [edi+CELL_SIZE]			; index
			cmp ebx, ecx
			jz	.Equ
			mov ebx, [_ip]
			add ebx, CELL_SIZE
			mov eax, [ebx]
			add [_ip], eax						; (colon) increments ip, so we set it to dpto(do)
			jmp .Back
.Equ		add DWORD [_ip], CELL_SIZE
			add	edi, 2*CELL_SIZE
.Back		ret


;*********************************************
; _paren_plus_loop_paren	(+LOOP)
;	( -- )
;	Runtime procedure compiled by +LOOP, which 
;	increments the loop index by n and tests for 
;	loop completion
;*********************************************
_paren_plus_loop_paren:
			POP_PS(eax)
			add [edi+CELL_SIZE], eax
			mov ebx, [edi]				; EBX: Limit
			mov ecx, [edi+CELL_SIZE]	; ECX: Index
			; in order to support: "X Y do I . Z +loop", where X, Y and Z can be pos or neg
			cmp ebx, 0
			jge .ChkPosIdx
			jmp .ChkNegIdx
.ChkPosIdx	cmp ecx, 0
			jge .ChkPos
			; here Limit is positive but Index is negative (Mixed)
			cmp ecx, ebx
			jc .Gte
			jmp .Next
.ChkPos		cmp ecx, ebx				; Both are positive. Compare them
			jge .Gte
			jmp .Next
.ChkNegIdx	cmp ecx, 0
			jnge .ChkNeg
			; here Limit is negative but Index is positive (Mixed)
			cmp ecx, ebx
			jnc .Gte
			jmp .Next
.ChkNeg		cmp ecx, ebx				; Both are negative. Compare them
			jna .Gte
			jmp .Next
.Next		mov ebx, [_ip]
			add ebx, CELL_SIZE
			mov eax, [ebx]
			add [_ip], eax
			jmp .Back
.Gte		add DWORD [_ip], CELL_SIZE
			add edi, 2*CELL_SIZE
.Back		ret


;*********************************************
;	_paren_postpone_paren
;	( -- )
;	Runtime code of POSTPONE.
;	If execution-depth is 1: executes "compile," ,
;	otherwise skips it (adds CELL_SIZE to _ip)
;*********************************************
_paren_postpone_paren:
			add	DWORD [_ip], CELL_SIZE
			mov eax, [_ip]
			mov eax, [eax]
			COMPILE_CELL(eax)
.Back		ret


;*********************************************
;	_paren_s_quote_paren		(S")
;	( -- addr u )
;	Runtime code of S".
;	Pushes the address and length of the string
;	compiled in dp after itself
;*********************************************
_paren_s_quote_paren:
			add DWORD [_ip], CELL_SIZE
			mov ebx, [_ip]
			PUSH_PS(ebx)
			call _count
			mov ebx, [_ip]
			WORD_PTR2(ebx)
			ALIGN_PTR(ebx)
			mov [_ip], eax
			sub DWORD [_ip], CELL_SIZE		; (colon) will increase the _ip after each call
			ret


;*********************************************
; _paren_system_paren	(SYSTEM)
;	( -- addr )
;	Runtime procedure compiled by system vars, 
;	which pushes the address of the 
;	system-variable on the parameter-stack
;	Its value is the index of the variable in 
;	the system-table and it's added to the 
;	addr of the system-table, this way we can 
;	use ! and @ the normal way
;*********************************************
_paren_system_paren:
			; if the depth of rstack is not zero --> called from a colon-def: ip = *ip
			cmp edi, [_rstack0]
			jz	.SkipDeref
			; dereference ip
			push DWORD [_ip]
			mov ebx, [_ip]					; ip = *ip
			mov eax, [ebx]
			mov [_ip], eax
.SkipDeref	mov ebx, [_ip]
			add ebx, CELL_SIZE
			mov eax, [ebx]
			shl eax, CELL_SIZE_SHIFT
			add eax, system_table
			mov ebx, [eax]
			PUSH_PS(ebx)
			; restore ip if it was dereferenced
			cmp edi, [_rstack0]
			jz	.SkipUnref
			pop DWORD [_ip]
.SkipUnref	ret


;*********************************************
; _paren_system_const_paren	(SYSTEMCONST)
;	( -- n )
;	Runtime procedure compiled by system constants, 
;	which pushes the value of the 
;	system-constant on the parameter-stack
;	Its value is the index of the constant in 
;	the system-constant-table and it's added to the 
;	addr of the system-table
;*********************************************
_paren_system_const_paren:
			; if the depth of rstack is not zero --> called from a colon-def: ip = *ip
			cmp edi, [_rstack0]
			jz	.SkipDeref
			; dereference ip
			push DWORD [_ip]
			mov ebx, [_ip]					; ip = *ip
			mov eax, [ebx]
			mov [_ip], eax
.SkipDeref	mov ebx, [_ip]
			add ebx, CELL_SIZE
			mov eax, [ebx]
			shl eax, CELL_SIZE_SHIFT
			add eax, system_const_table
			mov ebx, [eax]
			mov eax, [ebx]
			PUSH_PS(eax)
			; restore ip if it was dereferenced
			cmp edi, [_rstack0]
			jz	.SkipUnref
			pop DWORD [_ip]
.SkipUnref	ret


;*********************************************
; _paren_variable_paren	(VARIABLE)
;	( -- addr )
;	Runtime procedure compiled by VARIABLE, which 
;	pushes the address of its value on pstack
;*********************************************
_paren_variable_paren:
			; if the depth of rstack is not zero --> called from a colon-def: ip = *ip
			cmp edi, [_rstack0]
			jz	.SkipDeref
			; dereference ip
			push DWORD [_ip]
			mov ebx, [_ip]					; ip = *ip
			mov eax, [ebx]
			mov [_ip], eax
.SkipDeref	mov ebx, [_ip]
			add ebx, CELL_SIZE
			PUSH_PS(ebx)
			; restore ip if it was dereferenced
			cmp edi, [_rstack0]
			jz	.SkipUnref
			pop DWORD [_ip]
.SkipUnref	ret


;*********************************************
; _paren_zero_branch_paren		(0branch)
;	( flag -- )
;	Runtime procedure to conditionally branch.
;	If flag is false, the following in-line 
;	parameter is added to the ip to branch 
;	ahead or back.
;	Compiled by IF, UNTIL and WHILE
;*********************************************
_paren_zero_branch_paren:
			add DWORD [_ip], CELL_SIZE		; skip RT
			POP_PS(eax)
			cmp eax, 0
			jz	.Zero
			jmp .Back						; (colon) will increase [_ip]
.Zero		mov ebx, [_ip]
			mov eax, [ebx]
			add [_ip], eax					; (colon) will increase [_ip]
.Back		ret


;***************************************************
; _parse				PARSE
;	( c -- addr num )
;	c: delim; 
;	addr: beginning of word-pos in _input_buffer, 
;	num: # of parsed chars
;***************************************************
_parse:								; CORE-EXT
			mov ecx, 0
			mov eax, [esi]
			mov ebx, [_input_buffer]
			add ebx, [_to_in]
			push ebx				; orig pushed
.Prs		mov edx, [_to_in]
			cmp edx, [_in_input_buffer]
			jnge .Chk
			jmp .Skip
.Chk		mov ebx, [_input_buffer]
			add ebx, [_to_in]
			cmp BYTE [ebx], al
			jz .Skip
			inc DWORD [_to_in]
			inc ecx
			jmp .Prs
.Skip		pop ebx					; orig popped
			mov [esi], ebx
			PUSH_PS(ecx)
			mov edx, [_to_in]
			cmp edx, [_in_input_buffer]
			jnge .Incr
			jmp .Back
.Incr		inc DWORD [_to_in]
.Back		ret


;*********************************************
; _pick				PICK
;	( n -- n-nth)
;	Places a copy of the nth pstack entry on 
;	top of pstack  (0 PICK is DUP)
;*********************************************
_pick:								; CORE-EXT
			mov eax, [esi]
			shl eax, CELL_SIZE_SHIFT
			add eax, CELL_SIZE
			mov ebx, eax
			mov eax, [esi+ebx]
			mov [esi], eax
			ret


;*********************************************
; _plus				+
;	( n1 n2 -- n3 )
;	Adds n1 to n2, leaving the sum n3
;*********************************************
_plus:
			POP_PS(eax)
			add [esi], eax
			ret


;*********************************************
; _plus_loop		+LOOP
;	( n -- )
;	Like LOOP but increment the index by the 
;	specified value n
;*********************************************
_plus_loop:
			POP_PS(edx)			; dest
			sub edx, ebp		; will be in bytes
			sub edx, CELL_SIZE
			push eax
			push edx
			mov eax, [rtploop]
			COMPILE_CELL(eax)
			pop edx
			pop eax
			COMPILE_CELL(edx)
			POP_PS(ecx)
			mov eax, ebp
			sub eax, ecx
;			sub eax, CELL_SIZE
			mov [ecx], eax
.Back		ret


;*********************************************
; _plus_store		+!
;	( n addr -- )
;	Adds n to the contents of the cell at addr 
;	and stores the result at addr
;*********************************************
_plus_store:
			POP_PS(ebx)
			POP_PS(eax)
			add [ebx], eax
			ret
	

;*********************************************
; _postpone			POSTPONE
;	( -- )
;	At compile time, adds the compilation 
;	behavior of name, rather than its 
;	execution behavior, to the current definition
;*********************************************
_postpone:	; ?!
			mov eax, DELIM
			PUSH_PS(eax)
			mov BYTE [check_max_name_len], 1
			call _word
			call _find
			POP_PS(eax)				; flags|len-byte to EAX
			POP_PS(ebx)				; dptoxt to EBX
			cmp ebx, 0
			jz	.NotFnd
			jmp .Test
.NotFnd		mov DWORD [_error], E_NOWORD
			jmp .Back
.Test		test al, IMMEDIATE
			jnz	.Immed
			mov eax, [rtpostpone]
			COMPILE_CELL(eax)
			COMPILE_CELL(ebx)
			jmp .Back
.Immed		PUSH_PS(ebx)			; This works. If the word to be postponed is IMMEDIATE: ok
			call _compile_comma
.Back		ret


;*********************************************
; _pow						POW
;	( n1 n2 -- n )
;	n1 to the power of n2
;*********************************************
_pow:
			POP_PS(ecx)			; power
			POP_PS(ebx)			; base
			mov eax, 1
.Next		cmp ecx, 0
			jz .Ready
			imul ebx
			dec ecx
			jmp .Next
.Ready		PUSH_PS(eax)
			ret


;*********************************************
; _question_dup		?DUP
;	( n -- n n)	or ( 0 -- )
;	Duplicates the top pstack entry if its 
;	value is non-zero
;*********************************************
_question_dup:
			cmp DWORD [esi], 0
			jnz	.Pos
			jmp .Back
.Pos		mov eax, [esi]
			PUSH_PS(eax)
.Back		ret


;*********************************************
;	_quit			QUIT
;	( -- )
;	Terminates execution of the current word 
;	and all words that called it.
;	Clears return and parameter stacks.
;	No indication is given to the terminal 
;	that a QUIT has occurred. 
;	Enter interpretation state ...
;*********************************************
_quit:
.Again		mov edi, [_rstack0]
			mov DWORD [_source_id], 0
			mov DWORD [_state], INTERPRET
			mov DWORD [_error], E_OK
			mov ebx, [_tib]
			mov [_input_buffer], ebx
			mov DWORD [_ip], 0				; !?
			mov DWORD [in_colon], 0
			mov ebx, ' '
			call gstdio_remove_cursor   ; !!??
			call gstdio_prompt
			call gstdio_put_cursor
.Refill		call _refill					; flag on pstack
			POP_PS(eax)
			cmp eax, 0
			jz	.NoInp
			mov ebx, ' '
			call gstdio_remove_cursor
			mov DWORD [_to_in], 0
			call _interpret
			cmp DWORD [_error], E_OK
			jnz	.ViewErr
			call _chk_sys
			cmp DWORD [_error], E_OK
			jnz .ViewErr
			cmp DWORD [_state], INTERPRET
			jz	.PrOk
			cmp DWORD [_state], COMPILE
			jz	.PrKo
			jmp .Chk						; this shouldn't happen
.PrOk		cmp DWORD [in_colon], 1			; '[' (left_bracket) enters INTERPRETATION state (till ']') in a colon-def
			jnz	.OkMsg
			jmp .PrKo
.OkMsg		call _space
			mov	ebx, MSG_OK
			call gstdio_draw_text
			call _space
			call _c_r
			call gstdio_prompt
			mov ebx, ' '
			call gstdio_put_cursor 
			jmp .Chk
.PrKo		call _space
			mov ebp, [tmpdp] 				; semi-colon didn't mark the word but dp was advanced! Reload dp (or coldstart!?)
%ifdef MULTITASKING_DEF
			mov ebx, [tmpuser_offs]			; same goes for user_offs
			mov [user_offs], ebx
%endif
			mov	ebx, MSG_KO					; but '[' (left_bracket) enters INTERPRETATION state! (till ']')
			call gstdio_draw_text
			call _space
			call _c_r
			mov ebx, ' '
			call gstdio_put_cursor 
			jmp .Again						; !?
;			jmp .Chk
.NoInp		mov DWORD [_error], E_NOINPUT
			jmp	.ViewErr
.Chk		cmp DWORD [_error], E_OK
			jz	.Refill
.ViewErr	call _space
			call _view_err
			call _space
			call _c_r
			cmp DWORD [in_colon], 1
			jz	.KO
			jmp .Again
.KO			call _space
			mov	ebx, MSG_KO
			call gstdio_draw_text
			call _space
			call _c_r
			mov ebx, ' '
			call gstdio_put_cursor 
			mov ebp, [tmpdp]
			jmp .Again
			ret


;*********************************************
; _r_from			R>
;	R: ( n -- )  P: ( -- n )
;	Removes the item on the top of rstack 
;	and puts it onto pstack
;*********************************************
_r_from:
			POP_RS(eax)
			PUSH_PS(eax)
			ret


;*********************************************
; _r_fetch			R@
;	( -- )
;	Places a copy of the item on the top of 
;	the return stack onto the param stack.
;*********************************************
_r_fetch:
			mov eax, [edi]
			PUSH_PS(eax)
			ret


;;;DCell
;*********************************************
; _read_const
; ( ud1 c-addr1 u1 -- ud2 consttype|zero )	; zero if error
;	Reads a constant value let it be 
;	single-integer or double-integer.
;	If it was successfully converted to 
;	an SCell then the number and 1 are pushed 
;	on pstack. If to DCell, then the number and 
;	2 are pushed on pstack. 
;	Zero on pstack indicates that the conversion  
;	failed, i.e. not a number
;	NOTE: At ".GetLen" we throw away the len of the unprocessed string 
;	and its address!
;
; SF (>NUMBER):
; ( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )
;	ud2 is the unsigned result of converting 
;	the characters within the string specified by 
;	c-addr1 u1 into digits, using the number in BASE, 
;	and adding each into ud1 after multiplying ud1 by 
;	the number in BASE. Conversion continues left-to-right 
;	until a character that is not convertible, including any + or -, 
;	is encountered or the string is entirely converted. 
;	c-addr2 is the location of the first unconverted character or 
;	the first character past the end of the string if the string was 
;	entirely converted. u2 is the number of unconverted characters in the string. 
;	An ambiguous condition exists if ud2 overflows during the conversion. 
;*********************************************
_read_const:
			push edi
			mov edi, 1					; consttype
			cmp DWORD [esi], 0
			jz	.Num
			mov eax, [esi+CELL_SIZE]
			cmp BYTE [eax], '-'
			jz	.Neg
			mov ebx, 1					; positive
			jmp .Num
.Neg		dec DWORD [esi]
			inc DWORD [esi+CELL_SIZE]
			mov ebx, -1					; negative
.Num		cmp DWORD [esi], 0
			jz	.GetLen
			push ebx
			call _to_number
			pop ebx
			cmp DWORD [esi], 0
			jz	.GetLen
			mov eax, [esi+CELL_SIZE]
			xor edx, edx
			mov dl, [eax]
			cmp dl, FLOAT_CHAR
			jnz	.GetLen
			mov edi, 2
			dec DWORD [esi]
			add DWORD [esi+CELL_SIZE], 1
			jmp .Num
.GetLen		cmp ebx, 1	
			jz	.SetType
		; negative (negate 64-bit number, same as _d_negate)
			mov edx, [esi+2*CELL_SIZE]	; DCELL	
			mov eax, [esi+3*CELL_SIZE]
			mov ecx, edx		; negating: same as in DNEGATE
			xor	edx, edx
			neg	eax				; eax = 0-eax, setting flags appropriately
			sbb	edx, ecx		; result in edx:eax
		; put 64bit number back
			mov [esi+2*CELL_SIZE], edx	
			mov [esi+3*CELL_SIZE], eax
.SetType	POP_PS(ecx)
			cmp ecx, 0
			jnz	.Err
			mov [esi], edi		; overwrite address of unprocessed text
			jmp .Back
.Err		mov DWORD [esi], 0	; overwrite address of unprocessed text
.Back		pop edi
			ret


;*********************************************
; _recurse			RECURSE
;	( -- )
;	Appends the execution behavior of the 
;	current definition to the current 
;	definition, so it calls itself recursively
;*********************************************
_recurse:
			mov ebx, [_last_tmp]
			PUSH_PS(ebx)
			call _to_body
			add DWORD [esi], CELL_SIZE				; _again subtracts an extra CELL
			call _again
			ret


;*********************************************
;	_refill
;	(  -- flag )
;	Attempt to fill the input buffer from the input source, 
;	returning a true flag if successful.
;	When the input source is the user input device, 
;	attempt to receive input into the terminal input buffer. 
;	If successful, make the result the input buffer, set >IN to zero, 
;	and return true. Receipt of a line containing no characters 
;	is considered successful. If there is no input available from 
;	the current input source, return false.
;	When the input source is a string from EVALUATE, 
;	return false and perform no other action. 
;*********************************************
_refill:
			cmp DWORD [_blk], 0
			jz	.ChkTIB
			mov eax, [_blk]
			inc DWORD [_blk]
			mov DWORD [_to_in], 0
			PUSH_PS(eax)

			PUSH_PS(blocktxt)
			call _find
			POP_PS(eax)		; drop flags|len
			call _execute

			POP_PS(eax)
			cmp eax, 0
			jz	.ChkTIB
			mov [_input_buffer], eax
			mov eax, BLOCK_BUFF_LEN
			mov [_in_input_buffer], eax
			mov eax, TRUE
			cmp DWORD [_input_buffer], 0
			jnz	.ChkBlkVal
			mov eax, FALSE
			jmp .ToStack
.ChkBlkVal	cmp DWORD [_blk], 0
			jnz .ToStack
			mov eax, FALSE
.ToStack	PUSH_PS(eax)
			jmp .Back
.ChkTIB		cmp DWORD [_source_id], 0
			jnz	.ChkEval
			mov ebx, [_tib]
			PUSH_PS(ebx)
			mov ebx, [_tib_size]
			PUSH_PS(ebx)
			call _accept
			mov eax, [_tib]
			mov [_input_buffer], eax
			mov eax, [esi]			; no stack-incr
			mov [_in_input_buffer], eax
			mov DWORD [_to_in], 0
			mov DWORD [esi], TRUE
			jmp .Back
.ChkEval	cmp DWORD [_source_id], -1	; evaluate (from string)
			jnz .Fix
			PUSH_PS(FALSE)
			jmp .Back
.Fix		mov DWORD [_source_id], 0	; Currently there are no files
			jmp .ChkTIB
.Back		ret


;*********************************************
; _repeat			REPEAT
;	( -- )
;	At compile time, resolve two branches, 
;	usually set up by BEGIN and WHILE. 
;	In the most common usage, BEGIN leaves 
;	a destination on the control-flow stack.
;	The control-flow stack is the pstack at compile-time
;*********************************************
_repeat:
			call _again
			call _then
			ret


;*********************************************
; _right_bracket	]
;	( -- )
;	Enters compilation state. 
;*********************************************
_right_bracket:
			mov DWORD [_state], COMPILE
			ret


;*********************************************
; _roll				ROLL
;	( n -- )
;	Moves the nth stack entry to the top of the stack, 
;	moving down all the stack entries in between.
;	The 0th item is the top of the stack, so 0 ROLL 
;	does nothing, 1 ROLL is SWAP, 2 ROLL is ROT
;*********************************************
_roll:								; CORE-EXT
			POP_PS(eax)
			push eax
			shl eax, CELL_SIZE_SHIFT
			mov ebx, eax
			pop ecx				; ecx = u 
			mov eax, [esi+ebx]	; eax = xu
			push eax
.Next		mov eax, ecx
			dec eax
			shl eax, CELL_SIZE_SHIFT
			mov ebx, eax		; ebx = (i-1)*CELL_SIZE
			mov eax, [esi+ebx]
			push eax
			mov eax, ecx
			shl eax, CELL_SIZE_SHIFT
			mov ebx, eax		; ebx = i*CELL_SIZE
			pop eax
			mov [esi+ebx], eax
			loop .Next
			pop eax
			mov [esi], eax
			ret


;*********************************************
; _rot				ROT
;	( n1 n2 n3 -- n2 n3 n1)
;	Rotate the top three items on the stack
;*********************************************
_rot:
			mov eax, [esi]
			mov ebx, [esi+CELL_SIZE]
			mov ecx, [esi+2*CELL_SIZE]
			mov [esi], ecx
			mov [esi+CELL_SIZE], eax
			mov [esi+2*CELL_SIZE], ebx
			ret


;*********************************************
; _r_shift			RSHIFT
;	( n1 u -- n2 )
;	Performs a logical right shift of u places 
;	on n1, giving n2
;*********************************************
_r_shift:
			POP_PS(ecx)
			shr DWORD [esi], cl			; !!
			ret


;*********************************************
; _s_quote			S"
;	( -- caddr u )
;	Compiles a string in a definition, returning 
;	its address and count when executed.
;	When interpreting, looks ahead in the input 
;	stream and obtains a character string, 
;	delimited by " . Stores the string in a 
;	tmp buffer and returns the addr and len 
;	of the string.
;
;	Problem: two s"-s. The second one overwrites 
;	the content of the buffer! but only if INTERPRET, in COMPILE it's ok!
;*********************************************
_s_quote:
			cmp DWORD [_state], INTERPRET
			jnz .Comp
			mov eax, '"'
			PUSH_PS(eax)
			call _word
;			copy len+1 chars from dp to tmp-buff
			xor ecx, ecx
			mov ebx, ebp
			add ebx, CELL_SIZE
			mov cl, [ebx]
			inc cl
			push esi
			push edi
			mov esi, ebx
			mov edi, s_tmp_buff
			rep movsb
			pop edi
			pop esi
			mov DWORD [esi], s_tmp_buff
			call _count
			jmp .Back
.Comp		mov eax, '"'
			PUSH_PS(eax)
			call _word
			POP_PS(eax)						; throw away caddr
			mov eax, [rtsquote]				; WORD skips Link (a CELL_SIZE)
			COMPILE_CELL(eax)
			WORD_PTR2(ebp)
			mov ebp, ebx
			ALIGN_PTR(ebp)
			mov ebp, eax
.Back		ret


;*********************************************
; _semi_colon		;
;	( -- )
;	Ends the current definition and enters 
;	interpretation state. If the dp is not aligned, 
;	reserve enough space to align it.
;*********************************************
_semi_colon:
			call _exit
			mov DWORD [_state], INTERPRET
			mov DWORD [in_colon], 0
			call mark_word
			ret


;*********************************************
; _sign
;	( n -- )
;	If n is negative adds a minus sign to PNO
;*********************************************
_sign:
			POP_PS(eax)
			cmp eax, 0
			jge .Back
			mov ebx, [p_pnos]
			mov BYTE [ebx], '-'
			sub DWORD [p_pnos], CHAR_SIZE
			inc BYTE [in_pnos]
.Back		ret


;*********************************************
; _slash			/
;	( n1 n2 -- n3 )
;	Divide n1 by n2, leaving the quotient n3.
;*********************************************
_slash:
			POP_PS(ebx)
			xor edx, edx
			mov eax, [esi]
			cdq					; converts signed 32-bit in EAX to 64-bit in EDX:EAX
			idiv ebx
			mov [esi], eax
			ret


;*********************************************
; _slash_mod		/MOD
;	(n1 n2  -- n3 n4 )
;	Divide n1 by n2, leaving the remainder n3 
;	and the quotient n4.
;*********************************************
_slash_mod:
			mov ebx, [esi]
			xor edx, edx
			mov eax, [esi+CELL_SIZE]
			cdq					; converts signed 32-bit in EAX to 64-bit in EDX:EAX
			idiv ebx
			mov [esi], eax
			mov [esi+CELL_SIZE], edx
			ret


;*********************************************
; _source			SOURCE
;	( -- addr u )
;*********************************************
_source:
			mov eax, [_input_buffer]
			PUSH_PS(eax)
			mov eax, [_in_input_buffer]
			PUSH_PS(eax)
			ret


;*********************************************
; _space			SPACE
;	( -- )
;	Displays a space
;*********************************************
_space:
			mov ebx, DWORD DELIM
			call gstdio_draw_char
			ret


;*********************************************
; _spaces			SPACES
;	( n -- )
;	Displays n spaces
;*********************************************
_spaces:
			POP_PS(ecx)
			cmp ecx, 0
			jz	.Back
			mov ebx, DWORD DELIM
.Next		call gstdio_draw_char
			loop .Next
.Back		ret


;*********************************************
; _star				*
;	( n1 n2 -- n3 )
;	Multiply n1 by n2 leaving the product n3
;*********************************************
_star:
			POP_PS(ebx)
			mov eax, [esi]
			imul ebx
			mov [esi], eax
			ret


;*********************************************
; _star_slash			*/
;	( n1 n2 n3 -- n4 )
; 
;	Multiply n1 by n2 producing the intermediate double-cell result d. 
;	Divide d by n3 giving the single-cell quotient n4. 
;	An ambiguous condition exists if n3 is zero or if the quotient n4 lies 
;	outside the range of a signed number. If d and n3 differ in sign, 
;	the implementation-defined result returned will be the same as that 
;	returned by either the phrase >R M* R> FM/MOD SWAP DROP or 
;	the phrase >R M* R> SM/REM SWAP DROP
;*********************************************
;_star_slash:
;			mov eax, [esi+CELL_SIZE]
;			mov ebx, [esi+2*CELL_SIZE]
;;			xor edx, edx
;			imul ebx
;			mov ebx, [esi]
;			idiv ebx
;			mov [esi+2*CELL_SIZE], eax
;			add esi, 2*CELL_SIZE
;			ret


;*********************************************
; _star_slash_mod			*/MOD
;	( n1 n2 n3 -- n4 n5 )
; 
; Multiply n1 by n2 producing the intermediate double-cell result d. 
; Divide d by n3 producing the single-cell remainder n4 and the single-cell quotient n5. 
; An ambiguous condition exists if n3 is zero, or if the quotient n5 lies outside 
; the range of a single-cell signed integer. If d and n3 differ in sign, 
; the implementation-defined result returned will be the same as that returned by 
; either the phrase >R M* R> FM/MOD or the phrase >R M* R> SM/REM . 
;*********************************************
;_star_slash_mod:
;			mov eax, [esi+CELL_SIZE]
;			mov ebx, [esi+2*CELL_SIZE]
;;			xor edx, edx
;			imul ebx
;			mov ebx, [esi]
;			idiv ebx
;			mov [esi+2*CELL_SIZE], edx
;			mov [esi+CELL_SIZE], eax
;			add esi, CELL_SIZE
;			ret


;*********************************************
; _store			!
;	( n addr -- )
;	Stores n at the cell at addr, removing both 
;	from the stack
;*********************************************
_store:
			POP_PS(ebx)
			POP_PS(eax)
			mov [ebx], eax
			ret


;*********************************************
; _swap				SWAP
;	( n1 n2 -- n2 n1 )
;	Reverses the top two stack items
;*********************************************
_swap:
			mov eax, [esi]
			mov ebx, [esi+CELL_SIZE]
			mov [esi], ebx
			mov [esi+CELL_SIZE], eax
			ret


;*********************************************
; _then				THEN
;	( -- )
;
;*********************************************
_then:
			POP_PS(ebx)
			mov eax, ebp
			sub eax, ebx
			sub eax, CELL_SIZE				; (colon) will increase [_ip]
			mov [ebx], eax
			ret


;*********************************************
; _throw			THROW
;	( -- )
;	
;	We check if the current task is the Main-task.
;	If not, then switch to the Main-task and then kill the other task
;	The idea is to enable only the Main-task to call QUIT (control the command-line).
;	Maybe QUIT should be EXEC_ONLY (but there is the word LOAD too!!)
; NOTE: This hasn't been tested!!!
; CATCH hasn't been implemented!!
;*********************************************
%ifdef MULTITASKING_DEF
_throw:								; EXCEPTION
			POP_PS(eax)
			cmp eax, -2
			jnz	.NoType
			call _type
.NoType		cli
			cmp DWORD [_taskid], MAIN_TASK_ID	; Main-task?
			jne	.Switch							; if not, then switch to Main-task
			mov esi, [_pstack0]					; empty data stack
			mov edi, [_rstack0]					; empty return stack (!?)
			; empty kernel stack
			mov	esp, STACKBUFF+STACKLEN
			jmp .EnableIRQ
.Switch		mov eax, [_taskid]
			dec eax
			mov ebx, [_tasklen]
			mul ebx
			mov ebx, [_taskbuff]
			add ebx, eax
			add ebx, TASK_STATE_OFFS
			mov DWORD [ebx], TASK_UNUSED
			mov BYTE [from_irq], 0
			mov ebx, [_taskbuff]	; buffer of Main-task (the first buffer)
			mov ecx, MAIN_TASK_ID
			call activate_task
.EnableIRQ	sti
			; call _quit (empties return stack)	[jmp WarmStart]
			jmp WarmStart			; ColdStart would reload words to dictionary
;			call _quit				; a WarmStart without including kernel.asm
;			jmp $
			ret
%else
_throw:								; EXCEPTION
			POP_PS(eax)
			cmp eax, -2
			jnz	.NoType
			call _type
.NoType		cli
			mov esi, [_pstack0]					; empty data stack
			mov edi, [_rstack0]					; empty return stack (!?)
			; empty kernel stack
			mov	esp, STACKBUFF+STACKLEN
			jmp .EnableIRQ
.EnableIRQ	sti
			; call _quit (empties return stack)	[jmp WarmStart]
			jmp WarmStart			; ColdStart would reload words to dictionary
;			call _quit				; a WarmStart without including kernel.asm
;			jmp $
			ret

%endif		; MULTITASKING_DEF


;*********************************************
; _tick				'
;	( caddr -- dptoxt )
;	from the name of a word it retrieves its xt
;	caddr is ptr-to-flags|length-byte (from _word)
;	e.g. ' WORDS
;*********************************************
_tick:
			mov eax, DELIM
			PUSH_PS(eax)
			mov BYTE [check_max_name_len], 1
			call _word
			mov ebx, [esi]
			cmp BYTE [ebx], 0
			jnz	.Find
			POP_PS(ebx)
			jmp .Back
.Find		call _find
			POP_PS(eax)				; throw away flags|len-byte
			cmp DWORD [esi], 0		; is xt zero?
			jnz	.Back
			mov DWORD [_error], E_NOWORD
.Back		ret


;*********************************************
; _to_body			>BODY
;	( dptolink -- dptoxt )
; 	gets ptr to xt from dict-entry (ptr to link)
;*********************************************
_to_body:
			push eax
			push ebx
			POP_PS(eax)
			add eax, CELL_SIZE
			WORD_PTR(eax)
			mov eax, ebx
			ALIGN_PTR(eax)
;			add eax, CELL_SIZE			; code should be changed at several places to have dptodata
			PUSH_PS(eax)
			pop ebx
			pop eax
			ret


;*********************************************
; _to_link				>LINK
;	( dptoxt len -- dptolink )
;	Finds link in dictionary from dptoxt and len
;*********************************************
_to_link:
			POP_PS(eax)			; len 
			POP_PS(ecx)			; ptrtoxt
			inc eax				; flags|len byte
			xor edx, edx
			mov ebx, CELL_SIZE
			div ebx
			; eax: quotient
			; edx: remainder
			cmp edx, 0
			jz .Skip
			inc eax				; if there is remainder (1-3) then increment (plus one CELL_SIZE)
.Skip		shl eax, CELL_SIZE_SHIFT
			sub ecx, eax
			sub ecx, CELL_SIZE	; get to link from flags|len-byte
			PUSH_PS(ecx)
			ret


;;;DCell
;*********************************************
; _to_number		>NUMBER
;	( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )
;	See _read_const for details
;*********************************************
_to_number:
			push ebp
			mov ecx, [esi]				; len in ecx
			mov ebx, [esi+CELL_SIZE]	; caddr in ebx
			mov edx, [esi+2*CELL_SIZE]	; DCELL Hi32bits
			mov eax, [esi+3*CELL_SIZE]	; DCELL Lo32bits
.Digit		push eax
			xor eax, eax
			mov al, [ebx]
			push edx
		; Returns true(EDX=1) if AL is a valid digit acc. to the current BASE
			call is_base_digit		; after: AL is uppercase char!
			cmp edx, 0
			pop edx
			jz	.Store
			cmp ecx, 0
			jz	.Store
			mov ebp, eax			; digit in EBP
			pop eax
			push ebx	
			mov ebx, [_base]
		; In:  EDX:EAX, EBX	
		; Out: EDX:EAX
			call umul64bitWith32bit
			pop ebx
			cmp ebp, '9'
			ja	.Hex
			sub ebp, '0'
		; add 32bit to 64bit:
			clc
			add eax, ebp
			adc edx, 0				; clears carry-flag!?	[this maybe not necessary (multiply with base: last digit 0)]
			jmp	.Inc
.Hex		push eax
			mov eax, ebp
			call gutil_toupper
			mov ebp, eax
			pop eax
			sub ebp, 'A'
			add ebp, 10
		; add 32bit to 64bit:
			clc
			add eax, ebp
			adc edx, 0				; clears carry-flag!?	[this maybe not necessary (multiply with base: last digit 0)]
.Inc		inc ebx
			dec ecx
			jmp .Digit
.Store		pop eax
			mov [esi+2*CELL_SIZE], edx	; DCELL Hi32bits
			mov [esi+3*CELL_SIZE], eax	; DCELL Lo32bits
			mov [esi+CELL_SIZE], ebx	; caddr in ebx
			mov [esi], ecx				; len in ecx
.Back		pop ebp
			ret


; Returns true(EDX=1) if AL is a valid digit acc. to the current BASE
is_base_digit:
			push ebx
			call gutil_toupper
			cmp al, '0'
			jge .Chk9
			jmp .ChkA
.Chk9		cmp al, '9'
			jng .ChkBase1
			jmp .ChkA
.ChkBase1	xor ebx, ebx
			mov bl, al
			sub ebx, '0'
			cmp ebx, [_base]
			jnge .Valid
.Invalid	mov edx, 0
			jmp .Back
.Valid		mov edx, 1
			jmp .Back
.ChkA		cmp al, 'A'
			jge .ChkZ
			jmp .Invalid
.ChkZ		cmp al, 'Z'
			jng .ChkBase2
			jmp .Invalid
.ChkBase2	xor ebx, ebx
			mov bl, al
			sub ebx, 'A'
			add ebx, 10
			cmp ebx, [_base]
			jnge .Valid
			jmp .Invalid
.Back		pop ebx
			ret

					
;*********************************************
; _to_r				>R
;	( n -- ) R: ( -- n )
;	Removes the top item on pstack and puts it 
;	onto rstack
;*********************************************
_to_r:
			POP_PS(eax)
			PUSH_RS(eax)
			ret


;*********************************************
; _true				TRUE
;	( -- flag )
;	Returns a true flag (all bits set)
;*********************************************
_true:								; CORE-EXT
			PUSH_PS(TRUE)
			ret


;*********************************************
; _tuck				TUCK
;	( n1 n2 -- n2 n1 n2 )
;	Places a copy of the top stack item below 
;	the 2nd one
;*********************************************
_tuck:								; CORE-EXT
			mov eax, [esi]
			PUSH_PS(eax)
			mov eax, [esi+CELL_SIZE]
			mov ebx, [esi+2*CELL_SIZE]
			mov [esi+2*CELL_SIZE], eax
			mov [esi+CELL_SIZE], ebx
			ret


;*********************************************
; _type				TYPE
;	( caddr u -- )
;	Outputs the character string at caddr, 
;	length u
;*********************************************
_type:
			push edi
			POP_PS(ecx)
			POP_PS(edi)
			xor ebx, ebx
.Next		mov bl, BYTE [edi]
			call gstdio_draw_char
			inc edi
			loop .Next
			pop edi
			ret


;*********************************************
; _two_plus			2+
;	( n1 -- n2 )
;	Adds 2 to n1, giving the sum n2
;*********************************************
_two_plus:
			add DWORD [esi], 2
			ret


;*********************************************
; _two_minus		2-
;	( n1 -- n2 )
;	Subtracts 2 from n1, giving the diff n2
;*********************************************
_two_minus:
			sub DWORD [esi], 2
			ret


;*********************************************
; _two_slash		2/
;	( n1 -- n2 )
;	Return n2, the result of shifting n1 one bit 
;	towards the least-significant bit, leaving 
;	the most-significant bit unchanged.
;*********************************************
_two_slash:
			shr DWORD [esi], 1	
			ret


;*********************************************
; _two_star		2*
;	( n1 -- n2 )
;	Return n2, the result of shifting n1 one bit 
;	towards the most-significant bit, filling 
;	the least-significant bit with zero.
;*********************************************
_two_star:
			shl DWORD [esi], 1	
			ret


;*********************************************
; _u_dot			U.
;	( u -- )
;	Displays the top stack item as an unsigned 
;	integer followed by a space
;*********************************************
_u_dot:
			PUSH_PS(0)
			call _less_number_sign
			call _number_sign_s
			call _number_sign_greater
			call _type
			call _space
			ret


;*********************************************
; _u_dot_r			U.R
;	( u n -- )
;	Similar to .R but unsigned.
;*********************************************
_u_dot_r:
			POP_PS(ecx)
			push ecx
			PUSH_PS(0)
			call _less_number_sign
			call _number_sign_s
			call _number_sign_greater
			pop ecx
			cmp DWORD [esi], ecx
			jge	.Print
			sub ecx, DWORD [esi]
			PUSH_PS(ecx)
			call _spaces
.Print		call _type
			call _space
			ret


;*********************************************
; _u_greater_than	U>
;	( u1 u2 -- flag )
;	Returns true if u1 is greater than u2
;*********************************************
_u_greater_than:
			POP_PS(eax)
			cmp [esi], eax
			ja .Gt	
			mov DWORD [esi], FALSE
			jmp .Back
.Gt			mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _u_greater_or_equal_than	U>=
;	( u1 u2 -- flag )
;	Returns true if u1 is greater or equal than u2
;*********************************************
_u_greater_or_equal_than:
			POP_PS(eax)
			cmp [esi], eax
			jnc .Gt	
			mov DWORD [esi], FALSE
			jmp .Back
.Gt			mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _u_less_than		U<
;	( u1 u2 -- flag )
;	Returns true if u1 is less than u2
;*********************************************
_u_less_than:
			POP_PS(eax)
			cmp [esi], eax
			jc .Lt	
			mov DWORD [esi], FALSE
			jmp .Back
.Lt			mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _u_less_or_equal_than		U<=
;	( u1 u2 -- flag )
;	Returns true if u1 is less or equal than u2
;*********************************************
_u_less_or_equal_than:
			POP_PS(eax)
			cmp [esi], eax
			jna .Lt	
			mov DWORD [esi], FALSE
			jmp .Back
.Lt			mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _u_star			U*
;	( u1 u2 -- u3 )
;	Unsigned multiply u1 by u2 leaving the product u3
;*********************************************
_u_star:
			POP_PS(ebx)
			mov eax, [esi]
			mul ebx
			mov [esi], eax
			ret


;*********************************************
; _unloop			UNLOOP
;	( -- )
;	Discards the loop parameters for the 
;	current nesting level. Needed when calling 
;	EXIT in a DO-LOOP.
;*********************************************
_unloop:
			add edi, 2*CELL_SIZE
			ret


;*********************************************
; _until			UNTIL
;	( n -- )
;	At compile time, compiles a conditional 
;	backward branch to the location on the 
;	control-flow stack (usually left there by 
;	BEGIN). AT runtime, if n is zero, takes the 
;	backwards branch; otherwise, continues 
;	execution beyond UNTIL.
;*********************************************
_until:
			mov eax, [rtzbranch]
			COMPILE_CELL(eax)
			POP_PS(eax)
			sub	eax, ebp
			sub	eax, CELL_SIZE
			COMPILE_CELL(eax)
			ret


;*********************************************
; _unused			UNUSED
;	( -- u )
;	Returns u, the number of bytes remaining 
;	in the memory area where dictionary entries 
;	are constructed.
; Currently: (PAD-DICT)
;*********************************************
_unused:							; CORE-EXT
			call _here
			POP_PS(eax)
			mov ebx, PAD
			sub ebx, eax
			PUSH_PS(ebx)
			ret


;*********************************************
; _variable			VARIABLE
;	( "<spaces>name" -- )
;	Defines a variable. Execution of name will 
;	return the address of its data space.
;*********************************************
_variable:
			call create_definition					; why not: call _create !? if dp-offs will be used then we won't need A_VARIABLE ...
			COMPILE_CELL(_paren_variable_paren)
			COMPILE_CELL(0)
			call mark_word
			ret


;*********************************************
; _view_err			VIEWERR
;	( -- )
;	Message according to error-code
;*********************************************
_view_err:
			mov ebx, [_error]
			cmp BYTE [err_msg_word+ebx], 1
			jz	.Word
			jmp .Msg
.Word		mov ebx, DWORD '['
			call gstdio_draw_char
			mov ebx, ebp
			add ebx, CELL_SIZE		; skip link-ptr
			PUSH_PS(ebx)
			mov BYTE [use_length_mask], 1
			call _count
			call _type
			mov ebx, DWORD ']'
			call gstdio_draw_char
			mov ebx, ' '
			call gstdio_draw_char
.Msg		mov eax, [_error]
			shl eax, CELL_SIZE_SHIFT
			mov ebx, eax
			mov ebx, [err_msg_arr+ebx]
			call gstdio_draw_text

%ifdef MULTITASKING_DEF
			mov ebx, ' '
			call gstdio_draw_char
			mov ebx, TaskIdTxt
			call gstdio_draw_text
			mov ebx, DELIM
			call gstdio_draw_char
			mov eax, [_taskid]
			call gstdio_draw_dec
			mov ebx, DWORD ')'
			call gstdio_draw_char
%endif

			mov ebx, [_error]
			cmp BYTE [err_msg_abort+ebx], 1
			jz	.Abort
			jmp .Back
.Abort		mov ebx, DWORD '.'
			call gstdio_draw_char
			call _space
			mov ebx, err_msg_aborting
			call gstdio_draw_text
			call _abort
.Back		ret


;*********************************************
; _w_comma			W,
;	( w -- )
;	Store word to dictionary and advance dp
;*********************************************
_w_comma:
			POP_PS(eax)
			mov WORD [ebp], ax
			add ebp, 2
			ret


;*********************************************
; _w_fetch			W@
;	( waddr -- w )
;	fetch the word(i.e. 2bytewideInteger) stored at waddr
;*********************************************
_w_fetch:
			mov ebx, [esi]
			xor eax, eax
			mov ax, [ebx]
			mov [esi], eax
			ret


;*********************************************
; _w__plus_store	W+!
;	( w waddr -- )
;	Adds word w to word at waddr
;*********************************************
_w_plus_store:
			POP_PS(ebx)
			POP_PS(eax)
			add [ebx], ax
			ret


;*********************************************
; _w_store			W!
;	( w waddr -- )
;	Stores word w at waddr
;*********************************************
_w_store:
			POP_PS(ebx)
			POP_PS(eax)
			mov [ebx], ax
			ret


;*********************************************
; _while			WHILE
;	( n -- )
;	At compile time, places a new unresolved 
;	forward reference origin on the control-stack, 
;	under the topmost item (which is usually a 
;	destination left by BEGIN). 
;	At runtime, if n is zero, takes the forward 
;	branch to the destination that will have been 
;	supplied (e.g. by REPEAT) to resolve WHILE's origin; 
;	otherwise, continues execution beyond WHILE.
;*********************************************
_while:
			call _if
			call _swap
			ret

;*********************************************
; _within			WITHIN
;	( n1|u1 n2|u2 n3|u3 -- flag )
;	Perform a comparison of a test value n1|u1 with 
;	a lower limit n2|u2 and an upper limit n3|u3, 
;	returning true if either (n2|u2 < n3|u3 and 
;	(n2|u2 <= n1|u1 and n1|u1 < n3|u3)) or 
;	(n2|u2 > n3|u3 and (n2|u2 <= n1|u1 or n1|u1 < n3|u3)) is true, 
;	returning false otherwise. An ambiguous condition exists if 
;	n1|u1, n2|u2, and n3|u3 are not all the same type. 
;	Note: this is signed 
;	(jumps should be changed to unsigned ones)
; TEST!!
;*********************************************
_within:							; CORE-EXT
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			cmp eax, ebx
			jge	.C1
			jmp .False
.C1			cmp eax, ecx
			jnge .C2
.False		PUSH_PS(FALSE)
			jmp .Back
.C2			PUSH_PS(TRUE)
.Back		ret


;*********************************************
;	_word
; 	( c -- caddr )   
;	c: delimiter; caddr: string (dpOrig) (link+CELL_SIZE)
;	reads into dictionary but doesn't advance dp
;	fills length-byte with the length 	(flags zero)
;	Skips any leading occurences of the delimiter char.
;	Parses text delimited by char. Returns caddr, 
;	the address of a temporary location containing 
;	the parsed text as a counted string
;*********************************************
_word:
			mov eax, [esi]					; get DELIM from pstack
.Skip		mov edx, [_to_in]
			cmp edx, [_in_input_buffer]		; skip whitespace
			jnge .Chk
			jmp .Prs
.Chk		mov ebx, [_input_buffer]
			add ebx, [_to_in]
			cmp BYTE [ebx], al
			jnz .Prs
			inc DWORD [_to_in]
			jmp .Skip
	;	( c -- addr num )
.Prs		call _parse
			mov ebx, ebp
			add ebx, CELL_SIZE				; skip link !
			POP_PS(eax)						; length of word
		cmp BYTE [check_max_name_len], 0
		je	.StoreLen
		mov BYTE [check_max_name_len], 0
		cmp eax, MAX_WORD_NAME_LEN
		jna	.StoreLen
		mov eax, MAX_WORD_NAME_LEN
.StoreLen	mov BYTE [ebx], al				; length-byte
			mov ecx, [esi]					; addr
			inc ebx
			push esi
			push edi
			mov esi, ecx
			mov edi, ebx
			mov ecx, eax
			rep movsb						; copy chars
			pop edi
			pop esi
%ifdef SPACE_AFTER_WORDNAME
			mov BYTE [ebx+eax], DELIM
%endif
			dec ebx
			mov DWORD [esi], ebx
			ret


;*********************************************
; _xor				XOR
;	( n1 n2 -- n3 )
;	Returns n3, the bit-by-bit exclusive or 
;	of n1 with n2.
;*********************************************
_xor:
			POP_PS(ebx)
			POP_PS(eax)
			xor eax, ebx
			PUSH_PS(eax)
			ret


;*********************************************
; _zero_equals		0=
;	( n -- flag )
;	Returns flag, which is true if n is equal  
;	to zero.
;*********************************************
_zero_equals:	
			cmp DWORD [esi], 0
			jz	.Zero
			mov DWORD [esi], FALSE
			jmp .Back
.Zero		mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _zero_greater		0>
;	( n -- flag )
;	Returns flag, which is true if n is greater  
;	than zero.
;*********************************************
_zero_greater:						; CORE-EXT
			cmp DWORD [esi], 0
			jg	.Gt
			mov DWORD [esi], FALSE
			jmp .Back
.Gt			mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _zero_less		0<
;	( n -- flag )
;	Returns flag, which is true if n is less  
;	than zero.
;*********************************************
_zero_less:
			cmp DWORD [esi], 0
			jnge .NGE
			mov DWORD [esi], FALSE
			jmp .Back
.NGE		mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _zero_not_equals	0<>
;	( n -- flag )
;	Returns flag, which is true if n is not 
;	equal to zero
;*********************************************
_zero_not_equals:					; CORE-EXT
			cmp DWORD [esi], 0
			jnz	.NotEq
			mov DWORD [esi], FALSE
			jmp .Back
.NotEq		mov DWORD [esi], TRUE
.Back		ret


;*************************************************
; _restore_input		RESTORE-INPUT
;	(xn ... x1 n -- flag )
;*************************************************
_restore_input:
			POP_PS(eax)
			POP_PS(eax)
			mov [_blk], eax
			POP_PS(eax)
			mov [_to_in], eax
			POP_PS(eax)
			mov [_in_input_buffer], eax
			POP_PS(eax)
			mov [_input_buffer], eax
			POP_PS(eax)
			mov [_source_id], eax
			PUSH_PS(TRUE)
			ret


restore_input_specification:
			POP_RS(ecx)
			mov eax, ecx
			push eax
.Next		call _r_from
			loop .Next
			pop eax
			PUSH_PS(eax)
			call _restore_input
			POP_PS(eax)
			ret


;*************************************************
; _save_input			SAVE-INPUT
;	( -- xn ... x1 n)
;*************************************************
_save_input:
			mov eax, [_source_id]
			PUSH_PS(eax)
			mov eax, [_input_buffer]
			PUSH_PS(eax)
			mov eax, [_in_input_buffer]
			PUSH_PS(eax)
			mov eax, [_to_in]
			PUSH_PS(eax)
			mov eax, [_blk]
			PUSH_PS(eax)
			mov eax, 5
			PUSH_PS(eax)
			ret


save_input_specification:
			call _save_input
			POP_PS(ecx)
			mov eax, ecx
			push eax
.Next		call _to_r
			loop .Next
			pop eax
			PUSH_PS(eax)
			call _to_r
			ret


%ifdef HASHTABLE_DEF
; Hashing (Hash-Table) DJB2 algorithm
; IN: EBX(pointer to flags|length-byte)
; OUT: EAX(hash)
fhash:
			push ebx
			push ecx
			push edx
			mov eax, 5381
			xor ecx, ecx
			mov cl, BYTE [ebx]	; CL is len of name
			and cl, LENGTH_MASK
			xor edx, edx
.NextCh		inc ebx				; EBX points to first char of name		
			mov edx, eax
			shl eax, 5
			add eax, edx
			xor edx, edx
			mov dl, BYTE [ebx]
			add eax, edx
			loop .NextCh
			xor edx, edx		; modulo HASHLEN
			mov ebx, HASHLEN
			div ebx
			mov eax, edx
			pop edx
			pop ecx
			pop ebx
			ret


; IN: EAX(hash), EBX(points to link-ptr of the word to be added)
; OUT: _error contains E_HASHTABLE_LISTFULL in case of an error
hash_table_add:
			shl eax, HASHSHIFT
			shl eax, CELL_SIZE_SHIFT	; to bytes
			add eax, HASHTABLE
			xor ecx, ecx
.ChkSlot	cmp DWORD [eax], 0
			jnz	.FindSlot
			mov [eax], ebx
			jmp .Back
.FindSlot	inc ecx
			cmp ecx, HASHLISTLEN
			jz	.ListFull
			add eax, CELL_SIZE
			jmp .ChkSlot
.ListFull	mov DWORD [_error], E_HASHTABLE_LISTFULL
.Back		ret


; Moves items after a zero in a list (that belongs to a slot) to the left by one
; Should move only if nex item is non-zero !?
; IN: EAX(list-item ptr that contains zero, the forgotten word)
; IN: ECX (idx from the left)
hash_table_move:
			cmp ecx, HASHLISTLEN-1
			jz	.Back
.Next		mov edx, eax
			add edx, CELL_SIZE
			mov edx, [edx]
			mov [eax], edx
			add eax, CELL_SIZE
			inc ecx
			cmp ecx, HASHLISTLEN-1
			jc	.Next
.Back		ret

%endif	; HASHTABLE_DEF


; Should be a USER variable, but a register has no address
;*********************************************
; _sp_fetch				SP@	
;	( -- addr )
;	Pushes the address of the top of the 
;	parameter stack before SP@ is executed
;*********************************************
_sp_fetch:
			mov eax, esi
			PUSH_PS(eax)
			ret

%ifdef MULTITASKING_DEF
;*********************************************
; _user				USER
;	( "<spaces>name" -- )
;	Defines a user variable. Execution of name 
;	will return the address of its data space 
;	from the user-table of the current task
;*********************************************
_user:
			call create_definition		
			COMPILE_CELL(_paren_user_paren)
			mov eax, [user_offs]
			COMPILE_CELL(eax)
			call _incuser
			call mark_word
			ret


;*********************************************
; _incuser			INCUSER
;	( -- )
;	Increases the value of the number of 
;	user variables (user_offs) by CELL_SIZE.
;	Useful if we need an array in the user-table
;*********************************************
_incuser:
			; put a zero in this var in every user table!
			mov edx, [_taskbuff]
			add edx, TASK_USERVAR_OFFS
			add edx, [user_offs]
			mov ecx, 0
.NextTable	mov DWORD [edx], 0
			add edx, [_tasklen]
			inc ecx
			cmp ecx, TASK_MAX_NUM
			jnz	.NextTable
			add DWORD [user_offs], CELL_SIZE
			ret


;*********************************************
; _paren_user_paren	(USER)
;	( -- addr )
;	Runtime procedure compiled by USER, which 
;	pushes the address of the user-variable on 
;	the parameter-stack
;	Its value is the index of the variable in 
;	the USER-table and it's added to the 
;	addr of the User-table, this way we can 
;	use ! and @ the normal way
;*********************************************
_paren_user_paren:
			; if the depth of rstack is not zero --> called from a colon-def: ip = *ip
			cmp edi, [_rstack0]
			jz	.SkipDeref
			; dereference ip
			push DWORD [_ip]
			mov ebx, [_ip]					; ip = *ip
			mov eax, [ebx]
			mov [_ip], eax
.SkipDeref	mov ebx, [_ip]
			add ebx, CELL_SIZE
			mov eax, [ebx]
			push eax
;			[_taskbuff]+([_taskid]-1)*[_tasklen]+TASK_USERVAR_OFFS
			mov eax, [_taskid]
			dec eax
			mov ebx, [_tasklen]
			mul ebx
			mov ebx, [_taskbuff]
			add ebx, eax
			add ebx, TASK_USERVAR_OFFS
			pop eax
			add eax, ebx
			PUSH_PS(eax)
			; restore ip if it was dereferenced
			cmp edi, [_rstack0]
			jz	.SkipUnref
			pop DWORD [_ip]
.SkipUnref	ret


_paren_user_paren2:
			; if the depth of rstack is not zero --> called from a colon-def: ip = *ip
			cmp edi, [_rstack0]
			jz	.SkipDeref
			; dereference ip
			push DWORD [_ip]
			mov ebx, [_ip]					; ip = *ip
			mov eax, [ebx]
			mov [_ip], eax
.SkipDeref	mov ebx, [_ip]
			add ebx, CELL_SIZE
			mov eax, [ebx]
			shl eax, CELL_SIZE_SHIFT
			add eax, user_table
			PUSH_PS(eax)
			; restore ip if it was dereferenced
			cmp edi, [_rstack0]
			jz	.SkipUnref
			pop DWORD [_ip]
.SkipUnref	ret

%endif	; MULTITASKING_DEF

%ifndef MULTITASKING_DEF
;*********************************************
; _sleep				SLEEP
;	(  -- )
;	Waits n millisecs
;*********************************************
_sleep:
			POP_PS(ebx)
			call pit_delay
			ret

%endif


section .data

%include "forth/wordarr.asm"

; USER-variables and USER-table only exist in Multitasking-mode, in Single-tasking there is only System-variables and System-table
; ***********
; SYSTEM-variables		; accessable by the user and common to all the tasks
; System-variables 	[descriptor  dd  xt name, ending-zero-of-name, index-in-system-table]
; the system vars can be changed by the user and common for all the tasks
; DP can't be a system var because it's in EBP which has no address, so HERE and DPW words were added to the dict
; NOTE: PAD should also be a system-variable/constant but its value is computed
scrbuff_		dd _paren_system_paren
				db "scrbuff", 0, SYSTEM_SCRBUFF
bkgfg_clr_		dd _paren_system_paren
				db "bkgfgclr", 0, SYSTEM_BKGFGCLR
chbkgcurr_clr_	dd _paren_system_paren
				db "chbkgcurrclr", 0, SYSTEM_CHBKGCURRCLR
opaque_			dd _paren_system_paren
				db "opaque", 0, SYSTEM_OPAQUE
%ifndef MULTITASKING_DEF
	sp0_		dd _paren_system_paren
				db "sp0", 0, SYSTEM_SP0	
	base_		dd _paren_system_paren
				db "base", 0, SYSTEM_BASE
	source_id_	dd _paren_system_paren
				db "source-id", 0, SYSTEM_SOURCEID
	inpbuff_	dd _paren_system_paren
				db "inpbuff", 0, SYSTEM_INPBUFF
	ininpbuff_	dd _paren_system_paren
				db "#inpbuff", 0, SYSTEM_ININPBUFF
	toin_		dd _paren_system_paren
				db ">in", 0, SYSTEM_TOIN
	ip_			dd _paren_system_paren	
				db "ip", 0, SYSTEM_IP
	blk_		dd _paren_system_paren	
				db "blk", 0, SYSTEM_BLK
	scr_		dd _paren_system_paren	
				db "scr", 0, SYSTEM_SCR
	error_		dd _paren_system_paren	
%endif

%ifdef MULTITASKING_DEF
	system_arr	dd scrbuff_, bkgfg_clr_, chbkgcurr_clr_, opaque_, 0 
%else
	system_arr	dd scrbuff_, bkgfg_clr_, chbkgcurr_clr_, opaque_
				dd sp0_, base_, source_id_, inpbuff_, ininpbuff_, toin_, blk_, ip_, scr_, error_, 0
%endif
	
; currently no data, because the current ones are defines in gstdio
; ...
; e.g.:
;svar dd 0	 ; and add to system_table (below)

%ifdef MULTITASKING_DEF
	system_table dd gstdio_scrbuff, gstdio_bkgclr, gstdio_chbkgclr, gstdio_opaque ; Except for scrbuff, these vars are 16-bits. Two of them can form a DWORD.
												; In gstdio.asm bkgclr and fgclr form a DWORD, since they are consecutive WORDs in memory.
%else
	system_table dd gstdio_scrbuff, gstdio_bkgclr, gstdio_chbkgclr, gstdio_opaque 
				 dd	_pstack0, _pstack, _rstack0, _rstack, _base, _source_id, _input_buffer, _in_input_buffer
				 dd _to_in, _ip, _blk, _scr, _error, s_tmp_buff

_pstack0			dd	0	
_pstack				dd	0	; ESI holds pstack-ptr, so this is just a fake mem-location
_rstack0			dd	0
_rstack				dd	0	; EDI holds rstack-ptr, so this is just a fake mem-location
_base				dd	0
_source_id			dd	0
_input_buffer		dd	0
_in_input_buffer	dd	0	; # of chars in input_buffer
_to_in				dd	0	; # of chars in parsed from input_buffer including delim) (e.g. the third word parsed)
_ip					dd	0	; instruction pointer of the virtual machine (address of current instr)
_blk				dd	0	; block-related
_scr				dd	0	; block-related (a-addr is the address of a cell containing the block number of the block most recently LISTed)
_error				dd	0	

s_tmp_buff	times 80 db 0	; for S" (s_quote)

%endif	; MULTITASKING_DEF
; END of SYSTEM-variables
; ***********

; SYSTEM-constants		; accessable by the user and common to all the tasks, but their value cannot be changed
; System constants 	[descriptor  dd  xt name, ending-zero-of-name, index-in-system-table]
dp0_		dd _paren_system_const_paren
			db "dp0", 0, SYSTEM_DP0
scrw_		dd _paren_system_const_paren
			db "scrw", 0, SYSTEM_SCRW
scrh_		dd _paren_system_const_paren
			db "scrh", 0, SYSTEM_SCRH
framebuff_	dd _paren_system_const_paren
			db "framebuff", 0, SYSTEM_FRAMEBUFF

system_const_arr	dd dp0_, scrw_, scrh_, framebuff_, 0

_dp0		dd	0
_scrw		dd	GSTDIO_XRES
_scrh		dd	GSTDIO_YRES

system_const_table dd _dp0, _scrw, _scrh, gstdio_framebuff
; END of SYSTEM-constants
; ***********

%ifdef MULTITASKING_DEF
; ***********
; USER-variables		; different values for every task
; USER variables (startup)	[descriptor  dd  xt name, ending-zero-of-name, index-in-user-table]
; paren_user_paren2 is their xt-s because these are global variables that will be stored to and read from the user-tables of the tasks 
; during task-switch. During task-switch these global vars get saved to the taskbuffer and loaded from it.
; Their number multiplied by CELL_SIZE is the initial user_offs.
; Byte-offset of USER variables in the user-table.
; The xt of real USER vars are paren_user_paren, that will read the address of the variable from the user-table of the tasks, so no global 
; variable for them. 
; There are more user vars (i.e. one instance of the var for every task) but they are not accessible by the user.
; A real user variable is e.g. "USER UARRAY" with INCUSER INCUSER ... we can have room for every CELL of the array!
; NOTE: _pstack should also be a USER-variable but a register has no address (see SP@)
; NOTE: SOURCE( -- inpbuff ininpbuff) supersedes #TIB !
sp0_		dd _paren_user_paren2
			db "sp0", 0, USER_SP0	
base_		dd _paren_user_paren2
			db "base", 0, USER_BASE
source_id_	dd _paren_user_paren2
			db "source-id", 0, USER_SOURCEID
inpbuff_	dd _paren_user_paren2
			db "inpbuff", 0, USER_INPBUFF
ininpbuff_	dd _paren_user_paren2
			db "#inpbuff", 0, USER_ININPBUFF
toin_		dd _paren_user_paren2
			db ">in", 0, USER_TOIN
ip_			dd _paren_user_paren2	
			db "ip", 0, USER_IP
blk_		dd _paren_user_paren2	
			db "blk", 0, USER_BLK
scr_		dd _paren_user_paren2	
			db "scr", 0, USER_SCR
error_		dd _paren_user_paren2	
			db "error", 0, USER_ERROR

user_arr	dd sp0_, base_, source_id_, inpbuff_, ininpbuff_, toin_, blk_, ip_, scr_, error_, 0
	
user_table:
_pstack0			dd	0	
_pstack				dd	0	; ESI holds pstack-ptr, so this is just a fake mem-location
_rstack0			dd	0
_rstack				dd	0	; EDI holds rstack-ptr, so this is just a fake mem-location
_base				dd	0
_source_id			dd	0
_input_buffer		dd	0
_in_input_buffer	dd	0	; # of chars in input_buffer
_to_in				dd	0	; # of chars in parsed from input_buffer including delim) (e.g. the third word parsed)
_ip					dd	0	; instruction pointer of the virtual machine (address of current instr)
_blk				dd	0	; block-related
_scr				dd	0	; block-related (a-addr is the address of a cell containing the block number of the block most recently LISTed)
_error				dd	0	

s_tmp_buff	times 80 db 0	; for S" (s_quote)
; END of USER-variables
; ***********

user_offs	dd 0			; number of user vars multiplied by CELL_SIZE. Will be incremented by adding a USER var, and also by INCUSER. FORGET <WORD> will restore its value.
tmpuser_offs	dd	0		; see tmpdp, the same for user_offs

tasks_cnt	dd 0	; number of tasks (running, paused). Prepared, Sleeping and Suspended tasks are not included

MainTaskName	db "Main", 0
DummyTaskName	db "Dummy", 0

act_dp	dd 0		; ACTIVTE needs the dp of the WORD that executes ACTIVATE, because ACTIVATE saves it for FORGET

from_irq	db 0	; activate_next_task is also called from PIT

dummy_task_counter	dd 0 ; fill last_key for Ctrl+m, but check it once in 1000. Useful if Main-task is in a loop that calls PAUSE but not KEY

%endif	; MULTITASKING_DEF

last_key	db 0	; PIT-IRQ will need the last-key (e.g. ctrl-c), but _accept function discards it

_pstacklen	dd	0		; length of pstack
_rstacklen	dd	0		; length of rstack
_pstackbuff	dd	0		; address of TASK_MAX_NUM param-stack buffers (if MULTITASKING_DEF) 
_rstackbuff	dd	0		; address of TASK_MAX_NUM return-stack buffers (if MULTITASKING_DEF) 

_last			dd 0			; pointer to last word in dictionary
_last_tmp		dd 0			; in a colon-def (':') we write to _last only after exit (';'), this way the new word won't be found in colon-def
_last_builtin_word	dd 0	; for FORGET

tmpdp			dd 	0		; for storing dp at the begining of COMPILATION and in case of an incomplete definition reload dp from this.

_dp			dd	0

saved_dp	dd	0			; EBP holds the dict_ptr. We can use EBP (i.e. change it) in any function between "pushad" and "popad", 
							; but if we press ctrl-c to stop the currently running task, then the PIT-IRQ may kill the task 
							; before it could execute "popad", so the value of EBP will be lost.
							; Only the Main-task can change the dictionary, ':' (i.e. COLON), LOAD and FORGET are all EXEC_ONLY.

_tib				dd	0
_tib_size			dd	0

_state				dd	0
in_colon			dd	0	; _state is not enough to determine if we are currently in a ':' (i.e. compiling) beacuse of '[' (left_bracket)
tmpip				dd	0	; if EXECUTE called from a colon-def then ip will be dereferenced

dps_on_pstack		dd	0	; used by CASE-OF_ENDOF-ENDCASE. During compilation ENDCASE needs to know how many ebp-s (i.e. dp-s) were pushed to pstack

;PNO (Pictured Numeric Output) similar to printf in C, e.g. ( 1973/11/21 with 1973.1121 on pstack ('.' for DCELL)):
; <# # # [CHAR] / HOLD # # [CHAR] / HOLD #S #> type space
; Output words like '.S', '.' etc uses pno, so type is necessary before e.g. .S which would overwrite PNO-buffer!
; Note that in compilation [CHAR] needs to be used.
pnos		times 64 db 0
pnos_size	db	64 ;equ $-pnos
p_pnos		dd	0
in_pnos		db	0
; related functions: number_sign(#) , less_number_sign(<#) , number_sign_greater(#>), number_sign_s(#S), hold, sign

words_tmp	dd 0	; the array-address of the words to be loaded is stored temporarily here
is_system_or_user	db 0	; used in load_words

MSG_OK	db "ok", 0
MSG_KO	db "Incomplete definition. Removed from dictionary.", 0

NameTooLongTxt	db "Name is too long: ", 0

check_max_name_len	db 0
use_length_mask		db 0

blocktxt		db 5, "block"


%endif

