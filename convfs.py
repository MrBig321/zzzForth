#!/usr/bin/env python3

#to read the bytes of hdboot.bin and hdloader (need to boot from hd) and write them to text files

#import sys

NUM_PER_LINE = 16

# HDMBR
f = open("output/hdfsmbr.bin", "rb")
fo = open("output/hdfsmbrbytes.inc", "w")
try:
	fo.write('hdfsmbrdata\tdb ')
	bytesread = f.read()
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

finally:
	f.close()
	fo.close()

# HDBOOT
f = open("output/hdfsboot.bin", "rb")
fo = open("output/hdfsbootbytes.inc", "w")
try:
	fo.write('hdfsbootdata\tdb ')
	bytesread = f.read()
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

finally:
	f.close()
	fo.close()


