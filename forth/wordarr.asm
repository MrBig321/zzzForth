%ifndef __WORDARR__
%define __WORDARR__


%include "defs.asm"


 ; WORD-list
;descriptor-name  dd func-addr name(with 0 at the end) flags (length is missing and will be calculated)
; CORE words

abort_	dd _abort
		db "abort", 0, 0
abort_quote_	dd _abort_quote
				db 'abort"', 0, COMP_ONLY+IMMEDIATE
abs_	dd _abs
		db "abs", 0, 0
accept_	dd _accept
		db "accept", 0, 0
again_	dd _again												; CORE-EXT
		db "again", 0, COMP_ONLY+IMMEDIATE
ahead_	dd _ahead												; TOOLS-EXT
		db "ahead", 0, COMP_ONLY+IMMEDIATE
align_	dd _align
		db "align", 0, 0
aligned_	dd _aligned
			db "aligned", 0, 0
allot_	dd _allot
		db "allot", 0, 0
and_	dd _and
		db "and", 0, 0
at_x_y_	dd _at_x_y												; FACILITY
		db "at-xy", 0, 0
get_x_y_	dd _get_x_y											; FACILITY
		db "get-xy", 0, 0
b_l_	dd _b_l
		db "bl", 0, 0
begin_	dd _begin
		db "begin", 0, COMP_ONLY+IMMEDIATE
block_	dd _block
		db "block", 0, 0										; BLOCK
blank_	dd _blank
		db "blank", 0, 0										; STRING
bracket_char_	dd _bracket_char
				db "[char]", 0, COMP_ONLY+IMMEDIATE
bracket_tick_	dd _bracket_tick
				db "[']", 0, COMP_ONLY+IMMEDIATE
bswap2_	dd _bswap2
		db "bswap2", 0, 0 
bswap4_	dd _bswap4
		db "bswap4", 0, 0 
c_fetch_	dd _c_fetch
			db "c@", 0, 0
c_comma_	dd _c_comma
			db "c,", 0, 0
c_move_		dd _c_move											; STRING
			db "cmove", 0, 0
c_move_up_	dd _c_move_up										; STRING
			db "cmove>", 0, 0
c_plus_store_	dd _c_plus_store
				db "c+!", 0, 0
c_r_	dd _c_r
		db "cr", 0, 0
c_store_	dd _c_store
			db "c!", 0, 0
case_	dd _case
		db "case", 0, COMP_ONLY+IMMEDIATE
cell_plus_	dd _cell_plus
			db "cell+", 0, 0
cells_	dd _cells
		db "cells", 0, 0
char_	dd _char
		db "char", 0, 0
char_plus_	dd _char_plus
			db "char+", 0, 0
chars_	dd _chars
		db "chars", 0, 0
chksys_	dd _chk_sys
		db "chksys", 0, 0
colon_	dd _colon
		db ":", 0, EXEC_ONLY
comma_	dd _comma
		db ",", 0, 0
comp_only_	dd _comp_only
		db "componly", 0, 0
compare_	dd _compare											; STRING
			db "compare", 0, 0
compile_comma_	dd _compile_comma								; CORE-EXT
				db "compile,", 0, COMP_ONLY
constant_	dd _constant
			db "constant", 0, EXEC_ONLY
count_	dd _count
		db "count", 0, 0
create_		dd _create
			db "create", 0, 0
dash_trailing_	dd _dash_trailing								; STRING
				db "-trailing", 0, 0
date_	dd _date
		db "date", 0, 0
decimal_	dd _decimal
		db "decimal", 0, 0
depth_	dd _depth
		db "depth", 0, 0
discard_	dd _discard
			db "discard", 0, 0
do_	dd _do
	db "do", 0, COMP_ONLY+IMMEDIATE
does_	dd _does
		db "does>", 0, COMP_ONLY+IMMEDIATE
dot_	dd _dot
		db ".", 0, 0
dot_paren_	dd _dot_paren										; CORE-EXT
			db ".(", 0, IMMEDIATE
dot_quote_	dd _dot_quote
			db '."', 0, COMP_ONLY+IMMEDIATE
dot_r_	dd _dot_r
		db ".r", 0, 0
dot_s_	dd _dot_s												; TOOLS
		db ".s", 0, 0
dpw_	dd _dpw	
		db "dpw", 0, 0
drop_	dd _drop
		db "drop", 0, 0
dump_	dd _dump												; TOOLS
		db "dump", 0, 0
dup_	dd _dup
		db "dup", 0, 0
else_	dd _else
		db "else", 0, COMP_ONLY+IMMEDIATE
emit_	dd _emit
		db "emit", 0, 0
end_of_	dd _end_of
		db "endof", 0, COMP_ONLY+IMMEDIATE
end_case_	dd _end_case
			db "endcase", 0, COMP_ONLY+IMMEDIATE
equals_	dd _equals
		db "=", 0, 0
erase_	dd _erase
		db "erase", 0, 0
evaluate_	dd _evaluate
			db "evaluate", 0, 0
exec_only_	dd _exec_only										; CORE-EXT
		db "execonly", 0, 0
execute_	dd _execute
			db "execute", 0, 0
exit_	dd _exit
		db "exit", 0, COMP_ONLY+IMMEDIATE
fact_	dd _fact
		db "fact", 0, 0
false_	dd _false												; CORE-EXT
		db "false", 0, 0
fetch_	dd _fetch
		db "@", 0, 0
fill_	dd _fill
		db "fill", 0, 0
fill_w_	dd _fill_w
		db "fillw", 0, 0
find_	dd _find
		db "find", 0, 0
forget_	dd _forget
		db "forget", 0, EXEC_ONLY
greater_than_	dd _greater_than
				db ">", 0, 0
greater_or_equal_than_	dd _greater_or_equal_than
				db ">=", 0, 0
here_	dd _here
		db "here", 0, 0
hex_	dd _hex
		db "hex", 0, 0
hold_	dd _hold
		db "hold", 0, 0
i_	dd _i
	db "i", 0, COMP_ONLY
if_	dd _if
	db "if", 0, COMP_ONLY+IMMEDIATE
immediate_	dd _immediate
	db "immediate", 0, 0
interpret_	dd _interpret
			db "interpret", 0, 0
invert_	dd _invert
		db "invert", 0, 0
j_	dd _j
	db "j", 0, COMP_ONLY
key_	dd _key
		db "key", 0, 0
keyw_	dd _keyw
		db "keyw", 0, 0
leave_	dd _leave
		db "leave", 0, COMP_ONLY
left_bracket_	dd _left_bracket
				db "[", 0, COMP_ONLY+IMMEDIATE
less_number_sign_	dd _less_number_sign
					db "<#", 0, 0
less_than_	dd _less_than
			db "<", 0, 0
less_or_equal_than_	dd _less_or_equal_than
			db "<=", 0, 0
literal_	dd _literal
			db "literal", 0, COMP_ONLY+IMMEDIATE
loadm_		dd _loadm
			db "loadm", 0, EXEC_ONLY
loop_	dd _loop
		db "loop", 0, COMP_ONLY+IMMEDIATE
l_shift_	dd _l_shift
			db "lshift", 0, 0
max_	dd _max
		db "max", 0, 0
min_	dd _min
		db "min", 0, 0
minus_	dd _minus
		db "-", 0, 0
mod_	dd _mod
		db "mod", 0, 0
move_	dd _move
		db "move", 0, 0
move_w_	dd _move_w
		db "movew", 0, 0
negate_	dd _negate
		db "negate", 0, 0
nip_	dd _nip													; CORE-EXT
		db "nip", 0, 0
not_equals_	dd _not_equals										; CORE-EXT
			db "<>", 0, 0
number_sign_	dd _number_sign
				db "#", 0, 0
number_sign_greater_	dd _number_sign_greater
						db "#>", 0, 0
number_sign_s_	dd _number_sign_s
				db "#s", 0, 0
of_	dd _of
	db "of", 0, COMP_ONLY+IMMEDIATE
one_plus_	dd _one_plus
			db "1+", 0, 0
one_minus_	dd _one_minus
			db "1-", 0, 0
or_	dd _or
	db "or", 0, 0
over_	dd _over
		db "over", 0, 0
page_	dd _page												; FACILITY
		db "page", 0, 0
page_n	dd _page_n												; FACILITY
		db "pagen", 0, 0
paren_	dd _paren
		db "(", 0, IMMEDIATE
paren_branch_paren_	dd _paren_branch_paren
					db "(branch)", 0, 0
paren_colon_paren_	dd _paren_colon_paren
						db "(colon)", 0, 0
paren_compile_comma_paren_	dd _paren_compile_comma_paren
							db "(compile,)", 0, 0
paren_constant_paren_	dd _paren_constant_paren
						db "(constant)", 0, 0
paren_create_paren_	dd _paren_create_paren
						db "(create)", 0, 0
paren_do_paren_	dd _paren_do_paren
				db "(do)", 0, 0
paren_does_paren_	dd _paren_does_paren
					db "(does)", 0, 0
paren_does2_paren_	dd _paren_does2_paren
					db "(does2)", 0, 0
paren_dot_quote_paren_	dd _paren_dot_quote_paren
						db '(.")', 0, 0
paren_exit_paren_	dd _paren_exit_paren
					db "(exit)", 0, 0
paren_literal_paren_	dd _paren_literal_paren
						db "(literal)", 0, 0
paren_loop_paren_	dd _paren_loop_paren
					db "(loop)", 0, 0
paren_plus_loop_paren_	dd _paren_plus_loop_paren
					db "(+loop)", 0, 0
paren_postpone_paren_	dd _paren_postpone_paren
					db "(postpone)", 0, 0
paren_s_quote_paren_	dd _paren_s_quote_paren
						db '(s")', 0, 0
paren_system_paren_	dd _paren_system_paren
					db "(system)", 0, 0
paren_system_const_paren_	dd _paren_system_const_paren
							db "(systemconst)", 0, 0
paren_variable_paren_	dd _paren_variable_paren
					db "(variable)", 0, 0
paren_zero_branch_paren_	dd _paren_zero_branch_paren
							db "(0branch)", 0, 0
parse_	dd _parse												; CORE-EXT
		db "parse", 0, 0
pick_	dd _pick												; CORE-EXT
		db "pick", 0, 0
plus_	dd _plus
		db "+", 0, 0
plus_loop_	dd _plus_loop
			db "+loop", 0, COMP_ONLY+IMMEDIATE
plus_store_	dd _plus_store
			db "+!", 0, 0
postpone_	dd _postpone
			db "postpone", 0, COMP_ONLY+IMMEDIATE
pow_	dd _pow
		db "pow", 0, 0
question_	dd _question										; TOOLS
			db "?", 0, 0
question_dup_	dd _question_dup
				db "?dup", 0, 0
quit_	dd _quit
		db "quit", 0, 0
r_from_	dd _r_from
		db "r>", 0, COMP_ONLY
r_fetch_	dd _r_fetch
			db "r@", 0, COMP_ONLY
ram_map_	dd _ram_map
			db "rammap", 0, 0
read_const_	dd _read_const
			db "readconst", 0, 0
reboot_	dd _reboot
			db "reboot", 0, EXEC_ONLY
recurse_	dd _recurse
			db "recurse", 0, COMP_ONLY+IMMEDIATE
refill_	dd _refill
		db "refill", 0, 0
repeat_	dd _repeat
		db "repeat", 0, COMP_ONLY+IMMEDIATE
restore_input_	dd _restore_input								; CORE-EXT
				db "restore-input", 0, 0
right_bracket_	dd _right_bracket
				db "]", 0, 0
roll_	dd _roll												; CORE-EXT
		db "roll", 0, 0
rot_	dd _rot
		db "rot", 0, 0
r_shift_	dd _r_shift
			db "rshift", 0, 0
s_literal_	dd _s_literal										; STRING
			db "sliteral", 0, COMP_ONLY+IMMEDIATE
s_quote_	dd _s_quote
			db 's"', 0, IMMEDIATE
save_input_	dd _save_input										; CORE-EXT
			db "save-input", 0, 0
search_	dd _search												; STRING
		db "search", 0, 0
see_	dd _see													; TOOLS
		db "see", 0, EXEC_ONLY
semi_colon_	dd _semi_colon
			db ";", 0, COMP_ONLY+IMMEDIATE
sign_	dd _sign
		db "sign", 0, 0
slash_	dd _slash
		db "/", 0, 0
slash_mod_	dd _slash_mod
			db "/mod", 0, 0
slash_string_	dd _slash_string								; STRING
			db "/string", 0, 0
sleep_	dd _sleep
		db "sleep", 0, 0
source_	dd _source
		db "source", 0, 0
sp_fetch_	dd _sp_fetch
			db "sp@", 0, 0 ; USER variable
space_	dd _space
		db "space", 0, 0
spaces_	dd _spaces
		db "spaces", 0, 0
star_	dd _star
		db "*", 0, 0
;star_slash_	dd _star_slash
;			db "*/", 0, 0
;star_slash_mod_	dd _star_slash_mod
;				db "*/mod", 0, 0
store_	dd _store
		db "!", 0, 0
swap_	dd _swap
		db "swap", 0, 0
then_	dd _then
		db "then", 0, COMP_ONLY+IMMEDIATE
throw_	dd _throw
		db "throw", 0, 0
tick_	dd _tick
		db "'", 0, 0
time_	dd _time
		db "time", 0, 0
to_body_	dd _to_body
			db ">body", 0, 0
to_link_	dd _to_link
			db ">link", 0, 0
to_number_	dd _to_number
			db ">number", 0, 0
to_r_	dd _to_r
		db ">r", 0, COMP_ONLY
true_	dd _true												; CORE-EXT
		db "true", 0, 0
tuck_	dd _tuck												; CORE-EXT
		db "tuck", 0, 0
type_	dd _type
		db "type", 0, 0
two_plus_	dd _two_plus
			db "2+", 0, 0
two_minus_	dd _two_minus
			db "2-", 0, 0
two_slash_	dd _two_slash
			db "2/", 0, 0
two_star_	dd _two_star
			db "2*", 0, 0
u_dot_	dd _u_dot
		db "u.", 0, 0
u_dot_r_	dd _u_dot_r
			db "u.r", 0, 0
u_greater_or_equal_than_	dd _u_greater_or_equal_than
							db "u>=", 0, 0
u_greater_than_	dd _u_greater_than
				db "u>", 0, 0
u_less_than_	dd _u_less_than
				db "u<", 0, 0
u_less_or_equal_than_	dd _u_less_or_equal_than
						db "u<=", 0, 0
u_star_	dd _u_star
		db "u*", 0, 0
unloop_	dd _unloop
		db "unloop", 0, COMP_ONLY
until_	dd _until
		db "until", 0, COMP_ONLY+IMMEDIATE
unused_	dd _unused												; CORE-EXT
		db "unused", 0, 0
variable_	dd _variable
			db "variable", 0, EXEC_ONLY
view_err_	dd _view_err
			db "viewerr", 0, 0	
w_comma_    dd _w_comma 
			db "w,", 0, 0
w_fetch_    dd _w_fetch 
			db "w@", 0, 0
w_plus_store_	dd _w_plus_store 
				db "w+!", 0, 0
w_store_	dd _w_store 
			db "w!", 0, 0
while_	dd _while
		db "while", 0, COMP_ONLY+IMMEDIATE
within_	dd _within												; CORE-EXT
		db "within", 0, 0
word_	dd _word
		db "word", 0, 0
words_	dd _words												; TOOLS
		db "words", 0, 0
words_question_	dd _words_question								; TOOLS MINE
				db "words?", 0, 0
xor_	dd _xor
		db "xor", 0, 0
zero_equals_	dd _zero_equals	
				db "0=", 0, 0
zero_greater_	dd _zero_greater								; CORE-EXT
					db "0>", 0, 0
zero_less_	dd _zero_less
			db "0<", 0, 0
zero_not_equals_	dd _zero_not_equals							; CORE-EXT
					db "0<>", 0, 0

; DOUBLE
two_constant_	dd _two_constant
				db "2constant", 0, EXEC_ONLY
paren_two_constant_paren_ dd _paren_two_constant_paren
						   db "(2constant)", 0, 0
two_literal_	dd _two_literal
				db "2literal", 0, COMP_ONLY+IMMEDIATE
two_variable_	dd _two_variable
				db "2variable", 0, EXEC_ONLY
d_plus_			dd _d_plus
				db "d+", 0, 0
d_minus_		dd _d_minus
				db "d-", 0, 0
d_dot_			dd _d_dot
				db "d.", 0, 0
d_dot_r_		dd _d_dot_r
				db "d.r", 0, 0
d_zero_less_	dd _d_zero_less
				db "d0<", 0, 0
d_zero_equals_	dd _d_zero_equals
				db "d0=", 0, 0
d_two_star_		dd _d_two_star
				db "d2*", 0, 0
d_two_slash_	dd _d_two_slash
				db "d2/", 0, 0
d_less_than_	dd _d_less_than
				db "d<", 0, 0
d_u_less_		dd _d_u_less				; DOUBLE EXT
				db "du<", 0, 0
d_equals_		dd _d_equals
				db "d=", 0, 0
d_abs_			dd _d_abs
				db "dabs", 0, 0
d_max_			dd _d_max
				db "dmax", 0, 0
d_min_			dd _d_min
				db "dmin", 0, 0
d_negate_		dd _d_negate
				db "dnegate", 0, 0
star_slash_		dd _star_slash				; CORE
				db "*/", 0, 0
star_slash_mod_	dd _star_slash_mod			; CORE
				db "*/mod", 0, 0
m_star_slash_	dd _m_star_slash
				db "m*/", 0, 0
m_star_			dd _m_star					; CORE
				db "m*", 0, 0
u_m_star_		dd _u_m_star				; CORE
				db "um*", 0, 0
u_m_slash_mod_	dd _u_m_slash_mod			; CORE
				db "um/mod", 0, 0
f_m_slash_mod_  dd _f_m_slash_mod			; CORE
				db "fm/mod", 0, 0
s_m_slash_rem_	dd _s_m_slash_rem			; CORE
				db "sm/rem", 0, 0
s_to_d_			dd _s_to_d					; CORE
				db "s>d", 0, 0
d_to_s_			dd _d_to_s
				db "d>s", 0, 0
m_plus_			dd _m_plus
				db "m+", 0, 0
two_store_		dd _two_store				; CORE
				db "2!", 0, 0
two_fetch_		dd _two_fetch				; CORE
				db "2@", 0, 0
two_drop_		dd _two_drop				; CORE
				db "2drop", 0, 0
two_dup_		dd _two_dup					; CORE
				db "2dup", 0, 0
two_over_		dd _two_over				; CORE
				db "2over", 0, 0
two_swap_		dd _two_swap				; CORE
				db "2swap", 0, 0
two_rot_		dd _two_rot					; DOUBLE EXT
				db "2rot", 0, 0
two_to_r_		dd _two_to_r				; CORE EXT
				db "2>r", 0, COMP_ONLY
two_r_from_		dd _two_r_from				; CORE EXT
				db "2r>", 0, COMP_ONLY
two_r_fetch_	dd _two_r_fetch				; CORE EXT
				db "2r@", 0, COMP_ONLY

; Graphics
invscr_	dd _invscr
		db "invscr", 0, 0
invscr_rect_	dd _invscr_rect
				db "invscrrect", 0, 0
put_cur_	dd _put_cur
			db "putcur", 0, 0
rem_cur_	dd _rem_cur
			db "remcur", 0, 0
to_gmem_	dd _to_gmem
			db ">gmem", 0, 0
from_gmem_	dd _from_gmem
			db "gmem>", 0, 0

%ifdef HARDDISK_DEF
; Hard Drive
	hd_info_	dd _hd_info
				db "hdinfo", 0, 0
	hd_read_	dd _hd_read
				db "hdread", 0, 0
%ifdef MULTITASKING_DEF
	hd_read_dma_	dd _hd_read_dma
					db "hdreaddma", 0, 0
	hd_write_dma_	dd _hd_write_dma
					db "hdwritedma", 0, 0
%endif
	hd_write_	dd _hd_write
				db "hdwrite", 0, 0
%ifdef HDINSTALL_DEF
	hd_install_	dd _hd_install
				db "hdinstall", 0, 0
%endif
%endif
; PCI
pci_ls_		dd _pci_ls
			db "pcils", 0, 0
pci_cfg_	dd _pci_cfg
			db "pcicfg", 0, 0
pci_det_usb_	dd _pci_det_usb
				db "pcidetusb", 0, 0
pci_config_read_dword_	dd _pci_config_read_dword
						db "pcicfgrdd", 0, 0
pci_config_read_word_	dd _pci_config_read_word
						db "pcicfgrdw", 0, 0
pci_config_read_byte_	dd _pci_config_read_byte
						db "pcicfgrdb", 0, 0
pci_config_write_dword_	dd _pci_config_write_dword
						db "pcicfgwrd", 0, 0
pci_config_write_word_	dd _pci_config_write_word
						db "pcicfgwrw", 0, 0
pci_config_write_byte_	dd _pci_config_write_byte
						db "pcicfgwrb", 0, 0

%ifdef USB_DEF
; USB
	usb_devinfo_	dd _usb_devinfo
					db "usbdevinfo", 0, 0
	usb_ehci_	dd _usb_ehci
				db "usbehci", 0, 0
	usb_xhci_	dd _usb_xhci
				db "usbxhci", 0, 0
	usb_driver_	dd _usb_driver
					db "usbdriver", 0, 0
	usb_enum_	dd _usb_enum
				db "usbenum", 0, 0
	usb_read_	dd _usb_read
				db "usbread", 0, 0
	usb_write_	dd _usb_write
				db "usbwrite", 0, 0
	usb_init_msd_	dd _usb_init_msd
					db "usbinitmsd", 0, 0
	usb_fsinit_	dd _usb_fs_init
				db "usbfsinit", 0, 0
	usb_fsinfo_	dd _usb_fs_info
				db "usbfsinfo", 0, 0
	usb_fsinfo_upd_	dd _usb_fs_info_upd
					db "usbfsinfoupd", 0, 0
	usb_fsls_	dd _usb_fs_ls
				db "usbfsls", 0, 0
	usb_fscd_	dd _usb_fs_cd
				db "usbfscd", 0, 0
	usb_fspwd_	dd _usb_fs_pwd
				db "usbfspwd", 0, 0
	usb_fsread_	dd _usb_fs_read
				db "usbfsread", 0, 0
	usb_fswrite_	dd _usb_fs_write
					db "usbfswrite", 0, 0
	usb_fsrem_	dd _usb_fs_rem
				db "usbfsrem", 0, 0
%endif

%ifdef AUDIO_DEF
; Audio
	audio_get_supported_format_ dd _audio_get_supported_format
								db "augetsuppfmt", 0, 0
	audio_print_format_ dd _audio_print_format
						db "auprintfmt", 0, 0
	audio_init_	dd _audio_init
				db "auinit", 0, 0
	audio_info_	dd _audio_info
				db "auinfo", 0, 0
	audio_codecs_info_	dd _audio_codecs_info
						db "aucodecsinfo", 0, 0
	audio_play_	dd _audio_play
				db "auplay", 0, 0
	audio_stop_	dd _audio_stop
				db "austop", 0, 0
	audio_setvol_	dd _audio_setvol
					db "ausetvol", 0, 0
	audio_getvol_	dd _audio_getvol
					db "augetvol", 0, 0
	audio_pause_	dd _audio_pause
					db "aupause", 0, 0
	audio_resume_	dd _audio_resume
					db "auresume", 0, 0
	audio_wav_	dd _audio_wav
				db "auwav", 0, 0
%endif

%ifdef MULTITASKING_DEF
	user_	dd _user
			db "user", 0, EXEC_ONLY
	incuser_	dd _incuser
				db "incuser", 0, 0
	paren_user_paren_	dd _paren_user_paren
						db "(user)", 0, 0
; Multitasking
	activate_	dd _activate
				db "activate", 0, COMP_ONLY
	gettbuff_	dd _gettbuff	
				db "gettbuff", 0, 0
	kill_	dd _kill
			db "kill", 0, 0
	pause_	dd _pause	
			db "pause", 0, 0
	resume_	dd _resume
			db "resume", 0, 0
	suspend_	dd _suspend
				db "suspend", 0, 0
	task_	dd _task
			db "task", 0, EXEC_ONLY
	tasks_	dd _tasks
			db "tasks", 0, EXEC_ONLY
	task_clear_counter_	dd _task_clear_counter
						db "taskclrcnt", 0, EXEC_ONLY
	terminate_	dd _terminate
				db "terminate", 0, COMP_ONLY
%endif

; Special words (OS-related, not hardware)
outp_		dd _outp
			db "outp", 0, EXEC_ONLY
txt_view_	dd _txt_view
			db "txtvw", 0, 0
os_pars_off_	dd _os_pars_off
				db "osparsoff", 0, 0
os_pars_on_	dd _os_pars_on
			db "osparson", 0, 0
scroll_off_	dd _scroll_off
			db "scrolloff", 0, 0
scroll_on_	dd _scroll_on
			db "scrollon", 0, 0
to_main_scr_	dd _to_main_scr
				db ">mscr", 0, 0
from_main_scr_	dd _from_main_scr
				db "mscr>", 0, 0
tmp_to_main_scr_	dd _tmp_to_main_scr
					db ">tmscr", 0, 0
tmp_from_main_scr_	dd _tmp_from_main_scr
					db "tmscr>", 0, 0

; Extra keys (keyboard)
key_ctrl_question_	dd _key_ctrl_question
					db "kctrl?", 0, 0
key_shift_question_	dd _key_shift_question
					db "kshift?", 0, 0
key_alt_question_	dd _key_alt_question
					db "kalt?", 0, 0
key_scroll_lock_question_	dd _key_scroll_lock_question
							db "kscroll?", 0, 0
key_caps_lock_question_	dd _key_caps_lock_question
						db "kcaps?", 0, 0

word_arr	dd abort_, abort_quote_, abs_, accept_, again_, ahead_, align_, aligned_, allot_, and_, at_x_y_, get_x_y_
			dd b_l_, begin_, block_, blank_, bracket_char_, bracket_tick_, bswap2_, bswap4_
			dd c_fetch_, c_comma_, c_move_, c_move_up_, c_plus_store_, c_r_, c_store_, case_, cell_plus_, cells_, char_, char_plus_, chars_ 
			dd chksys_, colon_, comma_, comp_only_, compare_, compile_comma_, constant_, count_, create_
			dd dash_trailing_, date_, decimal_, depth_, discard_, do_, does_, dot_, dot_paren_, dot_quote_, dot_r_, dot_s_, dpw_ 
			dd drop_, dump_, dup_, else_, emit_, end_of_, end_case_, equals_, erase_, evaluate_, exec_only_, execute_, exit_
			dd fact_, false_, fetch_, fill_, fill_w_, find_, forget_, greater_than_, greater_or_equal_than_, here_, hex_, hold_
			dd i_, if_, immediate_, interpret_, invert_
			dd j_, key_, keyw_, leave_, left_bracket_, less_number_sign_, less_than_, less_or_equal_than_, literal_, loadm_, loop_, l_shift_
			dd max_, min_, minus_, mod_, move_, move_w_
			dd negate_, nip_, not_equals_, number_sign_, number_sign_greater_, number_sign_s_, of_
			dd one_plus_, one_minus_, or_, over_, page_, page_n
			dd paren_, paren_branch_paren_, paren_colon_paren_, paren_compile_comma_paren_, paren_constant_paren_, paren_create_paren_
			dd paren_do_paren_, paren_does_paren_, paren_does2_paren_, paren_dot_quote_paren_, paren_exit_paren_, paren_literal_paren_
			dd paren_loop_paren_, paren_plus_loop_paren_, paren_postpone_paren_, paren_s_quote_paren_
			dd paren_system_paren_, paren_system_const_paren_
			dd paren_variable_paren_, paren_zero_branch_paren_
			dd parse_, pick_, plus_, plus_loop_, plus_store_, postpone_, pow_
			dd question_, question_dup_, quit_
			dd r_from_, r_fetch_, ram_map_, read_const_, reboot_, recurse_, refill_, repeat_, restore_input_, right_bracket_, roll_, rot_
			dd r_shift_, s_literal_, s_quote_, save_input_, search_, see_, semi_colon_, sign_, slash_, slash_mod_, slash_string_, sleep_ 
			dd source_ , sp_fetch_, space_, spaces_, star_, star_slash_, star_slash_mod_, store_, swap_ 
			dd then_, throw_, tick_, time_, to_body_, to_link_, to_number_, to_r_, true_, tuck_, type_, two_plus_, two_minus_ 
			dd two_slash_, two_star_, u_dot_, u_dot_r_, u_greater_or_equal_than_, u_greater_than_, u_less_than_, u_less_or_equal_than_
			dd u_star_, unloop_, until_, unused_
			dd variable_, view_err_, w_comma_, w_fetch_, w_plus_store_, w_store_
			dd while_, within_, word_, words_, words_question_
			dd xor_, zero_equals_, zero_greater_, zero_less_, zero_not_equals_

			; DOUBLE
			dd two_constant_, paren_two_constant_paren_, two_literal_, two_variable_, d_plus_, d_minus_, d_dot_, d_dot_r_
			dd d_zero_less_, d_zero_equals_, d_two_star_, d_two_slash_, d_less_than_, d_u_less_, d_equals_, d_abs_, d_max_, d_min_
			dd d_negate_, star_slash_, star_slash_mod_, m_star_slash_, m_star_, u_m_star_, u_m_slash_mod_, f_m_slash_mod_, s_m_slash_rem_
			dd s_to_d_, d_to_s_, m_plus_
			dd two_store_, two_fetch_, two_drop_, two_dup_, two_over_, two_swap_, two_rot_, two_to_r_, two_r_from_, two_r_fetch_

			; Graphics
			dd invscr_, invscr_rect_, put_cur_, rem_cur_, to_gmem_, from_gmem_

%ifdef HARDDISK_DEF
			; Hard Disk
			dd hd_info_, hd_read_, hd_write_
	%ifdef MULTITASKING_DEF
			dd hd_read_dma_, hd_write_dma_
	%endif
	%ifdef HDINSTALL_DEF
			dd hd_install_
	%endif
%endif

			; PCI
			dd pci_ls_, pci_cfg_, pci_det_usb_
			dd pci_config_read_dword_, pci_config_read_word_, pci_config_read_byte_
			dd pci_config_write_dword_, pci_config_write_word_, pci_config_write_byte_

%ifdef USB_DEF
			; USB
			dd usb_devinfo_, usb_ehci_, usb_xhci_, usb_driver_, usb_enum_, usb_init_msd_, usb_read_, usb_write_
			dd usb_fsinit_, usb_fsinfo_, usb_fsinfo_upd_, usb_fsls_,  usb_fscd_, usb_fspwd_, usb_fsread_, usb_fswrite_, usb_fsrem_
%endif

%ifdef AUDIO_DEF
			; Audio
			dd audio_get_supported_format_, audio_print_format_, audio_init_, audio_info_, audio_codecs_info_, audio_play_, audio_stop_
			dd audio_setvol_, audio_getvol_, audio_pause_, audio_resume_, audio_wav_
%endif

%ifdef MULTITASKING_DEF
			dd user_, incuser_, paren_user_paren_ 
			; Multitasking
			dd activate_, gettbuff_, kill_, pause_, resume_, suspend_, task_, tasks_, task_clear_counter_, terminate_
%endif

			; Special
			dd outp_, txt_view_ 
			dd os_pars_off_, os_pars_on_, scroll_off_, scroll_on_, to_main_scr_, from_main_scr_, tmp_to_main_scr_, tmp_from_main_scr_

			; Extra keys (keyboard)
			dd key_ctrl_question_, key_shift_question_, key_alt_question_, key_scroll_lock_question_, key_caps_lock_question_	

			dd 0


%endif

