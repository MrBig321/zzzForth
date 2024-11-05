;***************************
; SCSI commands

%ifndef __SCSI__
%define __SCSI__
 


scsi_testunit_cbw	dd 0x43425355	;dCBWSignature
					dd 0xAABBCCDD	;dCBWTag
					dd 0			;dCBWDataTransferLength
					db 0			;bmCBWFlags 0x80=Device2Host, 00=Host2Device
					db 0			;bCBWLun
					db 6			;bCBWCBLength 
					db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 


scsi_sense_cbw		dd 0x43425355   ;dCBWSignature
					dd 0xBBAADDCC   ;dCBWTag
					dd 0x00000012	;dCBWDataTransferLength
					db 0x80			;bmCBWFlags 0x80=Device2Host, 00=Host2Device
					db 0x00			;bCBWLun
					db 0x06			;bCBWCBLength 
					db 0x03, 0x00, 0x00, 0x00, 0x12, 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 


scsi_inquiry_cbw		dd	0x43425355		; Signature, 		'USBC'
						dd	0xAAFFBBFF		; Tag, 				arbitrary, will be returned in CSW
						dd	0x00000024		; Transfer Length,	we want at most 36 bytes returned
						db	0x80			; Flags,			receive an in packet
						db	0x00			; LUN, 				first volume
						db	0x06			; Command Len,		this command is 6 bytes
						db	0x12, 0x00, 0x00, 0x00, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 

scsi_read_capacity10_cbw	dd	0x43425355		; Signature, 		'USBC'
							dd	0xCCFFDDFF		; Tag, 				arbitrary, will be returned in CSW
							dd	0x00000008		; Transfer Length,	we want at most 8 bytes returned
							db	0x80			; Flags,			receive an in packet
							db	0x00			; LUN, 				first volume
							db	0x0A			; Command Len,		this command is 10 bytes
							db	0x25, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 

scsi_read_capacity16_cbw	dd	0x43425355		; Signature, 		'USBC'
							dd	0xEEAADDBB		; Tag, 				arbitrary, will be returned in CSW
							dd	0x00000020		; Transfer Length,	we want at most 32 bytes returned
							db	0x80			; Flags,			receive an in packet
							db	0x00			; LUN, 				first volume
							db	0x10			; Command Len,		this command is 16 bytes
							db	0x9E, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 

scsi_read10_cbw		dd	0x43425355		; Signature, 		'USBC'
					dd	0xDD88EE77		; Tag, 				arbitrary, will be returned in CSW
					dd	0x00000000		; Transfer Length,	#sector * sectorsize, 				TO FILL
					db	0x80			; Flags,			receive an in packet
					db	0x00			; LUN, 				first volume
					db	0x0A			; Command Len,		this command is 10 bytes
					db	0x28, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
						; 3,4,5,6 LBA; 8,9 is #ofblocks (FILL)

scsi_read12_cbw		dd	0x43425355		; Signature, 		'USBC'
					dd	0xBBAA7733		; Tag, 				arbitrary, will be returned in CSW
					dd	0x00000000		; Transfer Length,	#sector * sectorsize,				 TO FILL
					db	0x80			; Flags,			receive an in packet
					db	0x00			; LUN, 				first volume
					db	0x0C			; Command Len,		this command is 12 bytes
					db	0xA8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
						; 3,4,5,6 LBA; 7,8,9,10 is #ofblocks (FILL)

scsi_read16_cbw		dd	0x43425355		; Signature, 		'USBC'
					dd	0xBB2255CC		; Tag, 				arbitrary, will be returned in CSW
					dd	0x00000000		; Transfer Length,	#sector * sectorsize,				 TO FILL
					db	0x80			; Flags,			receive an in packet
					db	0x00			; LUN, 				first volume
					db	0x10			; Command Len,		this command is 16 bytes
					db	0x88, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
						; 3-10 LBA; 11,12,13,14 is #ofblocks (FILL)

scsi_write10_cbw	dd	0x43425355		; Signature, 		'USBC'
					dd	0x33557799		; Tag, 				arbitrary, will be returned in CSW
					dd	0x00000000		; Transfer Length,	#sector * sectorsize, 				TO FILL
					db	0x00			; Flags,			send an out packet
					db	0x00			; LUN, 				first volume
					db	0x0A			; Command Len,		this command is 10 bytes
					db	0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
						; 3,4,5,6 LBA; 8,9 is #ofblocks (FILL)

scsi_write12_cbw	dd	0x43425355		; Signature, 		'USBC'
					dd	0xBBAA7733		; Tag, 				arbitrary, will be returned in CSW
					dd	0x00000000		; Transfer Length,	#sector * sectorsize,				 TO FILL
					db	0x00			; Flags,			send an out packet
					db	0x00			; LUN, 				first volume
					db	0x0C			; Command Len,		this command is 12 bytes
					db	0xAA, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
						; 3,4,5,6 LBA; 7,8,9,10 is #ofblocks (FILL)

scsi_write16_cbw	dd	0x43425355		; Signature, 		'USBC'
					dd	0x11223344		; Tag, 				arbitrary, will be returned in CSW
					dd	0x00000000		; Transfer Length,	#sector * sectorsize,				 TO FILL
					db	0x00			; Flags,			send an out packet
					db	0x00			; LUN, 				first volume
					db	0x10			; Command Len,		this command is 16 bytes
					db	0x8A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
						; 3-10 LBA; 11,12,13,14 is #ofblocks (FILL)



%endif



