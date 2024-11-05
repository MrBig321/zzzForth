%ifndef __FORTH_ERRORS__
%define __FORTH_ERRORS__


section .data

err_msg0 db		"everything is allright", 0
err_msg1 db 	"no input avaliable", 0
err_msg2 db		"unknown word", 0
err_msg3 db		"word must be compiled", 0
err_msg4 db		"word must be executed", 0
err_msg5 db		"parameter-stack underflow", 0
err_msg6 db		"parameter-stack overflow", 0
err_msg7 db		"return-stack underflow", 0
err_msg8 db		"return-stack overflow", 0
err_msg9 db 	"dictionary-space underflow", 0
err_msg10 db 	"dictionary-space overflow", 0
err_msg11 db 	"primitive not implemented", 0
err_msg12 db 	"it's a core word", 0
%ifdef HASHTABLE_DEF
	err_msg13 db 	"Hash-table: list full", 0
%endif

%ifdef HASHTABLE_DEF
	err_msg_arr	dd err_msg0, err_msg1, err_msg2, err_msg3, err_msg4, err_msg5, err_msg6, err_msg7
			dd err_msg8, err_msg9, err_msg10, err_msg11, err_msg12, err_msg13

	err_msg_abort db 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1
	err_msg_word  db 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0
%else
	err_msg_arr	dd err_msg0, err_msg1, err_msg2, err_msg3, err_msg4, err_msg5, err_msg6, err_msg7
			dd err_msg8, err_msg9, err_msg10, err_msg11, err_msg12

	err_msg_abort db 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1
	err_msg_word  db 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1
%endif

err_msg_aborting db "Aborting ...", 0x0A, 0


%endif

