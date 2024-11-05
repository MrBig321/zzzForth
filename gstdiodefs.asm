%ifndef __GSTDIODEFS__
%define __GSTDIODEFS__


%define GSTDIO_COLS_NUM	64
%define GSTDIO_ROWS_NUM	32

%define GSTDIO_TAB_SIZE	1	;4

;The New Way:
; define NORMAL_RES in defs.asm to have 1024*768*16
; the appropriate font needs to be in gfont.inc (note that the backslash-symbol in the font-file needs to be in a "" !!)

;The old Way:
;To switch between 1024*768*16(font:16*24) and 640*480*16(font: 10*15):
;	- the appropriate font needs to be in gfont.inc (note that the backslash-symbol in the font-file needs to be in a "" !!)
;	- in loader.asm(pendrive or floppy) see "call vga_switch_to_mode" (VGA_NORMAL_RES, VGA_SMALLRES)
;	- in hdloader.asm(pendrive or floppy) see "call vga_switch_to_mode" (VGA_NORMAL_RES, VGA_SMALLRES)
;	- in vga.asm see VGA_NORMALRES... and VGA_SMALLRES...
;	- here in this file activate or deactivate the defines below
%ifdef NORMALRES_DEF
	%define GSTDIO_NORMAL_FONT
	%define GSTDIO_CHAR_WIDTH	16
	%define GSTDIO_CHAR_HEIGHT	24
	%define GSTDIO_XRES	1024
	%define GSTDIO_YRES	768
%else
	%define GSTDIO_CHAR_WIDTH	10
	%define GSTDIO_CHAR_HEIGHT	15
	%define GSTDIO_XRES	640
	%define GSTDIO_YRES	480
%endif

%define GSTDIO_SCREEN_BYTES	(GSTDIO_XRES*GSTDIO_YRES*2)
%define GSTDIO_ROW_BYTES	(GSTDIO_XRES*GSTDIO_CHAR_HEIGHT*2)
%define GSTDIO_ROW_BYTE_NUM	(GSTDIO_XRES*2)

%define GSTDIO_BKGCLR	0x0000		; black
%define GSTDIO_FGCLR	0x07E0		; green
%define GSTDIO_CHBKGCLR	0xF800		; red
%define GSTDIO_CURRCLR	0xFFE0		; yellow

%define GSTDIO_SCRBUFF		(TIB+0x1000) ; copy to FRAMEBUFF from here
%define GSTDIO_TXTBUFF		(GSTDIO_SCRBUFF+0x180000)	 ; text buffer (saved chars of the screen; for example when we exit from LIST, we will use this buff)
%define GSTDIO_OUTPBUFF		(GSTDIO_TXTBUFF+0x800)	; text buffer (output of the last word; must be 64-byte aligned (0xFFFFFFC0)) 
%define GSTDIO_OUTPBUFF_SCRS	20 
%define GSTDIO_OUTPBUFF_LEN		64*32*(GSTDIO_OUTPBUFF_SCRS)


%endif

