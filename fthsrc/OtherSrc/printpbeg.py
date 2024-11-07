#!/usr/bin/env python3

# prints the partition-entries and their LBABegs from the Master Boot Record (MBR) from the given file

import sys


helptxt = '''Usage:
python3 ./printbbeg.py binaryfilename

Example:
python3 ./printpbeg.py mbr.bin
'''

num = len(sys.argv)
if num != 2:
	print (helptxt)
	sys.exit()

filename = sys.argv[1]

# addresses of the four partition entries
entries = (0x01BE, 0x01CE, 0x01DE, 0x01FE)
PE_LEN	= 16

PE_LBABEG_OFFS	= 8


try:
	f = open(filename, "rb")
except IOError:
	print("Couldn't open file")
else:
	try:
		f.seek(entries[0])
		for p in range(len(entries)):
			bytesread = f.read(PE_LEN)

			txt = 'Entry'+str(p+1)+': '
			for i in range(PE_LEN):
				txt += '0x'+"{0:02x}".format(bytesread[i])+' '
			print(txt)

			txt = 'LBABegin: 0x'
			txt += "{0:02x}".format(bytesread[PE_LBABEG_OFFS+3])
			txt += "{0:02x}".format(bytesread[PE_LBABEG_OFFS+2])
			txt += "{0:02x}".format(bytesread[PE_LBABEG_OFFS+1])
			txt += "{0:02x}".format(bytesread[PE_LBABEG_OFFS+0])
			print(txt)
	finally:
		f.close()










