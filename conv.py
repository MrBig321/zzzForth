#!/usr/bin/env python3

#to read the bytes of hdboot.bin and hdloader (need to boot from hd) and write them to text files

#import sys

NUM_PER_LINE = 16

f = open("output/hdboot.bin", "rb")
fo = open("output/hdbootbytes.inc", "w")
try:
	fo.write('hdbootdata\tdb ')
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


#The same as above but complete it to full sectors (512 bytes)
NUM_PER_SECTOR = 512
f = open("output/hdloader.bin", "rb")
fo = open("output/hdloaderbytes.inc", "w")
try:
	fo.write('hdloderdata\tdb ')
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

	bnumpersector = num % NUM_PER_SECTOR 
	if (bnumpersector != 0):
		if (num % NUM_PER_LINE != 0):
			fo.write(', ')

		bnum = NUM_PER_SECTOR-bnumpersector
		num2 = 0
		for i in range(bnum):
			if (num % NUM_PER_LINE == 0):
				fo.write('\n\t\t\tdb ')
			fo.write('0x00')
			if (num2+1 != bnum):
				fo.write(', ')

			num += 1
			num2 += 1

finally:
	f.close()
	fo.close()







