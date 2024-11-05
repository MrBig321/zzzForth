;********************************************
; USB 
;********************************************

%ifndef __USB__
%define __USB__

%include "usb/ehci.asm"
%include "usb/fat32.asm"
%include "usb/xhci.asm"


%define USB_TYPE_EHCI	0
%define USB_TYPE_XHCI	1

usb_type	db	USB_TYPE_EHCI

usb_res		dd	0


usb_ehci:
			mov BYTE [usb_type], USB_TYPE_EHCI
			ret


usb_xhci:
			mov BYTE [usb_type], USB_TYPE_XHCI
			ret


usb_driver:
			xor eax, eax
			mov al, [usb_type]
			ret


usb_enum:
			mov BYTE [usbfat32_fs_inited], 0
			cmp BYTE [usb_type], USB_TYPE_XHCI
			je	.XHCI
			call ehci_enum
			mov eax, [ehci_res]
			jmp .Back
.XHCI		call xhci_enum
			mov eax, [xhci_res]
.Back		ret


usb_dev_info:
			mov BYTE [usbfat32_fs_inited], 0
			cmp BYTE [usb_type], USB_TYPE_XHCI
			je	.XHCI
			call ehci_dev_info
			mov eax, [ehci_res]
			jmp .Back
.XHCI		call xhci_dev_info
			mov eax, [xhci_res]
.Back		ret


usb_init_msd:
			mov BYTE [usbfat32_fs_inited], 0
			cmp BYTE [usb_type], USB_TYPE_XHCI
			je	.XHCI
			call ehci_init_msd
			mov eax, [ehci_res]
			jmp .Back
.XHCI		call xhci_init_msd
			mov eax, [xhci_res]
.Back		ret


usb_read_msd:
			cmp BYTE [usb_type], USB_TYPE_XHCI
			je	.XHCI
			call ehci_read_msd
			mov eax, [ehci_res]
			mov [usb_res], eax
			jmp .Back
.XHCI		call xhci_read_msd
			mov eax, [xhci_res]
			mov [usb_res], eax
.Back		ret


usb_write_msd:
			cmp BYTE [usb_type], USB_TYPE_XHCI
			je	.XHCI
			call ehci_write_msd
			mov eax, [ehci_res]
			mov [usb_res], eax
			jmp .Back
.XHCI		call xhci_write_msd
			mov eax, [xhci_res]
			mov [usb_res], eax
.Back		ret

usb_fs_init:
			cmp BYTE [usb_type], USB_TYPE_XHCI
			je	.XHCI
			; MSD initialized?
			mov eax, 0						; ?!
			mov bl, [ehci_dev_address]
			cmp [ehci_inited_msd], bl
			jz	.Init
.XHCI		mov eax, 0						; ?!
			mov bl, [xhci_dev_address]
			cmp [xhci_inited_msd], bl
			jnz	.Back
.Init		call usbfat32_init
			mov eax, [usbfat32_res]
.Back		ret


usb_fs_info:
			call usbfat32_fsinfo
			mov eax, [usbfat32_res]
			ret


usb_fs_info_upd:
			call usbfat32_fsinfoupd
			mov eax, [usbfat32_res]
			ret


usb_fs_ls:
			call usbfat32_ls
			mov eax, [usbfat32_res]
			ret


usb_fs_cd:
			call usbfat32_cd
			mov eax, [usbfat32_res]
			ret


usb_fs_pwd:
			call usbfat32_pwd
			mov eax, [usbfat32_res]
			ret


usb_fs_read:
			call usbfat32_read
			mov eax, [usbfat32_res]
			ret


usb_fs_write:
			call usbfat32_write
			mov eax, [usbfat32_res]
			ret


usb_fs_rem:
			call usbfat32_rem
			mov eax, [usbfat32_res]
			ret


%endif


