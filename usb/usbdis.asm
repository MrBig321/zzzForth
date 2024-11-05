;********************************************
; USB 
;********************************************

%ifndef __USBDIS__
%define __USBDIS__

%include "pci.asm"


; Controller Types
%define USB_TYPE_UHCI	0x00
%define USB_TYPE_OHCI	0x10
%define USB_TYPE_EHCI	0x20
%define USB_TYPE_XHCI	0x30

;UHCI
%define UHCI_INTERRUPT_REG	0x04

;OHCI
%define OHCInterruptDisable	0x14

;EHCI
%define USBDIS_EHCI_CAPS_CapLength			0x00
%define USBDIS_EHCI_OPS_USBInterrupt		0x08
%define USBDIS_EHCI_OPS_USBStatus			0x04

;XHCI
%define USBDIS_xHC_CAPS_CapLength      0x00
%define USBDIS_xHC_OPS_USBCommand      0x00
%define USBDIS_xHC_OPS_USBStatus       0x04

;UHCI
usbdis_uhci_disable_interrupts:
			push eax
			mov edx, PCI_BAR4
			call pci_config_read_dword
			and eax, 0xFFFFFFFC			; get rid of bits 1:0
			mov edx, eax
			add edx, UHCI_INTERRUPT_REG
			mov ax, 0
			out dx, ax
			pop eax
			ret

;OHCI
usbdis_ohci_disable_interrupts:
			push eax
			mov edx, PCI_BAR0
			call pci_config_read_dword
			and eax, ~0x0F
			add eax, OHCInterruptDisable
			mov DWORD [eax], 0x80000000
			pop eax
			ret

;EHCI
usbdis_ehci_disable_interrupts:
			pushad
			mov edx, PCI_BAR0
			call pci_config_read_dword
			and eax, ~0xF
			mov ebx, eax
			add eax, USBDIS_EHCI_CAPS_CapLength
			xor edx, edx
			mov dl, [eax]					; opbase in DL
			add ebx, edx
			add ebx, USBDIS_EHCI_OPS_USBInterrupt
			and DWORD [ebx], ~0x3F			; disable all interrupts
			sub edx, USBDIS_EHCI_OPS_USBInterrupt
			add edx, USBDIS_EHCI_OPS_USBStatus
			mov DWORD [edx], 0x3F			; clear any pending interrupts
			popad
			ret

;XHCI
usbdis_xhci_disable_interrupts:
			pushad
			mov edx, PCI_BAR0
			call pci_config_read_dword
			and eax, ~0xF

			; to OperationalBase
			mov edx, eax
			add edx, USBDIS_xHC_CAPS_CapLength
			xor ebx, ebx
			mov bl, [edx]
			add eax, ebx
			add eax, USBDIS_xHC_OPS_USBCommand
			and DWORD [eax], ~0x04			; disable interrupts

			add eax, USBDIS_xHC_OPS_USBStatus
			or	DWORD [eax], 0x08			; clear any pending interrupts
			popad
			ret


usbdis_disable_interrupts:
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
			push eax
			mov edx, PCI_PROG_IF
			call pci_config_read_byte
			mov dl, al
			pop eax
			cmp dl, USB_TYPE_UHCI
			jnz	.OHCI
			call usbdis_uhci_disable_interrupts
			jmp .Continue
.OHCI		cmp dl, USB_TYPE_OHCI
			jnz	.EHCI
			call usbdis_ohci_disable_interrupts
			jmp .Continue
.EHCI		cmp dl, USB_TYPE_EHCI
			jnz	.XHCI
			call usbdis_ehci_disable_interrupts
			jmp .Continue
.XHCI		cmp dl, USB_TYPE_XHCI
			jnz	.Continue
			call usbdis_xhci_disable_interrupts
.Continue	inc ecx
			cmp ecx, PCI_MAX_FUN
			jnge .NextFun
			inc ebx
			cmp ebx, PCI_MAX_DEV
			jnge .NextDev
			inc eax
			cmp eax, PCI_MAX_BUS
			jnge .NextBus
			ret


%endif


