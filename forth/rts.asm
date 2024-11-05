%ifndef __FORTH_RTS__
%define __FORTH_RTS__


section .data

; names of RT-codes (and e.g. throw). We need to compile their dptoxt-s in colon-defs, so FIND will give them to us.
; we don't have to use FIND at runtime, so it will be faster [NOTE: maybe this was useful only before the Hash-table!]
rtliteraltxt	db 9, "(literal)"			; type, len, chars
rtbranchtxt		db 8, "(branch)"
rtzbranchtxt	db 9, "(0branch)"
rtdotxt			db 4, "(do)"
rtdoestxt		db 6, "(does)"
rtdoes2txt		db 7, "(does2)"
rtdotquotetxt	db 4, '(.")'
rtexittxt		db 6, "(exit)"
rtlooptxt		db 6, "(loop)"
rtplooptxt		db 7, "(+loop)"
rtpostponetxt	db 10, "(postpone)"
rtcolontxt		db 7, "(colon)"
rtcompilectxt	db 10, "(compile,)"
rtsquotetxt		db 4, '(s")'
rtthrowtxt		db 5, "throw"
rtswaptxt		db 4, "swap"
rtduptxt		db 3, "dup"
rtrottxt		db 3, "rot"
rtequalstxt		db 1, "="
rtdroptxt		db 4, "drop"
rtvariabletxt	db 10, "(variable)"
rtoutptxt		db 4, "outp"

rtliteral	dd 0		; dptoxt of (literal)
rtbranch	dd 0
rtzbranch	dd 0
rtdo		dd 0
rtdoes		dd 0
rtdoes2		dd 0
rtdotquote	dd 0
rtexit		dd 0
rtloop		dd 0
rtploop		dd 0
rtpostpone	dd 0
rtcolon		dd 0
rtcompilec	dd 0
rtsquote	dd 0
rtthrow		dd 0
rtswap		dd 0
rtdup		dd 0
rtrot		dd 0
rtequals	dd 0
rtdrop		dd 0
rtvariable	dd 0
rtoutp		dd 0


%endif

