%ifndef __DEFS__
%define __DEFS__

%define NORMALRES_DEF		; 1024*768*16 if defined; 640*480*16 if not (for Asus EEE PC) (see ZFOS/docs/resolutions.txt)

;%define HASHTABLE_DEF 		; < 1kB
%define MULTITASKING_DEF 	; 5kB

%define HARDDISK_DEF		; 6kB
%define HDINSTALL_DEF 		; 4kB Note that HARDDISK_DEF needs to be defined in order HDINSTALL_DEF to take effect
%define USB_DEF 			; 32kB
;%define USB_XHCI_IRQ_DEF 	; With polling, if not defined
%define AUDIO_DEF			; 14kB


%endif

 
