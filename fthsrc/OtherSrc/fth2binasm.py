#!/usr/bin/env python3

# Converts FORTH-src in file.txt to assembly binary data (file.asm)

# Let's say the input filename is bigf.txt
# 1. python3 ./fth2binasm.py bigf.txt bigf.asm
# 2. Copy bigf.asm to the ZFOS folder.
# 3. Add to forth/core.asm (at the end of the file, right before '%endif'): %include "bigf.asm"
# 4. Add to forth/core.asm (right before 'section data'):
#	_load_bigf_fth:
#			PUSH_PS(bigf_fth)
#			mov	eax, [bigf_fth_cnt]
#			PUSH_PS(eax)
#			call _loadm
#			ret
# 5. Add to forth/wordarr.asm:
#			lbigf_	dd _load_bigf_fth
#					db "lbigf", 0, 0
#	Add:
#		dd lbigf_ 
#	to the end of word_arr right before "dd 0"

import os
import sys

# total arguments
argsnum = len(sys.argv) 

if (argsnum != 3):
	print("Usage: python3 ./fth2binasm.py file.txt file.asm")
	exit()

NUM_PER_LINE = 16

fl1 = sys.argv[1]
fl2 = sys.argv[2]

fi = open(fl1, "rb")
fo = open(fl2, "w")
try:
	fname, fext = os.path.splitext(fl1)
	fname = fname.lower() 
	fo.write(fname + "_fth\tdb ")
	bytesread = fi.read()
	bnum = len(bytesread)
	num = 0

	for i in range(bnum):
		if ((num != 0) and (num % NUM_PER_LINE == 0) and ((num+1) != bnum)):
			fo.write('\n\t\t\tdb ')

		fo.write('0x')
		fo.write("{0:02x}".format(bytesread[i]))
		if (num+1 != bnum):
			fo.write(', ')
		num += 1

	fo.write("\n\n")
	fo.write(fname + "_fth_cnt\tdd " + str(bnum))
	fo.write("\n\n")

finally:
	fi.close()
	fo.close()

