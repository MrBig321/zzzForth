;************************
; GRAPHICS
;************************

%ifndef __FORTH_GRAPHICS__
%define __FORTH_GRAPHICS__


%include "gstdio.asm"


section .text

; ********* CHARACTER RELATED **********
; Related to "Drawing chars on character positions"

;*********************************************
; _os_pars_off					OSPARSOFF
;	( -- )
;	sets skipRecording and skipTxtBuff
;	Useful e.g. in case of LIST, where 
;	we don't need recording and writing to txtbuff
;	There is recording in gstdio: the output of a word gets recorded 
;	and can be viewed with OUTP. We can skip that here.
;	Writing to txtbuff in gstdio is useful if we return to 
;	main-screen from e.g. LIST: we restore what was on the screen 
;	prior to executing LIST from txtbuff.
;*********************************************
_os_pars_off:
			call gstdio_os_pars_off
			ret


;*********************************************
; _os_pars_on					OSPARSON
;	( -- )
;	Restores skipRecording and skipTxtBuff
;	See OSPARSOFF
;*********************************************
_os_pars_on:
			call gstdio_os_pars_on
			ret


;*********************************************
; _scroll_off					SCROLLOFF
;	( -- )
;	sets skipScroll 
;	Useful e.g. in case of LIST, where 
;	we don't need scrolling when we reach the 
;	bottom right corner of the block 
;*********************************************
_scroll_off:
			call gstdio_scroll_off
			ret


;*********************************************
; _scroll_on					SCROLLON
;	( -- )
;	restores skipScroll 
;	See SCROLLOFF
;*********************************************
_scroll_on:
			call gstdio_scroll_on
			ret


;*********************************************
; _to_main_scr					>MSCR
;	( -- )
;	We need to call this function at the end of our word, 
;	if we called MSCR>
;	Restores screen-related variables, but not corsor's position
;*********************************************
_to_main_scr:
			call gstdio_to_main_scr
			ret


;*********************************************
; _from_main_scr				MSCR>
; ( colbeg rowbeg colcnt rowcnt -- )  
;	Sometimes we create a word that uses only a 
;	part of the screen (a rectangle). For example LIST has a frame, 
;	where we display what the keys do.
;	With MSCR> we can set the size and position of 
;	the active rectangle. 
;	So, MSCR> sets these things but does't save cursor's position
;*********************************************
_from_main_scr:
			POP_PS(eax)
			mov [gstdio_row_cnt], al
			POP_PS(eax)
			mov [gstdio_col_cnt], al
			POP_PS(eax)
			mov [gstdio_row_beg], al
			POP_PS(eax)
			mov [gstdio_col_beg], al
			call gstdio_from_main_scr
			ret


;*********************************************
; _tmp_to_main_scr				>TMSCR
;	( -- )
;	Temporarily (T) switch back to the main-screen.
;	If e.g. we are in the editor (i.e. LIST) 
;	then we need to change text or numbers 
;	on the frame of the screen 
;	Example: "Updated/NotUpdated", blocknum
;	>TMSCR modifies the screen-related variables 
;	in order to be able to write on the whole screen. 
;	Before changing the variables, it saves them,  
;	so TMSCR> will be able to restore the 
;	original values.
;	Saves cursor's position
;	Note that we could use >MSCR too, but that 
;	computes many things
;*********************************************
_tmp_to_main_scr:
			call gstdio_tmp_to_main_scr
			ret


;*********************************************
; _tmp_from_main_scr			TMSCR>
;	( -- )
;	If e.g. we are in the editor (i.e. LIST) 
;	then we need to change text or numbers 
;	on the frame of the screen 
;	Example: "Updated/NotUpdated", blocknum
;	TMSCR> will restore every variables that 
;	>TMSCR changed. 
;	Restores cursor's position
;*********************************************
_tmp_from_main_scr:
			call gstdio_tmp_from_main_scr
			ret


;*********************************************
; _put_cur					PUTCUR
;	( c -- )
;	Shows cursor
;	c is char under cursor
;*********************************************
_put_cur:
			POP_PS(ebx)
			call gstdio_put_cursor
			ret


;*********************************************
; _rem_cur					REMCUR
;	( c -- )
;	Removes cursor
;	c is char under cursor
;*********************************************
_rem_cur:
			POP_PS(ebx)
			call gstdio_remove_cursor
			ret

; ********* End of CHARACTER RELATED **********


;*************************************************
; _invscr			INVSCR
;	(  -- )
; Invalidates screen, i.e. copies the screen buffer 
; to the framebuffer, so it will appear on the screen.
; Should be called after every graphical routines (pixel, line, circle, etc.)
;*************************************************
_invscr:
			call gstdio_invalidate
			ret


;*************************************************
; _invscr_rect			INVSCRRECT
;	( x, y, w, h -- )
; Invalidates the given rect of the screen, 
; i.e. copies the part screen buffer to the framebuffer, 
; so it will appear on the screen.
; Should be called after every graphical routines (pixel, line, circle)
;*************************************************
_invscr_rect:
			POP_PS(edx)
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			call gstdio_invalidate_rect
			ret


; ********* Graphics RELATED **********
; Related to drawing chars on pixel positions and drawing shapes 
; in memory other than SCRBUFF (useful in case of e.g. scrolling a text)

;*************************************************
; _to_gmem				>GMEM
;	( MemAddr MemRectWidth MemRectHeight -- )
; If we want to draw to e.g. a 160*240 pixels rect 
; in memory other than SCRBUFF, we need to call this
; word. E.g. it sets skipping copying of chars to framebuffer.
; This is useful in case of e.g. implementing a 
; scrolling feature: writing a text to a 
; e.g. 160*240 rect im memory, and then copy its rows 
; to framebuffer, then cal lINVSCR or INVSCRRECT 
; to have scrolling.
; We can use e.g. EMIT or ." to write text 
; into this rect on pixel positions, we can also draw 
; shapes into this rect.
; GMEM> restores original values/settings
;*************************************************
_to_gmem:
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			call gstdio_to_gmem
			ret


;*************************************************
; _from_gmem			GMEM>
;	( -- )
;*************************************************
_from_gmem:
			call gstdio_from_gmem
			ret


section .data


%endif


