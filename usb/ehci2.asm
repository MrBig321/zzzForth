; EHCI
;********************************************

; Here we use data-toggle(dt) in the TDs

%ifndef __EHCI__
%define __EHCI__


%include "pci.asm"
%include "usb/common.asm"
%include "gstdio.asm"
%include "gutil.asm"


%define EHCI_CAPS_CapLength			0x00
%define EHCI_CAPS_Reserved			0x01
%define EHCI_CAPS_IVersion			0x02
%define EHCI_CAPS_HCSParams			0x04
%define EHCI_CAPS_HCCParams			0x08
%define EHCI_CAPS_HCSPPortRoute		0x0C

%define EHCI_OPS_USBCommand			0x00
%define EHCI_OPS_USBStatus			0x04
%define EHCI_OPS_USBInterrupt		0x08
%define EHCI_OPS_FrameIndex			0x0C
%define EHCI_OPS_CtrlDSSegment		0x10
%define EHCI_OPS_PeriodicListBase	0x14
%define EHCI_OPS_AsyncListBase		0x18
%define EHCI_OPS_ConfigFlag			0x40
%define EHCI_OPS_PortStatus			0x44	; first port

%define EHCI_PORT_CCS			(1<<0)
%define EHCI_PORT_CSC			(1<<1)
%define EHCI_PORT_ENABLED		(1<<2)
%define EHCI_PORT_ENABLE_C		(1<<3)
%define EHCI_PORT_OVER_CUR_C	(1<<5)
%define EHCI_PORT_RESET			(1<<8)
%define EHCI_PORT_LINE_STATUS	(3<<10)
%define EHCI_PORT_PP			(1<<12)
%define EHCI_PORT_OWNER			(1<<13)

%define EHCI_LEGACY_USBLEGSUP	0x00
%define EHCI_LEGACY_USBLEGCTLSTS	0x04

%define EHCI_LEGACY_TIMEOUT		10		; 10 milliseconds
%define EHCI_LEGACY_BIOS_OWNED	(1<<16)
%define EHCI_LEGACY_OS_OWNED		(1<<24)
%define EHCI_LEGACY_OWNED_MASK	(EHCI_LEGACY_BIOS_OWNED | EHCI_LEGACY_OS_OWNED)

%define EHCI_PORT_WRITE_MASK	0x007FF1EE

%define EHCI_QUEUE_HEAD_PTR_MASK	0x1F

; HC uses the first 48 (68 if 64-bit) bytes, but each queue must be 32 byte aligned
%define EHCI_QUEUE_HEAD_SIZE	96	; 96 bytes

%define EHCI_QH_OFF_HORZ_PTR			0	; offset of item within queue head
%define EHCI_QH_OFF_ENDPT_CAPS			4
%define EHCI_QH_OFF_HUB_INFO			8
%define EHCI_QH_OFF_CUR_QTD_PTR			12
%define EHCI_QH_OFF_NEXT_QTD_PTR		16
%define EHCI_QH_OFF_ALT_NEXT_QTD_PTR	20
%define EHCI_QH_OFF_STATUS				24
%define EHCI_QH_OFF_BUFF0_PTR			28
%define EHCI_QH_OFF_BUFF1_PTR			32
%define EHCI_QH_OFF_BUFF2_PTR			36
%define EHCI_QH_OFF_BUFF3_PTR			40
%define EHCI_QH_OFF_BUFF4_PTR			44
%define EHCI_QH_OFF_BUFF0_HI			48
%define EHCI_QH_OFF_BUFF1_HI			52
%define EHCI_QH_OFF_BUFF2_HI			56
%define EHCI_QH_OFF_BUFF3_HI			60
%define EHCI_QH_OFF_BUFF4_HI			64
%define EHCI_QH_OFF_PREV_PTR			92	; we use this for our insert/remove queue stuff


%define EHCI_QH_HS_T0		(0<<0)		; pointer is valid
%define EHCI_QH_HS_T1		(1<<0)		; pointer is not valid

%define EHCI_QH_HS_TYPE_ISO		(0<<1)		; Isochronous TD
%define EHCI_QH_HS_TYPE_QH		(1<<1)		; Queue Head
%define EHCI_QH_HS_TYPE_SPLIT	(2<<1)		; Split Transaction Isochronous TD
%define EHCI_QH_HS_TYPE_FSTN	(3<<1)		; Frame Span Traversal Node

%define EHCI_QH_HS_EPS_FS	(0<<12)	; Full speed endpoint
%define EHCI_QH_HS_EPS_LS	(1<<12)	; Low  speed endpoint
%define EHCI_QH_HS_EPS_HS	(2<<12)	; High speed endpoint


%define EHCI_TD_SIZE	64	; 64 bytes

%define EHCI_TD_OFF_NEXT_TD_PTR			0	; offset of item within td
%define EHCI_TD_OFF_ALT_NEXT_QTD_PTR	4
%define EHCI_TD_OFF_STATUS				8
%define EHCI_TD_OFF_BUFF0_PTR			12
%define EHCI_TD_OFF_BUFF1_PTR			16
%define EHCI_TD_OFF_BUFF2_PTR			20
%define EHCI_TD_OFF_BUFF3_PTR			24
%define EHCI_TD_OFF_BUFF4_PTR			28
%define EHCI_TD_OFF_BUFF0_HI			32
%define EHCI_TD_OFF_BUFF1_HI			36
%define EHCI_TD_OFF_BUFF2_HI			40
%define EHCI_TD_OFF_BUFF3_HI			44
%define EHCI_TD_OFF_BUFF4_HI			48

%define	EHCI_QHS_NUM	2

%define	EHCI_HEAP_INIT		0x160000

%define	EHCI_CBW_LEN		31
%define	EHCI_CSW_LEN		13

ehci_bus	db	0
ehci_dev	db	0
ehci_fun	db	0

ehci_bar		dd	0
ehci_opbaseoffs	dd	0

ehci_control_mps	db	0
ehci_dev_address	db	0
ehci_len			dw	0
ehci_pid			db	0

ehci_lbahi			dd	0
ehci_lbalo			dd	0
ehci_sector_size	dd	0
ehci_curr_tag		dd	0		; CSW's tag

ehci_td_num			dd	0

; Bulk I/O
ehci_bulk_len		dd	0
ehci_bulk_mps		dw	0	
ehci_bulkin_mps		dw	0	
ehci_bulkout_mps	dw	0	
ehci_bulk_dt		dd	0
ehci_bulkin_dt		dd	0
ehci_bulkout_dt		dd	0
ehci_bulkout_endpt	db	0
ehci_bulkin_endpt	db	0
; end of Bulk

ehci_hcsparams	dd	0
ehci_hccparams	dd	0
ehci_cur_heap_ptr	dd	EHCI_HEAP_INIT
ehci_async_base		dd	0		; EHCI_QHS_NUM QHs
ehci_async_qh		dd	0
ehci_async_tds		dd	0
ehci_async_req_buff	dd	0
ehci_async_buff		dd	0
ehci_num_ports	db	0
ehci_res		dd	0
ehci_cur_heap_ptr_afterenum	dd	0

ehci_langid		dw	0

ehci_req_addr_packet	db	0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
ehci_req_desc_packet	db	USB_STDRD_GET_REQUEST, USB_DEVREQ_GET_DESCRIPTOR, 
						dw	(USB_DESCTYP_DEVICE << 8), 0, 0
ehci_req_langs_packet	db	0x80, 0x06, 
						dw	0x0300, 0x0000, 0 	;0xFF	; we request just 18(ehci_len) bytes of the langids-desc 
ehci_req_config_packet	db	0x80, 0x06, 
						dw	0x0200, 0x0000, 0

ehci_set_config_packet	db	0, 9, 
						dw	1, 0, 0
													; after the config descriptor there are the interface(s) and endpoints descriptors
ehci_req_lun_packet		db	0xA1, 0xFE, 
						dw	0x0000, 0, 0x0001	; intnum is interface number from interface descriptor (second word from the end)

;ehci_req_getcon_packet	db	0x80, 8, 
;						dw	0, 0, 1

ehci_max_lun	db	0
ehci_config		db	0

ehci_req_bulkreset_packet		db	0x21, 0xFF,
								dw	0, 0, 0

ehci_req_bulkendptreset_packet	db	0x02, 0x01,
								dw	0, 0, 0		; the 0 (word) in the middle is either BulkIn or BulkOut


ehci_testunit_cbw	dd 0x43425355	;dCBWSignature
					dd 0xAABBCCDD	;dCBWTag
					dd 0			;dCBWDataTransferLength
					db 0			;bmCBWFlags 0x80=Device2Host, 00=Host2Device
					db 0			;bCBWLun
					db 6			;bCBWCBLength 
					db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 


ehci_sense_cbw		dd 0x43425355   ;dCBWSignature
					dd 0xBBAADDCC   ;dCBWTag
					dd 0x00000012	;dCBWDataTransferLength
					db 0x80			;bmCBWFlags 0x80=Device2Host, 00=Host2Device
					db 0x00			;bCBWLun
					db 0x06			;bCBWCBLength 
					db 0x03, 0x00, 0x00, 0x00, 0x12, 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 


ehci_inquiry_cbw		dd	0x43425355		; Signature, 		'USBC'
						dd	0xAAFFBBFF		; Tag, 				arbitrary, will be returned in CSW
						dd	0x00000024		; Transfer Length,	we want at most 36 bytes returned
						db	0x80			; Flags,			receive an in packet
						db	0x00			; LUN, 				first volume
						db	0x06			; Command Len,		this command is 6 bytes
						db	0x12, 0x00, 0x00, 0x00, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 

ehci_read_capacity10_cbw	dd	0x43425355		; Signature, 		'USBC'
							dd	0xCCFFDDFF		; Tag, 				arbitrary, will be returned in CSW
							dd	0x00000008		; Transfer Length,	we want at most 8 bytes returned
							db	0x80			; Flags,			receive an in packet
							db	0x00			; LUN, 				first volume
							db	0x0A			; Command Len,		this command is 10 bytes
							db	0x25, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 

ehci_read_capacity16_cbw	dd	0x43425355		; Signature, 		'USBC'
							dd	0xEEAADDBB		; Tag, 				arbitrary, will be returned in CSW
							dd	0x00000020		; Transfer Length,	we want at most 32 bytes returned
							db	0x80			; Flags,			receive an in packet
							db	0x00			; LUN, 				first volume
							db	0x10			; Command Len,		this command is 16 bytes
							db	0x9E, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 

ehci_read10_cbw		dd	0x43425355		; Signature, 		'USBC'
					dd	0xDD88EE77		; Tag, 				arbitrary, will be returned in CSW
					dd	0x00000000		; Transfer Length,	#sector * sectorsize, 				TO FILL
					db	0x80			; Flags,			receive an in packet
					db	0x00			; LUN, 				first volume
					db	0x0A			; Command Len,		this command is 10 bytes
					db	0x28, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
						; 3,4,5,6 LBA; 8,9 is #ofblocks (FILL)

;ehci_read12_cbw		dd	0x43425355		; Signature, 		'USBC'
;					dd	0xBBAA7733		; Tag, 				arbitrary, will be returned in CSW
;					dd	0x00000000		; Transfer Length,	#sector * sectorsize,				 TO FILL
;					db	0x80			; Flags,			receive an in packet
;					db	0x00			; LUN, 				first volume
;					db	0x0C			; Command Len,		this command is 12 bytes
;					db	0xA8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
						; 3,4,5,6 LBA; 7,8,9,10 is #ofblocks (FILL)

ehci_read16_cbw		dd	0x43425355		; Signature, 		'USBC'
					dd	0xBB2255CC		; Tag, 				arbitrary, will be returned in CSW
					dd	0x00000000		; Transfer Length,	#sector * sectorsize,				 TO FILL
					db	0x80			; Flags,			receive an in packet
					db	0x00			; LUN, 				first volume
					db	0x10			; Command Len,		this command is 16 bytes
					db	0x88, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
						; 3-10 LBA; 11,12,13,14 is #ofblocks (FILL)

ehci_write10_cbw	dd	0x43425355		; Signature, 		'USBC'
					dd	0x33557799		; Tag, 				arbitrary, will be returned in CSW
					dd	0x00000000		; Transfer Length,	#sector * sectorsize, 				TO FILL
					db	0x80			; Flags,			receive an in packet
					db	0x00			; LUN, 				first volume
					db	0x0A			; Command Len,		this command is 10 bytes
					db	0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  
						; 3,4,5,6 LBA; 8,9 is #ofblocks (FILL)

ehci_write16_cbw	dd	0x43425355		; Signature, 		'USBC'
					dd	0x11223344		; Tag, 				arbitrary, will be returned in CSW
					dd	0x00000000		; Transfer Length,	#sector * sectorsize,				 TO FILL
					db	0x80			; Flags,			receive an in packet
					db	0x00			; LUN, 				first volume
					db	0x10			; Command Len,		this command is 16 bytes
					db	0x8A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
						; 3-10 LBA; 11,12,13,14 is #ofblocks (FILL)


; disable_legacyPO params
ehci_eecp_id				db	0
ehci_bios_owned_semaphore	db	0
ehci_os_owned_semaphore		db	0
ehci_usblegctlsts			db	0


ehci_FndEHCICtrlTxt			db 0x0A, 'Found EHCI controller ', 0
ehci_BIOSDidntRelLegacyTxt	db ' BIOS did not release Legacy support...', 0x0A, 0
ehci_FoundLSDevTxt			db ' Found a low- or full-speed device. Skipping.', 0x0A, 0
ehci_InterruptTOTxt			db ' USB EHCI Interrupt wait timedout.', 0x0A, 0
ehci_WaitInterruptTxt		db ' USB EHCI wait interrupt qtd->status = ', 0

ehci_TrFailedAddr0Txt		db 'Transaction failed with device address zero', 0x0A, 0
ehci_SetAddrFailedTxt 		db 'Setting address failed', 0x0A, 0
ehci_TrFailedAddrTxt		db 'Transaction failed with device address', 0x0A, 0
ehci_GetLangsFailedTxt		db 'Getting lang-ids failed', 0x0A, 0
ehci_GetManufStringFailedTxt	db 'Getting manufacturer string failed', 0x0A, 0
ehci_GetProdStringFailedTxt		db 'Getting product string failed', 0x0A, 0
ehci_NoStringTxt			db 'None', 0
ehci_SeparatorTxt			db ' - ', 0
ehci_StringPortDevAddrTxt	db ' String (Port, DeviceAddress)', 0x0A, 0
ehci_MaxLunTxt				db 'MaxLun: ', 0

ehci_failedTxt				db 'Failed', 0x0A, 0
ehci_EndptsErrTxt			db 'Not enough endpoints', 0x0A, 0

ehci_resetTOTxt				db ' Resetting the controller failed (TO)', 0x0A, 0
ehci_gettingDescriptorTxt	db ' Getting device descriptor ...', 0x0A, 0
ehci_gettingConfigTxt		db ' Getting config ...', 0x0A, 0
ehci_gettingLUNTxt			db ' Getting LUN ...', 0x0A, 0
ehci_HCHalted1Txt			db ' HCHalted is set', 0x0A, 0
;ehci_PortDidntResetTxt		db ' Timeout error: port did not reset', 0x0A, 0
ehci_InterruptErr			db ' Interrupt error', 0x0A, 0
ehci_removeQueueFailedTxt	db ' Remove queue failed', 0x0A, 0

ehci_SetConfigFailedTxt		db 'Setting configuration failed', 0x0A, 0
ehci_SendTestUnitCBWFailedTxt	db 'Sending testunit CBW failed', 0x0A, 0
ehci_SendSenseCBWFailedTxt	db 'Sending sense CBW failed', 0x0A, 0
ehci_SendInquiryCBWFailedTxt	db 'Sending inquiry CBW failed', 0x0A, 0
ehci_GetInquiryCBWFailedTxt	db 'Getting inquiry CBW failed', 0x0A, 0
ehci_GetSenseCBWFailedTxt	db 'Getting sense CBW failed', 0x0A, 0
ehci_SendCapCBWFailedTxt	db 'Sending capacity CBW failed', 0x0A, 0
ehci_GetCapCBWFailedTxt		db 'Getting capacity CBW failed', 0x0A, 0
ehci_GetCSWFailedTxt		db 'Getting CSW failed', 0x0A, 0
ehci_BulkResetFailedTxt		db 'Bulk reset failed', 0x0A, 0
ehci_BulkE1ResetFailedTxt	db 'Bulk endpoint 1 reset failed', 0x0A, 0
ehci_BulkE2ResetFailedTxt	db 'Bulk endpoint 2 reset failed', 0x0A, 0
ehci_SendRead10CBWFailedTxt	db 'Sending read10 CBW failed', 0x0A, 0
ehci_GetRead10DataFailedTxt	db 'Getting read10 data failed', 0x0A, 0
ehci_SendRead16CBWFailedTxt	db 'Sending read16 CBW failed', 0x0A, 0
ehci_GetRead16DataFailedTxt	db 'Getting read16 data failed', 0x0A, 0
ehci_SendWrite10CBWFailedTxt	db 'Sending write10 CBW failed', 0x0A, 0
ehci_SendWrite10DataFailedTxt	db 'Sending write10 data failed', 0x0A, 0
ehci_SendWrite16CBWFailedTxt	db 'Sending write16 CBW failed', 0x0A, 0
ehci_SendWrite16DataFailedTxt	db 'Sending write16 data failed', 0x0A, 0
ehci_LBATooBigTxt			db 'LBA too big', 0x0A, 0
ehci_CSWTagMismatchTxt		db 'CSW tag mismatch', 0x0A, 0
ehci_CSWStatusFailedTxt		db 'CSW-Status failed', 0x0A, 0

ehci_PressAKeyTxt	db "Press a Key", 0x0A, 0

; for ehci_cfg
ehci_ResettingTxt			db 'Resetting', 0x0A, 0
ehci_CouldntResetCtrlTxt	db 'Could not reset controller.', 0x0A, 0


ehci_InquiryTxt				db 'Inquiry: ', 0
ehci_TestUnitReadyTxt		db 'TestUnitReady: ', 0
ehci_RequestSenseTxt		db 'RequestSense: ', 0
ehci_CapacityTxt			db 'Capacity: ', 0
ehci_Read10Txt				db 'Read10: ', 0
ehci_Read16Txt				db 'Read16: ', 0
ehci_Write10Txt				db 'Write10: ', 0
ehci_Write16Txt				db 'Write16: ', 0


; DEBUG
;ehci_QHTxt					db 'QH:', 0x0A, 0



ehci_enum:
			pushad
			mov DWORD [ehci_cur_heap_ptr], EHCI_HEAP_INIT
			; for every controller each there can be 127 devices, but we don't support external HUBs, 
			; so 127 device addresses will be enough for all the ctrllers
			mov BYTE [ehci_dev_address], 1
			mov eax, 0					; bus
.NextBus	mov ebx, 0					; slot (or device)
.NextDev	mov ecx, 0					; function
.NextFun	mov edx, 0					; offset	; VendorID
			push eax	
			call pci_config_read_word
			mov dx, ax
			pop eax
			cmp dx, 0xFFFF				; check vendorID
			jz	.Continue
			; is it a USB controller?
			push eax
			mov edx, PCI_CLASS_CODE
			call pci_config_read_byte
			mov dl, al
			pop eax
			cmp dl, 0x0C
			jnz	.Continue
			push eax
			mov edx, PCI_SUB_CLASS
			call pci_config_read_byte
			mov dl, al
			pop eax
			cmp dl, 0x03
			jnz	.Continue
			; read cfg-space
			mov edx, 0
.NextDWord	push eax
			call pci_config_read_dword
			mov esi, [pci_cfg_arr]
			add esi, edx
			mov [esi], eax
			add edx, 4
			pop eax
			cmp edx, 0x100
			jnz	.NextDWord
			mov esi, [pci_cfg_arr]
			add esi, PCI_PROG_IF
			xor edx, edx
			mov dl, [esi]
			cmp dl, USB_TYPE_EHCI		; EHCI?
			jnz	.Continue
			push ebx
			mov ebx, ehci_FndEHCICtrlTxt
			call gstdio_draw_text
			mov dh, al
			call gstdio_draw_hex8
			mov ebx, ':'
			call gstdio_draw_char
			pop ebx
			mov dh, bl
			call gstdio_draw_hex8
			push ebx
			mov ebx, ':'
			call gstdio_draw_char
			mov dh, cl
			call gstdio_draw_hex8
			call gstdio_new_line
			mov ebx, ehci_StringPortDevAddrTxt
			call gstdio_draw_text
			pop ebx
			call ehci_process
.Continue	inc ecx
			cmp ecx, PCI_MAX_FUN
			jnge .NextFun
			inc ebx
			cmp ebx, PCI_MAX_DEV
			jnge .NextDev
			inc eax
			cmp eax, PCI_MAX_BUS
			jnge .NextBus
		mov ebx, [ehci_cur_heap_ptr]
		mov [ehci_cur_heap_ptr_afterenum], ebx
			popad
			ret


; reset the controller, give control of all ports to the companion controllers.
; IN: EAX(bus), EBX(dev), ECX(fun)
ehci_process:
			pushad
			mov [ehci_bus], al
			mov [ehci_dev], bl
			mov [ehci_fun], cl
			; allow access to data (memmapped IO)
			mov dx, 0x0006
			mov WORD [pci_tmp], dx
			mov edx, PCI_COMMAND
			call pci_config_write_word
			; The EHCI controller uses the dword at base0 and is memmapped access
			mov edx, PCI_BAR0
			call pci_config_read_dword
			and eax, ~0xF
			mov [ehci_bar], eax
			; calculate the operational base
			mov edx, [ehci_bar]
			add edx, EHCI_CAPS_CapLength
			xor eax, eax
			mov al, [edx]
			mov [ehci_opbaseoffs], al
			; stop ctrller
			mov edx, [ehci_bar]
			add edx, eax
			add edx, EHCI_OPS_USBCommand
			and DWORD [edx], ~1
			; check HCHALTED bit of USBStatus-reg
			sub edx, EHCI_OPS_USBCommand
			add edx, EHCI_OPS_USBStatus
.ChkHalted	test DWORD [edx], (1 << 12)
			jnz	.Reset
			mov ebx, 10
			call pit_delay
			jmp	.ChkHalted
			; reset the controller, returning after 50mS if it doesn't reset
.Reset		mov edx, [ehci_bar]
			add edx, eax
			add edx, EHCI_OPS_USBCommand
			or	DWORD [edx], (1 << 1)	; DIFF
			mov ecx, 50
.IsFinish	mov eax, [edx]
			and eax, (1 << 1)
			jz	.ChkTO
			mov ebx, 1
			call pit_delay
			loop .IsFinish
.ChkTO		cmp ecx, 0
			jnz	.StoreRegs
			mov ebx, ehci_resetTOTxt	
			call gstdio_draw_text
			jmp	.Back
			; if we get here, we have a valid EHCI controller, so set it up.
.StoreRegs	mov edx, [ehci_bar]
			add edx, EHCI_CAPS_HCSParams
			mov eax, [edx]
			mov [ehci_hcsparams], eax
			mov edx, [ehci_bar]
			add edx, EHCI_CAPS_HCCParams
			mov eax, [edx]
			mov [ehci_hccparams], eax
			; Turn off legacy support for Keyboard and Mice
			xor eax, eax
			xor ebx, ebx
			xor ecx, ecx
			mov al, [ehci_bus]
			mov bl, [ehci_dev]
			mov cl, [ehci_fun]
			call ehci_stop_legacyPO
			cmp ebx, 1
			jz	.GetNumPs
			mov ebx, ehci_BIOSDidntRelLegacyTxt
			call gstdio_draw_text
			jmp .Back
			; get num_ports from EHCI's HCSPARAMS register
.GetNumPs	xor ecx, ecx
			mov ecx, [ehci_hcsparams]
			and ecx, 0x0F				; at least 1 and no more than 15
			mov [ehci_num_ports], cl
			; allocate and initialize the async queue list (Control and Bulk TD's)
			mov eax, (EHCI_QHS_NUM * EHCI_QUEUE_HEAD_SIZE)
			mov ebx, 32
			call ehci_heap_alloc
			mov [ehci_async_base], ebx
			call ehci_init_stack_frame
			; set and start the Host Controllers schedule
			xor eax, eax
			mov al, [ehci_opbaseoffs]
			test DWORD [ehci_hccparams], (1 << 0)
			jz	.Skip64
			mov edx, [ehci_bar]
			add edx, eax
			add edx, EHCI_OPS_CtrlDSSegment
			mov DWORD [edx], 0			; we use only 32-bit addresses
.Skip64		mov edx, [ehci_bar]
			add edx, eax
			add edx, EHCI_OPS_PeriodicListBase 
			and DWORD [edx], 0x00000FFF		; DIFF	; physical address
			sub edx, EHCI_OPS_PeriodicListBase 
			add edx, EHCI_OPS_AsyncListBase
			mov ebx, [ehci_async_base]
		and ebx, 0xFFFFFFE0
		and DWORD [edx], 0x0000001F
			or	[edx], ebx			; DIFF	; physical address
			sub edx, EHCI_OPS_AsyncListBase
			add edx, EHCI_OPS_FrameIndex
			and DWORD [edx], 0xFFFFC000	; DIFF		; start at (micro)frame 0
			sub edx, EHCI_OPS_FrameIndex
			add edx, EHCI_OPS_USBInterrupt
			and DWORD [edx], 0xFFFFFFC0	; DIFF		; disallow interrupts
			sub edx, EHCI_OPS_USBInterrupt
			add edx, EHCI_OPS_USBStatus
			or	DWORD [edx], 0x3F		; DIFF		; clear any pending interrupts
			; start the host controller: 8 micro-frames, start schedule (frame list size = 1024)
			sub edx, EHCI_OPS_USBStatus
			add edx, EHCI_OPS_USBCommand
			or	DWORD [edx], (8 << 16)	; DIFF
			or	DWORD [edx], (1 << 0)
			; enable the asynchronous list
			call ehci_enable_async_listPO
			; Setting bit 0 in the ConfigFlags reg tells all ports to use the EHCI controller.
			mov edx, [ehci_bar]
			xor eax, eax
			mov al, [ehci_opbaseoffs]
			add edx, eax
			add edx, EHCI_OPS_ConfigFlag
			or	DWORD [edx], 1
			; if we have control to change the port power, we need to power each port to 1
			test DWORD [ehci_hcsparams], (1 << 4)
			jz	.Delay
			xor ecx, ecx
			xor ebx, ebx
			mov bl, [ehci_num_ports]
			sub edx, EHCI_OPS_ConfigFlag
			add edx, EHCI_OPS_PortStatus
.NPort		mov eax, ecx
			shl eax, 2
			push edx
			add edx, eax
			or	DWORD [edx], EHCI_PORT_PP
			pop edx
			inc ecx
			cmp ecx, ebx
			jnge .NPort
			; after powering a port, we must wait 20mS before using it.
.Delay		mov ebx, 20
			call pit_delay
			; we should be ready to detect any ports that are occupied
			xor ecx, ecx
			xor eax, eax
			mov al, [ehci_num_ports]
			mov BYTE [ehci_control_mps], 64
			; Since most high-speed devices will only work with a max packet size of 64,
			;  we don't request the first 8 bytes, then set the address, and request
			;  all 18 bytes like the uhci/ehci controllers.
			; power and reset the port
.DetOccPs	call ehci_reset_port
			cmp DWORD [ehci_res], 1
			jnz	.SkipDesc
;		push ebx
;		mov ebx, ehci_gettingDescriptorTxt
;		call gstdio_draw_text
;		pop ebx
			call ehci_get_descriptor
			inc BYTE [ehci_dev_address]		;;
.SkipDesc	inc ecx
			cmp ecx, eax
			jnge .DetOccPs
			; stop the controller
;			mov edx, [ehci_bar]
;			xor eax, eax
;			mov al, [ehci_opbaseoffs]
;			add edx, eax
;			add edx, EHCI_OPS_USBCommand
;			and DWORD [edx], ~1				; DIFF
;			; check HCHALTED bit of USBStatus-reg
;			sub edx, EHCI_OPS_USBCommand
;			add edx, EHCI_OPS_USBStatus
;.ChkHalt2	test DWORD [edx], (1 << 12)
;			jnz	.Back
;			mov ebx, 10
;			call pit_delay
;			jmp	.ChkHalt2
.Back		popad
			ret


; IN: ECX: port
; OUT: ehci_res
ehci_reset_port:
			pushad
			shl ecx, 2
			add ecx, EHCI_OPS_PortStatus
			; Clear the enable bit and status change bits (making sure the PP is set)
			mov edx, [ehci_bar]
			xor eax, eax
			mov al, [ehci_opbaseoffs]
			add edx, eax
			add edx, ecx
			test DWORD [ehci_hcsparams], (1 << 4)
			jz	.NoPPC
			or	DWORD [edx], EHCI_PORT_PP
.NoPPC		and DWORD [edx], ~EHCI_PORT_ENABLED
			or	DWORD [edx], (EHCI_PORT_OVER_CUR_C | EHCI_PORT_ENABLE_C | EHCI_PORT_CSC)
		;;should we clear here USBStatus-portchange!? (as in PrettyOS)
				; Check HCHalted
				mov ebx, [ehci_bar]
				add ebx, eax
				add ebx, EHCI_OPS_USBStatus
				test DWORD [ebx], (1 << 12)
				jz	.Run
				mov ebx, ehci_HCHalted1Txt
				call gstdio_draw_text
			; read the port and see if a device is attached
			; if device attached and is a hs device, the controller will set the enable bit.
			; if the enable bit is not set, then there was an error or it is a low- or full-speed device.
			; if bits 11:10 = 01b, then it isn't a high speed device anyway, skip the reset.
.Run		mov eax, [edx]
			test eax, EHCI_PORT_CCS
			jz	.Skip
			and eax, EHCI_PORT_LINE_STATUS
			shr eax, 10
			cmp eax, 0x01
			jz	.Skip
			; set bit 8 (writing a zero to bit 2)
			test DWORD [ehci_hcsparams], (1 << 4)
			jz	.NoPPC2
			or	DWORD [edx], EHCI_PORT_PP
.NoPPC2		and DWORD [edx], ~EHCI_PORT_ENABLED
			or	DWORD [edx], EHCI_PORT_RESET
;			mov ebx, 200 ;USB_TDRSTR					; at least 50 ms for a root hub
			mov ebx, USB_TDRSTR					; at least 50 ms for a root hub
			call pit_delay
			; clear the reset bit leaving the power bit set
			and DWORD [edx], ~EHCI_PORT_RESET			; without this: "port didn't reset"
			mov ebx, USB_TRSTRCY
			call pit_delay
; Check if really zero	(this is not necessary)
;				mov ecx, 50
;.ChkReset		test DWORD [edx], EHCI_PORT_RESET
;				jz	.Skip
;				mov ebx, 1
;				call pit_delay
;				loop .ChkReset
;				mov ebx, ehci_PortDidntResetTxt
;				call gstdio_draw_text
.Skip		mov eax, [edx]
			mov DWORD [ehci_res], 0
			test eax, EHCI_PORT_CCS	; VIRTUALBOX doesn't see attached devices
			jz	.Back
			; if after the reset, the enable bit is set, we have a high-speed device
			test eax, EHCI_PORT_ENABLED
			jz	.LSDev
			; Found a high-speed device.
			; clear the status change bit(s)
			and DWORD [edx], EHCI_PORT_WRITE_MASK
			mov DWORD [ehci_res], 1
			jmp .Back
.LSDev		mov ebx, ehci_FoundLSDevTxt
			call gstdio_draw_text
			; disable and power off the port
			and DWORD [edx], ~EHCI_PORT_ENABLED
			test DWORD [ehci_hcsparams], (1 << 4)
			jz	.NoPPC3
			and DWORD [edx], ~EHCI_PORT_PP	
.NoPPC3		mov ebx, 10
			call pit_delay
			; the next two lines are not necessary for this utility, but they remain included
			; to show what you would need to do to release ownership of the port.
			or	DWORD [edx], EHCI_PORT_OWNER	; DIFF
			; wait for the owner bit to actually be set, and the ccs bit to clear
			mov eax, (EHCI_PORT_OWNER | EHCI_PORT_CCS)
			mov ebx, EHCI_PORT_OWNER
			mov ecx, 25
			call ehci_handshake
			mov DWORD [ehci_res], 0
.Back		popad
			ret


; IN: ECX(port), ehci_control_mps
; OUT: EBX
ehci_get_descriptor:
			pushad
			xor eax, eax
			mov al, [ehci_dev_address]
			mov BYTE [ehci_dev_address], 0
			push eax
			mov esi, ehci_req_desc_packet
			mov WORD [ehci_len], 18
			mov ax, [ehci_len]
			mov [esi+USB_RECPAC_LENGTH], ax
			mov BYTE [ehci_pid], 1
	; IN: ESI(req_packet), ehci_len(bytenum of data), ehci_control_mps, ehci_pid(direction), ehci_async_buff(if PID is OUT)
			call ehci_control_io					; get devdesc with device address zero
			pop eax
			mov [ehci_dev_address], al
			cmp DWORD [ehci_res], 1
			jz	.Copy
			mov ebx, ehci_TrFailedAddr0Txt
			call gstdio_draw_text
			jmp .Back
.Copy		mov edi, usb_dev_desc
			mov esi, [ehci_async_buff]
			push ecx
			xor ecx, ecx
			mov cx, [ehci_len]
			rep movsb
			pop ecx
.SetAddr	mov esi, ehci_req_addr_packet
			mov WORD [ehci_len], 0
			mov BYTE [ehci_pid], 0
			mov al, [ehci_dev_address]
			mov [esi+USB_RECPAC_VALUE], al
			xor eax, eax
			mov al, [ehci_dev_address]
			mov BYTE [ehci_dev_address], 0
			push eax
			call ehci_control_io					; set address
			pop eax
			mov [ehci_dev_address], al
			mov ebx, 2								; setaddr recovery time
			call pit_delay
			cmp DWORD [ehci_res], 1
			jz	.Langs
			mov ebx, ehci_SetAddrFailedTxt
			call gstdio_draw_text
			jmp .Back
.Langs		mov esi, ehci_req_langs_packet
			mov WORD [ehci_len], 18					; we just request 18 bytes of the langids-string-descriptor
			mov ax, [ehci_len]
			mov [esi+USB_RECPAC_LENGTH], ax
			mov BYTE [esi+USB_RECPAC_IDX], 0
			mov BYTE [esi+USB_RECPAC_VALUE], 0
			mov BYTE [ehci_pid], 1
			call ehci_control_io
			cmp DWORD [ehci_res], 1
			jz	.StoreLgId
			mov ebx, ehci_GetLangsFailedTxt
			call gstdio_draw_text
			jmp .Back
.StoreLgId	mov ebx, [ehci_async_buff]
			add ebx, 2
			xor edx, edx
			mov dx, [ebx]
			mov [ehci_langid], dx
			cmp	BYTE [usb_dd_manuf_idx], 0			; is there a manufacturer-string?
			jz	.PrNoManuf
			mov esi, ehci_req_langs_packet
			mov WORD [ehci_len], 64
			mov ax, [ehci_len]
			mov [esi+USB_RECPAC_LENGTH], ax
			mov al, [ehci_langid]
			mov bl, [usb_dd_manuf_idx]
			mov BYTE [esi+USB_RECPAC_IDX], al
			mov BYTE [esi+USB_RECPAC_VALUE], bl
			mov BYTE [ehci_pid], 1
			call ehci_control_io					; get string
			cmp DWORD [ehci_res], 1
			jz	.PrManuf
			mov ebx, ehci_GetManufStringFailedTxt
			call gstdio_draw_text
			jmp .Back
.PrNoManuf	mov ebx, ehci_NoStringTxt
			call gstdio_draw_text
			jmp .PrSepar
.PrManuf	call ehci_print_string
.PrSepar	mov ebx, ehci_SeparatorTxt
			call gstdio_draw_text
			cmp	BYTE [usb_dd_prod_idx], 0			; is there a product-string?
			jnz	.ProdS
			mov ebx, ehci_NoStringTxt
			call gstdio_draw_text
			call gstdio_new_line
			jmp	.Back
.ProdS		mov esi, ehci_req_langs_packet
			mov WORD [ehci_len], 64
			mov ax, [ehci_len]
			mov [esi+USB_RECPAC_LENGTH], ax
			mov al, [ehci_langid]
			mov bl, [usb_dd_prod_idx]
			mov BYTE [esi+USB_RECPAC_IDX], al
			mov BYTE [esi+USB_RECPAC_VALUE], bl
			mov BYTE [ehci_pid], 1
			call ehci_control_io					; get string
			cmp DWORD [ehci_res], 1
			jz	.PrString
			mov ebx, ehci_GetProdStringFailedTxt
			call gstdio_draw_text
			jmp .Back
.PrString	call ehci_print_string
			; print port and devaddress
			mov ebx, ' '
			call gstdio_draw_char
			mov ebx, '('
			call gstdio_draw_char
			mov eax, ecx
			call gstdio_draw_dec
			mov ebx, ','
			call gstdio_draw_char
			xor eax, eax
			mov al, [ehci_dev_address]
			call gstdio_draw_dec
			mov ebx, ')'
			call gstdio_draw_char
			call gstdio_new_line
.Back		popad
			mov ebx, 1
			ret


; USED IN CONTROL TRANSFERS (Endpoint=0)
; IN: ESI(req_packet), ehci_len(bytenum of data), ehci_control_mps, ehci_pid(direction), ehci_async_buff(if PID is OUT)
; OUT: ehci_res, ehci_async_buff(if PID is IN), ehci_dev_address
ehci_control_io:
			pushad
			; calculate the number of TDs
			xor edx, edx
			xor eax, eax
			mov ax, [ehci_len]
			xor ebx, ebx
			mov bl, [ehci_control_mps]
			div ebx											; eax(quotient), edx(remainder)
			mov [ehci_td_num], eax
			add eax, 2										; Setup and Status TDs
			cmp edx, 0
			jz	.Alloc
			inc eax
			inc DWORD [ehci_td_num]
			; allocate TDs
.Alloc		mov ebx, EHCI_TD_SIZE
			mul	ebx
			mov ebx, 32
			call ehci_heap_alloc							; addr of TDs in EBX
			mov [ehci_async_tds], ebx
			; TDSetup
			mov eax, USB_REQUEST_PACKET_SIZE
			shl eax, 16
			or	eax, ((3 << 10) | (2 << 8) | 0x80)					; status-dword
			mov edx, esi											; buffer
			mov ecx, ebx											; next-td-ptr
			add ecx, EHCI_TD_SIZE
			mov edi, EHCI_QH_HS_T1									; alt-next-qtd-ptr
		; IN: EAX(Status-dword), EBX(address of TD), ECX(next-td-ptr), EDX(address of buffer), EDI(alt-next-td-ptr)
			call ehci_create_td
			add ebx, EHCI_TD_SIZE		
			cmp DWORD [ehci_td_num], 0
			jz	.StatusTD
			; TDs
			push ebx
			cmp BYTE [ehci_pid], 1
			jz	.In
			mov ebx, [ehci_async_buff]
			jmp .Creat
				; Allocate buffer
.In			xor eax, eax
			mov ax, [ehci_len]
			mov ebx, 1
			call ehci_heap_alloc
			mov [ehci_async_buff], ebx
				; create
.Creat		mov edx, ebx											; buffer
			pop ebx
			mov ebp, 1												; data-toggle bit
.TDio		xor eax, eax
			mov ax, [ehci_len]
			cmp DWORD [ehci_td_num], 1
			jz	.Sh
			xor eax, eax
			mov al, [ehci_control_mps]
.Sh			shl	eax, 16
			mov ecx, ebp
			shl ecx, 31
			or	eax, ecx
			or	eax, ((3 << 10) | 0x80)								; status-dword
			xor ecx, ecx
			mov cl, [ehci_pid]										; 	direction
			shl ecx, 8
			or	eax, ecx 
			mov ecx, ebx											; next-td-ptr
			add ecx, EHCI_TD_SIZE
			mov edi, ecx											; alt-next-qtd-ptr
		; IN: EAX(Status-dword), EBX(address of TD), ECX(next-td-ptr), EDX(address of buffer), EDI(alt-next-td-ptr)
			call ehci_create_td
			add ebx, EHCI_TD_SIZE							; inc address of TD
			dec DWORD [ehci_td_num]
;			cmp DWORD [ehci_td_num], 0
			jz	.StatusTD
			xor ecx, ecx
			mov cl, [ehci_control_mps]
			sub [ehci_len], cx
			add edx, ecx									; inc address of buff
			xor ebp, 1										; toggle dt
			jmp .TDio
			; TDStatus
.StatusTD	mov	eax, ((1 << 31) | (3 << 10) | 0x80)	; PID=0, PID is IN if no data-TDs or there are data-OUT-TDs!!	; status-dword
			cmp BYTE [ehci_pid], 0
			jnz	.STDOut
			or	eax, 1 << 8
.STDOut		mov edx, 0												; buffer
			mov ecx, EHCI_QH_HS_T1									; next-td-ptr
			mov edi, EHCI_QH_HS_T1									; alt-next-qtd-ptr
		; IN: EAX(Status-dword), EBX(address of TD), ECX(next-td-ptr), EDX(address of buffer), EDI(alt-next-td-ptr)
			call ehci_create_td
			; QH
			xor eax, eax											; EndPt
			xor ecx, ecx											; mps
			mov cl, [ehci_control_mps]
			xor edx, edx											; device address
			mov dl, [ehci_dev_address]
			mov ebp, [ehci_async_tds]								; addr of TDs
		; IN: EAX (EndPt), ECX(mps), EDX (device address), EBP (address of TDs)
			call ehci_create_qh
			mov [ehci_async_qh], ebx
			; Insert QH into QHs
			mov ecx, [ehci_async_qh]
			call ehci_insert_queue
			; Wait for result
			mov edx, [ehci_async_tds]
			mov ecx, 2000
			call ehci_wait_interrupt
			push DWORD [ehci_res]
			; Remove queue
			mov eax, [ehci_async_qh]
			call ehci_remove_queue
			pop eax
			mov [ehci_res], eax
			popad
			ret


; IN: EBX
;ehci_print_td:
;		pushad
;		mov edx, [ebx+EHCI_TD_OFF_NEXT_TD_PTR]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_TD_OFF_ALT_NEXT_QTD_PTR]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_TD_OFF_STATUS]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_TD_OFF_BUFF0_PTR]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_TD_OFF_BUFF1_PTR]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_TD_OFF_BUFF2_PTR]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_TD_OFF_BUFF3_PTR]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_TD_OFF_BUFF4_PTR]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		popad
;		ret


;ehci_print_qh:
;		pushad
;		mov ebx, ehci_QHTxt
;		call gstdio_draw_text
;		mov ebx, [ehci_async_qh]
;		mov edx, [ebx+EHCI_QH_OFF_HORZ_PTR]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_QH_OFF_ENDPT_CAPS]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_QH_OFF_HUB_INFO]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_QH_OFF_CUR_QTD_PTR]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_QH_OFF_NEXT_QTD_PTR]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_QH_OFF_ALT_NEXT_QTD_PTR]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		mov edx, [ebx+EHCI_QH_OFF_STATUS]
;		call gstdio_draw_hex
;		call gstdio_new_line
;		popad
;		ret



; allocates some memory in our heap on the alignment specified, rouding up to the nearest dword
; Checks for errors, but does not return an error.  Simply "exits" if error found
; will clear the memory to zero
; returns physical address of memory found
; alignment and boundary must be a power of 2
; IN: EAX(size), EBX(alignment)
; OUT: EBX (memaddr 32bit)
ehci_heap_alloc:
			pushad
			; align to the next alignment
			mov ecx, [ehci_cur_heap_ptr]
			add ecx, ebx
			dec ecx
			dec ebx
			not ebx
			and ecx, ebx
			mov [ehci_cur_heap_ptr], ecx
			; round up to the next dword size
			add eax, 3
			and eax, ~3
			; clear it to zeros
			mov edi, ecx
			mov ecx, eax
			push eax
			mov al, 0
			rep stosb
			pop eax
			; update our pointer for next time
			mov ebx, [ehci_cur_heap_ptr]
			add [ehci_cur_heap_ptr], eax
			mov [ehci_res], ebx
			popad
			mov ebx, [ehci_res]
			ret


; from PrettyOS
ehci_enable_async_listPO:
			pushad
			mov edx, [ehci_bar]
			xor eax, eax
			mov al, [ehci_opbaseoffs]
			add edx, eax
			mov edi, edx
			add edx, EHCI_OPS_USBStatus
			add edi, EHCI_OPS_USBCommand
	; EDI(USBCommand), EDX(USBStatus)		
			mov DWORD [ehci_res], 1
			or	DWORD [edi], (1 << 5)
			mov ecx, 7
.Test		test DWORD [edx], (1 << 15)
			jnz	.Back
			mov ebx, 10
			call pit_delay
			loop .Test
			mov DWORD [ehci_res], 0
.Back		popad
			ret


; enable/disable one of the lists.
; if the async member is set, it disables/enables the asynchronous list, else the periodic list
; IN: ESI (1 is TRUE, 0 is FALSE)
; OUT: ehci_res
ehci_enable_async_list:
			pushad
			; first make sure that both bits are the same
			; should not modify the enable bit unless the status bit has the same value
			mov edx, [ehci_bar]
			xor eax, eax
			mov al, [ehci_opbaseoffs]
			add edx, eax
			mov edi, edx
			add edx, EHCI_OPS_USBStatus
			add edi, EHCI_OPS_USBCommand
	; EDI(USBCommand), EDX(USBStatus)
			mov ebp, [edi]	; EBP is command
			mov eax, (1  << 15)
			mov ebx, 0
			test ebp, (1 << 5)
			jz	.Skip
			mov ebx, (1 << 15)
.Skip		mov ecx, 100
			call ehci_handshake
			cmp ebx, 1
			jnz	.Back
			cmp esi, 1
			jnz	.Else
			mov ebx, 0
			test ebp, (1 << 5)
			jnz	.Skip2
			or	ebp, (1 << 5)
			mov [edi], ebp			; !!??
.Skip2		mov eax, (1 << 15)
			mov ebx, (1 << 15)
			mov ecx, 100
			call ehci_handshake
			jmp .Back
.Else		test ebp, (1 << 5)
			jz	.Skip3
			and	ebp, ~(1 << 5)
			mov [edi], ebp			; !!??
.Skip3		mov eax, (1 << 15)
			mov ebx, 0
			mov ecx, 100
			call ehci_handshake
.Back		mov [ehci_res], ebx
			popad
			ret


; This routine waits for the value read at (base, reg) and'ed by mask to equal result.
; It returns TRUE if this happens before the alloted time expires
; returns FALSE if this does not happen
; IN: EDX(reg); EAX(MASK); EBX(result); ECX(ms)
; OUT: EBX
ehci_handshake:
			push ecx
			push ebp
.Check		mov ebp, [edx]
			and ebp, eax
			cmp ebp, ebx
			jz	.Ok
			push ebx
			mov ebx, 1
			call pit_delay
			pop ebx
			dec ecx
			jnz	.Check
			mov ebx, 0
			jmp .Back
.Ok			mov ebx, 1
.Back		pop ebp
			pop ecx
			ret


; initialize the async queue list (Control and Bulk TD's)
; IN: EBX (async_base)
ehci_init_stack_frame:
			pushad
			; the async queue (Control and Bulk TD's) is a round robin set of 16 Queue Heads.
			mov ecx, 0
.Next		mov [ebx+EHCI_QH_OFF_HORZ_PTR], ebx
			add DWORD [ebx+EHCI_QH_OFF_HORZ_PTR], EHCI_QUEUE_HEAD_SIZE
			or	DWORD [ebx+EHCI_QH_OFF_HORZ_PTR], (EHCI_QH_HS_TYPE_QH | EHCI_QH_HS_T0)
			mov DWORD [ebx+EHCI_QH_OFF_ENDPT_CAPS], ((0 << 16) | (2 << 12) | (0 << 8) | 0)
			cmp ecx, 0
			jnz .Skip
			or	DWORD [ebx+EHCI_QH_OFF_ENDPT_CAPS], (1 << 15)
.Skip		mov DWORD [ebx+EHCI_QH_OFF_HUB_INFO], (1 << 30)
			mov DWORD [ebx+EHCI_QH_OFF_NEXT_QTD_PTR], EHCI_QH_HS_T1
			mov DWORD [ebx+EHCI_QH_OFF_ALT_NEXT_QTD_PTR], EHCI_QH_HS_T1
			add ebx, EHCI_QUEUE_HEAD_SIZE
			inc ecx
			cmp ecx, EHCI_QHS_NUM
			jnge .Next
			; backup and point the last one at the first one
			sub ebx, EHCI_QUEUE_HEAD_SIZE
			mov eax, [ehci_async_base]
			or	eax, (EHCI_QH_HS_TYPE_QH | EHCI_QH_HS_T0)
			mov DWORD [ebx+EHCI_QH_OFF_HORZ_PTR], eax
			popad
			ret


; Release BIOS ownership of controller
; On Entry:
;      pci: bus(EAX), EBX(device), ECX(function)
;   params: the dword value of the capability register
; On Return:
;   TRUE if ownership released (EBX)
;
; Set bit 24 to indicate to the BIOS to release ownership
; The BIOS should clear bit 16 indicating that it has successfully done so
; Ownership is released when bit 24 is set *and* bit 16 is clear.
; This will wait EHCI_LEGACY_TIMEOUT ms for the BIOS to release ownership.
;   (It is unknown the exact time limit that the BIOS has to release ownership.)
;ehci_stop_legacy:
;;			push eax		; eax is not necessary to push
;;			push ebx		; ebx is not necessary to push
;			push edx
;			push ebp
;			mov edx, [ehci_hccparams]
;			and edx, 0x0000FF00
;			shr	edx, 8
;			cmp dl, 0x40
;			jnge .True
;			; set bit 24 asking the BIOS to release ownership
;			add edx, EHCI_LEGACY_USBLEGSUP
;			push eax
;			call pci_config_read_dword
;			or	eax, EHCI_LEGACY_OS_OWNED
;			mov DWORD [pci_tmp], eax
;			pop eax
;			call pci_config_write_dword 
;			; Timeout if bit 24 is not set and bit 16 is not clear after EHCI_LEGACY_TIMEOUT milliseconds
;			mov ebp, EHCI_LEGACY_TIMEOUT
;.Read		push eax
;			call pci_config_read_dword
;			and eax, EHCI_LEGACY_OWNED_MASK
;			cmp eax, EHCI_LEGACY_OS_OWNED
;			pop eax
;			jz	.True
;			push ebx
;			mov ebx, 1
;			call pit_delay
;			pop ebx
;			dec ebp
;			jnz	.Read
;			mov ebx, 0
;			jmp .Back
;.True		mov ebx, 1
;.Back		pop ebp
;			pop edx
;;			pop ebx
;;			pop eax
;			ret


; from PrettyOS
; On Entry:
;      pci: bus(EAX), EBX(device), ECX(function)
;   params: the dword value of the capability register
; On Return:
ehci_stop_legacyPO:
			push ebp
			push edx
			mov edx, [ehci_hccparams]
			shr	edx, 8
			and edx, 0x000000FF
;	cf. EHCI 1.0 spec, 2.2.4 HCCPARAMS - Capability Parameters, Bit 15:8 (BYTE2)
;	EHCI Extended Capabilities Pointer (EECP). Default = Implementation Dependent.
;	This optional field indicates the existence of a capabilities list.
;	A value of 00h indicates no extended capabilities are implemented.
;	A non-zero value in this register indicates the offset in PCI configuration space
;	of the first EHCI extended capability. The pointer value must be 40h or greater
;	if implemented to maintain the consistency of the PCI header defined for this class of device.
;	// cf. http://wiki.osdev.org/PCI#PCI_Device_Structure
;	//   eecp		// RO - This field identifies the extended capability.
;					//      01h identifies the capability as Legacy Support.
			cmp dl, 0x40
			jnge .True
			mov BYTE [ehci_eecp_id], 0
.NextCap	cmp dl, 0		 					; 00h indicates end of the ext. cap. list.
			jz	.Skip
			push eax
			call pci_config_read_byte
			mov BYTE [ehci_eecp_id], al
			pop eax
			cmp BYTE [ehci_eecp_id], 1
			jz	.Skip
			inc dl	;edx
			push eax
			call pci_config_read_byte
			mov dl, al
			pop eax
			jmp .NextCap
.Skip		mov BYTE [ehci_bios_owned_semaphore], dl
			add BYTE [ehci_bios_owned_semaphore], 2		; R/W - only Bit 16 (Bit 23:17 Reserved, must be set to zero)
			mov BYTE [ehci_os_owned_semaphore], dl
			add BYTE [ehci_os_owned_semaphore], 3		; R/W - only Bit 24 (Bit 31:25 Reserved, must be set to zero)
			mov BYTE [ehci_usblegctlsts], dl
			add BYTE [ehci_usblegctlsts], 4		; USB Legacy Support Control/Status (DWORD, cf. EHCI 1.0 spec, 2.1.8)
			; Legacy-Support-EC found? BIOS-Semaphore set?
			cmp BYTE [ehci_eecp_id], 1
			jnz	.True
		xor edx, edx
			mov dl, [ehci_bios_owned_semaphore]
			push eax
			call pci_config_read_byte
			and al, 0x01
			pop eax
			jz	.True
			mov BYTE [pci_tmp], 0x01
		xor edx, edx
			mov dl, [ehci_os_owned_semaphore]
			call pci_config_write_byte
			; Wait for BIOS-Semaphore being not set
			mov ebp, 250
		xor edx, edx
			mov dl, [ehci_bios_owned_semaphore]
.Read		push eax
			call pci_config_read_byte
			and al, 0x01
			pop eax
			jz	.ChkBO
			push ebx
			mov ebx, 10
			call pit_delay
			pop ebx
			dec ebp
			jnz	.Read
.ChkBO		push eax
			call pci_config_read_byte
			and al, 0x01
			pop eax
			jnz	.Write
			mov ebp, 250
		xor edx, edx
			mov dl, [ehci_os_owned_semaphore]
.Read2		push eax
			call pci_config_read_byte
			and al, 0x01
			pop eax
			jnz	.Write
			push ebx
			mov ebx, 10
			call pit_delay
			pop ebx
			dec ebp
			jnz	.Read2
.Write		mov DWORD [pci_tmp], 0
			xor edx, edx
			mov dl, [ehci_usblegctlsts]
			call pci_config_write_byte
.True		mov ebx, 1
.Back		pop edx
			pop ebp
			ret


; IN: EAX (EndPt), ECX(mps), EDX (device address), EBP (address of TDs)
; OUT: EBX (address of QH)
ehci_create_qh:
			push eax
			push ecx
			push eax
			mov eax, EHCI_QUEUE_HEAD_SIZE
			mov ebx, 32
			call ehci_heap_alloc
			pop eax
			; set EndPt
			shl eax, 8
			; fill
			mov DWORD [ebx+EHCI_QH_OFF_HORZ_PTR], 1
			shl	ecx, 16
			or	eax, ecx
			or	eax, ((8 << 28)	| (1 << 14) | (2 << 12))
			mov [ebx+EHCI_QH_OFF_ENDPT_CAPS], eax
			or	[ebx+EHCI_QH_OFF_ENDPT_CAPS], edx				; setting device address
			mov DWORD [ebx+EHCI_QH_OFF_HUB_INFO], (1 << 30)
			mov [ebx+EHCI_QH_OFF_NEXT_QTD_PTR], ebp
			pop ecx
			pop eax
			ret


; IN: EAX(Status-dword), EBX(address of TD), ECX(next-td-ptr), EDX(address of buffer), EDI(alt-next-td-ptr)
ehci_create_td:
			pushad
			; fill
			mov [ebx+EHCI_TD_OFF_STATUS], eax
			mov [ebx+EHCI_TD_OFF_NEXT_TD_PTR], ecx
			mov [ebx+EHCI_TD_OFF_ALT_NEXT_QTD_PTR], edi	
			; set low 32 bits of buffersptr
			mov [ebx+EHCI_TD_OFF_BUFF0_PTR], edx
			cmp edx, 0		; is buffer=0? (Status-TD?)
			jz	.Back
			add edx, 0x1000
			and edx, ~0x0FFF		; !?
			mov [ebx+EHCI_TD_OFF_BUFF1_PTR], edx
			mov [ebx+EHCI_TD_OFF_BUFF2_PTR], edx
			add DWORD [ebx+EHCI_TD_OFF_BUFF2_PTR], 0x1000
			mov [ebx+EHCI_TD_OFF_BUFF3_PTR], edx
			add DWORD [ebx+EHCI_TD_OFF_BUFF3_PTR], 0x2000
			mov [ebx+EHCI_TD_OFF_BUFF4_PTR], edx
			add DWORD [ebx+EHCI_TD_OFF_BUFF4_PTR], 0x3000
.Back		popad
			ret


; IN: ECX(address of QH)
ehci_insert_queue:
			pushad
			mov ebx, [ehci_async_base]
			mov eax, [ebx+EHCI_QH_OFF_HORZ_PTR]	; eax is QHs[0]'s next ptr
			add ecx, EHCI_QH_OFF_HORZ_PTR
			mov [ecx], eax
			mov [ebx+EHCI_QH_OFF_HORZ_PTR], ecx
			or	DWORD [ebx+EHCI_QH_OFF_HORZ_PTR], EHCI_QH_HS_TYPE_QH
			popad
			ret


; removes a queue from the async list
; EHCI section 4.8.2, shows that we must watch for three bits before we have "fully and successfully" removed
;   the queue(s) from the list
; IN: EAX(queue)
; OUT: EBX
ehci_remove_queue:
			pushad
			mov ebp, [eax+EHCI_QH_OFF_HORZ_PTR]
			mov ebx, [ehci_async_base]
			mov [ebx+EHCI_QH_OFF_HORZ_PTR], ebp
			; now wait for the successful "doorbell"
			; set bit 6 in command register (to tell the controller that something has been removed from the schedule)
			; then watch for bit 5 in the status register.  Once it is set, we can assume all removed correctly.
			; We ignore the interrupt on async bit in the USBINTR.  We don't need an interrupt here.
			mov edx, [ehci_bar]
			xor eax, eax
			mov al, [ehci_opbaseoffs]
			add edx, eax
			add edx, EHCI_OPS_USBCommand
			or	DWORD [edx], (1 << 6)
			sub edx, EHCI_OPS_USBCommand
			add edx, EHCI_OPS_USBStatus
			mov eax, (1 << 5)
			mov ebx, (1 << 5)
			mov ecx, 100
			call ehci_handshake
			cmp ebx, 1
			jnz	.False
			or	DWORD [edx], (1 << 5)	; DIFF			; acknowledge the bit
			jmp .True
.False		mov ebx, ehci_removeQueueFailedTxt
			call gstdio_draw_text
			popad
			mov ebx, 0
			jmp .Back
.True		popad
			mov ebx, 1
.Back		ret



; IN: EDX(addr), ECX(timeout)
; OUT: ehci_res
ehci_wait_interrupt:
			pushad
			mov ebx, -1
.Wait		mov eax, [edx+EHCI_TD_OFF_STATUS]
			and eax, ~1								; ignore bit 0 (?)
			test eax, 0x80							; active bit is clear? If not jump to Delay
			jnz	.Delay
			mov ebx, USB_SUCCESS
			test eax, 0x7F
			jz	.NextTD
			test eax, (1 << 6)
			jz	.ChkDBuff
			mov ebx, USB_ERROR_STALLED
			jmp .ChkRet
.ChkDBuff	test eax, (1 << 5)
			jz	.ChkBabble
			mov ebx, USB_ERROR_DATA_BUFFER_ERROR
			jmp .ChkRet
.ChkBabble	test eax, (1 << 4)
			jz	.ChkNAK
			mov ebx, USB_ERROR_BABBLE_DETECTED
			jmp .ChkRet
.ChkNAK		test eax, (1 << 3)
			jz	.ChkTime
			mov ebx, USB_ERROR_NAK
			jmp .ChkRet
.ChkTime	test eax, (1 << 2)
			jz	.Unknown
			mov ebx, USB_ERROR_TIME_OUT
			jmp .ChkRet
.Unknown	mov ebx, ehci_WaitInterruptTxt
			call gstdio_draw_text
			mov edx, eax
			call gstdio_draw_text
			call gstdio_new_line
			mov ebx, USB_ERROR_UNKNOWN
			jmp .ChkRet
.NextTD		mov ebp, eax
			and ebp, 0x7FFF0000
			shr	ebp, 16
			cmp ebp, 0
			jng	.Else
			and eax, (3 << 8)
			shr	eax, 8
			cmp eax, 1
			jnz	.Else
			test DWORD [edx+EHCI_TD_OFF_ALT_NEXT_QTD_PTR], 1
			jnz	.ChkRet
			mov edx, [edx+EHCI_TD_OFF_ALT_NEXT_QTD_PTR]
			jmp .Delay
.Else		test DWORD [edx+EHCI_TD_OFF_NEXT_TD_PTR], 1
			jnz	.ChkRet
			mov edx, [edx+EHCI_TD_OFF_NEXT_TD_PTR]
.Delay		push ebx
			mov ebx, 1
			call pit_delay
			pop ebx
			dec ecx
			jz	.ChkRet
			jmp .Wait
.ChkRet		mov DWORD [ehci_res], 1
			cmp ebx, -1
			jz	.TO
			cmp ebx, USB_SUCCESS
			jz	.Back
			mov ebx, ehci_InterruptErr
			call gstdio_draw_text	
			mov DWORD [ehci_res], 0
			jmp .Back
.TO			mov ebx, ehci_InterruptTOTxt
			call gstdio_draw_text
			mov DWORD [ehci_res], 0
.Back		popad
			ret


; IN:
; OUT: ehci_res
ehci_bulk_reset:
			pushad
			mov esi, ehci_req_bulkreset_packet
			mov WORD [ehci_len], 0
			mov BYTE [ehci_pid], 0
			call ehci_control_io
			cmp DWORD [ehci_res], 1
			jz	.ResetE1
			mov ebx, ehci_BulkResetFailedTxt
			call gstdio_draw_text
			jmp .Err
.ResetE1	mov esi, ehci_req_bulkendptreset_packet
			mov BYTE [esi+USB_RECPAC_IDX], 1
			mov WORD [ehci_len], 0
			mov BYTE [ehci_pid], 0
			call ehci_control_io
			cmp DWORD [ehci_res], 1
			jz	.ResetE2
			mov ebx, ehci_BulkE1ResetFailedTxt
			call gstdio_draw_text
			jmp .Err
.ResetE2	mov esi, ehci_req_bulkendptreset_packet
			mov BYTE [esi+USB_RECPAC_IDX], 2
			mov WORD [ehci_len], 0
			mov BYTE [ehci_pid], 0
			call ehci_control_io
			cmp DWORD [ehci_res], 1
			jz	.Back
			mov ebx, ehci_BulkE2ResetFailedTxt
			call gstdio_draw_text
.Err		mov DWORD [ehci_res], 0
.Back		mov ebx, 100			; DELAY
			call pit_delay
			popad
			ret


; IN: AL(Endpt-byte)
; OUT: AL(EndptNum)
ehci_save_endptnum:
			bt	ax, 7			
			jc	.EptIn
			and al, 0x0F
			mov [ehci_bulkout_endpt], al
			ret
.EptIn		and al, 0x0F
			mov [ehci_bulkin_endpt], al
			ret


; IN: AL(EndptNum), BX(MPS of Endpt)
ehci_save_endpt_mps:
			cmp al, 1
			jz	.In
			mov [ehci_bulkout_mps], bx
			ret
.In			mov [ehci_bulkin_mps], bx
			ret


; IN: ESI(buffer-ptr)
; OUT:
; THS FUNCTION HAS BUGS!! SEE THE FIX IN EHCI.ASM
ehci_save_endpts:
			pushad
			xor eax, eax
			mov al, [esi]
			add esi, eax
			add esi, 4								; Endpoints-byte
			cmp BYTE [esi], 1
			ja	.GetEPts
			mov ebx, ehci_EndptsErrTxt
			call gstdio_draw_text
			mov DWORD [ehci_res], 0
			jmp	.Back
.GetEPts	sub esi, 4
			xor eax, eax
			mov al, [esi]
			add esi, eax
			add esi, 2								; Endpt-byte
			mov al, [esi]
			call ehci_save_endptnum
			sub esi, 2
			mov bx, [esi+4]							; MPS
			call ehci_save_endpt_mps
			xor eax, eax
			mov al, [esi]
			add esi, eax
			add esi, 2
			mov al, [esi]
			call ehci_save_endptnum
			sub esi, 2
			mov bx, [esi+4]							; MPS
			call ehci_save_endpt_mps
			mov DWORD [ehci_res], 1
.Back		popad
			ret


; ************* WORDS

; IN: EAX(device address), EDX(idx)
; OUT: ehci_res
; memdump of device-descriptor, configuration-descriptor (including Interface and Endpoints descriptors)
; saves mps and endpts
; If device is a Mass-Storage one (0x08), then prints MaxLun
ehci_dev_info:
			pushad
			mov DWORD [ehci_res], 0
			mov [ehci_dev_address], al
			; check heap_ptr, if it contains its initial value, then no USBENUM was called
			cmp DWORD [ehci_cur_heap_ptr], EHCI_HEAP_INIT
			jz	.Back
			cmp edx, 0
			jz	.Dev
			call gstdio_new_line
			mov ebx, ehci_gettingDescriptorTxt
			call gstdio_draw_text
.Dev		mov esi, ehci_req_desc_packet
			mov WORD [ehci_len], 18
			mov ax, [ehci_len]
			mov [esi+USB_RECPAC_LENGTH], ax
			mov BYTE [ehci_pid], 1
			call ehci_control_io					; get devdesc with device address zero
			cmp DWORD [ehci_res], 1
			jz	.SaveMPS
			mov ebx, ehci_failedTxt
			call gstdio_draw_text
			jmp	.Rest
.SaveMPS	mov esi, [ehci_async_buff]
			add esi, USB_DEVDESC_MAX_PACETSIZE
			mov bl, [esi]
			mov [ehci_control_mps], bl
			cmp edx, 0								; print?
			jz	.Conf
			call gstdio_new_line
			mov esi, [ehci_async_buff]
			mov ecx, 18
			call gutil_mem_dump
			call gstdio_new_line
.Conf		cmp edx, 2
			jnz	.Conf2
			mov ebx, ehci_gettingConfigTxt
			call gstdio_draw_text
			; first get 64 bytes and check totalLength of the returned data, if greater than 64, then request totalLength
.Conf2		mov esi, ehci_req_config_packet
			mov WORD [ehci_len], 64					; or mps!?
			mov ax, [ehci_len]
			mov [esi+USB_RECPAC_LENGTH], ax
			mov BYTE [ehci_pid], 1
			call ehci_control_io					; get config-desc, 64 bytes
			cmp DWORD [ehci_res], 1
			jz	.ChkCfgLen
			mov ebx, ehci_failedTxt
			call gstdio_draw_text
			jmp	.Rest
.ChkCfgLen	mov esi, [ehci_async_buff]
			add esi, 2								; address of totalLength
			cmp WORD [esi], 64						; or mps!?
			jna	.SaveEndpts
			mov esi, ehci_req_config_packet
			mov ax, [esi]
			mov [ehci_len], ax
			mov [esi+USB_RECPAC_LENGTH], ax
			mov BYTE [ehci_pid], 1
			call ehci_control_io					; get config-desc, 64 bytes
			cmp DWORD [ehci_res], 1
			jz	.SaveEndpts
			mov ebx, ehci_failedTxt
			call gstdio_draw_text
			jmp	.Rest
.SaveEndpts	mov esi, [ehci_async_buff]
			call ehci_save_endpts
			cmp DWORD [ehci_res], 1
			jnz	.Rest
			cmp edx, 2
			jnz	.LUN
			call gstdio_new_line
			mov esi, [ehci_async_buff]
			mov eax, esi
			add eax, 2
			xor ecx, ecx
			mov cx, [eax]
			call gutil_mem_dump
			; should we set the configuration, or the currently set zero is OK!?
			; get MaxLun if device is a Pen-drive
.LUN		mov esi, [ehci_async_buff]
			add esi, 4								; address of NumInterfaces
			cmp BYTE [esi], 0						; no interfaces?
			jz	.Rest
			sub esi, 4
			xor ebx, ebx
			mov bl, [esi]
			add esi, ebx							; we are now at the beginning of the Interface Descriptor
			add esi, 5								; address of Class-code
			cmp BYTE [esi], 0x08					; Mass Storage?
			jnz	.Rest
			cmp edx, 2
			jnz	.LUN2
			call gstdio_new_line
			mov ebx, ehci_gettingLUNTxt
			call gstdio_draw_text
.LUN2		mov esi, ehci_req_lun_packet
			mov WORD [ehci_len], 1
			mov BYTE [ehci_pid], 1
			call ehci_control_io					; get LUN
			cmp DWORD [ehci_res], 1
			jz	.PrLUN
			mov ebx, ehci_failedTxt
			call gstdio_draw_text
			jmp	.Rest
.PrLUN		cmp edx, 2
			jnz	.Rest
			mov ebx, [ehci_async_buff]
			mov dl, [ebx]
			cmp dl, 0xFF
			jnz	.StoreLUN
			mov dl, 0
.StoreLUN	mov [ehci_max_lun], dl
			call gstdio_new_line
			mov ebx, ehci_MaxLunTxt
			call gstdio_draw_text
			mov dh, [ehci_max_lun]					; prints zero, but if it would be FF then it should mean zero as well!
			call gstdio_draw_hex8
			call gstdio_new_line
			; restore heap_ptr
.Rest		mov ebx, [ehci_cur_heap_ptr_afterenum]
			mov [ehci_cur_heap_ptr], ebx
.Back		popad
			ret


; IN: EAX(device address)
; OUT: ehci_res, lbaHi, lbaLO, sectorsize
ehci_init_msd:
			pushad
			mov DWORD [ehci_res], 0
			mov [ehci_dev_address], al
			mov DWORD [ehci_lbahi], 0
			mov DWORD [ehci_lbalo], 0
			mov DWORD [ehci_sector_size], 0
			; check heap_ptr, if it contains its initial value, then no USBENUM was called
			cmp DWORD [ehci_cur_heap_ptr], EHCI_HEAP_INIT
			jz	.Back
			mov esi, ehci_set_config_packet
			mov WORD [ehci_len], 0
			mov BYTE [ehci_pid], 0
			call ehci_control_io						; set config
			cmp DWORD [ehci_res], 1
			jz	.Init
			mov ebx, ehci_SetConfigFailedTxt
			call gstdio_draw_text
			jmp .Rest
.Init		call ehci_bulk_reset						; to clear data-toggles of Endpt-s
			cmp DWORD [ehci_res], 1
			jnz	.Rest
			mov ebx, 100								; DELAY
			call pit_delay
			mov DWORD [ehci_bulkin_dt], 0
			mov DWORD [ehci_bulkout_dt], 0
			call ehci_inquiry_req
			cmp DWORD [ehci_res], 1
			jnz	.Rest
			call ehci_testunit_req
			cmp DWORD [ehci_res], 1
			jnz	.Rest
			call ehci_sense_req
			cmp DWORD [ehci_res], 1
			jnz	.Rest
			call ehci_testunit_req
			cmp DWORD [ehci_res], 1
			jnz	.Rest
			mov eax, ehci_read_capacity10_cbw
			mov ecx, 8
			call ehci_capacity_req
			cmp DWORD [ehci_lbalo], 0xFFFFFFFF
			jnz	.Rest
			mov eax, ehci_read_capacity16_cbw
			mov ecx, 32
			call ehci_capacity_req
;			cmp DWORD [ehci_res], 1
;			jz	.Rest
			; restore heap_ptr
.Rest		mov edx, [ehci_cur_heap_ptr_afterenum]
			mov [ehci_cur_heap_ptr], edx
.Back		popad
			mov ebx, [ehci_lbahi]
			mov ecx, [ehci_lbalo]
			mov edx, [ehci_sector_size]
			ret


; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: ehci_res
ehci_read_msd:
			pushad
			mov DWORD [ehci_res], 0
			; check heap_ptr, if it contains its initial value, then no USBENUM was called
			cmp DWORD [ehci_cur_heap_ptr], EHCI_HEAP_INIT
			jz	.Back
			cmp eax, [ehci_lbahi]
			jna	.ChkLO
			jmp .Err
.ChkLO		cmp ebx, [ehci_lbalo]
			jc	.Read
.Err		mov ebx, ehci_LBATooBigTxt
			call gstdio_draw_text
			jmp	.Back
.Read		cmp eax, 0											; LBA-Hi is zero ?
			jz	.Read10
			call ehci_read16_req
			jmp .Rest
.Read10		call ehci_read10_req
.Rest		mov ebx, [ehci_cur_heap_ptr_afterenum]
			mov [ehci_cur_heap_ptr], ebx
.Back		popad
			ret
			

; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: ehci_res
ehci_write_msd:
			pushad
			mov DWORD [ehci_res], 0
			; check heap_ptr, if it contains its initial value, then no USBENUM was called
			cmp DWORD [ehci_cur_heap_ptr], EHCI_HEAP_INIT
			jz	.Back
			cmp eax, [ehci_lbahi]
			jna	.ChkLO
			jmp .Err
.ChkLO		cmp ebx, [ehci_lbalo]
			jc	.Read
.Err		mov ebx, ehci_LBATooBigTxt
			call gstdio_draw_text
			jmp	.Back
.Read		cmp eax, 0											; LBA-Hi is zero ?
			jz	.Read10
			call ehci_write16_req
			jmp .Rest
.Read10		call ehci_write10_req
.Rest		mov ebx, [ehci_cur_heap_ptr_afterenum]
			mov [ehci_cur_heap_ptr], ebx
.Back		popad
			ret
			


; ************* END OF WORDS


; **** SCSI

; IN: EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: ehci_res
; 32bit EBX: 4GB * 512 bytes can be addressed (~2097151 GB)
; 65535*512 bytes can be read at a time (~32 GB)
ehci_read10_req:
			pushad
			mov esi, ehci_read10_cbw
			mov ebp, [esi+4]
			mov [ehci_curr_tag], ebp
			add esi, USB_CBW_COMMAND_OFFS
			add esi, 2
			bswap ebx							; to big-endian
			mov [esi], ebx
			add esi, 5
			mov bx, dx
			xchg bl, bh							; to big-endian
			mov [esi], bx
			mov esi, ehci_read10_cbw
			add esi, USB_CBW_TOTALBYTES_OFFS
			xor eax, eax
			mov ax, dx
			mov ebx, [ehci_sector_size]
			mul ebx
			mov [esi], eax			
			mov ebx, eax
			mov eax, ehci_read10_cbw
			mov [ehci_async_buff], eax
			mov DWORD [ehci_bulk_len], EHCI_CBW_LEN
			mov ax, [ehci_bulkout_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 0
			mov eax, [ehci_bulkout_dt]
			mov [ehci_bulk_dt], eax
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkout_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.Get
			mov ebx, ehci_SendRead10CBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.Get		mov [ehci_bulk_len], ebx
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov [ehci_async_buff], ecx					; set memaddr
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ReadCSW
			mov ebx, ehci_GetRead10DataFailedTxt
			call gstdio_draw_text
			jmp .Err
.ReadCSW	mov DWORD [ehci_bulk_len], EHCI_CSW_LEN
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov DWORD [ehci_async_buff], 0
			call ehci_bulk_io		
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ChkCSW
			mov ebx, ehci_Read10Txt
			call gstdio_draw_text
			mov ebx, ehci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ChkCSW		mov ecx, ehci_Read10Txt
			call ehci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [ehci_res], 0
.Back		popad
			ret


; IN: ECX(txtPtr), ehci_async_buff, ehci_curr_tag
; OUT: EAX(0 ERR)
ehci_check_csw:
			mov eax, 0
			mov ebx, [ehci_async_buff]
			mov edx, [ehci_curr_tag]
			cmp [ebx+4], edx
			jz	.Status
			mov ebx, ehci_CSWTagMismatchTxt
			call gstdio_draw_text		
			jmp .Back
.Status		cmp BYTE [ebx+9], 0
			jz	.Ok
			mov ebx, ecx
			call gstdio_draw_text		
			mov ebx, ehci_CSWStatusFailedTxt
			call gstdio_draw_text		
			jmp .Back
.Ok			mov eax, 1
.Back		ret


; IN: EAX(LBAHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: ehci_res
ehci_read16_req:
			pushad
			mov esi, ehci_read16_cbw
			mov ebp, [esi+4]
			mov [ehci_curr_tag], ebp
			add esi, USB_CBW_COMMAND_OFFS
			add esi, 2
			bswap eax							; to big-endian
			mov [esi], eax
			add esi, 4
			bswap ebx							; to big-endian
			mov [esi], ebx
			add esi, 4
			mov ebx, edx
			bswap ebx							; to big-endian
			mov [esi], ebx
			mov esi, ehci_read16_cbw
			add esi, USB_CBW_TOTALBYTES_OFFS
			mov eax, edx
			mov ebx, [ehci_sector_size]
			mul ebx
			mov [esi], eax			
			mov ebx, eax
			mov eax, ehci_read16_cbw
			mov [ehci_async_buff], eax
			mov DWORD [ehci_bulk_len], EHCI_CBW_LEN
			mov ax, [ehci_bulkout_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 0
			mov eax, [ehci_bulkout_dt]
			mov [ehci_bulk_dt], eax
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkout_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.Get
			mov ebx, ehci_SendRead16CBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.Get		mov [ehci_bulk_len], ebx
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov [ehci_async_buff], ecx					; set memaddr
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ReadCSW
			mov ebx, ehci_GetRead16DataFailedTxt
			call gstdio_draw_text
			jmp .Err
.ReadCSW	mov DWORD [ehci_bulk_len], EHCI_CSW_LEN
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov DWORD [ehci_async_buff], 0
			call ehci_bulk_io		
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ChkCSW
			mov ebx, ehci_Read16Txt
			call gstdio_draw_text
			mov ebx, ehci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ChkCSW		mov ecx, ehci_Read16Txt
			call ehci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [ehci_res], 0
.Back		popad
			ret


; IN: EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: ehci_res
; 32bit EBX: 4GB * 512 bytes can be addressed (~2097151 GB)
; 65535*512 bytes can be written at a time (~32 GB)
ehci_write10_req:
			pushad
			mov esi, ehci_write10_cbw
			mov ebp, [esi+4]
			mov [ehci_curr_tag], ebp
			add esi, USB_CBW_COMMAND_OFFS
			add esi, 2
			bswap ebx							; to big-endian
			mov [esi], ebx
			add esi, 5
			mov bx, dx
			xchg bl, bh							; to big-endian
			mov [esi], bx
			mov esi, ehci_write10_cbw
			add esi, USB_CBW_TOTALBYTES_OFFS
			xor eax, eax
			mov ax, dx
			mov ebx, [ehci_sector_size]
			mul ebx
			mov [esi], eax			
			mov ebx, eax
			mov eax, ehci_write10_cbw
			mov [ehci_async_buff], eax
			mov DWORD [ehci_bulk_len], EHCI_CBW_LEN
			mov ax, [ehci_bulkout_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 0
			mov eax, [ehci_bulkout_dt]
			mov [ehci_bulk_dt], eax
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkout_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.Send
			mov ebx, ehci_SendWrite10CBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.Send		mov [ehci_bulk_len], ebx
			mov ax, [ehci_bulkout_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 0
			mov eax, [ehci_bulkout_dt]
			mov [ehci_bulk_dt], eax
			mov [ehci_async_buff], ecx					; set memaddr
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkout_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ReadCSW
			mov ebx, ehci_SendWrite10DataFailedTxt
			call gstdio_draw_text
			jmp .Err
.ReadCSW	mov DWORD [ehci_bulk_len], EHCI_CSW_LEN
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov DWORD [ehci_async_buff], 0
			call ehci_bulk_io		
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ChkCSW
			mov ebx, ehci_Write10Txt
			call gstdio_draw_text
			mov ebx, ehci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ChkCSW		mov ecx, ehci_Write10Txt
			call ehci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [ehci_res], 0
.Back		popad
			ret


; IN: EAX(LBAHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: ehci_res
ehci_write16_req:
			pushad
			mov esi, ehci_write16_cbw
			mov ebp, [esi+4]
			mov [ehci_curr_tag], ebp
			add esi, USB_CBW_COMMAND_OFFS
			add esi, 2
			bswap eax							; to big-endian
			mov [esi], eax
			add esi, 4
			bswap ebx							; to big-endian
			mov [esi], ebx
			add esi, 4
			mov ebx, edx
			bswap ebx							; to big-endian
			mov [esi], ebx
			mov esi, ehci_write16_cbw
			add esi, USB_CBW_TOTALBYTES_OFFS
			mov eax, edx
			mov ebx, [ehci_sector_size]
			mul ebx
			mov [esi], eax			
			mov ebx, eax
			mov eax, ehci_write16_cbw
			mov [ehci_async_buff], eax
			mov DWORD [ehci_bulk_len], EHCI_CBW_LEN
			mov ax, [ehci_bulkout_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 0
			mov eax, [ehci_bulkout_dt]
			mov [ehci_bulk_dt], eax
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkout_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.Send
			mov ebx, ehci_SendWrite16CBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.Send		mov [ehci_bulk_len], ebx
			mov ax, [ehci_bulkout_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 0
			mov eax, [ehci_bulkout_dt]
			mov [ehci_bulk_dt], eax
			mov [ehci_async_buff], ecx					; set memaddr
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkout_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ReadCSW
			mov ebx, ehci_SendWrite16DataFailedTxt
			call gstdio_draw_text
			jmp .Err
.ReadCSW	mov DWORD [ehci_bulk_len], EHCI_CSW_LEN
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov DWORD [ehci_async_buff], 0
			call ehci_bulk_io		
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ChkCSW
			mov ebx, ehci_Write16Txt
			call gstdio_draw_text
			mov ebx, ehci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ChkCSW		mov ecx, ehci_Write16Txt
			call ehci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [ehci_res], 0
.Back		popad
			ret


; IN: 
; OUT: ehci_res
ehci_testunit_req:
			pushad
			mov eax, ehci_testunit_cbw
			mov ebp, [eax+4]
			mov [ehci_curr_tag], ebp
			mov [ehci_async_buff], eax
			mov DWORD [ehci_bulk_len], EHCI_CBW_LEN
			mov ax, [ehci_bulkout_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 0
			mov eax, [ehci_bulkout_dt]
			mov [ehci_bulk_dt], eax
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkout_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ReadCSW
			mov ebx, ehci_SendTestUnitCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ReadCSW	mov DWORD [ehci_bulk_len], EHCI_CSW_LEN
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov DWORD [ehci_async_buff], 0
			call ehci_bulk_io		
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ChkCSW
			mov ebx, ehci_TestUnitReadyTxt
			call gstdio_draw_text
			mov ebx, ehci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ChkCSW		mov ecx, ehci_TestUnitReadyTxt
			call ehci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [ehci_res], 0
.Back		popad
			ret


; IN:
; OUT: ehci_res
ehci_inquiry_req:
			pushad
			mov eax, ehci_inquiry_cbw
			mov ebp, [eax+4]
			mov [ehci_curr_tag], ebp
			mov [ehci_async_buff], eax
			mov DWORD [ehci_bulk_len], EHCI_CBW_LEN
			mov ax, [ehci_bulkout_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 0
			mov eax, [ehci_bulkout_dt]
			mov [ehci_bulk_dt], eax
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkout_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.Get
			mov ebx, ehci_SendInquiryCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.Get		mov DWORD [ehci_bulk_len], 36
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov DWORD [ehci_async_buff], 0
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ReadCSW
			mov ebx, ehci_GetInquiryCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ReadCSW	mov DWORD [ehci_bulk_len], EHCI_CSW_LEN
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov DWORD [ehci_async_buff], 0
			call ehci_bulk_io	
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ChkCSW
			mov ebx, ehci_InquiryTxt
			call gstdio_draw_text
			mov ebx, ehci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ChkCSW		mov ecx, ehci_InquiryTxt
			call ehci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [ehci_res], 0
.Back		popad
			ret


; IN:
; OUT: ehci_res
ehci_sense_req:
			pushad
			mov eax, ehci_sense_cbw
			mov ebp, [eax+4]
			mov [ehci_curr_tag], ebp
			mov [ehci_async_buff], eax
			mov DWORD [ehci_bulk_len], EHCI_CBW_LEN
			mov ax, [ehci_bulkout_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 0
			mov eax, [ehci_bulkout_dt]
			mov [ehci_bulk_dt], eax
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkout_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.Get
			mov ebx, ehci_SendSenseCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.Get		mov DWORD [ehci_bulk_len], 18
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov DWORD [ehci_async_buff], 0
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ReadCSW
			mov ebx, ehci_GetSenseCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ReadCSW	mov DWORD [ehci_bulk_len], EHCI_CSW_LEN
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov DWORD [ehci_async_buff], 0
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ChkCSW
			mov ebx, ehci_RequestSenseTxt
			call gstdio_draw_text
			mov ebx, ehci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ChkCSW		mov ecx, ehci_RequestSenseTxt
			call ehci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [ehci_res], 0
.Back		popad
			ret


; IN: EAX(CBW), ECX(size of bytes to receive)
; OUT: ehci_res, EBX(lbaHI), ECX(lbaLO), EDX(Sectorsize)
ehci_capacity_req:
			pushad
			mov [ehci_async_buff], eax
			mov ebp, [eax+4]
			mov [ehci_curr_tag], ebp
			mov DWORD [ehci_bulk_len], EHCI_CBW_LEN
			mov ax, [ehci_bulkout_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 0
			mov eax, [ehci_bulkout_dt]
			mov [ehci_bulk_dt], eax
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkout_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.Get
			mov ebx, ehci_SendCapCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.Get		mov DWORD [ehci_bulk_len], ecx
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov DWORD [ehci_async_buff], 0
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.Save
			mov ebx, ehci_GetCapCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
			; save capacity
.Save		cmp ecx, 32								; ReadCap16 ?
			jz	.SaveCap16
			mov ebx, [ehci_async_buff]
			mov eax, [ebx]
			bswap eax								; big-endian to little endian
			mov DWORD [ehci_lbahi], 0
			mov [ehci_lbalo], eax
			add ebx, 4
			mov eax, [ebx]
			bswap eax								; big-endian to little endian
			mov [ehci_sector_size], eax
			jmp	.ReadCSW
.SaveCap16	mov ebx, [ehci_async_buff]
			mov eax, [ebx]
			bswap eax								; big-endian to little endian
			mov [ehci_lbahi], eax
			add ebx, 4
			mov eax, [ebx]
			bswap eax								; big-endian to little endian
			mov [ehci_lbalo], eax
			add ebx, 4
			mov eax, [ebx]
			bswap eax								; big-endian to little endian
			mov [ehci_sector_size], eax
.ReadCSW	mov DWORD [ehci_bulk_len], EHCI_CSW_LEN
			mov ax, [ehci_bulkin_mps]
			mov [ehci_bulk_mps], ax
			mov BYTE [ehci_pid], 1
			mov eax, [ehci_bulkin_dt]
			mov [ehci_bulk_dt], eax
			mov DWORD [ehci_async_buff], 0
			call ehci_bulk_io
			mov eax, [ehci_bulk_dt]
			mov [ehci_bulkin_dt], eax
			cmp DWORD [ehci_res], 1
			jz	.ChkCSW
			mov ebx, ehci_CapacityTxt
			call gstdio_draw_text
			mov ebx, ehci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ChkCSW		mov ecx, ehci_CapacityTxt
			call ehci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [ehci_res], 0
.Back		popad
			ret


; USED IN BULK TRANSFERS (Endpoint=BulkIn/BulkOut)
; A TD can transfer up to 0x5000 bytes in a bulk transfer, but data-toggle needs to be handled in QH
; IN: ehci_async_buff(data IN/OUT), ehci_bulk_len(bytenum of data), ehci_bulk_mps, ehci_pid(direction), ehci_bulk_dt, 
;		ehci_bulkout_endpt, ehci_bulkin_endpt, ehci_dev_address
; OUT: ehci_res, ehci_async_buff
ehci_bulk_io:
			pushad
			mov DWORD [ehci_res], 0
			cmp DWORD [ehci_bulk_len], 0
			jz	.Back
			; calculate number of TDs
			xor edx, edx
			mov eax, [ehci_bulk_len]
			xor ebx, ebx
			mov bx, [ehci_bulk_mps]
			div ebx									; eax(quotient), edx(remainder)
			cmp edx, 0
			jz	.Alloc
			inc eax
			; allocate TDs
.Alloc		mov [ehci_td_num], eax
			mov ebx, EHCI_TD_SIZE
			mul	ebx
			mov ebx, 32
			call ehci_heap_alloc					; addr of TDs in EBX
			mov [ehci_async_tds], ebx
			; TDs
			push ebx
			cmp DWORD [ehci_async_buff], 0
			jz	.Buff
			mov ebx, [ehci_async_buff]
			jmp .Creat
				; Allocate buffer
.Buff		mov eax, [ehci_bulk_len]
			mov ebx, 1
			call ehci_heap_alloc
			mov [ehci_async_buff], ebx
				; create
.Creat		mov edx, ebx									; buffer
			pop ebx
			mov ebp, [ehci_bulk_dt]							; data-toggle bit
.TDio		mov eax, [ehci_bulk_len]
			cmp DWORD [ehci_td_num], 1
			jz	.Sh
			xor eax, eax
			mov ax, [ehci_bulk_mps]
.Sh			shl	eax, 16
			mov ecx, ebp
			shl ecx, 31
			or	eax, ecx
			or	eax, ((3 << 10) | 0x80)						; status-dword
			xor ecx, ecx
			mov cl, [ehci_pid]								; 	direction
			shl ecx, 8
			or	eax, ecx 
			cmp DWORD [ehci_td_num], 1
			jz	.Last
			mov ecx, ebx									; next-td-ptr
			add ecx, EHCI_TD_SIZE
			jmp .AltPtr
.Last		mov ecx, EHCI_QH_HS_T1
.AltPtr		mov edi, EHCI_QH_HS_T1							; alt-next-qtd-ptr
		; IN: EAX(Status-dword), EBX(address of TD), ECX(next-td-ptr), EDX(address of buffer), EDI(alt-next-td-ptr)
			call ehci_create_td
			dec DWORD [ehci_td_num]
;			cmp DWORD [ehci_td_num], 0
			jz	.QH
			add ebx, EHCI_TD_SIZE							; inc address of TD
			xor ecx, ecx
			mov cx, [ehci_bulk_mps]
			sub [ehci_bulk_len], ecx
			add edx, ecx									; inc address of buff
			xor ebp, 1										; toggle dt
			jmp .TDio
.QH			xor ebp, 1
			mov [ehci_bulk_dt], ebp
			; QH
			xor eax, eax
			mov al, [ehci_bulkout_endpt]					; EndPt (OUT)
			cmp BYTE [ehci_pid], 1
			jnz	.Skip										; if PID is not In, then skip
			mov al, [ehci_bulkin_endpt]
.Skip		xor ecx, ecx									; mps
			mov cx, [ehci_bulk_mps]
			xor edx, edx									; device address
			mov dl, [ehci_dev_address]
			mov ebp, [ehci_async_tds]						; addr of TDs
		; IN: EAX (EndPt), ECX(mps), EDX (device address), EBP (address of TDs)
			call ehci_create_qh
			mov [ehci_async_qh], ebx
			; Insert QH into QHs
			mov ecx, [ehci_async_qh]
			call ehci_insert_queue
			; Wait for result
			mov edx, [ehci_async_tds]
			mov ecx, 5000									; this is enough for smaller files
			call ehci_wait_interrupt
			push DWORD [ehci_res]
			; Remove queue
			mov eax, [ehci_async_qh]
			call ehci_remove_queue
			pop eax
			mov [ehci_res], eax
.Back		popad
			ret



ehci_press_a_key:
			pushad
			mov ebx, ehci_PressAKeyTxt
			call gstdio_draw_text
.Key		call kybrd_get_last_key
			call kybrd_key_to_ascii
			cmp bl, 0
			jz .Key
			call kybrd_discard_last_key
			popad
			ret


; **************Print

ehci_print_string:
			pushad
			mov esi, [ehci_async_buff]
			xor ecx, ecx
			mov cl, [esi]
			sub ecx, 2					; number of chars
			add esi, 2
			shr ecx, 1
			xor eax, eax			
.Next		xor ebx, ebx
			mov bl, [esi]
			call gstdio_draw_char
			add esi, 2
			inc eax
			cmp al, cl
			jnge .Next
.Back		popad
			ret


;*********************************************************************

; Disable controller right after boot in order to prevent IRQ being fired
ehci_cfg:
			pushad
			mov eax, 0					; bus
.NextBus	mov ebx, 0					; slot (or device)
.NextDev	mov ecx, 0					; function
.NextFun	mov edx, 0					; offset	; VendorID
			push eax	
			call pci_config_read_word
			mov dx, ax
			pop eax
			cmp dx, 0xFFFF				; check vendorID
			jz	.Continue
			; is it a USB controller?
			push eax
			mov edx, PCI_CLASS_CODE
			call pci_config_read_byte
			mov dl, al
			pop eax
			cmp dl, 0x0C
			jnz	.Continue
			push eax
			mov edx, PCI_SUB_CLASS
			call pci_config_read_byte
			mov dl, al
			pop eax
			cmp dl, 0x03
			jnz	.Continue
			; read cfg-space
			mov edx, 0
.NextDWord	push eax
			call pci_config_read_dword
			mov esi, [pci_cfg_arr]
			add esi, edx
			mov [esi], eax
			add edx, 4
			pop eax
			cmp edx, 0x100
			jnz	.NextDWord
			mov esi, [pci_cfg_arr]
			add esi, PCI_PROG_IF
			xor edx, edx
			mov dl, [esi]
			cmp dl, USB_TYPE_EHCI		; 	EHCI?
			jnz	.Continue
			push ebx
			mov ebx, ehci_FndEHCICtrlTxt
			call gstdio_draw_text
			mov dh, al
			call gstdio_draw_hex8
			mov ebx, ':'
			call gstdio_draw_char
			pop ebx
			mov dh, bl
			call gstdio_draw_hex8
			push ebx
			mov ebx, ':'
			call gstdio_draw_char
			mov dh, cl
			call gstdio_draw_hex8
			call gstdio_new_line
			mov ebx, ehci_ResettingTxt
			call gstdio_draw_text
			pop ebx
			; enable bus-mastering and memory mapped i/o (this frequently freezes on Laptop with OHCI!)
;			mov dx, 0x0006
;			mov WORD [pci_tmp], dx
;			mov edx, PCI_COMMAND
;			call pci_config_write_word
			; read BAR
			push eax
			mov edx, PCI_BAR0
			call pci_config_read_dword
			and eax, ~0xF
			mov [ehci_bar], eax
			; calculate the operational base
			mov edx, [ehci_bar]
			add edx, EHCI_CAPS_CapLength
			xor eax, eax
			mov al, [edx]
			mov [ehci_opbaseoffs], al
			; reset the controller
			mov edx, [ehci_bar]
			add edx, eax
			add edx, EHCI_OPS_USBCommand
			mov DWORD [edx], (1 << 1)
			push ecx
			mov ecx, 50
.IsFinish	mov eax, [edx]
			and eax, (1 << 1)
			cmp eax, 0
			jz	.ChkTO
			push ebx
			mov ebx, 1
			call pit_delay
			pop ebx
			loop .IsFinish
.ChkTO		cmp ecx, 0
			jnz	.Ok
			push ebx
			mov ebx, ehci_CouldntResetCtrlTxt
			call gstdio_draw_text
			pop ebx
.Ok			pop ecx
			pop eax
.Continue	inc ecx
			cmp ecx, PCI_MAX_FUN
			jnge .NextFun
			inc ebx
			cmp ebx, PCI_MAX_DEV
			jnge .NextDev
			inc eax
			cmp eax, PCI_MAX_BUS
			jnge .NextBus
			popad
			ret


ehci_disable_interrupts:
			pushad
			mov edx, PCI_BAR0
			call pci_config_read_dword
			and eax, ~0xF
			mov ebx, eax
			add eax, EHCI_CAPS_CapLength
			xor edx, edx
			mov dl, [eax]					; opbase in DL
			add ebx, edx
			add ebx, EHCI_OPS_USBInterrupt
			and DWORD [ebx], ~0x3F			; disable all interrupts
			sub edx, EHCI_OPS_USBInterrupt
			add edx, EHCI_OPS_USBStatus
			mov DWORD [edx], 0x3F			; clear any pending interrupts
			popad
			ret


%endif 



