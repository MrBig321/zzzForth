;********************************************
;	PCI bus
;
;********************************************


%ifndef __PCI__
%define __PCI__


%include "defs.asm"
;%include "kybrd.asm"
%include "gstdio.asm"


%define PCI_CONFIG_ADDR 0x0CF8
%define PCI_CONFIG_DATA 0x0CFC
%define PCI_MAX_BUS		256
%define PCI_MAX_DEV		32
%define PCI_MAX_FUN		8


; 64 standardized bytes of the 256-byte PCI Config-Space
; PCI Registers (or offsets) HeaderType=0
%define PCI_VENDOR_ID			0x00	; WORD
%define PCI_DEVICE_ID			0x02	; WORD
%define PCI_COMMAND				0x04	; WORD
%define PCI_STATUS				0x06	; WORD
%define PCI_REVISION_ID			0x08	; BYTE
%define PCI_PROG_IF				0x09	; BYTE
%define PCI_SUB_CLASS			0x0A	; BYTE
%define PCI_CLASS_CODE			0x0B	; BYTE
%define PCI_CACHE_LINE_SIZE		0x0C	; BYTE
%define PCI_LATENCY_TIMER		0x0D	; BYTE
%define PCI_HEADER_TYPE			0x0E	; BYTE
%define PCI_BIST				0x0F	; BYTE
%define PCI_BAR0				0x10	; DWORD
%define PCI_BAR1				0x14	; DWORD
%define PCI_BAR2				0x18	; DWORD
%define PCI_BAR3				0x1C	; DWORD
%define PCI_BAR4				0x20	; DWORD
%define PCI_BAR5				0x24	; DWORD
%define PCI_CARDBUS_CIS_POINTER	0x28	; DWORD
%define PCI_SUBSYSTEM_VENDOR_ID	0x2C	; WORD
%define PCI_SUBSYSTEM_ID		0x2E	; WORD
%define PCI_EXP_ROM_BASE_ADDR	0x30	; DWORD
%define PCI_CAPABILITIES_PTR	0x34	; BYTE
%define PCI_INTERRUPT_LINE		0x3C	; BYTE
%define PCI_INTERRUPT_PIN		0x3D	; BYTE
%define PCI_MIN_GRANT			0x3E	; BYTE
%define PCI_MAX_LATENCY			0x3F	; BYTE

%define PCI_TYPE_XHCI	0x30

section .text

pci_ls:
			mov ebx, PCIHeaderTxt
			call gstdio_draw_text
			mov eax, 0		; bus
.NextBus	mov ebx, 0		; slot (or device)
			mov ecx, 0		; function
			mov edx, 0		; offset	; VendorID
.NextSlot	push eax
			call pci_config_read_dword
			cmp eax, 0xFFFFFFFF	; check if deviceId and vendorID are not FFFF. Maybe check ClassId too?
			jz	.Restore
			pop eax
			call pci_print_function
			call pci_check_functions
			jmp .Continue
.Restore	pop eax
.Continue 	inc ebx
			cmp ebx, 32
			jnge .NextSlot
			inc eax
			cmp eax, 256
			jnge .NextBus
			ret


; IN: EAX bus, EBX slot(or device)
pci_check_functions:
			push ecx
			push edx
			push eax
			; check header type
			mov edx, 0x0E
			call pci_config_read_byte
			and al, 0x80				; multi-function device if not zero
			jz	.End
			pop eax
			push eax
			mov ecx, 1
.NextFun	push eax
			mov edx, 0x0				; read VendorId, if it's not 0xFFFF then function exists
			call pci_config_read_dword
			cmp ax, 0xFFFF
			jz	.Restore
			pop eax
			call pci_print_function
			jmp .IncFun
.Restore	pop eax
.IncFun		inc ecx
			cmp ecx, 0x08
			jnz	.NextFun
.End		pop eax
			pop edx
			pop ecx
			ret


; IN: EAX bus, EBX slot(or device), ECX func
; Should be printed according to BASE (DEC or HEX) !!!! or always HEX!?
pci_print_function:
			push eax
			push ebx
			push ecx
			push edx
			push esi
			push edi
			mov esi, eax
			mov edi, ebx
			; bus and slot
			mov edx, eax
			shl dx, 8
			call gstdio_draw_hex8
			mov ebx, PCI2SpacesTxt
			call gstdio_draw_text
			mov ebx, edi
			mov edx, ebx
			shl dx, 8
			call gstdio_draw_hex8
			mov ebx, PCI3SpacesTxt
			call gstdio_draw_text
			; function
			mov dh, cl
			call gstdio_draw_hex8
			mov ebx, PCI2SpacesTxt
			call gstdio_draw_text
			; get deviceId and vendorId
;			mov eax, esi
			mov ebx, edi
			mov edx, 0x0
			call pci_config_read_dword
			mov edx, eax
			shr edx, 16
			call gstdio_draw_hex16
			mov ebx, PCI2SpacesTxt
			call gstdio_draw_text
			mov edx, eax
			and edx, 0xFFFF
			call gstdio_draw_hex16
			mov ebx, PCI2SpacesTxt
			call gstdio_draw_text
			; class, subclass
			mov eax, esi
			mov ebx, edi
			mov edx, 0x0B
			call pci_config_read_byte
			mov dh, al
			call gstdio_draw_hex8
			mov ebx, PCI4SpacesTxt
			call gstdio_draw_text
			mov eax, esi
			mov ebx, edi
			mov edx, 0x0A
			call pci_config_read_byte
			mov dh, al
			call gstdio_draw_hex8
			call gstdio_new_line
			pop edi
			pop esi
			pop edx
			pop ecx
			pop ebx
			pop eax
			ret


; IN: EAX bus, EBX slot(or device), ECX func
pci_cfg:
			push esi
			mov edx, 0
.Next		push eax
			call pci_config_read_dword
			mov esi, [pci_cfg_arr]
			add esi, edx
			mov [esi], eax
			add edx, 4
			pop eax
			cmp edx, 0x100
			jnz	.Next

			mov esi, [pci_cfg_arr]
			mov ecx, 256
			call gutil_mem_dump
			pop esi
			ret


; lspci on Linux will help you to identify the devices on the PCI bus
pci_init:
; Ethernet (Network) ?
%ifdef HARDDISK_DEF
			call pci_init_ide_ctrlr
			call pci_init_sata_ctrlr	; this is necessary if we have a SATA-controller that can be switched to IDE (like ASUS EEEPC 1001px)
			call pci_init_hd			; for DMA
;			call pci_init_usb_ctrlr
%endif
			ret


pci_init_ide_ctrlr:			; SHOULDN'T WE INIT bit0 and bit2 of COMMAND register!? (i/o space, bus-master)
			; Intel?					; see ICH7-datasheet
			mov eax, 0
			mov ebx, 0x1F	; 31
			mov ecx, 1
			mov edx, 0		; VendorId
			call pci_config_read_word
			cmp ax, 0x8086			; Intel
			jnz	.AMD

			; Set IDE-controller to native-mode. Only one controller should have a channel set to compatibility mode at a time. 
			mov eax, 0	
			mov ebx, 0x1F	; 31
			mov ecx, 1
			mov edx, 0x09
			push eax
			call pci_config_read_byte
			or al, 0x05
			mov BYTE [pci_tmp], al
			pop eax
			call pci_config_write_byte
			jmp .Back


			; AMD/ATI?					; SB700/710/750 Register Reference Guide
.AMD		mov eax, 0
			mov ebx, 0x14
			mov ecx, 1
			mov edx, 0		; VendorId
			call pci_config_read_word
			cmp ax, 0x1002
;			jnz .Back
			jnz .VIA

			; Set IDE-controller to native-mode. Only one controller should have a channel set to compatibility mode at a time. 
			mov eax, 0
			mov ebx, 0x14
			mov ecx, 1
			mov edx, 0x09
			push eax
			call pci_config_read_byte
			or al, 0x05
			mov BYTE [pci_tmp], al
			pop eax
			call pci_config_write_byte
;			jmp .Back

.VIA		mov eax, 0
			mov ebx, 0x0F
			mov ecx, 0
			mov edx, 0		; VendorId
			call pci_config_read_word
			cmp ax, 0x1106					; VIA ?
			jnz	.Back

			mov eax, 0						; IRQ-disabling
			mov ebx, 0x0F
			mov ecx, 0
			mov edx, 4
			push eax
			call pci_config_read_word
			or	ax, 1024
			mov WORD [pci_tmp], ax
			pop eax
			call pci_config_write_word

			mov eax, 0						; IRQ-disabling
			mov ebx, 0x0F
			mov ecx, 1
			mov edx, 4
			push eax
			call pci_config_read_word
			or	ax, 1024
			mov WORD [pci_tmp], ax
			pop eax
			call pci_config_write_word

.Back		ret


pci_init_sata_ctrlr:
			; Intel?						; ICH7 datasheet
			mov eax, 0
			mov ebx, 0x1F	; 31
			mov ecx, 2
			mov edx, 0		; VendorId
			call pci_config_read_word
			cmp ax, 0x8086				; Intel
			jnz	.AMD

			mov eax, 0						; IRQ-disabling
			mov ebx, 0x1F
			mov ecx, 2
			mov edx, 4
			push eax
			call pci_config_read_word
			or	ax, 1024
			mov WORD [pci_tmp], ax
			pop eax
			call pci_config_write_word

			; set "SATA as IDE" mode (0 to register 0x90 of the controller);
			mov edx, 0x90
			mov BYTE [pci_tmp], 0
			call pci_config_write_byte

			; set Legacy-mode (i.e. compatibility) in register 0x09 by setting bits 0 and 2 to 0 (primary and secondary channel)
			push eax
			mov edx, 0x09
			call pci_config_read_byte
			and al, 0xFA
			mov BYTE [pci_tmp], al
			pop eax
			call pci_config_write_byte
			jmp .Back

			; AMD/ATI?					; SB700/710/750 Register Reference Guide
.AMD		mov eax, 0
			mov ebx, 0x11	; 17
			mov ecx, 0
			mov edx, 0		; VendorId
			call pci_config_read_word
			cmp ax, 0x1002
			jnz	.Back			; .VIA

			mov eax, 0						; IRQ-disabling
			mov ebx, 0x11
			mov ecx, 0
			mov edx, 4
			push eax
			call pci_config_read_word
			or	ax, 1024
			mov WORD [pci_tmp], ax
			pop eax
			call pci_config_write_word

			; set bit0 of register 0x40 in order to be able to program the followings
			push eax
			mov edx, 0x40
			call pci_config_read_byte
			or al, 0x01
			mov BYTE [pci_tmp], al
			pop eax
			call pci_config_write_byte
			; clear bit24 of register 0x40 in order to be able to program the followings
			push eax
			mov edx, 0x43
			call pci_config_read_byte
			and al, 0xFE
			mov BYTE [pci_tmp], al
			pop eax
			call pci_config_write_byte

			; set deviceId to 0x4390 (IDE)
			mov edx, 0x02
			mov WORD [pci_tmp], 0x4390
			call pci_config_write_word

			; set "SATA as IDE" mode (0x01 to register 0x0A (Subclass))
			mov edx, 0x0A
			mov BYTE [pci_tmp], 0x01
			call pci_config_write_byte

			; set Legacy-mode (i.e. compatibility) in register 0x09 by setting bits 0 and 2 to 0 (primary and secondary channel)
			push eax
			mov edx, 0x09
			call pci_config_read_byte
			and al, 0xFA
			mov BYTE [pci_tmp], al
			pop eax
			call pci_config_write_byte
;			jmp .Back
.Back		ret


%ifdef AUDIO_DEF
pci_detect_audio:
			push esi
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
			; is it audio?
			push eax
			mov edx, PCI_CLASS_CODE
			call pci_config_read_byte
			mov dl, al
			pop eax
			cmp dl, 0x04
			jnz	.Continue
			push eax
			mov edx, PCI_SUB_CLASS
			call pci_config_read_byte
			mov dl, al
			pop eax
			cmp dl, 0x03				; 0x3 - Audio Device
			jnz	.Continue
			; read cfg
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
			push eax
			xor eax, eax
			mov al, [esi]
			cmp al, 0			; ProgIF is zero ==> audio device
			pop eax
			je	.Store
.Continue	inc ecx
			cmp ecx, PCI_MAX_FUN
			jnge .NextFun
			inc ebx
			cmp ebx, PCI_MAX_DEV
			jnge .NextDev
			inc eax
			cmp eax, PCI_MAX_BUS
			jnge .NextBus
			jmp .Back
.Store		mov [pci_audio_bus], al
			mov [pci_audio_dev], bl
			mov [pci_audio_fun], cl
			mov BYTE [pci_audio_detected], 1
.Back		pop esi
			ret


pci_audio_get_irq:
			xor eax, eax
			mov al, [pci_audio_bus]
			xor ebx, ebx
			mov bl, [pci_audio_dev]
			xor ecx, ecx
			mov cl, [pci_audio_fun]
			mov edx, PCI_INTERRUPT_LINE
			call pci_config_read_byte
			ret
%endif


%ifdef USB_DEF
	%ifdef USB_XHCI_IRQ_DEF
pci_detect_xhci:
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
			cmp dl, PCI_TYPE_XHCI		; XHCI?
			jnz	.Continue
			mov [pci_xhci_bus], al
			mov [pci_xhci_dev], bl
			mov [pci_xhci_fun], cl
			mov BYTE [pci_xhci_detected], 1
			jmp .Back					; this finds only one controller! Should use an array to find all!?
.Continue	inc ecx
			cmp ecx, PCI_MAX_FUN
			jnge .NextFun
			inc ebx
			cmp ebx, PCI_MAX_DEV
			jnge .NextDev
			inc eax
			cmp eax, PCI_MAX_BUS
			jnge .NextBus
.Back		popad
			ret

pci_xhci_get_irq:
			xor eax, eax
			mov al, [pci_xhci_bus]
			xor ebx, ebx
			mov bl, [pci_xhci_dev]
			xor ecx, ecx
			mov cl, [pci_xhci_fun]
			mov edx, PCI_INTERRUPT_LINE
			call pci_config_read_byte
			ret
	%endif
%endif

; IN: -
; OUT: EAX(bus), EBX(dev), ECX(fun), EDX(1, if detected)
pci_detect_xhci_controller:
			push esi
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
			cmp dl, PCI_TYPE_XHCI		; XHCI?
			jz	.Fnd					; this finds only one controller! Should use an array to find all!?
.Continue	inc ecx
			cmp ecx, PCI_MAX_FUN
			jnge .NextFun
			inc ebx
			cmp ebx, PCI_MAX_DEV
			jnge .NextDev
			inc eax
			cmp eax, PCI_MAX_BUS
			jnge .NextBus
			xor edx, edx
			jmp .Back
.Fnd		mov edx, 1
.Back		pop esi
			ret


%ifdef USB_DEF
pci_detect_usb:
			push esi
			mov ebx, USBHeaderTxt
			call gstdio_draw_text
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
			; read cfg
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
			push eax
			xor eax, eax
			mov al, [esi]
			shr al, 4
			cmp al, 3
			jng .Skip
			mov al, 4
.Skip		push ebx
			mov ebx, USBFndTxt	
			call gstdio_draw_text
			mov ebx, 4
			mul ebx
			mov esi, usb_ctrls_txts
			add esi, eax
			mov ebx, [esi]
			call gstdio_draw_text
			call gstdio_new_line
			shl ax, 8
			call gstdio_draw_hex8		; bus
			mov ebx, ':'
			call gstdio_draw_char
			pop ebx
			mov edx, ebx
			push ebx
			shl dx, 8
			call gstdio_draw_hex8		; device
			mov ebx, ':'
			call gstdio_draw_char
			mov edx, ecx
			shl dx, 8
			call gstdio_draw_hex8		; function
			mov ebx, ' '
			call gstdio_draw_char
			mov ebx, USBBARTxt
			call gstdio_draw_text
			mov esi, [pci_cfg_arr]		; print BAR
			add esi, PCI_PROG_IF
			cmp BYTE [esi], 0			; UHCI uses BAR4
			jz	.UHCI
			sub esi, PCI_PROG_IF
			add esi, PCI_BAR0
			mov edx, [esi]
			call gstdio_draw_hex
			jmp .IRQ
.UHCI		sub esi, PCI_PROG_IF
			add esi, PCI_BAR4
			mov edx, [esi]
			call gstdio_draw_hex
.IRQ		mov ebx, ' '
			call gstdio_draw_char
			mov ebx, USBIRQTxt
			call gstdio_draw_text
			mov esi, [pci_cfg_arr]
			add esi, PCI_INTERRUPT_LINE
			xor edx, edx
			mov dl, [esi]
			shl dx, 8
			call gstdio_draw_hex8
			call gstdio_new_line
			pop ebx
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
			pop esi
			ret
%endif


;pci_init_usb_ctrlr:
;			; Intel? (UHCI(0, 1, 2, 3), EHCI(7))			; ICH7 datasheet
;			mov eax, 0
;			mov ebx, 0x1D
;			mov ecx, 0
;.NextIntel	mov edx, 0		; VendorId
;			push eax
;			call pci_config_read_word
;			cmp ax, 0x8086
;			jz	.Intel
;			pop eax
;.IncIntel	inc ecx
;			cmp ecx, 4				; skip empty
;			jz	.IntelSkip
;			cmp ecx, 7
;			jng	.NextIntel
;			jmp .ChkAMD
;.IntelSkip	add ecx, 3
;			jmp .NextIntel
;
;			; disable IRQ
;.Intel		pop eax	
;			mov edx, 4
;			push eax
;			call pci_config_read_word
;			or	ax, 1024
;			mov WORD [pci_tmp], ax
;			pop eax
;			call pci_config_write_word
;			jmp .IncIntel
;
;			; AMD/ATI?					; SB700/710/750 Register Reference Guide
;.ChkAMD		mov eax, 0
;			mov ebx, 0x12	; 18
;			mov ecx, 0
;			mov edx, 0		; VendorId
;			call pci_config_read_word
;			cmp ax, 0x1002
;			jz	.AMD
;			jmp .Back
;
;.AMD		mov eax, 0
;			mov ebx, 0x12
;.NextAMDDev	mov ecx, 0
;.NextAMD	mov edx, 0		; VendorId
;			push eax
;			call pci_config_read_word
;			cmp ax, 0x1002
;			jz	.AMD2
;			pop eax
;.IncAMD		inc ecx
;			cmp ecx, 2
;			jng	.NextAMD
;			inc ebx
;			cmp ebx, 0x14
;			jnz	.NextAMDDev
;			jmp .AMD3
;
;			; disable IRQ
;.AMD2		pop eax	
;			mov edx, 4
;			push eax
;			call pci_config_read_word
;			or	ax, 1024
;			mov WORD [pci_tmp], ax
;			pop eax
;			call pci_config_write_word
;			jmp .IncAMD
;
;.AMD3		mov eax, 0
;			mov ebx, 0x14
;			mov ecx, 5
;			mov edx, 4
;			push eax
;			call pci_config_read_word
;			or	ax, 1024
;			mov WORD [pci_tmp], ax
;			pop eax
;			call pci_config_write_word
;
;.Back		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; IN: EAX bus, EBX slot(or device), ECX func, EDX offset
pci_set_config_addr:
			push ebp
			shl	eax, 16
			mov ebp, eax
			shl	ebx, 11
			or	ebp, ebx
			shl	ecx, 8
			or	ebp, ecx
			and	edx, 0x000000FC
			or	ebp, edx
			or	ebp, 0x80000000
			mov eax, ebp
			mov dx, PCI_CONFIG_ADDR
			out dx, eax
			pop ebp
			ret


; IN: EAX bus, EBX slot(or device), ECX func, EDX offset
; OUT: AL	
pci_config_read_byte:
			push ebx
			push ecx
			push edx

			call pci_set_config_addr

			pop edx
			push edx
			and edx, 3
			add edx, PCI_CONFIG_DATA
			xor eax, eax
			in al, dx

			pop edx
			pop ecx
			pop ebx
			ret


; IN: EAX bus, EBX slot(or device), ECX func, EDX offset
; OUT: AX	
pci_config_read_word:
			push ebx
			push ecx
			push edx

			call pci_set_config_addr

		; should here be a little delay!?
			pop edx
			push edx
			and edx, 2
			add edx, PCI_CONFIG_DATA
			xor eax, eax
			in ax, dx

			pop edx
			pop ecx
			pop ebx
			ret


; IN: EAX bus, EBX slot(or device), ECX func, EDX offset
; OUT: EAX	
pci_config_read_dword:
			push ebx
			push ecx
			push edx

			call pci_set_config_addr

			mov dx, PCI_CONFIG_DATA
			in eax, dx

			pop edx
			pop ecx
			pop ebx
			ret


; IN: EAX bus, EBX slot(or device), ECX func, EDX offset, [pci_tmp] byte to write
pci_config_write_byte:
			push eax
			push ebx
			push ecx
			push edx

			call pci_set_config_addr

			pop edx
			push edx
			and edx, 3
			add edx, PCI_CONFIG_DATA
			xor eax, eax
			mov al, [pci_tmp]
			out dx, al

			pop edx
			pop ecx
			pop ebx
			pop eax
			ret


; IN: EAX bus, EBX slot(or device), ECX func, EDX offset, [pci_tmp] word to write
pci_config_write_word:
			push eax
			push ebx
			push ecx
			push edx

			call pci_set_config_addr

			pop edx
			push edx
			and edx, 2
			add edx, PCI_CONFIG_DATA
			xor eax, eax
			mov ax, [pci_tmp]
			out dx, ax

			pop edx
			pop ecx
			pop ebx
			pop eax
			ret


; IN: EAX bus, EBX slot(or device), ECX func, EDX offset, [pci_tmp] dword to write
pci_config_write_dword:
			push eax
			push ebx
			push ecx
			push edx

			call pci_set_config_addr

			mov dx, PCI_CONFIG_DATA
			mov eax, [pci_tmp]
			out dx, eax

			pop edx
			pop ecx
			pop ebx
			pop eax
			ret


pci_init_hd:
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
			; is it an IDE Controller?
			push eax
			mov edx, PCI_CLASS_CODE
			call pci_config_read_byte
			mov dl, al
			pop eax
			cmp dl, 0x01
			jnz	.Continue
			push eax
			mov edx, PCI_SUB_CLASS
			call pci_config_read_byte
			mov dl, al
			pop eax
			cmp dl, 0x01
			jnz	.Continue
			; found
			mov BYTE [pci_ide_ctrlr_found], 1
			mov [pci_ide_bus], al
			mov [pci_ide_dev], bl
			mov [pci_ide_fun], cl
			; Enable bus-master and memory-space, enable IRQs
			mov edx, 0x04
			push eax
			call pci_config_read_word
			or ax, 0x0007
			and ax, 0xFBFF					; clear bit 10 (to enable IRQs)
			mov WORD [pci_tmp], ax
			pop eax
			call pci_config_write_word
;			; Enable UDMA		(BIOS sets it to 0x05)
;			mov edx, 0x48
;			push eax
;;			call pci_config_read_word
;			or al, 0x0F
;			mov BYTE [pci_tmp], al
;			pop eax
;			call pci_config_write_word

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
			add esi, PCI_BAR4
			mov edx, [esi]
			and edx, 0xFFFFFFFE					; remove bit0 that indicates port not memmapped
			mov [pci_bus_master_reg], edx
			jmp .Back
.Continue	inc ecx
			cmp ecx, PCI_MAX_FUN
			jnge .NextFun
			inc ebx
			cmp ebx, PCI_MAX_DEV
			jnge .NextDev
			inc eax
			cmp eax, PCI_MAX_BUS
			jnge .NextBus
.Back		popad
			ret


section .data

pci_cfg_arr dd 0x92000	; Pointer to 256-byte PCI Config Space

pci_tmp	dd 0

pci_ide_ctrlr_found	db 0
pci_bus_master_reg	dd 0	; if bit0 is 1 ==> port not memmapped
pci_ide_bus	db 0
pci_ide_dev	db 0
pci_ide_fun	db 0

%ifdef AUDIO_DEF
pci_audio_bus	db 0
pci_audio_dev	db 0
pci_audio_fun	db 0
pci_audio_detected db 0
%endif

%ifdef USB_DEF
	%ifdef USB_XHCI_IRQ_DEF
		pci_xhci_bus	db 0
		pci_xhci_dev	db 0
		pci_xhci_fun	db 0
		pci_xhci_detected db 0
	%endif
%endif

PCIHeaderTxt	db "bus slot fun devId venId class sub", 0x0A, 0
PCI2SpacesTxt	db "  ", 0
PCI3SpacesTxt	db "   ", 0
PCI4SpacesTxt	db "    ", 0

; USB
USBHeaderTxt	db 0x0A, "Detecting USB Controllers on PCI Bus (data in hex)", 0x0A, 0
USBUHCITxt		db "(UHCI)", 0
USBOHCITxt		db "(OHCI)", 0
USBEHCITxt		db "(EHCI)", 0
USBxHCITxt		db "(xHCI)", 0
USBUnkTxt		db "(Unknown)", 0
usb_ctrls_txts	dd USBUHCITxt, USBOHCITxt, USBEHCITxt, USBxHCITxt, USBUnkTxt
USBFndTxt		db "Found a USB compatible device entry. ", 0	; write type after this
USBBARTxt		db "BAR:", 0
USBIRQTxt		db "IRQ:", 0


%endif

