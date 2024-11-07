#!/usr/bin/env python3

# prints the BIOS Parameter Block (BPB) from the given file

import sys


helptxt = '''Usage:
python3 ./printbpb.py binaryfilename

Example:
python3 ./printbpb.py vbr.bin
'''

num = len(sys.argv)
if num != 2:
	print (helptxt)
	sys.exit()

filename = sys.argv[1]

BPB_OFFSET = 3

BPBOEM_OFFS						= 0		#db "mkdosfs",0		; 8 chars
BPBBYTESPERSECTOR_OFFS			= 8		#dw 0x0200			; 8
BPBSECTORSPERCLUSTER_OFFS		= 10	#db 0x08			; 10
BPBRESERVEDSECTORS_OFFS			= 11	#dw 0x0020			; 11
BPBNUMBEROFFATS_OFFS			= 13	#db 0x02			; 13
BPBROOTENTRIES_OFFS				= 14	#dw 0x0000			; 14
BPBTOTALSECTORS_OFFS			= 16	#dw 0x0000			; 16
BPBMEDIA_OFFS					= 18	#db 0xF8			; 18
BPBSECTORSPERFAT16_OFFS			= 19	#dw 0x0000			; 19
BPBSECTORSPERTRACK_OFFS			= 21	#dw 0x003E			; 21
BPBHEADSPERCYLINDER_OFFS		= 23	#dw 0x007C			; 23
BPBHIDDENSECTORS_OFFS			= 25	#dd 0x00000000		; 25
BPBLARGETOTALSECTORS_OFFS		= 29	#dd 0x0077FFDF		; 29
BPBSECTORSPERFAT_OFFS			= 33	#dd 0x00001DF8		; 33
BPBMIRRORINGFLAGS_OFFS			= 37	#dw 0x0000			; 37
BPBVERSION_OFFS					= 39	#dw 0x0000			; 39
BPBROOTDIRCLUSTER_OFFS			= 41	#dd 0x00000002		; 41
BPBLOCATIONFSINFSECTOR_OFFS		= 45	#dw 0x0001			; 45
BPBLOCATIONBACKUPSECTOR_OFFS	= 47	#dw 0x0006			; 47
BPBRESERVEDBOOTFNAME_OFFS		= 49	#times 12 db 0x00	; 49
BPBPHYSDRIVENUM_OFFS			= 61	#db 0x00			; 61
BPBFLAGS_OFFS					= 62	#db 0x00			; 62
BPBEXTENDEDBOOTSIG_OFFS			= 63	#db 0x29			; 63
BPBVOLUMESERIALNUM_OFFS			= 64	#dd 0xE58C48B6		; 64
# DOS 7.1 Extended BPB (79 bytes, without bpbOEM)
BPBVOLUMELABEL_OFFS				= 68	#db "           "	; 11 chars	; 68
BPBFSTYPE_OFFS					= 79	#db "FAT32   "		; 8 chars	; 79

BPB_BYTES	= 87

BPB_NUM = 26

DB = 0
DW = 1
DD = 2

txts = ('bpbOEM', 'bpbBytesPerSector', 'bpbSectorsPerCluster', 'bpbReservedSectors', 'bpbNumberOfFATs', 'bpbRootEntries', 'bpbTotalSectors', 'bpbMedia', 'bpbSectorsPerFAT16', 'bpbSectorsPerTrack', 'bpbHeadsPerCylinder', 'bpbHiddenSectors', 'bpbLargeTotalSectors', 'bpbSectorsPerFat', 'bpbMirroringFlags', 'bpbVersion', 'bpbRootDirCluster', 'bpbLocationFSInfSector', 'bpbLocationBackupSector', 'bpbReservedBootFName', 'bpbPhysDriveNum', 'bpbFlags', 'bpbExtendedBootSig', 'bpbVolumeSerialNum', 'bpbVolumeLabel', 'bpbFSType')

txttypes = ('\t\t\tdb', '\tdw', '\tdb', '\tdw', '\t\tdb', '\t\tdw', '\t\tdw', '\t\tdb', '\tdw', '\tdw', '\tdw', '\tdd', '\tdd', '\tdd', '\tdw', '\t\tdw', '\tdd', '\tdw', '\tdw', '\tdb', '\t\tdb', '\t\tdb', '\tdb', '\tdd', '\t\tdb', '\t\tdb')

idxs = (BPBOEM_OFFS, BPBBYTESPERSECTOR_OFFS, BPBSECTORSPERCLUSTER_OFFS, BPBRESERVEDSECTORS_OFFS, BPBNUMBEROFFATS_OFFS, BPBROOTENTRIES_OFFS, BPBTOTALSECTORS_OFFS, BPBMEDIA_OFFS, BPBSECTORSPERFAT16_OFFS, BPBSECTORSPERTRACK_OFFS, BPBHEADSPERCYLINDER_OFFS, BPBHIDDENSECTORS_OFFS, BPBLARGETOTALSECTORS_OFFS, BPBSECTORSPERFAT_OFFS, BPBMIRRORINGFLAGS_OFFS, BPBVERSION_OFFS, BPBROOTDIRCLUSTER_OFFS, BPBLOCATIONFSINFSECTOR_OFFS, BPBLOCATIONBACKUPSECTOR_OFFS, BPBRESERVEDBOOTFNAME_OFFS, BPBPHYSDRIVENUM_OFFS, BPBFLAGS_OFFS, BPBEXTENDEDBOOTSIG_OFFS, BPBVOLUMESERIALNUM_OFFS, BPBVOLUMELABEL_OFFS, BPBFSTYPE_OFFS, BPB_BYTES)


typs = (DB, DW, DB, DW, DB, DW, DW, DB, DW, DW, DW, DD, DD, DD, DW, DW, DD, DW, DW, DB, DB, DB, DB, DD, DB, DB)

try:
	f = open(filename, "rb")
except IOError:
	print("Couldn't open file")
else:
	try:
		bytesread = f.read(BPB_BYTES)

		for i in range(BPB_NUM):

			val = bytesread[BPB_OFFSET+idxs[i]:BPB_OFFSET+idxs[i+1]]
			if (i == 0 or i == 19 or i == 24 or i == 25):
				print(txts[i]+txttypes[i]+'\t'+str(val))
			else:
				txt = txts[i]+txttypes[i]+'\t'
				txt += '0x'
				if (typs[i] == DB):
					txt += "{0:02x}".format(val[0])
				if (typs[i] == DW):
					txt += "{0:02x}".format(val[1])
					txt += "{0:02x}".format(val[0])
				if (typs[i] == DD):
					txt += "{0:02x}".format(val[3])
					txt += "{0:02x}".format(val[2])
					txt += "{0:02x}".format(val[1])
					txt += "{0:02x}".format(val[0])
				print(txt)

			if (i == 22 and (val[0] != 41)):	# decimal 41 is 0x29
				break

	finally:
		f.close()

#print(txts[i]+txttypes[i]+'\t'+''.join(["%02X " % x for x in val]).strip())









