;*************************************************
;	idt.inc
;		-IDT Routines
;
;*************************************************

%ifndef __IDT__
%define __IDT__

%include "defs.asm"
%include "gstdio.asm"
%ifdef HARDDISK_DEF
	%include "hd.asm"
%endif
%include "pic.asm"
%ifdef AUDIO_DEF
	%include "hdaudio.asm"
%endif
%ifdef USB_DEF
	%ifdef USB_XHCI_IRQ_DEF
		%include "usb/xhci.asm"
	%endif
%endif


bits 32


%define IDT_ISR_NUM 20
%define IDT_MAX_INTERRUPTS	256
%define IDT_ENTRY_SIZE 	8


section .text

;*******************************************
; idt_init
; Loads the handlers to every slot
; Note that idt_ptr and idt_entry_arr also
; belongs to the init process
;*******************************************
idt_init:
			mov ebx, 0
.Next		mov edx, [idt_isr_arr+ebx*4]
			call idt_install_irh
			inc ebx
			cmp ebx, IDT_MAX_INTERRUPTS
			jnz .Next

			; load idt
			lidt [idt_ptr]

			ret


;*******************************************
; idt_load_isrs
; Loads the first 20 isr-vectors
;*******************************************
idt_load_isrs:
			mov ebx, 39
			mov edx, idt_isr_39Spec
			call idt_install_irh

%ifdef HARDDISK_DEF
			mov ebx, 46
			mov edx, idt_isr_hd14
			call idt_install_irh

			mov ebx, 47
			mov edx, idt_isr_hd15
			call idt_install_irh
%endif

%ifdef AUDIO_DEF
			; check if Intel HD Audio is available and get its IRQ-number
			cmp BYTE [pci_audio_detected], 1
			jnz	.Next
			call pci_audio_get_irq
			xor ebx, ebx
			mov bl, al
			mov [idt_hda_irq_num], bl
			add ebx, 32			; IRQs from 0-15 are remapped to 32-47 in PIC
			mov edx, idt_isr_hdaudio
			call idt_install_irh
%endif
.Next:
%ifdef USB_DEF
	%ifdef USB_XHCI_IRQ_DEF
			; check if XHCI-Controller is available and get its IRQ-number
			cmp BYTE [pci_xhci_detected], 1
			jnz	.Next2
			call pci_xhci_get_irq
			xor ebx, ebx
			mov bl, al
			mov [idt_xhci_irq_num], bl
			add ebx, 32			; IRQs from 0-15 are remapped to 32-47 in PIC
			mov edx, idt_isr_xhci
			call idt_install_irh
	%endif
%endif
.Next2:
			ret


;*******************************************
; idt_install_irh
; EBX: slot number
; EDX: handler
; Installs interrupt handler(in EDX) 
; to slot EBX
;*******************************************
idt_install_irh:
			pushad
			; Check slotnum >= IDT_MAX_INTERRUPTS and handler=0
			cmp ebx, IDT_MAX_INTERRUPTS
			jge .Back
			cmp edx, 0
			jz .Back

			mov esi, idt_entry_arr
			mov WORD [esi+ebx*IDT_ENTRY_SIZE], dx
			shr edx, 16
			mov WORD [esi+ebx*IDT_ENTRY_SIZE+6], dx			; 6 is baseHiOffs (upper 16-bits)
			mov WORD [esi+ebx*IDT_ENTRY_SIZE+2], 0x08		; code-segment selector
			mov BYTE [esi+ebx*IDT_ENTRY_SIZE+5], 0x8E		; type and attributes (32-bit interrupt-gate)
.Back		popad
			ret


SeparatorTxt	db "======================================", 0x0A, 0
EFlagsTxt		db "EFlags: ", 0
CSTxt			db "CS:     ", 0
EIPTxt			db "EIP:    ", 0
EAXTxt			db "EAX:    ", 0
EBXTxt			db "EBX:    ", 0
ECXTxt			db "ECX:    ", 0
EDXTxt			db "EDX:    ", 0
ESITxt			db "ESI:    ", 0
EDITxt			db "EDI:    ", 0
EBPTxt			db "EBP:    ", 0


idt_info:
		push ebx
		push edx

		call gstdio_new_line
		mov ebx, SeparatorTxt
		call gstdio_draw_text

		mov ebx, EAXTxt
		call gstdio_draw_text
		mov edx, eax
		call gstdio_draw_hex
		call gstdio_new_line

		mov ebx, EBXTxt
		call gstdio_draw_text
		pop edx					; pop ebx to edx
		call gstdio_draw_hex
		call gstdio_new_line

		mov ebx, ECXTxt
		call gstdio_draw_text
		mov edx, ecx
		call gstdio_draw_hex
		call gstdio_new_line

		mov ebx, EDXTxt
		call gstdio_draw_text
		pop edx
		call gstdio_draw_hex
		call gstdio_new_line

		mov ebx, ESITxt
		call gstdio_draw_text
		mov edx, esi
		call gstdio_draw_hex
		call gstdio_new_line

		mov ebx, EDITxt
		call gstdio_draw_text
		mov edx, edi
		call gstdio_draw_hex
		call gstdio_new_line

		mov ebx, EBPTxt
		call gstdio_draw_text
		mov edx, ebp
		call gstdio_draw_hex
		call gstdio_new_line

		mov ebx, EIPTxt
		call gstdio_draw_text
		pop edx
		call gstdio_draw_hex
		call gstdio_new_line

		mov ebx, CSTxt
		call gstdio_draw_text
		pop edx
		call gstdio_draw_hex
		call gstdio_new_line

		mov ebx, EFlagsTxt
		call gstdio_draw_text
		pop edx
		call gstdio_draw_hex
		call gstdio_new_line
		jmp $

;*******************************************
; Exceptions
;*******************************************
; 0: Divide By Zero
idt_isr0:
		cli
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr0txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 1: Debug
idt_isr1:
		cli
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr1txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 2: Non Maskable Interrupt
idt_isr2:
		cli
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr2txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 3: Breakpoint
idt_isr3:
		cli
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr3txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 4: Overflow
idt_isr4:
		cli
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr4txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 5: Bound Range Exceeded
idt_isr5:
		cli
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr5txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 6: Invalid Opcode
idt_isr6:
		cli
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr6txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 7: Device Not Available
idt_isr7:
		cli
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr7txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 8: Double Fault
idt_isr8:
		cli
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr8txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 9: Coprocessor Segment Overrun
idt_isr9:
		cli
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr9txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 10: Invalid TSS
idt_isr10:
		cli
;		mov ebx, 1
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr10txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 11: Segment Not Present
idt_isr11:
		cli
;		mov ebx, 1
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr11txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 12: Stack Segment Fault
idt_isr12:
		cli
;		mov ebx, 1
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr12txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 13: General Protection Fault
idt_isr13:
		cli
;		mov ebx, 1
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr13txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 14: Page Fault
idt_isr14:
		cli
;		mov ebx, 1
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr14txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 15: Reserved
idt_isr15:
		cli
;		mov ebx, 1
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr15txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 16: x87 Floating-Point Exception
idt_isr16:
		cli
;		mov ebx, 1
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr16txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 17: Alignment Check
idt_isr17:
		cli
;		mov ebx, 1
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr17txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 18: Machine Check
idt_isr18:
		cli
;		mov ebx, 1
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr18txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

; 19: SIMD Floating-Point Exception
idt_isr19:
		cli
;		mov ebx, 1
;		call gstdio_clrscr
		call gstdio_new_line
		mov ebx, idt_isr19txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

idt_isr20:
		cli
		mov ebx, idt_isr20txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

idt_isr21:
		cli
		mov ebx, idt_isr21txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr22:
		cli
		mov ebx, idt_isr22txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr23:
		cli
		mov ebx, idt_isr23txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr24:
		cli
		mov ebx, idt_isr24txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr25:
		cli
		mov ebx, idt_isr25txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr26:
		cli
		mov ebx, idt_isr26txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr27:
		cli
		mov ebx, idt_isr27txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr28:
		cli
		mov ebx, idt_isr28txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr29:
		cli
		mov ebx, idt_isr29txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr30:
		cli
		mov ebx, idt_isr30txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr31:
		cli
		mov ebx, idt_isr31txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr32:
		cli
		mov ebx, idt_isr32txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr33:
		cli
		mov ebx, idt_isr33txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr34:
		cli
		mov ebx, idt_isr34txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr35:
		cli
		mov ebx, idt_isr35txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr36:
		cli
		mov ebx, idt_isr36txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr37:
		cli
		mov ebx, idt_isr37txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr38:
		cli
		mov ebx, idt_isr38txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr39:
		cli
		mov ebx, idt_isr39txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr40:
		cli
		mov ebx, idt_isr40txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr41:
		cli
		mov ebx, idt_isr41txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr42:
		cli
		mov ebx, idt_isr42txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr43:
		cli
		mov ebx, idt_isr43txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr44:
		cli
		mov ebx, idt_isr44txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr45:
		cli
		mov ebx, idt_isr45txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr46:
		cli
		mov ebx, idt_isr46txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr47:
		cli
		mov ebx, idt_isr47txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr48:
		cli
		mov ebx, idt_isr48txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr49:
		cli
		mov ebx, idt_isr49txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr50:
		cli
		mov ebx, idt_isr50txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr51:
		cli
		mov ebx, idt_isr51txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr52:
		cli
		mov ebx, idt_isr52txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr53:
		cli
		mov ebx, idt_isr53txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr54:
		cli
		mov ebx, idt_isr54txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr55:
		cli
		mov ebx, idt_isr55txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr56:
		cli
		mov ebx, idt_isr56txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr57:
		cli
		mov ebx, idt_isr57txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr58:
		cli
		mov ebx, idt_isr58txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr59:
		cli
		mov ebx, idt_isr59txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr60:
		cli
		mov ebx, idt_isr60txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr61:
		cli
		mov ebx, idt_isr61txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr62:
		cli
		mov ebx, idt_isr62txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr63:
		cli
		mov ebx, idt_isr63txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr64:
		cli
		mov ebx, idt_isr64txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr65:
		cli
		mov ebx, idt_isr65txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr66:
		cli
		mov ebx, idt_isr66txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr67:
		cli
		mov ebx, idt_isr67txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr68:
		cli
		mov ebx, idt_isr68txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr69:
		cli
		mov ebx, idt_isr69txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr70:
		cli
		mov ebx, idt_isr70txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr71:
		cli
		mov ebx, idt_isr71txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr72:
		cli
		mov ebx, idt_isr72txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr73:
		cli
		mov ebx, idt_isr73txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr74:
		cli
		mov ebx, idt_isr74txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr75:
		cli
		mov ebx, idt_isr75txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr76:
		cli
		mov ebx, idt_isr76txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr77:
		cli
		mov ebx, idt_isr77txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr78:
		cli
		mov ebx, idt_isr78txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr79:
		cli
		mov ebx, idt_isr79txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr80:
		cli
		mov ebx, idt_isr80txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr81:
		cli
		mov ebx, idt_isr81txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr82:
		cli
		mov ebx, idt_isr82txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr83:
		cli
		mov ebx, idt_isr83txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr84:
		cli
		mov ebx, idt_isr84txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr85:
		cli
		mov ebx, idt_isr85txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr86:
		cli
		mov ebx, idt_isr86txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr87:
		cli
		mov ebx, idt_isr87txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr88:
		cli
		mov ebx, idt_isr88txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr89:
		cli
		mov ebx, idt_isr89txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr90:
		cli
		mov ebx, idt_isr90txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr91:
		cli
		mov ebx, idt_isr91txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr92:
		cli
		mov ebx, idt_isr92txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr93:
		cli
		mov ebx, idt_isr93txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr94:
		cli
		mov ebx, idt_isr94txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr95:
		cli
		mov ebx, idt_isr95txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr96:
		cli
		mov ebx, idt_isr96txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr97:
		cli
		mov ebx, idt_isr97txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr98:
		cli
		mov ebx, idt_isr98txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr99:
		cli
		mov ebx, idt_isr99txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr100:
		cli
		mov ebx, idt_isr100txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr101:
		cli
		mov ebx, idt_isr101txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr102:
		cli
		mov ebx, idt_isr102txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr103:
		cli
		mov ebx, idt_isr103txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr104:
		cli
		mov ebx, idt_isr104txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr105:
		cli
		mov ebx, idt_isr105txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr106:
		cli
		mov ebx, idt_isr106txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr107:
		cli
		mov ebx, idt_isr107txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr108:
		cli
		mov ebx, idt_isr108txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr109:
		cli
		mov ebx, idt_isr109txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr110:
		cli
		mov ebx, idt_isr110txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr111:
		cli
		mov ebx, idt_isr111txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr112:
		cli
		mov ebx, idt_isr112txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr113:
		cli
		mov ebx, idt_isr113txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr114:
		cli
		mov ebx, idt_isr114txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr115:
		cli
		mov ebx, idt_isr115txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr116:
		cli
		mov ebx, idt_isr116txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr117:
		cli
		mov ebx, idt_isr117txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr118:
		cli
		mov ebx, idt_isr118txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr119:
		cli
		mov ebx, idt_isr119txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr120:
		cli
		mov ebx, idt_isr120txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr121:
		cli
		mov ebx, idt_isr121txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr122:
		cli
		mov ebx, idt_isr122txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr123:
		cli
		mov ebx, idt_isr123txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr124:
		cli
		mov ebx, idt_isr124txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr125:
		cli
		mov ebx, idt_isr125txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr126:
		cli
		mov ebx, idt_isr126txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr127:
		cli
		mov ebx, idt_isr127txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr128:
		cli
		mov ebx, idt_isr128txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr129:
		cli
		mov ebx, idt_isr129txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr130:
		cli
		mov ebx, idt_isr130txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr131:
		cli
		mov ebx, idt_isr131txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr132:
		cli
		mov ebx, idt_isr132txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr133:
		cli
		mov ebx, idt_isr133txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr134:
		cli
		mov ebx, idt_isr134txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr135:
		cli
		mov ebx, idt_isr135txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr136:
		cli
		mov ebx, idt_isr136txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr137:
		cli
		mov ebx, idt_isr137txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr138:
		cli
		mov ebx, idt_isr138txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr139:
		cli
		mov ebx, idt_isr139txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr140:
		cli
		mov ebx, idt_isr140txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr141:
		cli
		mov ebx, idt_isr141txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr142:
		cli
		mov ebx, idt_isr142txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr143:
		cli
		mov ebx, idt_isr143txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr144:
		cli
		mov ebx, idt_isr144txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr145:
		cli
		mov ebx, idt_isr145txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr146:
		cli
		mov ebx, idt_isr146txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr147:
		cli
		mov ebx, idt_isr147txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr148:
		cli
		mov ebx, idt_isr148txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr149:
		cli
		mov ebx, idt_isr149txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr150:
		cli
		mov ebx, idt_isr150txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr151:
		cli
		mov ebx, idt_isr151txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr152:
		cli
		mov ebx, idt_isr152txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr153:
		cli
		mov ebx, idt_isr153txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr154:
		cli
		mov ebx, idt_isr154txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr155:
		cli
		mov ebx, idt_isr155txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr156:
		cli
		mov ebx, idt_isr156txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr157:
		cli
		mov ebx, idt_isr157txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr158:
		cli
		mov ebx, idt_isr158txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr159:
		cli
		mov ebx, idt_isr159txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr160:
		cli
		mov ebx, idt_isr160txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr161:
		cli
		mov ebx, idt_isr161txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr162:
		cli
		mov ebx, idt_isr162txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr163:
		cli
		mov ebx, idt_isr163txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr164:
		cli
		mov ebx, idt_isr164txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr165:
		cli
		mov ebx, idt_isr165txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr166:
		cli
		mov ebx, idt_isr166txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr167:
		cli
		mov ebx, idt_isr167txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr168:
		cli
		mov ebx, idt_isr168txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr169:
		cli
		mov ebx, idt_isr169txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr170:
		cli
		mov ebx, idt_isr170txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr171:
		cli
		mov ebx, idt_isr171txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr172:
		cli
		mov ebx, idt_isr172txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr173:
		cli
		mov ebx, idt_isr173txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr174:
		cli
		mov ebx, idt_isr174txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr175:
		cli
		mov ebx, idt_isr175txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr176:
		cli
		mov ebx, idt_isr176txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr177:
		cli
		mov ebx, idt_isr177txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr178:
		cli
		mov ebx, idt_isr178txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr179:
		cli
		mov ebx, idt_isr179txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr180:
		cli
		mov ebx, idt_isr180txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr181:
		cli
		mov ebx, idt_isr181txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr182:
		cli
		mov ebx, idt_isr182txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr183:
		cli
		mov ebx, idt_isr183txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr184:
		cli
		mov ebx, idt_isr184txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr185:
		cli
		mov ebx, idt_isr185txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr186:
		cli
		mov ebx, idt_isr186txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr187:
		cli
		mov ebx, idt_isr187txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr188:
		cli
		mov ebx, idt_isr188txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr189:
		cli
		mov ebx, idt_isr189txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr190:
		cli
		mov ebx, idt_isr190txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr191:
		cli
		mov ebx, idt_isr191txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr192:
		cli
		mov ebx, idt_isr192txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr193:
		cli
		mov ebx, idt_isr193txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr194:
		cli
		mov ebx, idt_isr194txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr195:
		cli
		mov ebx, idt_isr195txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr196:
		cli
		mov ebx, idt_isr196txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr197:
		cli
		mov ebx, idt_isr197txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr198:
		cli
		mov ebx, idt_isr198txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr199:
		cli
		mov ebx, idt_isr199txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr200:
		cli
		mov ebx, idt_isr200txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr201:
		cli
		mov ebx, idt_isr201txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr202:
		cli
		mov ebx, idt_isr202txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr203:
		cli
		mov ebx, idt_isr203txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr204:
		cli
		mov ebx, idt_isr204txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr205:
		cli
		mov ebx, idt_isr205txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr206:
		cli
		mov ebx, idt_isr206txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr207:
		cli
		mov ebx, idt_isr207txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr208:
		cli
		mov ebx, idt_isr208txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr209:
		cli
		mov ebx, idt_isr209txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr210:
		cli
		mov ebx, idt_isr210txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr211:
		cli
		mov ebx, idt_isr211txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr212:
		cli
		mov ebx, idt_isr212txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr213:
		cli
		mov ebx, idt_isr213txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr214:
		cli
		mov ebx, idt_isr214txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr215:
		cli
		mov ebx, idt_isr215txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr216:
		cli
		mov ebx, idt_isr216txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr217:
		cli
		mov ebx, idt_isr217txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr218:
		cli
		mov ebx, idt_isr218txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr219:
		cli
		mov ebx, idt_isr219txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr220:
		cli
		mov ebx, idt_isr220txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr221:
		cli
		mov ebx, idt_isr221txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr222:
		cli
		mov ebx, idt_isr222txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr223:
		cli
		mov ebx, idt_isr223txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr224:
		cli
		mov ebx, idt_isr224txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr225:
		cli
		mov ebx, idt_isr225txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr226:
		cli
		mov ebx, idt_isr226txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr227:
		cli
		mov ebx, idt_isr227txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr228:
		cli
		mov ebx, idt_isr228txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr229:
		cli
		mov ebx, idt_isr229txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr230:
		cli
		mov ebx, idt_isr230txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr231:
		cli
		mov ebx, idt_isr231txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr232:
		cli
		mov ebx, idt_isr232txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr233:
		cli
		mov ebx, idt_isr233txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr234:
		cli
		mov ebx, idt_isr234txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr235:
		cli
		mov ebx, idt_isr235txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr236:
		cli
		mov ebx, idt_isr236txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr237:
		cli
		mov ebx, idt_isr237txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr238:
		cli
		mov ebx, idt_isr238txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr239:
		cli
		mov ebx, idt_isr239txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr240:
		cli
		mov ebx, idt_isr240txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr241:
		cli
		mov ebx, idt_isr241txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr242:
		cli
		mov ebx, idt_isr242txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr243:
		cli
		mov ebx, idt_isr243txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr244:
		cli
		mov ebx, idt_isr244txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr245:
		cli
		mov ebx, idt_isr245txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr246:
		cli
		mov ebx, idt_isr246txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr247:
		cli
		mov ebx, idt_isr247txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr248:
		cli
		mov ebx, idt_isr248txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr249:
		cli
		mov ebx, idt_isr249txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr250:
		cli
		mov ebx, idt_isr250txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr251:
		cli
		mov ebx, idt_isr251txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr252:
		cli
		mov ebx, idt_isr252txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr253:
		cli
		mov ebx, idt_isr253txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr254:
		cli
		mov ebx, idt_isr254txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret
idt_isr255:
		cli
		mov ebx, idt_isr255txt
		call gstdio_draw_text
		jmp idt_info
		jmp $
		iret

idt_isr_arr dd	idt_isr0, idt_isr1, idt_isr2, idt_isr3, idt_isr4, idt_isr5, idt_isr6, idt_isr7, idt_isr8, idt_isr9, idt_isr10, 
			dd	idt_isr11, idt_isr12, idt_isr13, idt_isr14, idt_isr15, idt_isr16, idt_isr17, idt_isr18, idt_isr19, idt_isr20, 
			dd	idt_isr21, idt_isr22, idt_isr23, idt_isr24, idt_isr25, idt_isr26, idt_isr27, idt_isr28, idt_isr29, idt_isr30, 
			dd	idt_isr31, idt_isr32, idt_isr33, idt_isr34, idt_isr35, idt_isr36, idt_isr37, idt_isr38, idt_isr39, idt_isr40, 
			dd	idt_isr41, idt_isr42, idt_isr43, idt_isr44, idt_isr45, idt_isr46, idt_isr47, idt_isr48, idt_isr49, idt_isr50, 
			dd	idt_isr51, idt_isr52, idt_isr53, idt_isr54, idt_isr55, idt_isr56, idt_isr57, idt_isr58, idt_isr59, idt_isr60, 
			dd	idt_isr61, idt_isr62, idt_isr63, idt_isr64, idt_isr65, idt_isr66, idt_isr67, idt_isr68, idt_isr69, idt_isr70, 
			dd	idt_isr71, idt_isr72, idt_isr73, idt_isr74, idt_isr75, idt_isr76, idt_isr77, idt_isr78, idt_isr79, idt_isr80, 
			dd	idt_isr81, idt_isr82, idt_isr83, idt_isr84, idt_isr85, idt_isr86, idt_isr87, idt_isr88, idt_isr89, idt_isr90, 
			dd	idt_isr91, idt_isr92, idt_isr93, idt_isr94, idt_isr95, idt_isr96, idt_isr97, idt_isr98, idt_isr99, idt_isr100, 
			dd	idt_isr101, idt_isr102, idt_isr103, idt_isr104, idt_isr105, idt_isr106, idt_isr107, idt_isr108, idt_isr109, idt_isr110, 
			dd	idt_isr111, idt_isr112, idt_isr113, idt_isr114, idt_isr115, idt_isr116, idt_isr117, idt_isr118, idt_isr119, idt_isr120, 
			dd	idt_isr121, idt_isr122, idt_isr123, idt_isr124, idt_isr125, idt_isr126, idt_isr127, idt_isr128, idt_isr129, idt_isr130, 
			dd	idt_isr131, idt_isr132, idt_isr133, idt_isr134, idt_isr135, idt_isr136, idt_isr137, idt_isr138, idt_isr139, idt_isr140, 
			dd	idt_isr141, idt_isr142, idt_isr143, idt_isr144, idt_isr145, idt_isr146, idt_isr147, idt_isr148, idt_isr149, idt_isr150, 
			dd	idt_isr151, idt_isr152, idt_isr153, idt_isr154, idt_isr155, idt_isr156, idt_isr157, idt_isr158, idt_isr159, idt_isr160, 
			dd	idt_isr161, idt_isr162, idt_isr163, idt_isr164, idt_isr165, idt_isr166, idt_isr167, idt_isr168, idt_isr169, idt_isr170, 
			dd	idt_isr171, idt_isr172, idt_isr173, idt_isr174, idt_isr175, idt_isr176, idt_isr177, idt_isr178, idt_isr179, idt_isr180, 
			dd	idt_isr181, idt_isr182, idt_isr183, idt_isr184, idt_isr185, idt_isr186, idt_isr187, idt_isr188, idt_isr189, idt_isr190, 
			dd	idt_isr191, idt_isr192, idt_isr193, idt_isr194, idt_isr195, idt_isr196, idt_isr197, idt_isr198, idt_isr199, idt_isr200, 
			dd	idt_isr201, idt_isr202, idt_isr203, idt_isr204, idt_isr205, idt_isr206, idt_isr207, idt_isr208, idt_isr209, idt_isr210, 
			dd	idt_isr211, idt_isr212, idt_isr213, idt_isr214, idt_isr215, idt_isr216, idt_isr217, idt_isr218, idt_isr219, idt_isr220, 
			dd	idt_isr221, idt_isr222, idt_isr223, idt_isr224, idt_isr225, idt_isr226, idt_isr227, idt_isr228, idt_isr229, idt_isr230, 
			dd	idt_isr231, idt_isr232, idt_isr233, idt_isr234, idt_isr235, idt_isr236, idt_isr237, idt_isr238, idt_isr239, idt_isr240, 
			dd	idt_isr241, idt_isr242, idt_isr243, idt_isr244, idt_isr245, idt_isr246, idt_isr247, idt_isr248, idt_isr249, idt_isr250, 
			dd	idt_isr251, idt_isr252, idt_isr253, idt_isr254, idt_isr255

idt_isr0txt		db	"Division By Zero", 0
idt_isr1txt		db	"Debug", 0
idt_isr2txt		db	"Non Maskable Interrupt", 0
idt_isr3txt		db	"Breakpoint", 0
idt_isr4txt		db	"Overflow", 0
idt_isr5txt		db	"Bound Range Exceeded", 0
idt_isr6txt		db	"Invalid Opcode", 0
idt_isr7txt		db	"Device Not Available", 0
idt_isr8txt		db	"Double Fault", 0
idt_isr9txt		db	"Coprocessor Segment Overrun", 0
idt_isr10txt	db	"Invalid TSS", 0
idt_isr11txt	db	"Segment Not Present", 0
idt_isr12txt	db	"Stack Segment Fault", 0
idt_isr13txt	db	"General Protection Fault", 0
idt_isr14txt	db	"Page Fault", 0
idt_isr15txt	db	"Reserved", 0
idt_isr16txt	db	"x87 Floating-Point Exception", 0
idt_isr17txt	db	"Alignment Check", 0
idt_isr18txt	db	"Machine Check", 0
idt_isr19txt	db	"SIMD Floating-Point Exception", 0
idt_isr20txt	db	"I20", 0
idt_isr21txt	db	"I21", 0
idt_isr22txt	db	"I22", 0
idt_isr23txt	db	"I23", 0
idt_isr24txt	db	"I24", 0
idt_isr25txt	db	"I25", 0
idt_isr26txt	db	"I26", 0
idt_isr27txt	db	"I27", 0
idt_isr28txt	db	"I28", 0
idt_isr29txt	db	"I29", 0
idt_isr30txt	db	"I30", 0
idt_isr31txt	db	"I31", 0
idt_isr32txt	db	"I32", 0
idt_isr33txt	db	"I33", 0
idt_isr34txt	db	"I34", 0
idt_isr35txt	db	"I35", 0
idt_isr36txt	db	"I36", 0
idt_isr37txt	db	"I37", 0
idt_isr38txt	db	"I38", 0
idt_isr39txt	db	"I39", 0
idt_isr40txt	db	"I40", 0
idt_isr41txt	db	"I41", 0
idt_isr42txt	db	"I42", 0
idt_isr43txt	db	"I43", 0
idt_isr44txt	db	"I44", 0
idt_isr45txt	db	"I45", 0
idt_isr46txt	db	"I46", 0
idt_isr47txt	db	"I47", 0
idt_isr48txt	db	"I48", 0
idt_isr49txt	db	"I49", 0
idt_isr50txt	db	"I50", 0
idt_isr51txt	db	"I51", 0
idt_isr52txt	db	"I52", 0
idt_isr53txt	db	"I53", 0
idt_isr54txt	db	"I54", 0
idt_isr55txt	db	"I55", 0
idt_isr56txt	db	"I56", 0
idt_isr57txt	db	"I57", 0
idt_isr58txt	db	"I58", 0
idt_isr59txt	db	"I59", 0
idt_isr60txt	db	"I60", 0
idt_isr61txt	db	"I61", 0
idt_isr62txt	db	"I62", 0
idt_isr63txt	db	"I63", 0
idt_isr64txt	db	"I64", 0
idt_isr65txt	db	"I65", 0
idt_isr66txt	db	"I66", 0
idt_isr67txt	db	"I67", 0
idt_isr68txt	db	"I68", 0
idt_isr69txt	db	"I69", 0
idt_isr70txt	db	"I70", 0
idt_isr71txt	db	"I71", 0
idt_isr72txt	db	"I72", 0
idt_isr73txt	db	"I73", 0
idt_isr74txt	db	"I74", 0
idt_isr75txt	db	"I75", 0
idt_isr76txt	db	"I76", 0
idt_isr77txt	db	"I77", 0
idt_isr78txt	db	"I78", 0
idt_isr79txt	db	"I79", 0
idt_isr80txt	db	"I80", 0
idt_isr81txt	db	"I81", 0
idt_isr82txt	db	"I82", 0
idt_isr83txt	db	"I83", 0
idt_isr84txt	db	"I84", 0
idt_isr85txt	db	"I85", 0
idt_isr86txt	db	"I86", 0
idt_isr87txt	db	"I87", 0
idt_isr88txt	db	"I88", 0
idt_isr89txt	db	"I89", 0
idt_isr90txt	db	"I90", 0
idt_isr91txt	db	"I91", 0
idt_isr92txt	db	"I92", 0
idt_isr93txt	db	"I93", 0
idt_isr94txt	db	"I94", 0
idt_isr95txt	db	"I95", 0
idt_isr96txt	db	"I96", 0
idt_isr97txt	db	"I97", 0
idt_isr98txt	db	"I98", 0
idt_isr99txt	db	"I99", 0
idt_isr100txt	db	"I100", 0
idt_isr101txt	db	"I101", 0
idt_isr102txt	db	"I102", 0
idt_isr103txt	db	"I103", 0
idt_isr104txt	db	"I104", 0
idt_isr105txt	db	"I105", 0
idt_isr106txt	db	"I106", 0
idt_isr107txt	db	"I107", 0
idt_isr108txt	db	"I108", 0
idt_isr109txt	db	"I109", 0
idt_isr110txt	db	"I110", 0
idt_isr111txt	db	"I111", 0
idt_isr112txt	db	"I112", 0
idt_isr113txt	db	"I113", 0
idt_isr114txt	db	"I114", 0
idt_isr115txt	db	"I115", 0
idt_isr116txt	db	"I116", 0
idt_isr117txt	db	"I117", 0
idt_isr118txt	db	"I118", 0
idt_isr119txt	db	"I119", 0
idt_isr120txt	db	"I120", 0
idt_isr121txt	db	"I121", 0
idt_isr122txt	db	"I122", 0
idt_isr123txt	db	"I123", 0
idt_isr124txt	db	"I124", 0
idt_isr125txt	db	"I125", 0
idt_isr126txt	db	"I126", 0
idt_isr127txt	db	"I127", 0
idt_isr128txt	db	"I128", 0
idt_isr129txt	db	"I129", 0
idt_isr130txt	db	"I130", 0
idt_isr131txt	db	"I131", 0
idt_isr132txt	db	"I132", 0
idt_isr133txt	db	"I133", 0
idt_isr134txt	db	"I134", 0
idt_isr135txt	db	"I135", 0
idt_isr136txt	db	"I136", 0
idt_isr137txt	db	"I137", 0
idt_isr138txt	db	"I138", 0
idt_isr139txt	db	"I139", 0
idt_isr140txt	db	"I140", 0
idt_isr141txt	db	"I141", 0
idt_isr142txt	db	"I142", 0
idt_isr143txt	db	"I143", 0
idt_isr144txt	db	"I144", 0
idt_isr145txt	db	"I145", 0
idt_isr146txt	db	"I146", 0
idt_isr147txt	db	"I147", 0
idt_isr148txt	db	"I148", 0
idt_isr149txt	db	"I149", 0
idt_isr150txt	db	"I150", 0
idt_isr151txt	db	"I151", 0
idt_isr152txt	db	"I152", 0
idt_isr153txt	db	"I153", 0
idt_isr154txt	db	"I154", 0
idt_isr155txt	db	"I155", 0
idt_isr156txt	db	"I156", 0
idt_isr157txt	db	"I157", 0
idt_isr158txt	db	"I158", 0
idt_isr159txt	db	"I159", 0
idt_isr160txt	db	"I160", 0
idt_isr161txt	db	"I161", 0
idt_isr162txt	db	"I162", 0
idt_isr163txt	db	"I163", 0
idt_isr164txt	db	"I164", 0
idt_isr165txt	db	"I165", 0
idt_isr166txt	db	"I166", 0
idt_isr167txt	db	"I167", 0
idt_isr168txt	db	"I168", 0
idt_isr169txt	db	"I169", 0
idt_isr170txt	db	"I170", 0
idt_isr171txt	db	"I171", 0
idt_isr172txt	db	"I172", 0
idt_isr173txt	db	"I173", 0
idt_isr174txt	db	"I174", 0
idt_isr175txt	db	"I175", 0
idt_isr176txt	db	"I176", 0
idt_isr177txt	db	"I177", 0
idt_isr178txt	db	"I178", 0
idt_isr179txt	db	"I179", 0
idt_isr180txt	db	"I180", 0
idt_isr181txt	db	"I181", 0
idt_isr182txt	db	"I182", 0
idt_isr183txt	db	"I183", 0
idt_isr184txt	db	"I184", 0
idt_isr185txt	db	"I185", 0
idt_isr186txt	db	"I186", 0
idt_isr187txt	db	"I187", 0
idt_isr188txt	db	"I188", 0
idt_isr189txt	db	"I189", 0
idt_isr190txt	db	"I190", 0
idt_isr191txt	db	"I191", 0
idt_isr192txt	db	"I192", 0
idt_isr193txt	db	"I193", 0
idt_isr194txt	db	"I194", 0
idt_isr195txt	db	"I195", 0
idt_isr196txt	db	"I196", 0
idt_isr197txt	db	"I197", 0
idt_isr198txt	db	"I198", 0
idt_isr199txt	db	"I199", 0
idt_isr200txt	db	"I200", 0
idt_isr201txt	db	"I201", 0
idt_isr202txt	db	"I202", 0
idt_isr203txt	db	"I203", 0
idt_isr204txt	db	"I204", 0
idt_isr205txt	db	"I205", 0
idt_isr206txt	db	"I206", 0
idt_isr207txt	db	"I207", 0
idt_isr208txt	db	"I208", 0
idt_isr209txt	db	"I209", 0
idt_isr210txt	db	"I210", 0
idt_isr211txt	db	"I211", 0
idt_isr212txt	db	"I212", 0
idt_isr213txt	db	"I213", 0
idt_isr214txt	db	"I214", 0
idt_isr215txt	db	"I215", 0
idt_isr216txt	db	"I216", 0
idt_isr217txt	db	"I217", 0
idt_isr218txt	db	"I218", 0
idt_isr219txt	db	"I219", 0
idt_isr220txt	db	"I220", 0
idt_isr221txt	db	"I221", 0
idt_isr222txt	db	"I222", 0
idt_isr223txt	db	"I223", 0
idt_isr224txt	db	"I224", 0
idt_isr225txt	db	"I225", 0
idt_isr226txt	db	"I226", 0
idt_isr227txt	db	"I227", 0
idt_isr228txt	db	"I228", 0
idt_isr229txt	db	"I229", 0
idt_isr230txt	db	"I230", 0
idt_isr231txt	db	"I231", 0
idt_isr232txt	db	"I232", 0
idt_isr233txt	db	"I233", 0
idt_isr234txt	db	"I234", 0
idt_isr235txt	db	"I235", 0
idt_isr236txt	db	"I236", 0
idt_isr237txt	db	"I237", 0
idt_isr238txt	db	"I238", 0
idt_isr239txt	db	"I239", 0
idt_isr240txt	db	"I240", 0
idt_isr241txt	db	"I241", 0
idt_isr242txt	db	"I242", 0
idt_isr243txt	db	"I243", 0
idt_isr244txt	db	"I244", 0
idt_isr245txt	db	"I245", 0
idt_isr246txt	db	"I246", 0
idt_isr247txt	db	"I247", 0
idt_isr248txt	db	"I248", 0
idt_isr249txt	db	"I249", 0
idt_isr250txt	db	"I250", 0
idt_isr251txt	db	"I251", 0
idt_isr252txt	db	"I252", 0
idt_isr253txt	db	"I253", 0
idt_isr254txt	db	"I254", 0
idt_isr255txt	db	"I255", 0



idt_isr_39Spec:
		iret


%ifdef AUDIO_DEF
idt_isr_hdaudio:
		cli
		pushad
		call hdaudio_handle_irq
		mov al, [idt_hda_irq_num]					; EOI
		call pic_interrupt_done
		popad
		sti
		iret
%endif

%ifdef HARDDISK_DEF
; IRQ 14, 15 (i.e. remapped 46, 47 are from the winchesters)
idt_isr_hd14:
		cli
		pushad
		call hd_irq_handler
		mov al, 14 					; EOI
		call pic_interrupt_done
		popad
		sti
		iret


idt_isr_hd15:
		cli
		pushad
		call hd_irq_handler
		mov al, 15 					; EOI
		call pic_interrupt_done
		popad
		sti
		iret
%endif


%ifdef USB_DEF
	%ifdef USB_XHCI_IRQ_DEF
		idt_isr_xhci:
			cli
			pushad
			call xhci_handle_irq
			mov al, [idt_xhci_irq_num]					; EOI
			call pic_interrupt_done
			popad
			sti
			iret
	%endif
%endif


section .data

;*******************************************
; Interrupt Descriptor Table (IDT)
;*******************************************
idt_start:
idt_entry_arr: times (IDT_MAX_INTERRUPTS*IDT_ENTRY_SIZE) db 0

idt_end:
idt_ptr:
		.limit	dw idt_end - idt_start			; bits 0...15 is size of idt
		.base	dd idt_start					; base of idt


%ifdef AUDIO_DEF
	; IRQ number of HDAudio from PCI-config
	idt_hda_irq_num	db 0
%endif

%ifdef USB_DEF
	%ifdef USB_XHCI_IRQ_DEF
		; IRQ number of XHCI from PCI-config
		idt_xhci_irq_num		db 0
	%endif
%endif

;baseLowOffs	db	0
;selectorOffs	db	2
;reservedOffs	db	4
;flagsOffs		db	5
;baseHiOffs		db	6

;STRUC idtentry
;.m_baseLow:	resw 1
;.m_selector:	resw 1
;.m_reserved:	resb 1
;.m_flags:		resb 1
;.m_baseHi:		resw 1
;ENDSTRUC


%endif

