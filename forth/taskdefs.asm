%ifndef __FORTH_TASKDEFS__
%define __FORTH_TASKDEFS__


%define TASK_MAX_NUM	100

; prios
%define TASK_PRIO_LOW		0
%define TASK_PRIO_NORMAL	1
%define TASK_PRIO_HIGH		2

; states
%define TASK_UNUSED		0
%define TASK_PREPARED	1
%define TASK_RUNNING	2
%define TASK_PAUSED		3
%define TASK_SLEEPING	4
%define TASK_SUSPENDED	5

%define	MAIN_TASK_ID		1
%define	DUMMY_TASK_ID		2
%define	MAX_INITIAL_TASK_ID	2

; offsets in bytes
%define TASK_ID_OFFS		0
%define TASK_PARENTID_OFFS	4
%define TASK_NAME_OFFS		8
%define TASK_PRIORITY_OFFS	24
%define TASK_STATE_OFFS		28
%define TASK_DP_OFFS		32
%define TASK_STACK_OFFS		36
%define TASK_COUNTER_OFFS	40
%define TASK_USERVAR_OFFS	44


%endif

