;********************************************************************
;
;	pic.inc
;		8259 Programmable Interrupt Controller
;
;*********************************************************************

%ifndef __PIC__
%define __PIC__

bits 32

; The following devices use PIC 1 to generate interrupts
%define		PIC_IRQ_TIMER			0
%define		PIC_IRQ_KEYBOARD		1
%define		PIC_IRQ_SERIAL2			3
%define		PIC_IRQ_SERIAL1			4
%define		PIC_IRQ_PARALLEL2		5
%define		PIC_IRQ_DISKETTE		6
%define		PIC_IRQ_PARALLEL1		7

; The following devices use PIC 2 to generate interrupts
%define		PIC_IRQ_CMOSTIMER		0
%define		PIC_IRQ_CGARETRACE		1
%define		PIC_IRQ_AUXILIARY		4
%define		PIC_IRQ_FPU				5
%define		PIC_IRQ_HDC				6

;-----------------------------------------------
;	Command words are used to control the devices
;-----------------------------------------------

; Command Word 2 bit masks. Use when sending commands
%define		PIC_OCW2_MASK_L1		1		;00000001
%define		PIC_OCW2_MASK_L2		2		;00000010
%define		PIC_OCW2_MASK_L3		4		;00000100
%define		PIC_OCW2_MASK_EOI		0x20	;00100000
%define		PIC_OCW2_MASK_SL		0x40	;01000000
%define		PIC_OCW2_MASK_ROTATE	0x80	;10000000

; Command Word 3 bit masks. Use when sending commands
%define		PIC_OCW3_MASK_RIS		1		;00000001
%define		PIC_OCW3_MASK_RIR		2		;00000010
%define		PIC_OCW3_MASK_MODE		4		;00000100
%define		PIC_OCW3_MASK_SMM		0x20	;00100000
%define		PIC_OCW3_MASK_ESMM		0x40	;01000000
%define		PIC_OCW3_MASK_D7		0x80	;10000000


;-----------------------------------------------
;	Controller Registers
;-----------------------------------------------

; PIC 1 register port addresses
%define PIC1_REG_COMMAND	0x20
%define PIC1_REG_STATUS		0x20
%define PIC1_REG_DATA		0x21
%define PIC1_REG_IMR		0x21

; PIC 2 register port addresses
%define PIC2_REG_COMMAND	0xA0
%define PIC2_REG_STATUS		0xA0
%define PIC2_REG_DATA		0xA1
%define PIC2_REG_IMR		0xA1

;-----------------------------------------------
;	Initialization Command Bit Masks
;-----------------------------------------------

; Initialization Control Word 1 bit masks
%define PIC_ICW1_MASK_IC4			0x1			;00000001
%define PIC_ICW1_MASK_SNGL			0x2			;00000010
%define PIC_ICW1_MASK_ADI			0x4			;00000100
%define PIC_ICW1_MASK_LTIM			0x8			;00001000
%define PIC_ICW1_MASK_INIT			0x10		;00010000

; Initialization Control Words 2 and 3 do not require bit masks

; Initialization Control Word 4 bit masks
%define PIC_ICW4_MASK_UPM			0x1			;00000001
%define PIC_ICW4_MASK_AEOI			0x2			;00000010
%define PIC_ICW4_MASK_MS			0x4			;00000100
%define PIC_ICW4_MASK_BUF			0x8			;00001000
%define PIC_ICW4_MASK_SFNM			0x10		;00010000

;-----------------------------------------------
;	Initialization Command 1 control bits
;-----------------------------------------------

%define PIC_ICW1_IC4_EXPECT				1			;1
%define PIC_ICW1_IC4_NO					0			;0
%define PIC_ICW1_SNGL_YES				2			;10
%define PIC_ICW1_SNGL_NO				0			;00
%define PIC_ICW1_ADI_CALLINTERVAL4		4			;100
%define PIC_ICW1_ADI_CALLINTERVAL8		0			;000
%define PIC_ICW1_LTIM_LEVELTRIGGERED	8			;1000
%define PIC_ICW1_LTIM_EDGETRIGGERED		0			;0000
%define PIC_ICW1_INIT_YES				0x10		;10000
%define PIC_ICW1_INIT_NO				0			;00000

;-----------------------------------------------
;	Initialization Command 4 control bits
;-----------------------------------------------

%define PIC_ICW4_UPM_86MODE			1			;1
%define PIC_ICW4_UPM_MCSMODE		0			;0
%define PIC_ICW4_AEOI_AUTOEOI		2			;10
%define PIC_ICW4_AEOI_NOAUTOEOI		0			;0
%define PIC_ICW4_MS_BUFFERMASTER	4			;100
%define PIC_ICW4_MS_BUFFERSLAVE		0			;0
%define PIC_ICW4_BUF_MODEYES		8			;1000
%define PIC_ICW4_BUF_MODENO			0			;0
%define PIC_ICW4_SFNM_NESTEDMODE	0x10		;10000
%define PIC_ICW4_SFNM_NOTNESTED		0			;a binary 2 (joke)


section .text

;************************************************
; pic_init  (remap)
;************************************************
; Normally, IRQs 0 to 7 are mapped to entries 8 to 15. This
;  is a problem in protected mode, because IDT entry 8 is a
;  Double Fault! Without remapping, every time IRQ0 fires,
;  you get a Double Fault Exception, which is NOT actually
;  what's happening. We send commands to the Programmable
;  Interrupt Controller (PICs - also called the 8259's) in
;  order to make IRQ0 to 15 be remapped to IDT entries 32 to
;  47 
pic_init:
			mov al, PIC_ICW1_INIT_YES+PIC_ICW1_IC4_EXPECT
			out PIC1_REG_COMMAND, al
			out PIC2_REG_COMMAND, al
			mov al, 0x20
			out PIC1_REG_DATA, al
			mov al, 0x28
			out PIC2_REG_DATA, al
			mov al, 0x04
			out PIC1_REG_DATA, al
			mov al, 0x02
			out PIC2_REG_DATA, al
			mov al, PIC_ICW1_INIT_YES+PIC_ICW1_IC4_EXPECT
			mov bl, PIC_ICW4_MASK_UPM
			not bl
			and al, bl
			or	al, PIC_ICW4_UPM_86MODE
			out PIC1_REG_DATA, al
			out PIC2_REG_DATA, al
;			mov al, 0x0
;			out PIC1_REG_DATA, al
;			out PIC2_REG_DATA, al
			ret


; It's this simple
;pic_init:
;			mov al, 0x11
;			out 0x20, al
;			out 0xA0, al
;			mov al, 0x20
;			out 0x21, al
;			mov al, 0x28
;			out 0xA1, al
;			mov al, 0x04
;			out 0x21, al
;			mov al, 0x02
;			out 0xA1, al
;			mov al, 0x01
;			out 0x21, al
;			out 0xA1, al
;			mov al, 0x0
;			out 0x21, al
;			out 0xA1, al
;			ret


;************************************************
; pic_interrupt_done
; AL: intnum
; called from pit and kbd
;************************************************
pic_interrupt_done:
			; ensure its a valid hardware irq
			cmp al, 16
			jg .Back
			; test if we need to send end-of-interrupt to second pic
			cmp al, 8
			jge .Second
			jmp .First
.Second		mov al, 0x20
			out 0xA0, al
			; always send end-of-interrupt to primary pic
.First		mov al, 0x20
			out 0x20, al
.Back		ret



%endif

