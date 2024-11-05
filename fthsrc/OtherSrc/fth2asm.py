#!/usr/bin/env python3

# Converts FORTH-src in file.txt to assembly text-array (file.asm)
# This way tick can not be used in the given FORTH-src!
# If we used double-quotes as delimiters, then e.g. dot-quote could not be used in FORTH-src.

# Let's say the input filename was bigf.txt
# 1. Copy bigf.asm to the ZFOS folder.
# 2. Add to forth/core.asm (at the end of the file, right before '%endif'): %include "bigf.asm"
# 3. Add to forth/core.asm (right before 'section data'):
#	_load_bigf:
#			PUSH_PS(bigf)
#			mov	eax, [bigf_cnt]
#			PUSH_PS(eax)
#			call _loadm
#			ret
# 4. Add to forth/wordarr.asm:
#			lbigf_	dd _load_bigf
#					db "lbigf", 0, 0
#	Add:
#		dd lbigf_ 
#	to the end of word_arr right before "dd 0"

import os
import sys

# total arguments
argsnum = len(sys.argv) 

if (argsnum != 3):
	print("Usage: python3 ./fth2asm.py file.txt file.asm")
	exit()

fl1 = sys.argv[1]
fl2 = sys.argv[2]

fi = open(fl1, "r")
fo = open(fl2, "w")
try:
	chrs = fi.read()
	nchrs = len(chrs)
	print("nchars=", nchrs)

	fname, fext = os.path.splitext(fl1)
	fname = fname.lower() 
	fo.write(fname + " db ' \\\n")

	for i in range(nchrs):
		if (chrs[i] == "\n"):
			fo.write(' \\')			# this substitutes newline-char with a space, so no extra bytes will be added
		fo.write(chrs[i])

	fo.write(" ', 0")
	fo.write("\n\n")
	fo.write(fname + "_cnt dd " + str(nchrs + 2))   # +2 is the two extra spaces after and before the delimiter.
	fo.write("\n\n")

finally:
	fi.close()
	fo.close()

