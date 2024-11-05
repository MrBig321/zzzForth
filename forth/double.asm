%ifndef __FORTH_DOUBLE__
%define __FORTH_DOUBLE__


;DOUBLE
;Brodie-StartingForth Ch.7 "the high order cell on top"
;Brodie-ThinkingForth(p240): the high-order part of a double-length number is on top of the stack  !!!


section .text


;*********************************************
; _two_constant			2CONSTANT
;	( x1 x2 "<spaces>name" -- )
;	Defines a constant whose value is x1, x2
;*********************************************
_two_constant:
			call create_definition
			COMPILE_CELL(_paren_two_constant_paren)
			POP_PS(eax)
			POP_PS(ebx)
			COMPILE_CELL(ebx)
			COMPILE_CELL(eax)
			call mark_word
			ret


;*********************************************
; _paren_two_constant_paren	(2CONSTANT)
;	( -- x1 x2 )
;	Runtime procedure compiled by 2CONSTANT, which 
;	pushes its value on pstack
;*********************************************
_paren_two_constant_paren:
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
			add ebx, CELL_SIZE
			mov eax, [ebx]
			PUSH_PS(eax)
			; restore ip if it was dereferenced
			cmp edi, [_rstack0]
			jz	.SkipUnref
			pop DWORD [_ip]
.SkipUnref	ret


;*********************************************
; _two_literal			2LITERAL
;	( x1 x2 -- ) Compile-time
;	( -- x1 x2 ) Run-time
;	Appends run-time semantics (pushing value
;	to the pstack) to the current definition
;*********************************************
_two_literal:
			mov eax, [rtliteral]
			COMPILE_CELL(eax)
			POP_PS(ebx)
			POP_PS(ecx)
			COMPILE_CELL(ecx)	
			COMPILE_CELL(eax)
			COMPILE_CELL(ebx)	
			ret


;*********************************************
; _two_variable			2VARIABLE
;	( "<spaces>name" -- )
;	Defines a variable. Execution of name will 
;	return the address of its data space.
;*********************************************
_two_variable:
			call create_definition					; why not: call _create !? if dp-offs will be used then we won't need A_VARIABLE ...
			COMPILE_CELL(_paren_variable_paren)
			COMPILE_CELL(0)
			COMPILE_CELL(0)
			call mark_word
			ret


; there is unsigned integer arithmetic (where overflow is indicated by the carry flag) and 
;  signed integer arithmetic (where overflow is indicated by the overflow flag).  (!!!)
; signed!? 
;*********************************************
; _d_plus				D+
;	( d1 d2 -- d3 )
;	Adds d1 to d2, leaving the sum d3
;*********************************************
_d_plus:
			POP_PS(edx)
			POP_PS(eax)
			clc
			add [esi+CELL_SIZE], eax
			adc [esi], edx
			ret


; there is unsigned integer arithmetic (where overflow is indicated by the carry flag) and 
;  signed integer arithmetic (where overflow is indicated by the overflow flag).  (!!!)
; signed!? 
;*********************************************
; _d_minus			D-
;	( d1 d2 -- d3 )
;	Subtracts d2 from d1 giving the diff d3
;*********************************************
_d_minus:
			POP_PS(edx)	
			POP_PS(eax)
			clc
			sub [esi+CELL_SIZE], eax
			sbb [esi], edx
			ret


;*********************************************
; _d_dot				D.
;	( d -- )
;	Removes the top of pstack and displays it 
;	as a signed d followed by a space
;*********************************************
_d_dot:
			xor ebx, ebx
			POP_PS(edx)
			POP_PS(eax)
			test edx, (1 << 31)
			jz	.Pos
			mov ecx, edx		; negating: same as in DNEGATE
			xor	edx, edx
			neg	eax				; eax = 0-eax, setting flags appropriately
			sbb	edx, ecx		; result in edx:eax
			mov ebx, 1
.Pos		PUSH_PS(eax)
			PUSH_PS(edx)
			push ebx
			call _less_number_sign
			call _number_sign_s
			pop ebx
			cmp ebx, 1
			jnz	.SkipNeg
			xor ebx, ebx
			mov bl, '-'
			PUSH_PS(ebx)
			call _hold
.SkipNeg	call _number_sign_greater
			call _type
			call _space
			ret


;*********************************************
; _d_dot_r			D.R
;	( d1 n2 -- )
;	Display signed d1 with leading 
;	spaces to fill a field of n2, right-justified
;*********************************************
_d_dot_r:
			xor ebx, ebx
			POP_PS(ecx)
			POP_PS(edx)
			POP_PS(eax)
			test edx, (1 << 31)		; !? problem if called from ".r" (negative number and S>D, see S>D)
			jz	.Pos
			cmp DWORD [_base], 10
			jnz	.Pos
			push ecx
			mov ecx, edx		; negating: same as in DNEGATE
			xor	edx, edx
			neg	eax				; eax = 0-eax, setting flags appropriately
			sbb	edx, ecx		; result in edx:eax
			pop ecx
			mov ebx, 1
.Pos		PUSH_PS(eax)
			PUSH_PS(edx)
			push ebx
			push ecx
			call _less_number_sign
			call _number_sign_s
			pop ecx
			pop ebx
			cmp ebx, 1
			jnz	.SkipNeg
			xor ebx, ebx
			mov bl, '-'
			PUSH_PS(ebx)
			call _hold
.SkipNeg	call _number_sign_greater
			cmp [esi], ecx
			jge	.Print
			sub ecx, DWORD [esi]
			PUSH_PS(ecx)
			call _spaces
.Print		call _type
			call _space
			ret


;*********************************************
; _d_zero_less		D0<
;	( d -- flag )
;	Returns flag, which is true if d is less  
;	than zero.
;*********************************************
_d_zero_less:
			POP_PS(eax)					; Hi32bits is on top
			test eax, (1 << 31)
			jnz	.Neg
			mov DWORD [esi], FALSE
			jmp .Back
.Neg		mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _d_zero_equals		D0=
;	( d -- flag )
;	Returns flag, which is true if n is equal  
;	to zero.
;*********************************************
_d_zero_equals:	
			POP_PS(edx)
			POP_PS(eax)
			cmp edx, 0
			jnz	.False
			cmp eax, 0
			jnz	.False
			PUSH_PS(TRUE)
			jmp .Back
.False		PUSH_PS(FALSE)
.Back		ret


;*********************************************
; d_two_star		D2*
;	( d1 -- d2 )
;	Return d2, the result of shifting d1 one bit 
;	towards the most-significant bit, filling 
;	the least-significant bit with zero.
;*********************************************
; (Docs: implemented as a logical left-shift)
;_d_two_star:
;if negative, negate before shifting!? 
;			POP_PS(edx)
;			POP_PS(eax)
;			xor ebx, ebx
;			test edx, (1 << 31)
;			jz	.Pos
;			mov ebx, 1
;			mov ecx, edx		; negating: same as in DNEGATE
;			xor	edx, edx
;			neg	eax				; eax = 0-eax, setting flags appropriately
;			sbb	edx, ecx		; result in edx:eax
;.Pos		shld edx, eax, 1
;			shl	eax, 1					; !? shld doesn't shift EAX!
;			cmp ebx, 1
;			jnz	.Skip
;			mov ecx, edx		; negating: same as in DNEGATE
;			xor	edx, edx
;			neg	eax				; eax = 0-eax, setting flags appropriately
;			sbb	edx, ecx		; result in edx:eax
;.Skip		PUSH_PS(eax)
;			PUSH_PS(edx)
;			ret


;*********************************************
; d_two_star		D2*
;	( d1 -- d2 )
;	Return d2, the result of shifting d1 one bit 
;	towards the most-significant bit, filling 
;	the least-significant bit with zero.
;*********************************************
; (Docs: implemented as a logical left-shift)
; !?
; SHLD: Shifts the first operand (destination operand) to the left 
; the number of bits specified by the third operand (count operand). 
; The second operand (source operand) provides bits to shift in 
; from the right (starting with bit 0 of the destination operand). 
; Internet: with "cl < 0" --> right-rotate
_d_two_star:
			POP_PS(edx)
			POP_PS(eax)
			mov ebx, eax
			mov ecx, 1
			shld eax, edx, cl	; Why EAX !?
			shld edx, ebx, cl
			test cl, 32
			jz .NoSwap
			xchg edx, eax
.NoSwap		PUSH_PS(eax)
			PUSH_PS(edx)
			ret



;*********************************************
; _d_two_slash		D2/
;	( d1 -- d2 )
;	Return d2, the result of shifting d1 one bit 
;	towards the least-significant bit, leaving 
;	the most-significant bit unchanged.
;*********************************************
; This means arithmetic shift !?
_d_two_slash:
;if negative, negate before shifting!?
			POP_PS(edx)
			POP_PS(eax)
			xor ebx, ebx
			test edx, (1 << 31)
			jz	.Pos
			mov ebx, 1
			mov ecx, edx		; negating: same as in DNEGATE
			xor	edx, edx
			neg	eax				; eax = 0-eax, setting flags appropriately
			sbb	edx, ecx		; result in edx:eax
.Pos		shrd eax, edx, 1
			sar	edx, 1					; !? shrd doesn't shift EDX!
			cmp ebx, 1
			jnz	.Skip
			mov ecx, edx		; negating: same as in DNEGATE
			xor	edx, edx
			neg	eax				; eax = 0-eax, setting flags appropriately
			sbb	edx, ecx		; result in edx:eax
.Skip		PUSH_PS(eax)
			PUSH_PS(edx)
.Back		ret


;*********************************************
; _d_less_than		D<
;	( d1 d2 -- flag )
;	Returns flag which is true if d1 < d2
;*********************************************
_d_less_than:
;negative numbers!? (if negative ==> to positive, check if d1>d2, back to negative!?)
			mov edx, [esi]
			mov eax, [esi+CELL_SIZE]
			mov ecx, [esi+2*CELL_SIZE]
			mov ebx, [esi+3*CELL_SIZE]
			add esi, 3*CELL_SIZE
	;if(edx > ecx || (edx == ecx && eax > ebx)
	;	TRUE
			cmp edx, ecx
			jg	.True
			cmp edx, ecx
			jne	.False
			cmp eax, ebx
			jg	.True
.False		mov DWORD [esi], FALSE
			jmp .Back
.True		mov DWORD [esi], TRUE
.Back		ret


; DOUBLE EXT
;*********************************************
; _d_u_less				DU<
;	( ud1 ud2 -- flag )
;
;	flag is true if and only if ud1 is less than ud2. 
;*********************************************
_d_u_less:
			mov edx, [esi]
			mov eax, [esi+CELL_SIZE]
			mov ecx, [esi+2*CELL_SIZE]
			mov ebx, [esi+3*CELL_SIZE]
			add esi, 3*CELL_SIZE
	;if(edx > ecx || (edx == ecx && eax > ebx)
	;	TRUE
			cmp edx, ecx
			ja	.True
			cmp edx, ecx
			jne	.False
			cmp eax, ebx
			ja	.True
.False		mov DWORD [esi], FALSE
			jmp .Back
.True		mov DWORD [esi], TRUE
.Back		ret


;*********************************************
; _d_equals			D=
;	( d1 d2 -- flag )
;	Returns flag, which is true if d1 is 
;	equal to d2
;*********************************************
_d_equals:
			mov edx, [esi]
			mov eax, [esi+CELL_SIZE]
			mov ecx, [esi+2*CELL_SIZE]
			mov ebx, [esi+3*CELL_SIZE]
			add esi, 3*CELL_SIZE
			cmp edx, ecx
			jne	.False
			cmp eax, ebx
			jne	.False
			mov DWORD [esi], TRUE
			jmp .Back
.False		mov DWORD [esi], FALSE
.Back		ret


;*********************************************
; _d_abs				DABS
;	( d -- ud )
;*********************************************
_d_abs:
			mov edx, [esi]
			mov eax, [esi+CELL_SIZE]
			test edx, (1 << 31)
			jz	.Back
			mov ecx, edx		; negating: same as in DNEGATE
			xor	edx, edx
			neg	eax				; eax = 0-eax, setting flags appropriately
			sbb	edx, ecx		; result in edx:eax
			mov [esi], edx
			mov [esi+CELL_SIZE], eax
.Back		ret


;*********************************************
; _d_max				DMAX
;	( d1 d2 -- d3 )
;	d3 is the greater of d1 and d2
;*********************************************
_d_max:
			mov ecx, [esi]
			mov ebx, [esi+CELL_SIZE]
			mov edx, [esi+2*CELL_SIZE]
			mov eax, [esi+3*CELL_SIZE]
			add esi, 2*CELL_SIZE
	;if(ecx > edx || (ecx == edx && ebx > eax)
	;	Mov
			cmp ecx, edx
			jg	.Mov
			cmp ecx, edx
			jne	.Back
			cmp ebx, eax
			jng	.Back
.Mov		mov [esi], ecx
			mov [esi+CELL_SIZE], ebx
.Back		ret


;*********************************************
; _d_min				DMIN
;	( d1 d2 -- d3 )
;	d3 is the smaller of d1 and d2
;*********************************************
_d_min:
			mov edx, [esi]
			mov eax, [esi+CELL_SIZE]
			mov ecx, [esi+2*CELL_SIZE]
			mov ebx, [esi+3*CELL_SIZE]
			add esi, 2*CELL_SIZE
	;if(ecx > edx || (ecx == edx && ebx > eax)
	;	Mov
			cmp ecx, edx
			jg	.Mov
			cmp ecx, edx
			jne	.Back
			cmp ebx, eax
			jng	.Back
.Mov		mov [esi], edx
			mov [esi+CELL_SIZE], eax
.Back		ret


;*********************************************
; _d_negate			DNEGATE
;	( d1 -- d2 )
;
;	Negates d1, giving d2
;*********************************************
_d_negate:
			mov edx, [esi]
			mov eax, [esi+CELL_SIZE]
			mov ecx, edx
			xor	edx, edx
			neg	eax				; eax = 0-eax, setting flags appropriately
			sbb	edx, ecx		; result in edx:eax
			mov [esi], edx
			mov [esi+CELL_SIZE], eax
			ret


; CORE
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
_star_slash:
			mov eax, [esi+CELL_SIZE]
			mov ebx, [esi+2*CELL_SIZE]
;			xor edx, edx
			imul ebx
			mov ebx, [esi]
			idiv ebx
			mov [esi+2*CELL_SIZE], eax
			add esi, 2*CELL_SIZE
			ret


; CORE
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
_star_slash_mod:
			mov eax, [esi+CELL_SIZE]
			mov ebx, [esi+2*CELL_SIZE]
;			xor edx, edx
			imul ebx
			mov ebx, [esi]
			idiv ebx
			mov [esi+2*CELL_SIZE], edx
			mov [esi+CELL_SIZE], eax
			add esi, CELL_SIZE
			ret


;*********************************************
; _m_star_slash			M*/
;	( d1 n1 +n2 -- d2 )
;
;	Multiply d1 by n1 producing the triple-cell intermediate result t.
;	Divide t by +n2 giving the double-cell quotient d2. 
;	An ambiguous condition exists if +n2 is zero or negative, 
;	or the quotient lies outside of the range of a double-precision signed integer. 
; triple-cell!?
;*********************************************
_m_star_slash:
;triple-cell!?
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(edx)
			POP_PS(eax)
			call imul64bitWith32bit		; !!??
			mov ebx, ecx
			call idiv64by32				; !!??
			PUSH_PS(eax)
			PUSH_PS(edx)
			ret


; CORE
;*********************************************
; _s_to_d				S>D
;	( n -- d )
;
;	Convert the number n to the double-cell number d 
;	with the same numerical value. 
;*********************************************
_s_to_d:
			PUSH_PS(0)
; In case of a 32-bit negative number:
; 	if we convert to a 64-bit negative value, then ".r" will print 16 digits for a negative HEX value (e.g. -12A)
; 	if we don't, then ".r" will print unsigned value for -12A, because the code in D.R checks the topmost bit of Hi32Bits (i.e. 64th bit)
; Maybe ".r" shouldn't call "D.R" !?
			cmp DWORD [esi+CELL_SIZE], 0	
			jge .Back
			neg DWORD [esi+CELL_SIZE]
			call _d_negate
.Back		ret


;*********************************************
; _d_to_s				D>S
;	( d -- n )
;
;	n is the equivalent of d. An ambiguous condition exists 
;	if d lies outside the range of a signed single-cell number. 
;*********************************************
_d_to_s:
			call _drop
			ret


;*********************************************
; _m_plus				M+
;	( d1|ud1 n -- d2|ud2 )
;
;	Add n to d1|ud1, giving the sum d2|ud2. 
;*********************************************
_m_plus:
			call _s_to_d
			call _d_plus
			ret


; CORE
;*********************************************
; _two_store			2!
;	( x1 x2 a-addr -- )
;
;	Store the cell pair x1 x2 at a-addr, with x2 at 
;	a-addr and x1 at the next consecutive cell. 
;	It is equivalent to the sequence SWAP OVER ! CELL+ ! . 
;*********************************************
_two_store:
			POP_PS(ebx)
			POP_PS(eax)
			mov [ebx], eax
			POP_PS(eax)
			mov [ebx+CELL_SIZE], eax
			ret


; CORE
;*********************************************
; _two_fetch			2@
;	( a-addr -- x1 x2 )
;
;	Fetch the cell pair x1 x2 stored at a-addr. 
;	x2 is stored at a-addr and x1 at the next consecutive cell. 
;	It is equivalent to the sequence DUP CELL+ @ SWAP @ . 
;*********************************************
_two_fetch:
			POP_PS(ebx)
			mov eax, [ebx+CELL_SIZE]
			PUSH_PS(eax)
			mov eax, [ebx]
			PUSH_PS(eax)
			ret


; CORE
;*********************************************
; _two_drop			2DROP
;	( x1 x2 -- )
;
;	Drop cell pair x1 x2 from the stack. 
;*********************************************
_two_drop:
			add esi, 2*CELL_SIZE
			ret


; CORE
;*********************************************
; _two_dup			2DUP
;	( x1 x2 -- x1 x2 x1 x2 )
;
;	Duplicate cell pair x1 x2. 
;*********************************************
_two_dup:
			mov eax, [esi]
			mov ebx, [esi+CELL_SIZE]
			PUSH_PS(ebx)
			PUSH_PS(eax)
			ret


; CORE
;*********************************************
; _two_over			2OVER
;	( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 )
;
;	Copy cell pair x1 x2 to the top of the stack. 
;*********************************************
_two_over:
			mov eax, [esi+3*CELL_SIZE]
			mov ebx, [esi+2*CELL_SIZE]
			PUSH_PS(eax)
			PUSH_PS(ebx)
			ret


; CORE
;*********************************************
; _two_swap			2SWAP
;	( x1 x2 x3 x4 -- x3 x4 x1 x2 )
;
;	Exchange the top two cell pairs. 
;*********************************************
_two_swap:
			mov eax, [esi+3*CELL_SIZE]
			mov ebx, [esi+2*CELL_SIZE]
			mov ecx, [esi+CELL_SIZE]
			mov edx, [esi]
			mov [esi+3*CELL_SIZE], ecx
			mov [esi+2*CELL_SIZE], edx
			mov [esi+CELL_SIZE], eax
			mov [esi], ebx
			ret


; DOUBLE EXT
;*********************************************
; _two_rot			2ROT
;	( x1 x2 x3 x4 x5 x6 -- x3 x4 x5 x6 x1 x2 )
;     ax bx cx dx bp di    
;	Rotate the top three cell pairs on the stack 
;	bringing cell pair x1 x2 to the top of the stack. 
;*********************************************
_two_rot:
			push ebp
			push edi
			mov eax, [esi+5*CELL_SIZE]
			mov ebx, [esi+4*CELL_SIZE]
			mov ecx, [esi+3*CELL_SIZE]
			mov edx, [esi+2*CELL_SIZE]
			mov ebp, [esi+CELL_SIZE]
			mov edi, [esi]
			mov [esi+5*CELL_SIZE], ecx
			mov [esi+4*CELL_SIZE], edx
			mov [esi+3*CELL_SIZE], ebp
			mov [esi+2*CELL_SIZE], edi
			mov [esi+CELL_SIZE], eax
			mov [esi], ebx
			pop edi
			pop ebp
			ret


; CORE EXT
;*********************************************
; _two_to_r				2>R
;	( x1 x2 -- ) ( R:  -- x1 x2 )
;
;	Transfer cell pair x1 x2 to the return stack. 
;	Semantically equivalent to SWAP >R >R . 
;*********************************************
_two_to_r:
			POP_PS(eax)
			POP_PS(ebx)
			PUSH_RS(ebx)
			PUSH_RS(eax)
			ret


; CORE EXT
;*********************************************
; _two_r_from				2R>
;	( -- x1 x2 ) ( R:  x1 x2 -- )
;
;	Transfer cell pair x1 x2 from the return stack. 
;	Semantically equivalent to R> R> SWAP . 
;*********************************************
_two_r_from:
			POP_RS(eax)
			POP_RS(ebx)
			PUSH_PS(ebx)
			PUSH_PS(eax)
			ret


; CORE EXT
;*********************************************
; _two_r_fetch				2R@
;	( -- x1 x2 ) ( R:  x1 x2 -- x1 x2 )
;
;	Copy cell pair x1 x2 from the return stack. 
;	Semantically equivalent to R> R> 2DUP >R >R SWAP . 
;*********************************************
_two_r_fetch:

			mov eax, [edi]
			mov ebx, [edi+CELL_SIZE]
			PUSH_PS(ebx)
			PUSH_PS(eax)
			ret


; CORE
;*********************************************
; _m_star					M*
;	( n1 n2 -- d )
;
;	d is the signed product of n1 times n2
;*********************************************
_m_star:
			mov eax, [esi]
			mov ebx, [esi+CELL_SIZE]
;			xor edx, edx
			imul ebx
			mov [esi], edx
			mov [esi+CELL_SIZE], eax
			ret


; CORE
;*********************************************
; _u_m_star					UM*
;	( u1 u2 -- ud )
;
;	Multiply u1 by u2, giving the unsigned double-cell product ud. 
;	All values and arithmetic are unsigned. 
;*********************************************
_u_m_star:
			mov eax, [esi]
			mov ebx, [esi+CELL_SIZE]
;			xor edx, edx
			mul ebx	
			mov [esi], edx
			mov [esi+CELL_SIZE], eax
			ret


; CORE
;*********************************************
; _u_m_slash_mod			UM/MOD
;	( ud u1 -- u2 u3 )
;
;	Divide ud by u1, giving the quotient u3 and the remainder u2. 
;	All values and arithmetic are unsigned. 
;	An ambiguous condition exists if u1 is zero or if the quotient 
;	lies outside the range of a single-cell unsigned integer. 
;*********************************************
_u_m_slash_mod:
			POP_PS(ebx)
			mov edx, [esi]
			mov eax, [esi+CELL_SIZE]
			div ebx	
			mov [esi], eax
			mov [esi+CELL_SIZE], edx
			ret


; CORE
;*********************************************
; _f_m_slash_mod			FM/MOD
;	( d1 n1 -- n2 n3 )
;
;	Divide d1 by n1, giving the floored quotient n3 
;	and the remainder n2. Input and output stack 
;	arguments are signed. An ambiguous condition exists 
;	if n1 is zero or if the quotient lies outside the 
;	range of a single-cell signed integer. 
;*********************************************
; Floored division is integer division in which the 
; remainder carries the sign of the divisor or is zero, 
; and the quotient is rounded to its arithmetic floor.
; Floored Division examples:
; Dividend        Divisor Remainder       Quotient
; --------        ------- ---------       --------
;  10                7       3                1
; -10                7       4               -2
;  10               -7      -4               -2
; -10               -7      -3                1
_f_m_slash_mod:
			POP_PS(ebx)
			mov edx, [esi]
			mov eax, [esi+CELL_SIZE]
			idiv ebx
			mov [esi], eax
			mov [esi+CELL_SIZE], edx
%ifndef FLOORED_DIVISION
			cmp DWORD [esi], 0
			jge .Back
			dec DWORD [esi]
			cmp DWORD [esi+CELL_SIZE], 0
			jge .Inc
			dec DWORD [esi+CELL_SIZE]
			jmp .End
.Inc		inc DWORD [esi+CELL_SIZE]
.End		neg DWORD [esi+CELL_SIZE]
%endif
.Back		ret


; CORE
;*********************************************
; _s_m_slash_rem			SM/REM
;	( d1 n1 -- n2 n3 )
;
;	Divide d1 by n1, giving the symmetric quotient n3 
;	and the remainder n2. 
;	Input and output stack arguments are signed. 
;	An ambiguous condition exists if n1 is zero or 
;	if the quotient lies outside the range of a 
;	single-cell signed integer. 
;*********************************************
; Symmetric division is integer division in which the 
; remainder carries the sign of the dividend or is zero 
; and the quotient is the mathematical quotient 
; rounded towards zero or truncated.
; Symmetric Division examples:
; Dividend        Divisor Remainder       Quotient
; --------        ------- ---------       --------
;  10                7       3                1
; -10                7      -3               -1
;  10               -7       3               -1
; -10               -7      -3                1
_s_m_slash_rem:
			POP_PS(ebx)
			mov edx, [esi]
			mov eax, [esi+CELL_SIZE]
			idiv ebx
			mov [esi], eax
			mov [esi+CELL_SIZE], edx
%ifdef FLOORED_DIVISION	
			cmp DWORD [esi], 0
			jge .Back
			inc DWORD [esi]
			cmp DWORD [esi+CELL_SIZE], 0
			jge .Dec
			inc DWORD [esi+CELL_SIZE]
			jmp .End
.Dec		dec DWORD [esi+CELL_SIZE]
.End		neg DWORD [esi+CELL_SIZE]
%endif
.Back			ret



;int div64by32eq64(uint64* dividend, uint32 divisor)
;{
;  uint32 dividendHi = (uint32)(*dividend >> 32);
;  uint32 dividendLo = (uint32)*dividend;
;  uint32 quotientHi;
;  uint32 quotientLo;
;
;  if (divisor == 0)
;    return 0;
;
;  // This can be done as one 32-bit DIV, e.g. "div ecx"
;  quotientHi = dividendHi / divisor;
;  dividendHi = dividendHi % divisor;
;
;  // This can be done as another 32-bit DIV, e.g. "div ecx"
;  quotientLo = (uint32)((((uint64)dividendHi << 32) + dividendLo) / divisor);
;
;  *dividend = ((uint64)quotientHi << 32) + quotientLo;
;
;  return 1;
;}

; EDX:EAX dividend, 64bit number (IN)
; EBX 32bit numbers divisor (IN)
; EDX:EAX 64bit result (OUT)
; ECX: remainder
udiv64by32:
			push eax
			mov eax, edx
			xor edx, edx
			div ebx				; get high 32 bits of quotient
;quotHi in EAX
			xchg eax, [esp]		; store them on stack, get low 32 bits of dividend
;quotHi on stack
;dividendLo in EAX
;remainder in EDX
			div ebx				; get low 32 bits of quotient
			mov ecx, edx		; save remainder
			pop edx				; 64-bit quotient in edx:eax now
			ret


; EDX:EAX dividend, 64bit number (IN)
; EBX 32bit numbers divisor (IN)
; EDX:EAX 64bit result (OUT)
idiv64by32:						;TODO
			push eax
			mov eax, edx
			xor edx, edx
			div ebx				; get high 32 bits of quotient
;quotHi in EAX
			xchg eax, [esp]		; store them on stack, get low 32 bits of dividend
;quotHi on stack
;dividendLo in EAX
;remainder in EDX
			div ebx				; get low 32 bits of quotient
			pop edx				; 64-bit quotient in edx:eax now
			ret


; In:  EDX:EAX, EBX	
; Out: EDX:EAX
umul64bitWith32bit:	
			push ecx
			push esi
			push ebp
			mov esi, edx		; 32Hi in ESI
			mul ebx				; result in EDX:EAX
			mov ecx, edx		; 32bitHi in ECX
			mov ebp, eax		; 32bitLo in EBP		;endresultLO in EBP
			mov eax, esi
			mul ebx				; result in EDX:EAX	
			mov edx, eax
			add edx, ecx		; no need for ADC, because ECX is 32Hi from previous MUL
			mov eax, ebp
			pop ebp
			pop esi
			pop ecx
			ret


; In:  EDX:EAX, EBX	
; Out: EDX:EAX
imul64bitWith32bit:		;TODO
			push ecx
			push esi
			push ebp
			mov esi, edx		; 32Hi in ESI
			mul ebx				; result in EDX:EAX
			mov ecx, edx		; 32bitHi in ECX
			mov ebp, eax		; 32bitLo in EBP		;endresultLO in EBP
			mov eax, esi
			mul ebx				; result in EDX:EAX	
			mov edx, eax
			add edx, ecx		; no need for ADC, because ECX is 32Hi from previous MUL
			mov eax, ebp
			pop ebp
			pop esi
			pop ecx
			ret


;x=0x0A4565FE
;y=0x03 0x123
;res=0x1ED03205 ACE2EFBA
;	x_lo	dd 0x0A4565FE
;	x_hi	dd 0
;	y_lo	dd 0x123
;	y_hi	dd 0x03
; THIS WORKS!!
;     = x_l*y_l + (x_h*y_l + x_l*y_h)*2^32
;mul64bitWith32bit:				;unsigned multiplication!!!
;			xor edx, edx
;			mov eax, [x_lo]
;			mov ebx, [y_lo]
;			mul ebx				; result in EDX:EAX

;			mov ecx, edx		; 32bitHi in ECX
;			mov ebp, eax		; 32bitLo in EBP		;endresultLO in EBP

;			xor edx, edx
;			mov eax, [x_lo]
;			mov ebx, [y_hi]
;			mul ebx				; result in EDX:EAX	

;			mov edx, eax
;			add edx, ecx		; adc?	if not, then clc!?
;			mov eax, ebp

			; result in EDX:EAX	
;			ret


;;;;;;;;;;;;;;;;;;;;;;;
; What the below code does is multiplication of two 64-bit 
;  signed integers that keeps the least-significant 64 bits of 
;  the product.
;mov esi, y_low
;mov eax, x
;mov edx, eax
;sar edx, 31
;mov ecx, y_high

;imul ecx, eax 			; ecx = y_high *{signed} x

;mov ebx, edx

;imul ebx, esi 			; ebx = sign_extension(x) *{signed} y_low

;add ecx, ebx 			; ecx = y_high *{signed} x_low + x_high *{signed} y_low

;mul esi 				; edx:eax = x_low *{unsigned} y_low

;lea edx, [ecx + edx] 	; edx = high(x_low *{unsigned} y_low + y_high *{signed} x_low + x_high *{signed} y_low)

;mov ecx, dest
;mov [ecx], eax
;mov [ecx + 4], edx

;Where does the other 64-bit multiplicand come from? It's x sign-extended from 32 bits to 64. 
;The sar instruction is used to replicate x's sign bit into all bits of edx. 
;I call this value consisting only of the x's sign x_high. x_low is the value of x actually passed into the routine.

;y_low and y_high are the least and most significant parts of y, just like x's x_low and x_high are.

;From here it's pretty easy:

;product = y *{signed} x =
;(y_high * 232 + y_low) *{signed} (x_high * 232 + x_low) =
;y_high *{signed} x_high * 264 +
;y_high *{signed} x_low * 232 +
;y_low *{signed} x_high * 232 +
;y_low *{signed} x_low

;y_high *{signed} x_high * 264 isn't calculated because it doesn't contribute to the least 
; significant 64 bits of the product. We'd calculate it if we were interested in the full 
; 128-bit product (full 96-bit product for the picky).

;y_low *{signed} x_low is calculated using unsigned multiplication. 
; It's legal to do so because 2's complement signed multiplication gives the same least 
; significant bits as unsigned multiplication. Example: -1 *{signed} -1 = 1
; 0xFFFFFFFFFFFFFFFF *{unsigned} 0xFFFFFFFFFFFFFFFF = 0xFFFFFFFFFFFFFFFE0000000000000001 
; (64 least significant bits are equivalent to 1)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Also: multiplication of two 64-bit numbers to get ...
;Below is the algorithm of 64-bit multiplication:

;x, y: 64-bit integer
;x_h/x_l: higher/lower 32 bits of x
;y_h/y_l: higher/lower 32 bits of y

;x*y  = ((x_h*2^32 + x_l)*(y_h*2^32 + y_l)) mod 2^64
;     = (x_h*y_h*2^64 + x_l*y_l + x_h*y_l*2^32 + x_l*y_h*2^32) mod 2^64
;     = x_l*y_l + (x_h*y_l + x_l*y_h)*2^32

;Now from the equation you can see that only 3(not 4) multiplication needed.

; movl 16(%ebp), %esi    ; get y_l
; movl 12(%ebp), %eax    ; get x_l
; movl %eax, %edx
; sarl $31, %edx         ; get x_h, (x >>a 31), higher 32 bits of sign-extension of x
; movl 20(%ebp), %ecx    ; get y_h
; imull %eax, %ecx       ; compute s: x_l*y_h
; movl %edx, %ebx
; imull %esi, %ebx       ; compute t: x_h*y_l
; addl %ebx, %ecx        ; compute s + t
; mull %esi              ; compute u: x_l*y_l
; leal (%ecx,%edx), %edx ; u_h += (s + t), result is u
; movl 8(%ebp), %ecx
; movl %eax, (%ecx)
; movl %edx, 4(%ecx)


%endif

