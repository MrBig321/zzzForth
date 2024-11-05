;*************************************************************************
;
;	pit.inc
;		8253 Programmable Interval Timer
;
;*************************************************************************

%ifndef __PIT__
%define __PIT__

%include "pic.asm"
%include "kybrd.asm"
%ifdef MULTITASKING_DEF
	%include "forth/taskdefs.asm"
	%include "forth/task.asm"		; _pause2
%endif

bits 32

%define		PIT_TASK_COUNTER_LIMIT	10000		; 10 seconds

;-----------------------------------------------
;	Operational Command Bit masks
;-----------------------------------------------

%define		PIT_OCW_MASK_BINCOUNT		1		;00000001
%define		PIT_OCW_MASK_MODE			0xE		;00001110
%define		PIT_OCW_MASK_RL				0x30	;00110000
%define		PIT_OCW_MASK_COUNTER		0xC0	;11000000

;-----------------------------------------------
;	Operational Command control bits
;-----------------------------------------------

; Use when setting binary count mode
%define		PIT_OCW_BINCOUNT_BINARY		0		;0
%define		PIT_OCW_BINCOUNT_BCD		1		;1

; Use when setting counter mode
%define		PIT_OCW_MODE_TERMINALCOUNT	0		;0000
%define		PIT_OCW_MODE_ONESHOT		0x2		;0010
%define		PIT_OCW_MODE_RATEGEN		0x4		;0100
%define		PIT_OCW_MODE_SQUAREWAVEGEN	0x6		;0110
%define		PIT_OCW_MODE_SOFTWARETRIG	0x8		;1000
%define		PIT_OCW_MODE_HARDWARETRIG	0xA		;1010

; Use when setting data transfer
%define		PIT_OCW_RL_LATCH			0			;000000
%define		PIT_OCW_RL_LSBONLY			0x10		;010000
%define		PIT_OCW_RL_MSBONLY			0x20		;100000
%define		PIT_OCW_RL_DATA				0x30		;110000

; Use when setting the counter we are working with
%define		PIT_OCW_COUNTER_0			0		;00000000
%define		PIT_OCW_COUNTER_1			0x40	;01000000
%define		PIT_OCW_COUNTER_2			0x80	;10000000


;-----------------------------------------------
;	Controller Registers
;-----------------------------------------------

%define		PIT_REG_COUNTER0		0x40
%define		PIT_REG_COUNTER1		0x41
%define		PIT_REG_COUNTER2		0x42
%define		PIT_REG_COMMAND			0x43

PIT_IRQ_NUM		equ 32
PIT_FREQ		equ 1000 ; hz		; set bochs-cfg to real-time in order to have a 1-ms timer!


section .text

;***********************************************
; pit_init
;***********************************************
pit_init:
			mov ebx, PIT_IRQ_NUM
			mov edx, pit_irq
			call idt_install_irh
			ret


;***********************************************
; pit_start_counter
;***********************************************
pit_start_counter:
			mov dx, 1193180 / PIT_FREQ
			mov al, PIT_OCW_MODE_SQUAREWAVEGEN
			mov bl, PIT_OCW_MASK_RL
			not bl
			and al, bl
			or	al, 0						; 0 is counter 
			out PIT_REG_COMMAND, al
			mov ax, dx
			out PIT_REG_COUNTER0, al
			xchg ah, al
			out PIT_REG_COUNTER0, al

%ifdef MULTITASKING_DEF
			mov [pit_ticks], DWORD 0
%endif
			ret

; It's this simple
;pit_start_counter:
;			mov dx, 1193180 / PIT_FREQ
;			mov al, 36h
;			out 43h, al
;			mov ax, dx
;			out 40h, al
;			xchg ah, al
;			out 40h, al
;
;			mov [pit_ticks], DWORD 0
;			ret


%ifdef MULTITASKING_DEF
;***********************************************
; pit_irq
;	Sleeping tasks. Checks counter-stops in the pit_sleep_stops
;	When one is expired, it sets the task's 
;	state to PAUSED, and clears the counterstop.
;	Checks Ctrl-m (reinits Main-task) and Ctrl-c, 
;	if pressed terminates current task.
;
;	Useful if task is in forever loop 
;	(if it calls PAUSE, the keyboard will be read by _accept).
;	If doesn't call PAUSE, then the pit_task_ticks counter will be used.

;	If there is only the Main-task running and it calls SLEEP, 
;	there would be no task to switch to (to have it run in a loop).
;	That's why there is a dummy-task that just calls PAUSE.
;***********************************************
; IRET pops EIP, CS and EFLAGS from the stack and resumes execution of the interrupted procedure.
pit_irq:
			cli
			pushad
			inc DWORD [pit_ticks]
			inc DWORD [pit_ticks2]
			inc DWORD [pit_task_runtime]
			inc DWORD [pit_task_ticks]
			cmp DWORD [pit_task_ticks], PIT_TASK_COUNTER_LIMIT
			jc	.ChkKeys
			cmp DWORD [_taskid], MAX_INITIAL_TASK_ID
			jna	.InitMain
			jmp .Switch
			; Ctrl-m or Ctrl-c ?
.ChkKeys	inc WORD [pit_ctrl_check_cnt]
			cmp WORD [pit_ctrl_check_cnt], 100			; counter
			jnge .ChkTasks
			mov WORD [pit_ctrl_check_cnt], 0
			call kybrd_get_ctrl
			cmp al, 1
			jnz	.ChkTasks
			cmp BYTE [last_key], KEY_M					; Main-task can be stopped with Ctrl+m
			jnz	.ChkC
.InitMain	mov BYTE [last_key], 0
			mov DWORD [pit_taskcnt], 0
			mov DWORD [pit_task_ticks], 0
			mov ecx, TASK_MAX_NUM
			mov edi, pit_sleep_stops
			xor eax, eax
			rep stosd
			mov WORD [pit_ctrl_check_cnt], 0
			mov DWORD [esp+8*4], Stage3					; EIP is not the first one because of PUSHAD
			jmp	.EOI
.ChkC		cmp BYTE [last_key], KEY_C					; a non-Main-task can be stopped with Ctrl+c
			jnz	.ChkTasks
			cmp DWORD [_taskid], MAX_INITIAL_TASK_ID	; don't kill the main or the dummy task!
			jna	.ChkTasks
.Switch		mov ebx, [_taskbuff]
			call find_paused_task
			cmp ecx, -1
			jne	.Terminate
			jmp .InitMain
.Terminate	mov BYTE [last_key], 0
			mov BYTE [from_irq], 1
			call _terminate				; TERMINATE calls PAUSE-code, so the code won't return here!! (it clears pit_task_ticks too!)
			; end of Ctrl-m and -c
.ChkTasks	cmp DWORD [pit_taskcnt], 0
			jz	.EOI
			xor ecx, ecx
			mov edx, [_taskbuff]
			mov ebx, pit_sleep_stops
			mov eax, [pit_ticks]
.Next		cmp DWORD [ebx], 0
			jz	.Inc
			cmp eax, [ebx]
			jnc .Set
.Inc		add ebx, CELL_SIZE
			add edx, [_tasklen]
			inc ecx
			cmp ecx, TASK_MAX_NUM
			jnz	.Next
			jmp	.EOI
.Set		add edx, TASK_STATE_OFFS
			mov DWORD [edx], TASK_PAUSED			; was the task sleeping for sure? (well, its pit-counter is non-zero)
			sub edx, TASK_STATE_OFFS
			dec DWORD [pit_taskcnt]
			mov DWORD [ebx], 0
			inc DWORD [tasks_cnt]
			cmp DWORD [pit_taskcnt], 0
			jz	.EOI
			jmp .Inc
.EOI		mov al, 0								; EOI
			call pic_interrupt_done
			popad
			sti
			iret			; alias for iretd because of BITS 32


;***********************************************
; pit_sleep
;	EBX: ticks(ms!?) to wait
;	Stores counter+delay in pit_sleep_stops 
;	according to its taskid.
;	Sets the state of the task to SLEEPING.
;	Switches tasks by calling _pause2.
;***********************************************
pit_sleep:
			cli
			push ebx
			mov eax, [_taskid]
			dec eax
			shl eax, CELL_SIZE_SHIFT
			mov ebx, pit_sleep_stops
			add ebx, eax
			pop ecx
			add ecx, [pit_ticks]
			mov DWORD [ebx], ecx
			inc DWORD [pit_taskcnt]
			dec DWORD [tasks_cnt]
			call _pause2
			sti
			ret


;***********************************************
; pit_remove_task
;	EAX: taskid
;	When a task gets killed or suspended, then it 
;	needs to be removed from PIT
;***********************************************
pit_remove_task:
;			cli
			dec eax
			shl eax, CELL_SIZE_SHIFT
			mov ebx, pit_sleep_stops
			add ebx, eax
			mov DWORD [ebx], 0
			dec DWORD [pit_taskcnt]
;			sti
			ret

%else

;***********************************************
; pit_irq			(single-tasking)
;***********************************************
; IRET pops EIP, CS and EFLAGS from the stack and resumes execution of the interrupted procedure.
pit_irq:
			cli
			pushad
			inc DWORD [pit_ticks2]
			; Ctrl-m ?
			inc WORD [pit_ctrl_check_cnt]
			cmp WORD [pit_ctrl_check_cnt], 100			; counter
			jnge .EOI
			mov WORD [pit_ctrl_check_cnt], 0
			call kybrd_get_ctrl
			cmp al, 1
			jnz	.EOI
			cmp BYTE [last_key], KEY_M					; Go to Welcome-Msg with Ctrl+m
			jnz	.EOI
			; Ctrl-M
			mov DWORD [esp+8*4], Stage3					; EIP is not the first one because of PUSHAD
			mov BYTE [last_key], 0
			mov DWORD [pit_ticks2], 0
			mov WORD [pit_ctrl_check_cnt], 0
.EOI		mov al, 0	
			call pic_interrupt_done
			popad
			sti
			iret			; alias for iretd because of BITS 32

%endif


;***********************************************
; pit_delay
;	EBX: ticks(ms!?) to wait
;	Used in polling (e.g. hard-disk), 
;	no task-switch, i.e. PAUSE
; NOTE: this is called from e.g. USB driver
;***********************************************
pit_delay:
			mov DWORD [pit_ticks2], 0
.Chk		cmp ebx, [pit_ticks2]
			ja	.Chk
			ret


section .data


%ifdef MULTITASKING_DEF

pit_ticks		dd 0				; for sleep

; TASK_MAX_NUM structs of counterstop. When counterstop is reached, timer sets the state of the task to PAUSED.
pit_sleep_stops times TASK_MAX_NUM dd 0	; reserve TASK_MAX_NUM*32-bit counterstop; 0 means unused
pit_taskcnt	dd 0		; we don't need to scan all TASK_MAX_NUM pit_sleep_stops. Only pit_taskcnt. It is faster.

pit_task_ticks	dd 0	; cleared in _pause. If a task is in a forever-loop and doesn't call PAUSE, then the keyboard won't be read (_accept), so the only way to stop a task like that is with a counter.
pit_task_runtime dd 0	; if a task calls pause, but it's the only task, then it will run again (PAUSE clears pit_task_ticks)

%endif

pit_ctrl_check_cnt	dw 0
pit_ticks2			dd 0				; for polling-sleep (no task-switch (i.e. PAUSE) in Multitasking-mode)


%endif

