;************************
; PCI
;************************

%ifndef __FORTH_PCI__
%define __FORTH_PCI__


%include "pci.asm"
%include "forth/common.asm"
%include "forth/core.asm"


section .text

;*************************************************
; _pci_ls				PCILS
;	( -- )
;	Displays info about PCI devices
;*************************************************
_pci_ls:
			call _c_r
			call pci_ls
			ret


;*************************************************
; _pci_cfg				PCICFG
;	( b, d, f -- )
;	Displays 256-byte config-space of PCI device 
;	identified by bus, device(or slot) and function
;*************************************************
_pci_cfg:
			call _c_r
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			call pci_cfg
			ret


;*************************************************
; _pci_det_usb			PCIDETUSB
;	( -- )
;*************************************************
_pci_det_usb:
			call pci_detect_usb
			ret


;*************************************************
; _pci_config_write_dword		PCICFGWRD
;	( b d f o n -- ) 
;*************************************************
_pci_config_write_dword:
			POP_PS(eax)
			mov [pci_tmp], eax
			POP_PS(edx)
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			call pci_config_write_dword
			ret 


;*************************************************
; _pci_config_write_word		PCICFGWRW
;	( b d f o n -- ) 
;*************************************************
_pci_config_write_word:
			POP_PS(eax)
			mov [pci_tmp], ax
			POP_PS(edx)
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			call pci_config_write_word
			ret 


;*************************************************
; _pci_config_write_byte		PCICFGWRB
;	( b d f o n -- ) 
;*************************************************
_pci_config_write_byte:
			POP_PS(eax)
			mov [pci_tmp], al
			POP_PS(edx)
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			call pci_config_write_byte
			ret 


;*************************************************
; _pci_config_read_dword		PCICFGRDD
;	( b d f o -- d ) 
;*************************************************
_pci_config_read_dword:
			POP_PS(edx)
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			call pci_config_read_dword
			PUSH_PS(eax)
			ret 


;*************************************************
; _pci_config_read_word		 	PCICFGRDW
;	( b d f o -- w ) 
;*************************************************
_pci_config_read_word:
			POP_PS(edx)
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			call pci_config_read_word
			PUSH_PS(eax)
			ret 


;*************************************************
; _pci_config_read_byte		 	PCICFGRDB
;	( b d f o -- b ) 
;*************************************************
_pci_config_read_byte:
			POP_PS(edx)
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			call pci_config_read_byte
			PUSH_PS(eax)
			ret 


%endif


