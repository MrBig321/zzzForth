%ifndef __XHCI__
%define __XHCI__

%include "pci.asm"
%include "pit.asm"
%include "gstdio.asm"
%include "gutil.asm"
%include "usb/common.asm"
%include "usb/scsi.asm"


; For debugging:
;%define DBGXHCI_INIT
;%define DBGXHCI_TR_RING_INIT
;%define DBGXHCI_PORTINFO
;%define DBGXHCI_RESETPORT
;%define DBGXHCI_CONTROL
;%define DBGXHCI_EPPTRARR
;%define DBGXHCI_CONTROLSUB
;%define DBGXHCI_IRQ
;%define DBGXHCI_DEVINFO
;%define DBGXHCI_INITMSD
;%define DBGXHCI_BULKIO
;%define DBGXHCI_BULK_READ
;%define DBGXHCI_BULK_WRITE

; If we define DO_DEVDESC8, then first SetAddress(with blocking) 
;  (slotstate=1 and deviceaddress=0 set by Bochs) will be sent and 
;  the first 8 bytes of the DeviceDescriptor will be retrieved, 
;  only then will SetAddress(without blocking) sent, and all 18 bytes of the DevDesc retrieved
;  Note that this fails with Bochs (SetAddress(without blocking): CompletionCode=19, i.e. ContextStateError in EventTRB
;       Also fails on real hw getting the 8 bytes of the DevDesc: CompletionCode=4, i.e. USB Transaction Error
; If we don't define DO_DEVDESC8, we only send SetAddress(without blocking) 
;  (slotstate=2 and deviceaddress=2 set by Bochs) and retrieve all 18 bytes of the DevDesc (works!).
;%define DO_DEVDESC8

%define	XHCI_HEAP_INIT		0x600000		; from FORTH-Memory-Map(FMM) in forth/forth.asm
%define	XHCI_HEAP_SIZE		0x400000			; from FORTH-Memory-Map(FMM) in forth/forth.asm
%define	XHCI_HEAP_LIMIT		(XHCI_HEAP_INIT+XHCI_HEAP_SIZE)

%define XHCI_CMND_RING_TRBS			1024 ;4096	
%define XHCI_TRBS_PER_RING			1024 ;4096
%define XHCI_TRBS_PER_EVENT_RING	4096		; currently only one segment is created in xhci_create_event_ring, so this is the maximum
%define XHCI_TRBS_PER_BULK_RING		(4096*28) 	; we can read at least a 45Mb file with this (see also XHCI_HEAP_SIZE)

;%define MAX_BULK_TR_BYTES	65535

%define XHCI_BUFF	0x9000		; from FORTH Memory map		!!??

%define xHC_CAPS_CapLength      0x00
%define xHC_CAPS_Reserved       0x01
%define xHC_CAPS_IVersion       0x02
%define xHC_CAPS_HCSParams1     0x04
%define xHC_CAPS_HCSParams2     0x08
%define xHC_CAPS_HCSParams3     0x0C
%define xHC_CAPS_HCCParams1     0x10
%define xHC_CAPS_DBOFF          0x14
%define xHC_CAPS_RTSOFF         0x18
%define xHC_CAPS_HCCParams2		0x1C

%define xHC_OPS_USBCommand      0x00
%define xHC_OPS_USBStatus       0x04
%define xHC_OPS_USBPageSize     0x08
%define xHC_OPS_USBDnctrl       0x14
%define xHC_OPS_USBCrcr         0x18
%define xHC_OPS_USBDcbaap       0x30
%define xHC_OPS_USBConfig       0x38

%define xHC_OPS_USBPortSt       0x400
%define xHC_Port_PORTSC             0
%define xHC_Port_PORTPMSC           4
%define xHC_Port_PORTLI             8
%define xHC_Port_RESV              12

%define xHC_PortUSB_CHANGE_BITS		((1<<17) | (1<<18) | (1<<20) | (1<<21) | (1<<22))
										; Quirk:  TI TUSB7340: sets bit 19 on USB2 ports  ??????????????

%define xHC_INTERRUPTER_PRIMARY      0

%define xHC_INTERRUPTER_IMAN      0x00
%define xHC_INTERRUPTER_IMOD      0x04
%define xHC_INTERRUPTER_TAB_SIZE  0x08
%define xHC_INTERRUPTER_RESV      0x0C
%define xHC_INTERRUPTER_ADDRESS   0x10
%define xHC_INTERRUPTER_DEQUEUE   0x18

; xHCI speed values
%define xHCI_SPEED_FULL   1
%define xHCI_SPEED_LOW    2
%define xHCI_SPEED_HI     3
%define xHCI_SPEED_SUPER  4

%define xHCI_DIR_NO_DATA  0
%define xHCI_DIR_OUT      2
%define xHCI_DIR_IN       3

%define xHCI_DIR_OUT_B  0
%define xHCI_DIR_IN_B   1

; End Point Doorbell numbers
%define xHCI_SLOT_CNTX   0
%define xHCI_CONTROL_EP  1
%define xHCI_EP1_OUT     2
%define xHCI_EP1_IN      3
%define xHCI_EP2_OUT     4
%define xHCI_EP2_IN      5
%define xHCI_EP3_OUT     6
%define xHCI_EP3_IN      7
%define xHCI_EP4_OUT     8
%define xHCI_EP4_IN      9
%define xHCI_EP5_OUT     10
%define xHCI_EP5_IN      11
%define xHCI_EP6_OUT     12
%define xHCI_EP6_IN      13
%define xHCI_EP7_OUT     14
%define xHCI_EP7_IN      15
%define xHCI_EP8_OUT     16
%define xHCI_EP8_IN      17
%define xHCI_EP9_OUT     18
%define xHCI_EP9_IN      19
%define xHCI_EP10_OUT    20
%define xHCI_EP10_IN     21
%define xHCI_EP11_OUT    22
%define xHCI_EP11_IN     23
%define xHCI_EP12_OUT    24
%define xHCI_EP12_IN     25
%define xHCI_EP13_OUT    26
%define xHCI_EP13_IN     27
%define xHCI_EP14_OUT    28
%define xHCI_EP14_IN     29
%define xHCI_EP15_OUT    30
%define xHCI_EP15_IN     31

; Port_info flags
%define xHCI_PROTO_INFO           (1<<0)  ; bit 0 set = USB3, else USB2
%define xHCI_PROTO_HSO            (1<<1)  ; bit 1 set = is USB 2 and High Speed Only
%define xHCI_PROTO_HAS_PAIR       (1<<2)  ; bit 2 set = has a corresponding port. (i.e.: is a USB3 and has USB2 port (a must))
                                          ;     clear = does not have a corr. port (i.e.: is a USB2 port and does not have a USB3 port)
%define xHCI_PROTO_ACTIVE         (1<<3)  ; is the active port of the pair.

%define xHCI_PROTO_USB2  0
%define xHCI_PROTO_USB3  1

%define xHC_TRB_ID_LINK         6
%define xHC_TRB_ID_NOOP         8

%define xHC_xECP_ID_NONE       0
%define xHC_xECP_ID_LEGACY     1
%define xHC_xECP_ID_PROTO      2
%define xHC_xECP_ID_POWER      3
%define xHC_xECP_ID_VIRT       4
%define xHC_xECP_ID_MESS       5
%define xHC_xECP_ID_LOCAL      6
%define xHC_xECP_ID_DEBUG     10
%define xHC_xECP_ID_EXT_MESS  17

%define xHC_xECP_LEGACY_TIMEOUT     10  ; 10 milliseconds
%define xHC_xECP_LEGACY_BIOS_OWNED  (1<<16)
%define xHC_xECP_LEGACY_OS_OWNED    (1<<24)
%define xHC_xECP_LEGACY_OWNED_MASK  (xHC_xECP_LEGACY_BIOS_OWNED | xHC_xECP_LEGACY_OS_OWNED)

%define XHCI_MAX_CONTEXT_SIZE   64                               ; Max Context size in bytes
%define XHCI_MAX_SLOT_SIZE      (XHCI_MAX_CONTEXT_SIZE * 32)          ; Max Total Slot size in bytes

; Slot State
%define XHCI_SLOT_STATE_DISABLED_ENABLED 	0
%define XHCI_SLOT_STATE_DEFAULT				1
%define XHCI_SLOT_STATE_ADDRESSED			2
%define XHCI_SLOT_STATE_CONFIGURED			3

; EndPoint Types
%define XHCI_EP_TYPE_NOTVALID 	0
%define XHCI_EP_TYPE_ISOCHR_OUT 1
%define XHCI_EP_TYPE_BULK_OUT 	2
%define XHCI_EP_TYPE_INTERR_OUT 3
%define XHCI_EP_TYPE_CONTROL 	4
%define XHCI_EP_TYPE_ISOCHR_IN 	5
%define XHCI_EP_TYPE_BULK_IN 	6
%define XHCI_EP_TYPE_INTERR_IN 	7

%define	XHCI_SLOT_CONTEXT_ENTRIES_OFFS			0
%define	XHCI_SLOT_CONTEXT_HUB_OFFS				4
%define	XHCI_SLOT_CONTEXT_MTT_OFFS				5
%define	XHCI_SLOT_CONTEXT_SPEED_OFFS			6
%define	XHCI_SLOT_CONTEXT_ROUTE_STR_OFFS		10
%define	XHCI_SLOT_CONTEXT_NUM_PORTS_OFFS		14
%define	XHCI_SLOT_CONTEXT_RH_PORT_NUM_OFFS		18
%define	XHCI_SLOT_CONTEXT_MAX_EXIT_LAT_OFFS		22
%define	XHCI_SLOT_CONTEXT_INT_TARGET_OFFS		26
%define	XHCI_SLOT_CONTEXT_TTT_OFFS				30
%define	XHCI_SLOT_CONTEXT_TT_PORT_NUM_OFFS		34
%define	XHCI_SLOT_CONTEXT_TT_HUB_SLOT_ID_OFFS	38
%define	XHCI_SLOT_CONTEXT_SLOT_STATE_OFFS		42
%define	XHCI_SLOT_CONTEXT_DEVICE_ADDR_OFFS		46

; EP State
%define XHCI_EP_STATE_DISABLED 0
%define XHCI_EP_STATE_RUNNING  1
%define XHCI_EP_STATE_HALTED   2
%define XHCI_EP_STATE_STOPPED  3
%define XHCI_EP_STATE_ERROR    4

%define	XHCI_EP_CONTEXT_INTERVAL_OFFS				0
%define	XHCI_EP_CONTEXT_LSA_OFFS					4
%define	XHCI_EP_CONTEXT_MAX_PSTREAMS_OFFS			5
%define	XHCI_EP_CONTEXT_MULT_OFFS					9
%define	XHCI_EP_CONTEXT_EP_STATE_OFFS				13
%define	XHCI_EP_CONTEXT_MAX_PACKET_SIZE_OFFS		17
%define	XHCI_EP_CONTEXT_MAX_BURST_SIZE_OFFS			21
%define	XHCI_EP_CONTEXT_HID_OFFS					25
%define	XHCI_EP_CONTEXT_EP_TYPE_OFFS				26
%define	XHCI_EP_CONTEXT_CERR_OFFS					30
%define	XHCI_EP_CONTEXT_TR_DEQUEUE_PTR_LO_OFFS		34
%define	XHCI_EP_CONTEXT_TR_DEQUEUE_PTR_HI_OFFS		38
%define	XHCI_EP_CONTEXT_DCS_OFFS					42
%define	XHCI_EP_CONTEXT_MAX_ESIT_PAYLOAD_OFFS		43
%define	XHCI_EP_CONTEXT_MAX_AVERAGE_TRB_LEN_OFFS	47

%define	XHCI_TRB_SIZE		16 ; in bytes

; TRB-struct
;%define	XHCI_TRB_PARAM_OFFS		0
;%define	XHCI_TRB_STATUS_OFFS	8
;%define	XHCI_TRB_COMMAND_OFFS	12

%define XHCI_DIR_EP_OUT   0
%define XHCI_DIR_EP_IN    1
;%define XHCI_GET_DIR(x)      (((x) & (1    <<  7)) >> 7)

;%define TRB_GET_STYPE(x)     (((x) & (0x1F << 16)) >> 16)
%define XHCI_TRB_SET_STYPE(x)     (((x) & 0x1F) << 16)
;%define TRB_GET_TYPE(x)      (((x) & (0x3F << 10)) >> 10)
%macro XHCI_TRB_GET_TYPE_REG 1
			mov eax, %1
			and eax, (0x3F << 10)
			shr	eax, 10
%endmacro
%define XHCI_TRB_SET_TYPE(x)      (((x) & 0x3F) << 10)
%macro XHCI_TRB_SET_TYPE_REG 1
			mov eax, %1
			and eax, 0x3F
			shl	eax, 10
%endmacro
;%define XHCI_TRB_GET_COMP_CODE(x) (((x) & (0x7F << 24)) >> 24)
%macro XHCI_TRB_GET_COMP_CODE_REG 1
			mov eax, %1
			and eax, (0x7F << 24)
			shr	eax, 24
%endmacro
;%define TRB_SET_COMP_CODE(x) (((x) & 0x7F) << 24)
;%define XHCI_TRB_GET_SLOT(x)      (((x) & (0xFF << 24)) >> 24)
%macro XHCI_TRB_GET_SLOT_REG 1
			mov eax, %1
			and eax, (0xFF << 24)
			shr	eax, 24
%endmacro
;%define XHCI_TRB_SET_SLOT(x)      (((x) & 0xFF) << 24)
%macro XHCI_TRB_SET_SLOT_REG 1
			mov eax, %1
			and eax, 0xFF
			shl	eax, 24
%endmacro
;%define TRB_GET_TDSIZE(x)    (((x) & (0x1F << 17)) >> 17)
;%define TRB_SET_TDSIZE(x)    (((x) & 0x1F) << 17)
;%define TRB_GET_EP(x)        (((x) & (0x1F << 16)) >> 16)
;%define TRB_SET_EP(x)        (((x) & 0x1F) << 16)

;%define TRB_GET_TARGET(x)    (((x) & (0x3FF << 22)) >> 22)
;%define TRB_GET_TX_LEN(x)     ((x) & 0x1FFFF)
;%define TRB_GET_TOGGLE(x)    (((x) & (1<<1)) >> 1)

;%define TRB_DC(x)            (((x) & (1<<9)) >> 9)
;%define TRB_IS_IMMED_DATA(x) (((x) & (1<<6)) >> 6)
;%define TRB_IOC(x)           (((x) & (1<<5)) >> 5)
;%define TRB_CHAIN(x)         (((x) & (1<<4)) >> 4)
;%define TRB_SPD(x)           (((x) & (1<<2)) >> 2)
;%define TRB_TOGGLE(x)        (((x) & (1<<1)) >> 1)

%define TRB_SET_TYPE(x)      (((x) & 0x3F) << 10)

%define XHCI_TRB_CYCLE_ON			(1<<0)
%define XHCI_TRB_CYCLE_OFF			(0<<0)

%define XHCI_TRB_TOGGLE_CYCLE_ON	(1<<1)
%define XHCI_TRB_TOGGLE_CYCLE_OFF	(0<<1)

%define XHCI_TRB_CHAIN_ON			(1<<4)
%define XHCI_TRB_CHAIN_OFF			(0<<4)

%define XHCITRB_IOC_ON				(1<<5)
%define XHCI_TRB_IOC_OFF			(0<<5)

%define XHCI_TRB_LINK_CMND			(XHCI_TRB_SET_TYPE(XHCI_LINK) | XHCI_TRB_IOC_OFF | XHCI_TRB_CHAIN_OFF | XHCI_TRB_TOGGLE_CYCLE_OFF | XHCI_TRB_CYCLE_ON)

; Common TRB types
%define	XHCI_NORMAL					1
%define	XHCI_SETUP_STAGE			2
%define	XHCI_DATA_STAGE				3
%define	XHCI_STATUS_STAGE			4
%define	XHCI_ISOCH					5
%define	XHCI_LINK					6
%define	XHCI_EVENT_DATA				7
%define	XHCI_NO_OP					8
%define	XHCI_ENABLE_SLOT			9
%define	XHCI_DISABLE_SLOT			10
%define	XHCI_ADDRESS_DEVICE			11
%define	XHCI_CONFIG_EP				12
%define	XHCI_EVALUATE_CONTEXT		13
%define	XHCI_RESET_EP				14
%define	XHCI_STOP_EP				15
%define	XHCI_SET_TR_DEQUEUE			16
%define	XHCI_RESET_DEVICE			17
%define	XHCI_FORCE_EVENT			18
%define	XHCI_DEG_BANDWIDTH			19
%define	XHCI_SET_LAT_TOLERANCE		20
%define	XHCI_GET_PORT_BAND			21
%define	XHCI_FORCE_HEADER			22
%define	XHCI_NO_OP_CMD				23
; 24 - 31 = reserved
%define	XHCI_TRANS_EVENT			32
%define	XHCI_COMMAND_COMPLETION		33
%define	XHCI_PORT_STATUS_CHANGE		34
%define	XHCI_BANDWIDTH_REQUEST		35
%define	XHCI_DOORBELL_EVENT			36
%define	XHCI_HOST_CONTROLLER_EVENT	37
%define	XHCI_DEVICE_NOTIFICATION	38
%define	XHCI_MFINDEX_WRAP			39
       ; 40 - 47 = reserved
       ; 48 - 63 = Vendor Defined

; event completion codes
%define	XHCI_TRB_SUCCESS			1
%define	XHCI_DATA_BUFFER_ERROR		2
%define	XHCI_BABBLE_DETECTION		3
%define	XHCI_TRANSACTION_ERROR		4
%define	XHCI_TRB_ERROR				5
%define	XHCI_STALL_ERROR			6
%define	XHCI_RESOURCE_ERROR			7
%define	XHCI_BANDWIDTH_ERROR		8
%define	XHCI_NO_SLOTS_ERROR			9
%define	XHCI_INVALID_STREAM_TYPE	10
%define	XHCI_SLOT_NOT_ENABLED		11
%define	XHCI_EP_NOT_ENABLED			12
%define	XHCI_SHORT_PACKET			13
%define	XHCI_RING_UNDERRUN			14
%define	XHCI_RUNG_OVERRUN			15
%define	XHCI_VF_EVENT_RING_FULL		16
%define	XHCI_PARAMETER_ERROR		17
%define	XHCI_BANDWITDH_OVERRUN		18
%define	XHCI_CONTEXT_STATE_ERROR	19
%define	XHCI_NO_PING_RESPONSE		20
%define	XHCI_EVENT_RING_FULL		21
%define	XHCI_INCOMPATIBLE_DEVICE	22
%define	XHCI_MISSED_SERVICE			23
%define	XHCI_COMMAND_RING_STOPPED	24
%define	XHCI_COMMAND_ABORTED		25
%define	XHCI_STOPPED				26
%define	XHCI_STOPPER_LENGTH_ERROR	27
%define	XHCI_RESERVED				28
%define	XHCI_ISOCH_BUFFER_OVERRUN	29	; !?
%define	XHCI_EVERN_LOST				32
%define	XHCI_UNDEFINED				33
%define	XHCI_INVALID_STREAM_ID		34
%define	XHCI_SECONDARY_BANDWIDTH	35
%define	XHCI_SPLIT_TRANSACTION		36
       ; 37 - 191 reserved
       ; 192 - 223 vender defined errors
       ; 224 - 225 vendor defined info

%define XHCI_IRQ_DONE  (1<<31)

; Port-Info-struct
%define	XHCI_PORT_INFO_FLAGS_OFFS			0
%define	XHCI_PORT_INFO_OTHER_PORT_NUM_OFFS	1
%define	XHCI_PORT_INFO_OFFSET_OFFS			2
%define	XHCI_PORT_INFO_RESERVED_OFFS		3

%define	XHCI_PORT_INFO_SIZE		4		; in bytes
%define	XHCI_MAX_PORT_INFO_NUM	32		; arbitrary

%define	XHCI_CBW_LEN		31
%define	XHCI_CSW_LEN		13

%define	XHCI_DEVICE_SMALL	0
%define	XHCI_DEVICE_MEDIUM	1
%define	XHCI_DEVICE_BIG		2

%define XHCI_MAX_DEV_CNT 32		; this could be 127, but I belive, we won't use that many devices knowing that currently no external HUBs are supported

%define MAX_TRB_CNT_PER_TR_RING 4096
%define MAX_SEGMENT_CNT_PER_TR_RING 30

;%define xHCI_IS_USB3_PORT(x)  ((port_info[(x)].flags & xHCI_PROTO_INFO) == xHCI_PROTO_USB3)
;%define xHCI_IS_USB2_PORT(x)  ((port_info[(x)].flags & xHCI_PROTO_INFO) == xHCI_PROTO_USB2)
;%define xHCI_IS_USB2_HSO(x)   ((port_info[(x)].flags & xHCI_PROTO_HSO) == xHCI_PROTO_HSO)
;%define xHCI_HAS_PAIR(x)      ((port_info[(x)].flags & xHCI_PROTO_HAS_PAIR) == xHCI_PROTO_HAS_PAIR)
;%define xHCI_IS_ACTIVE(x)     ((port_info[(x)].flags & xHCI_PROTO_ACTIVE) == xHCI_PROTO_ACTIVE)
%macro xHCI_IS_USB3_PORT 1
			push esi
			mov esi, xhci_port_info
			push %1
			shl	%1, 2					; *XHCI_PORT_INFO_SIZE
			add esi, %1
			pop	%1
			mov al, [esi+XHCI_PORT_INFO_FLAGS_OFFS]
			and al, xHCI_PROTO_INFO
			cmp al, xHCI_PROTO_USB3
			je	%%Set
			mov al, 0
			jmp %%Back
%%Set		mov al, 1
%%Back		pop esi
%endmacro

%macro xHCI_IS_USB2_PORT 1
			push esi
			mov esi, xhci_port_info
			push %1
			shl	%1, 2					; *XHCI_PORT_INFO_SIZE
			add esi, %1
			pop	%1
			mov al, [esi+XHCI_PORT_INFO_FLAGS_OFFS]
			and al, xHCI_PROTO_INFO
			cmp al, xHCI_PROTO_USB2
			je	%%Set
			mov al, 0
			jmp %%Back
%%Set		mov al, 1
%%Back		pop esi
%endmacro

%macro xHCI_IS_USB2_HSO 1
			push esi
			mov esi, xhci_port_info
			push %1
			shl	%1, 2					; *XHCI_PORT_INFO_SIZE
			add esi, %1
			pop	%1
			mov al, [esi+XHCI_PORT_INFO_FLAGS_OFFS]
			and al, xHCI_PROTO_HSO
			cmp al, xHCI_PROTO_HSO
			je	%%Set
			mov al, 0
			jmp %%Back
%%Set		mov al, 1
%%Back		pop esi
%endmacro

%macro xHCI_HAS_PAIR 1
			push esi
			mov esi, xhci_port_info
			push %1
			shl	%1, 2					; *XHCI_PORT_INFO_SIZE
			add esi, %1
			pop	%1
			mov al, [esi+XHCI_PORT_INFO_FLAGS_OFFS]
			and al, xHCI_PROTO_HAS_PAIR
			cmp al, xHCI_PROTO_HAS_PAIR
			je	%%Set
			mov al, 0
			jmp %%Back
%%Set		mov al, 1
%%Back		pop esi
%endmacro

%macro xHCI_IS_ACTIVE 1
			push esi
			mov esi, xhci_port_info
			push %1
			shl	%1, 2					; *XHCI_PORT_INFO_SIZE
			add esi, %1
			pop	%1
			mov al, [esi+XHCI_PORT_INFO_FLAGS_OFFS]
			and al, xHCI_PROTO_ACTIVE
			cmp al, xHCI_PROTO_ACTIVE
			je	%%Set
			mov al, 0
			jmp %%Back
%%Set		mov al, 1
%%Back		pop esi
%endmacro


section .text


; IN: -
; OUT: -
xhci_clear_cur_ep_ring_ptr_arr:
			push eax
			push edi
			mov edi, [xhci_cur_ep_ring_ptr_arr]
			mov ecx, XHCI_MAX_DEV_CNT
			xor eax, eax
			rep stosd
			; also clear ring_cycle array
			mov edi, [xhci_cur_ep_ring_cycle_arr]
			mov ecx, XHCI_MAX_DEV_CNT
			xor eax, eax
			rep stosb
			pop edi
			pop eax
			ret


; IN: EAX(slotID), [xhci_cur_ep_ring_ptr], [xhci_cur_ep_ring_cycle]
; OUT: -
xhci_save_cur_ep_ring_ptr:
			push eax
			push ebx
			dec eax
			cmp eax, XHCI_MAX_DEV_CNT
			jnc	.Back
			push eax
			shl	eax, 2				; to have DWORDs
			add eax, xhci_cur_ep_ring_ptr_arr
			mov ebx, [xhci_cur_ep_ring_ptr]
			mov [eax], ebx
			pop eax
			; also save ring_cycle
			add eax, xhci_cur_ep_ring_cycle_arr
			mov bl, [xhci_cur_ep_ring_cycle]
			mov [eax], bl
.Back		pop ebx
			pop eax
			ret


; IN: EAX(slotID)
; OUT: the updated [xhci_cur_ep_ring_ptr] (can be zero, if error) and [xhci_cur_ep_ring_cycle]
xhci_get_cur_ep_ring_ptr:
			push eax
			push ebx
			dec eax
			cmp eax, XHCI_MAX_DEV_CNT
			jnc	.Back
			push eax
			shl	eax, 2				; to have DWORDs
			add eax, xhci_cur_ep_ring_ptr_arr
			mov ebx, [eax]
			mov [xhci_cur_ep_ring_ptr], ebx
			pop eax
			; also get ring_cycle
			add eax, xhci_cur_ep_ring_cycle_arr
			mov bl, [eax]
			mov [xhci_cur_ep_ring_cycle], bl
.Back		pop ebx
			pop eax
			ret

%ifndef USB_XHCI_IRQ_DEF
; IN: -
; OUT: EAX(bus), EBX(dev), ECX(fun), EDX(1, if detected)
xhci_detect_controller:
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
%endif

; This function uses only one xhci-controller (the one that was detected). If there are more xhci-controllers on the PCI-bus, 
; then either use the plugs of this detected xhci-controller, or have arrays to detect all xhci-controllers and 
; set the same irq-handler for all of them.
xhci_enum:
			pushad
			mov DWORD [xhci_res], 0
%ifdef USB_XHCI_IRQ_DEF
			cmp BYTE [pci_xhci_detected], 1
%else
			call xhci_detect_controller
			cmp edx, 1
%endif
			jnz	.Back
%ifdef USB_XHCI_IRQ_DEF
			xor eax, eax
			mov al, [pci_xhci_bus]
			xor ebx, ebx
			mov bl, [pci_xhci_dev]
			xor ecx, ecx
			mov cl, [pci_xhci_fun]
%endif
			mov DWORD [xhci_cur_heap_ptr], XHCI_HEAP_INIT
			mov BYTE [xhci_inited_msd], 0xFF
			push ebx
			mov ebx, xhci_FndXHCICtrlTxt
			call gstdio_draw_text
			mov dh, al
			call gstdio_draw_hex8
			mov ebx, ':'
			call gstdio_draw_char
			pop ebx
			mov dh, bl
			call gstdio_draw_hex8
			push ebx
			mov ebx, ':'
			call gstdio_draw_char
			mov dh, cl
			call gstdio_draw_hex8
			call gstdio_new_line
			mov ebx, xhci_StringPortDevAddrTxt
			call gstdio_draw_text
			pop ebx
			call xhci_process
			mov ebx, [xhci_cur_heap_ptr]
			mov [xhci_cur_heap_ptr_afterenum], ebx
			mov DWORD [xhci_res], 1			; !? otherwise USBENUM returns 0
.Back		popad
			ret


; reset the controller, create a few rings, set the address, and request the device descriptor.
; IN: EAX(bus), EBX(dev), ECX(fun)
xhci_process:
			pushad
%ifdef USB_XHCI_IRQ_DEF
			mov [pci_xhci_bus], al
			mov [pci_xhci_dev], bl
			mov [pci_xhci_fun], cl
%else 
			mov [xhci_bus], al
			mov [xhci_dev], bl
			mov [xhci_fun], cl
%endif
			; mem I/O access enable and bus master enable
			mov WORD [pci_tmp], 0x0006
			mov edx, PCI_COMMAND
			call pci_config_write_word

			; clear the port-info-structs
			push eax
			push ecx
			mov edi, xhci_port_info
			mov eax, 0
			mov ecx, XHCI_MAX_PORT_INFO_NUM*XHCI_PORT_INFO_SIZE
			rep stosb
			pop ecx
			pop eax

			; get base
			push eax
			mov edx, PCI_BAR0
			call pci_config_read_dword
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_Base0Txt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, eax
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			mov edx, eax
			pop eax
			mov [xhci_base_bits4], edx				;
			and DWORD [xhci_base_bits4], 0x0F		;
			and edx, ~0xF
			mov [xhci_base0], edx
			test DWORD [xhci_base_bits4], 1
			jz	.Chk64
			mov ebx, xhci_NotMemMappedIOTxt
			call gstdio_draw_text
			jmp .Back
.Chk64		cmp DWORD [xhci_base_bits4], 0x04
			jne	.FLADJ
			; get upper 32bits of base0
			push eax
			mov edx, PCI_BAR1
			call pci_config_read_dword
			mov edx, eax
			pop eax
			cmp edx, 0
			je	.FLADJ
			mov ebx, xhci_64bitBase0Txt
			call gstdio_draw_text
			jmp .Back
			; Write to the FLADJ register incase the BIOS didn't
			; At the time of this writing, there wasn't a BIOS that supported xHCI yet :-)
.FLADJ		mov BYTE [pci_tmp], 0x20
			mov edx, 0x61
			call pci_config_write_byte
			; read the version register (just a small safety check)
			mov esi, [xhci_base0]
			add esi, xHC_CAPS_IVersion
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_VersionTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov dx, [esi]
		call gstdio_draw_hex16
		call gstdio_new_line
		pop edx
%endif
			cmp WORD [esi], 0x95
			jc	.Back
			; if it is a Panther Point device, make sure sockets are xHCI controlled.
			xor edx, edx
			call pci_config_read_word
			cmp ax, 0x8086
			jne	.CalcOpB
			xor eax, eax
%ifdef USB_XHCI_IRQ_DEF
			mov al, [pci_xhci_bus]
%else
			mov al, [xhci_bus]
%endif
			mov edx, 2
			call pci_config_read_word
			cmp ax, 0x1E31
			jne	.CalcOpB		
			xor eax, eax
%ifdef USB_XHCI_IRQ_DEF
			mov al, [pci_xhci_bus]
%else
			mov al, [xhci_bus]
%endif
			mov edx, 8
			call pci_config_read_byte
			cmp al, 4
			jne	.CalcOpB				
			xor eax, eax
%ifdef USB_XHCI_IRQ_DEF
			mov al, [pci_xhci_bus]
%else
			mov al, [xhci_bus]
%endif
			mov DWORD [pci_tmp], 0xFFFFFFFF
			mov edx, 0xd8
			call pci_config_write_dword
			mov DWORD [pci_tmp], 0xFFFFFFFF
			mov edx, 0xd0
			call pci_config_write_dword
			; calculate the operational base
.CalcOpB	mov esi, [xhci_base0]
			add esi, xHC_CAPS_CapLength
			xor eax, eax
			mov al, [esi]
			mov [xhci_op_base_off], eax
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_OpbaseTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, eax
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			; reset the controller, returning false after 500mS if it doesn't reset
			mov esi, [xhci_base0]
			add esi, eax
			add esi, xHC_OPS_USBCommand
			mov DWORD [esi], (1 << 1)	; changes the other bits too!!
			mov ecx, 500
.IsFinish	mov eax, [esi]
			and eax, (1 << 1)
			jz	.Out
			mov ebx, 1
			call pit_delay
			loop .IsFinish
			mov ebx, xhci_resetCtrllerTOTxt	;TEST
			call gstdio_draw_text
			jmp	.Back
			; if we get here, we have a valid xHCI controller, so set it up.
			; First we need to find out which port access arrays are USB2 and which are USB3

			; calculate the address of the Extended Capabilities registers and store the other registers
.Out:
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_ValidCtrlTxt
		call gstdio_draw_text
		pop ebx
%endif

			mov esi, [xhci_base0]
			add esi, xHC_CAPS_HCCParams1
			mov eax, [esi]
			mov [xhci_hccparams1], eax
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_HCCParams1Txt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, eax
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			sub esi, xHC_CAPS_HCCParams1
			add esi, xHC_CAPS_HCCParams2
			mov eax, [esi]
			mov [xhci_hccparams2], eax
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_HCCParams2Txt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, eax
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			sub esi, xHC_CAPS_HCCParams2
			add esi, xHC_CAPS_HCSParams1
			mov eax, [esi]
			mov [xhci_hcsparams1], eax
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_HCSParams1Txt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, eax
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			sub esi, xHC_CAPS_HCSParams1
			add esi, xHC_CAPS_HCSParams2
			mov eax, [esi]
			mov [xhci_hcsparams2], eax
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_HCSParams2Txt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, eax
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			sub esi, xHC_CAPS_HCSParams2
			add esi, xHC_CAPS_RTSOFF
			mov eax, [esi]
			and eax, ~0x1F		; bits 4:0 are reserved
			mov [xhci_rts_offset], eax
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_RTSOffsTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, eax
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			sub esi, xHC_CAPS_RTSOFF
			add esi, xHC_CAPS_DBOFF
			mov eax, [esi]
			and eax, ~0x03		; bits 1:0 are reserved
			mov [xhci_db_offset], eax
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_DBOffsTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, eax
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			mov eax, [xhci_hccparams1]
			and eax, 0xFFFF0000
			shr	eax, 16
			shl	eax, 2							; *4 to get BYTES
			mov [xhci_ext_caps_off], eax	
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_ExtCapsOffsTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, eax
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
		call gutil_press_a_key
%endif

%ifdef	DBGXHCI_INIT
		push eax
		push ebx
		push edx
		mov ebx, xhci_ExtCapsTxt
		call gstdio_draw_text
		mov ebx, [xhci_base0]
		add ebx, [xhci_ext_caps_off]
.NxtCps	mov dh, [ebx]
		call gstdio_draw_hex8
		call gstdio_new_line
		mov eax, [ebx]
		shr	eax, 8
		and eax, 0xFF
		jz	.CpsEnd
		shl	eax, 2
		add ebx, eax
		jmp .NxtCps
.CpsEnd	pop edx
		pop ebx
		pop eax
		push esi
		push ecx
		mov esi, [xhci_base0]
		add esi, [xhci_ext_caps_off]
		mov ecx, 128
		call gutil_mem_dump
		pop ecx
		pop esi
		call gstdio_new_line
;		call gutil_press_a_key
%endif

			mov eax, [xhci_hccparams1]
			and eax, (1 << 2)
			jz	.Set32
			mov DWORD [xhci_context_size], 64
			jmp .TurnOff
.Set32		mov DWORD [xhci_context_size], 32
			; Turn off legacy support for Keyboard and Mice
.TurnOff:
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_ContextSizeTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, [xhci_context_size]
		call gstdio_draw_dec
		call gstdio_new_line
		pop eax
		call gutil_press_a_key
%endif
			call xhci_stop_legacy
			cmp eax, 1
			je	.GetPorts
			mov ebx, xhci_BIOSDidntRelLegacyTxt
			call gstdio_draw_text
			jmp	.Back
			; get num_ports from XHCI's HCSPARAMS1 register
.GetPorts	mov eax, [xhci_hcsparams1]
			and eax, 0xFF000000
			shr	eax, 24
			mov [xhci_ndp], eax			; it's really a 1byte value!	(should be smaller than XHCI_MAX_PORT_INFO_NUM !?)
			mov ebx, xhci_FndRootHubPortsTxt
			call gstdio_draw_text
			call gstdio_draw_dec
			call gstdio_new_line

			cmp DWORD [xhci_ndp], XHCI_MAX_PORT_INFO_NUM
			jc	.GetProt
			mov ebx, xhci_RootHubPortNumGreaterTxt
			call gstdio_draw_text
			jmp .Back

			; Get protocol of each port
			; Each physical port will have a USB3 and a USB2 PortSC register set.
			; Most likely a controller will only have one protocol item for each version.
			;  i.e.:  One for USB 3 and one for USB 2, they will not be fragmented.
			; However, it doesn't state anywhere that it can't be fragmented, so the below
			; code allows for fragmented protocol items
.GetProt	mov DWORD [xhci_ports_usb2], 0
			mov DWORD [xhci_ports_usb3], 0
			; find the USB 2.0 ports and mark the port_info byte as USB2 if found
			mov ebp, [xhci_ext_caps_off]

%ifdef	DBGXHCI_PORTINFO
		push eax
		push ebx
		push ecx
		push edx
		push esi
		xor eax, eax						; loop-cntr
		mov esi, [xhci_base0]
		add esi, ebp
		mov ecx, 256
.NCapsR	mov ebx, xhci_ExtCapsRegsTxt
		call gstdio_draw_text
		inc eax
		call gstdio_draw_dec
		dec eax
		call gstdio_new_line
		push eax
		mov ebx, eax
		mov eax, 256
		mul ebx
		add esi, eax	
		pop eax
		call gutil_mem_dump
		call gutil_press_a_key
		inc eax
		cmp eax, 3							; This many loop
		jc	.NCapsR
		pop esi
		pop edx
		pop ecx
		pop ebx
		pop eax
%endif

.Next2		cmp ebp, 0
			je	.USB3
			mov ebx, 2
	; IN:	EBP(list_off), EBX(version)
	; OUT:	EAX(offset), EBX(flags), ECX(count), EBP(next)
			call xhci_get_proto_offset
%ifdef	DBGXHCI_PORTINFO
		push ebx
		mov ebx, xhci_PortInfoUSB2CntTxt
		call gstdio_draw_text
		push eax
		mov eax, ecx
		call gstdio_draw_dec
		call gstdio_new_line
		pop eax
		mov ebx, xhci_PortInfoUSB2OffsTxt
		call gstdio_draw_text
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_PortInfoUSB2FlagsTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
		push ebx
		mov ebx, xhci_PortInfoUSB2NextTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebp
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			cmp ecx, 0
			jz	.Next2
			xor edi, edi
			mov esi, xhci_port_info
			shl	eax, 2					; *XHCI_PORT_INFO_SIZE
			add esi, eax				; ESI (port_info[offset])
.Port2		mov eax, [xhci_ports_usb2]
			mov [esi+XHCI_PORT_INFO_OFFSET_OFFS], al
			inc DWORD [xhci_ports_usb2]
			mov BYTE [esi+XHCI_PORT_INFO_FLAGS_OFFS], xHCI_PROTO_USB2
			test ebx, 2
			jz	.Inc2
			or	BYTE [esi+XHCI_PORT_INFO_FLAGS_OFFS], xHCI_PROTO_HSO
.Inc2		inc edi
			add esi, XHCI_PORT_INFO_SIZE
			cmp edi, ecx
			jc	.Port2	
			jmp .Next2
			; find the USB 3.0 ports and mark the port_info byte as USB3 if found
.USB3:

%ifdef	DBGXHCI_PORTINFO
		push ebx
		mov ebx, xhci_PortInfoUSB2Txt
		call gstdio_draw_text
		mov ebx, xhci_PortsUSB2Txt
		call gstdio_draw_text
		push eax
		mov eax, [xhci_ports_usb2]
		call gstdio_draw_dec
		pop eax
		pop ebx
		call gstdio_new_line
		push esi
		push ecx
;		call gstdio_new_line
		mov esi, xhci_port_info
		mov ecx, [xhci_ndp]
		shl	ecx, 2
		call gutil_mem_dump
		pop ecx
		pop esi
		call gutil_press_a_key
%endif

			mov ebp, [xhci_ext_caps_off]
.Next3		cmp ebp, 0
			je	.PairUp
			mov ebx, 3
	; IN:	EBP(list_off), EBX(version)
	; OUT:	EAX(offset), EBX(flags), ECX(count), EBP(next)
			call xhci_get_proto_offset
%ifdef	DBGXHCI_PORTINFO
		push ebx
		mov ebx, xhci_PortInfoUSB3CntTxt
		call gstdio_draw_text
		push eax
		mov eax, ecx
		call gstdio_draw_dec
		call gstdio_new_line
		pop eax
		mov ebx, xhci_PortInfoUSB3OffsTxt
		call gstdio_draw_text
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_PortInfoUSB3NextTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebp
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			cmp ecx, 0
			jz	.Next3
			xor edi, edi
			mov esi, xhci_port_info
			shl	eax, 2					; *XHCI_PORT_INFO_SIZE
			add esi, eax
.Port3		mov eax, [xhci_ports_usb3]
			mov [esi+XHCI_PORT_INFO_OFFSET_OFFS], al
			inc DWORD [xhci_ports_usb3]
			mov BYTE [esi+XHCI_PORT_INFO_FLAGS_OFFS], xHCI_PROTO_USB3
			inc edi
			add esi, XHCI_PORT_INFO_SIZE
			cmp edi, ecx
			jc	.Port3	
			jmp .Next3
 			; pair up each USB3 port with it's companion USB2 port
.PairUp:
%ifdef	DBGXHCI_PORTINFO
		push esi
		push ecx
		push ebx
		mov ebx, xhci_PortInfoUSB3Txt
		call gstdio_draw_text
		mov ebx, xhci_PortsUSB3Txt
		call gstdio_draw_text
		push eax
		mov eax, [xhci_ports_usb3]
		call gstdio_draw_dec
		pop eax
		pop ebx
		call gstdio_new_line
		mov esi, xhci_port_info
		mov ecx, [xhci_ndp]
		shl	ecx, 2
		call gutil_mem_dump
		pop ecx
		pop esi
		call gutil_press_a_key
%endif

			xor ebx, ebx
.NextI		mov esi, xhci_port_info
			shl	ebx, 2					; *XHCI_PORT_INFO_SIZE
			add esi, ebx
			shr	ebx, 2
				;inner loop
			xor ecx, ecx
.NextK		mov edi, xhci_port_info
			shl	ecx, 2					; *XHCI_PORT_INFO_SIZE
			add edi, ecx
			shr	ecx, 2
			mov al, [esi+XHCI_PORT_INFO_OFFSET_OFFS]
			cmp [edi+XHCI_PORT_INFO_OFFSET_OFFS], al
			jne	.IncK
			mov al, [esi+XHCI_PORT_INFO_FLAGS_OFFS]
			and al, xHCI_PROTO_INFO
			push ebx
			mov bl, [edi+XHCI_PORT_INFO_FLAGS_OFFS]
			and bl, xHCI_PROTO_INFO
			cmp al, bl
			pop ebx
			je	.IncK	; !?
			mov [esi+XHCI_PORT_INFO_OTHER_PORT_NUM_OFFS], cl
			or	BYTE [esi+XHCI_PORT_INFO_FLAGS_OFFS], xHCI_PROTO_HAS_PAIR
			mov [edi+XHCI_PORT_INFO_OTHER_PORT_NUM_OFFS], bl
			or	BYTE [edi+XHCI_PORT_INFO_FLAGS_OFFS], xHCI_PROTO_HAS_PAIR
.IncK		inc ecx
			cmp ecx, [xhci_ndp]
			jc	.NextK	
				; end of inner loop
			inc ebx
			cmp ebx, [xhci_ndp]
			jc	.NextI	
%ifdef	DBGXHCI_PORTINFO
		push esi
		push ecx
		push ebx
		mov ebx, xhci_PortInfoPairedTxt
		call gstdio_draw_text
		pop ebx
		mov esi, xhci_port_info
		mov ecx, [xhci_ndp]
		shl	ecx, 2
		call gutil_mem_dump
		pop ecx
		pop esi
		call gutil_press_a_key
%endif
			; mark all USB3 ports and any USB2 only ports as active, deactivating any USB2 ports that have a USB3 companion
			xor ecx, ecx
			mov esi, xhci_port_info
.NextMark	xHCI_IS_USB3_PORT(ecx)
			cmp al, 1
			je	.SetActive
			xHCI_IS_USB2_PORT(ecx)
			cmp al, 1
			jne	.NextP
			xHCI_HAS_PAIR(ecx)
			cmp al, 1
			je	.NextP
.SetActive	or	BYTE [esi+XHCI_PORT_INFO_FLAGS_OFFS], xHCI_PROTO_ACTIVE
.NextP		inc ecx
			add esi, XHCI_PORT_INFO_SIZE
			cmp ecx, [xhci_ndp]
			jc	.NextMark
%ifdef	DBGXHCI_PORTINFO
		push esi
		push ecx
		push ebx
		mov ebx, xhci_PortInfoActDeactTxt
		call gstdio_draw_text
		pop ebx
		mov esi, xhci_port_info
		mov ecx, [xhci_ndp]
		shl	ecx, 2
		call gutil_mem_dump
		call gutil_press_a_key
		pop ecx
		pop esi
		call gutil_press_a_key
%endif
			; Now that we have the protocol for each port, let's set up the controller
			;  we need a command ring and a single endpoint ring with it's event ring.
			;  we also need a slot context area, which includes the pointer array
			; get the page size of the controller
			mov esi, [xhci_base0]
			add esi, [xhci_op_base_off]
			mov eax, [esi+xHC_OPS_USBPageSize]
			and eax, 0xFFFF
			shl	eax, 12
			mov [xhci_page_size], eax
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_PageSizeTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, eax
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif

			mov ecx, [xhci_hcsparams1]
			and ecx, 0xFF					; ecx is max_slots
			mov [xhci_max_slots], cl
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_MaxSlotsTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ecx
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			; "allocate" the dcbaa and the slot contexts
			; set the scratch_buffer pointer to zero
			;  and clear out the rest of the buffer
			mov eax, 2048
			mov ebx, 64
			mov edx, [xhci_page_size]
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
			mov [xhci_dcbaap_start], ebx
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_DCBAAPStartTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
		call gutil_press_a_key
%endif
			; write the address to the controller
			mov esi, [xhci_base0]
			add esi, [xhci_op_base_off]
			mov [esi+xHC_OPS_USBDcbaap], ebx
			test DWORD [xhci_hccparams1], 1
			jz	.Scratch
			mov DWORD [esi+xHC_OPS_USBDcbaap+4], 0		; upper 32-bits of a 64-bit value
.Scratch	mov ecx, [xhci_hcsparams2]
			and ecx, 0xF8000000
			shr	ecx, 27
			mov [xhci_max_scratch_buffs], ecx
			cmp ecx, 0
			jz	.CreatCR
			mov eax, [xhci_max_scratch_buffs]
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_MaxScratchpadBuffsTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_dec
		call gstdio_new_line
%endif
			shl	eax, 3
			mov ebx, 64
			mov edx, [xhci_page_size]
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
			mov [xhci_scratch_buff_array_start], ebx
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_ScratchpadBuffArrayStartTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			push edx
			mov eax, [xhci_max_scratch_buffs]
			mov ebx, [xhci_page_size]
			mul ebx
			pop edx
			mov eax, ebx
			mov ebx, [xhci_page_size]
			mov edx, 0   ;  [xhci_page_size]   !!!!!
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
			mov [xhci_scratch_buff_start], ebx
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_ScratchpadBuffStartTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			mov ebx, [xhci_scratch_buff_array_start]
			mov ecx, [xhci_dcbaap_start]
			mov [ecx], ebx
			test DWORD [xhci_hccparams1], 1
			jz	.WriteScr
			mov DWORD [ecx+4], 0
.WriteScr	xor ecx, ecx
.NextSrtch	mov ebp, [xhci_scratch_buff_array_start]
			shl	ecx, 3
			add ebp, ecx
			shr ecx, 3
			push edx
			mov eax, ecx
			mov ebx, [xhci_page_size]
			mul ebx
			pop edx
			add eax, [xhci_scratch_buff_start]
			mov [ebp], eax
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_ScratchpadBuffStartIdxTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, eax
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			test DWORD [xhci_hccparams1], 1
			jz	.IncBuffN
			mov DWORD [ebp+4], 0
.IncBuffN	inc ecx
			cmp ecx, [xhci_max_scratch_buffs]
			jc	.NextSrtch
%ifdef	DBGXHCI_INIT
		call gutil_press_a_key
%endif
			; create the command ring, returning the physical address of the ring
	; IN:	EAX(number of TRBs)
	; OUT:	EBX(memaddr)
.CreatCR	mov eax, XHCI_CMND_RING_TRBS
			call xhci_create_ring
			mov [xhci_cmnd_ring_addr], ebx
			mov [xhci_cmnd_trb_addr], ebx

%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_CmdRingTRBAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			mov DWORD [xhci_cmnd_trb_cycle], XHCI_TRB_CYCLE_ON	; we start with a Cycle bit of 1 for our command ring
			; Command Ring Control Register
			mov esi, [xhci_base0]
			add esi, [xhci_op_base_off]
			or	ebx, XHCI_TRB_CYCLE_ON
			mov [esi+xHC_OPS_USBCrcr], ebx
			test DWORD [xhci_hccparams1], 1
			jz	.Conf
			mov DWORD [esi+xHC_OPS_USBCrcr+4], 0		; upper 32-bits of a 64-bit value
			; Configure Register
.Conf		xor ecx, ecx
			mov cl, [xhci_max_slots]
			mov [esi+xHC_OPS_USBConfig], ecx
			; Device Notification Control (only bit 1 is allowed)
			mov DWORD [esi+xHC_OPS_USBDnctrl], (1 << 1)
			; Initialize the interrupters
			mov ecx, [xhci_hcsparams2]
			and ecx, 0x000000F0
			shr	ecx, 4
			mov DWORD [xhci_max_event_segs], 1		; not used !?
			shl DWORD [xhci_max_event_segs], cl
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_MaxEventSegsTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, [xhci_max_event_segs]
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			mov ecx, [xhci_hcsparams1]
			and ecx, 0x0007FF00
			shr	ecx, 8
			mov DWORD [xhci_max_interrupters], ecx	; not used !?
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_MaxInterruptersTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, [xhci_max_interrupters]
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			mov eax, XHCI_TRBS_PER_EVENT_RING
	; IN:	EAX(trbs)
	; OUT:	EBX(addr), EDX(table_addr) 
			call xhci_create_event_ring
			mov [xhci_cur_event_ring_addr], ebx
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_CurEventRingAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
		push ebx
		mov ebx, xhci_EventRingAddrTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_hex
		call gstdio_new_line
%endif
			mov DWORD [xhci_cur_event_ring_cycle], 1
			; write the registers
			mov esi, [xhci_base0]
			add esi, [xhci_rts_offset]
			add esi, 0x20
			mov eax, [esi+xHC_INTERRUPTER_IMAN]
			and eax, 0xFFFFFFFC
%ifdef USB_XHCI_IRQ_DEF
			or	eax, (1 << 1) | (1 << 0)	; enable bit & clear pending bit
%else
			or	eax, (1 << 0)				; clear pending bit
%endif
			mov DWORD [esi+xHC_INTERRUPTER_IMAN], eax
			mov DWORD [esi+xHC_INTERRUPTER_IMOD], 0						; disable throttling
			mov eax, [esi+xHC_INTERRUPTER_TAB_SIZE]
			and eax, 0xFFFF0000
			or	eax, 1													; count of segments (table_size)
			mov [esi+xHC_INTERRUPTER_TAB_SIZE], eax
			mov eax, ebx
			or	eax, (1 << 3)
			mov DWORD [esi+xHC_INTERRUPTER_DEQUEUE], eax
			test DWORD [xhci_hccparams1], 1
			jz	.EventRA
			mov DWORD [esi+xHC_INTERRUPTER_DEQUEUE+4], 0
.EventRA	mov eax, [esi+xHC_INTERRUPTER_ADDRESS]
			and eax, 0x1F
			or	eax, edx
			mov [esi+xHC_INTERRUPTER_ADDRESS], eax	
			test DWORD [xhci_hccparams1], 1
			jz	.ClearStat
			mov DWORD [esi+xHC_INTERRUPTER_ADDRESS+4], 0
			; clear the status register bits
.ClearStat	mov esi, [xhci_base0]
			add esi, [xhci_op_base_off]
			mov DWORD [esi+xHC_OPS_USBStatus], (1<<10) | (1<<4) | (1<<3) | (1<<2)
%ifdef	DBGXHCI_INIT
		push ebx
		mov ebx, xhci_StartIntTxt
		call gstdio_draw_text
		pop ebx
%endif

			; clear array of EP's Transfer-ring ptr and cycle
			call xhci_clear_cur_ep_ring_ptr_arr

			; set and start the Host Controller's schedule
%ifdef USB_XHCI_IRQ_DEF
			mov DWORD [esi+xHC_OPS_USBCommand], (1<<3) | (1<<2) | (1<<0)
%else
			mov DWORD [esi+xHC_OPS_USBCommand], (1<<2) | (1<<0)
%endif
			mov ebx, 100
			call pit_delay
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_LoopUSB3Txt
		call gstdio_draw_text
		pop ebx
%endif
			; loop through the ports, starting with the USB3 ports
			xor ecx, ecx
.NextUSB3P	xHCI_IS_USB3_PORT(ecx)
			cmp al, 1
			jnz	.IncUSB3P
			xHCI_IS_ACTIVE(ecx)
			cmp al, 1
			jnz	.IncUSB3P
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_ResettingPortsTxt
		call gstdio_draw_text
		call gutil_press_a_key
		pop ebx
%endif
			; power and reset the port
		; IN:	ECX(port)
		; OUT:	xhci_res(result, 1 if success)
			call xhci_reset_port
			; if the reset was good, get the descriptor
			; if the reset was bad, the reset routine will mark this port as inactive,
			;  and mark the USB2 port as active.
			cmp DWORD [xhci_res], 1
			jnz	.IncUSB3P
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_GetDescUSB3Txt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ecx
		call gstdio_draw_dec
		call gstdio_new_line
		pop eax
%endif
			call xhci_get_descriptor
			cmp DWORD [xhci_res], 1
			jne	.Back
.IncUSB3P	inc ecx
%ifdef	DBGXHCI_CONTROL
		call gutil_press_a_key
%endif
			cmp ecx, [xhci_ndp]
			jc	.NextUSB3P	

			; now the USB2 ports
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx,xhci_LoopUSB2Txt
		call gstdio_draw_text
		pop ebx
%endif

			xor ecx, ecx
.NextUSB2P	xHCI_IS_USB2_PORT(ecx)
			cmp al, 1
			jnz	.IncUSB2P
			xHCI_IS_ACTIVE(ecx)
			cmp al, 1
			jnz	.IncUSB2P
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_ResettingPortsTxt
		call gstdio_draw_text
		call gutil_press_a_key
		pop ebx
%endif
			; power and reset the port
		; IN:	ECX(port)
		; OUT:	xhci_res(result, 1 if success)
			call xhci_reset_port
			; if the reset was good, get the descriptor
			cmp DWORD [xhci_res], 1
			jnz	.IncUSB2P
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_GetDescUSB2Txt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ecx
		call gstdio_draw_dec
		call gstdio_new_line
		pop eax
%endif
			call xhci_get_descriptor
			cmp DWORD [xhci_res], 1
			jne	.Back
.IncUSB2P	inc ecx
%ifdef	DBGXHCI_CONTROL
		call gutil_press_a_key
%endif
			cmp ecx, [xhci_ndp]
			jc	.NextUSB2P
.Back		popad
			ret


; Release BIOS ownership of controller
; On Entry:
;   list: xhci_ext_caps_off, pointer to the start of the Capability list
; On Return:
;   EAX is 1 if ownership released
;
; Set bit 24 to indicate to the BIOS to release ownership
; The BIOS should clear bit 16 indicating that it has successfully done so
; Ownership is released when bit 24 is set *and* bit 16 is clear.
; This will wait xHC_xECP_LEGACY_TIMEOUT ms for the BIOS to release ownership.
;   (It is unknown the exact time limit that the BIOS has to release ownership.)
; IN:	xhci_ext_caps_off
; OUT:	EAX(1 on success)
xhci_stop_legacy:
			push esi
			push ebx
			push ecx

		mov esi, [xhci_base0]
		add esi, [xhci_ext_caps_off]
.NxtCps	cmp BYTE [esi], xHC_xECP_ID_LEGACY 
		je	.Set
		mov eax, [esi]
		shr	eax, 8
		and eax, 0xFF
		jz	.DBG
		shl	eax, 2
		add esi, eax
		jmp .NxtCps

			; set bit 24 asking the BIOS to release ownership
.Set		or	DWORD [esi], xHC_xECP_LEGACY_OS_OWNED
			; Timeout if bit 24 is not set and bit 16 is not clear after xHC_xECP_LEGACY_TIMEOUT milliseconds
			mov ecx, xHC_xECP_LEGACY_TIMEOUT
.IsFinish	mov eax, [esi]
			and eax, xHC_xECP_LEGACY_OWNED_MASK
			cmp eax, xHC_xECP_LEGACY_OS_OWNED
			jz	.Ok
			mov ebx, 1
			call pit_delay
			loop .IsFinish
			xor eax, eax
			jmp	.Back
.DBG:
%ifdef	DBGXHCI_INIT
		mov ebx, xhci_NoLegacyTxt
		call gstdio_draw_text
%endif
.Ok			mov eax, 1
.Back		pop ecx
			pop ebx
			pop esi
			ret

; New code from TheUSBImage3, causes freeze at StartInterrupter!?
;xhci_stop_legacy2:
;			push esi
;			push ebx
;			push ecx
;			push edx
;			push ebp
;			mov ebp, [xhci_ext_caps_off]	; EBP(list_off)
;		; calculate next item position
;.NItem		mov esi, [xhci_base0]
;			add esi, ebp
;			inc esi							; (BYTE [ESI])(item_next)
;			xor edx, edx
;			xor eax, eax
;			mov al, [esi]
;			cmp al, 0 
;			je	.ChkEntry
;			shl	eax, 2
;			add eax, ebp
;			mov edx, eax					; EDX(next)
;		; is this the legacy entry?
;.ChkEntry	cmp BYTE [esi], xHC_xECP_ID_LEGACY 
;			jne	.NextItem
;			or	DWORD [esi], xHC_xECP_LEGACY_OS_OWNED
;			; Timeout if bit 24 is not set and bit 16 is not clear after xHC_xECP_LEGACY_TIMEOUT milliseconds
;			mov ecx, xHC_xECP_LEGACY_TIMEOUT
;.ChkTO		mov eax, [esi]
;			and eax, xHC_xECP_LEGACY_OWNED_MASK
;			cmp eax, xHC_xECP_LEGACY_OS_OWNED
;			jz	.Ok
;			mov ebx, 1
;			call pit_delay
;			loop .ChkTO
;			xor eax, eax	
;			jmp	.Back
;;			jmp .Ok
;   	; point to next item
;.NextItem	mov ebp, edx
;			cmp ebp, 0
;			jne	.NItem
;		; if we get here, either there was not a legacy entry,
;		;  or the BIOS didn't give it up.
;		; We return TRUE anyway, just to see if we can keep going.
;%ifdef	DBGXHCI_INIT
;		mov ebx, xhci_NoLegacyTxt
;		call gstdio_draw_text
;%endif
;.Ok			mov eax, 1
;.Back		pop ebp
;			pop edx
;			pop ecx
;			pop ebx
;			pop esi
;			ret


; Returns offset and count of port register sets for a given version, including flags register
; On Entry:
;   list_off: offset to the start or current position of the Capability list
;    version: 2 or 3.  Version of register set to find.
; On Return:
;  writes count of register sets found in *count.
;  if *count > 0, *offset is written with zero based offset
;  writes value of item->Protocol_defined in *flags
;  returns offset of next item in list or 0 if no more
; The following code assumes:
; - Little-Endian storage
; - there is a properly formatted list at this pointer
; IN:	EBP(list_off), EBX(version)
; OUT:	EAX(offset), EBX(flags), ECX(count), EBP(next)
xhci_get_proto_offset:
			push edx
			push esi
			; calculate next item position
.Next		mov esi, [xhci_base0]
			add esi, ebp	
			xor edx, edx		; EDX(next)
			cmp BYTE [esi+1], 0	; (BYTE [ESI+1])(item_next)
			je	.ChkProt
			mov dl, [esi+1]
			shl	edx, 2
			add	edx, ebp		; EDX(next)
			; is this a protocol item and if so, is it the version we are looking for?
.ChkProt	cmp BYTE [esi], xHC_xECP_ID_PROTO
			jne	.NextIt
			cmp [esi+3], bl		; bl is version (2 or 3)
			jne	.NextIt
			xor eax, eax
			mov al, [esi+8]		; EAX(offset)
			dec eax				; make it zero based
			xor ecx, ecx
			mov cl, [esi+9]		; ECX(count)
			xor ebx, ebx
			mov bx, [esi+10]	; EBX(flags)
			and bx, 0x0FFF
			mov ebp, edx		; EBP(next)
			jmp .Back
.NextIt		mov ebp, edx
			cmp ebp, 0
			jne	.Next
			xor ecx, ecx
.Back		pop esi
			pop edx
			ret


; allocates some memory in our heap on the alignment specified, rounding up to the nearest dword
; doesn't allow the memory to cross the given boundary (unless boundary == 0)
; Checks for errors, but does not return an error.  Simply "exits" if error found
; will clear the memory to zero
; returns physical address of memory found
; alignment and boundary must be a power of 2
; size must be <= boundary
; IN: EAX(size), EBX(alignment), EDX(boundary)
; OUT: EBX (memaddr 32bit)
xhci_heap_alloc:
			pushad
			; align to the next alignment
			mov ecx, [xhci_cur_heap_ptr]
			dec ebx				;; simplification
			add ecx, ebx
			not ebx
			and ecx, ebx
			mov [xhci_cur_heap_ptr], ecx
			; round up to the next dword size
			add eax, 3
			and eax, ~3
			; check to see if this will cross a boundary (unless boundary == 0)
			cmp edx, 0
			jna	.ChkOOB		;; fix
			mov ebx, edx		; ebx will be next_boundary
			dec ebx
			mov ecx, ebx	;;simplification
			add ebx, [xhci_cur_heap_ptr]
			not ecx
			and ebx, ecx		; ebx is next_boundary
			mov ecx, [xhci_cur_heap_ptr]
			add ecx, eax
			cmp ecx, edx
			jna	.ChkOOB
			mov [xhci_cur_heap_ptr], ebx
			; check to see if we are out of bounds
.ChkOOB		mov ebx, [xhci_cur_heap_ptr]
			add ebx, eax
			dec ebx
			cmp ebx, XHCI_HEAP_LIMIT
			jnc	.Err		; >=
			cmp edx, 0	
			je	.Clear
			cmp eax, edx
			jna	.Clear
.Err		mov ebx, xhci_ErrHeapLimitReachedTxt	;;fixed
			call gstdio_draw_text
			jmp $					; HALT
			; clear it to zeros
.Clear		mov edi, [xhci_cur_heap_ptr]
			mov ecx, eax
			push eax
			xor eax, eax
			rep stosb
			pop eax
			; update our pointer for next time
			mov ebx, [xhci_cur_heap_ptr]
			add [xhci_cur_heap_ptr], eax
			mov [xhci_res_tmp], ebx
			popad
			mov ebx, [xhci_res_tmp]
			ret


; IN:	EAX(number of TRBs)
; OUT:	EBX(memaddr)
xhci_create_ring:
			pushad
			xor edx, edx
			mov ebx, MAX_TRB_CNT_PER_TR_RING
			div ebx
	; EAX(quotient), EDX(remainder)
%ifdef DBGXHCI_TR_RING_INIT
		push ebx
		mov ebx, xhci_CreateTRRingTxt
		call gstdio_draw_text
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_CreateTRRingQRTxt
		call gstdio_draw_text
		call gstdio_draw_dec
		mov ebx, 32
		call gstdio_draw_char
		pop ebx
		push eax
		mov eax, edx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		call gutil_press_a_key
%endif

			mov esi, eax
			cmp edx, 0
			jz	.ChkMax
			inc esi
.ChkMax		cmp esi, MAX_SEGMENT_CNT_PER_TR_RING
			jna	.Save
			mov eax, MAX_SEGMENT_CNT_PER_TR_RING
			cmp	edx, 0
			jz	.Save
			dec eax
.Save		mov esi, eax				; ESI(quotient)
			mov ebp, edx				; EBP(remainder)
%ifdef DBGXHCI_TR_RING_INIT
		push ebx
		mov ebx, xhci_CreateTRRingQRAdjustedTxt
		call gstdio_draw_text
		call gstdio_draw_dec
		mov ebx, 32
		call gstdio_draw_char
		pop ebx
		push eax
		mov eax, edx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		call gutil_press_a_key
%endif
			cmp esi, 0
			jz	.DoRem
			xor ecx, ecx
			mov eax, MAX_TRB_CNT_PER_TR_RING 
			shl eax, 4								; *XHCI_TRB_SIZE
			mov edx, 65536
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
.Next		mov ebx, 64
			call xhci_heap_alloc
%ifdef DBGXHCI_TR_RING_INIT
		push ebx
		mov ebx, xhci_CreateTRRingSegAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		call gutil_press_a_key
%endif
			mov edi, ecx
			shl	edi, 2
			push edi
			add edi, xhci_tr_ring_segments
			mov [edi], ebx
			pop edi
			add edi, xhci_tr_ring_segment_cnts
			mov DWORD [edi], MAX_TRB_CNT_PER_TR_RING
			inc ecx
			cmp ecx, esi
			jc	.Next
		; remainder
.DoRem		cmp ebp, 0
			jz	.CalcCnt
			mov eax, ebp
			shl eax, 4								; *XHCI_TRB_SIZE
			mov ebx, 64
			mov edx, 65536
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
%ifdef DBGXHCI_TR_RING_INIT
		push ebx
		mov ebx, xhci_CreateTRRingSegAddrRemTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		call gutil_press_a_key
%endif
			mov edi, esi
			shl	edi, 2
			push edi
			add edi, xhci_tr_ring_segments
			mov [edi], ebx
			pop edi
			add edi, xhci_tr_ring_segment_cnts
			mov [edi], ebp

			; segmentCnt
.CalcCnt	cmp ebp, 0
			jz	.SetLNK
			inc esi									; ESI(segmentCnt)

		; set LINK TRBs
.SetLNK:
%ifdef DBGXHCI_TR_RING_INIT
		push ebx
		mov ebx, xhci_TRRingSegsTxt
		call gstdio_draw_text
		push ecx
		push edx
		xor ecx, ecx
.DgNSeg push ecx
		shl ecx, 2
		add ecx, xhci_tr_ring_segments 
		mov edx, [ecx]
		call gstdio_draw_hex
		pop ecx
		mov ebx, 32
		call gstdio_draw_char
		inc ecx
		cmp ecx, esi
		jc	.DgNSeg
		pop edx
		mov ebx, xhci_TRRingCntsTxt
		call gstdio_draw_text
		push eax
		xor ecx, ecx
.DgNCnt push ecx
		shl ecx, 2
		add ecx, xhci_tr_ring_segment_cnts
		mov eax, [ecx]
		call gstdio_draw_dec
		pop ecx
		mov ebx, 32
		call gstdio_draw_char
		inc ecx
		cmp ecx, esi
		jc	.DgNCnt
		call gstdio_new_line
		pop eax
		pop ecx
		pop ebx
		call gutil_press_a_key
%endif
			cmp esi, 0
			jz	.Back
			cmp esi, 1
			jz	.LastLNK

			dec esi

%ifdef DBGXHCI_TR_RING_INIT
		push ebx
		mov ebx, xhci_TRRingBefNextLNKTxt
		call gstdio_draw_text
		pop ebx
%endif
			xor ecx, ecx
.NextLNK	mov edi, ecx
			shl edi, 2
			push edi
			add edi, xhci_tr_ring_segments
			mov ebx, [edi]							; EBX(ptr to segmentArr[idx])
			pop edi
			add edi, xhci_tr_ring_segment_cnts
			mov eax, [edi]							; EAX(#TRBs in the given segment)
			; make the last one a link TRB to point to the first one of the first segment
			dec eax									; to the last TRB
			shl eax, 4								; *XHCI_TRB_SIZE
			add ebx, eax							; EBX(ptr to last TRB in the given segment)
			; get ptr to start of next segment
			mov edi, ecx
			inc edi
			shl edi, 2
			add edi, xhci_tr_ring_segments
			mov	eax, [edi]							; EAX(ptr to the start of the next segment)
			mov [ebx], eax
			test DWORD [xhci_hccparams1], 1
			jz	.Status
			mov DWORD [ebx+4], 0
.Status		mov DWORD [ebx+8], ((0 << 22) | 0)	
			mov DWORD [ebx+12], XHCI_TRB_LINK_CMND 
			inc ecx
			cmp ecx, esi
			jc	.NextLNK

			inc esi

.LastLNK:
%ifdef DBGXHCI_TR_RING_INIT
		push ebx
		mov ebx, xhci_TRRingBefLastLNKTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			dec esi
			shl esi, 2
			push esi
			add esi, xhci_tr_ring_segments
			mov ebx, [esi]							; EBX(ptr to segmentArr[idx])
			pop esi
			add esi, xhci_tr_ring_segment_cnts
			mov eax, [esi]							; EAX(#TRBs in the given segment)
			; make the last one a link TRB to point to the first one of the first segment
			dec eax									; to the last TRB
			shl eax, 4								; *XHCI_TRB_SIZE
			add ebx, eax							; EBX(ptr to last TRB in the given segment)
			; get ptr to start of first segment
			mov edi, [xhci_tr_ring_segments]		; [xhci_tr_ring_segments](ptr to the start of the first segment)
			mov [ebx], edi
%ifdef DBGXHCI_TR_RING_INIT
		push ebx
		mov ebx, xhci_TRRingDestValueTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		push ebx
		mov ebx, 32
		call gstdio_draw_char
		pop ebx
		mov edx, edi
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		call gutil_press_a_key
%endif
			test DWORD [xhci_hccparams1], 1
			jz	.StatusL
			mov DWORD [ebx+4], 0
.StatusL	mov DWORD [ebx+8], ((0 << 22) | 0)	
			mov DWORD [ebx+12], XHCI_TRB_LINK_CMND | XHCI_TRB_TOGGLE_CYCLE_ON	; we set the ToggleCycleBit for the last LINK-TRB
.Back		popad
			mov ebx, [xhci_tr_ring_segments]
			ret


; IN:	EAX(trbs)
; OUT:	EBX(addr), EDX(table_addr)
xhci_create_event_ring:
			push eax
			push ecx
	; Please note that 'trbs' should be <= 4096 or you will need to make multiple segments
	; I only use one here.
			mov ecx, eax
			mov	eax, 64
			mov ebx, 64
			mov edx, 0
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc					; table_addr
			push ebx
			mov eax, ecx
			shl eax, 4								; *XHCI_TRB_SIZE
			mov ebx, 64
			mov edx, 65536
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc					; addr
			pop edx
			mov [edx], ebx
			test DWORD [xhci_hccparams1], 1
			jz	.Count
			mov DWORD [edx+4], 0
.Count		mov [edx+8], ecx						; count of TRB's
			mov DWORD [edx+12], 0
			pop ecx
			pop eax
			ret


; IN:	ECX(port)
; OUT:	xhci_res(result, 1 if success)
xhci_reset_port:
			pushad
			mov edx, ecx
			mov DWORD [xhci_res], 0
			mov esi, [xhci_base0]
			add esi, [xhci_op_base_off]
			shl	edx, 4
			add esi, edx
			add esi, xHC_OPS_USBPortSt

%ifdef	DBGXHCI_RESETPORT
		push ebx
		mov ebx, xhci_ResettingPortTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ecx
		call gstdio_draw_dec
		call gstdio_new_line
		pop eax
		push ebx
		mov ebx, xhci_PortSCTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, [esi+xHC_Port_PORTSC]
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			; power the port?
			; LUNT: Whether the PPC bit is set or clear, you still have to set bit 9 in the PortSC register
			;test DWORD [xhci_hccparams], (1 <<3)
			;jz	.Stat
%ifdef	DBGXHCI_RESETPORT
		push ebx
		mov ebx, xhci_PoweringUpPortTxt
		call gstdio_draw_text
		pop ebx
%endif
			test DWORD [esi+xHC_Port_PORTSC], (1 << 9)
			jnz	.Stat
			mov DWORD [esi+xHC_Port_PORTSC], (1 << 9)
			mov ebx, 20
			call pit_delay
			test DWORD [esi+xHC_Port_PORTSC], (1 << 9)
			jz	.Back			; return bad reset.
			; we need to make sure that the status change bits are clear
.Stat		mov DWORD [esi+xHC_Port_PORTSC], (1 << 9) | xHC_PortUSB_CHANGE_BITS
%ifdef	DBGXHCI_RESETPORT
		push ebx
		mov ebx, xhci_PortSC2Txt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, [esi+xHC_Port_PORTSC]
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			; set bit 4 (USB2) or 31 (USB3) to reset the port
			xHCI_IS_USB3_PORT(ecx)
			cmp al, 1
			jnz	.USB2
			mov DWORD [esi+xHC_Port_PORTSC], (1 << 9) | (1 << 31)
%ifdef	DBGXHCI_RESETPORT
		push ebx
		mov ebx, xhci_ResettingUSB3PortTxt
		call gstdio_draw_text
		pop ebx
%endif
			jmp .Wait21
.USB2		mov DWORD [esi+xHC_Port_PORTSC], (1 << 9) | (1 << 4)
%ifdef	DBGXHCI_RESETPORT
		push ebx
		mov ebx, xhci_ResettingUSB2PortTxt
		call gstdio_draw_text
		pop ebx
%endif
			; wait for bit 21 to set
.Wait21		mov edx, ecx
			mov ecx, 500
.IsFinish	test DWORD [esi+xHC_Port_PORTSC], (1 << 21)	; LUNT try bit 19 for USB3 !?
			jnz	.NoTO
			mov ebx, 1
			call pit_delay
			loop .IsFinish
;			mov ebx, xhci_resetPortTOTxt
;			call gstdio_draw_text
			jmp .DoUSB2
	; if we didn't time out
.NoTO		mov ebx, USB_TRHRSI		; reset recovery time
			call pit_delay
			; if after the reset, the enable bit is non zero, there was a successful reset/enable
			test DWORD [esi+xHC_Port_PORTSC], (1 << 1)
			jz	.DoUSB2
%ifdef	DBGXHCI_RESETPORT
		push ebx
		mov ebx, xhci_PortSC3Txt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, [esi+xHC_Port_PORTSC]
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
				; clear the status change bit(s)
			mov DWORD [esi+xHC_Port_PORTSC], (1 << 9) | (xHC_PortUSB_CHANGE_BITS)	; OSDEV(prajwal): don't kill PRC after reset (bit 21)
%ifdef	DBGXHCI_RESETPORT
		push ebx
		mov ebx, xhci_PortSC4Txt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, [esi+xHC_Port_PORTSC]
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
%endif
			mov DWORD [xhci_res], 1
	; if we have a successful USB2 reset, we need to make sure this port is marked active,
	;  and if it has a paired port, it is marked inactive
.DoUSB2		cmp DWORD [xhci_res], 1
			jnz	.Deact
			xHCI_IS_USB2_PORT(edx)
			cmp al, 1
			jnz	.Deact

%ifdef	DBGXHCI_PORTINFO
		push ebx
		mov ebx, xhci_PortResPortInfoUSB2ActTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, xhci_port_info
		mov ecx, [xhci_ndp]
		shl	ecx, 2
		call gutil_mem_dump
		pop ecx
		pop esi
		call gutil_press_a_key
%endif

			mov esi, xhci_port_info
			push edx
			shl	edx, 2					; *XHCI_PORT_INFO_SIZE
			add esi, edx
			pop edx
			or	BYTE [esi+XHCI_PORT_INFO_FLAGS_OFFS], xHCI_PROTO_ACTIVE
			mov	al, [esi+XHCI_PORT_INFO_FLAGS_OFFS]
			and	al, xHCI_PROTO_HAS_PAIR
			cmp al, 0
			jz	.Deact
			xor eax, eax
			mov al, [esi+XHCI_PORT_INFO_OTHER_PORT_NUM_OFFS]
			shl	eax, 2					; *XHCI_PORT_INFO_SIZE
			mov esi, xhci_port_info
			add esi, eax		
			and	BYTE [esi+XHCI_PORT_INFO_FLAGS_OFFS], ~xHCI_PROTO_ACTIVE

			; if error resetting USB3 protocol, deactivate this port and activate the paired USB2 port.
			;  it will be paired since all USB3 ports must be USB2 compatible.
.Deact:
%ifdef	DBGXHCI_PORTINFO
		push ebx
		mov ebx, xhci_PortResPortInfoUSB3DeactTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, xhci_port_info
		mov ecx, [xhci_ndp]
		shl	ecx, 2
		call gutil_mem_dump
		pop ecx
		pop esi
		call gutil_press_a_key
%endif

			cmp DWORD [xhci_res], 0
			jnz	.Back
			xHCI_IS_USB3_PORT(edx)
			cmp al, 1
			jnz	.Back
			mov esi, xhci_port_info
			shl	edx, 2					; *XHCI_PORT_INFO_SIZE
			add esi, edx
			and BYTE [esi+XHCI_PORT_INFO_FLAGS_OFFS], ~xHCI_PROTO_ACTIVE
			xor eax, eax
			mov al, [esi+XHCI_PORT_INFO_OTHER_PORT_NUM_OFFS]
			shl	eax, 2					; *XHCI_PORT_INFO_SIZE
			mov esi, xhci_port_info
			add esi, eax
			or	BYTE [esi+XHCI_PORT_INFO_FLAGS_OFFS], xHCI_PROTO_ACTIVE
%ifdef	DBGXHCI_PORTINFO
		push ebx
		mov ebx, xhci_PortResPortInfoUSB3Deact2Txt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, xhci_port_info
		mov ecx, [xhci_ndp]
		shl	ecx, 2
		call gutil_mem_dump
		pop ecx
		pop esi
%endif

.Back:
%ifdef	DBGXHCI_RESETPORT
		call gutil_press_a_key
%endif
			popad
			ret


; IN:	ECX(port)
; OUT:	xhci_res(result, 1 if success)
xhci_get_descriptor:
			pushad
			mov DWORD [xhci_res], 0
			mov esi, [xhci_base0]
			add esi, [xhci_op_base_off]
			mov [xhci_port_num], cl
			shl	ecx, 4
			add esi, ecx
			add esi, xHC_OPS_USBPortSt
			; clear device_descriptor struct
			mov edi, usb_dev_desc
			mov ecx, 18
			mov eax, 0
			rep stosb
			; port has been reset, and is ready to be used
			; we have a port that has a device attached and is ready for data transfer.
			; so lets create our stack and send it along.
			mov ebx, DWORD [esi+xHC_Port_PORTSC]
			and ebx, (0x0F << 10)
			shr	ebx, 10			; speed: FULL = 1, LOW = 2, HI = 3, SS = 4
			mov [xhci_speed], ebx
			; Some devices will only send the first 8 bytes of the device descriptor
			;  while in the default state.  We must request the first 8 bytes, then reset
			;  the port, set address, then request all 18 bytes.
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_SpeedTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ebx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
%endif

			; send the initialize and enable slot command
			; send the command and wait for it to return

%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_SendCmdESTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov DWORD [xhci_trb_param], 0
			mov DWORD [xhci_trb_param+4], 0
			mov DWORD [xhci_trb_status], 0
			mov DWORD [xhci_trb_command], (XHCI_TRB_SET_STYPE(0) | XHCI_TRB_SET_TYPE(XHCI_ENABLE_SLOT))
%ifdef	DBGXHCI_CONTROLSUB
		push esi
		push ecx
		mov esi, xhci_trb_param
		mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
		pop ecx
		pop esi
		call gutil_press_a_key
%endif
			mov edx, 1
			call xhci_send_command
			cmp eax, 1
			jz	.Back
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_SendCmdESOkTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			; once we get the interrupt, we can get the slot_id
			mov eax, [xhci_trb_command]
			XHCI_TRB_GET_SLOT_REG(eax)
			mov [xhci_slot_id], eax
			; if the slot id > 0, we have a valid slot id
			cmp eax, 0
			jng	.Back
%ifdef	DBGXHCI_CONTROL	
		push ebx
		mov ebx, xhci_SlotIDTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_dec
		call gstdio_new_line
		call gutil_press_a_key
%endif
			mov ebx, [xhci_speed]
			call xhci_get_max_packet_from_enum
			; initialize the device/slot context
	;IN: EAX(slot_id), ECX(port), EBX(speed), EDX(max_packet)
	;OUT: EDX(slot_addr)
			mov [xhci_max_packet], edx
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_InitSlotTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_dec
		push ebx
		mov ebx, 32
		call gstdio_draw_char
		pop ebx
		push eax
		mov al, [xhci_port_num]
		call gstdio_draw_dec
		pop eax
		push ebx
		mov ebx, 32
		call gstdio_draw_char
		pop ebx
		push eax
		mov eax, ebx
		call gstdio_draw_dec
		pop eax
		push ebx
		mov ebx, 32
		call gstdio_draw_char
		pop ebx
		push eax
		mov eax, edx
		call gstdio_draw_dec
		pop eax
		push ebx
		mov ebx, 32
		call gstdio_draw_char
		pop ebx
		call gstdio_new_line
		call gutil_press_a_key
%endif
			mov eax, [xhci_slot_id]
			xor ecx, ecx
			mov cl, [xhci_port_num]
	;IN: EAX(slot_id), ECX(port), EBX(speed), EDX(max_packet)
	;OUT: EDX(slot_addr)
			call xhci_initialize_slot
			mov [xhci_slot_addr], edx
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_SlotContextTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		call gstdio_new_line
		mov esi, edx
		mov ecx, [xhci_context_size]
		shl	ecx, 1
		call gutil_mem_dump
		call gutil_press_a_key
		pop ecx
		pop esi
%endif

%ifdef DO_DEVDESC8  ;!!!!!!!!!!!

			; send the address_device command
	;IN: EAX(slot_id), EBX(flag; 1 or 0), EDX(slot_addr)
%ifdef	DBGXHCI_CONTROL
		call gstdio_draw_hex
		call gstdio_new_line
		push ebx
		mov ebx, xhci_SetAddressTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			; save heap_ptr because the InputContext-buffer (used by set_address) is not needed after set_address
			mov ebx, [xhci_cur_heap_ptr]
			mov [xhci_cur_heap_ptr_saved], ebx
			mov ebx, 1
			mov eax, [xhci_slot_id]
			mov edx, [xhci_slot_addr]
			call xhci_set_address
			mov ebx, [xhci_cur_heap_ptr_saved]
			mov [xhci_cur_heap_ptr], ebx
			cmp DWORD [xhci_res], 1
			jne	.Back
			mov DWORD [xhci_res], 0
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_SetAddressOKTxt
		call gstdio_draw_text
		pop ebx
;	push esi
;	push edx
;	mov esi, [xhci_base0]
;	add esi, [xhci_rts_offset]
;	add esi, 0x20
;	mov edx, [esi+xHC_INTERRUPTER_IMAN]
;	call gstdio_draw_hex
;	call gstdio_new_line
;	pop edx
;	pop esi
		call gutil_press_a_key
%endif

%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_StatusRegTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push edx
		mov esi, [xhci_base0]
		add esi, [xhci_op_base_off]
		mov edx, [esi+xHC_OPS_USBStatus]
		call gstdio_draw_hex
		call gstdio_new_line
		push ebx
		mov ebx, xhci_CmdRegTxt
		call gstdio_draw_text
		pop ebx
		mov edx, [esi+xHC_OPS_USBCommand]
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
		pop esi
		call gutil_press_a_key
%endif

%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_GetDevDesc8Txt
		call gstdio_draw_text
		call gutil_press_a_key
		pop ebx
%endif
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
			mov eax, [xhci_slot_id]
			mov ecx, 8
			mov edx, [xhci_max_packet]
			mov DWORD [xhci_control_dest_buff_addr], usb_dev_desc
			mov ebx, xhci_req_dev_desc_packet
			mov [xhci_req_desc_packet], ebx
			mov BYTE [xhci_dir], 1
			; now send the "get_descriptor" packet (get 8 bytes)
			call xhci_control_io
			cmp DWORD [xhci_res], 0
			jne	.PrintDesc8
			mov ebx, xhci_ControlTransferFailedDevDesc8Txt
			call gstdio_draw_text
%ifdef	DBGXHCI_CONTROL
		push ebx
		push edx
		push esi
		mov ebx, xhci_StatusRegTxt
		call gstdio_draw_text
		mov esi, [xhci_base0]
		add esi, [xhci_op_base_off]
		mov edx, [esi+xHC_OPS_USBStatus]
		call gstdio_draw_hex
		call gstdio_new_line
		mov ebx, xhci_CmdRegTxt
		call gstdio_draw_text
		mov edx, [esi+xHC_OPS_USBCommand]
		call gstdio_draw_hex
		call gstdio_new_line
		pop esi
		pop edx
		pop ebx
		call gutil_press_a_key
%endif
			jmp .Back
.PrintDesc8:
%ifdef	DBGXHCI_CONTROL
		mov ebx, xhci_DevDesc8Txt
		call gstdio_draw_text
		mov esi, usb_dev_desc
		mov ecx, 8
		call gutil_mem_dump
		call gstdio_new_line
		call gutil_press_a_key
%endif

; TODO: if the dev_desc.max_packet was different than what we have as max_packet,
;       you would need to change it here and in the slot context by doing a
;       evaluate_slot_context call. Read 4.8.2.1 (Evaluate Endpoint Command) in the Intel XHCI-specs
;		We need an InputContext (like in case of SetAddress or ConfigureEndPoints).
;		I believe if the current maxpacket is 512 but the real one (that we have just read) is e.g. 1024, 
;		512 will work but it will be slower
			push edx
			xor ecx, ecx
			mov cl, [usb_dev_desc+USB_DEVDESC_MAX_PACKETSIZE]
			xor edx, edx
			mov dx, [usb_dev_desc+USB_DEVDESC_VER]
			cmp dh, 0x03
			jnz	.CheckMaxP
			mov edx, 1
			shl edx, cl
.CheckMaxP	cmp edx, [xhci_max_packet]
			jz	.Get18
			mov ebx, xhci_MaxPacketDiffTxt
			call gstdio_draw_text
			push eax
			mov eax, [xhci_max_packet]
			call gstdio_draw_dec
			mov ebx, 32
			call gstdio_draw_char
			mov eax, edx
			call gstdio_draw_dec
			pop eax
			call gstdio_new_line
			call gutil_press_a_key
.Get18:		pop edx
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_ResettingPortsTxt
		call gstdio_draw_text
		call gutil_press_a_key
		pop ebx
%endif
			; reset the port
   			; IN:	ECX(port)
			; OUT:	xhci_res(result, 1 if success)
			xor ecx, ecx
			mov cl, [xhci_port_num]
			call xhci_reset_port

%endif ; DO_DEVDESC8 !!!
				; check xhci_res!?
			; send set_address_command again
	;IN: EAX(slot_id), EBX(flag; 1 or 0), EDX(slot_addr)
%ifdef	DBGXHCI_CONTROL
		mov edx, [xhci_slot_addr]
		call gstdio_draw_hex
		call gstdio_new_line
		push ebx
		mov ebx, xhci_SetAddressTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			; save heap_ptr because the InputContext-buffer (used by set_address) is not needed after set_address
			mov ebx, [xhci_cur_heap_ptr]
			mov [xhci_cur_heap_ptr_saved], ebx
			mov eax, [xhci_slot_id]
			mov ebx, 0
			mov edx, [xhci_slot_addr]
		;IN: EAX(slot_id), EBX(flag; 1(block it) or 0(don't block)), EDX(slot_addr)
		;OUT: xhci_res
			call xhci_set_address
			mov ebx, [xhci_cur_heap_ptr_saved]
			mov [xhci_cur_heap_ptr], ebx
			cmp DWORD [xhci_res], 1
			jne	.Back
			mov DWORD [xhci_res], 0
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_SetAddressOKTxt
		call gstdio_draw_text
		pop ebx
;	push esi
;	push edx
;	mov esi, [xhci_base0]
;	add esi, [xhci_rts_offset]
;	add esi, 0x20
;	mov edx, [esi+xHC_INTERRUPTER_IMAN]
;	call gstdio_draw_hex
;	call gstdio_new_line
;	pop edx
;	pop esi
		call gutil_press_a_key
%endif

%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_GetDevDescAllTxt
		call gstdio_draw_text
		call gutil_press_a_key
		pop ebx
%endif
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
			mov eax, [xhci_slot_id]
			mov ecx, 18
			mov edx, [xhci_max_packet]
			mov DWORD [xhci_control_dest_buff_addr], usb_dev_desc
			mov ebx, xhci_req_dev_desc_packet
			mov [xhci_req_desc_packet], ebx
			mov BYTE [xhci_dir], 1
			; get the whole packet
			call xhci_control_io
			cmp DWORD [xhci_res], 0
			jne	.Print
			mov ebx, xhci_ControlTransferFailedDevDescAllTxt
			call gstdio_draw_text
			jmp .Back
		    ; print the descriptor
.Print:
%ifdef	DBGXHCI_CONTROL
		mov ebx, xhci_DevDescTxt
		call gstdio_draw_text
		mov esi, usb_dev_desc
		mov ecx, 18
		call gutil_mem_dump
		call gstdio_new_line
		call gutil_press_a_key
%endif

%ifdef	DBGXHCI_CONTROL
		push ebx
		push edx
		xor edx, edx
		mov ebx, xhci_ManufacturerIdxTxt
		call gstdio_draw_text
		mov dl, [usb_dev_desc+USB_DEVDESC_MANUFIDX]
		call gstdio_draw_hex
		call gstdio_new_line
		mov ebx, xhci_ProductIdxTxt
		call gstdio_draw_text
		mov dl, [usb_dev_desc+USB_DEVDESC_PRODIDX]
		call gstdio_draw_hex
		call gstdio_new_line
		mov ebx, xhci_SerialNumIdxTxt
		call gstdio_draw_text
		mov dl, [usb_dev_desc+USB_DEVDESC_SERIALIDX]
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
		pop ebx
		call gutil_press_a_key
%endif
;;;;;;;;;;;;;;;;;;String Descriptor
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_GettingStringDescTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
;	1. requests 18 bytes of the langids-descriptor
;	2. saves word (from buff+2) to xhci_langid
;	3. checks devdesc-manufacturer, if zero ==> prints "None", else requests langs-packet again with len=64, langid to RECPAC_IDX, manufId to RECPAC_VALUE (error: print GettingManufStringFailed jmp Back)
;	4. print separator
;	5. checks devdesc-product, if zero ==> prints "None" jmp Back, else requests langs-packet again with len=64, langid to RECPAC_IDX, prodId to RECPAC_VALUE (error: print GettingProdStringFailed jmp Back)
;	6. prints " (port, devaddress)" newline

	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
			mov eax, [xhci_slot_id]
			mov ecx, 18
			mov edx, [xhci_max_packet]
			mov DWORD [xhci_control_dest_buff_addr], XHCI_BUFF
			mov ebx, xhci_req_langs_packet
			mov [xhci_req_desc_packet], ebx
			mov [ebx+USB_RECPAC_LENGTH], cx
			mov BYTE [ebx+USB_RECPAC_IDX], 0
			mov BYTE [ebx+USB_RECPAC_VALUE], 0
			mov BYTE [xhci_dir], 1
			call xhci_control_io
			cmp DWORD [xhci_res], 0
			jne	.SaveLngID
			mov ebx, xhci_ControlTransferFailedLangIDsTxt
			call gstdio_draw_text
			jmp .Back
.SaveLngID:	
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_StringDescLangIdsTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, XHCI_BUFF
		mov ecx, 18
		call gutil_mem_dump
		call gutil_press_a_key
		pop ecx
		pop esi
%endif
			mov ebx, XHCI_BUFF
			add ebx, 2
			xor edx, edx
			mov dx, [ebx]
			mov [xhci_langid], dx
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_LangIDTxt
		call gstdio_draw_text
		xor edx, edx
		mov dx, [xhci_langid]
		call gstdio_draw_hex
		call gstdio_new_line
		pop ebx
%endif
			cmp	BYTE [usb_dd_manuf_idx], 0			; is there a manufacturer-string?
			jz	.PrNoManuf
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_ManufAvailTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
			mov eax, [xhci_slot_id]
			mov ecx, 64
			mov edx, [xhci_max_packet]
			mov DWORD [xhci_control_dest_buff_addr], XHCI_BUFF
			mov esi, xhci_req_langs_packet
			mov [xhci_req_desc_packet], esi
			mov [esi+USB_RECPAC_LENGTH], cx
			mov bl, [xhci_langid]
			mov [esi+USB_RECPAC_IDX], bl
			mov bl, [usb_dd_manuf_idx]
			mov [esi+USB_RECPAC_VALUE], bl
			mov BYTE [xhci_dir], 1
			call xhci_control_io
			cmp DWORD [xhci_res], 0
			jne	.PrManuf
			mov ebx, xhci_ControlTransferFailedManufactTxt
			call gstdio_draw_text
			jmp .Back
.PrNoManuf	mov ebx, xhci_NoStringTxt
			call gstdio_draw_text
			jmp .PrSepar
.PrManuf:
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_ManufTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, XHCI_BUFF
		mov ecx, 64
		call gutil_mem_dump
		pop ecx
		pop esi
		call gutil_press_a_key
%endif
			call xhci_print_string
.PrSepar	mov ebx, xhci_SeparatorTxt
			call gstdio_draw_text
			cmp	BYTE [usb_dd_prod_idx], 0			; is there a product-string?
			jnz	.ProdS
			mov ebx, xhci_NoStringTxt
			call gstdio_draw_text
			call gstdio_new_line
			jmp	.Back
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
.ProdS		mov eax, [xhci_slot_id]
			mov ecx, 64
			mov edx, [xhci_max_packet]
			mov DWORD [xhci_control_dest_buff_addr], XHCI_BUFF
			mov esi, xhci_req_langs_packet
			mov [xhci_req_desc_packet], esi
			mov [esi+USB_RECPAC_LENGTH], cx
			mov bl, [xhci_langid]
			mov [esi+USB_RECPAC_IDX], bl
			mov bl, [usb_dd_prod_idx]
			mov [esi+USB_RECPAC_VALUE], bl
			mov BYTE [xhci_dir], 1
			call xhci_control_io
			cmp DWORD [xhci_res], 0
			jne	.PrString
			mov ebx, xhci_ControlTransferFailedProductTxt
			call gstdio_draw_text
			jmp .Back
.PrString	call xhci_print_string
			; print port and devaddress
			xor ecx, ecx
			mov cl, [xhci_port_num]
			mov ebx, ' '
			call gstdio_draw_char
			mov ebx, '('
			call gstdio_draw_char
			mov eax, ecx
			call gstdio_draw_dec
			mov ebx, ','
			call gstdio_draw_char
			mov eax, [xhci_slot_context_device_addr]
			call gstdio_draw_dec
			mov ebx, ')'
			call gstdio_draw_char
			call gstdio_new_line
.Back		popad
			ret


; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
; OUT: xhci_res, [xhci_control_dest_buff_addr]
xhci_control_io:
			pushad
%ifdef	DBGXHCI_CONTROL
		push eax
		push ebx
		mov ebx, xhci_ControlIOTxt
		call gstdio_draw_text
		mov ebx, xhci_SlotIDTxt
		call gstdio_draw_text
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_LengthTxt
		call gstdio_draw_text
		mov eax, ecx
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_CMaxPacketTxt
		call gstdio_draw_text
		mov eax, edx
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DirTxt
		call gstdio_draw_text
		xor eax, eax
		mov al, [xhci_dir]
		call gstdio_draw_dec
		call gstdio_new_line
		pop ebx
		pop eax 
		call gutil_press_a_key
%endif
			mov DWORD [xhci_res], 0
			mov	esi, eax	; ESI is slot_id
			mov	edi, edx	; EDI is max_packet
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov ebp, ebx			; EBP is status_addr
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_StatusAddrNTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebp
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
		call gutil_press_a_key
%endif
			cmp ecx, 0
			jz	.ToSetup
			mov	eax, 256
			mov ebx, 1
			mov edx, 0
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; get a physical address buffer and then copy from it later
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_BufferAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
		call gutil_press_a_key
%endif
.ToSetup	mov eax, [xhci_req_desc_packet]
			mov [eax+USB_RECPAC_LENGTH], cx
	; IN: EAX(dir) (AL only); xhci_req_desc_packet (ptr)
			cmp ecx, 0
			jz	.NoData
			cmp BYTE [xhci_dir], 1
			jz	.DirIn
			mov eax, xHCI_DIR_OUT
			jmp .Setup
.DirIn		mov eax, xHCI_DIR_IN
			jmp .Setup
.NoData		mov eax, xHCI_DIR_NO_DATA
.Setup		call xhci_setup_stage

			cmp ecx, 0
			jz	.StatusSt
			push esi
			cmp BYTE [xhci_dir], 1
			jz	.DirInDt
			mov eax, xHCI_DIR_OUT_B
			jmp .SetDataSt
.DirInDt	mov eax, xHCI_DIR_IN_B
.SetDataSt	mov esi, XHCI_DATA_STAGE
	; IN: EAX(dir) (AL only); EBX(addr); ECX(size); ESI(trb_type); EBP(status_addr); EDI(max_packet)
			call xhci_data_stage
			pop esi

		; save the EP's ring ptr and cycle of the device 
	; IN: EAX(slotID), [xhci_cur_ep_ring_ptr], [xhci_cur_ep_ring_cycle]
	; OUT: -
			mov eax, esi
			call xhci_save_cur_ep_ring_ptr

%ifdef DBGXHCI_EPPTRARR
		push eax
		push ebx
		push edx
		mov ebx, xhci_EPSlotIDTxt
		call gstdio_draw_text
		mov eax, esi
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_CurEPRingPtrTxt
		call gstdio_draw_text
		mov edx, [xhci_cur_ep_ring_ptr]
		call gstdio_draw_hex
		call gstdio_new_line
		mov ebx, xhci_CurEPRingCycleTxt
		call gstdio_draw_text
		xor eax, eax
		mov al, [xhci_cur_ep_ring_cycle]
		call gstdio_draw_dec
		call gstdio_new_line
		pop edx
		pop ebx
		pop eax
		call gutil_press_a_key
%endif

%ifdef DBGXHCI_EPPTRARR
		push ebx
		push ecx
		push esi
		mov ebx, xhci_CurEPPtrArrTxt
		call gstdio_draw_text
		mov esi, xhci_cur_ep_ring_ptr_arr
		mov ecx, XHCI_MAX_DEV_CNT
		shl ecx, 2
		call gutil_mem_dump
		call gutil_press_a_key
		mov ebx, xhci_CurEPCycleArrTxt
		call gstdio_draw_text
		mov esi, xhci_cur_ep_ring_cycle_arr
		mov ecx, XHCI_MAX_DEV_CNT
		call gutil_mem_dump
		call gutil_press_a_key
		pop esi
		pop ecx
		pop ebx
%endif

%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_BeforeDoorbellDtTxt
		call gstdio_draw_text
		pop ebx
		push ebx
		mov ebx, xhci_SlotID2Txt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, esi
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		call gutil_press_a_key
%endif
			; Now ring the doorbell and wait for the interrupt to happen
			push esi
			shl	esi, 2					; *4 to get DWORDS
			add	esi, [xhci_base0]
			add esi, [xhci_db_offset]
			mov DWORD [esi], xHCI_CONTROL_EP
			pop esi
			; Now wait for the interrupt to happen
	; IN: EDX(status_addr)
	; OUT: EAX(result)
			mov edx, ebp
			call xhci_wait_for_interrupt
			cmp eax, XHCI_TRB_SUCCESS
			jne	.Back

.StatusSt:
%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_SetupAndDataIRQTxt
		call gstdio_draw_text
		pop ebx
%endif

			mov eax, xHCI_DIR_IN_B
			cmp BYTE [xhci_dir], 1
			jnz	.DoStatus
			cmp ecx, 0
			jz	.DoStatus
			mov eax, xHCI_DIR_OUT_B
.DoStatus	push ebx
			mov ebx, ebp
	; IN: EAX(dir) AL-only; EBX(status_addr)
			call xhci_status_stage
			pop ebx

		; save the EP's ring ptr and cycle of the device 
	; IN: EAX(slotID), [xhci_cur_ep_ring_ptr], [xhci_cur_ep_ring_cycle]
	; OUT: -
			mov eax, esi
			call xhci_save_cur_ep_ring_ptr

%ifdef DBGXHCI_EPPTRARR
		push eax
		push ebx
		push edx
		mov ebx, xhci_EPSlotIDTxt
		call gstdio_draw_text
		mov eax, esi
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_CurEPRingPtrTxt
		call gstdio_draw_text
		mov edx, [xhci_cur_ep_ring_ptr]
		call gstdio_draw_hex
		call gstdio_new_line
		mov ebx, xhci_CurEPRingCycleTxt
		call gstdio_draw_text
		xor eax, eax
		mov al, [xhci_cur_ep_ring_cycle]
		call gstdio_draw_dec
		call gstdio_new_line
		call gutil_press_a_key
		pop edx
		pop ebx
		pop eax
%endif

%ifdef DBGXHCI_EPPTRARR
		push ebx
		push ecx
		push esi
		mov ebx, xhci_CurEPPtrArrTxt
		call gstdio_draw_text
		mov esi, xhci_cur_ep_ring_ptr_arr
		mov ecx, XHCI_MAX_DEV_CNT
		shl ecx, 2
		call gutil_mem_dump
		call gutil_press_a_key
		mov ebx, xhci_CurEPCycleArrTxt
		call gstdio_draw_text
		mov esi, xhci_cur_ep_ring_cycle_arr
		mov ecx, XHCI_MAX_DEV_CNT
		call gutil_mem_dump
		pop esi
		pop ecx
		pop ebx
		call gutil_press_a_key
%endif

%ifdef	DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_BeforeDoorbellStTxt
		call gstdio_draw_text
		mov ebx, xhci_SlotID2Txt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, esi
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		call gutil_press_a_key
%endif
			; Now ring the doorbell and wait for the interrupt to happen
			shl	esi, 2					; *4 to get DWORDS
			add	esi, [xhci_base0]
			add esi, [xhci_db_offset]
			mov DWORD [esi], xHCI_CONTROL_EP
			; Now wait for the interrupt to happen
	; IN: EDX(status_addr)
	; OUT: EAX(result)
			mov edx, ebp
			call xhci_wait_for_interrupt
			cmp eax, XHCI_TRB_SUCCESS
			jne	.Back

			cmp BYTE [xhci_dir], 1
			jnz	.Ok
			cmp ecx, 0
			jz	.Ok
			; now copy from the physical buffer to the specified buffer
			mov esi, ebx
			mov edi, [xhci_control_dest_buff_addr]
			rep movsb
.Ok			mov DWORD [xhci_res], 1
.Back		popad
			ret


; IN: EAX(dir) (AL only); xhci_req_desc_packet (ptr)
xhci_setup_stage:
			pushad
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_SetupStgReqDescPktTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, [xhci_req_desc_packet]
		mov ecx, 8
		call gutil_mem_dump
		pop ecx
		pop esi
		push ebx
		mov ebx, xhci_DirectionTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_dec
		call gstdio_new_line
		call gutil_press_a_key
%endif
			mov ebp, [xhci_req_desc_packet]
			xor ebx, ebx
			mov bx, [ebp+USB_RECPAC_VALUE]
			shl	ebx, 16
			xor edx, edx
			mov dl, [ebp+USB_RECPAC_REQUEST]
			shl	edx, 8
			or	ebx, edx
			or	bl, [ebp+USB_RECPAC_TYPE]
			mov edx, [xhci_cur_ep_ring_ptr]
			mov [edx], ebx					;lower32of64bits
;			test DWORD [xhci_hccparams1], 1
;			jz	.Skip
			xor ebx, ebx
			mov bx, [ebp+USB_RECPAC_LENGTH]
			shl	ebx, 16
			xor ecx, ecx
			mov cx, [ebp+USB_RECPAC_IDX]
			or	ebx, ecx
			mov [edx+4], ebx				;upper32of64bits
.Skip		mov DWORD [edx+8], ((0 << 22) | 8)
			shl	eax, 16
			mov [edx+12], eax
			or	DWORD [edx+12], XHCI_TRB_SET_TYPE(XHCI_SETUP_STAGE) | (1 << 6) | (0 << 5)
			xor ebx, ebx
			mov bl, [xhci_cur_ep_ring_cycle]
			or	[edx+12], ebx
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_SetupTRBTxt	; 6.4.1.2.1 in XHCI-specs
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, edx
		mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
		call gstdio_new_line
		pop ecx
		pop esi
%endif

%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_EPRingTRBCntTxt
		call gstdio_draw_text
		pop ebx
		inc DWORD [xhci_cur_ep_ring_trb_cnt]
		push eax
		mov eax, [xhci_cur_ep_ring_trb_cnt]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
%endif

			add DWORD [xhci_cur_ep_ring_ptr], XHCI_TRB_SIZE
			call xhci_handle_link
.Back		popad
			ret


;IN: [xhci_cur_ep_ring_ptr]
;OUT: updated [xhci_cur_ep_ring_ptr], if LINK-TRB
xhci_handle_link:
			pushad
			mov ebx, [xhci_cur_ep_ring_ptr]
			; if the next trb is the link trb, then move to the first TRB
			mov eax, [ebx+12]
			XHCI_TRB_GET_TYPE_REG(eax)
			cmp eax, XHCI_LINK
			jnz	.Back
			mov eax, [ebx+12]	; this could be simplified
			push eax
			and eax, ~1
			or	eax, [xhci_cur_ep_ring_cycle]
			mov [ebx+12], eax
			mov eax, [ebx]
			mov [xhci_cur_ep_ring_ptr], eax
			pop eax
			test eax, 2			; ToggleCycle-bit set?
			jz	.Back
			xor DWORD [xhci_cur_ep_ring_cycle], 1
.Back		popad
			ret


; IN: EAX(dir) (AL only); EBX(addr); ECX(size); ESI(trb_type); EBP(status_addr); EDI(max_packet)
; copies data to usb_dev_desc
; OUT: xhci_trbs_num
xhci_data_stage:
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_DataStageTxt
		call gstdio_draw_text
		pop ebx
		push ebx
		mov ebx, xhci_DirectionTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_dec
		call gstdio_new_line
		push ebx
		mov ebx, xhci_AddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_SizeTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ecx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_TRBTypeTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, esi
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_StatusAddrNSubTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebp
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_MaxPacketTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, edi
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		call gutil_press_a_key
%endif
			pushad
			push eax
			push ebx
			mov DWORD [xhci_trbs_num], 0
			mov eax, edi
			dec eax
			add eax, ecx
			mov ebx, edi
			xor edx, edx
			div ebx
			dec eax
			cmp eax, 0
			jge .NoClear
			xor eax, eax
.NoClear	mov edx, eax	; EDX is remaining
			pop ebx
			pop eax
			; while cycle
.Next		cmp ecx, 0
			jng	.Out
			push edx
			mov edx, [xhci_cur_ep_ring_ptr]
			mov [edx], ebx ; physical address
			test DWORD [xhci_hccparams1], 1
			jz	.Skip
			mov DWORD [edx+4], 0
.Skip		pop edx
			push ebx
			mov ebx, edx
			shl ebx, 17
			cmp ecx, edi
			jnc	.MPS		; jump if unsigned greater or equal
			or	ebx, ecx
			jmp .Store
.MPS 		or	ebx, edi
.Store		push edx
		or	ebx, (0 << 22)
			mov edx, [xhci_cur_ep_ring_ptr]
			mov [edx+8], ebx
			pop edx
			mov ebx, eax
			shl	ebx, 16
			XHCI_TRB_SET_TYPE_REG(esi)
			or	ebx, eax
			or	ebx, (0 << 6) | (0 << 5) | (1 << 4) | (0 << 3) | (0 << 2)
			cmp edx, 0
			jne	.NotLast
			or	ebx, (1 << 1)		; !?
.NotLast	or	bl, [xhci_cur_ep_ring_cycle] 
			push edx
			mov edx, [xhci_cur_ep_ring_ptr]
			mov [edx+12], ebx
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_DataTRBTxt	; 6.4.1.2.2. in XHCI-specs
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, [xhci_cur_ep_ring_ptr]
		mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
		pop ecx
		pop esi
		call gstdio_new_line
		call gutil_press_a_key
%endif
			pop	edx
			pop ebx
			add ebx, edi
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_EPRingTRBCntTxt
		call gstdio_draw_text
		pop ebx
		inc DWORD [xhci_cur_ep_ring_trb_cnt]
		push eax
		mov eax, [xhci_cur_ep_ring_trb_cnt]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
%endif
			add DWORD [xhci_cur_ep_ring_ptr], XHCI_TRB_SIZE
			call xhci_handle_link
			inc DWORD [xhci_trbs_num]
			sub ecx, edi
			dec edx
			; if is a DATA_STAGE TRB, after the first trb, the remaining are NORMAL TRBs and direction is not used.
			mov esi, XHCI_NORMAL
			xor eax, eax
			jmp	.Next
.Out		mov DWORD [ebp], 0	; clear the status dword
			mov edx, [xhci_cur_ep_ring_ptr]
			mov [edx], ebp
			test DWORD [xhci_hccparams1], 1
			jz	.Skip2
			mov DWORD [edx+4], 0
.Skip2		mov DWORD [edx+8], (0 << 22)
			mov DWORD [edx+12], XHCI_TRB_SET_TYPE(XHCI_EVENT_DATA) | (1 << 5) | (0 << 4) | (0 << 1)
			xor ebx, ebx
			mov	bl, [xhci_cur_ep_ring_cycle] 
			or	DWORD [edx+12], ebx
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_EventDataTRBTxt	; 6.4.4.2 in XHCI-specs
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, [xhci_cur_ep_ring_ptr]
		mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
		call gstdio_new_line
		pop ecx
		pop esi
		call gutil_press_a_key
%endif
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_EPRingTRBCntTxt
		call gstdio_draw_text
		pop ebx
		inc DWORD [xhci_cur_ep_ring_trb_cnt]
		push eax
		mov eax, [xhci_cur_ep_ring_trb_cnt]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
%endif
			add DWORD [xhci_cur_ep_ring_ptr], XHCI_TRB_SIZE
			call xhci_handle_link
			inc DWORD [xhci_trbs_num]
			popad
			ret


; IN: EAX(dir) AL-only; EBX(status_addr)
xhci_status_stage:
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_StatusStageTxt
		call gstdio_draw_text
		pop ebx
		push ebx
		mov ebx, xhci_DirectionTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_dec
		call gstdio_new_line
		push ebx
		mov ebx, xhci_StatusAddrNSubTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		call gutil_press_a_key
%endif
			pushad
			mov edx, [xhci_cur_ep_ring_ptr]
			mov DWORD [edx], 0
;			test DWORD [xhci_hccparams1], 1
;			jz	.Skip
			mov DWORD [edx+4], 0
.Skip		mov DWORD [edx+8], (0 << 22)
			shl	eax, 16
			mov DWORD [edx+12], eax
			or	DWORD [edx+12], XHCI_TRB_SET_TYPE(XHCI_STATUS_STAGE) | (0 << 5) | (1 << 4 | (0 << 1))
			xor ecx, ecx
			mov cl, [xhci_cur_ep_ring_cycle]
			or	DWORD [edx+12], ecx
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_StatusTRBTxt	; 6.4.1.2.3 in XHCI-specs
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, edx
		mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
		call gstdio_new_line
		pop ecx
		pop esi
		call gutil_press_a_key
%endif
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_EPRingTRBCntTxt
		call gstdio_draw_text
		pop ebx
		inc DWORD [xhci_cur_ep_ring_trb_cnt]
		push eax
		mov eax, [xhci_cur_ep_ring_trb_cnt]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
%endif
			add DWORD [xhci_cur_ep_ring_ptr], XHCI_TRB_SIZE
			call xhci_handle_link
			mov edx, [xhci_cur_ep_ring_ptr]
			mov DWORD [ebx], 0			; clear the status word
			mov [edx], ebx
			test DWORD [xhci_hccparams1], 1
			jz	.Skip2
			mov DWORD [edx+4], 0
.Skip2		mov DWORD [edx+8], (0 << 22)
			mov DWORD [edx+12], XHCI_TRB_SET_TYPE(XHCI_EVENT_DATA) | (1 << 5) | (0 << 4) | (0 << 1)
			xor ebx, ebx
			mov bl, [xhci_cur_ep_ring_cycle]
			or	DWORD [edx+12], ebx
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_Event2TRBTxt	; 6.4.4.2 in XHCI-specs
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, edx
		mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
		call gstdio_new_line
		pop ecx
		pop esi
		call gutil_press_a_key
%endif
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_EPRingTRBCntTxt
		call gstdio_draw_text
		pop ebx
		inc DWORD [xhci_cur_ep_ring_trb_cnt]
		push eax
		mov eax, [xhci_cur_ep_ring_trb_cnt]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
%endif
			add DWORD [xhci_cur_ep_ring_ptr], XHCI_TRB_SIZE
			call xhci_handle_link
			popad
			ret


; IN: EDX(status_addr)
; OUT: EAX(result)
xhci_wait_for_interrupt:
			pushad
%ifdef DBGXHCI_CONTROL
		push ebx
		mov ebx, xhci_WaitForIRQTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_hex
		call gstdio_new_line
%endif

%ifndef USB_XHCI_IRQ_DEF
			mov ecx, 2000
.WCycle		mov eax, xhci_trb_event_param	
			mov ebx, [xhci_cur_event_ring_addr]
	; IN: EAX(memaddrToWriteTo), EBX(addressToReadFrom)
			call xhci_get_trb
			mov eax, [xhci_trb_event_command]
			and eax, 1
			cmp eax, [xhci_cur_event_ring_cycle]
			je	.Out
			mov ebx, 1
			call pit_delay
			loop .WCycle
			mov ebx, xhci_CommandIntTOPollTxt
			call gstdio_draw_text
			jmp .Back
.Out		call xhci_handle_irq
%endif

%ifdef USB_XHCI_IRQ_DEF
			mov ecx, 2000
%endif
.Next		test DWORD [edx], XHCI_IRQ_DONE
			jz	.Wait
			mov eax, [edx]
			XHCI_TRB_GET_COMP_CODE_REG(eax)
			cmp eax, XHCI_TRB_SUCCESS
			je	.Success 
			cmp eax, XHCI_SHORT_PACKET
			je	.Success
			cmp eax, XHCI_STALL_ERROR
			je	.StallErr
			cmp eax, XHCI_DATA_BUFFER_ERROR
			je	.StallErr
			cmp eax, XHCI_BABBLE_DETECTION
			je	.StallErr
			mov ebx, xhci_InterruptStatTxt
			call gstdio_draw_text
			push edx
			mov edx, [edx]
			call gstdio_draw_hex
			push ebx
			mov ebx, 32
			call gstdio_draw_char
			pop ebx
			pop edx
			mov eax, [edx]
			XHCI_TRB_GET_COMP_CODE_REG(eax)
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
			mov eax, USB_ERROR_UNKNOWN
			jmp .Back
.Wait:
%ifdef USB_XHCI_IRQ_DEF
			mov ebx, 1
			call pit_delay
			loop .Next
%endif
			mov ebx, xhci_InterruptTOTxt
			call gstdio_draw_text
			mov eax, USB_ERROR_TIME_OUT
			jmp .Back
.Success	mov eax, XHCI_TRB_SUCCESS
			jmp .Back
.StallErr	mov eax, XHCI_STALL_ERROR
.Back		mov [xhci_res_tmp], eax
			popad
			mov eax, [xhci_res_tmp]
			ret


;IN: EAX(slot_id), EBX(flag; 1(block it) or 0(don't block)), EDX(slot_addr)
;OUT: xhci_res
xhci_set_address:
			pushad
			mov DWORD [xhci_res], 0
			push edx
			push eax
			mov eax, [xhci_context_size]
;			mov ecx, eax
			shl eax, 5
;			add eax, ecx
			mov ecx, ebx			; flag in ECX
;add eax, [xhci_context_size]
			mov ebx, 64
			mov edx, [xhci_page_size]
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_SetAddrHeapTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		call gutil_press_a_key
%endif
			mov DWORD [ebx], 0		; heap_alloc already cleared it!
			mov DWORD [ebx+4], 0x03
	; IN: EBP(address)
			mov ebp, ebx
			add ebp, [xhci_context_size]
			call xhci_write_to_slot
			mov eax, [xhci_context_size]
			push edx
			push ebx
			mov ebx, xHCI_CONTROL_EP
			mul	ebx
			pop ebx
			pop edx
			add ebp, eax
		; IN: EBP(address)
			call xhci_write_to_ep
			pop eax
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_InputContextBuffTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, ebx
		mov ecx, [xhci_context_size]
;		shl ecx, 5				; Bochs dies!
		shl ecx, 2
		call gutil_mem_dump
		pop ecx
		pop esi
		call gstdio_new_line
		call gutil_press_a_key
%endif
			mov DWORD [xhci_trb_param], ebx		
			mov DWORD [xhci_trb_param+4], 0
			mov DWORD [xhci_trb_status], 0
			XHCI_TRB_SET_SLOT_REG(eax)
			mov DWORD [xhci_trb_command], eax
			or	DWORD [xhci_trb_command], TRB_SET_TYPE(XHCI_ADDRESS_DEVICE)
			shl	ecx, 9
			or	DWORD [xhci_trb_command], ecx
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_TRBSetAddrTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, xhci_trb_param
		mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
		pop ecx
		pop esi
		call gstdio_new_line
		call gutil_press_a_key
%endif
	; IN:	xhci_trb_..., EDX(1 is TRUE, ring it)
	; OUT:	EAX(1 is TO)
			mov edx, 1
			call xhci_send_command
			cmp eax, 1
			pop ebp			; EDX in EBP	
			jz	.Err
			mov eax, [xhci_trb_status]
			XHCI_TRB_GET_COMP_CODE_REG(eax)
			cmp eax, XHCI_TRB_SUCCESS
			jne	.Err
	; IN: EBP(offset), EBX(slot-ptr)
			mov ebx, xhci_slot_context2
			call xhci_read_from_slot

%ifdef DBGXHCI_CONTROLSUB
		push eax
		push ebx
		mov ebx, xhci_SlotContextEntriesTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_entries]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextHubTxt
		call gstdio_draw_text
		xor eax, eax
		mov al, [xhci_slot_context_hub]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextMttTxt
		call gstdio_draw_text
		xor eax, eax
		mov al, [xhci_slot_context_mtt]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextSpeedTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_speed]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextRouteStrTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_route_str]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextNumPortsTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_num_ports]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextRhPortNumTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_rh_port_num]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextMaxExitLatTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_max_exit_lat]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextIntTargetTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_int_target]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextTttTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_ttt]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextTtPortNumTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_tt_port_num]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextTtHubSlotIdTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_tt_hub_slotid]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextSlotStateTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_slot_state]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextDeviceAddressTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_device_addr]
		call gstdio_draw_dec
		call gstdio_new_line
		pop ebx
		pop eax
		call gutil_press_a_key
%endif

		mov eax, [xhci_slot_context_slot_state2] 
		mov [xhci_slot_context_slot_state], eax
		mov eax, [xhci_slot_context_device_addr2]
		mov [xhci_slot_context_device_addr], eax

%ifdef DBGXHCI_CONTROLSUB
		push eax
		push ebx
		mov ebx, xhci_SlotContextSlotStateTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_slot_state]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_SlotContextDeviceAddressTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_device_addr]
		call gstdio_draw_dec
		call gstdio_new_line
		pop ebx
		pop eax
		call gutil_press_a_key
%endif

	; IN: EBP(offset), EBX(ep-ptr)
			push edx
			mov eax, [xhci_context_size]
			mov ebx, xHCI_CONTROL_EP
			mul	ebx
			pop edx
			add ebp, eax
			mov ebx, xhci_ep_context2
			call xhci_read_from_ep

%ifdef DBGXHCI_CONTROLSUB
		push eax
		push ebx
		mov ebx, xhci_ContextIntervalTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_interval]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_ContextLSATxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_lsa]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_ContextPStreamsTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_max_pstreams]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_ContextMultTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_mult]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_ContextEPStateTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_ep_state]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_ContextMaxPSizeTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_max_packet_size]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_ContextMaxBSizeTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_max_burst_size]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_ContextHIDTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_hid]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_ContextEPTypeTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_ep_type]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_ContextCErrTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_cerr]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_ContextDequeuePtrLoTxt
		call gstdio_draw_text
		push edx
		mov edx, [xhci_ep_context_tr_dequeue_ptr_LO]
		call gstdio_draw_hex
		call gstdio_new_line
		mov ebx, xhci_ContextDequeuePtrHiTxt
		call gstdio_draw_text
		mov edx, [xhci_ep_context_tr_dequeue_ptr_HI]
		call gstdio_draw_hex
		call gstdio_new_line
		mov ebx, xhci_ContextDCSTxt
		call gstdio_draw_text
		xor edx, edx
		mov dl, [xhci_ep_context_dcs]
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
		mov ebx, xhci_ContextMaxESITPLDTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_max_esit_payload]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_ContextAvgTRBLenTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_max_average_trb_len]
		call gstdio_draw_dec
		call gstdio_new_line
		pop ebx
		pop eax
		call gutil_press_a_key
%endif

			mov eax, [xhci_ep_context_ep_state2]
			mov [xhci_ep_context_ep_state], eax
			mov eax, [xhci_ep_context_max_packet_size2]
			mov [xhci_ep_context_max_packet_size], eax

%ifdef DBGXHCI_CONTROLSUB
		push eax
		push ebx
		mov ebx, xhci_ContextEPStateTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_ep_state]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_ContextMaxPSizeTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_max_packet_size]
		call gstdio_draw_dec
		call gstdio_new_line
		pop ebx
		pop eax
		call gutil_press_a_key
%endif

			mov DWORD [xhci_res], 1
			jmp .Back
.Err		mov ebx, xhci_SetAddressFailedTxt
			call gstdio_draw_text
.Back		popad
			ret


; inserts a command into the command ring at the current command trb location
; returns TRUE if timed out
; IN:	xhci_trb_..., EDX(1 is TRUE, ring it)
; OUT:	EAX(1 is TO)
xhci_send_command:
			pushad
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_SendCmdTxt
		call gstdio_draw_text
		mov ebx, xhci_CmdRingTRBCntTxt
		call gstdio_draw_text
		inc DWORD [xhci_cmd_ring_trb_cnt]
		push eax
		mov eax, [xhci_cmd_ring_trb_cnt]
		call gstdio_draw_dec
		pop eax
		pop ebx
		call gstdio_new_line
%endif
			; we monitor bit 31 in the command dword
			mov ebx, [xhci_cmnd_trb_addr]
			mov [xhci_org_trb_addr], ebx
			; must write param and status fields to the ring before the command field.
			mov eax, [xhci_trb_param]
			mov [ebx], eax						; param
			test DWORD [xhci_hccparams1], 1
			jz	.Status
			mov eax, [xhci_trb_param+4]
			mov [ebx+4], eax
.Status		mov eax, [xhci_trb_status]
			mov [ebx+8], eax					; status
			mov eax, [xhci_trb_command]
			or	eax, [xhci_cmnd_trb_cycle]
			mov [ebx+12], eax					; command
%ifdef	DBGXHCI_CONTROLSUB
		push esi
		push ecx
		mov esi, ebx
		mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
		pop ecx
		pop esi
		call gutil_press_a_key
%endif
			add DWORD [xhci_cmnd_trb_addr], XHCI_TRB_SIZE
			mov ebx, [xhci_cmnd_trb_addr]
			; if the next trb is the link trb, then move to the next segment
			mov eax, [ebx+12]
			XHCI_TRB_GET_TYPE_REG(eax)
			cmp eax, XHCI_LINK
			jnz	.Ring
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		mov ebx, xhci_SendCmdLinkTxt
		call gstdio_draw_text
		pop ebx
;		mov DWORD [xhci_cmd_ring_trb_cnt], 0
%endif
			mov eax, [ebx+12]	; this could be simplified
			push eax
			and eax, ~1
			or	eax, [xhci_cmnd_trb_cycle]
			mov [ebx+12], eax
			mov eax, [ebx]
			mov [xhci_cmnd_trb_addr], eax
			pop eax
			test eax, 2			; ToggleCycle-bit set?
			jz	.Ring
			xor DWORD [xhci_cmnd_trb_cycle], 1
.Ring		mov DWORD [xhci_res_tmp], 0
			cmp edx, 1
			jne	.Back
			mov esi, [xhci_base0]
			add esi, [xhci_db_offset]
			mov DWORD [esi], 0					; ring the doorbell

%ifndef USB_XHCI_IRQ_DEF
			mov ecx, 2000
.WCycle		mov eax, xhci_trb_event_param	
			mov ebx, [xhci_cur_event_ring_addr]
	; IN: EAX(memaddrToWriteTo), EBX(addressToReadFrom)
			call xhci_get_trb
			mov eax, [xhci_trb_event_command]
			and eax, 1
			cmp eax, [xhci_cur_event_ring_cycle]
			je	.Out
			mov ebx, 1
			call pit_delay
			loop .WCycle
			mov ebx, xhci_CommandIntTOPollTxt
			call gstdio_draw_text
			jmp .Back
.Out		call xhci_handle_irq
%endif

			; Now wait for the interrupt to happen
			; We use bit 31 of the command dword since it is reserved
%ifdef USB_XHCI_IRQ_DEF
			mov ecx, 2000
%endif
.Timer		mov eax, [xhci_org_trb_addr]
			mov ebx, [eax+8]
			test ebx, XHCI_IRQ_DONE
			jnz	.GetData
%ifdef USB_XHCI_IRQ_DEF
			mov ebx, 1
			call pit_delay
			loop .Timer
%endif
			mov ebx, xhci_CommandIntTOTxt
			call gstdio_draw_text
%ifdef	DBGXHCI_CONTROLSUB
		push ebx
		push edx
		mov ebx, [xhci_base0]
		add ebx, [xhci_op_base_off] 
		add ebx, xHC_OPS_USBStatus					; bit3:EventInterrupt(set if when an InterruptPending-bit of any Interrupter is set)
		mov edx, [ebx]
		mov ebx, xhci_StatusRegSubTxt
		call gstdio_draw_text
		call gstdio_draw_hex
		call gstdio_new_line
		mov ebx, [xhci_base0]
		add ebx, [xhci_rts_offset]
		add ebx, 0x20
		mov edx, [ebx+xHC_INTERRUPTER_IMAN]			; bit1:InterruptEnable , bit0:InterruptPending (0x00000003)
		mov ebx, xhci_InterrupterMainRegTxt
		call gstdio_draw_text
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
		pop ebx
		call gutil_press_a_key
%endif
			mov DWORD [xhci_res_tmp], 1
			jmp .Back
			; retrieve the trb data
.GetData	mov eax, xhci_trb_param	
			mov ebx, [xhci_org_trb_addr]
			call xhci_get_trb
			; clear off the done bit
			mov eax, XHCI_IRQ_DONE	;!? ~ fails!?
			not eax
			and DWORD [xhci_trb_status], eax
			mov DWORD [xhci_res_tmp], 0
.Back		popad
			mov eax, [xhci_res_tmp]
			ret


; Create a slot entry
; - at this time, we don't know if the device is a hub or not, so we don't
;   set the slot->hub, ->mtt, ->ttt, ->etc, items.
;IN: EAX(slot_id), ECX(port), EBX(speed), EDX(max_packet)
;OUT: EDX(slot_addr)
xhci_initialize_slot:
			pushad
			; two contexts (slot and control_ep), 32 byte alignment, page_size boundary
			push eax
			push ebx
			push edx
			mov eax, [xhci_context_size]
			shl eax, 1
			mov ebx, 32
			mov edx, [xhci_page_size]
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
			mov ebp, ebx				; EBP is slot_addr
			pop edx
			pop ebx
			pop eax
			push ecx
			; write the address of the slot in the slot array
			mov ecx, [xhci_dcbaap_start]
			push eax
			shl	eax, 3		; sizeof(int64)
			add ecx, eax
			mov [ecx], ebp
			test DWORD [xhci_hccparams1], 1
			jz	.Out
			mov DWORD [ecx+4], 0
			; clear it out first
			; set the initial values
.Out		mov edi, xhci_slot_context
			mov ecx, XHCI_SLOT_CONTEXT_SIZE
			mov eax, 0
			rep stosb
			pop eax
			pop ecx
			mov DWORD [xhci_slot_context_entries], 1		; the control ep
			mov DWORD [xhci_slot_context_speed], ebx		; speed
		mov DWORD [xhci_slot_context_route_str], 0
			inc ecx
			mov DWORD [xhci_slot_context_rh_port_num], ecx	; root hub port number this device is downstream of
			dec ecx
		mov DWORD [xhci_slot_context_max_exit_lat], 0	; calculated later
			mov DWORD [xhci_slot_context_int_target], xHC_INTERRUPTER_PRIMARY
			mov DWORD [xhci_slot_context_slot_state], XHCI_SLOT_STATE_DISABLED_ENABLED
		mov DWORD [xhci_slot_context_device_addr], 0
			; now write it to the controllers slot memory buffer
			call xhci_write_to_slot	; EBP is slot_addr
			; initialize the control ep
			mov ecx, xHCI_CONTROL_EP
			mov ebx, USB_CONTROL_EP
			xor esi, esi
			xor edi, edi
	;IN: EBP(slot_addr), EAX(slot_id), ECX(ep_num), EDX(max_packet_size), EBX(type), ESI(dir), NOTUSED:EBX(speed), EDI(ep_interval)
			call xhci_initialize_ep
			mov [xhci_res_tmp], ebp
			popad
			mov edx, [xhci_res_tmp]
			ret


; IN: EBP(slot_addr, i.e. offset)
; write slot context to memory slot context buffer used by the controller
xhci_write_to_slot:
			pushad
			mov eax, [xhci_slot_context_entries]
			shl	eax, 27
			xor ebx, ebx
			mov bl, [xhci_slot_context_hub]
			shl	ebx, 26
			or eax, ebx
			xor ebx, ebx
			mov bl, [xhci_slot_context_mtt]
			shl	ebx, 25
			or eax, ebx
			mov ebx, [xhci_slot_context_speed]
			shl	ebx, 20
			or eax, ebx
			mov ebx, [xhci_slot_context_route_str]
			or eax, ebx
			mov [ebp], eax
			mov eax, [xhci_slot_context_num_ports]
			shl	eax, 24
			mov ebx, [xhci_slot_context_rh_port_num]
			shl	ebx, 16
			or eax, ebx
			mov ebx, [xhci_slot_context_max_exit_lat]
			or eax, ebx
			mov [ebp+4], eax
			mov eax, [xhci_slot_context_int_target]
			shl	eax, 22
			mov ebx, [xhci_slot_context_ttt]
			shl	ebx, 16
			or eax, ebx
			mov ebx, [xhci_slot_context_tt_port_num]
			shl	ebx, 8
			or eax, ebx
			mov ebx, [xhci_slot_context_tt_hub_slotid]
			or eax, ebx
			mov [ebp+8], eax
			mov eax, [xhci_slot_context_slot_state]
			shl	eax, 27
			mov ebx, [xhci_slot_context_device_addr]
			or eax, ebx
			mov [ebp+12], eax
			popad
			ret


; IN: EBP(offset), EBX(slot-ptr)
; read slot context from memory slot context buffer used by the controller
xhci_read_from_slot:
			pushad
			mov eax, [ebp]
			and eax, 0x1F << 27
			shr	eax, 27
			mov [ebx+XHCI_SLOT_CONTEXT_ENTRIES_OFFS], eax
			mov eax, [ebp]
			and eax, 0x01 << 26
			shr	eax, 26
			mov [ebx+XHCI_SLOT_CONTEXT_HUB_OFFS], al
			mov eax, [ebp]
			and eax, 0x01 << 25
			shr	eax, 25
			mov [ebx+XHCI_SLOT_CONTEXT_MTT_OFFS], al
			mov eax, [ebp]
			and eax, 0x0F << 20
			shr	eax, 20
			mov [ebx+XHCI_SLOT_CONTEXT_SPEED_OFFS], eax
			mov eax, [ebp]
			and eax, 0xFFFFF
			mov [ebx+XHCI_SLOT_CONTEXT_ROUTE_STR_OFFS], eax
			mov eax, [ebp+4]
			and eax, 0xFF << 24
			shr	eax, 24
			mov [ebx+XHCI_SLOT_CONTEXT_NUM_PORTS_OFFS], eax
			mov eax, [ebp+4]
			and eax, 0xFF << 16
			shr	eax, 16
			mov [ebx+XHCI_SLOT_CONTEXT_RH_PORT_NUM_OFFS], eax
			mov eax, [ebp+4]
			and eax, 0xFFFF
			mov [ebx+XHCI_SLOT_CONTEXT_MAX_EXIT_LAT_OFFS], eax
			mov eax, [ebp+8]
			and eax, 0x3FF << 22
			shr	eax, 22
			mov [ebx+XHCI_SLOT_CONTEXT_INT_TARGET_OFFS], eax
			mov eax, [ebp+8]
			and eax, 0x03 << 16
			shr	eax, 16
			mov [ebx+XHCI_SLOT_CONTEXT_TTT_OFFS], eax
			mov eax, [ebp+8]
			and eax, 0xFF << 8
			shr	eax, 8
			mov [ebx+XHCI_SLOT_CONTEXT_TT_PORT_NUM_OFFS], eax
			mov eax, [ebp+8]
			and eax, 0xFF
			mov [ebx+XHCI_SLOT_CONTEXT_TT_HUB_SLOT_ID_OFFS], eax
			mov eax, [ebp+12]
			and eax, 0x1F << 27
			shr	eax, 27
			mov [ebx+XHCI_SLOT_CONTEXT_SLOT_STATE_OFFS], eax
			mov eax, [ebp+12]
			and eax, 0xFF
			mov [ebx+XHCI_SLOT_CONTEXT_DEVICE_ADDR_OFFS], eax
			popad
			ret


; The Average TRB Length field is computed by dividing the average TD Transfer Size by 
;  the average number of TRBs that are used to describe a TD, including Link, No Op, and Event Data TRBs.
;IN: EBP(slot_addr), EAX(slot_id), ECX(ep_num), EDX(max_packet_size), EBX(type), ESI(dir), NOTUSED:EBX(speed), EDI(ep_interval)
xhci_initialize_ep:
			pushad
			; since we are only getting the device descriptor, we assume type will be CONTROL_EP
			cmp ebx, USB_CONTROL_EP
			jne	.Back

			; clear it out first
			push ecx
			push edi
			mov edi, xhci_ep_context
			mov ecx, XHCI_EP_CONTEXT_SIZE
			mov eax, 0
			rep stosb
			pop edi
			pop ecx
			; allocate the EP's Transfer Ring
	; IN:	EAX(number of TRBs)
	; OUT:	EBX(memaddr)
			mov eax, XHCI_TRBS_PER_RING
			call xhci_create_ring
			mov [xhci_ep_context_tr_dequeue_ptr_LO], ebx
			mov DWORD [xhci_ep_context_tr_dequeue_ptr_HI], 0
			mov BYTE [xhci_ep_context_dcs], XHCI_TRB_CYCLE_ON
			; save for the control_in stuff
			mov [xhci_cur_ep_ring_ptr], ebx

			mov al, [xhci_ep_context_dcs]
			mov [xhci_cur_ep_ring_cycle], al 

			; set the initial values
			mov [xhci_ep_context_max_packet_size], edx
		mov BYTE [xhci_ep_context_lsa], 0
		mov DWORD [xhci_ep_context_max_pstreams], 0
		mov DWORD [xhci_ep_context_mult], 0
			mov DWORD [xhci_ep_context_ep_state], XHCI_EP_STATE_DISABLED
		mov BYTE [xhci_ep_context_hid], 0
			mov DWORD [xhci_ep_context_ep_type], XHCI_EP_TYPE_CONTROL 
			mov DWORD [xhci_ep_context_max_average_trb_len], 8
			mov DWORD [xhci_ep_context_cerr], 3
		mov DWORD [xhci_ep_context_max_burst_size], 0
			mov [xhci_ep_context_interval], edi
			; now write it to the controllers ep memory block
			push edx
			mov eax, [xhci_context_size]
			mov ebx, ecx
			mul ebx
			pop edx
			add ebp, eax
		; IN: EBP(slot_addr, i.e. offset)
			call xhci_write_to_ep
.Back		popad
			ret


; IN: EBP(offset), EBX(ep-ptr)
; read ep context from memory ep context buffer used by the controller
xhci_read_from_ep:
			pushad
			mov eax, [ebp]
			and eax, 0xFF << 16
			shr	eax, 16
			mov [ebx+XHCI_EP_CONTEXT_INTERVAL_OFFS], eax
			mov eax, [ebp]
			and eax, 0x01 << 15
			shr	eax, 15
			mov [ebx+XHCI_EP_CONTEXT_LSA_OFFS], al
			mov eax, [ebp]
			and eax, 0x1F << 10
			shr	eax, 10
			mov [ebx+XHCI_EP_CONTEXT_MAX_PSTREAMS_OFFS], eax
			mov eax, [ebp]
			and eax, 0x03 << 8
			shr	eax, 8
			mov [ebx+XHCI_EP_CONTEXT_MULT_OFFS], eax
			mov eax, [ebp]
			and eax, 0x07
			mov [ebx+XHCI_EP_CONTEXT_EP_STATE_OFFS], eax
			mov eax, [ebp+4]
			and eax, 0xFFFF << 16
			shr	eax, 16
			mov [ebx+XHCI_EP_CONTEXT_MAX_PACKET_SIZE_OFFS], eax
			mov eax, [ebp+4]
			and eax, 0x00FF << 8
			shr	eax, 8
			mov [ebx+XHCI_EP_CONTEXT_MAX_BURST_SIZE_OFFS], eax
			mov eax, [ebp+4]
			and eax, 0x01 << 7
			shr	eax, 7
			mov [ebx+XHCI_EP_CONTEXT_HID_OFFS], al
			mov eax, [ebp+4]
			and eax, 0x07 << 3
			shr	eax, 3
			mov [ebx+XHCI_EP_CONTEXT_EP_TYPE_OFFS], eax
			mov eax, [ebp+4]
			and eax, 0x03 << 1
			shr	eax, 1
			mov [ebx+XHCI_EP_CONTEXT_CERR_OFFS], eax
			mov eax, [ebp+8]
			and eax, ~0x0F
			mov [ebx+XHCI_EP_CONTEXT_TR_DEQUEUE_PTR_LO_OFFS], eax
;			test DWORD [xhci_hccparams1], 1
;			jz	.Out
			mov eax, [ebp+12]
			mov [ebx+XHCI_EP_CONTEXT_TR_DEQUEUE_PTR_HI_OFFS], eax
.Out		mov eax, [ebp+8]
			and eax, 0x01
			mov [ebx+XHCI_EP_CONTEXT_DCS_OFFS], al
			mov eax, [ebp+16]
			and eax, 0xFFFF << 16
			shr	eax, 16
			mov [ebx+XHCI_EP_CONTEXT_MAX_ESIT_PAYLOAD_OFFS], eax
			mov eax, [ebp+16]
			and eax, 0xFFFF
			mov [ebx+XHCI_EP_CONTEXT_MAX_AVERAGE_TRB_LEN_OFFS], eax
			popad
			ret


; write ep context to memory ep context buffer used by the controller
; IN: EBP(slot_addr, i.e. offset)
xhci_write_to_ep:
			pushad
			mov eax, [xhci_ep_context_interval]
			shl	eax, 16
			xor ebx, ebx
			mov bl, [xhci_ep_context_lsa]
			shl	ebx, 15
			or eax, ebx
			mov ebx, [xhci_ep_context_max_pstreams]
			shl	ebx, 10
			or eax, ebx
			mov ebx, [xhci_ep_context_mult]
			shl	ebx, 8
			or eax, ebx
			mov ebx, [xhci_ep_context_ep_state]
			or eax, ebx
			mov [ebp], eax
			mov eax, [xhci_ep_context_max_packet_size]
			shl	eax, 16
			mov ebx, [xhci_ep_context_max_burst_size]
			shl	ebx, 8
			or eax, ebx
			xor ebx, ebx
			mov bl, [xhci_ep_context_hid]
			shl	ebx, 7
			or eax, ebx
			mov ebx, [xhci_ep_context_ep_type]
			shl	ebx, 3
			or eax, ebx
			mov ebx, [xhci_ep_context_cerr]
			shl	ebx, 1
			or eax, ebx
			mov [ebp+4], eax
			mov eax, [xhci_ep_context_tr_dequeue_ptr_LO]
			or	al, [xhci_ep_context_dcs]
			mov [ebp+8], eax
			mov eax, [xhci_ep_context_tr_dequeue_ptr_HI]
			mov [ebp+12], eax
			mov eax, [xhci_ep_context_max_esit_payload]
			shl eax, 16
			or	eax, [xhci_ep_context_max_average_trb_len]
			mov [ebp+16], eax
			popad
			ret


; we only "catch" the ones we need and ignore all of the rest.
; It is a big job to work on all returned events.  This will be something
;  I will leave for your efforts.
; Remember that this also assumes that all events will fit within the same segment and not wrap...
xhci_handle_irq:
%ifndef USB_XHCI_IRQ_DEF
			pushad
%endif

%ifdef	DBGXHCI_IRQ
		push ebx
		call gstdio_new_line
		mov ebx, xhci_IRQArrivedTxt
		call gstdio_draw_text
		pop ebx
%endif

%ifndef USB_XHCI_IRQ_DEF
		; we need a little delay because the XHCI-controller needs some time after it put the first TRB in the event-ring
			push ebx
			mov ebx, 1			; works on Dell
			call pit_delay
			pop ebx
%else
			; acknowledge interrupt (status register first)
			; clear the status register bits
			mov esi, [xhci_base0]
			add esi, [xhci_op_base_off] 
			add esi, xHC_OPS_USBStatus
			mov eax, [esi]
			mov [esi], eax
			mov esi, [xhci_base0]
			add esi, [xhci_rts_offset]
			add esi, 0x20
			mov eax, [esi+xHC_INTERRUPTER_IMAN]
			mov ebx, eax
			and ebx, 3
			cmp ebx, 3
			jnz	.Back
%endif

%ifdef	DBGXHCI_IRQ
		push ebx
		mov ebx, xhci_IRQAcknowledgeTxt
		call gstdio_draw_text
		pop ebx
%endif

%ifdef USB_XHCI_IRQ_DEF
			; acknowledge the interrupter's IP bit being set
			or	eax, 3
			mov	DWORD [esi+xHC_INTERRUPTER_IMAN], eax
%endif
			; do the work
			mov edi, [xhci_cur_event_ring_addr]	; EDI is last_addr (we don't use it here!?)
			mov eax, xhci_trb_event_param	
			mov ebx, [xhci_cur_event_ring_addr]
	; IN: EAX(memaddrToWriteTo), EBX(addressToReadFrom)
			call xhci_get_trb
%ifdef	DBGXHCI_IRQ
		push ebx
		mov ebx, xhci_IRQEventRingTRBTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, [xhci_cur_event_ring_addr]
		mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
;		call gstdio_new_line
		push ebx
		mov ebx, xhci_IRQTRBTxt
		call gstdio_draw_text
		pop ebx
		mov esi, xhci_trb_event_param
		mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
		call gstdio_new_line
		pop ecx
		pop esi
%endif
			; while cycle
.Cycle		mov eax, [xhci_trb_event_command]
			and eax, 1
			cmp eax, [xhci_cur_event_ring_cycle]
			jne	.Out
%ifdef	DBGXHCI_IRQ
		push ebx
		mov ebx, xhci_IRQEventRingCycleIsOneTxt			; <--
		call gstdio_draw_text
		pop ebx
%endif
			mov eax, [xhci_trb_event_command]
			and eax, (1 << 2)
			jnz	.Done									; <--
%ifdef	DBGXHCI_IRQ
		push ebx
		mov ebx, xhci_IRQCmdBit2NotSetTxt
		call gstdio_draw_text
		pop ebx
%endif
			mov eax, [xhci_trb_event_status]
			XHCI_TRB_GET_COMP_CODE_REG(eax)
%ifdef	DBGXHCI_IRQ
		push ebx
		mov ebx, xhci_IRQTRBCodeTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_dec
		call gstdio_new_line
%endif
			cmp eax, XHCI_TRB_SUCCESS
			jne	.GetNext
%ifdef	DBGXHCI_IRQ
		push ebx
		mov ebx, xhci_IRQTRBSuccessTxt
		call gstdio_draw_text
		pop ebx
%endif
			; TRB_SUCCESS
			mov eax, [xhci_trb_event_command]
			XHCI_TRB_GET_TYPE_REG(eax)
			cmp eax, XHCI_COMMAND_COMPLETION
			jne	.GetNext
			; Command Completion Event
.COMCOMPL:
%ifdef	DBGXHCI_IRQ
		push ebx
		mov ebx, xhci_IRQTRBCommComplTxt
		call gstdio_draw_text
		pop ebx
%endif
			mov ebp, [xhci_trb_event_param]	; EBP is org_address
			mov eax, xhci_trb_org_param	
			mov ebx, ebp
	; IN: EAX(memaddrToWriteTo), EBX(addressToReadFrom)
			call xhci_get_trb
			mov eax, [xhci_trb_org_command]
			XHCI_TRB_GET_TYPE_REG(eax)
			cmp eax, XHCI_ENABLE_SLOT
			jne	.Default
			and DWORD [xhci_trb_org_command], 0x00FFFFFF
			mov eax, [xhci_trb_event_command]
			and eax, 0xFF000000				; return slot ID (1 based)
			or	DWORD [xhci_trb_org_command], eax
			mov eax, [xhci_trb_event_status]
			mov [xhci_trb_org_status], eax
			jmp .MarkCmd
.Default	mov eax, [xhci_trb_event_status]
			mov [xhci_trb_org_status], eax
			; mark the command as done
.MarkCmd	or	DWORD [xhci_trb_org_status], XHCI_IRQ_DONE
			; and write it back
			mov eax, ebp
			mov ebx, xhci_trb_org_param
		; IN: EAX(memaddrToWriteTo), EBX(addressToReadFrom)
			call xhci_get_trb
			jmp .GetNext
			; mark the TRB as done
.Done:
%ifdef	DBGXHCI_IRQ
		push ebx
		mov ebx, xhci_IRQMarkTRBTxt
		call gstdio_draw_text
		pop ebx
%endif
			mov eax, [xhci_trb_event_command]
			XHCI_TRB_GET_TYPE_REG(eax)
			cmp eax, XHCI_TRANS_EVENT
			jne	.GetNext
%ifdef	DBGXHCI_IRQ
		push ebx
		mov ebx, xhci_IRQTransEventTxt
		call gstdio_draw_text
		pop ebx
%endif
			; If SPD was encountered in this TD, comp_code will be SPD, else it should be SUCCESS (specs 4.10.1.1)
			mov eax, [xhci_trb_event_status]
			or	eax, XHCI_IRQ_DONE			; return code + bytes *not* transferred
			push ebx
			mov ebx, [xhci_trb_event_param]
			mov [ebx], eax
			pop ebx
			; get next one
.GetNext	mov edi, [xhci_cur_event_ring_addr]
			add	DWORD [xhci_cur_event_ring_addr], XHCI_TRB_SIZE
			mov eax, xhci_trb_event_param	
			mov ebx, [xhci_cur_event_ring_addr]
			call xhci_get_trb
%ifdef	DBGXHCI_IRQ
		push ebx
		mov ebx, xhci_IRQEventRingTRBCntTxt
		call gstdio_draw_text
		pop ebx
		inc DWORD [xhci_cur_event_ring_trb_cnt]
		push eax
		mov eax, [xhci_cur_event_ring_trb_cnt]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
%endif
			jmp	.Cycle		; end of while-loop
			; advance the dequeue pointer (clearing the busy bit)
.Out		mov esi, [xhci_base0]
			add esi, [xhci_rts_offset]
			add esi, 0x20
			or	edi, (1<<3)
			mov DWORD [esi+xHC_INTERRUPTER_DEQUEUE], edi
			test DWORD [xhci_hccparams1], 1
			jz	.Back
			mov DWORD [esi+xHC_INTERRUPTER_DEQUEUE+4], 0
.Back:		
%ifndef USB_XHCI_IRQ_DEF
			popad
%endif
			ret


; IN: EAX(memaddrToWriteTo), EBX(addressToReadFrom)
xhci_get_trb:
			pushad
			mov ecx, [ebx]
			mov [eax], ecx
			mov ecx, [ebx+4]
			mov [eax+4], ecx
			mov ecx, [ebx+8]
			mov [eax+8], ecx
			mov ecx, [ebx+12]
			mov [eax+12], ecx
			popad
			ret

xhci_print_string:
			pushad
			mov esi, [xhci_control_dest_buff_addr]
			xor ecx, ecx
			mov cl, [esi]
			sub ecx, 2					; number of chars
			add esi, 2
			shr ecx, 1
			xor eax, eax			
.Next		xor ebx, ebx
			mov bl, [esi]
			call gstdio_draw_char
			add esi, 2
			inc eax
			cmp al, cl
			jnge .Next
.Back		popad
			ret


; ************* WORDS

; IN: EAX(device address), EDX(idx)
; OUT: xhci_res
; memdump of device-descriptor, configuration-descriptor (including Interface and Endpoints descriptors)
; saves mps and endpts
; If device is a Mass-Storage one (0x08), then prints MaxLun
; First finds the slot_addr from device-address, then gets slot_id and max_packet (reads slot-context to xhci_slot_context structure)
; Then it gets the DevDesc, because usb_dev_desc may contain another device's data.
; For a SuperSpeed-device (max_packet>=512) we need to request the BOS(BinaryDeviceObjectStore)-descriptor first. 
; The Endpoint-descriptor of a SuperSpeed-device has an Endpoint-Companion-descriptor.
xhci_dev_info:
			pushad
%ifdef DBGXHCI_DEVINFO
		call gstdio_new_line
		push ebx
		mov ebx, xhci_DIDevInfoTxt
		call gstdio_draw_text
		mov ebx, xhci_DIDevInfoDevAddrTxt
		call gstdio_draw_text
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DIDevInfoIDXTxt
		call gstdio_draw_text
		push eax
		mov eax, edx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		pop ebx
		call gutil_press_a_key
%endif
			mov DWORD [xhci_res], 0
			mov BYTE [xhci_inited_msd], 0xFF
			mov [xhci_dev_address], al
			mov ebp, [xhci_dcbaap_start]				; slot_addr = [xhci_dcbaap_start]+slot_id*sizeof(bit64u), slot_id, the scratchpad-buffer is zero in the array
%ifdef DBGXHCI_DEVINFO
		push ebx
		mov ebx, xhci_DIDCBAAPStartTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebp
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push esi
		push ecx
		mov esi, ebp
		mov ecx, 64
		call gutil_mem_dump
		pop ecx
		pop esi
		call gutil_press_a_key
%endif
			xor ecx, ecx								; ECX((slot_id)
.NextSlot	add ebp, 8									; sizeof(bit64u)
			inc ecx
			cmp DWORD [ebp], 0							; 64-bit pointers !!??
			jz	.Back
%ifdef	DBGXHCI_DEVINFO
		push ebx
		mov ebx, xhci_DISlotIterTxt
		call gstdio_draw_text
		pop ebx
%endif
%ifdef DBGXHCI_DEVINFO
		push esi
		push ecx
		mov esi, [ebp]
		mov ecx, XHCI_SLOT_CONTEXT_SIZE
		call gutil_mem_dump
		pop ecx
		pop esi
		call gstdio_new_line
		call gutil_press_a_key
%endif
			push ebp
			mov ebp, [ebp]
			mov [xhci_slot_addr], ebp				; save slot-address for xhci_init_msd
	; IN: EBP(offset), EBX(slot-ptr)
			mov ebx, xhci_slot_context				; xhci_slot_context2 !?
			call xhci_read_from_slot
			pop ebp
%ifdef DBGXHCI_DEVINFO
		push eax
		push ebx
		mov ebx, xhci_DISlotContextEntriesTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_entries]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextHubTxt
		call gstdio_draw_text
		xor eax, eax
		mov al, [xhci_slot_context_hub]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextMttTxt
		call gstdio_draw_text
		xor eax, eax
		mov al, [xhci_slot_context_mtt]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextSpeedTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_speed]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextRouteStrTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_route_str]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextNumPortsTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_num_ports]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextRhPortNumTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_rh_port_num]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextMaxExitLatTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_max_exit_lat]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextIntTargetTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_int_target]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextTttTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_ttt]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextTtPortNumTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_tt_port_num]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextTtHubSlotIdTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_tt_hub_slotid]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextSlotStateTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_slot_state]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DISlotContextDeviceAddressTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_device_addr]
		call gstdio_draw_dec
		call gstdio_new_line
		pop ebx
		pop eax
		call gutil_press_a_key
%endif
			cmp eax, [xhci_slot_context_device_addr]
			jnz	.NextSlot
%ifdef	DBGXHCI_DEVINFO
		push ebx
		mov ebx, xhci_DIDevInfoDevAddrFndTxt
		call gstdio_draw_text
		pop ebx
%endif
			cmp DWORD [xhci_slot_context_slot_state], XHCI_SLOT_STATE_ADDRESSED
			jne	.Back
%ifdef	DBGXHCI_DEVINFO
		push ebx
		mov ebx, xhci_DIDevInfoStateAddressedFndTxt
		call gstdio_draw_text
		pop ebx
%endif
			mov ebp, edx								; EBP(idx)
			mov ebx, [xhci_slot_context_speed]
			call xhci_get_max_packet_from_enum			; EDX(max_packet)
			mov [xhci_max_packet], edx
			mov eax, ecx								; EAX(slot_id)
			mov [xhci_slot_id], eax

%ifdef	DBGXHCI_DEVINFO
		push ebx
		mov ebx, xhci_DISlotIdTxt
		call gstdio_draw_text
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DIMaxPacketTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, edx
		call gstdio_draw_dec
		call gstdio_new_line
		pop eax
%endif

;		; The EP's transfer-ring-ptr 
		; IN: EAX(slotID)
		; OUT: the updated [xhci_cur_ep_ring_ptr] (can be zero, if error) and [xhci_cur_ep_ring_cycle]
			call xhci_get_cur_ep_ring_ptr

%ifdef	DBGXHCI_EPPTRARR
		push eax
		push ebx
		push edx
		mov ebx, xhci_CurEPRingPtrTxt
		call gstdio_draw_text
		mov edx, [xhci_cur_ep_ring_ptr]
		call gstdio_draw_hex
		call gstdio_new_line
		mov ebx, xhci_CurEPRingCycleTxt
		call gstdio_draw_text
		xor eax, eax
		mov al, [xhci_cur_ep_ring_cycle]
		call gstdio_draw_dec
		call gstdio_new_line
		pop edx
		pop ebx
		pop eax
		call gutil_press_a_key
%endif

			cmp ebp, 0
			jz	.Dev
	; We need to get the DevDesc, because usb_dev_desc may contain another device's data
			call gstdio_new_line
			mov ebx, xhci_GettingDevDescriptorTxt
			call gstdio_draw_text
.Dev:
%ifdef	DBGXHCI_DEVINFO
		push ebx
		mov ebx, xhci_GettingDevDescriptorTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov ecx, 18
			mov DWORD [xhci_control_dest_buff_addr], usb_dev_desc
			mov ebx, xhci_req_dev_desc_packet
			mov [xhci_req_desc_packet], ebx
			mov BYTE [xhci_dir], 1
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
			call xhci_control_io
			cmp DWORD [xhci_res], 0
			jne	.ChkPrint1
			mov ebx, xhci_ControlTransferFailedDevDescAllTxt
			call gstdio_draw_text
			jmp .Back
.ChkPrint1	cmp ebp, 0
			jz	.ChkBOS
		    ; print Device-descriptor
			mov ebx, xhci_DevDescTxt
			call gstdio_draw_text
			mov esi, usb_dev_desc
			mov ecx, 18
			call gutil_mem_dump
			call gstdio_new_line
.ChkBOS:		
%ifdef	DBGXHCI_DEVINFO
	    ; print Device-descriptor
		mov ebx, xhci_DevDescTxt
		call gstdio_draw_text
		mov esi, usb_dev_desc
		mov ecx, 18
		call gutil_mem_dump
		call gstdio_new_line
		call gutil_press_a_key
%endif
			cmp edx, 512								; if max_packet<512 then it is not a SuperSpeed-device
			jc	.Conf
			cmp ebp, 2
			jnz	.BOS
			mov ebx, xhci_GettingBOSDescriptorTxt
			call gstdio_draw_text
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
.BOS		mov ecx, 22
			mov DWORD [xhci_control_dest_buff_addr], XHCI_BUFF
			mov ebx, xhci_req_bos_desc_packet
			mov [xhci_req_desc_packet], ebx
			mov BYTE [xhci_dir], 1
			call xhci_control_io
			cmp DWORD [xhci_res], 0
			jne	.ChkPrint2
			mov ebx, xhci_ControlTransferFailedBOSTxt
			call gstdio_draw_text
			jmp .Back
.ChkPrint2	cmp ebp, 2
			jnz	.Conf
		    ; print BOS-descriptor
			mov ebx, xhci_BOSDescTxt
			call gstdio_draw_text
			mov esi, [xhci_control_dest_buff_addr]
			mov ecx, 22
			call gutil_mem_dump
			call gstdio_new_line
.Conf		cmp ebp, 2
			jnz	.Conf2
			mov ebx, xhci_GettingConfigDescTxt
			call gstdio_draw_text
;			; first get 64 bytes and check totalLength of the returned data, if greater than 64, then request totalLength
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
.Conf2		mov ecx, 64
			mov DWORD [xhci_control_dest_buff_addr], XHCI_BUFF
			mov ebx, xhci_req_config_packet
			mov [xhci_req_desc_packet], ebx
			mov [ebx+USB_RECPAC_LENGTH], cx
			mov BYTE [xhci_dir], 1
			call xhci_control_io
			cmp DWORD [xhci_res], 0
			jne	.ChkCfgLen
			mov ebx, xhci_ControlTransferFailedConfigDescTxt
			call gstdio_draw_text
			jmp .Back
.ChkCfgLen	mov esi, [xhci_control_dest_buff_addr]
			add esi, 2								; address of totalLength
			cmp WORD [esi], 64						; or mps!?
			jna	.ChkPrint3
%ifdef DBGXHCI_DEVINFO
		push ebx
		mov ebx, xhci_DIConfigBiggerTxt
		call gstdio_draw_text
		pop ebx
%endif
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
			xor ecx, ecx
			mov cx, [esi]
			mov DWORD [xhci_control_dest_buff_addr], XHCI_BUFF
			mov ebx, xhci_req_config_packet
			mov [xhci_req_desc_packet], ebx
			mov [ebx+USB_RECPAC_LENGTH], cx
			mov BYTE [xhci_dir], 1
			call xhci_control_io
			cmp DWORD [xhci_res], 0
			jne	.ChkPrint3
			mov ebx, xhci_ControlTransferFailedConfigDesc2Txt
			call gstdio_draw_text
			jmp .Back
.ChkPrint3	cmp ebp, 2
			jnz	.SaveEndpts
		    ; print Config-descriptor
			mov ebx, xhci_ConfigDescTxt
			call gstdio_draw_text
			mov esi, [xhci_control_dest_buff_addr]
			mov eax, esi
			add eax, 2
			xor ecx, ecx
			mov cx, [eax]
			call gutil_mem_dump
			call gstdio_new_line
.SaveEndpts	mov esi, [xhci_control_dest_buff_addr]
			call xhci_save_endpts
			cmp DWORD [xhci_res], 1
			jnz	.Back
%ifdef DBGXHCI_DEVINFO
		push ebx
		mov ebx, xhci_DIEndptsSavedTxt
		call gstdio_draw_text
		pop ebx
		push eax
		push ebx
		mov ebx, xhci_DIBulkOutEptTxt
		call gstdio_draw_text
		xor eax, eax
		mov al, [xhci_bulkout_endpt]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DIBulkOutMpsTxt
		call gstdio_draw_text
		xor eax, eax
		mov ax, [xhci_bulkout_mps]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DIBulkInEptTxt
		call gstdio_draw_text
		xor eax, eax
		mov al, [xhci_bulkin_endpt]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_DIBulkInMpsTxt
		call gstdio_draw_text
		xor eax, eax
		mov ax, [xhci_bulkin_mps]
		call gstdio_draw_dec
		call gstdio_new_line
		pop ebx
		pop eax
		call gutil_press_a_key
%endif
;			; get MaxLun if device is a Pen-drive
.LUN		mov esi, [xhci_control_dest_buff_addr]
			add esi, 4								; address of NumInterfaces
			cmp BYTE [esi], 0						; no interfaces?
			jz	.Back
			sub esi, 4
			xor ebx, ebx
			mov bl, [esi]
			add esi, ebx							; we are now at the beginning of the Interface Descriptor
			add esi, 5								; address of Class-code
			cmp BYTE [esi], 0x08					; Mass Storage?
			jnz	.Back
			cmp ebp, 2
			jnz	.LUN2
			mov ebx, xhci_GettingLUNTxt
			call gstdio_draw_text
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
.LUN2		mov ecx, 1
			mov eax, [xhci_slot_id]
			mov edx, [xhci_max_packet]
			mov DWORD [xhci_control_dest_buff_addr], XHCI_BUFF
			mov ebx, xhci_req_lun_packet
			mov [xhci_req_desc_packet], ebx
			mov BYTE [xhci_dir], 1
			call xhci_control_io
			cmp DWORD [xhci_res], 0
			jne	.StoreLUN
			mov ebx, xhci_ControlTransferFailedLUNTxt
			call gstdio_draw_text
			jmp .Back
.StoreLUN	mov ebx, [xhci_control_dest_buff_addr]
			mov dl, [ebx]
			cmp dl, 0xFF
			jnz	.StoreLUN2
			mov dl, 0
.StoreLUN2	mov [xhci_max_lun], dl
.PrLUN		cmp ebp, 2
			jnz	.Back
			mov ebx, xhci_MaxLunTxt
			call gstdio_draw_text
			mov dh, [xhci_max_lun]					; prints zero, but if it would be FF then it should mean zero as well!
			call gstdio_draw_hex8
			call gstdio_new_line
.Back		popad
			ret


; IN: [xhci_dev_address]
; OUT: xhci_res, lbaHi, lbaLO, sectorsize
; Function xhci_dev_info fills xhci_slot_id and xhci_max_packet variables
; device_address is not used!? (because we get slotaddr, slotid from xhci_dev_info !?)
; It does: 
;	- sets context_enties to 5 (slot-context was already read in xhci_dev_info)
;	- reads from Slot-Context to ep-struct 
;	- allocates InputContext(33 slots), fills InputContext [Slot and ControlEP, ContextEntries=5], 
;   - sends an EvaluateContext (or ConfigureEP immediately!?), 
;	- set first two bits of add-context (Slot and ControlEP), then sets two of the next 4 bits according to 
;		the xhci_bulkin_endpt and xhci_bulkout_endpt
; 	- fills the endpoints, then sends a ConfigureEP
;	- sets configuration1
;	- does a bulkreset
;	- Inquiry, TestUnit, Sense, TestUnit
;	- gets capacity of msd (mass storage device)
xhci_init_msd:
			pushad
%ifdef DBGXHCI_INITMSD
		call gstdio_new_line
		push ebx
		mov ebx, xhci_IMSDInitMSDTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov DWORD [xhci_res], 0
			mov DWORD [xhci_lbahi], 0
			mov DWORD [xhci_lbalo], 0
			mov DWORD [xhci_sector_size], 0
			mov BYTE [xhci_inited_msd], 0xFF
			; check heap_ptr, if it contains its initial value, then no USBENUM was called
			cmp DWORD [xhci_cur_heap_ptr], XHCI_HEAP_INIT
			jz	.Back

			mov DWORD [xhci_slot_context_entries], 5

			; read from Slot-ControlEP to ep-struct
	; IN: EBP(offset), EBX(ep-ptr)
			mov eax, [xhci_context_size]
			mov ebx, xHCI_CONTROL_EP
			mul	ebx
			add ebp, eax
			mov ebx, xhci_ep_context
			call xhci_read_from_ep
%ifdef DBGXHCI_INITMSD
		push eax
		push ebx
		mov ebx, xhci_IMSDEPContextIntervalTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_interval]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextLSATxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_lsa]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextPStreamsTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_max_pstreams]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextMultTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_mult]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextEPStateTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_ep_state]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextMaxPSizeTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_max_packet_size]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextMaxBSizeTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_max_burst_size]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextHIDTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_hid]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextEPTypeTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_ep_type]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextCErrTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_cerr]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextDequeuePtrLoTxt
		call gstdio_draw_text
		push edx
		mov edx, [xhci_ep_context_tr_dequeue_ptr_LO]
		call gstdio_draw_hex
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextDequeuePtrHiTxt
		call gstdio_draw_text
		mov edx, [xhci_ep_context_tr_dequeue_ptr_HI]
		call gstdio_draw_hex
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextDCSTxt
		call gstdio_draw_text
		xor edx, edx
		mov dl, [xhci_ep_context_dcs]
		call gstdio_draw_hex
		call gstdio_new_line
		pop edx
		mov ebx, xhci_IMSDEPContextMaxESITPLDTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_max_esit_payload]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDEPContextAvgTRBLenTxt
		call gstdio_draw_text
		mov eax, [xhci_ep_context_max_average_trb_len]
		call gstdio_draw_dec
		call gstdio_new_line
		pop ebx
		pop eax
		call gutil_press_a_key
%endif
			; allocate memory for Input Context	(33 slots)
			; save heap_ptr because the InputContext-buffer is not needed after the command
			mov ebx, [xhci_cur_heap_ptr]
			mov [xhci_cur_heap_ptr_saved], ebx
			mov eax, [xhci_context_size]
			mov ecx, eax
			shl eax, 5
			add eax, ecx
			mov ecx, ebx			; flag in ECX
		;add eax, [xhci_context_size]
			mov ebx, 64
			mov edx, [xhci_page_size]
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDInputContextHeapTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
%endif
; Fill InputContext(i.e. ebx) [Slot and ControlEP, ContextEntries=5], then send an EvaluateContext (or ConfigureEP immediately!?)
; set first two bits of add-context (Slot and ControlEP), then set two of the next 4 bits according to 
;	the xhci_bulkin_endpt and xhci_bulkout_endpt
; then fill the endpoints, then send a ConfigureEP

			; to Add/Delete
			mov DWORD [ebx], 0
			mov DWORD [ebx+4], 0x03		; plus the two bits of bulk-EPts later
	; IN: EBP(slot_addr, i.e. offset)
			mov ebp, ebx
			add ebp, [xhci_context_size]
			call xhci_write_to_slot

			mov eax, [xhci_context_size]
			push edx
			push ebx
			mov ebx, xHCI_CONTROL_EP
			mul	ebx
			pop ebx
			pop edx
			add ebp, eax
			call xhci_write_to_ep

			add ebp, [xhci_context_size]
	; modify xhci_ep_context, then write to EPContext-slots
			cmp BYTE [xhci_bulkout_endpt], 1
			jnz	.BulkIn
			mov	DWORD [ebx+4], 0x27
	; IN: EBP(address), EDI(direction: in if 1), ECX(MaxPacketSize)
			xor edi, edi
			xor ecx, ecx
			mov cx, [xhci_bulkout_mps]
			call xhci_set_bulk_context
			add ebp, [xhci_context_size]
			add ebp, [xhci_context_size]
			add ebp, [xhci_context_size]
			; in
	; IN: EBP(address), EDI(direction: in if 1), ECX(MaxPacketSize)
			mov edi, 1
			xor ecx, ecx
			mov cx, [xhci_bulkin_mps]
			call xhci_set_bulk_context
			jmp .ConfEP
.BulkIn		add ebp, [xhci_context_size]
			mov	DWORD [ebx+4], 0x1B
	; IN: EBP(address), EDI(direction: in if 1), ECX(MaxPacketSize)
			mov edi, 1
			xor ecx, ecx
			mov cx, [xhci_bulkin_mps]
			call xhci_set_bulk_context
			; out
			add ebp, [xhci_context_size]
			xor edi, edi
			xor ecx, ecx
			mov cx, [xhci_bulkout_mps]
			call xhci_set_bulk_context
	; send ConfigureEP (or EvaluateContext then ConfigureEP)
.ConfEP:
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDInputContextTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, ebx
		push eax
		mov ecx, [xhci_context_size]
		mov eax, ecx
		shl ecx, 2						; *4
		add ecx, eax					; 5th
		add ecx, eax					; 6th
		pop eax
		call gutil_mem_dump
		pop ecx
		pop esi
		call gstdio_new_line
		call gutil_press_a_key
%endif
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDConfigureEPTxt
		call gstdio_draw_text
		pop ebx
%endif
			mov DWORD [xhci_trb_param], ebx	
			mov DWORD [xhci_trb_param+4], 0
			mov DWORD [xhci_trb_status], 0
			mov eax, [xhci_slot_id]
			mov	DWORD [xhci_trb_command], 0
			XHCI_TRB_SET_SLOT_REG(eax)
			mov DWORD [xhci_trb_command], eax
			or	DWORD [xhci_trb_command], TRB_SET_TYPE(XHCI_CONFIG_EP)
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDConfigureEPTRBTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, xhci_trb_param
		mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
		pop ecx
		pop esi
		call gstdio_new_line
		call gutil_press_a_key
%endif

			mov edx, 1
			call xhci_send_command
			mov ebx, [xhci_cur_heap_ptr_saved]			; !?
			mov [xhci_cur_heap_ptr], ebx
			cmp eax, 1
			jz	.ErrCfg
			mov eax, [xhci_trb_status]
			XHCI_TRB_GET_COMP_CODE_REG(eax)
			cmp eax, XHCI_TRB_SUCCESS
			je	.CfgOk
.ErrCfg		mov ebx, xhci_ConfigureEPFailedTxt
			call gstdio_draw_text
			jmp .Back
.CfgOk:

%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDConfigureEPOkTxt
		call gstdio_draw_text
		push ebp
		mov ebp, [xhci_slot_addr]
		mov ebx, xhci_slot_context
		call xhci_read_from_slot
		pop ebp
		pop ebx
		call gutil_press_a_key
		push eax
		push ebx
		mov ebx, xhci_IMSDSlotContextEntriesTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_entries]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextHubTxt
		call gstdio_draw_text
		xor eax, eax
		mov al, [xhci_slot_context_hub]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextMttTxt
		call gstdio_draw_text
		xor eax, eax
		mov al, [xhci_slot_context_mtt]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextSpeedTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_speed]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextRouteStrTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_route_str]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextNumPortsTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_num_ports]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextRhPortNumTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_rh_port_num]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextMaxExitLatTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_max_exit_lat]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextIntTargetTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_int_target]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextTttTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_ttt]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextTtPortNumTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_tt_port_num]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextTtHubSlotIdTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_tt_hub_slotid]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextSlotStateTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_slot_state]
		call gstdio_draw_dec
		call gstdio_new_line
		mov ebx, xhci_IMSDSlotContextDeviceAddressTxt
		call gstdio_draw_text
		mov eax, [xhci_slot_context_device_addr]
		call gstdio_draw_dec
		call gstdio_new_line
		pop ebx
		pop eax
		call gutil_press_a_key
%endif

; Specs p101: In addressed state only a few commands can be issued.
;		p102: SET_CONFIGURATION Request, issue after configuring EPts.
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDSetConfigDevTxt
		call gstdio_draw_text
		pop ebx
%endif
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
			mov ecx, 0
			mov eax, [xhci_slot_id]
			mov edx, [xhci_max_packet]
			mov DWORD [xhci_control_dest_buff_addr], XHCI_BUFF
			mov ebx, xhci_set_config_packet
			mov [xhci_req_desc_packet], ebx
			mov [ebx+USB_RECPAC_LENGTH], cx
			mov BYTE [xhci_dir], 0
			call xhci_control_io
			cmp DWORD [xhci_res], 0
			jne	.BulkReset
			mov ebx, xhci_SetControlTransferFailedSetConfigTxt
			call gstdio_draw_text
			jmp .Back

.BulkReset:
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDSetConfigOkTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif

%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDBulkResetTxt
		call gstdio_draw_text
		pop ebx
%endif
			call xhci_bulk_reset						; to clear data-toggles of Endpt-s
			cmp DWORD [xhci_res], 1
			jnz	.Back
			mov ebx, 100								; DELAY
			call pit_delay
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDInquiryTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			call xhci_inquiry_req
			cmp DWORD [xhci_res], 1
			jnz	.Back
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDTestUnitTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			call xhci_testunit_req
			cmp DWORD [xhci_res], 1
			jnz	.Back
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDSenseTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			call xhci_sense_req
			cmp DWORD [xhci_res], 1
			jnz	.Back
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDTestUnitTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			call xhci_testunit_req
			cmp DWORD [xhci_res], 1
			jnz	.Back
			mov eax, scsi_read_capacity10_cbw
			mov ecx, 8
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDCapacityTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			call xhci_capacity_req
			cmp DWORD [xhci_lbalo], 0xFFFFFFFF
			jz	.Cap16
			cmp DWORD [xhci_lbalo], 0x1000000					; number of sectors of a 8Gb drive
			ja	.Medium
			mov BYTE [xhci_device_size], XHCI_DEVICE_SMALL
			jmp .Inited
.Medium		mov BYTE [xhci_device_size], XHCI_DEVICE_MEDIUM
			jmp .Inited
.Cap16		mov eax, scsi_read_capacity16_cbw
			mov ecx, 32
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDCapacityTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			call xhci_capacity_req
			mov BYTE [xhci_device_size], XHCI_DEVICE_BIG
			cmp DWORD [xhci_res], 1
			jnz	.Back
.Inited		mov al, [xhci_dev_address]
			mov [xhci_inited_msd], al
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDSetInitedMSDTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
.Back		popad
			mov ebx, [xhci_lbahi]
			mov ecx, [xhci_lbalo]
			mov edx, [xhci_sector_size]
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDHEAPPTRTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, [xhci_cur_heap_ptr]
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		call gutil_press_a_key
%endif
			ret


; IN:EBX(enum-value)
; OUT: EDX(max_packet)
xhci_get_max_packet_from_enum:
			cmp ebx, xHCI_SPEED_LOW
			je	.Low
			cmp ebx, xHCI_SPEED_FULL
			je	.FullHi
			cmp ebx, xHCI_SPEED_HI
			je	.FullHi
			cmp ebx, xHCI_SPEED_SUPER
			je	.Super
			jmp .Back
.Low		mov edx, 8
			jmp .Back
.FullHi		mov edx, 64
			jmp .Back
.Super		mov edx, 512		
.Back		ret


; IN: ESI(buffer-ptr)
; OUT:
xhci_save_endpts:
			pushad
			mov DWORD [xhci_res], 0
			xor ecx, ecx
			mov cl, [esi+4]							; ECX: number of interfaces
			xor eax, eax
			mov al, [esi]
			add esi, eax
			cmp BYTE [esi+4], 1						; Endpoints-byte is greater than 1 ?
			ja	.GetEPts
			mov ebx, xhci_EndptsErrTxt
			call gstdio_draw_text
			jmp	.Back
;			; skip other interfaces
;.NextInt	dec ecx
;			jz	.GetEPts
;			xor eax, eax
;			mov al, [esi]
;			add esi, eax
;			jmp .NextInt
.GetEPts	xor eax, eax
			mov al, [esi]
			add esi, eax
			mov al, [esi+2]							; Endpt-byte
			call xhci_save_endptnum
			mov bx, [esi+4]							; MPS
			call xhci_save_endpt_mps
			xor eax, eax
			mov al, [esi]
			add esi, eax
			cmp BYTE [esi+1], 0x30					; Endpt-Companion-descriptor? (for SuperSpeed-device) 
			jne	.GetEpt2
			xor eax, eax
			mov al, [esi]
			add esi, eax
.GetEpt2	mov al, [esi+2]							; Endpt-byte
			call xhci_save_endptnum
			mov bx, [esi+4]							; MPS
			call xhci_save_endpt_mps
			mov DWORD [xhci_res], 1
.Back		popad
			ret


; IN: AL(Endpt-byte)
; OUT: AL(EndptNum)
xhci_save_endptnum:
			bt	ax, 7			
			jc	.EptIn
			and al, 0x0F
			mov [xhci_bulkout_endpt], al
			ret
.EptIn		and al, 0x0F
			mov [xhci_bulkin_endpt], al
			ret


; IN: AL(EndptNum), BX(MPS of Endpt)
xhci_save_endpt_mps:
			cmp al, 1
			jz	.In
			mov [xhci_bulkout_mps], bx
			ret
.In			mov [xhci_bulkin_mps], bx
			ret


; IN:
; OUT: xhci_res
xhci_bulk_reset:
			pushad
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
			mov ecx, 0
			mov eax, [xhci_slot_id]
			mov edx, [xhci_max_packet]
			mov DWORD [xhci_control_dest_buff_addr], XHCI_BUFF
			mov ebx, xhci_req_bulkreset_packet
			mov [xhci_req_desc_packet], ebx
			mov [ebx+USB_RECPAC_LENGTH], cx
			mov BYTE [xhci_dir], 0
			call xhci_control_io
			cmp DWORD [xhci_res], 1
;			jz	.ResetE1
	jz	.Back
			mov ebx, xhci_BulkResetFailedTxt
			call gstdio_draw_text
			jmp .Err
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
.ResetE1	mov ecx, 0
			mov eax, [xhci_slot_id]
			mov edx, [xhci_max_packet]
			mov DWORD [xhci_control_dest_buff_addr], XHCI_BUFF
			mov ebx, xhci_req_bulkendptreset_packet			; ClearFeature(ENDPOINT_HALT), EP1
			mov [xhci_req_desc_packet], ebx
			mov BYTE [ebx+USB_RECPAC_IDX], 1
			mov [ebx+USB_RECPAC_LENGTH], cx
			mov BYTE [xhci_dir], 0
			call xhci_control_io
			cmp DWORD [xhci_res], 1
			jz	.ResetE2
			mov ebx, xhci_BulkE1ResetFailedTxt
			call gstdio_draw_text
			jmp .Err
	; IN: EAX(slot_id), ECX(len), EDX(max_packet), [xhci_dir], [xhci_req_desc_packet], [xhci_control_dest_buff_addr]
	; OUT: xhci_res, [xhci_control_dest_buff_addr]
.ResetE2	mov ecx, 0
			mov eax, [xhci_slot_id]
			mov edx, [xhci_max_packet]
			mov DWORD [xhci_control_dest_buff_addr], XHCI_BUFF
			mov ebx, xhci_req_bulkendptreset_packet			; ClearFeature(ENDPOINT_HALT), EP1
			mov [xhci_req_desc_packet], ebx
			mov BYTE [ebx+USB_RECPAC_IDX], 2
			mov [ebx+USB_RECPAC_LENGTH], cx
			mov BYTE [xhci_dir], 0
			call xhci_control_io
			cmp DWORD [xhci_res], 1
			jz	.Back
			mov ebx, xhci_BulkE2ResetFailedTxt
			call gstdio_draw_text
.Err		mov DWORD [xhci_res], 0
.Back		mov ebx, 100			; DELAY
			call pit_delay
			popad
			ret


; IN: EBP(address), EDI(direction: in if 1), ECX(MaxPacketSize)
xhci_set_bulk_context:
			pushad
			; allocate the EP's Transfer Ring
	; IN:	EAX(number of TRBs)
	; OUT:	EBX(memaddr)
			mov eax, XHCI_TRBS_PER_BULK_RING
			call xhci_create_ring									; this memory won't be enough for bulk!!
			mov [xhci_ep_context_tr_dequeue_ptr_LO], ebx
			mov DWORD [xhci_ep_context_tr_dequeue_ptr_HI], 0
			mov BYTE [xhci_ep_context_dcs], XHCI_TRB_CYCLE_ON
			cmp edi, 0
			jz	.Out
			mov [xhci_cur_bulkin_ep_ring_ptr], ebx
			mov al, [xhci_ep_context_dcs]
			mov [xhci_cur_bulkin_ep_ring_cycle], al
			mov DWORD [xhci_ep_context_ep_type], XHCI_EP_TYPE_BULK_IN
			jmp .Rest
.Out		mov [xhci_cur_bulkout_ep_ring_ptr], ebx
			mov al, [xhci_ep_context_dcs]
			mov [xhci_cur_bulkout_ep_ring_cycle], al
			mov DWORD [xhci_ep_context_ep_type], XHCI_EP_TYPE_BULK_OUT
.Rest		mov [xhci_ep_context_max_packet_size], ecx
			mov BYTE [xhci_ep_context_lsa], 0
			mov DWORD [xhci_ep_context_max_pstreams], 0
			mov DWORD [xhci_ep_context_mult], 0
			mov DWORD [xhci_ep_context_ep_state], XHCI_EP_STATE_DISABLED
			mov BYTE [xhci_ep_context_hid], 0
			mov DWORD [xhci_ep_context_max_average_trb_len], 3072	; 3kb
			mov DWORD [xhci_ep_context_cerr], 3
			mov DWORD [xhci_ep_context_max_burst_size], 0
			mov DWORD [xhci_ep_context_interval], 0
	; IN: EBP(slot_addr, i.e. offset)
			call xhci_write_to_ep
			popad
			ret


;IN: [xhci_cur_bulkin_ep_ring_ptr], [xhci_cur_bulkin_ep_ring_cycle]
;OUT: updated IN if LINK-TRB
xhci_handle_bulkin_link:
			pushad
			mov ebx, [xhci_cur_bulkin_ep_ring_ptr]
			; if the next trb is the link trb, then move to the first TRB
			mov eax, [ebx+12]
			XHCI_TRB_GET_TYPE_REG(eax)
			cmp eax, XHCI_LINK
			jnz	.Back
			mov eax, [ebx+12]	; this could be simplified
			push eax
			and eax, ~1
			or	eax, [xhci_cur_bulkin_ep_ring_cycle]
			mov [ebx+12], eax
			mov eax, [ebx]
			mov [xhci_cur_bulkin_ep_ring_ptr], eax
			pop eax
			test eax, 2			; ToggleCycle-bit set?
			jz	.Back
			xor DWORD [xhci_cur_bulkin_ep_ring_cycle], 1
.Back		popad
			ret


;IN: [xhci_cur_bulkout_ep_ring_ptr], [xhci_cur_bulkout_ep_ring_cycle]
;OUT: updated IN if LINK-TRB
xhci_handle_bulkout_link:
			pushad
			mov ebx, [xhci_cur_bulkout_ep_ring_ptr]
			; if the next trb is the link trb, then move to the first TRB
			mov eax, [ebx+12]
			XHCI_TRB_GET_TYPE_REG(eax)
			cmp eax, XHCI_LINK
			jnz	.Back
			mov eax, [ebx+12]	; this could be simplified
			push eax
			and eax, ~1
			or	eax, [xhci_cur_bulkout_ep_ring_cycle]
			mov [ebx+12], eax
			mov eax, [ebx]
			mov [xhci_cur_bulkout_ep_ring_ptr], eax
			pop eax
			test eax, 2			; ToggleCycle-bit set?
			jz	.Back
			xor DWORD [xhci_cur_bulkout_ep_ring_cycle], 1
.Back		popad
			ret


; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet); 
;	xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
; OUT: xhci_res, xhci_trbs_num
; from direction: usage of EP (bulkOut or bulkIn)
; ring Out/In-Doorbell
xhci_bulk_io:
			pushad
%ifdef	DBGXHCI_BULKIO
		push ebx
		mov ebx, xhci_BulkIOTxt
		call gstdio_draw_text
		pop ebx
		push ebx
		mov ebx, xhci_BulkDirTxt
		call gstdio_draw_text
		pop ebx
		push eax
		xor eax, eax
		mov al, [xhci_bulk_dir]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkSizeTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ecx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkStatusAddrNSubTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ebp
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkMaxPacketTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, edi
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		call gutil_press_a_key
%endif
			push ebx
			mov DWORD [xhci_trbs_num], 0
			mov eax, edi
			dec eax
			add eax, ecx
			mov ebx, edi
			xor edx, edx
			div ebx
			dec eax
			cmp eax, 0
			jge .NoClear
			xor eax, eax
.NoClear	mov edx, eax	; EDX is remaining
			pop ebx
			cmp BYTE [xhci_bulk_dir], 0
			jne	.In
			mov eax, [xhci_cur_bulkout_ep_ring_ptr]
			jmp .Next
.In			mov eax, [xhci_cur_bulkin_ep_ring_ptr]	; ring_ptr in EAX
			; while cycle
.Next		cmp ecx, 0
			jng	.Out
.StoreAddr	mov [eax], ebx ; physical address
			test DWORD [xhci_hccparams1], 1
			jz	.Skip
			mov DWORD [eax+4], 0
.Skip		push ebx
			mov ebx, edx
			shl ebx, 17
			cmp ecx, edi
			jnc	.MPS
			or	ebx, ecx
			jmp .Store
.MPS 		or	ebx, edi
.Store		or	ebx, (0 << 22)
			mov [eax+8], ebx
			push eax
			mov esi, XHCI_NORMAL
			XHCI_TRB_SET_TYPE_REG(esi)
			mov	ebx, eax
			pop eax
			or	ebx, (0 << 9) | (0 << 6) | (0 << 5) | (1 << 4) | (0 << 3) | (0 << 2)
			cmp edx, 0
			jne	.NotLast
			or	ebx, (1 << 1)		; !?
.NotLast	cmp BYTE [xhci_bulk_dir], 0
			jne	.InCyc
			or	bl, [xhci_cur_bulkout_ep_ring_cycle]
			jmp .Store12
.InCyc		or	bl, [xhci_cur_bulkin_ep_ring_cycle]
.Store12	mov [eax+12], ebx
%ifdef	DBGXHCI_BULKIO
		push ebx
		mov ebx, xhci_BulkTRBTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		cmp BYTE [xhci_bulk_dir], 0
		jne	.InDbg
		mov esi, [xhci_cur_bulkout_ep_ring_ptr]
		jmp .SiDbg
.InDbg	mov esi, [xhci_cur_bulkin_ep_ring_ptr]
.SiDbg	mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
		pop ecx
		pop esi
;		call gstdio_new_line
%endif
			pop ebx
			add ebx, edi
%ifdef	DBGXHCI_BULKIO
		push eax
		cmp BYTE [xhci_bulk_dir], 0
		jne	.InDbgC
		push ebx
		mov ebx, xhci_BulkOutEPRingTRBCntTxt
		call gstdio_draw_text
		pop ebx
		inc DWORD [xhci_cur_bulkout_ep_ring_trb_cnt]
		mov eax, [xhci_cur_bulkout_ep_ring_trb_cnt]
		jmp .DrDbg
.InDbgC	push ebx
		mov ebx, xhci_BulkInEPRingTRBCntTxt
		call gstdio_draw_text
		pop ebx
		inc DWORD [xhci_cur_bulkin_ep_ring_trb_cnt]
		mov eax, [xhci_cur_bulkin_ep_ring_trb_cnt]
.DrDbg	call gstdio_draw_dec
		pop eax
		call gstdio_new_line
%endif
			; this assumes that we will always have room in the ring for these TRB's
			cmp BYTE [xhci_bulk_dir], 0
			jne	.IncIn
			add DWORD [xhci_cur_bulkout_ep_ring_ptr], XHCI_TRB_SIZE
			call xhci_handle_bulkout_link
			mov eax, [xhci_cur_bulkout_ep_ring_ptr]
			jmp .IncTRBs
.IncIn		add DWORD [xhci_cur_bulkin_ep_ring_ptr], XHCI_TRB_SIZE
			call xhci_handle_bulkin_link
			mov eax, [xhci_cur_bulkin_ep_ring_ptr]
.IncTRBs	inc DWORD [xhci_trbs_num]
			sub ecx, edi
			dec edx
			jmp	.Next
.Out		mov DWORD [ebp], 0	; clear the status dword
			mov [eax], ebp
			test DWORD [xhci_hccparams1], 1
			jz	.Skip2
			mov DWORD [eax+4], 0
.Skip2		mov DWORD [eax+8], (0 << 22)
			mov DWORD [eax+12], XHCI_TRB_SET_TYPE(XHCI_EVENT_DATA) | (1 << 5) | (0 << 4) | (0 << 1)
			xor ebx, ebx
			cmp BYTE [xhci_bulk_dir], 0
			jne	.InCyc2
			mov	bl, [xhci_cur_bulkout_ep_ring_cycle] 
			jmp .Store12_2
.InCyc2		mov	bl, [xhci_cur_bulkin_ep_ring_cycle] 
.Store12_2	or	DWORD [eax+12], ebx
%ifdef	DBGXHCI_BULKIO
		push ebx
		mov ebx, xhci_BulkEventDataTRBTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		cmp BYTE [xhci_bulk_dir], 0
		jne	.InDbg2
		mov esi, [xhci_cur_bulkout_ep_ring_ptr]
		jmp .SiDbg2
.InDbg2	mov esi, [xhci_cur_bulkin_ep_ring_ptr]
.SiDbg2	mov ecx, XHCI_TRB_SIZE
		call gutil_mem_dump
		call gstdio_new_line
		pop ecx
		pop esi
%endif
%ifdef	DBGXHCI_BULKIO
		push eax
		cmp BYTE [xhci_bulk_dir], 0
		jne	.IDbgC
		push ebx
		mov ebx, xhci_BulkOutEPRingTRBCntTxt
		call gstdio_draw_text
		pop ebx
		inc DWORD [xhci_cur_bulkout_ep_ring_trb_cnt]
		mov eax, [xhci_cur_bulkout_ep_ring_trb_cnt]
		jmp .DDbg
.IDbgC	push ebx
		mov ebx, xhci_BulkInEPRingTRBCntTxt
		call gstdio_draw_text
		pop ebx
		inc DWORD [xhci_cur_bulkin_ep_ring_trb_cnt]
		mov eax, [xhci_cur_bulkin_ep_ring_trb_cnt]
.DDbg	call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		call gutil_press_a_key
%endif
			; this assumes that we will always have room in the ring for these TRB's
			cmp BYTE [xhci_bulk_dir], 0
			jne	.IncIn2
			add DWORD [xhci_cur_bulkout_ep_ring_ptr], XHCI_TRB_SIZE
			call xhci_handle_bulkout_link
			mov eax, [xhci_cur_bulkout_ep_ring_ptr]
			jmp .IncTRBs2
.IncIn2		add DWORD [xhci_cur_bulkin_ep_ring_ptr], XHCI_TRB_SIZE
			call xhci_handle_bulkin_link
			mov eax, [xhci_cur_bulkin_ep_ring_ptr]
.IncTRBs2	inc DWORD [xhci_trbs_num]
			; Now ring the doorbell and wait for the interrupt to happen
			xor eax, eax
			cmp BYTE [xhci_bulk_dir], 0				; out?
			jne	.InChk
			cmp BYTE [xhci_bulkout_endpt], 1		; 1 or 2
			jne	.SetOut2
			mov al, xHCI_EP1_OUT
			jmp .RingDB
.SetOut2	mov al, xHCI_EP2_OUT
			jmp .RingDB
.InChk		cmp BYTE [xhci_bulkin_endpt], 1			; 1 or 2
			jne	.SetIn2
			mov al, xHCI_EP1_IN
			jmp .RingDB
.SetIn2		mov al, xHCI_EP2_IN
.RingDB		mov esi, [xhci_slot_id]
			shl	esi, 2					; *4 to get DWORDS
			add	esi, [xhci_base0]
			add esi, [xhci_db_offset]
			mov DWORD [esi], eax
			; Now wait for the interrupt to happen
	; IN: EDX(status_addr)
	; OUT: EAX(result)
			mov edx, ebp
			call xhci_wait_for_interrupt
			mov DWORD [xhci_res], 0
			cmp eax, XHCI_TRB_SUCCESS
			jne	.Back
			mov DWORD [xhci_res], 1
.Back		popad
			ret


; IN:
; OUT: xhci_res
xhci_inquiry_req:
			pushad
			mov ebx, scsi_inquiry_cbw
			mov ebp, [ebx+4]
			push ebx
			mov [xhci_curr_tag], ebp
			mov ecx, XHCI_CBW_LEN
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov ebp, ebx			; status_addr
			pop ebx
			mov BYTE [xhci_bulk_dir], 0
			xor edi, edi
			mov di, [xhci_bulkout_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			cmp DWORD [xhci_res], 1
			jz	.Get
			mov ebx, xhci_SendInquiryCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.Get:
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDInquiryGetTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov ebp, ebx			; status_addr
			mov	eax, 36
			mov ebx, 1
			mov edx, 0
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
		mov [xhci_bulk_arr], ebx
			mov ecx, eax
		mov [xhci_bulk_size], ecx
			mov BYTE [xhci_bulk_dir], 1
			xor edi, edi
			mov di, [xhci_bulkin_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			cmp DWORD [xhci_res], 1
			jz	.ReadCSW
			mov ebx, xhci_GetInquiryCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ReadCSW:
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDInquiryGetArrTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, [xhci_bulk_arr]
		mov ecx, [xhci_bulk_size]
		call gutil_mem_dump
		pop ecx
		pop esi
;		call gstdio_new_line
		call gutil_press_a_key
%endif
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDInquiryReadCSWTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov ebp, ebx			; status_addr
			mov	eax, XHCI_CSW_LEN
			mov ebx, 1
			mov edx, 0
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
		mov [xhci_bulk_arr], ebx
			mov ecx, eax
		mov [xhci_bulk_size], ecx
			mov BYTE [xhci_bulk_dir], 1
			xor edi, edi
			mov di, [xhci_bulkin_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			cmp DWORD [xhci_res], 1
			jz	.ChkCSW
			mov ebx, xhci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
	; IN: ECX(txtPtr), EBX(buff), xhci_curr_tag
	; OUT: EAX(0 ERR)
.ChkCSW:
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDInquiryDumpCSWTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, [xhci_bulk_arr]
		mov ecx, [xhci_bulk_size]
		call gutil_mem_dump
		pop ecx
		pop esi
;		call gstdio_new_line
		call gutil_press_a_key
%endif
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDInquiryCheckCSWTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov ecx, xhci_InquiryTxt
			call xhci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [xhci_res], 0
.Back		popad
			ret


; IN: 
; OUT: xhci_res
xhci_testunit_req:
			pushad
			mov ebx, scsi_testunit_cbw
			mov ebp, [ebx+4]
			push ebx
			mov [xhci_curr_tag], ebp
			mov ecx, XHCI_CBW_LEN
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov ebp, ebx			; status_addr
			pop ebx
			mov BYTE [xhci_bulk_dir], 0
			xor edi, edi
			mov di, [xhci_bulkout_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			cmp DWORD [xhci_res], 1
			jz	.ReadCSW
			mov ebx, xhci_SendTestUnitCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ReadCSW:
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDTestUnitReadCSWTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov ebp, ebx			; status_addr
			mov	eax, XHCI_CSW_LEN
			mov ebx, 1
			mov edx, 0
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
		mov [xhci_bulk_arr], ebx
			mov ecx, eax
		mov [xhci_bulk_size], ecx
			mov BYTE [xhci_bulk_dir], 1
			xor edi, edi
			mov di, [xhci_bulkin_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			cmp DWORD [xhci_res], 1
			jz	.ChkCSW
			mov ebx, xhci_TestUnitReadyTxt
			call gstdio_draw_text
			mov ebx, xhci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ChkCSW		jmp .Back	; WE DON'T CHECK TAG, BECAUSE TESTUNIT_READY CAN FAIL THE FIRST TIME
	; IN: ECX(txtPtr), EBX(buff), xhci_curr_tag
	; OUT: EAX(0 ERR)
			mov ecx, xhci_TestUnitReadyTxt
			call xhci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [xhci_res], 0
.Back		popad
			ret


; IN:
; OUT: xhci_res
xhci_sense_req:
			pushad
			mov ebx, scsi_sense_cbw
			mov ebp, [ebx+4]
			push ebx
			mov [xhci_curr_tag], ebp
			mov ecx, XHCI_CBW_LEN
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov ebp, ebx			; status_addr
			pop ebx
			mov BYTE [xhci_bulk_dir], 0
			xor edi, edi
			mov di, [xhci_bulkout_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			cmp DWORD [xhci_res], 1
			jz	.Get
			mov ebx, xhci_SendSenseCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.Get:
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDSenseGetTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov ebp, ebx			; status_addr
			mov	eax, 18
			mov ebx, 1
			mov edx, 0
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
		mov [xhci_bulk_arr], ebx
			mov ecx, eax
		mov [xhci_bulk_size], ecx
			mov BYTE [xhci_bulk_dir], 1
			xor edi, edi
			mov di, [xhci_bulkin_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			cmp DWORD [xhci_res], 1
			jz	.ReadCSW
			mov ebx, xhci_GetSenseCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ReadCSW:
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDSenseGetArrTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, [xhci_bulk_arr]
		mov ecx, [xhci_bulk_size]
		call gutil_mem_dump
		pop ecx
		pop esi
;		call gstdio_new_line
		call gutil_press_a_key
%endif
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDSenseReadCSWTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov ebp, ebx			; status_addr
			mov	eax, XHCI_CSW_LEN
			mov ebx, 1
			mov edx, 0
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
		mov [xhci_bulk_arr], ebx
			mov ecx, eax
		mov [xhci_bulk_size], ecx
			mov BYTE [xhci_bulk_dir], 1
			xor edi, edi
			mov di, [xhci_bulkin_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			cmp DWORD [xhci_res], 1
			jz	.ChkCSW
			mov ebx, xhci_RequestSenseTxt
			call gstdio_draw_text
			mov ebx, xhci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
	; IN: ECX(txtPtr), EBX(buff), xhci_curr_tag
	; OUT: EAX(0 ERR)
.ChkCSW:
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDSenseDumpCSWTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, [xhci_bulk_arr]
		mov ecx, [xhci_bulk_size]
		call gutil_mem_dump
		pop ecx
		pop esi
;		call gstdio_new_line
		call gutil_press_a_key
%endif
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDSenseCheckCSWTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov ecx, xhci_RequestSenseTxt
			call xhci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [xhci_res], 0
.Back		popad
			ret


; IN: EAX(CBW), ECX(size of bytes to receive)
; OUT: xhci_res, EBX(lbaHI), ECX(lbaLO), EDX(Sectorsize)
xhci_capacity_req:
			pushad
			push ecx
			mov ebx, eax
			mov ebp, [ebx+4]
			push ebx
			mov [xhci_curr_tag], ebp
			mov ecx, XHCI_CBW_LEN
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov ebp, ebx			; status_addr
			pop ebx
			mov BYTE [xhci_bulk_dir], 0
			xor edi, edi
			mov di, [xhci_bulkout_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			pop ecx
			cmp DWORD [xhci_res], 1
			jz	.Get
			mov ebx, xhci_SendCapCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
.Get:
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDCapacityGetTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov ebp, ebx			; status_addr
			mov	eax, ecx
			mov ebx, 1
			mov edx, 0
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
		mov [xhci_bulk_arr], ebx
			mov ecx, eax
		mov [xhci_bulk_size], ecx
			mov BYTE [xhci_bulk_dir], 1
			xor edi, edi
			mov di, [xhci_bulkin_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			cmp DWORD [xhci_res], 1
			jz	.Save
			mov ebx, xhci_GetCapCBWFailedTxt
			call gstdio_draw_text
			jmp .Err
			; save capacity
.Save		cmp ecx, 32								; ReadCap16 ?
			jz	.SaveCap16
			mov eax, [ebx]
			bswap eax								; big-endian to little endian
			mov DWORD [xhci_lbahi], 0
			mov [xhci_lbalo], eax
			add ebx, 4
			mov eax, [ebx]
			bswap eax								; big-endian to little endian
			mov [xhci_sector_size], eax
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDCapacityLBAHiTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, [xhci_lbahi]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_IMSDCapacityLBALoTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, [xhci_lbalo]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_IMSDCapacitySectorTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, [xhci_sector_size]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		call gutil_press_a_key
%endif
			jmp	.ReadCSW
.SaveCap16	mov eax, [ebx]
			bswap eax								; big-endian to little endian
			mov [xhci_lbahi], eax
			add ebx, 4
			mov eax, [ebx]
			bswap eax								; big-endian to little endian
			mov [xhci_lbalo], eax
			add ebx, 4
			mov eax, [ebx]
			bswap eax								; big-endian to little endian
			mov [xhci_sector_size], eax
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDCapacityLBAHiTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, [xhci_lbahi]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_IMSDCapacityLBALoTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, [xhci_lbalo]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_IMSDCapacitySectorTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, [xhci_sector_size]
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		call gutil_press_a_key
%endif
.ReadCSW:
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDCapacityGetArrTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, [xhci_bulk_arr]
		mov ecx, [xhci_bulk_size]
		call gutil_mem_dump
		pop ecx
		pop esi
;		call gstdio_new_line
		call gutil_press_a_key
%endif
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDCapacityReadCSWTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov ebp, ebx			; status_addr
			mov	eax, XHCI_CSW_LEN
			mov ebx, 1
			mov edx, 0
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
		mov [xhci_bulk_arr], ebx
			mov ecx, eax
		mov [xhci_bulk_size], ecx
			mov BYTE [xhci_bulk_dir], 1
			xor edi, edi
			mov di, [xhci_bulkin_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			cmp DWORD [xhci_res], 1
			jz	.ChkCSW
			mov ebx, xhci_CapacityTxt
			call gstdio_draw_text
			mov ebx, xhci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
	; IN: ECX(txtPtr), EBX(buff), xhci_curr_tag
	; OUT: EAX(0 ERR)
.ChkCSW:
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDCapacityDumpCSWTxt
		call gstdio_draw_text
		pop ebx
		push esi
		push ecx
		mov esi, [xhci_bulk_arr]
		mov ecx, [xhci_bulk_size]
		call gutil_mem_dump
		pop ecx
		pop esi
;		call gstdio_new_line
		call gutil_press_a_key
%endif
%ifdef DBGXHCI_INITMSD
		push ebx
		mov ebx, xhci_IMSDCapacityCheckCSWTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov ecx, xhci_CapacityTxt
			call xhci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [xhci_res], 0
.Back		popad
			ret


; IN: ECX(txtPtr), EBC(buff), xhci_curr_tag
; OUT: EAX(0 ERR)
xhci_check_csw:	
			mov eax, 0
			mov edx, [xhci_curr_tag]
			cmp [ebx+4], edx
			jz	.Status
			mov ebx, ecx
			call gstdio_draw_text		
			mov ebx, xhci_CSWTagMismatchTxt
			call gstdio_draw_text		
			jmp .Back
.Status		cmp BYTE [ebx+12], 0
			jz	.Ok
			mov ebx, ecx
			call gstdio_draw_text		
			mov ebx, xhci_CSWStatusFailedTxt
			call gstdio_draw_text		
			jmp .Back
.Ok			mov eax, 1
.Back		ret


; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: xhci_res
xhci_read_msd:
			pushad
%ifdef DBGXHCI_BULK_READ
		push ebx
		mov ebx, xhci_BulkRead_ReadMsdTxt
		call gstdio_draw_text
		pop ebx
		push ebx
		mov ebx, xhci_BulkRead_LBAHITxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_dec
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkRead_LBALOTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ebx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkRead_MemAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ecx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkRead_SectorsNumTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, edx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		call gutil_press_a_key
%endif
			mov DWORD [xhci_res], 0
			; check heap_ptr, if it contains its initial value, then no USBENUM was called
			cmp DWORD [xhci_cur_heap_ptr], XHCI_HEAP_INIT		;!? use _inited instead!?
			jz	.Back
			push eax
			mov al, [xhci_dev_address]
			cmp [xhci_inited_msd], al
			pop eax
			jnz	.Back
			cmp eax, [xhci_lbahi]
			jna	.ChkLO
			jmp .Err
.ChkLO		cmp ebx, [xhci_lbalo]
			jc	.Read
.Err		mov ebx, xhci_LBATooBigTxt
			call gstdio_draw_text
			jmp	.Back
.Read		cmp BYTE [xhci_device_size], XHCI_DEVICE_SMALL
			je	.Read10
			cmp BYTE [xhci_device_size], XHCI_DEVICE_MEDIUM
			je	.Read12
%ifdef DBGXHCI_BULK_READ
		push ebx
		mov ebx, xhci_BulkRead_Read16Txt
		call gstdio_draw_text
		pop ebx
%endif
			call xhci_read16_req
			jmp .Back
.Read10:
%ifdef DBGXHCI_BULK_READ
		push ebx
		mov ebx, xhci_BulkRead_Read10Txt
		call gstdio_draw_text
		pop ebx
%endif
			call xhci_read10_req
			jmp .Back
.Read12:
%ifdef DBGXHCI_BULK_READ
		push ebx
		mov ebx, xhci_BulkRead_Read12Txt
		call gstdio_draw_text
		pop ebx
%endif
			call xhci_read12_req
.Back		popad
			ret
			

; IN: EAX(lbaHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: xhci_res
xhci_write_msd:
			pushad
%ifdef DBGXHCI_BULK_WRITE
		push ebx
		mov ebx, xhci_BulkWrite_WriteMsdTxt
		call gstdio_draw_text
		pop ebx
%endif
			mov DWORD [xhci_res], 0
			; check heap_ptr, if it contains its initial value, then no USBENUM was called
			cmp DWORD [xhci_cur_heap_ptr], XHCI_HEAP_INIT
			jz	.Back
			push eax
			mov al, [xhci_dev_address]
			cmp [xhci_inited_msd], al
			pop eax
			jnz	.Back
			cmp eax, [xhci_lbahi]
			jna	.ChkLO
			jmp .Err
.ChkLO		cmp ebx, [xhci_lbalo]
			jc	.Write
.Err		mov ebx, xhci_LBATooBigTxt
			call gstdio_draw_text
			jmp	.Back
.Write		cmp BYTE [xhci_device_size], XHCI_DEVICE_SMALL
			je	.Write10
			cmp BYTE [xhci_device_size], XHCI_DEVICE_MEDIUM
			je	.Write12
%ifdef DBGXHCI_BULK_WRITE
		push ebx
		mov ebx, xhci_BulkWrite_Write16Txt
		call gstdio_draw_text
		pop ebx
%endif
			call xhci_write16_req
			jmp .Back
.Write10:
%ifdef DBGXHCI_BULK_WRITE
		push ebx
		mov ebx, xhci_BulkWrite_Write10Txt
		call gstdio_draw_text
		pop ebx
%endif
			call xhci_write10_req
			jmp .Back
.Write12:
%ifdef DBGXHCI_BULK_WRITE
		push ebx
		mov ebx, xhci_BulkWrite_Write12Txt
		call gstdio_draw_text
		pop ebx
%endif
			call xhci_write12_req
.Back		popad
			ret
			


; ************* END OF WORDS


; **** SCSI

; IN: EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: xhci_res
; 32bit LBA: 4GB * 512 bytes can be addressed (2048 GB)
; 16bit sectornum: 65535*512 bytes can be read at a time (32 MB)
xhci_read10_req:
			pushad
%ifdef DBGXHCI_BULK_READ
		push ebx
		mov ebx, xhci_BulkRead_Read10_SubTxt
		call gstdio_draw_text
		mov ebx, xhci_BulkRead_LBALOTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ebx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkRead_MemAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ecx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkRead_SectorsNumTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_hex
		call gstdio_new_line
		call gutil_press_a_key
%endif
			call xhci_align_topage	
	inc DWORD [scsi_read10_cbw+4]				; inc TAG
			mov esi, scsi_read10_cbw
			mov ebp, [esi+4]
			mov [xhci_curr_tag], ebp
			add esi, USB_CBW_COMMAND_OFFS
			add esi, 2
			bswap ebx							; to big-endian
			mov [esi], ebx
			add esi, 5
			mov bx, dx
			xchg bl, bh							; to big-endian
			mov [esi], bx
			mov esi, scsi_read10_cbw
			add esi, USB_CBW_TOTALBYTES_OFFS
			xor eax, eax
			mov ax, dx
			mov ebx, [xhci_sector_size]
			mul ebx
			mov [esi], eax			
			mov ebx, eax
			mov eax, scsi_read10_cbw
			mov ebp, xhci_read10_msgs
			call xhci_read_common
			popad
			ret


; IN: EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: xhci_res
; 32bit LBA: 4GB * 512 bytes can be addressed (2048 GB)
; 32bit sectornum: 4GB*512 bytes can be read at a time (2048 GB)
xhci_read12_req:
			pushad
%ifdef DBGXHCI_BULK_READ
		push ebx
		mov ebx, xhci_BulkRead_Read12_SubTxt
		call gstdio_draw_text
		mov ebx, xhci_BulkRead_LBALOTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ebx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkRead_MemAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ecx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkRead_SectorsNumTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_hex
		call gstdio_new_line
		call gutil_press_a_key
%endif
			call xhci_align_topage
	inc DWORD [scsi_read12_cbw+4]		; inc TAG
			mov esi, scsi_read12_cbw
			mov ebp, [esi+4]
			mov [xhci_curr_tag], ebp
			add esi, USB_CBW_COMMAND_OFFS
			add esi, 2
			bswap ebx							; to big-endian
			mov [esi], ebx
			add esi, 4
			mov ebx, edx
			bswap ebx							; to big-endian
			mov [esi], ebx
			mov esi, scsi_read12_cbw
			add esi, USB_CBW_TOTALBYTES_OFFS
			mov eax, edx
			mov ebx, [xhci_sector_size]
			mul ebx
			mov [esi], eax			
			mov ebx, eax
			mov eax, scsi_read12_cbw
			mov ebp, xhci_read12_msgs
			call xhci_read_common
			popad
			ret


; IN: EAX(LBAHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: xhci_res
xhci_read16_req:
			pushad
%ifdef DBGXHCI_BULK_READ
		push ebx
		mov ebx, xhci_BulkRead_Read16_SubTxt
		call gstdio_draw_text
		mov ebx, xhci_BulkRead_LBALOTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ebx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkRead_MemAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ecx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkRead_SectorsNumTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_hex
		call gstdio_new_line
		call gutil_press_a_key
%endif
			call xhci_align_topage
	inc DWORD [scsi_read16_cbw+4]		; inc TAG
			mov esi, scsi_read16_cbw
			mov ebp, [esi+4]
			mov [xhci_curr_tag], ebp
			add esi, USB_CBW_COMMAND_OFFS
			add esi, 2
			bswap eax							; to big-endian
			mov [esi], eax
			add esi, 4
			bswap ebx							; to big-endian
			mov [esi], ebx
			add esi, 4
			mov ebx, edx
			bswap ebx							; to big-endian
			mov [esi], ebx
			mov esi, scsi_read16_cbw
			add esi, USB_CBW_TOTALBYTES_OFFS
			mov eax, edx
			mov ebx, [xhci_sector_size]
			mul ebx
			mov [esi], eax			
			mov ebx, eax
			mov eax, scsi_read16_cbw
			mov ebp, xhci_read16_msgs
			call xhci_read_common
			popad
			ret


; IN: EAX(ptr to address); EBX(number of bytes to read); ECX(memaddr); EBP(ptr to message-array)
; OUT: xhci_res
xhci_read_common:
%ifdef DBGXHCI_BULK_READ
		push ebx
		mov ebx, xhci_BulkRead_ReadCommonTxt
		call gstdio_draw_text
		mov ebx, xhci_BulkRead_PtrToAddrTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_dec
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkRead_NumBytesTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ebx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkRead_MemAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ecx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkRead_PtrToMsgArrTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov esi, ebx			; ESI is #bytesToRead
			mov edi, ecx			; EDI is memaddr
			mov ebx, eax
			mov edx, [ebx+4]
			push ebx
			mov [xhci_curr_tag], edx
			mov ecx, XHCI_CBW_LEN
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov eax, ebp
			mov ebp, ebx			; status_addr
			pop ebx
			mov BYTE [xhci_bulk_dir], 0
			push edi
			xor edi, edi
			mov di, [xhci_bulkout_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			pop edi
			mov ebp, eax
			cmp DWORD [xhci_res], 1
			jz	.Get
			mov ebx, [ebp]
			call gstdio_draw_text
			jmp .Err
.Get		mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			push ebp
			mov ebp, ebx			; status_addr
			mov ebx, edi
		mov [xhci_bulk_arr], ebx
			mov ecx, esi
		mov [xhci_bulk_size], ecx
			mov BYTE [xhci_bulk_dir], 1
			xor edi, edi
			mov di, [xhci_bulkin_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			pop ebp
			cmp DWORD [xhci_res], 1
			jz	.ReadCSW
			mov ebx, [ebp+4]
			call gstdio_draw_text
			jmp .Err
.ReadCSW	mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			push ebp
			mov ebp, ebx			; status_addr
			mov	eax, XHCI_CSW_LEN
			mov ebx, 1
			mov edx, 0
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
		mov [xhci_bulk_arr], ebx
			mov ecx, eax
		mov [xhci_bulk_size], ecx
			mov BYTE [xhci_bulk_dir], 1
			xor edi, edi
			mov di, [xhci_bulkin_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			pop ebp
			cmp DWORD [xhci_res], 1
			jz	.ChkCSW
			mov ebx, [ebp+8]
			call gstdio_draw_text
			mov ebx, xhci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ChkCSW		mov ecx, [ebp+8]
			call xhci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [xhci_res], 0
.Back		ret


; IN: EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: xhci_res
; 32bit EBX: 4GB * 512 bytes can be addressed (2048 GB)
; 65535*512 bytes can be written at a time (32 MB)
xhci_write10_req:
			pushad
%ifdef DBGXHCI_BULK_WRITE
		push ebx
		mov ebx, xhci_BulkWrite_Write10_SubTxt
		call gstdio_draw_text
		mov ebx, xhci_BulkWrite_LBALOTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ebx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkWrite_MemAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ecx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkWrite_SectorsNumTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_hex
		call gstdio_new_line
		call gutil_press_a_key
%endif
			call xhci_align_topage
			mov esi, scsi_write10_cbw
			mov ebp, [esi+4]
			mov [xhci_curr_tag], ebp
			add esi, USB_CBW_COMMAND_OFFS
			add esi, 2
			bswap ebx							; to big-endian
			mov [esi], ebx
			add esi, 5
			mov bx, dx
			xchg bl, bh							; to big-endian
			mov [esi], bx
			mov esi, scsi_write10_cbw
			add esi, USB_CBW_TOTALBYTES_OFFS
			xor eax, eax
			mov ax, dx
			mov ebx, [xhci_sector_size]
			mul ebx
			mov [esi], eax			
			mov ebx, eax
			mov eax, scsi_write10_cbw
			mov ebp, xhci_write10_msgs
			call xhci_write_common
			popad
			ret


; IN: EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: xhci_res
xhci_write12_req:
			pushad
%ifdef DBGXHCI_BULK_WRITE
		push ebx
		mov ebx, xhci_BulkWrite_Write12_SubTxt
		call gstdio_draw_text
		mov ebx, xhci_BulkWrite_LBALOTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ebx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkWrite_MemAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ecx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkWrite_SectorsNumTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_hex
		call gstdio_new_line
		call gutil_press_a_key
%endif
			call xhci_align_topage
			mov esi, scsi_write12_cbw
			mov ebp, [esi+4]
			mov [xhci_curr_tag], ebp
			add esi, USB_CBW_COMMAND_OFFS
			add esi, 2
			bswap ebx							; to big-endian
			mov [esi], ebx
			add esi, 4
			mov ebx, edx
			bswap ebx							; to big-endian
			mov [esi], ebx
			mov esi, scsi_write12_cbw
			add esi, USB_CBW_TOTALBYTES_OFFS
			xor eax, eax
			mov ax, dx
			mov ebx, [xhci_sector_size]
			mul ebx
			mov [esi], eax			
			mov ebx, eax
			mov eax, scsi_write12_cbw
			mov ebp, xhci_write12_msgs
			call xhci_write_common
			popad
			ret


; IN: EAX(LBAHI), EBX(LBALO), ECX(memaddr), EDX(number of sectors)
; OUT: xhci_res
xhci_write16_req:
			pushad
%ifdef DBGXHCI_BULK_WRITE
		push ebx
		mov ebx, xhci_BulkWrite_Write16_SubTxt
		call gstdio_draw_text
		mov ebx, xhci_BulkWrite_LBALOTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ebx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkWrite_MemAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ecx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkWrite_SectorsNumTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_hex
		call gstdio_new_line
		call gutil_press_a_key
%endif
			call xhci_align_topage
			mov esi, scsi_write16_cbw
			mov ebp, [esi+4]
			mov [xhci_curr_tag], ebp
			add esi, USB_CBW_COMMAND_OFFS
			add esi, 2
			bswap eax							; to big-endian
			mov [esi], eax
			add esi, 4
			bswap ebx							; to big-endian
			mov [esi], ebx
			add esi, 4
			mov ebx, edx
			bswap ebx							; to big-endian
			mov [esi], ebx
			mov esi, scsi_write16_cbw
			add esi, USB_CBW_TOTALBYTES_OFFS
			mov eax, edx
			mov ebx, [xhci_sector_size]
			mul ebx
			mov [esi], eax			
			mov ebx, eax
			mov eax, scsi_write16_cbw
			mov ebp, xhci_write16_msgs
			call xhci_write_common
			popad
			ret

; IN: EAX(ptr to address); EBX(number of bytes to write); ECX(memaddr); EBP(ptr to message-array)
; OUT: xhci_res
xhci_write_common:
%ifdef DBGXHCI_BULK_WRITE
		push ebx
		mov ebx, xhci_BulkWrite_WriteCommonTxt
		call gstdio_draw_text
		mov ebx, xhci_BulkWrite_PtrToAddrTxt
		call gstdio_draw_text
		pop ebx
		call gstdio_draw_dec
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkWrite_NumBytesTxt
		call gstdio_draw_text
		pop ebx
		push eax
		mov eax, ebx
		call gstdio_draw_dec
		pop eax
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkWrite_MemAddrTxt
		call gstdio_draw_text
		pop ebx
		push edx
		mov edx, ecx
		call gstdio_draw_hex
		pop edx
		call gstdio_new_line
		push ebx
		mov ebx, xhci_BulkWrite_PtrToMsgArrTxt
		call gstdio_draw_text
		pop ebx
		call gutil_press_a_key
%endif
			mov esi, ebx			; ESI is #bytesToWrite
			mov edi, ecx			; EDI is memaddr
			mov ebx, eax
			mov edx, [ebx+4]
			push ebx
			mov [xhci_curr_tag], edx
			mov ecx, XHCI_CBW_LEN
			mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			mov eax, ebp
			mov ebp, ebx			; status_addr
			pop ebx
			mov BYTE [xhci_bulk_dir], 0
			push edi
			xor edi, edi
			mov di, [xhci_bulkout_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			pop edi
			mov ebp, eax
			cmp DWORD [xhci_res], 1
			jz	.Send
			mov ebx, [ebp]
			call gstdio_draw_text
			jmp .Err
.Send		mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			push ebp
			mov ebp, ebx			; status_addr
			mov ebx, edi
		mov [xhci_bulk_arr], ebx
			mov ecx, esi
		mov [xhci_bulk_size], ecx
			mov BYTE [xhci_bulk_dir], 0
			xor edi, edi
			mov di, [xhci_bulkin_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			pop ebp
			cmp DWORD [xhci_res], 1
			jz	.ReadCSW
			mov ebx, [ebp+4]
			call gstdio_draw_text
			jmp .Err
.ReadCSW	mov	eax, 4
			mov ebx, 16
			mov edx, 16
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc	; we need a dword status buffer with a physical address
			push ebp
			mov ebp, ebx			; status_addr
			mov	eax, XHCI_CSW_LEN
			mov ebx, 1
			mov edx, 0
	; IN: EAX(size), EBX(alignment), EDX(boundary)
	; OUT: EBX (memaddr 32bit)
			call xhci_heap_alloc
		mov [xhci_bulk_arr], ebx
			mov ecx, eax
		mov [xhci_bulk_size], ecx
			mov BYTE [xhci_bulk_dir], 1
			xor edi, edi
			mov di, [xhci_bulkin_mps]
	; IN: xhci_bulk_dir(byte), EBX(addr); ECX(size); EBP(status_addr); EDI(max_packet)
		; xhci_cur_bulkout/in_ep_ring_cycle; xhci_cur_bulkout/in_ep_ring_ptr
	; OUT: xhci_res, xhci_trbs_num
			call xhci_bulk_io
			pop ebp
			cmp DWORD [xhci_res], 1
			jz	.ChkCSW
			mov ebx, [ebp+8]
			call gstdio_draw_text
			mov ebx, xhci_GetCSWFailedTxt
			call gstdio_draw_text
			jmp .Err
.ChkCSW		mov ecx, [ebp+8]
			call xhci_check_csw
			cmp eax, 1
			jz	.Back
.Err		mov DWORD [xhci_res], 0
.Back		ret


; IN: ECX(memaddr) ; in bulk transfers the memaddr need to begin on page boundary (last 3 digits are zero)
; OUT: ECX(aligned memaddr)
xhci_align_topage:
			push ebx
			mov ebx, ecx
			and ebx, 0x00000FFF
			jz	.Back
			and ecx, 0xFFFFF000
			add ecx, 0x1000
.Back		pop ebx
			ret


section .data

%ifndef USB_XHCI_IRQ_DEF
	xhci_bus	db 0
	xhci_dev	db 0
	xhci_fun	db 0
%endif

; TRB-struct
;%define	XHCI_TRB_PARAM_OFFS		0
;%define	XHCI_TRB_STATUS_OFFS	8
;%define	XHCI_TRB_COMMAND_OFFS	12

;%define	XHCI_TRB_SIZE		16 ; in bytes
xhci_trb_param		dd	0
					dd	0
xhci_trb_status		dd	0
xhci_trb_command	dd	0

xhci_trb_event_param		dd	0
							dd	0
xhci_trb_event_status		dd	0
xhci_trb_event_command		dd	0

xhci_trb_org_param		dd	0
						dd	0
xhci_trb_org_status		dd	0
xhci_trb_org_command	dd	0

xhci_port_info times (XHCI_MAX_PORT_INFO_NUM*XHCI_PORT_INFO_SIZE)	db	0
; end of Port-Info-struct

xhci_base0			dd	0
xhci_base_bits4		dd	0	; LUNT page 2-8: bits2:1=00 the address is <4GB; bits2:1=01 it is <1MB; bits2:1=10 it is 64bits (get the high 32bits of the address from next base address field of the PCI); bit3 is reserved

xhci_op_base_off	dd	0

xhci_hccparams1		dd	0
xhci_hccparams2		dd	0
xhci_hcsparams1		dd	0
xhci_hcsparams2		dd	0
xhci_rts_offset		dd	0
xhci_db_offset		dd	0

xhci_ext_caps_off	dd	0
xhci_context_size	dd	0

xhci_ndp			dd	0

xhci_ports_usb2		dd	0
xhci_ports_usb3		dd	0

xhci_page_size		dd	0

; command ring
xhci_cmnd_ring_addr		dd	0
xhci_cmnd_trb_addr		dd	0
xhci_cmnd_trb_cycle		dd	0

xhci_org_trb_addr		dd	0	

xhci_max_event_segs		dd	0
xhci_max_interrupters	dd	0

; event ring
xhci_cur_event_ring_addr	dd	0
xhci_cur_event_ring_cycle	dd	0

xhci_dcbaap_start	dd	0

xhci_cur_ep_ring_ptr	dd	0
xhci_cur_ep_ring_cycle	db	0

xhci_cur_heap_ptr			dd	XHCI_HEAP_INIT
xhci_cur_heap_ptr_afterenum	dd 0
xhci_cur_heap_ptr_saved		dd 0

xhci_res		dd	0
xhci_res_tmp	dd	0

xhci_control_dest_buff_addr	dd 0

; device descriptor request
xhci_req_dev_desc_packet	db	USB_STDRD_GET_REQUEST, USB_DEVREQ_GET_DESCRIPTOR, 
							dw	(USB_DESCTYP_DEVICE << 8), 0, 0

; string descriptor request
xhci_req_langs_packet	db	0x80, 0x06, 
						dw	0x0300, 0x0000, 0 	;0xFF	; we request just 18 bytes of the langids-desc 

xhci_req_config_packet	db	0x80, 0x06, 
						dw	0x0200, 0x0000, 0

xhci_req_lun_packet		db	0xA1, 0xFE, 
						dw	0x0000, 0, 0x0001	; intnum is interface number from interface descriptor (second word from the end)

xhci_set_config_packet	db	0, 9, 
						dw	1, 0, 0

xhci_req_desc_packet	dd 0							; ptr to request packet

; BOS-descriptor request
xhci_req_bos_desc_packet	db	USB_STDRD_GET_REQUEST, USB_DEVREQ_GET_DESCRIPTOR, 
							dw	(USB_DESCTYP_BOS << 8), 0, 0

xhci_req_bulkreset_packet		db	0x21, 0xFF,
								dw	0, 0, 0

xhci_req_bulkendptreset_packet	db	0x02, 0x01,
								dw	0, 0, 0		; the 0 (word) in the middle is either BulkIn or BulkOut

xhci_trbs_num	dd	0

xhci_langid		dw  0

xhci_scratch_buff_array_start	dd 0
xhci_scratch_buff_start			dd 0
xhci_max_scratch_buffs			dd 0			

xhci_max_slots	db	0
xhci_port_num	db	0
xhci_slot_addr 	dd	0
xhci_max_packet	dd	0
xhci_speed		dd	0
xhci_slot_id	dd	0

xhci_dir 		db 0	; direction of data transfer: in(1, Device-To-Host) or out(0, Host-To-Device)

xhci_dev_address	db	0
xhci_max_lun		db	0
;xhci_bulk_mps		dw	0	
xhci_bulkin_mps		dw	0	
xhci_bulkout_mps	dw	0	
;xhci_bulk_endpt		db	0
xhci_bulkout_endpt	db	0
xhci_bulkin_endpt	db	0
xhci_cur_bulkin_ep_ring_ptr	dd 0
xhci_cur_bulkin_ep_ring_cycle dd 0
xhci_cur_bulkout_ep_ring_ptr dd 0
xhci_cur_bulkout_ep_ring_cycle dd 0
xhci_bulk_dir		db	0				; 0:out

xhci_bulk_arr		dd 0
xhci_bulk_size		dd 0

xhci_device_size	db	0
xhci_lbahi			dd	0
xhci_lbalo			dd	0
xhci_sector_size	dd	0
xhci_inited_msd		db	0xFF
xhci_curr_tag		dd	0		; CSW's tag

xhci_read10_msgs	dd xhci_SendRead10CBWFailedTxt, xhci_GetRead10DataFailedTxt, xhci_Read10Txt
xhci_read12_msgs	dd xhci_SendRead12CBWFailedTxt, xhci_GetRead12DataFailedTxt, xhci_Read12Txt
xhci_read16_msgs	dd xhci_SendRead16CBWFailedTxt, xhci_GetRead16DataFailedTxt, xhci_Read16Txt

xhci_write10_msgs	dd xhci_SendWrite10CBWFailedTxt, xhci_SendWrite10DataFailedTxt, xhci_Write10Txt
xhci_write12_msgs	dd xhci_SendWrite12CBWFailedTxt, xhci_SendWrite12DataFailedTxt, xhci_Write12Txt
xhci_write16_msgs	dd xhci_SendWrite16CBWFailedTxt, xhci_SendWrite16DataFailedTxt, xhci_Write16Txt


; There are three rings in XHCI (Command, EP's Transfer, Event)
; Command is one for the xHC, and Event is one per Interrupter, but "EP's Transfer" belongs to the EndPoint, so it is device-dependent.
; The EP's transfer ring (i.e. [xhci_cur_ep_ring_ptr]) is a global pointer in the code (also [xhci_cur_ep_cycle]), 
; so if there are several devices found by USBENUM, [xhci_cur_ep_ring_ptr] will contain the EP-ptr of the last device.
; xhci_dev_info retrieves the DeviceDescriptor for the given device, so it needs [xhci_cur_ep_ring_ptr] set to the 
; EP-ptr of the given device. That's why we need to save the value of [xhci_cur_ep_ring_ptr] to an array according to slotID.
; The EP-ring ptr of the given device will be filled from this array according to the slotID.
; Unfortunately the EP's transfer-ring-ptr (i.e. [ep_context_tr_dequeue_ptr_LO] of the EP-context) contains the initial value, 
;	so we can't get the last value of the [xhcicur_ep_ring_ptr] from there.
; !? Other way: there is a "Set TR Dequeue Pointer" command in the XCHI-specs, with which we could write a new value to the EP's ring-ptr.
;	Would it work!?
xhci_cur_ep_ring_ptr_arr	times XHCI_MAX_DEV_CNT dd 0
xhci_cur_ep_ring_cycle_arr	times XHCI_MAX_DEV_CNT db 0

xhci_slot_context:
xhci_slot_context_entries		dd	0
xhci_slot_context_hub			db	0
xhci_slot_context_mtt			db	0
xhci_slot_context_speed			dd	0
xhci_slot_context_route_str		dd	0
xhci_slot_context_num_ports		dd	0
xhci_slot_context_rh_port_num	dd	0
xhci_slot_context_max_exit_lat	dd	0
xhci_slot_context_int_target	dd	0
xhci_slot_context_ttt			dd	0
xhci_slot_context_tt_port_num	dd	0
xhci_slot_context_tt_hub_slotid	dd	0
xhci_slot_context_slot_state	dd	0
xhci_slot_context_device_addr	dd	0
XHCI_SLOT_CONTEXT_SIZE equ ($-xhci_slot_context)

xhci_slot_context2:
xhci_slot_context_entries2			dd	0
xhci_slot_context_hub2				db	0
xhci_slot_context_mtt2				db	0
xhci_slot_context_speed2			dd	0
xhci_slot_context_route_str2		dd	0
xhci_slot_context_num_ports2		dd	0
xhci_slot_context_rh_port_num2		dd	0
xhci_slot_context_max_exit_lat2		dd	0
xhci_slot_context_int_target2		dd	0
xhci_slot_context_ttt2				dd	0
xhci_slot_context_tt_port_num2		dd	0
xhci_slot_context_tt_hub_slotid2	dd	0
xhci_slot_context_slot_state2		dd	0
xhci_slot_context_device_addr2		dd	0
XHCI_SLOT_CONTEXT_SIZE equ ($-xhci_slot_context2)

xhci_ep_context:
xhci_ep_context_interval			dd	0
xhci_ep_context_lsa					db	0
xhci_ep_context_max_pstreams		dd	0
xhci_ep_context_mult				dd	0
xhci_ep_context_ep_state			dd	0
xhci_ep_context_max_packet_size		dd	0
xhci_ep_context_max_burst_size		dd	0
xhci_ep_context_hid					db	0
xhci_ep_context_ep_type				dd	0
xhci_ep_context_cerr				dd	0
xhci_ep_context_tr_dequeue_ptr_LO	dd	0
xhci_ep_context_tr_dequeue_ptr_HI	dd	0
xhci_ep_context_dcs					db	0
xhci_ep_context_max_esit_payload	dd	0
xhci_ep_context_max_average_trb_len	dd	0
XHCI_EP_CONTEXT_SIZE equ ($-xhci_ep_context)

xhci_ep_context2:
xhci_ep_context_interval2				dd	0
xhci_ep_context_lsa2					db	0
xhci_ep_context_max_pstreams2			dd	0
xhci_ep_context_mult2					dd	0
xhci_ep_context_ep_state2				dd	0
xhci_ep_context_max_packet_size2		dd	0
xhci_ep_context_max_burst_size2			dd	0
xhci_ep_context_hid2					db	0
xhci_ep_context_ep_type2				dd	0
xhci_ep_context_cerr2					dd	0
xhci_ep_context_tr_dequeue_ptr_LO2		dd	0
xhci_ep_context_tr_dequeue_ptr_HI2		dd	0
xhci_ep_context_dcs2					db	0
xhci_ep_context_max_esit_payload2		dd	0
xhci_ep_context_max_average_trb_len2	dd	0
XHCI_EP_CONTEXT_SIZE equ ($-xhci_ep_context2)

xhci_tr_ring_segments 		times MAX_SEGMENT_CNT_PER_TR_RING dd 0
xhci_tr_ring_segment_cnts	times MAX_SEGMENT_CNT_PER_TR_RING dd 0

xhci_FndXHCICtrlTxt				db 0x0A, "Found XHCI controller ", 0
xhci_StringPortDevAddrTxt		db " String (Port, DeviceAddress)", 0x0A, 0
xhci_64bitBase0Txt				db "Base0 is 64-bits (32bit OS)", 0x0A, 0
xhci_NotMemMappedIOTxt			db "Not memory mapped IO", 0x0A, 0
xhci_resetCtrllerTOTxt			db " Resetting the controller failed (TO)", 0x0A, 0
xhci_BIOSDidntRelLegacyTxt		db " BIOS did not release Legacy support...", 0x0A, 0
xhci_FndRootHubPortsTxt			db 0x0A, "Found (virtual) root hub ports: ", 0
xhci_RootHubPortNumGreaterTxt	db "Root-hub port-num >= allocated port_num array", 0x0A, 0
xhci_ErrHeapLimitReachedTxt		db "Error: heap-limit reached", 0x0A, 0
xhci_resetPortTOTxt				db " Resetting port timed out", 0x0A, 0
xhci_GetDescUSB3Txt				db "getting descriptor on USB3 port: ", 0
xhci_GetDescUSB2Txt				db "getting descriptor on USB2 port: ", 0
xhci_CommandIntTOTxt			db " USB xHCI Command Interrupt wait TO", 0x0A, 0
xhci_CommandIntTOPollTxt		db " USB xHCI Command Interrupt wait TO (Polling)", 0x0A, 0
xhci_InterruptTOTxt				db " USB xHCI Interrupt wait TO", 0x0A, 0
xhci_InterruptStatTxt			db " USB xHCI Interrupt Status=", 0x0A, 0
xhci_ControlTransferFailedDevDesc8Txt	db "Control transfer failed (DevDesc8)", 0x0A, 0
xhci_ControlTransferFailedDevDescAllTxt	db "Control transfer failed (DevDescAll)", 0x0A, 0
xhci_ControlTransferFailedLangIDsTxt	db "Control transfer failed (LangIds)", 0x0A, 0
xhci_ControlTransferFailedManufactTxt	db "Control transfer failed (Manufacturer)", 0x0A, 0
xhci_ControlTransferFailedProductTxt	db "Control transfer failed (Product)", 0x0A, 0
xhci_NoStringTxt				db "None", 0
xhci_SeparatorTxt				db " - ", 0
xhci_SetAddressFailedTxt		db "Setting address failed", 0x0A, 0
xhci_DevDesc8Txt				db "Device descriptor(8):", 0x0A, 0
xhci_DevDescTxt					db "Device descriptor:", 0x0A, 0
xhci_MaxPacketDiffTxt			db "max_packet is different!", 0x0A, 0
xhci_GettingDevDescriptorTxt	db " Getting Device-descriptor ...", 0x0A, 0
xhci_GettingBOSDescriptorTxt	db " Getting BOS-descriptor ...", 0x0A, 0
xhci_GettingConfigDescTxt		db " Getting Configuration-descriptor ...", 0x0A, 0
xhci_BOSDescTxt					db "BOS descriptor:", 0x0A, 0
xhci_ConfigDescTxt				db "Configuration-descriptor:", 0x0A, 0
xhci_GettingLUNTxt				db " Getting LUN ...", 0x0A, 0
xhci_ControlTransferFailedBOSTxt			db "Control transfer failed (BOS)", 0x0A, 0
xhci_ControlTransferFailedConfigDescTxt		db "Control transfer failed (Config)", 0x0A, 0
xhci_ControlTransferFailedConfigDesc2Txt	db "Control transfer failed (Config2)", 0x0A, 0
xhci_ControlTransferFailedLUNTxt	db "Control transfer failed (LUN)", 0x0A, 0
xhci_MaxLunTxt				db "MaxLun: ", 0
xhci_EndptsErrTxt			db "Not enough endpoints", 0x0A, 0
xhci_SetControlTransferFailedSetConfigTxt	db "Control transfer failed (Set Config (device))", 0x0A, 0

xhci_ConfigureEPFailedTxt	db "Configure Endpoint failed", 0x0A, 0

; bulk
xhci_SendTestUnitCBWFailedTxt	db "Sending testunit CBW failed", 0x0A, 0
xhci_SendSenseCBWFailedTxt		db "Sending sense CBW failed", 0x0A, 0
xhci_SendInquiryCBWFailedTxt	db "Sending inquiry CBW failed", 0x0A, 0
xhci_GetInquiryCBWFailedTxt		db "Getting inquiry CBW failed", 0x0A, 0
xhci_GetSenseCBWFailedTxt		db "Getting sense CBW failed", 0x0A, 0
xhci_SendCapCBWFailedTxt		db "Sending capacity CBW failed", 0x0A, 0
xhci_GetCapCBWFailedTxt			db "Getting capacity CBW failed", 0x0A, 0
xhci_GetCSWFailedTxt			db "Getting CSW failed", 0x0A, 0
xhci_BulkResetFailedTxt			db "Bulk reset failed", 0x0A, 0
xhci_BulkE1ResetFailedTxt		db "Bulk endpoint 1 reset failed", 0x0A, 0
xhci_BulkE2ResetFailedTxt		db "Bulk endpoint 2 reset failed", 0x0A, 0
xhci_SendRead10CBWFailedTxt		db "Sending read10 CBW failed", 0x0A, 0
xhci_GetRead10DataFailedTxt		db "Getting read10 data failed", 0x0A, 0
xhci_SendRead12CBWFailedTxt		db "Sending read12 CBW failed", 0x0A, 0
xhci_GetRead12DataFailedTxt		db "Getting read12 data failed", 0x0A, 0
xhci_SendRead16CBWFailedTxt		db "Sending read16 CBW failed", 0x0A, 0
xhci_GetRead16DataFailedTxt		db "Getting read16 data failed", 0x0A, 0
xhci_SendWrite10CBWFailedTxt	db "Sending write10 CBW failed", 0x0A, 0
xhci_SendWrite10DataFailedTxt	db "Sending write10 data failed", 0x0A, 0
xhci_SendWrite12CBWFailedTxt	db "Sending write12 CBW failed", 0x0A, 0
xhci_SendWrite12DataFailedTxt	db "Sending write12 data failed", 0x0A, 0
xhci_SendWrite16CBWFailedTxt	db "Sending write16 CBW failed", 0x0A, 0
xhci_SendWrite16DataFailedTxt	db "Sending write16 data failed", 0x0A, 0
xhci_LBATooBigTxt			db "LBA too big", 0x0A, 0
xhci_CSWTagMismatchTxt		db "CSW tag mismatch", 0x0A, 0
xhci_CSWStatusFailedTxt		db "CSW-Status failed", 0x0A, 0

xhci_InquiryTxt				db "Inquiry: ", 0
xhci_TestUnitReadyTxt		db "TestUnitReady: ", 0
xhci_RequestSenseTxt		db "RequestSense: ", 0
xhci_CapacityTxt			db "Capacity: ", 0
xhci_Read10Txt				db "Read10: ", 0
xhci_Read12Txt				db "Read12: ", 0
xhci_Read16Txt				db "Read16: ", 0
xhci_Write10Txt				db "Write10: ", 0
xhci_Write12Txt				db "Write12: ", 0
xhci_Write16Txt				db "Write16: ", 0

;Debug
%ifdef DBGXHCI_INIT
	xhci_Base0Txt		db "base0=", 0
	xhci_VersionTxt		db "version=", 0
	xhci_OpbaseTxt		db "opbase=", 0
	xhci_ValidCtrlTxt	db "controller is valid", 0x0A, 0
	xhci_HCCParams1Txt	db "[xhci_hccparams1]=", 0
	xhci_HCCParams2Txt	db "[xhci_hccparams2]=", 0
	xhci_HCSParams1Txt	db "[xhci_hcsparams1]=", 0
	xhci_HCSParams2Txt	db "[xhci_hcsparams2]=", 0
	xhci_RTSOffsTxt		db "[xhci_rts_offset]=", 0
	xhci_DBOffsTxt		db "[xhci_db_offset]=", 0
	xhci_ExtCapsOffsTxt	db "[xhci_ext_caps_off]=", 0
	xhci_ExtCapsTxt		db 0x0A, "Extended capabilities:", 0x0A, 0
	xhci_ContextSizeTxt	db "***********[xhci_context_size]=", 0
	xhci_NoLegacyTxt	db "no legacy-support in extcaps", 0x0A, 0
	xhci_PageSizeTxt	db "[xhci_page_size]=", 0
	xhci_MaxSlotsTxt	db "max slots=", 0
	xhci_DCBAAPStartTxt	db "[xhci_dcbaap_start]=", 0
	xhci_MaxScratchpadBuffsTxt		 db "[xhci_max_scratch_buffs]=", 0
	xhci_ScratchpadBuffArrayStartTxt db "[xhci_scratch_buff_array_start]=", 0
	xhci_ScratchpadBuffStartTxt		 db "[xhci_scratch_buff_start]=", 0
	xhci_ScratchpadBuffStartIdxTxt	 db "[xhci_scratch_buff_start]+i=", 0
	xhci_CmdRingTRBAddrTxt		db "[xhci_cmnd_ring_addr]=[xhci_cmnd_trb_addr]=", 0
	xhci_MaxEventSegsTxt		db "max event segments=", 0
	xhci_MaxInterruptersTxt		db "max interrupters=", 0
	xhci_CurEventRingAddrTxt	db "[xhci_cur_event_ring_addr]=", 0
	xhci_EventRingAddrTxt		db "[event_ring_addr]=", 0
	xhci_StartIntTxt	db "starting the interrupter", 0x0A, 0
	xhci_IRQLineTxt		db "***IRQ line=***", 0
%endif

%ifdef DBGXHCI_TR_RING_INIT
	xhci_CreateTRRingTxt			db "***xhci_create_ring***: ", 0
	xhci_CreateTRRingQRTxt			db "quotient, remainder: ", 0
	xhci_CreateTRRingQRAdjustedTxt	db "adjusted quotient, remainder: ", 0
	xhci_CreateTRRingSegAddrTxt		db "HeapAlloc(SegAddr)=", 0
	xhci_CreateTRRingSegAddrRemTxt	db "HeapAlloc(SegAddr)(Rem)=", 0
	xhci_TRRingSegsTxt				db "segs: ", 0
	xhci_TRRingCntsTxt				db "cnts: ", 0
	xhci_TRRingBefNextLNKTxt		db "Before NextLNK", 0x0A, 0
	xhci_TRRingBefLastLNKTxt		db "Before LastLNK", 0x0A, 0
	xhci_TRRingDestValueTxt			db "dest, value= ", 0
%endif

%ifdef DBGXHCI_PORTINFO
	xhci_ExtCapsRegsTxt			db "ExtendedCapsRegs loop:", 0
	xhci_PortInfoUSB2Txt		db "port_info(after USB2):", 0x0A, 0
	xhci_PortsUSB2Txt			db "xhci_ports_usb2=", 0
	xhci_PortInfoUSB2CntTxt		db "USB2-proto (cnt):", 0
	xhci_PortInfoUSB2OffsTxt	db "USB2-proto (offset):", 0
	xhci_PortInfoUSB2FlagsTxt	db "USB2-proto (flags):", 0
	xhci_PortInfoUSB2NextTxt	db "USB3-proto (next):", 0
	xhci_PortInfoUSB3Txt		db "port_info(after USB3):", 0x0A, 0
	xhci_PortsUSB3Txt			db "xhci_ports_usb3=", 0
	xhci_PortInfoUSB3CntTxt		db "USB3-proto (cnt):", 0
	xhci_PortInfoUSB3OffsTxt	db "USB3-proto (offset):", 0
	xhci_PortInfoUSB3NextTxt	db "USB3-proto (next):", 0
	xhci_PortInfoPairedTxt		db "port_info(paired):", 0x0A, 0
	xhci_PortInfoActDeactTxt	db "port_info(act-deact):", 0x0A, 0
	xhci_PortResPortInfoUSB2ActTxt	db "port_info(in xhci_reset_port, Bef Act USB2):", 0x0A, 0
	xhci_PortResPortInfoUSB3DeactTxt	db "port_info(in xhci_reset_port, Bef Deact USB3):", 0x0A, 0
	xhci_PortResPortInfoUSB3Deact2Txt	db "port_info(in xhci_reset_port, Aft Deact USB3):", 0x0A, 0
%endif

%ifdef DBGXHCI_RESETPORT
	xhci_ResettingPortTxt	db "Resetting port: ", 0
	xhci_PoweringUpPortTxt	db "powering up the port", 0x0A, 0
	xhci_PortSCTxt			db "PortSC: ", 0
	xhci_PortSC2Txt			db "PortSC(after clearing status change bits): ", 0
	xhci_PortSC3Txt			db "PortSC(after successful reset/enable): ", 0
	xhci_PortSC4Txt			db "PortSC(after clearing status change bits): ", 0
	xhci_ResettingUSB3PortTxt	db "resetting USB3 port", 0x0A, 0
	xhci_ResettingUSB2PortTxt	db "resetting USB2 port", 0x0A, 0
%endif

%ifdef DBGXHCI_CONTROL
	xhci_LoopUSB3Txt	db "loop thru USB3 ports", 0x0A, 0
	xhci_ResettingPortsTxt	db "+++Resetting ports...+++ ", 0x0A, 0
	xhci_LoopUSB2Txt	db "loop thru USB2 ports", 0x0A, 0
	xhci_SpeedTxt		db "Speed of attached device:", 0
	xhci_SendCmdESTxt	db "SendCmd EnableSlot", 0x0A, 0
	xhci_SendCmdESOkTxt	db "SendCmd EnableSlot ok", 0x0A, 0
	xhci_SlotIDTxt		db "slotid=", 0
	xhci_SlotID2Txt		db "*******************slotid=", 0
	xhci_InitSlotTxt	db "Initializing slot ", 0x0A, 0
	xhci_SetAddressTxt	db "+++Setting address+++ ", 0x0A, 0
	xhci_SlotContextTxt	db "SlotContext: ", 0x0A, 0
	xhci_SetAddressOKTxt	db "setaddress OK", 0x0A, 0
	xhci_StatusRegTxt	db "usbstatusreg=", 0
	xhci_CmdRegTxt		db "usbcmdreg=", 0
	xhci_SetupAndDataIRQTxt	db "Setup and data stage IRQ arrived", 0x0A, 0
	xhci_ControlIOTxt	db "ControlIO:", 0x0A, 0
	xhci_CMaxPacketTxt	db "MaxPacket:", 0
	xhci_LengthTxt		db "Length:", 0
	xhci_DirTxt			db "Dir:", 0
	xhci_StatusAddrNTxt	db "statusaddr=", 0
	xhci_BufferAddrTxt	db "bufferaddr=", 0
	xhci_WaitForIRQTxt	db "xhci_wait_for_interrupt: ", 0
	xhci_BeforeDoorbellTxt	db "Before doorbell", 0x0A, 0
	xhci_BeforeDoorbellDtTxt	db "Before doorbell(After DataStage)", 0x0A, 0
	xhci_BeforeDoorbellStTxt	db "Before doorbell(After StatusStage)", 0x0A, 0
	xhci_GetDevDesc8Txt		db "Getting DevDesc 8 ...", 0x0A, 0
	xhci_GetDevDescAllTxt	db "Getting DevDesc All ...", 0x0A, 0
	xhci_ManufacturerIdxTxt	db "ManufacturerIdx:", 0
	xhci_GettingStringDescTxt	db "+++Getting string-descriptor...+++", 0x0A, 0
	xhci_StringDescLangIdsTxt	db "LangIDs:", 0x0A, 0
	xhci_LangIDTxt				db "langid=", 0x0A, 0
	xhci_ManufAvailTxt			db "Manufacturer available", 0x0A, 0
	xhci_ManufTxt				db "Manufacturer", 0x0A, 0
	xhci_ProductIdxTxt		db "ProductIdx:", 0
	xhci_SerialNumIdxTxt	db "SerailNumIdx", 0
%endif

%ifdef DBGXHCI_EPPTRARR
	xhci_EPSlotIDTxt		db "slotid=", 0
	xhci_CurEPRingPtrTxt	db "*****+++++[xhci_cur_ep_ring_ptr]=", 0
	xhci_CurEPRingCycleTxt	db "[xhci_cur_ep_ring_cycle]=", 0
	xhci_CurEPPtrArrTxt		db "CurEPPtrArr=", 0x0A, 0
	xhci_CurEPCycleArrTxt	db "CurEPCycleArr=", 0x0A, 0
%endif

%ifdef DBGXHCI_CONTROLSUB
	xhci_StatusRegSubTxt	db "usbstatusreg=", 0
	xhci_StatusAddrNSubTxt	db "statusaddr=", 0
	xhci_SetupStgReqDescPktTxt	db "+++SetupStage+++, RequestPacket:", 0x0A, 0
	xhci_DirectionTxt	db "Direction: ", 0
	xhci_DataStageTxt	db "+++DataStage+++", 0x0A, 0
	xhci_AddrTxt		db "Address:", 0
	xhci_SizeTxt		db "Size:", 0
	xhci_TRBTypeTxt		db "TRBType:", 0
	xhci_MaxPacketTxt	db "MaxPacket:", 0
	xhci_StatusStageTxt	db "+++StatusStage+++", 0x0A, 0
	xhci_SetupTRBTxt	db "Setup-TRB", 0x0A, 0
	xhci_DataTRBTxt		db "Data-TRB", 0x0A, 0
	xhci_EventDataTRBTxt	db "EventData-TRB", 0x0A, 0
	xhci_StatusTRBTxt	db "Status-TRB", 0x0A, 0
	xhci_Event2TRBTxt	db "Event2-TRB", 0x0A, 0
	xhci_SetAddrHeapTxt	db "SetAddress Heap:", 0
	xhci_InputContextBuffTxt	db "InputContextBuffer:", 0x0A, 0
	xhci_TRBSetAddrTxt	db "TRB set-address:", 0x0A, 0
	xhci_DeviceAddrTxt	db "++++++++++++++++++Device address=", 0
	xhci_SendCmdTxt		db "xhci_send_command:", 0x0A, 0
	xhci_CmdRingTRBCntTxt	db "cmnd_ring_trb_cnt=", 0
	xhci_SendCmdLinkTxt		db "xhci_send_command: LINK", 0x0A, 0
	xhci_EPRingTRBCntTxt	db "cur_ep_ring_trb_cnt=", 0
	xhci_InterrupterMainRegTxt	db "InterrupterMain=", 0
	xhci_cmd_ring_trb_cnt		dd 0
	xhci_cur_ep_ring_trb_cnt	dd 0

	xhci_SlotContextEntriesTxt 			db "[xhci_slot_context_entries]=", 0
	xhci_SlotContextHubTxt 				db "[xhci_slot_context_hub]=", 0
	xhci_SlotContextMttTxt 				db "[xhci_slot_context_mtt]=", 0
	xhci_SlotContextSpeedTxt 			db "[xhci_slot_context_speed]=", 0
	xhci_SlotContextRouteStrTxt 		db "[xhci_slot_context_route_str]=", 0
	xhci_SlotContextNumPortsTxt 		db "[xhci_slot_context_num_ports]=", 0
	xhci_SlotContextRhPortNumTxt 		db "[xhci_slot_context_rh_port_num]=", 0
	xhci_SlotContextMaxExitLatTxt 		db "[xhci_slot_context_max_exit_lat]=", 0
	xhci_SlotContextIntTargetTxt 		db "[xhci_slot_context_int_target]=", 0
	xhci_SlotContextTttTxt 				db "[xhci_slot_context_ttt]=", 0
	xhci_SlotContextTtPortNumTxt 		db "[xhci_slot_context_port_num]=", 0
	xhci_SlotContextTtHubSlotIdTxt 		db "[xhci_slot_context_tt_hub_slotid]=", 0
	xhci_SlotContextSlotStateTxt 		db "[xhci_slot_context_slot_state]=", 0
	xhci_SlotContextDeviceAddressTxt 	db "[xhci_slot_context_device_address]=", 0

	xhci_ContextIntervalTxt		db "[xhci_ep_context_interval]=", 0
	xhci_ContextLSATxt			db "[xhci_ep_context_lsa]=", 0
	xhci_ContextPStreamsTxt		db "[xhci_ep_context_max_pstreams]=", 0
	xhci_ContextMultTxt			db "[xhci_ep_context_mult]=", 0
	xhci_ContextEPStateTxt		db "[xhci_ep_context_ep_state]=", 0
	xhci_ContextMaxPSizeTxt		db "[xhci_ep_context_max_packet_size]=", 0
	xhci_ContextMaxBSizeTxt		db "[xhci_ep_context_max_burst_size]=", 0
	xhci_ContextHIDTxt			db "[xhci_ep_context_hid]=", 0
	xhci_ContextEPTypeTxt		db "[xhci_ep_context_ep_type]=", 0
	xhci_ContextCErrTxt			db "[xhci_ep_context_cerr]=", 0
	xhci_ContextDequeuePtrLoTxt	db "[xhci_ep_context_tr_dequeue_ptr_LO]=", 0
	xhci_ContextDequeuePtrHiTxt	db "[xhci_ep_context_tr_dequeue_ptr_HI]=", 0
	xhci_ContextDCSTxt			db "[xhci_ep_context_dcs]=", 0
	xhci_ContextMaxESITPLDTxt	db "[xhci_ep_context_max_esit_payload]=", 0
	xhci_ContextAvgTRBLenTxt	db "[xhci_ep_context_max_average_trb_len]=", 0

%endif

%ifdef	DBGXHCI_IRQ
	xhci_IRQArrivedTxt		db "***IRQ arrived***", 0x0A, 0
	xhci_IRQAcknowledgeTxt	db "IRQ acknowledgement", 0x0A, 0
	xhci_IRQEventRingTRBTxt	db "IRQ Event-ring TRB:", 0x0A, 0
	xhci_IRQTRBTxt			db "IRQ TRB:", 0x0A, 0
	xhci_IRQEventRingCycleIsOneTxt	db "IRQ Event-ring cycle is 1", 0x0A, 0
	xhci_IRQCmdBit2NotSetTxt	db "IRQ cmd bit2 not set", 0x0A, 0
	xhci_IRQTRBSuccessTxt	db "IRQ TRB success", 0x0A, 0
	xhci_IRQTRBCodeTxt		db "IRQ TRB code=", 0
	xhci_IRQTRBCommComplTxt	db "IRQ TRB CommandCompletion", 0x0A, 0
	xhci_IRQMarkTRBTxt		db "IRQ Mark TRB", 0x0A, 0
	xhci_IRQTransEventTxt	db "IRQ TransEvent", 0x0A, 0
	xhci_IRQEventRingTRBCntTxt	db "IRQ cur_event_ring_trb_cnt=", 0
	xhci_cur_event_ring_trb_cnt	dd 0
%endif

%ifdef DBGXHCI_DEVINFO
	xhci_DIDevInfoTxt					db "DevInfo", 0x0A, 0
	xhci_DIDevInfoDevAddrTxt			db "devaddr=", 0
	xhci_DIDevInfoIDXTxt				db "idx=", 0
	xhci_DISlotIterTxt					db "SlotContext: checking slot...", 0x0A, 0
	xhci_DIDevInfoDevAddrFndTxt			db "Device address found!", 0x0A, 0
	xhci_DIDevInfoStateAddressedFndTxt	db "State=addressed", 0x0A, 0
	xhci_DIDCBAAPStartTxt				db "[xhci_dcbaap_start]=", 0
	xhci_DISlotContextEntriesTxt 		db "[xhci_slot_context_entries]=", 0
	xhci_DISlotContextHubTxt 			db "[xhci_slot_context_hub]=", 0
	xhci_DISlotContextMttTxt 			db "[xhci_slot_context_mtt]=", 0
	xhci_DISlotContextSpeedTxt 			db "[xhci_slot_context_speed]=", 0
	xhci_DISlotContextRouteStrTxt 		db "[xhci_slot_context_route_str]=", 0
	xhci_DISlotContextNumPortsTxt 		db "[xhci_slot_context_num_ports]=", 0
	xhci_DISlotContextRhPortNumTxt 		db "[xhci_slot_context_rh_port_num]=", 0
	xhci_DISlotContextMaxExitLatTxt 	db "[xhci_slot_context_max_exit_lat]=", 0
	xhci_DISlotContextIntTargetTxt 		db "[xhci_slot_context_int_target]=", 0
	xhci_DISlotContextTttTxt 			db "[xhci_slot_context_ttt]=", 0
	xhci_DISlotContextTtPortNumTxt 		db "[xhci_slot_context_port_num]=", 0
	xhci_DISlotContextTtHubSlotIdTxt 	db "[xhci_slot_context_tt_hub_slotid]=", 0
	xhci_DISlotContextSlotStateTxt 		db "[xhci_slot_context_slot_state]=", 0
	xhci_DISlotContextDeviceAddressTxt db "[xhci_slot_context_device_address]=", 0
	xhci_DIConfigBiggerTxt				db "Config descriptor bigger", 0x0A, 0
	xhci_DIEndptsSavedTxt				db "Endpoints saved", 0x0A, 0
	xhci_DIGettingLUNTxt				db "Getting LUN ...", 0x0A, 0
	xhci_DISlotIdTxt		db "slotid=", 0
	xhci_DIMaxPacketTxt		db "max_packet=", 0
	xhci_DIBulkOutEptTxt	db "bulkout_endpt=", 0
	xhci_DIBulkOutMpsTxt	db "bulkout_mps=", 0
	xhci_DIBulkInEptTxt		db "bulkin_endpt=", 0
	xhci_DIBulkInMpsTxt		db "bulkin_mps=", 0
%endif

%ifdef DBGXHCI_INITMSD
	xhci_IMSDSlotContextEntriesTxt 			db "[xhci_slot_context_entries]=", 0
	xhci_IMSDSlotContextHubTxt 				db "[xhci_slot_context_hub]=", 0
	xhci_IMSDSlotContextMttTxt 				db "[xhci_slot_context_mtt]=", 0
	xhci_IMSDSlotContextSpeedTxt 			db "[xhci_slot_context_speed]=", 0
	xhci_IMSDSlotContextRouteStrTxt 		db "[xhci_slot_context_route_str]=", 0
	xhci_IMSDSlotContextNumPortsTxt 		db "[xhci_slot_context_num_ports]=", 0
	xhci_IMSDSlotContextRhPortNumTxt 		db "[xhci_slot_context_rh_port_num]=", 0
	xhci_IMSDSlotContextMaxExitLatTxt 		db "[xhci_slot_context_max_exit_lat]=", 0
	xhci_IMSDSlotContextIntTargetTxt 		db "[xhci_slot_context_int_target]=", 0
	xhci_IMSDSlotContextTttTxt 				db "[xhci_slot_context_ttt]=", 0
	xhci_IMSDSlotContextTtPortNumTxt 		db "[xhci_slot_context_port_num]=", 0
	xhci_IMSDSlotContextTtHubSlotIdTxt	 	db "[xhci_slot_context_tt_hub_slotid]=", 0
	xhci_IMSDSlotContextSlotStateTxt 		db "[xhci_slot_context_slot_state]=", 0
	xhci_IMSDSlotContextDeviceAddressTxt 	db "[xhci_slot_context_device_address]=", 0
	xhci_IMSDInitMSDTxt				db "InitMSD", 0x0A, 0
	xhci_IMSDSetConfigDevTxt		db "Setting configuration for device", 0x0A, 0
	xhci_IMSDSetConfigOkTxt			db "SetConfiguration Ok", 0x0A, 0
	xhci_IMSDInputContextHeapTxt	db "InputContextHeap=", 0
	xhci_IMSDInputContextTxt		db "InputContext:", 0
	xhci_IMSDConfigureEPTRBTxt		db "ConfigureEP TRB:", 0x0A, 0
	xhci_IMSDConfigureEPOkTxt		db "ConfigureEP ok", 0x0A, 0

	xhci_IMSDEPContextIntervalTxt		db "[xhci_ep_context_interval]=", 0
	xhci_IMSDEPContextLSATxt			db "[xhci_ep_context_lsa]=", 0
	xhci_IMSDEPContextPStreamsTxt		db "[xhci_ep_context_max_pstreams]=", 0
	xhci_IMSDEPContextMultTxt			db "[xhci_ep_context_mult]=", 0
	xhci_IMSDEPContextEPStateTxt		db "[xhci_ep_context_ep_state]=", 0
	xhci_IMSDEPContextMaxPSizeTxt		db "[xhci_ep_context_max_packet_size]=", 0
	xhci_IMSDEPContextMaxBSizeTxt		db "[xhci_ep_context_max_burst_size]=", 0
	xhci_IMSDEPContextHIDTxt			db "[xhci_ep_context_hid]=", 0
	xhci_IMSDEPContextEPTypeTxt			db "[xhci_ep_context_ep_type]=", 0
	xhci_IMSDEPContextCErrTxt			db "[xhci_ep_context_cerr]=", 0
	xhci_IMSDEPContextDequeuePtrLoTxt	db "[xhci_ep_context_tr_dequeue_ptr_LO]=", 0
	xhci_IMSDEPContextDequeuePtrHiTxt	db "[xhci_ep_context_tr_dequeue_ptr_HI]=", 0
	xhci_IMSDEPContextDCSTxt			db "[xhci_ep_context_dcs]=", 0
	xhci_IMSDEPContextMaxESITPLDTxt		db "[xhci_ep_context_max_esit_payload]=", 0
	xhci_IMSDEPContextAvgTRBLenTxt		db "[xhci_ep_context_max_average_trb_len]=", 0

	xhci_IMSDConfigureEPTxt		db "Configuring Endpoint ...", 0x0A, 0
	xhci_IMSDBulkResetTxt 		db "Doing a Bulk Reset ...", 0x0A, 0
	xhci_IMSDInquiryTxt			db "InquiryReq", 0x0A, 0
	xhci_IMSDInquiryGetTxt		db "Inquiry(Get)", 0x0A, 0
	xhci_IMSDInquiryGetArrTxt	db "Inquiry(Get) Array:", 0x0A, 0
	xhci_IMSDInquiryDumpCSWTxt	db "Inquiry(Get) CSW:", 0x0A, 0
	xhci_IMSDInquiryReadCSWTxt	db "Inquiry(ReadCSW)", 0x0A, 0
	xhci_IMSDInquiryCheckCSWTxt	db "Inquiry(CheckCSW)", 0x0A, 0
	xhci_IMSDTestUnitTxt		db "TestUnitReq", 0x0A, 0
	xhci_IMSDTestUnitReadCSWTxt	db "TestUnitReq(ReadCSW)", 0x0A, 0
	xhci_IMSDSenseTxt			db "SenseReq", 0x0A, 0
	xhci_IMSDSenseGetTxt		db "Sense(Get)", 0x0A, 0
	xhci_IMSDSenseGetArrTxt		db "Sense(Get) Array:", 0x0A, 0
	xhci_IMSDSenseReadCSWTxt	db "Sense(ReadCSW)", 0x0A, 0
	xhci_IMSDSenseDumpCSWTxt	db "Sense(Get) CSW:", 0x0A, 0
	xhci_IMSDSenseCheckCSWTxt	db "Sense(CheckCSW)", 0x0A, 0
	xhci_IMSDCapacityTxt		db "CapacityReq", 0x0A, 0
	xhci_IMSDSetInitedMSDTxt	db "++++++++++++++Setting [xhci_inited_msd]", 0x0A, 0
	xhci_IMSDCapacityGetTxt		db "Capacity(Get)", 0x0A, 0
	xhci_IMSDCapacityGetArrTxt	db "Capacity(Get) Array:", 0x0A, 0
	xhci_IMSDCapacityReadCSWTxt	db "Capacity(ReadCSW)", 0x0A, 0
	xhci_IMSDCapacityDumpCSWTxt	db "Capacity(Get) CSW:", 0x0A, 0
	xhci_IMSDCapacityCheckCSWTxt	db "Capacity(CheckCSW)", 0x0A, 0
	xhci_IMSDCapacityLBAHiTxt	db "Capacity(LBAHi)=", 0
	xhci_IMSDCapacityLBALoTxt	db "Capacity(LBALo)=", 0
	xhci_IMSDCapacitySectorTxt	db "Capacity(SectorSize)=", 0
	xhci_IMSDHEAPPTRTxt			db "[xhci_cur_heap_ptr]=", 0
%endif

%ifdef	DBGXHCI_BULKIO
	xhci_BulkIOTxt					db "Bulk IO", 0x0A, 0
	xhci_BulkDirTxt					db "Direction:", 0
	xhci_BulkAddrTxt				db "Address:", 0
	xhci_BulkSizeTxt				db "Size:", 0
	xhci_BulkStatusAddrNSubTxt		db "statusaddr=", 0
	xhci_BulkMaxPacketTxt			db "MaxPacket:", 0
	xhci_BulkTRBTxt					db "Bulk TRB", 0x0A, 0
	xhci_BulkOutEPRingTRBCntTxt		db "[cur_bulkout_ep_ring_trb_cnt]=", 0
	xhci_BulkInEPRingTRBCntTxt		db "[cur_bulkin_ep_ring_trb_cnt]=", 0
	xhci_BulkEventDataTRBTxt		db "EventData-TRB", 0x0A, 0
	xhci_cur_bulkout_ep_ring_trb_cnt	dd 0
	xhci_cur_bulkin_ep_ring_trb_cnt		dd 0
%endif

%ifdef DBGXHCI_BULK_READ
	xhci_BulkRead_ReadMsdTxt	db "ReadMsd", 0x0A, 0
	xhci_BulkRead_Read10Txt		db "Read10", 0x0A, 0
	xhci_BulkRead_Read12Txt		db "Read12", 0x0A, 0
	xhci_BulkRead_Read16Txt		db "Read16", 0x0A, 0
	xhci_BulkRead_Read10_SubTxt	db "xhci_read10_req:", 0x0A, 0
	xhci_BulkRead_LBAHITxt		db "LBAHi=", 0
	xhci_BulkRead_LBALOTxt		db "LBALo=", 0
	xhci_BulkRead_MemAddrTxt	db "MemAddr=", 0
	xhci_BulkRead_SectorsNumTxt	db "SectorsNum=", 0
	xhci_BulkRead_Read12_SubTxt	db "xhci_read12_req:", 0x0A, 0
	xhci_BulkRead_Read16_SubTxt	db "xhci_read16_req:", 0x0A, 0
	xhci_BulkRead_ReadCommonTxt	db "xhci_read_common:", 0x0A, 0
	xhci_BulkRead_PtrToAddrTxt	db "PtrToAddr=", 0
	xhci_BulkRead_NumBytesTxt	db "NumBytes=", 0
	xhci_BulkRead_PtrToMsgArrTxt db "PtrToMsgArr= ...", 0x0A, 0
%endif

%ifdef DBGXHCI_BULK_WRITE
	xhci_BulkWrite_WriteMsdTxt	db "WriteMsd", 0x0A, 0
	xhci_BulkWrite_Write10Txt	db "Write10", 0x0A, 0
	xhci_BulkWrite_Write12Txt	db "Write12", 0x0A, 0
	xhci_BulkWrite_Write16Txt	db "Write16", 0x0A, 0
	xhci_BulkWrite_Write10_SubTxt db "xhci_write10_req:", 0x0A, 0
	xhci_BulkWrite_LBALOTxt		db "LBALo=", 0
	xhci_BulkWrite_MemAddrTxt	db "MemAddr=", 0
	xhci_BulkWrite_SectorsNumTxt db "SectorsNum=", 0
	xhci_BulkWrite_Write12_SubTxt db "xhci_write12_req:", 0x0A, 0
	xhci_BulkWrite_Write16_SubTxt db "xhci_write16_req:", 0x0A, 0
	xhci_BulkWrite_WriteCommonTxt	db "xhci_write_common:", 0x0A, 0
	xhci_BulkWrite_PtrToAddrTxt	db "PtrToAddr=", 0
	xhci_BulkWrite_NumBytesTxt	db "NumBytes=", 0
	xhci_BulkWrite_PtrToMsgArrTxt db "PtrToMsgArr= ...", 0x0A, 0
%endif


%endif

 
