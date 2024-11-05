%ifndef __FORTH_STRING__
%define __FORTH_STRING__


%include "gutil.asm"
%include "forth/common.asm"
%include "forth/rts.asm"
%include "forth/core.asm"			; _fill !?


section .text

;*********************************************
; _dash_trailing			-TRAILING
;	( caddr u1 -- caddr u2 )
;	Removes trailing space from the string
;*********************************************
_dash_trailing:	
			mov ecx, [esi]
			mov ebx, [esi+CELL_SIZE]
.Next		dec ecx
			cmp BYTE [ebx+ecx], DELIM
			jz	.Next
			inc ecx
			mov [esi], ecx
			ret


;*********************************************
; _slash_string		/STRING
;	(caddr1 u1 n -- caddr2 u2) 
;	removes first n chars
;*********************************************
_slash_string:
			POP_PS(ecx)
			add [esi+CELL_SIZE], ecx
			sub [esi], ecx
			ret


;*********************************************
; _blank			BLANK
;	( c-addr u -- )
;
;	If u is greater than zero, store the character value 
;	for space in u consecutive character positions beginning at c-addr. 
;*********************************************
_blank:
			PUSH_PS(' ')
			call _fill				; !?
			ret


;*********************************************
; _c_move			CMOVE
;	( caddr1 caddr2 u -- ) 
;	copies u bytes from caddr1 to caddr2 
;	(from lower to higher addresses)
;*********************************************
_c_move:
			cld				; clear direction flag, just to be sure
			POP_PS(ecx)
			POP_PS(edx)
			POP_PS(eax)
			push esi
			push edi
			mov esi, eax
			mov edi, edx
			rep movsb
			pop edi
			pop esi
			ret


;*********************************************
; _c_move_up			CMOVE>
;	( caddr1 caddr2 u -- ) 
;	copies u bytes from caddr1 to caddr2 
;	(from higher to lower addresses)
;	For overlapping regions
;*********************************************
_c_move_up:	
			std				; set direction flag
			POP_PS(ecx)
			POP_PS(edx)
			POP_PS(eax)
			push esi
			push edi
			mov esi, eax
			add esi, ecx
			dec esi
			mov edi, edx
			add edi, ecx
			dec edi
			rep movsb
			pop edi
			pop esi
			cld
			ret


;*********************************************
; _compare			COMPARE
;	( caddr1 u1 caddr2 u2 -- n )
;	compares strings. n=0 if identical. ...
;*********************************************
_compare:
			POP_PS(eax)			; u2
			POP_PS(ebx)			; caddr2
			POP_PS(ecx)			; u1
			POP_PS(edx)			; caddr1
			PUSH_PS(eax)
			PUSH_PS(ecx)
			call _min
			POP_PS(ecx)
			push esi
			push edi
			call gutil_strcmp
			pop edi
			pop esi
			PUSH_PS(eax)
			ret


;*********************************************
; _search			SEARCH
;	( c-addr1 u1 c-addr2 u2 -- c-addr3 u3 flag )
;	Searches the string specified by caddr1 u1 
;	for the string specified by caddr2 u2.
;	If flag is true a match was found at caddr3 
;	with u3 chars remaining. If flag is false 
;	there was no match and caddr3 is caddr1 and 
;	u3 is u1
;*********************************************
_search:
			mov DWORD [_error], E_NOPRIM
			ret


;*********************************************
; _s_literal 				SLITERAL
;	( caddr1 u -- ) COMP
;	( -- caddr2 u ) EXEC
;	Compiles into a definition a string 
;	that is characterized by the starting 
;	address and length on the stack at compile time. 
;	At runtime, return the string's address and 
;	length to the stack.
;*********************************************
_s_literal:	
			mov eax, [rtliteral]
			COMPILE_CELL(eax)
			POP_PS(eax)
			POP_PS(ebx)
			COMPILE_CELL(ebx)
			push eax
			mov eax, [rtliteral]
			COMPILE_CELL(eax)
			pop eax
			COMPILE_CELL(eax)
			ret


%endif

