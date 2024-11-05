%ifndef __FORTH_TASK__
%define __FORTH_TASK__


%include "pit.asm"
%include "forth/taskdefs.asm"
%include "forth/rts.asm"
%include "forth/core.asm"


%define MAX_TASKNAME_LEN	15		; maximum chars in a taskname (chnum+chars=16)

; we need to add the offset of USER_SP and USER_RSP in the task-struct, that why we need these
%define USER_SP_OFFS		USER_SP*CELL_SIZE		
%define USER_RSP_OFFS		USER_RSP*CELL_SIZE


section .text

;*********************************************
;	_activate			ACTIVATE
;	( taskid -- )
;	Activates(i.e. creates) the taskid task 
;	by setting PREPARED state to RUNNING, 
;	so it will be executed immediately. 
;	Sets the _ip of the current task to the 
;	runtime code of semicolon (check DOES> too).
;	Saves the current task to the taskbuffer.
;*********************************************
_activate:
			POP_PS(ecx)			; new taskid in ECX
			; check if PREPARED
			mov eax, ecx
			call get_task_state_buff
			cmp DWORD [ebx], TASK_PREPARED
			jz	.Save
			call _paren_exit_paren
			ret					; if not, return. Useful if we tried to do: ALET ALET  (this is incorrect, to use the same task-buff twice)
.Save		mov [tmp_data3], ecx
			mov eax, [_ip]
			mov DWORD [tmp_data], eax
			mov eax, [tmpip]
			mov DWORD [tmp_data2], eax
			; find runtime code of semicolon, and set the _ip of the current task to it
			mov eax, [rtexit]
			mov edx, [rtdoes2]
.Next		mov ebx, [_ip]
			cmp [ebx], eax
			jz	.Found
			cmp [ebx], edx
			jz	.Does2
			add DWORD [_ip], CELL_SIZE
			jmp .Next
.Does2		add ebx, CELL_SIZE
			mov edx, [ebx]		; (exit) in ECX
			add edx, CELL_SIZE
			mov [_ip], edx
.Next2		mov ebx, [_ip]
			cmp [ebx], eax
			jz	.Found
			add DWORD [_ip], CELL_SIZE
			jmp .Next2
.Found		sub DWORD [_ip], CELL_SIZE			; because (colon) will inc it!?
			mov ecx, TASK_PAUSED				; SAVE the current task
			call save_curr_task
			mov eax, [tmp_data]
			mov DWORD [_ip], eax
			mov eax, [tmp_data2]
			mov DWORD [tmpip], eax
			mov ecx, [tmp_data3]
			mov eax, ecx
			dec eax
			mov ebx, [_tasklen]
			mul ebx
			add eax, [_taskbuff]
			mov ebx, eax
			add ebx, TASK_PARENTID_OFFS
			mov eax, [_taskid]
			mov DWORD [ebx], eax
			mov [_taskid], ecx
			inc DWORD [tasks_cnt]
			sub ebx, TASK_PARENTID_OFFS
			add ebx, TASK_COUNTER_OFFS
			mov DWORD [ebx], 0
			sub ebx, TASK_COUNTER_OFFS
			add ebx, TASK_STATE_OFFS
			mov DWORD [ebx], TASK_RUNNING
			sub ebx, TASK_STATE_OFFS
			; copy dict-ptr for FORGET
			add ebx, TASK_DP_OFFS
			mov eax, [act_dp]
			mov DWORD [ebx], eax
			; set the stack-ptr of this buffer
			mov eax, [esp]						; but first save the return address of the current task
			mov [tmp_data], eax
			mov eax, [_taskid]
			mov ebx, STACKLEN
			mul ebx
			add eax, STACKBUFF
			mov esp, eax	
			mov eax, [tmp_data]
			sub esp, CELL_SIZE					; set the return address from ACTIVATE on the new stack
			mov [esp], eax
			; init uservars
			mov eax, [_taskid]
			mov ebx, [_pstacklen]
			mul ebx			
			add eax, [_pstackbuff]
			mov [_pstack0], eax
			mov esi, eax
			mov eax, [_taskid]
			mov ebx, [_rstacklen]
			mul ebx			
			add eax, [_rstackbuff]
			mov [_rstack0], eax
			mov edi, eax
			sub edi, CELL_SIZE				; A task runs in a colon-def, so rstack-ptr can't point to rstack0. E.g. (USER) needs it for dereferencing
			mov DWORD [_base], 10
			mov DWORD [_tib], TIB
			mov DWORD [_tib_size], DEF_TIB_SIZE
			mov DWORD [_source_id], 0
			mov DWORD [_input_buffer], TIB				;!?
			mov DWORD [_in_input_buffer], 0
			mov DWORD [_to_in], 0						;!?
			mov DWORD [_state], 0
			mov DWORD [in_colon], 0
			; _ip, tmpip contains the previous task's data, so it is ok. The previous task is the one that created this one
			mov DWORD [_blk], 0
			mov DWORD [_scr], 0
			mov DWORD [dps_on_pstack], 0
			mov DWORD [_error], E_OK
			; should we clear s_tmp_buff !?
.Back		ret


;*********************************************
; _gettbuff					GETTBUFF
;	(-- taskid taskbuff) 
;	if no free taskbuff: ( -- 0)
;	Finds first UNUSED taskbuff.
;*********************************************
_gettbuff:
			mov ebx, [_taskbuff]
			add ebx, TASK_STATE_OFFS
			mov ecx, 1
.NextTask	cmp DWORD [ebx], TASK_UNUSED
			jz	.Found
			add ebx, [_tasklen]
			inc ecx
			cmp ecx, TASK_MAX_NUM+1			; +1 because ecx starts from 1
			jnz	.NextTask
			PUSH_PS(0)
			jmp .Back
.Found		PUSH_PS(ecx)
			PUSH_PS(ebx)
.Back		ret


;*********************************************
; _kill				KILL
;	( taskid -- )
;	Sets taskid task to UNUSED, so it won't 
;	be activated again. Decrements tasks_cnt.
;	A task can't kill itself. 
;	Use TERMINATE to do that.
;*********************************************
_kill:
			POP_PS(eax)
			cmp eax, [_taskid]		; a task can't kill itself
			jz .Back
			cmp eax, MAX_INITIAL_TASK_ID	; The Main-task and the dummy-task cannot be killed
			jna .Back
			; if SLEEPING, then remove from PIT with cli/sti
			cli
			push eax
			call get_task_state_buff
			pop eax
			cmp DWORD [ebx], TASK_SLEEPING
			jnz	.Skip
			push ebx
			call pit_remove_task
			pop ebx
.Skip		sti
			cmp DWORD [ebx], TASK_PAUSED
			jnz .NoDec
			dec DWORD [tasks_cnt]
.NoDec		mov DWORD [ebx], TASK_UNUSED
.Back		ret


;*********************************************
; _pause				PAUSE
;	( -- )
;	Switches tasks
;	Saves the current task to taskbuff, 
;	sets it to PAUSED, saves user vars and
;	loads next PAUSED task from taskbuff. 
;	Sets it's state to RUNNING 
;*********************************************
_pause:
			cli
			mov DWORD [pit_task_ticks], 0	; clear pit-counter 
			; first, check if there is at least one PAUSED task (maybe all are sleeping)
			; e.g. the dummy-task calls PAUSE, but the Main-task is sleeping (and all other tasks)
			mov eax, [_taskid]
			dec eax
			mov ebx, [_tasklen]
			mul ebx
			mov ebx, [_taskbuff]
			add ebx, eax
			call find_paused_task
			cmp ecx, -1
			je	.Back

			mov ecx, TASK_PAUSED
			call save_curr_task
			call activate_next_task
.Back		sti
			ret


;*********************************************
; _resume				RESUME
;	( taskid -- )
;	Sets taskid task to PAUSED, so it can 
;	be activated again with PAUSE.
;	A task cannot RESUME itself (it is not even executed, so it's impossible).
;*********************************************
_resume:
			POP_PS(eax)
			cmp eax, [_taskid]
			jz .Back
			; is it suspended?
			call get_task_state_buff
			cmp DWORD [ebx], TASK_SUSPENDED
			jnz	.Back
			mov DWORD [ebx], TASK_PAUSED
			inc DWORD [tasks_cnt]
.Back		ret


;*********************************************
; _sleep				SLEEP
;	( n -- )
;	waits n millisecs
;*********************************************
_sleep:
			POP_PS(ebx)
			call pit_sleep
			ret


;*********************************************
; _suspend				SUSPEND
;	( taskid -- )
;	Sets taskid task to SUSPEND, so it won't 
;	be activated till RESUME sets it to PAUSED.
;	A task cannot SUSPEND itself.
;*********************************************
_suspend:
			POP_PS(eax)
			cmp eax, [_taskid]
			jz .Back
			cmp eax, MAX_INITIAL_TASK_ID		; The Main-task and the dummy-task cannot be suspended
			jna .Back
			; if SLEEPING, then remove from PIT with cli/sti
			cli
			push eax
			call get_task_state_buff
			pop eax
			cmp DWORD [ebx], TASK_SLEEPING
			jnz	.Skip
			push ebx
			call pit_remove_task
			pop ebx
.Skip		sti
			cmp DWORD [ebx], TASK_PAUSED
			jnz .Back
			dec DWORD [tasks_cnt]
			mov DWORD [ebx], TASK_SUSPENDED
.Back		ret


;*********************************************
; _task				TASK
;	( -- taskid)
;	Finds the first UNUSED taskbuff and sets it to PREPARED. 
;	Copies its name to the taskbuff.
;	If there is no UNUSED, then taskbuffer is full (TASK_MAX_NUM) 
;	and taskid is zero, name is thrown away.
; TASKNAME should be less than MAX_TASKNAME_LEN ! (or it will be truncated)
;*********************************************
_task:
			cmp DWORD [in_colon], 1			;!?
			jz	.Back
			call _gettbuff
			POP_PS(ebx)
			cmp ebx, 0
			jnz .Found
			; throw away name
			mov eax, DELIM
			PUSH_PS(eax)
			call _word
			POP_PS(eax)
			PUSH_PS(0)
			jmp .Back
.Found		POP_PS(ecx)
			mov DWORD [ebx], TASK_PREPARED
			sub ebx, TASK_STATE_OFFS
			add ebx, TASK_NAME_OFFS
			push ecx
			mov eax, DELIM						; read name
			PUSH_PS(eax)
			push DWORD [_to_in]
			push ebx
			call _word					; ptr to flags|len-byte on pstack
			pop ebx
			pop DWORD [_to_in]
			POP_PS(eax)
			push esi
			push edi
			mov esi, eax
			xor ecx, ecx
			mov cl, BYTE [esi]
			cmp cl, MAX_TASKNAME_LEN
			jna	.Save
			mov cl, MAX_TASKNAME_LEN
.Save		mov BYTE [ebx], cl
			inc esi
			inc ebx
			mov edi, ebx
			rep movsb
			pop edi
			pop esi
			call create_definition
			COMPILE_CELL(_paren_variable_paren)
			pop ecx
			COMPILE_CELL(ecx)						; variable holds taskid
			PUSH_PS(ecx)
			call mark_word
.Back		ret


; TOOLS ?
;*********************************************
; _tasks				TASKS
;	( -- )
;	Prints RUNNING, PAUSED, SLEEPING and SUSPENDED
;	tasks (id, parentid, name, counter, state)
;*********************************************
_tasks:
			call _c_r
			mov ebx, TasksHeaderTxt
			call gstdio_draw_text
			call _c_r
			mov ebx, [_taskbuff]
			add ebx, TASK_STATE_OFFS
			mov ecx, 1
.NextTask	cmp DWORD [ebx], TASK_UNUSED
			jz	.Skip
			push ecx
			sub ebx, TASK_STATE_OFFS
			mov edx, [ebx]
			PUSH_PS(edx)
			push ebx
			push edx
			call _dot
			call _space
			pop edx							; if id is less than 10 then another space
			cmp edx, 10
			jnc .NoSpace
			call _space
.NoSpace	pop ebx
			add ebx, TASK_PARENTID_OFFS
			mov edx, [ebx]
			PUSH_PS(edx)
			push ebx
			push edx
			call _dot
			call _space			
			pop edx							; if pid is less than 10 then another space
			cmp edx, 10
			jnc .NoSpace2
			call _space
.NoSpace2	pop ebx
			sub ebx, TASK_PARENTID_OFFS
			add ebx, TASK_NAME_OFFS
			inc ebx
			PUSH_PS(ebx)
			dec ebx
			xor edx, edx
			mov dl, BYTE [ebx]
			push ebx
			push edx
			PUSH_PS(edx)
			call _type
			pop ecx
			mov edx, MAX_TASKNAME_LEN
			sub edx, ecx
			PUSH_PS(edx)
			call _spaces
			call _space
			pop ebx
			sub ebx, TASK_NAME_OFFS

			add ebx, TASK_COUNTER_OFFS		; counter
			mov edx, [ebx]
			call gstdio_draw_hex
			push ebx
			call _space
			pop ebx
			sub ebx, TASK_COUNTER_OFFS

			add ebx, TASK_STATE_OFFS
			push ebx
			mov eax, [ebx]
			dec eax
			shl eax, CELL_SIZE_SHIFT
			mov ebx, eax
			mov ebx, [taskstxts+ebx]
			call gstdio_draw_text
			pop ebx
			call _c_r
			pop ecx
.Skip		add ebx, [_tasklen]
			inc ecx
			cmp ecx, TASK_MAX_NUM+1
			jnz	.NextTask
			ret


;*********************************************
; _task_clear_counter		TASKCLRCNT
;	( taskid -- )
;	Clears the counter of task
;*********************************************
_task_clear_counter:
			cli
			POP_PS(eax)
			dec eax
			mov ebx, [_tasklen]
			mul ebx
			mov ebx, [_taskbuff]
			add ebx, eax
			add ebx, TASK_COUNTER_OFFS
			mov DWORD [ebx], 0
			sti
			ret


;*********************************************
; _terminate		TERMINATE
;	( -- )
;	Sets the state of the current task to UNUSED
;	in the taskbuffer. Decrements tasks_cnt
;	Swithes tasks.
;*********************************************
_terminate:
			cmp DWORD [_taskid], MAX_INITIAL_TASK_ID		; The Main-task and the dummy-task can't be terminated
			jna .Back
			mov eax, [_taskid]
			dec eax
			mov ebx, [_tasklen]
			mul ebx
			mov ebx, [_taskbuff]
			add ebx, eax
			add ebx, TASK_STATE_OFFS
			mov DWORD [ebx], TASK_UNUSED
			sub ebx, TASK_STATE_OFFS
			dec DWORD [tasks_cnt]
			call activate_next_task
.Back		mov BYTE [from_irq], 0
			ret



; find next task that is PAUSED (circular: search TASK_MAX_NUM taskstructs from current task)
;	The dummy-task only calls PAUSE (so not SLEEP), so we can at least switch to it.
;	BTW, we can't wait for tasks to wakeup here in a loop, if this func was called from Pit-IRQ. 
; Clears pit_task_counter, otherwise PIT-IRQ would jump to WelcomeMsg (inits the system)
;	useful if a task is in a forever loop and doesn't call PAUSE
; IN: EBX contains the pointer to the task-struct of the current _taskid 
activate_next_task:
			call find_paused_task
			cmp ecx, -1
			jne	activate_task ;.Do
			call gstdio_new_line
			mov ebx, NoFreeTaskTxt
			call gstdio_draw_text
			jmp $
activate_task:		; EBX(ptr to task-buff); ECX (taskid to activate)
.Do			mov DWORD [pit_task_runtime], 0
			mov DWORD [pit_task_ticks], 0	; clear pit-counter 
			mov [_taskid], ecx
			; calc task-struct from ecx
			add ebx, TASK_STATE_OFFS
			mov DWORD [ebx], TASK_RUNNING
			sub ebx, TASK_STATE_OFFS
			add ebx, TASK_STACK_OFFS
			mov esp, [ebx]
			sub ebx, TASK_STACK_OFFS
			add ebx, TASK_USERVAR_OFFS	
			push esi
			push edi
			mov ecx, USER_NUM
			mov esi, ebx
			mov edi, user_table
			rep movsd
			pop edi
			pop esi
			; load stacks (param and return)
			add ebx, USER_SP_OFFS
			mov esi, [ebx]
			sub ebx, USER_SP_OFFS
			add ebx, USER_RSP_OFFS
			mov edi, [ebx]
			mov ebp, [saved_dp]					; restore dict-ptr
			cmp BYTE [from_irq], 1
			je	.EOI							; TERMINATE is called from PIT, and a stack-switch takes place here, so it won't return to PIT!!
			jmp .Back
.EOI		mov BYTE [from_irq], 0
			mov al, 0							; EOI
			call pic_interrupt_done
.Back		sti
			ret


; IN: EBX contains the pointer to the task-struct of the given (current) _taskid 
; OUT: ECX the task-slot, or -1 if not found; EBX ptr to its task_struct
; We start from taskid+1 to have RoundRobin
find_paused_task:
			cmp DWORD [_taskid], TASK_MAX_NUM
			jz	.Begin
			; from taskid+1 to TASK_MAX_NUM
			add ebx, TASK_STATE_OFFS
			mov ecx, [_taskid]
			inc ecx
.NextTask	add ebx, [_tasklen]
			cmp DWORD [ebx], TASK_PAUSED
			jz	.Found
			inc ecx
			cmp ecx, TASK_MAX_NUM
			jnz	.NextTask
			; from 1 to taskid
.Begin		mov ecx, 1
			mov ebx, [_taskbuff]
			add ebx, TASK_STATE_OFFS
.NextTask2	cmp DWORD [ebx], TASK_PAUSED
			jz	.Found
			add ebx, [_tasklen]
			inc ecx
			cmp ecx, [_taskid]
			jnz .NextTask2
			mov ecx, -1
.Found		sub ebx, TASK_STATE_OFFS
			ret


; taskid in EAX
; OUT: EBX ptr to state in taskstruct (i.e. taskbuff)
get_task_state_buff:
			dec eax
			mov ebx, [_tasklen]
			mul ebx
			mov ebx, [_taskbuff]
			add ebx, eax
			add ebx, TASK_STATE_OFFS
			ret


; called from PIT
_pause2:
			mov ecx, TASK_SLEEPING
			call save_curr_task
			call activate_next_task
			ret


; Saves current task to its task-structure (i.e. buffer)
; IN: ECX state
; OUT: EBX contains the pointer to its task-struct
save_curr_task:
			cmp DWORD [_taskid], MAIN_TASK_ID
			jne	.SkipDP
			mov [saved_dp], ebp					; save dict-ptr
.SkipDP		mov eax, [_taskid]
			dec eax
			mov ebx, [_tasklen]
			mul ebx
			mov ebx, [_taskbuff]
			add ebx, eax
			add ebx, TASK_STATE_OFFS
			mov DWORD [ebx], ecx				; set state of current task
			sub ebx, TASK_STATE_OFFS
			add ebx, TASK_STACK_OFFS			; save ESP (stack ptr)
			mov eax, esp
			add eax, CELL_SIZE					; throw away the return address of the caller
			mov DWORD [ebx], eax
			sub ebx, TASK_STACK_OFFS
			add ebx, TASK_COUNTER_OFFS			; save task_counter (pit-irq, in milliseconds); for how much time the task used the CPU
			mov eax, [pit_task_runtime]
			cmp eax, [ebx]
			jna	.Users
			mov [ebx], eax
.Users		sub ebx, TASK_COUNTER_OFFS
			add ebx, TASK_USERVAR_OFFS			; save user vars
			push esi
			push edi
			mov ecx, USER_NUM
			mov esi, user_table
			mov edi, ebx
			rep movsd
			pop edi
			pop esi
			; save stacks (param and return)
			add ebx, USER_SP_OFFS
			mov [ebx], esi
			sub ebx, USER_SP_OFFS
			add ebx, USER_RSP_OFFS
			mov [ebx], edi
			sub ebx, USER_RSP_OFFS
			sub ebx, TASK_USERVAR_OFFS
			ret


; The dummy-task only calls PAUSE. If for example, the Main-task is the only task, and
;	it calls SLEEP, we can switch to the dummy-task. So we will have a loop.
dummy_task:
.Do			call _pause
			inc DWORD [dummy_task_counter]
			cmp DWORD [dummy_task_counter], 1000
			jna	.Next
			mov DWORD [dummy_task_counter], 0
			call kybrd_get_last_key
			call kybrd_key_to_ascii	
			cmp bl, 0
			jz	.Next
			call kybrd_get_ctrl
			cmp al, 1
			jnz	.Erase
			mov [last_key], bl				; PIT-IRQ will need the last-key (e.g. ctrl-c), but _accept function discards it
			jmp .Next
.Erase		mov BYTE [last_key], 0
.Next		jmp .Do
			ret


; kill all the tasks that have greater dict-ptrs saved.
; FORGET is EXEC_ONLY, so only the main task can FORGET! 
; (what about LOAD !?)
; IN: _last_tmp(pointer to word to FORGET)
kill_tasks:
			mov ebx, [_taskbuff]
			add ebx, TASK_STATE_OFFS
			mov ecx, 1
.NextTask	cmp DWORD [ebx], TASK_UNUSED
			jnz	.Check
.IncTS		add ebx, [_tasklen]
			inc ecx
			cmp ecx, TASK_MAX_NUM
			jnz	.NextTask
			jmp .Back
.Check		mov edx, ebx
			sub edx, TASK_STATE_OFFS
			add edx, TASK_DP_OFFS
			mov eax, [_last_tmp]
			cmp DWORD [edx], eax
			jc .IncTS
		; remove
			push ebx
			push edx
			PUSH_PS(ecx)
			call _kill
			pop edx
			pop ebx
			jmp	.IncTS
.Back		ret


section .data

_taskbuff	dd	0		; address of taskbuff of TASK_MAX_NUM
_tasklen	dd	0		; length of task-struct
_taskid		dd	0		; id of current task (from 1 to TASK_MAX_NUM)

;errTaskBuffInUseTxt db "Error: task-buffer already in use: ", 0
TaskIdTxt		db "(TaskId: ", 0
NoFreeTaskTxt	db "Error: no free task found", 0

; for word TASKS (id, parentid, name, counter, state)
TasksHeaderTxt	db "ID  PID NAME            Counter  State", 0
;taskstxtlen equ $-TasksHeaderTxt
TasksPreparedTxt	db "Prepared", 0
TasksRunningTxt		db "Running", 0
TasksPausedTxt		db "Paused", 0
TasksSleepingTxt	db "Sleeping", 0
TasksSuspendedTxt	db "Suspended", 0

taskstxts	dd TasksPreparedTxt, TasksRunningTxt, TasksPausedTxt, TasksSleepingTxt, TasksSuspendedTxt

; needed in _activate (storing the _ip, tmpip and data on pstack)
tmp_data		dd	0		; in _activate to store the _ip
tmp_data2		dd	0		; and tmpip
tmp_data3		dd	0	


%endif

