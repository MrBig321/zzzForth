;********************************************
; USB common
;********************************************

%ifndef __USBCOMMON__
%define __USBCOMMON__


; Controller Types
%define USB_TYPE_UHCI	0x00
%define USB_TYPE_OHCI	0x10
%define USB_TYPE_EHCI	0x20
%define USB_TYPE_XHCI	0x30


; transfer types (Endpoint types) (USB 2.0 page 270)
%define USB_CONTROL_EP		0
%define USB_ISOCHRONOUS_EP	1
%define USB_BULK_EP			2
%define USB_INTERRUPT_EP	3 


; Reset wait times.  USB 2.0 specs, page 153, section 7.1.7.5, paragraph 3
%define USB_TDRSTR	50	; reset on a root hub
%define USB_TDRST	10  ; minimum delay for a reset
%define USB_TRHRSI	3   ; No more than this between resets for root hubs
%define USB_TRSTRCY	10  ; reset recovery


; Device Descriptor offsets
%define	USB_DEVDESC_LEN				0 	;bit8u  len;
%define	USB_DEVDESC_TYPE			1	;bit8u  type;
%define	USB_DEVDESC_VER				2	;bit16u usb_ver;
%define	USB_DEVDESC_CLASS			4	;bit8u  _class;
%define	USB_DEVDESC_SUBCLASS		5	;bit8u  subclass;
%define	USB_DEVDESC_PROTOCOL		6	;bit8u  protocol;
%define	USB_DEVDESC_MAX_PACKETSIZE	7	;bit8u  max_packet_size;
%define	USB_DEVDESC_VENDORID		8	;bit16u vendorid;
%define	USB_DEVDESC_PRODUCTID		10	;bit16u productid;
%define	USB_DEVDESC_DEVICEREL		12	;bit16u device_rel;
%define	USB_DEVDESC_MANUFIDX		14	;bit8u  manuf_indx;   // index value
%define	USB_DEVDESC_PRODIDX			15	;bit8u  prod_indx;    // index value
%define	USB_DEVDESC_SERIALIDX		16	;bit8u  serial_indx;  // index value
%define	USB_DEVDESC_CONFIGS			17	;bit8u  configs;      // Number of configurations


usb_dev_desc:
usb_dd_len				db	0
usb_dd_type				db	0
usb_dd_usb_ver			dw	0
usb_dd_class			db	0
usb_dd_subclass			db	0
usb_dd_protocol			db	0
usb_dd_max_packet_size	db	0
usb_dd_vendorid			dw	0
usb_dd_productid		dw	0
usb_dd_device_rel		dw	0
usb_dd_manuf_idx		db	0
usb_dd_prod_idx			db	0
usb_dd_serial_idx		db	0
usb_dd_configs			db	0


; Request Packet offsets
%define USB_RECPAC_TYPE		0	;bit8u  request_type;
%define USB_RECPAC_REQUEST	1	;bit8u  request;
%define USB_RECPAC_VALUE	2	;bit16u value;
%define USB_RECPAC_IDX		4	;bit16u index;
%define USB_RECPAC_LENGTH	6	;bit16u length;

%define USB_REQUEST_PACKET_SIZE	8

;struct REQUEST_PACKET {
;	bit8u  request_type;
;	bit8u  request;
;	bit16u value;
;	bit16u index;
;	bit16u length;
;};


; setup packets 
%define USB_DEV_TO_HOST			0x80
%define USB_HOST_TO_DEV			0x00
%define USB_REQ_TYPE_STNDRD		0x00
%define USB_REQ_TYPE_CLASS		0x20
%define USB_REQ_TYPE_VENDOR		0x40
%define USB_REQ_TYPE_RESV		0x60
%define USB_RECPT_DEVICE		0x00
%define USB_RECPT_INTERFACE		0x01
%define USB_RECPT_ENDPOINT		0x02
%define USB_RECPT_OTHER			0x03
%define USB_STDRD_GET_REQUEST   (USB_DEV_TO_HOST | USB_REQ_TYPE_STNDRD | USB_RECPT_DEVICE)
%define USB_STDRD_SET_REQUEST   (USB_HOST_TO_DEV | USB_REQ_TYPE_STNDRD | USB_RECPT_DEVICE)
%define USB_STDRD_SET_INTERFACE (USB_HOST_TO_DEV | USB_REQ_TYPE_STNDRD | USB_RECPT_INTERFACE)


; device requests
%define USB_DEVREQ_GET_STATUS			0
%define USB_DEVREQ_CLEAR_FEATURE		1
%define USB_DEVREQ_SET_FEATURE			3
%define USB_DEVREQ_SET_ADDRESS			5
%define USB_DEVREQ_GET_DESCRIPTOR		6
%define USB_DEVREQ_SET_DESCRIPTOR		7
%define USB_DEVREQ_GET_CONFIGURATION	8
%define USB_DEVREQ_SET_CONFIGURATION	9
; interface requests
%define USB_DEVREQ_GET_INTERFACE		10
%define USB_DEVREQ_SET_INTERFACE		11
; standard endpoint requests
%define USB_DEVREQ_SYNCH_FRAME			12
; Device specific
%define USB_DEVREQ_GET_MAX_LUNS			0xFE
%define USB_DEVREQ_BULK_ONLY_RESET		0xFF


; Descriptor types
%define USB_DESCTYP_DEVICE					1
%define USB_DESCTYP_CONFIG					2
%define USB_DESCTYP_STRING					3
%define USB_DESCTYP_INTERFACE				4
%define USB_DESCTYP_ENDPOINT				5
%define USB_DESCTYP_DEVICE_QUALIFIER		6
%define USB_DESCTYP_OTHER_SPEED_CONFIG		7
%define USB_DESCTYP_INTERFACE_POWER			8
%define USB_DESCTYP_OTG						9
%define USB_DESCTYP_DEBUG					10
%define USB_DESCTYP_INTERFACE_ASSOCIATION	11
%define USB_DESCTYP_HID						0x21
%define USB_DESCTYP_HID_REPORT				0x22
%define USB_DESCTYP_HID_PHYSICAL			0x23
%define USB_DESCTYP_HUB						0x29

%define USB_DESCTYP_BOS						0x0F


%define USB_CBW_TOTALBYTES_OFFS			8
%define USB_CBW_COMMAND_OFFS			15


; from common.h
%define USB_SUCCESS                   0
%define USB_ERROR_STALLED            -1
%define USB_ERROR_DATA_BUFFER_ERROR  -2
%define USB_ERROR_BABBLE_DETECTED    -3
%define USB_ERROR_NAK                -4
%define USB_ERROR_TIME_OUT          254
%define USB_ERROR_UNKNOWN           255




%endif


