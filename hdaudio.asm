; The HDAudio driver worked on Dell D820 and an old desktop computer.
; I also tested it on Dell Inspiron 5559 and Eee PC 1001PX.
; FEATURES
;	- Uses the first codec found
;	- Output only
;	- Short list-entries only (parsing 2 DWORDS, i.e. max 8 ConnListEntries for a node)
;	- (Range)	Not implemented yet
;	- Sets volume to medium (gain = 0x3F) (0x7F is the maximum)
;	- DEBUGPARSE defined: prints parse-paths
;	- DEBUG_SETTINGS prints the values of the widgets after we set them
;	- I couldn't test the Knob-widget 

%ifndef __HDAUDIO__
%define __HDAUDIO__


%include "pci.asm"
%include "pit.asm"
%include "gstdio.asm"
%include "gutil.asm"		; for pressakey


;%define DEBUGPARSE	1			; For debugging parsing
;%define DEBUG_SETTINGS			; Prints settings before playing the selected wav

; Registers
%define	HDAUDIO_GCAP_OFFS		0x00
%define	HDAUDIO_VMIN_OFFS		0x02
%define	HDAUDIO_VMAJ_OFFS		0x03
%define	HDAUDIO_OUTPAY_OFFS		0x04
%define	HDAUDIO_INPAY_OFFS		0x06
%define	HDAUDIO_GCTL_OFFS		0x08
%define	HDAUDIO_WAKEEN_OFFS		0x0C
%define	HDAUDIO_STATESTS_OFFS	0x0E
%define	HDAUDIO_GSTS_OFFS		0x10
%define	HDAUDIO_OUTSTRMPAY_OFFS	0x18
%define	HDAUDIO_INSTRMPAY_OFFS	0x1A
%define	HDAUDIO_INTCTL_OFFS		0x20
%define	HDAUDIO_INTSTS_OFFS		0x24
%define	HDAUDIO_WALCLK_OFFS		0x30
%define	HDAUDIO_SSYNC_OFFS		0x38
%define	HDAUDIO_CORBLBASE_OFFS	0x40
%define	HDAUDIO_CORBUBASE_OFFS	0x44
%define	HDAUDIO_CORBWP_OFFS		0x48
%define	HDAUDIO_CORBRP_OFFS		0x4A
%define	HDAUDIO_CORBCTL_OFFS	0x4C
%define	HDAUDIO_CORBSTS_OFFS	0x4D
%define	HDAUDIO_CORBSIZE_OFFS	0x4E
%define	HDAUDIO_RIRBLBASE_OFFS	0x50
%define	HDAUDIO_RIRBUBASE_OFFS	0x54
%define	HDAUDIO_RIRBWP_OFFS		0x58
%define	HDAUDIO_RINTCNT_OFFS	0x5A
%define	HDAUDIO_RIRBCTL_OFFS	0x5C
%define	HDAUDIO_RIRBSTS_OFFS	0x5D
%define	HDAUDIO_RIRBSIZE_OFFS	0x5E
%define	HDAUDIO_ICOI_OFFS		0x60
%define	HDAUDIO_ICII_OFFS		0x64
%define	HDAUDIO_ICIS_OFFS		0x68
%define	HDAUDIO_DPIBLBASE_OFFS	0x70
%define	HDAUDIO_DPIBUBASE_OFFS	0x74
; Output0 (80h+(ISS*20h), ISS is the number of input-streams in GCAP)

%define HDAUDIO_INPUT_BASE		0x80
; The offsets from base
%define	HDAUDIO_SD0CTL_OFFS		0x00
%define	HDAUDIO_SD0STS_OFFS		0x03
%define	HDAUDIO_SD0LPIB_OFFS	0x04
%define	HDAUDIO_SD0CBL_OFFS		0x08
%define	HDAUDIO_SD0LVI_OFFS		0x0C
%define	HDAUDIO_SD0FIFOD_OFFS	0x10
%define	HDAUDIO_SD0FMT_OFFS		0x12
%define	HDAUDIO_SD0BDPL_OFFS	0x18
%define	HDAUDIO_SD0BDPU_OFFS	0x1C

%define	HDAUDIO_CORB_BUFF	0x00100000
%define	HDAUDIO_RIRB_BUFF	0x00101000
%define	HDAUDIO_DPL_BUFF	0x00102000
%define	HDAUDIO_BDL_BUFF	0x00103000	; BDL-Entries
%define HDAUDIO_BDL_ENTRY_NUM	4		; LVI is 3

%define	HDAUDIO_BUFF_ADDR	0x00105000	; from this the four 0x10000 buffers
%define	HDAUDIO_BUFF_LEN	0x10000		; BDL-entries must be 128-byte aligned!! this way, the DMA engine is looping

hdaudio_pcm_addr	dd 0
hdaudio_pcm_len		dd 0

hdaudio_pcm_part		dw 0
hdaudio_pcm_part_max	dw 0
hdaudio_buff_num		db 0
hdaudio_data_copied		db 0


; Commands
%define HDAUDIO_CMD_GET_PARAMETER				0xF00
%define HDAUDIO_CMD_GET_CONN_SEL_CTRL			0xF01
%define HDAUDIO_CMD_SET_CONN_SEL_CTRL			0x701
%define HDAUDIO_CMD_GET_CONN_LIST_ENTRY_CTRL	0xF02
%define HDAUDIO_CMD_GET_PROC_STATE				0xF03
%define HDAUDIO_CMD_SET_PROC_STATE				0x703
%define HDAUDIO_CMD_GET_COEFF_IDX				0xD00		; !?
%define HDAUDIO_CMD_SET_COEFF_IDX				0x500		; !?
%define HDAUDIO_CMD_GET_PROC_COEFF				0xC00		; !?	Spec: Ch 
%define HDAUDIO_CMD_SET_PROC_COEFF				0x400		; !?
%define HDAUDIO_CMD_GET_AMP_GAINMUTE			0xB00		; !?
%define HDAUDIO_CMD_SET_AMP_GAINMUTE			0x300		; !?
;%define HDAUDIO_CMD_GET_AMP_GAINMUTE			0x0B		; !?
;%define HDAUDIO_CMD_SET_AMP_GAINMUTE			0x03		; !?
%define HDAUDIO_CMD_GET_CONV_FORMAT				0xA00		; !?
%define HDAUDIO_CMD_SET_CONV_FORMAT				0x200		; !?
%define HDAUDIO_CMD_GET_SPDIF_CONV_CTRL			0xF0D
%define HDAUDIO_CMD_SET_SPDIF_CONV_CTRL1		0x70D
%define HDAUDIO_CMD_SET_SPDIF_CONV_CTRL2		0x70E
%define HDAUDIO_CMD_SET_SPDIF_CONV_CTRL3		0x73E
%define HDAUDIO_CMD_SET_SPDIF_CONV_CTRL4		0x73F
%define HDAUDIO_CMD_GET_POWER_STATE				0xF05
%define HDAUDIO_CMD_SET_POWER_STATE				0x705
%define HDAUDIO_CMD_GET_STREAM_CONV_CTRL		0xF06
%define HDAUDIO_CMD_SET_STREAM_CONV_CTRL		0x706
%define HDAUDIO_CMD_GET_INP_CONV_SDI_SEL		0xF04
%define HDAUDIO_CMD_SET_INP_CONV_SDI_SEL		0x704
%define HDAUDIO_CMD_GET_PIN_WIDGET_CTRL			0xF07
%define HDAUDIO_CMD_SET_PIN_WIDGET_CTRL			0x707
%define HDAUDIO_CMD_GET_UNSOL_RESP_CTRL			0xF08
%define HDAUDIO_CMD_SET_UNSOL_RESP_CTRL			0x708
%define HDAUDIO_CMD_GET_PIN_SENSE_CTRL			0xF09
%define HDAUDIO_CMD_SET_PIN_SENSE_CTRL			0x709
%define HDAUDIO_CMD_GET_EAPDBTL_ENABLE			0xF0C
%define HDAUDIO_CMD_SET_EAPDBTL_ENABLE			0x70C
%define HDAUDIO_CMD_GET_GPI_DATA				0xF10
%define HDAUDIO_CMD_SET_GPI_DATA				0x710
%define HDAUDIO_CMD_GET_GPI_WAKE_ENA_MASK		0xF11
%define HDAUDIO_CMD_SET_GPI_WAKE_ENA_MASK		0x711
%define HDAUDIO_CMD_GET_GPI_UNSOL_ENA_MASK		0xF12
%define HDAUDIO_CMD_SET_GPI_UNSOL_ENA_MASK		0x712
%define HDAUDIO_CMD_GET_GPI_STICKY_MASK			0xF13
%define HDAUDIO_CMD_SET_GPI_STICKY_MASK			0x713
%define HDAUDIO_CMD_GET_GPO_DATA				0xF14
%define HDAUDIO_CMD_SET_GPO_DATA				0x714
%define HDAUDIO_CMD_GET_GPIO_DATA				0xF15
%define HDAUDIO_CMD_SET_GPIO_DATA				0x715
%define HDAUDIO_CMD_GET_GPIO_ENA_MASK			0xF16
%define HDAUDIO_CMD_SET_GPIO_ENA_MASK			0x716
%define HDAUDIO_CMD_GET_GPIO_DIR				0xF17
%define HDAUDIO_CMD_SET_GPIO_DIR				0x717
%define HDAUDIO_CMD_GET_GPIO_WAKE_ENA_MASK		0xF18
%define HDAUDIO_CMD_SET_GPIO_WAKE_ENA_MASK		0x718
%define HDAUDIO_CMD_GET_GPIO_UNSOL_ENA_MASK		0xF19
%define HDAUDIO_CMD_SET_GPIO_UNSOL_ENA_MASK		0x719
%define HDAUDIO_CMD_GET_GPIO_STICKY_MASK		0xF1A
%define HDAUDIO_CMD_SET_GPIO_STICKY_MASK		0x71A
%define HDAUDIO_CMD_GET_BEEP_GEN				0xF0A
%define HDAUDIO_CMD_SET_BEEP_GEN				0x70A
%define HDAUDIO_CMD_GET_VOLUME_KNOB				0xF0F
%define HDAUDIO_CMD_SET_VOLUME_KNOB				0x70F
%define HDAUDIO_CMD_GET_IMPL_ID					0xF20
%define HDAUDIO_CMD_SET_IMPL_ID1				0x720
%define HDAUDIO_CMD_SET_IMPL_ID2				0x721
%define HDAUDIO_CMD_SET_IMPL_ID3				0x722
%define HDAUDIO_CMD_SET_IMPL_ID4				0x723
%define HDAUDIO_CMD_GET_CONFIG_DEFAULT			0xF1C
%define HDAUDIO_CMD_SET_CONFIG_DEFAULT1			0x71C
%define HDAUDIO_CMD_SET_CONFIG_DEFAULT2			0x71D
%define HDAUDIO_CMD_SET_CONFIG_DEFAULT3			0x71E
%define HDAUDIO_CMD_SET_CONFIG_DEFAULT4			0x71F
%define HDAUDIO_CMD_GET_STRIPE_CTRL				0xF24
%define HDAUDIO_CMD_SET_STRIPE_CTRL				0x724
%define HDAUDIO_CMD_FUNCTION_RESET				0x7FF
%define HDAUDIO_CMD_GET_ELD_DATA				0xF2F
%define HDAUDIO_CMD_GET_CONV_CH_CNT				0xF2D
%define HDAUDIO_CMD_SET_CONV_CH_CNT				0x72D
%define HDAUDIO_CMD_GET_DIP_SIZE				0xF2E
%define HDAUDIO_CMD_GET_DIP_IDX					0xF30
%define HDAUDIO_CMD_SET_DIP_IDX					0x730
%define HDAUDIO_CMD_GET_DIP_DATA				0xF31
%define HDAUDIO_CMD_SET_DIP_DATA				0x731
%define HDAUDIO_CMD_GET_DIP_TR_CTRL				0xF32
%define HDAUDIO_CMD_SET_DIP_TR_CTRL				0x732
%define HDAUDIO_CMD_GET_CONTENT_PROT_CTRL		0xF33
%define HDAUDIO_CMD_SET_CONTENT_PROT_CTRL		0x733

; Parameters
%define	HDAUDIO_PARAM_VENDORID					0x00
%define	HDAUDIO_PARAM_REVISIONID				0x02
%define	HDAUDIO_PARAM_SUB_NODE_CNT				0x04
%define	HDAUDIO_PARAM_FUNC_GR_TYPE				0x05
%define	HDAUDIO_PARAM_AFG_CAPS					0x08
%define	HDAUDIO_PARAM_WIDGET_CAPS				0x09
%define	HDAUDIO_PARAM_SUPP_PCM_SIZE				0x0A
%define	HDAUDIO_PARAM_HDMI_LPCM_CAD				0x20
%define	HDAUDIO_PARAM_SUPP_STREAM_FORMATS		0x0B
%define	HDAUDIO_PARAM_PIN_CAPS					0x0C
%define	HDAUDIO_PARAM_INP_AMP_CAPS				0x0D
%define	HDAUDIO_PARAM_CONN_LIST_LEN				0x0E
%define	HDAUDIO_PARAM_SUPP_POWER_STATES			0x0F
%define	HDAUDIO_PARAM_PROC_CAPS					0x10
%define	HDAUDIO_PARAM_GPIO_CNT					0x11
%define	HDAUDIO_PARAM_OUTP_AMP_CAPS				0x12
%define	HDAUDIO_PARAM_VOLUME_KNOB_CAPS			0x13

; Vendor and Device IDs
%define	HDAUDIO_CODEC_VENDORID		(0xFF << 16)
%define	HDAUDIO_CODEC_DEVICEID		(0xFF << 0)

; RevisionID
%define	HDAUDIO_CODEC_REV_MAJ			(0x0F << 20)
%define	HDAUDIO_CODEC_REV_MIN			(0x0F << 16)
%define	HDAUDIO_CODEC_REV_ID			(0xFF << 8)
%define	HDAUDIO_CODEC_REV_STEPPING_ID	(0xFF)

; Subordinate Node Count
%define	HDAUDIO_SUB_NODE_CNT_START			(0xFF << 16)
%define	HDAUDIO_SUB_NODE_CNT_START_SHIFT	16
%define	HDAUDIO_SUB_NODE_CNT_TOTAL			(0xFF << 0)

; Function Group Types
%define	HDAUDIO_FG_AUDIO	0x01
%define	HDAUDIO_FG_MODEM	0x02
%define	HDAUDIO_FG_OTHER	0x80	; or higher (vendor defined FG)

; AFG Caps (page 200)
%define	HDAUDIO_AFG_CAPS_BEEP_GEN			(1 << 16)
%define	HDAUDIO_AFG_CAPS_BEEP_GEN_SHIFT		16
%define	HDAUDIO_AFG_CAPS_INP_DELAY			(0x0F << 8)
%define	HDAUDIO_AFG_CAPS_INP_DELAY_SHIFT	8
%define	HDAUDIO_AFG_CAPS_OUTP_DELAY			(0x0F << 0)

; Power States (page 151)
%define HDAUDIO_POWER_STATE_D0		0x00
%define HDAUDIO_POWER_STATE_D1		0x01
%define HDAUDIO_POWER_STATE_D2		0x02
%define HDAUDIO_POWER_STATE_D3		0x03

; Widget types (page 202)
%define	HDAUDIO_WIDGET_AUD_OUT		0x00
%define	HDAUDIO_WIDGET_AUD_IN		0x01
%define	HDAUDIO_WIDGET_AUD_MIX		0x02
%define	HDAUDIO_WIDGET_AUD_SEL		0x03
%define	HDAUDIO_WIDGET_PIN			0x04
%define	HDAUDIO_WIDGET_POWER		0x05
%define	HDAUDIO_WIDGET_VOL_KNOB		0x06
%define	HDAUDIO_WIDGET_BEEP_GEN		0x07
%define	HDAUDIO_WIDGET_VENDOR		0x0F

; Pin Widget Control
%define	HDAUDIO_PINCTL_HP_ENABLE	(1 << 7)
%define	HDAUDIO_PINCTL_OUT_ENABLE	(1 << 6)
%define	HDAUDIO_PINCTL_IN_ENABLE	(1 << 5)
%define	HDAUDIO_PINCTL_IN_ENABLE	(1 << 5)
%define	HDAUDIO_PINCTL_VREF100		5
%define	HDAUDIO_PINCTL_VREF80		4
%define	HDAUDIO_PINCTL_VREFGRD		2
%define	HDAUDIO_PINCTL_VREF80		1
%define	HDAUDIO_PINCTL_VREFHIZ		0
%define	HDAUDIO_PINCTL_VREF_ENA		0x07	; !?

; ConfigurationDefault (page 177)
%define	HDAUDIO_CONFIGDEF_PORTCONN			(0x03 << 30)
%define	HDAUDIO_CONFIGDEF_PORTCONN_SHIFT	30
%define	HDAUDIO_CONFIGDEF_LOCATION			(0x3F << 24)
%define	HDAUDIO_CONFIGDEF_LOCATION_SHIFT	24
%define	HDAUDIO_CONFIGDEF_DEFDEV			(0x0F << 20)
%define	HDAUDIO_CONFIGDEF_DEFDEV_SHIFT		20
%define	HDAUDIO_CONFIGDEF_CONNTYPE			(0x0F << 16)
%define	HDAUDIO_CONFIGDEF_CONNTYPE_SHIFT	16
%define	HDAUDIO_CONFIGDEF_COLOR				(0x0F << 12)
%define	HDAUDIO_CONFIGDEF_COLOR_SHIFT		12
%define	HDAUDIO_CONFIGDEF_MISC				(0x0F << 8)
%define	HDAUDIO_CONFIGDEF_MISC_SHIFT		8
%define	HDAUDIO_CONFIGDEF_DEFASSOC			(0x0F << 4)
%define	HDAUDIO_CONFIGDEF_DEFASSOC_SHIFT	4
%define	HDAUDIO_CONFIGDEF_SEQ				(0x0F)
;	Jacks (page 180)
%define	HDAUDIO_JACK_LINE_OUT			0x00
%define	HDAUDIO_JACK_SPEAKER			0x01
%define	HDAUDIO_JACK_HP_OUT				0x02
%define	HDAUDIO_JACK_CD					0x03
%define	HDAUDIO_JACK_SPDIF_OUT			0x04
%define	HDAUDIO_JACK_DIG_OTHER_OUT		0x05
%define	HDAUDIO_JACK_MODEM_LINE_SIDE	0x06
%define	HDAUDIO_JACK_MODEM_HAND_SIDE	0x07
%define	HDAUDIO_JACK_LINE_IN			0x08
%define	HDAUDIO_JACK_AUX				0x09
%define	HDAUDIO_JACK_MIC_IN				0x0A
%define	HDAUDIO_JACK_TELEPHONY			0x0B
%define	HDAUDIO_JACK_SPDIF_IN			0x0C
%define	HDAUDIO_JACK_DIG_OTHER_IN		0x0D
%define	HDAUDIO_JACK_OTHER				0x0F
;	Port connectivity
%define	HDAUDIO_PORTCONN_JACK		0x00
%define	HDAUDIO_PORTCONN_NO			0x01
%define	HDAUDIO_PORTCONN_FIXED		0x02
%define	HDAUDIO_PORTCONN_BOTH		0x03
; ConfigDef end

; Audio Widget Capabilities(param 09h) masks offsets(to shift if it consists of several bits) (page 201)
%define	HDAUDIO_WCAPS_TYPE					(0x0F << 20)
%define	HDAUDIO_WCAPS_TYPE_SHIFT			20
%define	HDAUDIO_WCAPS_DELAY					(0x0F << 16)
%define	HDAUDIO_WCAPS_DELAY_SHIFT			16
%define	HDAUDIO_WCAPS_CHAN_CNT_EXT			(0x07 << 13)
%define	HDAUDIO_WCAPS_CHAN_CNT_EXT_SHIFT	13
%define	HDAUDIO_WCAPS_CP_CASPS				(1 << 12)
%define	HDAUDIO_WCAPS_LR_SWAP				(1 << 11)
%define	HDAUDIO_WCAPS_PWR_CNTRL				(1 << 10)
%define	HDAUDIO_WCAPS_DIGITAL				(1 << 9)
%define	HDAUDIO_WCAPS_CONN_LIST				(1 << 8)
%define	HDAUDIO_WCAPS_UNSOL_CAP				(1 << 7)
%define	HDAUDIO_WCAPS_PROC_WG				(1 << 6)
%define	HDAUDIO_WCAPS_STRIPE				(1 << 5)
%define	HDAUDIO_WCAPS_FORMAT_OVRR			(1 << 4)
%define	HDAUDIO_WCAPS_AMP_PAR_OVRR			(1 << 3)
%define	HDAUDIO_WCAPS_OUT_AMP_PRES			(1 << 2)
%define	HDAUDIO_WCAPS_IN_AMP_PRES			(1 << 1)
%define	HDAUDIO_WCAPS_CH_CNT_LSB			(1 << 0)

; AMP gain/mute (page 145)
%define	HDAUDIO_AMP_SET_OUTPUT		(1 << 15)
%define	HDAUDIO_AMP_SET_INPUT		(1 << 14)
%define	HDAUDIO_AMP_SET_LEFT		(1 << 13)
%define	HDAUDIO_AMP_SET_RIGHT		(1 << 12)
%define	HDAUDIO_AMP_INDEX			(0x0F << 8)
%define	HDAUDIO_AMP_INDEX_SHIFT		8
%define	HDAUDIO_AMP_MUTE			(1 << 7)
%define	HDAUDIO_AMP_GAIN			(0x7F)
;		get
%define	HDAUDIO_AMP_GET_OUTPUT	(1 << 15)
%define	HDAUDIO_AMP_GET_INPUT	(0 << 15)
%define	HDAUDIO_AMP_GET_LEFT	(1 << 13)
%define	HDAUDIO_AMP_GET_RIGHT	(0 << 13)
%define	HDAUDIO_AMP_GET_INDEX	(0x0F)

; Supported PCM rates (page 204)
%define	HDAUDIO_PCM_RATES		(0x0FFF << 0)

; Supported PCM sizes (page 204)
%define	HDAUDIO_PCM_SIZE_B8		(1 << 16)
%define	HDAUDIO_PCM_SIZE_B16	(1 << 17)
%define	HDAUDIO_PCM_SIZE_B20	(1 << 18)
%define	HDAUDIO_PCM_SIZE_B24	(1 << 19)
%define	HDAUDIO_PCM_SIZE_B32	(1 << 20)

%define	HDAUDIO_PCM_KHZ_384		(1 << 11)
%define	HDAUDIO_PCM_KHZ_192		(1 << 10)
%define	HDAUDIO_PCM_KHZ_1764	(1 << 9)
%define	HDAUDIO_PCM_KHZ_96		(1 << 8)
%define	HDAUDIO_PCM_KHZ_882		(1 << 7)
%define	HDAUDIO_PCM_KHZ_48		(1 << 6)
%define	HDAUDIO_PCM_KHZ_441		(1 << 5)
%define	HDAUDIO_PCM_KHZ_32		(1 << 4)
%define	HDAUDIO_PCM_KHZ_2205	(1 << 3)
%define	HDAUDIO_PCM_KHZ_16		(1 << 2)
%define	HDAUDIO_PCM_KHZ_11025	(1 << 1)
%define	HDAUDIO_PCM_KHZ_8		(1 << 0)


; Supported Stream formats (page 205)
%define HDAUDIO_STREAM_FT_MASK		0x07
%define	HDAUDIO_STREAM_FT_PCM		(1 << 0)
%define	HDAUDIO_STREAM_FT_FLOAT32	(1 << 1)
%define	HDAUDIO_STREAM_FT_AC3		(1 << 2)

; Pin Caps
%define	HDAUDIO_PIN_CAPS_HBR			(1 << 27)
%define	HDAUDIO_PIN_CAPS_DP				(1 << 24)
%define	HDAUDIO_PIN_CAPS_EAPD			(1 << 16)
%define	HDAUDIO_PIN_CAPS_VREF_CTRL		(0xFF << 8)
%define	HDAUDIO_PIN_CAPS_HDMI			(1 << 7)
%define	HDAUDIO_PIN_CAPS_BAL_IO			(1 << 6)
%define	HDAUDIO_PIN_CAPS_INP_CAP		(1 << 5)
%define	HDAUDIO_PIN_CAPS_OUTP_CAP		(1 << 4)
%define	HDAUDIO_PIN_CAPS_HEADPH_CAP		(1 << 3)
%define	HDAUDIO_PIN_CAPS_PRES_DET_CAP	(1 << 2)
%define	HDAUDIO_PIN_CAPS_TRIGGER_REQ	(1 << 1)
%define	HDAUDIO_PIN_CAPS_IMP_SENSE_CAP	(1 << 0)

; EAPD/BTL (page 167)
%define	HDAUDIO_EAPDBTL_BALANCED	(1 << 0)
%define	HDAUDIO_EAPDBTL_EAPD		(1 << 1)
%define	HDAUDIO_EAPDBTL_LRSWAP		(1 << 2)

; Amplifier Caps (page 207)
%define	HDAUDIO_AMP_CAPS_MUTE			(1 << 31)
%define	HDAUDIO_AMP_CAPS_STEPSIZE		(0x7F << 16)
%define	HDAUDIO_AMP_CAPS_STEPSIZE_SHIFT	16
%define	HDAUDIO_AMP_CAPS_NUMSTEPS		(0x7F << 8)
%define	HDAUDIO_AMP_CAPS_NUMSTEPS_SHIFT	8
%define	HDAUDIO_AMP_CAPS_OFFSET			(0x7F << 0)

; Connection List Length (page 208)
%define	HDAUDIO_CONN_LIST_LEN		(0x7F << 0)
%define	HDAUDIO_CONN_LIST_LEN_LONG	(1 << 7)

%define	HDAUDIO_CONN_LIST_ENTRY_RANGE	(1 << 7)
%define	HDAUDIO_CONN_LIST_NID			(0x7F << 0)

; Supported Power States
%define	HDAUDIO_PWR_STATE_EPSS			(1 << 31)
%define	HDAUDIO_PWR_STATE_CLKSTOP		(1 << 30)
%define	HDAUDIO_PWR_STATE_S3D3COLDSUP	(1 << 29)
%define	HDAUDIO_PWR_STATE_D3COLDSUP		(1 << 4)
%define	HDAUDIO_PWR_STATE_D3SUP			(1 << 3)
%define	HDAUDIO_PWR_STATE_D2SUP			(1 << 2)
%define	HDAUDIO_PWR_STATE_D1SUP			(1 << 1)
%define	HDAUDIO_PWR_STATE_D0SUP			(1 << 0)

; Processing Caps
%define	HDAUDIO_PROC_CAP_NUM_COEFF		(0xFF << 8)
%define	HDAUDIO_PROC_CAP_BENIGN			(1 << 0)

; GP I/O Count
%define HDAUDIO_GPIO_CNT_GPIWAKE		(1 << 31)
%define HDAUDIO_GPIO_CNT_GPIUNSOL		(1 << 30)
%define HDAUDIO_GPIO_CNT_NUMGPIS		(0xFF << 16)
%define HDAUDIO_GPIO_CNT_NUMGPOS		(0xFF << 8)
%define HDAUDIO_GPIO_CNT_NUMGPIOS		(0xFF << 0)

; Volume Knob Caps
%define	HDAUDIO_VOL_KNOB_CAP_DELTA		(1 << 7)
%define	HDAUDIO_VOL_KNOB_CAP_NUMSTEPS	(0x7F << 0)

; Command offsets
%define HDAUDIO_OFF_CMD_CAD		28
%define HDAUDIO_OFF_CMD_I		27
%define HDAUDIO_OFF_CMD_NID		20
%define HDAUDIO_OFF_CMD_VERB	8
%define HDAUDIO_OFF_CMD_PARM	0

; direction
%define	HDAUDIO_INPUT		0x00
%define	HDAUDIO_OUTPUT		0x01

HDAUDIO_MAX_CONN_LIST_LEN	equ	8	; currently only 2 connlistentry-DWORDs are used

HDAUDIO_MAX_WIDGET_NUM	equ 128		; max. 128 widgets for the time being	 (a widget is a node)

; to get the data of the widgets
%define HDAUDIO_WIDCAPS_IDX			0
%define HDAUDIO_SUPPSTRMFMT_IDX		1
%define HDAUDIO_SUPPPCMSIZE_IDX		2
%define HDAUDIO_PINCAPS_IDX			3
%define HDAUDIO_INPAMPCAPS_IDX		4
%define HDAUDIO_OUTPAMPCAPS_IDX		5
%define HDAUDIO_CONNLISTLEN_IDX		6
%define HDAUDIO_VOLKNOBCAPS_IDX		7
%define HDAUDIO_CONFIGDEF_IDX		8
%define HDAUDIO_CONNLSTENTCTRL_IDX	9
%define HDAUDIO_CONNLSTENTCTRL2_IDX	10
HDAUDIO_WIDGET_REQ_NUM	equ	11

HDAUDIO_DEF_GAIN	equ 0x3F


section .text


; ************** funcs for DETECTING and INITIALIZING

hdaudio_detect:
			cmp BYTE [pci_audio_detected], 1
			jnz	.Back
			xor eax, eax
			mov al, [pci_audio_bus]
			xor ebx, ebx
			mov bl, [pci_audio_dev]
			xor ecx, ecx
			mov cl, [pci_audio_fun]
			; Enable bus-master and memory-space (bit10 INTs !? 1:HDA INTs will be deasserted; 0: INTs may be asserted); (or ax, 1024)
			mov edx, 0x04
			push eax
			call pci_config_read_word
			or ax, 0x0006
			and ax, 0xFBFF					; clear bit 10 (to enable IRQs)
			mov WORD [pci_tmp], ax
			pop eax
			call pci_config_write_word

			; Select HDA if HDA and AC97 are shared
			mov edx, 0x40
			push eax
			call pci_config_read_byte
			or al, 0x01
			mov BYTE [pci_tmp], al
			pop eax
			call pci_config_write_byte
			; Save BAR
			mov edx, PCI_BAR0
			push eax
			call pci_config_read_dword
			mov edx, eax
			pop eax
			mov [hdaudio_base_bits4], edx
			and DWORD [hdaudio_base_bits4], 0x0F	
			and edx, ~0xF
			mov [hdaudio_bar_lo], edx
			test DWORD [xhci_base_bits4], 1
			jz	.Chk64
			mov ebx, hdaudio_NotMemMappedIOTxt
			call gstdio_draw_text
			jmp .Back
.Chk64		cmp DWORD [hdaudio_base_bits4], 0x04
			jne	.ClrTCSEL
			; get upper 32bits of base0
			push eax
			mov edx, PCI_BAR1
			call pci_config_read_dword
			mov edx, eax
			pop eax
			cmp edx, 0
			je	.ClrTCSEL
			mov ebx, hdaudio_64bitBase0Txt
			call gstdio_draw_text
			jmp .Back
			; Clear TCSEL
.ClrTCSEL	mov edx, 0x44					; TCSEL-reg
			push eax
			call pci_config_read_byte
			and al, ~0x07
			mov BYTE [pci_tmp], al
			pop eax
			call pci_config_write_byte

			; Should we enable snooping for several NVIDIA and Intel devices!?

			mov BYTE [hdaudio_detected], 1
.Back		ret


; FORTH WORD
hdaudio_init_controller:
			pushad
			call hdaudio_reset_controller
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			; init CORB/RIRB
			mov ebx, [hdaudio_bar_lo]
			; CORB
;.ChkCORB	mov dl, [ebx+HDAUDIO_CORBCTL_OFFS]
;			test dl, 2			; CORB-DMA is running?
;			jz	.Save64OK
;			and dl, 0xFD
;			mov [ebx+HDAUDIO_CORBCTL_OFFS], dl
;			jmp .ChkCORB
.Save64OK	xor edx, edx
			mov dx, [ebx+HDAUDIO_GCAP_OFFS]
			mov BYTE [hdaudio_64ok], 0
			test dx, 1
			jz	.ChkOutpN
			mov BYTE [hdaudio_64ok], 1
.ChkOutpN 	mov eax, edx
			and eax, 0x0F << 12
			jnz	.GetOBase
			mov ebx, hdaudio_OutputStreamsNotSuppErrTxt
			call gstdio_draw_text
			jmp .Back
.GetOBase	and edx, 0x0F << 8
			shr edx, 8
			mov [hdaudio_input_cnt], edx
			; Output0 (80h+(ISS*20h), ISS is the number of input-streams in GCAP)
			shl edx, 5							; * 0x20
			add edx, HDAUDIO_INPUT_BASE
			mov [hdaudio_output_base], edx
			; Size
.InitCORB	mov dl, [ebx+HDAUDIO_CORBSIZE_OFFS]
			mov al, dl
				; is there only one size? (then Read-only)
			and al, 0x70
			and al, 0x40
			jnz	.Set256C
			mov al, dl
			and al, 0x20
			jnz	.Set16C
			mov al, dl
			and al, 0x10
			jnz	.Set2C
			mov BYTE [hdaudio_error], 1
			mov ebx, hdaudio_InitErrorTxt
			call gstdio_draw_text
			jmp .Back
.Set256C	mov BYTE [hdaudio_corb_size], 256-1
			and dl, 3
			or	dl, 2
			mov [ebx+HDAUDIO_CORBSIZE_OFFS], dl
			jmp .CORBPtrs
.Set16C		mov BYTE [hdaudio_corb_size], 16-1
			and dl, 3
			or	dl, 1
			mov [ebx+HDAUDIO_CORBSIZE_OFFS], dl
			jmp .CORBPtrs
.Set2C		mov BYTE [hdaudio_corb_size], 2-1
			and dl, 3
			mov [ebx+HDAUDIO_CORBSIZE_OFFS], dl

				; RP
.CORBPtrs	mov dx, [ebx+HDAUDIO_CORBRP_OFFS]
			or	dx, 0x8000
			mov [ebx+HDAUDIO_CORBRP_OFFS], dx
				; check if reset is completed
			push ebx
			mov ebx, 10
			call pit_delay
			pop ebx
.ChkRRes	mov dx, [ebx+HDAUDIO_CORBRP_OFFS]
			test dx, 0x8000	
			jnz	.SetR0
			mov BYTE [hdaudio_error], 1
			mov ebx, hdaudio_ResetRPErrorTxt
			call gstdio_draw_text
			jmp .Back

.SetR0		mov dx, [ebx+HDAUDIO_CORBRP_OFFS]
			and	dx, 0x7FFF
			mov [ebx+HDAUDIO_CORBRP_OFFS], dx
				; check if bit is zero
			mov dx, [ebx+HDAUDIO_CORBRP_OFFS]
			and dx, 0x8000
			jz	.DoWP
			mov BYTE [hdaudio_error], 1
			mov ebx, hdaudio_ResetRPErrorTxt
			call gstdio_draw_text
			jmp .Back

				; WP
.DoWP		mov BYTE [ebx+HDAUDIO_CORBWP_OFFS], 0		; BYTE write to a WORD sizes register, because the upper byte is RsvdP
				; set buffer-address
			mov DWORD [ebx+HDAUDIO_CORBLBASE_OFFS], HDAUDIO_CORB_BUFF
			cmp BYTE [hdaudio_64ok], 1
			jne	.DisIRQ
			mov DWORD [ebx+HDAUDIO_CORBUBASE_OFFS], 0
				; disable Memory Error interrupts (CMEIE)
.DisIRQ		mov dl, [ebx+HDAUDIO_CORBCTL_OFFS]
			and dl, 0xFE
			mov [ebx+HDAUDIO_CORBCTL_OFFS], dl

			; RIRB Size
.InitRIRB	mov dl, [ebx+HDAUDIO_RIRBSIZE_OFFS]
			mov al, dl
				; is there only one size? (then Read-only)
			and al, 0x70
			and al, 0x40
			jnz	.Set256R
			mov al, dl
			and al, 0x20
			jnz	.Set16R
			mov al, dl
			and al, 0x10
			jnz	.Set2R
			mov BYTE [hdaudio_error], 1
			mov ebx, hdaudio_InitErrorTxt
			call gstdio_draw_text
			jmp .Back
.Set256R	mov BYTE [hdaudio_rirb_size], 256-1
			and dl, 3
			or	dl, 2
			mov [ebx+HDAUDIO_RIRBSIZE_OFFS], dl
			jmp .RIRBPtrs
.Set16R		mov BYTE [hdaudio_rirb_size], 16-1
			and dl, 3
			or	dl, 1
			mov [ebx+HDAUDIO_RIRBSIZE_OFFS], dl
			jmp .RIRBPtrs
.Set2R		mov BYTE [hdaudio_rirb_size], 2-1
			and dl, 3
			mov [ebx+HDAUDIO_RIRBSIZE_OFFS], dl

				; WP
.RIRBPtrs	mov dx, [ebx+HDAUDIO_RIRBWP_OFFS]
			or	dx, 0x8000
			mov [ebx+HDAUDIO_RIRBWP_OFFS], dx
				; RP
			mov BYTE [hdaudio_rirb_wp], 0		
				; set buffer-address
			mov DWORD [ebx+HDAUDIO_RIRBLBASE_OFFS], HDAUDIO_RIRB_BUFF
			cmp BYTE [hdaudio_64ok], 1
			jne	.DisIRQ2
			mov DWORD [ebx+HDAUDIO_RIRBUBASE_OFFS], 0
				; disable interrupts
.DisIRQ2	mov dl, [ebx+HDAUDIO_RIRBCTL_OFFS]
			and dl, 0xFA
			mov [ebx+HDAUDIO_RIRBCTL_OFFS], dl

			; disable interrupts
			mov ax, [ebx+HDAUDIO_WAKEEN_OFFS]
			and ax, 0x8000
			mov [ebx+HDAUDIO_WAKEEN_OFFS], ax
			mov DWORD [ebx+HDAUDIO_INTCTL_OFFS], 0

			; clear status-bits
				; CORBSTS
			mov dl, [ebx+HDAUDIO_CORBSTS_OFFS]
			or	dl, 1
			mov [ebx+HDAUDIO_CORBSTS_OFFS], dl
				; RIRBSTS
			mov dl, [ebx+HDAUDIO_RIRBSTS_OFFS]
			or	dl, 5
			mov [ebx+HDAUDIO_RIRBSTS_OFFS], dl
				; Streams
			mov eax, [hdaudio_output_base]
			mov dl, [ebx+eax+HDAUDIO_SD0STS_OFFS]
			or	dl, 0x1C
			mov [ebx+eax+HDAUDIO_SD0STS_OFFS], dl

			; enable unsolicited responses
;			mov edx, [ebx+HDAUDIO_GCTL_OFFS]
;			or	edx, (1 << 8)
;			mov [ebx+HDAUDIO_GCTL_OFFS], edx

			; start CORB/RIRB
			mov dl, [ebx+HDAUDIO_CORBCTL_OFFS]
			or	dl, 2
			mov [ebx+HDAUDIO_CORBCTL_OFFS], dl			; "Must read the value back" !?
			mov dl, [ebx+HDAUDIO_RIRBCTL_OFFS]
			or	dl, 2
			mov [ebx+HDAUDIO_RIRBCTL_OFFS], dl

			; stream
			call hdaudio_stream_reset
			cmp BYTE [hdaudio_error], 0
			jnz	.Back

			mov DWORD [hdaudio_mutegain], 0					; currently muteandgain is stored in it

		; codec, widgets
			call hdaudio_get_codecs_data
			cmp BYTE [hdaudio_error], 0
			jz	.GetStFmt
			mov BYTE [hdaudio_error], 1
			mov ebx, hdaudio_InitErrorTxt
			call gstdio_draw_text
			jmp .Back

.GetStFmt	call hdaudio_get_afg_supported_stream_fmt
			cmp BYTE [hdaudio_error], 0
			jz	.GetPCMFmt
			mov ebx, hdaudio_GetSuppStreamFmtErrTxt
			call gstdio_draw_text
			jmp .Back
.GetPCMFmt	call hdaudio_get_afg_supported_pcm_fmt
			cmp BYTE [hdaudio_error], 0
			jz	.Ok
			mov ebx, hdaudio_GetSuppPCMFmtErrTxt
			call gstdio_draw_text
			jmp .Back
.Ok			mov BYTE [hdaudio_inited], 1
.Back		popad
			ret


; IN: -
; OUT: hdaudio_error(0 if ok)
hdaudio_reset_controller:
			mov BYTE [hdaudio_error], 0
			mov ebx, [hdaudio_bar_lo]
			mov dl, [ebx+HDAUDIO_CORBCTL_OFFS]
			test dl, 2			; CORB-DMA is running?
			jz	.RIRB
			and dl, 0xFD
			mov [ebx+HDAUDIO_CORBCTL_OFFS], dl
.RIRB		mov dl, [ebx+HDAUDIO_RIRBCTL_OFFS]
			test dl, 2			; RIRB-DMA is running?
			jz	.ChkCORB
			and dl, 0xFD
			mov [ebx+HDAUDIO_RIRBCTL_OFFS], dl
			mov ecx, 10
.ChkCORB	mov dl, [ebx+HDAUDIO_CORBCTL_OFFS]
			test dl, 2			; CORB-DMA is running?
			jz	.DoRIRB
			push ebx
			mov ebx, 1
			call pit_delay
			pop ebx
			loop .ChkCORB
			mov BYTE [hdaudio_error], 1
			mov ebx, hdaudio_ResetCORBFailedTxt	
			call gstdio_draw_text
			ret
.DoRIRB		mov ecx, 10
.ChkRIRB	mov dl, [ebx+HDAUDIO_RIRBCTL_OFFS]
			test dl, 2			; RIRB-DMA is running?
			jz	.ResetCtrl
			push ebx
			mov ebx, 1
			call pit_delay
			pop ebx
			loop .ChkRIRB
			mov BYTE [hdaudio_error], 1
			mov ebx, hdaudio_ResetRIRBFailedTxt	
			call gstdio_draw_text
			ret
			; set CRST-bit to 1 (to leave Reset-state)
;			mov ebx, [hdaudio_bar_lo]
;			mov edx, [ebx+HDAUDIO_GCTL_OFFS]
;			or	edx, 1
;			mov [ebx+HDAUDIO_GCTL_OFFS], edx
;.ResChk		mov edx, [ebx+HDAUDIO_GCTL_OFFS]
;			and edx, 1
;			jz	.ResChk
;			mov ebx, 10			; wait at least 1 ms after CRST-bit changed
;			call pit_delay

			; reset controller
.ResetCtrl	mov ebx, [hdaudio_bar_lo]
			mov edx, [ebx+HDAUDIO_GCTL_OFFS]
			and	edx, 0xFFFFFFFE
			mov [ebx+HDAUDIO_GCTL_OFFS], edx
			mov ecx, 10
.ResChk2	mov edx, [ebx+HDAUDIO_GCTL_OFFS]
			and edx, 1
			jz	.Wait10
			push ebx
			mov ebx, 1
			call pit_delay
			pop ebx
			loop .ResChk2
			mov BYTE [hdaudio_error], 1
			mov ebx, hdaudio_ResetControllerFailed1Txt	
			call gstdio_draw_text
			ret

.Wait10		mov ebx, 10			; wait at least 1 ms after CRST-bit changed (IT WAS 100, AND IT WORKED ON NETBOOK)
			call pit_delay

			; set CRST-bit to 1 (to leave Reset-state)
.SetCRST	mov ebx, [hdaudio_bar_lo]
			mov edx, [ebx+HDAUDIO_GCTL_OFFS]
			or	edx, 1
			mov [ebx+HDAUDIO_GCTL_OFFS], edx
			mov ecx, 10
.ResChk3	mov edx, [ebx+HDAUDIO_GCTL_OFFS]
			and edx, 1
			jnz	.Wait10_2
			push ebx
			mov ebx, 1	
			call pit_delay
			pop ebx
			loop .ResChk3
			mov BYTE [hdaudio_error], 1
			mov ebx, hdaudio_ResetControllerFailed2Txt	
			call gstdio_draw_text
			ret
.Wait10_2	mov ebx, 10			; wait at least 1 ms after CRST-bit changed
			call pit_delay
.SetMask	mov ebx, [hdaudio_bar_lo]
			mov dx, [ebx+HDAUDIO_STATESTS_OFFS]
			and dx, 0x7FFF
			mov [hdaudio_codecs_mask], dx
			ret


; ******************* funcs of CORB/RIRB

; IN: EAX(cmd)
; Writes a command-DWORD to CORB, one at a time, so needs to be called several times to write several cmds
hdaudio_write_cmd:
			pushad
			mov ebx, [hdaudio_bar_lo]
			mov cx, [ebx+HDAUDIO_CORBWP_OFFS]	; bits 15:8 are RsvdP
			cmp cl, [hdaudio_corb_size]
			jnz	.SkipRollO
			mov	cl, 0
			jmp .Store
.SkipRollO	inc cl
.Store		xor edx, edx
			mov dl, cl
			shl edx, 2							; *4 to get bytes from WP
			mov [HDAUDIO_CORB_BUFF+edx], eax
			mov [ebx+HDAUDIO_CORBWP_OFFS], cx
			; wait !?
.Chk		mov cx, [ebx+HDAUDIO_CORBWP_OFFS]
			mov dx, [ebx+HDAUDIO_CORBRP_OFFS]
			cmp cl, dl
			jnz	.Chk
			popad
			ret


; OUT: ECX(space, i.e. number of free entries)
hdaudio_get_corb_space:
			push eax
			push ebx
			push edx
			mov ebx, [hdaudio_bar_lo]
			mov cx, [ebx+HDAUDIO_CORBWP_OFFS]	; bits 15:8 are RsvdP
			mov dx, [ebx+HDAUDIO_CORBRP_OFFS]	; bits7:0 is ptr
			and ecx, 0xFF
			and edx, 0xFF
			sub ecx, edx
			jns	.Pos
			; Neg
			neg ecx
			jmp .Back
.Pos		xor eax, eax
			mov al, [hdaudio_corb_size]
			sub eax, ecx
			mov ecx, eax
.Back		pop edx
			pop ebx
			pop eax
			ret


; Checks CMEI-bit (bit0) in CORBSTS to see if there was an error
; OUT: EDX(bit0 is 1 if error)
hdaudio_chk_cmei:
			push ebx
			xor edx, edx
			mov ebx, [hdaudio_bar_lo]
			mov dl, [ebx+HDAUDIO_CORBSTS_OFFS]
			and dl, 1
			pop ebx
			ret


; Checks RIRBOIS-bit (bit2) in RIRBSTS to see if there was an overrun
; OUT: EDX(bit0 is 1 if error)
hdaudio_chk_rirbois:
			push ebx
			xor edx, edx
			mov ebx, [hdaudio_bar_lo]
			mov dl, [ebx+HDAUDIO_RIRBSTS_OFFS]
			and dl, 4
			shr	edx, 2
			pop ebx
			ret


; OUT: EAX(response, verb); ECX(responseextended)
; reads a response (2 DWORDS) at a time from RIRB, so needs to be called several times to read several responses
; RIRB contains 256 * 2-DWORD entries if buffsize is 256
; When writing a SET cmd, the response(EAX) will contain the nodeId
hdaudio_read_resp:
			push ebx
			push edx
			xor edx, edx
			mov dl, [hdaudio_rirb_wp]
			mov ebx, [hdaudio_bar_lo]
.Chk		mov cx, [ebx+HDAUDIO_RIRBWP_OFFS]	; bits 14:8 are RsvdP, bit15 is Reset Ptr
			cmp dl, cl
			jz	.Chk							; POLL
			; read
			cmp dl, [hdaudio_rirb_size]
			jnz	.SkipRollO
			mov	dl, 0
			jmp .Store
.SkipRollO	inc dl
.Store		mov [hdaudio_rirb_wp], dl
			shl edx, 3							; *8 to get bytes from RP
			mov eax, [HDAUDIO_RIRB_BUFF+edx]
			mov ecx, [HDAUDIO_RIRB_BUFF+edx+4]
.Back		pop edx
			pop ebx
			ret


; IN: EAX(CAd 4 LSBs), EBX(I), ECX(NID), EDX(Verb), EBP(param)
; OUT: EAX(cmd)
hdaudio_make_cmd:
			push ebx
			push ecx
			push edx
			push ebp
			shl	eax, HDAUDIO_OFF_CMD_CAD
			shl ebx, HDAUDIO_OFF_CMD_I
			or	eax, ebx
			shl ecx, HDAUDIO_OFF_CMD_NID
			or	eax, ecx
			shl	edx, HDAUDIO_OFF_CMD_VERB
			or	eax, edx
			shl ebp, HDAUDIO_OFF_CMD_PARM
			or	eax, ebp
			pop ebp
			pop edx
			pop ecx
			pop ebx
			ret


; IN: ECX(NID), EDX(Verb), EBP(param)
; OUT: EAX(response, verb); ECX(responseextended)
hdaudio_send_cmd:
			push ebx
			mov BYTE [hdaudio_error], 0
			mov eax, [hdaudio_codec_id]
			mov ebx, 0
; IN: EAX(CAd 4 LSBs), EBX(I), ECX(NID), EDX(Verb), EBP(param)
; OUT: EAX(cmd)
			call hdaudio_make_cmd
; IN: EAX(cmd)
; Writes a command-DWORD to CORB, one at a time, so needs to be called several times to write several cmds
			call hdaudio_write_cmd
			; check error
; Checks CMEI-bit (bit0) in CORBSTS to see if there was an error
; OUT: EDX(bit0 is 1 if error)
			call hdaudio_chk_cmei
			cmp edx, 1
			jnz	.Poll
			mov BYTE [hdaudio_error], 1
%ifdef DEBUG_SETTINGS
			mov ebx, hdaudio_DbgSendCmdErrorTxt
			call gstdio_draw_text
%endif
			jmp .Back
			; poll response
; OUT: EAX(response, verb); ECX(responseextended)
; reads a response (2 DWORDS) at a time from RIRB, so needs to be called several times to read several responses
; RIRB contains 256 * 2-DWORD entries if buffsize is 256
; When writing a SET cmd, the response(EAX) will contain the nodeId
.Poll		call hdaudio_read_resp
.Back		pop ebx
			ret


; ************** funcs of STREAM
; IN: - 
; OUT: hdaudio_error(0 if ok)
hdaudio_stream_reset:
			pushad
			call hdaudio_stream_clear
			; set reset-bit
			mov ebx, [hdaudio_bar_lo]
			mov edx, [hdaudio_output_base]
			mov eax, [ebx+edx+HDAUDIO_SD0CTL_OFFS]
			or	eax, 1
			mov [ebx+edx+HDAUDIO_SD0CTL_OFFS], eax
			push ebx
			mov ebx, 10											; wait 10 ms
			call pit_delay
			pop ebx
			; check if bit is 1
			mov ecx, 300
.ChkRes1	mov eax, [ebx+edx+HDAUDIO_SD0CTL_OFFS]
			test eax, 1
			jnz	.Delay
			dec ecx
			jnz	.ChkRes1
			mov ebx, hdaudio_ResetStreamErrorTxt
			call gstdio_draw_text
			mov BYTE [hdaudio_error], 1
			jmp .Back
.Delay		push ebx
			mov ebx, 10											; wait 10 ms
			call pit_delay
			pop ebx
			; clear reset-bit
			mov eax, [ebx+edx+HDAUDIO_SD0CTL_OFFS]
			and	eax, 0xFFFFFFFE
			mov [ebx+edx+HDAUDIO_SD0CTL_OFFS], eax
			push ebx
			mov ebx, 10											; wait 10 ms
			call pit_delay
			pop ebx
			; check if bit is 0
			mov ecx, 300
.ChkRes0	mov eax, [ebx+edx+HDAUDIO_SD0CTL_OFFS]					; or a 300-cycle-TO here, then exit!?
			test eax, 1
			jz	.Delay2
			dec ecx
			jnz	.ChkRes0
			mov ebx, hdaudio_ResetStreamErrorTxt
			call gstdio_draw_text
			mov BYTE [hdaudio_error], 1
			jmp .Back
.Delay2		push ebx
			mov ebx, 10											; wait 10 ms
			call pit_delay
			pop ebx
			; reset position buffer
			mov edx, HDAUDIO_DPL_BUFF
			mov ecx, 32
.ClearNext	mov DWORD [edx], 0
			add edx, 4
			loop .ClearNext
.Back		popad
			ret


hdaudio_stream_clear:
			pushad
			mov ebx, [hdaudio_bar_lo]
			mov edx, [hdaudio_output_base]
			mov eax, [ebx+edx+HDAUDIO_SD0CTL_OFFS]
			and	eax, 0xFFFFFFE0									; clear RUN-bit and IRQs
			mov [ebx+edx+HDAUDIO_SD0CTL_OFFS], eax
			popad
			ret


; IN: ECX(nodeID of DAC)
; set converter stream, channel
; set format of converter (DAC)
hdaudio_set_converter_stream:
			pushad
			; set converter stream, channel
			mov edx, HDAUDIO_CMD_SET_STREAM_CONV_CTRL
			mov	ebp, 0x10				; stream1 and channel0
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			push ecx
			call hdaudio_send_cmd
			pop ecx
			cmp BYTE [hdaudio_error], 0
			jnz	.Back

			; wait 1ms
			mov ebx, 1
			call pit_delay

			; set format of converter (DAC)
			mov edx, HDAUDIO_CMD_SET_CONV_FORMAT
			xor ebp, ebp
			mov	bp, [hdaudio_format]			; same as in _play for stream
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
.Back		popad
			ret


; ************* IRQ

hdaudio_handle_irq:
			pushad

			cmp BYTE [hdaudio_inited], 1
			jnz	.Back
			mov ebx, [hdaudio_bar_lo]
			mov edx, [hdaudio_output_base]
			mov al, [ebx+edx+HDAUDIO_SD0STS_OFFS]
			and al, 0x3C			; clear reserved bits
			test al, 0x04			; Buffer Completion Interrupt Status ?
			jz	.Clear	

			mov eax, [ebx+HDAUDIO_INTSTS_OFFS]
			mov edx, 1
			mov ecx, [hdaudio_input_cnt]
			shl edx, cl
			test eax, edx			; first Output Stream irq ?
			jz	.Clear

			cmp BYTE [hdaudio_data_copied], 1
			jnz	.CopyChk
			dec WORD [hdaudio_pcm_part_max]
			jz	.Stop
			jmp .Clear

.CopyChk	inc WORD [hdaudio_pcm_part]
			mov ax, [hdaudio_pcm_part]
			cmp ax, [hdaudio_pcm_part_max]
			jg	.Stop

			mov esi, [hdaudio_pcm_addr]
			xor eax, eax
			mov ax, [hdaudio_pcm_part]
			mov ebx, HDAUDIO_BUFF_LEN
			mul ebx
			add esi, eax
			mov edi, HDAUDIO_BUFF_ADDR
			xor eax, eax
			mov al, BYTE [hdaudio_buff_num]	
			mov ebx, HDAUDIO_BUFF_LEN
			mul ebx
			add edi, eax
			mov ecx, HDAUDIO_BUFF_LEN
			shr	ecx, 1							; to WORDS
			rep movsw

			inc BYTE [hdaudio_buff_num]
			xor edx, edx
			xor eax, eax
			mov al, BYTE [hdaudio_buff_num]		; buff_num %= HDAUDIO_BDL_ENTRY_NUM
			mov ebx, HDAUDIO_BDL_ENTRY_NUM
			div ebx
			mov [hdaudio_buff_num], dl
			jmp .Clear

.Stop		call hdaudio_stop

			; clear IRQ-bits
.Clear		mov ebx, [hdaudio_bar_lo]
			mov edx, [hdaudio_output_base]
			mov al, [ebx+edx+HDAUDIO_SD0STS_OFFS]
			and al, 0x3C						; clear reserved bits
			mov [ebx+edx+HDAUDIO_SD0STS_OFFS], al

.Back		popad
			ret


; ************* PLAY

;FORTH-WORD
; IN: EAX(PCM-address), EBX(lengthInBytes), ECX(format)
hdaudio_play:
			pushad
			cmp BYTE [hdaudio_inited], 1
			jnz	.Back

			mov [hdaudio_format], cx

			mov [hdaudio_pcm_addr], eax
			mov [hdaudio_pcm_len], ebx
			mov eax, ebx
			mov ebx, HDAUDIO_BUFF_LEN
			xor edx, edx
			div ebx
			cmp edx, 0
			jz	.StoreVal
			inc	eax
.StoreVal	mov WORD [hdaudio_pcm_part_max], ax
			inc WORD [hdaudio_pcm_part_max]				; it played 1 buffer less

			; clear buffer
			mov eax, 0
			mov edi, HDAUDIO_BUFF_ADDR
			mov ecx, HDAUDIO_BUFF_LEN*HDAUDIO_BDL_ENTRY_NUM
			shr	ecx, 2									; to get DWORDS
			rep stosd

			cmp WORD [hdaudio_pcm_part_max], HDAUDIO_BDL_ENTRY_NUM
			jg	.CopyPart

			; copy all
			mov esi, [hdaudio_pcm_addr]
			mov edi, HDAUDIO_BUFF_ADDR
			mov ecx, [hdaudio_pcm_len]
			shr	ecx, 1									; to WORDS
			rep movsw

			mov BYTE [hdaudio_data_copied], 1			; all of the data is copied (fit in buffers)
			jmp .Init
.CopyPart	mov esi, [hdaudio_pcm_addr]
			mov edi, HDAUDIO_BUFF_ADDR
			mov ecx, HDAUDIO_BUFF_LEN*HDAUDIO_BDL_ENTRY_NUM
			shr	ecx, 1									; to WORDS
			rep movsw
			mov BYTE [hdaudio_data_copied], 0
			mov WORD [hdaudio_pcm_part], HDAUDIO_BDL_ENTRY_NUM-1
			mov BYTE [hdaudio_buff_num], 0

.Init		mov BYTE [hdaudio_error], 0

			mov ebx, [hdaudio_bar_lo]

			; stop engines
				; DMA-positions to RAM
			mov eax, [ebx+HDAUDIO_DPIBLBASE_OFFS]		; clear bit0 to stop the controller to write DMA positions to RAM
			and	eax, 0xFFFFFFFE
			mov [ebx+HDAUDIO_DPIBLBASE_OFFS], eax
			cmp BYTE [hdaudio_64ok], 1
			jne	.StreamRes
			mov DWORD [ebx+HDAUDIO_DPIBUBASE_OFFS], 0
.StreamRes	call hdaudio_stream_reset	; _clear
			cmp BYTE [hdaudio_error], 0
			jnz	.Back

			mov edx, [hdaudio_output_base]
			; Set stream as output, and set streamId as 1
			mov eax, [ebx+edx+HDAUDIO_SD0CTL_OFFS]
			and	eax, 0x00FFFFFF
; !!BIT19 IS READONLY FOR NON-BIDIR ENGINES!!
			or	eax, (0x18 << 16)
			mov [ebx+edx+HDAUDIO_SD0CTL_OFFS], eax			; I/O needs to be set before any other stream-regs!!

	; to vars, or: a register and OR it
			; SDnFMT (Stream format)
			mov ax, [ebx+edx+HDAUDIO_SD0FMT_OFFS]
			and	ax, 0x0080								; clear everything except reserved-bits  !?
			or	ax, [hdaudio_format]
			mov [ebx+edx+HDAUDIO_SD0FMT_OFFS], ax

			; CBL
			mov DWORD [ebx+edx+HDAUDIO_SD0CBL_OFFS], HDAUDIO_BDL_ENTRY_NUM*HDAUDIO_BUFF_LEN 

			; LVI
			mov ax, [ebx+edx+HDAUDIO_SD0LVI_OFFS]
			and ax, 0xFF00
			or	ax, HDAUDIO_BDL_ENTRY_NUM-1
			mov [ebx+edx+HDAUDIO_SD0LVI_OFFS], ax

			; BDL
			mov DWORD [ebx+edx+HDAUDIO_SD0BDPL_OFFS], HDAUDIO_BDL_BUFF
			cmp BYTE [hdaudio_64ok], 1
			jne	.AddEntries
			mov DWORD [ebx+edx+HDAUDIO_SD0BDPU_OFFS], 0	
.AddEntries	xor ecx, ecx
			mov eax, HDAUDIO_BDL_BUFF
			mov edx, HDAUDIO_BUFF_ADDR
.NextBuff	mov [eax], edx
			mov DWORD [eax+4], 0
			mov DWORD [eax+8], HDAUDIO_BUFF_LEN			; length
			mov DWORD [eax+12], 1						; IOC
			add eax, 16
			add edx, HDAUDIO_BUFF_LEN
			inc ecx
			cmp ecx, HDAUDIO_BDL_ENTRY_NUM
			jc	.NextBuff

			; DPLBASE
			mov eax, HDAUDIO_DPL_BUFF
			or	eax, 1									; set bit0 to have the controller to write DMA positions to RAM
			mov [ebx+HDAUDIO_DPIBLBASE_OFFS], eax
			cmp BYTE [hdaudio_64ok], 1
			jne	.SetPwr
			mov DWORD [ebx+HDAUDIO_DPIBUBASE_OFFS], 0
.SetPwr		mov ecx, [hdaudio_afg_id]
			mov ebx, HDAUDIO_POWER_STATE_D0
			call hdaudio_set_power_state
			cmp BYTE [hdaudio_error], 0
			jz	.Parse
			mov ebx, hdaudio_SetPwrStateErrTxt
			call gstdio_draw_text
			jmp .Back
			; shouldn't we get codecs_data again after set_power !?

.Parse		call hdaudio_parse_output
;		call hdaudio_print_out_path				;
;		call hdaudio_print_hp_path				;
;call gutil_press_a_key
	%ifdef DEBUGPARSE
		jmp .Back
	%endif

; Test tree for my EeePC
; Comments on the right are from the hdaudio_print_settings function
;mov BYTE [hdaudio_tree_out_path], 0x14		; 0	; PinComplex, AllGain=0,       ConnIdx=0, EAPDSet (InpAmpCaps:0, OutpAmpCaps:80000000)
;mov BYTE [hdaudio_tree_out_path+1], 0x0C	; 1	; Mixer, 	  GainInpR/L=0x80, ConnIdx=1		  (InpAmpCaps:80000000, OutpAmpCaps:0)
;mov BYTE [hdaudio_tree_out_path+2], 0x0B	; 2	; Mixer,	  GainInpR/L=0x97, ConnIdx=2		  (InpAmpCaps:80051F17, OutpAmpCaps:0)
;mov BYTE [hdaudio_tree_out_path+3], 0x1A	; 1	; PinComplex, GainInpR/L=0x03, ConnIdx=1	  	  (InpAmpCaps:002F0300, OutpAmpCaps:8..0)
;mov BYTE [hdaudio_tree_out_path+4], 0x0D	; 0	; Mixer, 	  AllGain=0,       ConnIdx=0		  (InpAmpCaps:80000000, OutpAmpCaps:0)
;mov BYTE [hdaudio_tree_out_path+5], 0x03	; 	; DAC, 		  GainOutpR/L=0x0F
;mov BYTE [hdaudio_tree_out_depth], 6
; Defaults (without setting):
; 0x14: GainOutpR/L=0x80
; 0x0C: GainInpR/L=0x80
; 0x0B: GainInpR/L=0x97
; 0x1A: GainOutpR/L=0x80
; 0x0D: AllGain=0
; 0x03: GainOutpR/L=0x57


			call hdaudio_prepare_afg
			cmp BYTE [hdaudio_error], 0
			jz	.Tree
			mov ebx, hdaudio_PrepareAFGErrTxt
			call gstdio_draw_text
			jmp .Back

.Tree		xor edx, edx
			cmp BYTE [hdaudio_tree_out_depth], 0
			jz	.HP
			mov dl, [hdaudio_tree_out_depth]
			mov ebx, hdaudio_tree_out_path
			; unmute etc
			call hdaudio_prepare_path
			cmp BYTE [hdaudio_error], 0
			jz	.HP
			mov ebx, hdaudio_PreparePathErrTxt
			call gstdio_draw_text
			jmp .Back
.HP			cmp BYTE [hdaudio_tree_hp_depth], 0
			jz	.SetKnob
			mov dl, [hdaudio_tree_hp_depth]
			mov ebx, hdaudio_tree_hp_path
			; unmute etc
			call hdaudio_prepare_path
			cmp BYTE [hdaudio_error], 0
			jz	.SetKnob
			mov ebx, hdaudio_PreparePathErrTxt
			call gstdio_draw_text
			jmp .Back
.SetKnob	cmp BYTE [hdaudio_tree_out_depth], 0
			jz	.Back
			call hdaudio_prepare_knob
			cmp BYTE [hdaudio_error], 0
			jz	.SetConv
			mov ebx, hdaudio_PrepareKnobErrTxt
			call gstdio_draw_text
			jmp .Back
			; set format of converter (DAC)
			; set converter stream, channel
.SetConv	xor ecx, ecx
			xor edx, edx
			cmp BYTE [hdaudio_tree_out_depth], 0
			jz	.HPStream
			mov dl, [hdaudio_tree_out_depth]
			mov ebx, hdaudio_tree_out_path
			dec edx
			mov cl, [ebx+edx]								; DAC-widget is the very last one in the path
			call hdaudio_set_converter_stream
			cmp BYTE [hdaudio_error], 0
			jz	.HPStream
			mov ebx, hdaudio_SetConvStreamErrTxt
			call gstdio_draw_text
			jmp .Back
.HPStream	cmp BYTE [hdaudio_tree_hp_depth], 0
			jz	.Start
			mov dl, [hdaudio_tree_hp_depth]
			mov ebx, hdaudio_tree_hp_path
			dec edx
			mov cl, [ebx+edx]								; DAC-widget is the very last one in the path
			call hdaudio_set_converter_stream
			cmp BYTE [hdaudio_error], 0
			jz	.Start
			mov ebx, hdaudio_SetConvStreamErrTxt
			call gstdio_draw_text
			jmp .Back

.Start:
%ifdef DEBUG_SETTINGS
		call hdaudio_print_settings
%endif
			mov ebx, [hdaudio_bar_lo]

			; set interrupts
			or	WORD [ebx+HDAUDIO_WAKEEN_OFFS], 0x7FFF
; !!!! EXACT ISS-NUM FROM GCAPS!!!!!
			mov DWORD [ebx+HDAUDIO_INTCTL_OFFS], 0x800000F0	; 4 ISS is the first 4 bits, next 4 is the 4 OSS
			; Start stream
			mov edx, [hdaudio_output_base]
			mov eax, [ebx+edx+HDAUDIO_SD0CTL_OFFS]
			and	eax, 0x000CFFE0
			or	eax, 0x0010001C								; set stream1 and IRQs 
			or	eax, 0x00000002								; set RUN-bit
			mov [ebx+edx+HDAUDIO_SD0CTL_OFFS], eax

.Back		popad
			ret


;FORTH-WORD
hdaudio_stop:
			pushad
			cmp BYTE [hdaudio_inited], 1
			jnz	.Back
			mov ebx, [hdaudio_bar_lo]
			; disable interrupts
			and WORD [ebx+HDAUDIO_WAKEEN_OFFS], 0x8000
			mov DWORD [ebx+HDAUDIO_INTCTL_OFFS], 0
			call hdaudio_stream_clear						; STOP
.Back		popad
			ret


hdaudio_pause:
			pushad
			cmp BYTE [hdaudio_inited], 1
			jnz	.Back
			mov BYTE [hdaudio_paused], 1
			mov ebx, [hdaudio_bar_lo]
			mov edx, [hdaudio_output_base]
			mov eax, [ebx+edx+HDAUDIO_SD0CTL_OFFS]
			and	eax, 0x00FFFFFD								; clear run-bit
			mov [ebx+edx+HDAUDIO_SD0CTL_OFFS], eax

			; disable interrupts
			and WORD [ebx+HDAUDIO_WAKEEN_OFFS], 0x8000
			mov DWORD [ebx+HDAUDIO_INTCTL_OFFS], 0
.Back		popad
			ret


hdaudio_resume:
			pushad
			cmp BYTE [hdaudio_inited], 1
			jnz	.Back
			cmp BYTE [hdaudio_paused], 1
			jnz	.Back
			mov BYTE [hdaudio_paused], 0
			mov ebx, [hdaudio_bar_lo]
			; enable interrupts
			or	WORD [ebx+HDAUDIO_WAKEEN_OFFS], 0x7FFF
			mov DWORD [ebx+HDAUDIO_INTCTL_OFFS], 0x800000F0	; 4 ISS is the first 4 bits, next 4 is the 4 OSS

			mov edx, [hdaudio_output_base]
			mov eax, [ebx+edx+HDAUDIO_SD0CTL_OFFS]
			or	eax, 0x00000002								; set run-bit
			mov [ebx+edx+HDAUDIO_SD0CTL_OFFS], eax
.Back		popad
			ret


hdaudio_get_afg_supported_stream_fmt:
			pushad
			xor ecx, ecx
			mov cl, [hdaudio_afg_id]
			mov edx, HDAUDIO_CMD_GET_PARAMETER
			mov ebp, HDAUDIO_PARAM_SUPP_STREAM_FORMATS
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			and eax, HDAUDIO_STREAM_FT_MASK
			mov [hdaudio_afg_supported_stream_fmt], eax
.Back		popad
			ret


hdaudio_get_afg_supported_pcm_fmt:
			pushad
			xor ecx, ecx
			mov cl, [hdaudio_afg_id]
			mov edx, HDAUDIO_CMD_GET_PARAMETER
			mov ebp, HDAUDIO_PARAM_SUPP_PCM_SIZE
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			and eax, 0x001F0FFF		; See the defines at "Supported PCM sizes (page 204)" in this file
			mov [hdaudio_afg_supported_pcm_fmt], eax
.Back		popad
			ret


hdaudio_get_supported_stream_format:
			xor eax, eax
			cmp BYTE [hdaudio_inited], 1
			jnz	.Back
			mov eax, [hdaudio_afg_supported_stream_fmt]
.Back		ret


hdaudio_get_supported_pcm_format:
			xor eax, eax
			cmp BYTE [hdaudio_inited], 1
			jnz	.Back
			mov eax, [hdaudio_afg_supported_pcm_fmt]
.Back		ret


;FORTH-WORD
; IN: EAX(gain)
; currently only out (so no HP)
hdaudio_setvol:
			pushad
			cmp BYTE [hdaudio_inited], 1
			jnz	.Back
			and eax, (HDAUDIO_AMP_MUTE | HDAUDIO_AMP_GAIN)
			mov [hdaudio_mutegain], eax
			xor ecx, ecx
.Next		xor ebx, ebx
			mov bl, [hdaudio_tree_out_path+ecx]
			sub ebx, [hdaudio_afg_start_widget_id]
			mov eax, HDAUDIO_WIDGET_REQ_NUM*4
			mul ebx
			mov ebx, [hdaudio_widget_data+eax]
			and ebx, (HDAUDIO_WCAPS_OUT_AMP_PRES | HDAUDIO_WCAPS_IN_AMP_PRES)
			jz	.Cont
			xor eax, eax
			mov al, [hdaudio_tree_out_path+ecx]
			push ecx
			mov ecx, eax
			mov edx, HDAUDIO_CMD_SET_AMP_GAINMUTE
			mov ebp, (HDAUDIO_AMP_SET_OUTPUT | HDAUDIO_AMP_SET_INPUT | HDAUDIO_AMP_SET_LEFT | HDAUDIO_AMP_SET_RIGHT)
			or	ebp, [hdaudio_mutegain]	
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			pop ecx
			cmp BYTE [hdaudio_error], 0
			jnz	.Err
.Cont 		inc ecx
			cmp cl, [hdaudio_tree_out_depth]
			jnz	.Next
			jmp .Back
.Err		mov DWORD [hdaudio_mutegain], 0
			mov ebx, hdaudio_SetVolErrTxt
			call gstdio_draw_text
.Back		popad
			ret


;FORTH-WORD
; OUT: EAX(gain)
; currently only out (so no HP)
hdaudio_getvol:
			mov eax, [hdaudio_mutegain]
			ret


; ************* funcs for WIDGETS (e.g parsing)

hdaudio_get_codecs_data:
			pushad
.GetSpace	call hdaudio_get_corb_space
			cmp ecx, 0
			jz	.GetSpace

			xor edx, edx
			mov dx, [hdaudio_codecs_mask]
			; VendorId
			bsf	eax, edx	; find first set-bit in codec-mask
			mov [hdaudio_codec_id], eax
			mov ecx, 0
			mov edx, HDAUDIO_CMD_GET_PARAMETER
			mov ebp, HDAUDIO_PARAM_VENDORID
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov [hdaudio_codec_devid], eax

			; RevisionId
			mov ecx, 0
			mov edx, HDAUDIO_CMD_GET_PARAMETER
			mov ebp, HDAUDIO_PARAM_REVISIONID
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov [hdaudio_codec_revid], eax

			; NumberOfFGs
			mov ecx, 0
			mov edx, HDAUDIO_CMD_GET_PARAMETER
			mov ebp, HDAUDIO_PARAM_SUB_NODE_CNT
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov [hdaudio_codec_fg_num], eax

			; find AFG
			mov ecx, eax
			and ecx, HDAUDIO_SUB_NODE_CNT_START		; ECX: startNodeId
			shr ecx, HDAUDIO_SUB_NODE_CNT_START_SHIFT
			mov [hdaudio_afg_id], ecx
			mov edi, eax
			and edi, HDAUDIO_SUB_NODE_CNT_TOTAL		; EDI: total number of nodes
			mov esi, 0								; ESI: number of loops till EDI
.NextAFG	mov [hdaudio_afg_id], ecx
			mov edx, HDAUDIO_CMD_GET_PARAMETER
			mov ebp, HDAUDIO_PARAM_FUNC_GR_TYPE
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			and eax, 0x000000FF
			cmp eax, HDAUDIO_FG_AUDIO
			jz	.AFGFnd
			inc esi
			cmp esi, edi
			jz	.ErrNoAFG
			inc DWORD [hdaudio_afg_id]
			jmp .NextAFG

			; number of widgets
.AFGFnd		mov ecx, [hdaudio_afg_id]
			mov edx, HDAUDIO_CMD_GET_PARAMETER
			mov ebp, HDAUDIO_PARAM_SUB_NODE_CNT
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov ecx, eax
			and ecx, HDAUDIO_SUB_NODE_CNT_START
			shr ecx, HDAUDIO_SUB_NODE_CNT_START_SHIFT
			mov [hdaudio_afg_start_widget_id], ecx
			mov ecx, eax
			and ecx, HDAUDIO_SUB_NODE_CNT_TOTAL	
			mov [hdaudio_afg_total_widget_num], ecx

			; get parameters of the widgets
			mov ebp, hdaudio_widget_data
			mov ecx, [hdaudio_afg_start_widget_id]
.NextWid	mov esi, hdaudio_widget_verbs
			mov edi, hdaudio_widget_params
.NextWPar	cmp DWORD [esi], HDAUDIO_CMD_GET_CONN_LIST_ENTRY_CTRL
			jnz	.Cmd
			cmp DWORD [edi], 0
			jz	.ChkConList				; if not: listentryctrl with param 4 (i.e. offset=4, listentry2)
			; Skip ConnListEntry2 if ConnListLen < HDAUDIO_MAX_ENTRYNUM_PER_DWORD
			mov ebx, [hdaudio_connlistlen]
			and ebx, HDAUDIO_CONN_LIST_LEN					; removes Short/long bit (bit7)
			cmp ebx, HDAUDIO_MAX_ENTRYNUM_PER_DWORD
			ja	.Cmd
			add ebp, 4			; skip connlistctrl2 entry
			jmp .NWid

.ChkConList	mov eax, [hdaudio_wcaps]
			and eax, HDAUDIO_WCAPS_CONN_LIST
			jnz	.Cmd
			add ebp, 8			; skip two connlistctrl entries
			jmp .NWid

.Cmd		mov edx, [esi]
			push ecx
			push ebp
			mov ebp, [edi]
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			pop ebp
			pop ecx
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov [ebp], eax									; save data

			cmp DWORD [edi], HDAUDIO_PARAM_WIDGET_CAPS
			jnz	.ChkConnLL
			mov [hdaudio_wcaps], eax

.ChkConnLL	cmp DWORD [edi], HDAUDIO_PARAM_CONN_LIST_LEN
			jnz	.NWPar
			mov [hdaudio_connlistlen], eax

.NWPar		add esi, 4
			add edi, 4
			add ebp, 4
			cmp DWORD [esi], 0xFFFFFFFF
			jnz	.NextWPar

.NWid		inc ecx
			mov eax, ecx
			sub eax, [hdaudio_afg_start_widget_id]
			cmp eax, [hdaudio_afg_total_widget_num]
			jc	.NextWid
			jmp .Back
.Err		mov BYTE [hdaudio_error], 1
			jmp .Back
.ErrNoAFG	mov BYTE [hdaudio_error], 2
.Back		popad
			ret


; IN: ECX(AFG-nodeId), EBX(pwr-state)
hdaudio_set_power_state:
			pushad
			mov ebp, ebx
			cmp ebp, HDAUDIO_POWER_STATE_D3
			jnz	.SetAFG
			; this delay seems necessary to avoid clicking noise at pwr down
			mov ebx, 100	; 100 ms
			call pit_delay
.SetAFG		mov edx, HDAUDIO_CMD_SET_POWER_STATE
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
; TODO !?  (PS-Error(bit8), PS-SettingsReset(bit10), PS-Set(3:0), Ps-Act(7:4))
			cmp ebp, HDAUDIO_POWER_STATE_D0
			jnz	.SetWids
			mov ebx, 10		; 10 ms
			call pit_delay
.SetWids	mov ecx, [hdaudio_afg_start_widget_id]
			mov edx, hdaudio_widget_data
.NextWid	mov eax, [edx]
			test eax, HDAUDIO_WCAPS_PWR_CNTRL
			jz	.Cont
			cmp ebp, HDAUDIO_POWER_STATE_D3
			jnz	.SetPwr
			and eax, HDAUDIO_WCAPS_TYPE
			shr eax, HDAUDIO_WCAPS_TYPE_SHIFT
			cmp eax, HDAUDIO_WIDGET_PIN
			jnz	.SetPwr
			; don't power down the widget if it controls EAPD and EAPD_BTLENABLE is set
			mov eax, [edx+HDAUDIO_PINCAPS_IDX*4]
			test eax, HDAUDIO_PIN_CAPS_EAPD
			jz	.SetPwr
			push ecx
			push edx
			push ebp
			mov edx, HDAUDIO_CMD_GET_EAPDBTL_ENABLE
			xor ebp, ebp
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			pop ebp
			pop edx
			pop ecx
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			test eax, HDAUDIO_EAPDBTL_EAPD
			jnz	.Cont
.SetPwr		push ecx
			push edx
			mov edx, HDAUDIO_CMD_SET_POWER_STATE
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			pop edx
			pop ecx
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
.Cont		inc ecx
			add edx, HDAUDIO_WIDGET_REQ_NUM*4
			mov eax, ecx
			sub eax, [hdaudio_afg_start_widget_id]
			cmp eax, [hdaudio_afg_total_widget_num]
			jnz	.NextWid
			jmp .Back
.Err		mov BYTE [hdaudio_error], 1
.Back		popad
			ret


hdaudio_parse_output:
			pushad
	%ifdef DEBUGPARSE
		call gstdio_new_line
	%endif
			; first look for LineOut
			mov eax, HDAUDIO_JACK_LINE_OUT
			mov ebx, hdaudio_tree_path
			mov DWORD [ebx], hdaudio_tree_out_path
			call hdaudio_parse_output_jack
			mov al, [hdaudio_tree_depth]
			mov [hdaudio_tree_out_depth], al
			cmp al, 0
			jnz	.ChkHP
			; look for Speaker, if LineOut not found
.ChkSpeaker	mov eax, HDAUDIO_JACK_SPEAKER
			mov ebx, hdaudio_tree_path
			mov DWORD [ebx], hdaudio_tree_out_path
			call hdaudio_parse_output_jack
			mov al, [hdaudio_tree_depth]
			mov [hdaudio_tree_out_depth], al
			; look for HP
.ChkHP		mov eax, HDAUDIO_JACK_HP_OUT
			mov ebx, hdaudio_tree_path
			mov DWORD [ebx], hdaudio_tree_hp_path
			call hdaudio_parse_output_jack
			mov al, [hdaudio_tree_depth]
			mov [hdaudio_tree_hp_depth], al
			; LineOut, Speaker or HP was found?
			cmp BYTE [hdaudio_tree_out_depth], 0
			jnz	.Back
			cmp BYTE [hdaudio_tree_hp_depth], 0
			jnz	.Back
			; No LineOut or HP pins found: choose first output pin
			mov eax, -1
			mov ebx, hdaudio_tree_path
			mov DWORD [ebx], hdaudio_tree_out_path
			call hdaudio_parse_output_jack
			mov al, [hdaudio_tree_depth]
			mov [hdaudio_tree_out_depth], al
.Back		popad
			ret


; IN: EAX(jacktype)
; OUT: ECX(Id of Pin-node if path to DAC found, zero otherwise)
; Look for the output PIN widget with the given jacktype
; and parse the output path to that PIN.
; Returns the path to DAC, tree_depth is zero if not found.
hdaudio_parse_output_jack:
			pushad
			mov ecx, 0
			mov edx, 0
.NextNode	mov ebx, [hdaudio_widget_data+edx+HDAUDIO_WIDCAPS_IDX*4]
			and ebx, HDAUDIO_WCAPS_TYPE
			shr ebx, HDAUDIO_WCAPS_TYPE_SHIFT
			cmp ebx, HDAUDIO_WIDGET_PIN
			jnz	.Cont
			mov ebx, [hdaudio_widget_data+edx+HDAUDIO_PINCAPS_IDX*4]			; PinCaps: output capable?
			and ebx, HDAUDIO_PIN_CAPS_OUTP_CAP
			jz	.Cont
			mov ebx, [hdaudio_widget_data+edx+HDAUDIO_CONFIGDEF_IDX*4]			; ConfigDef (bits 31:30)
			and ebx, HDAUDIO_CONFIGDEF_PORTCONN
			shr ebx, HDAUDIO_CONFIGDEF_PORTCONN_SHIFT
			cmp ebx, HDAUDIO_PORTCONN_NO
			jz	.Cont
			cmp eax, 0				; if negative
			jl	.EnaSense
			mov ebx, [hdaudio_widget_data+edx+HDAUDIO_CONFIGDEF_IDX*4]			; ConfigDef (device-type)
			and ebx, HDAUDIO_CONFIGDEF_DEFDEV
			shr ebx, HDAUDIO_CONFIGDEF_DEFDEV_SHIFT
			cmp eax, ebx
			jnz	.Cont
			mov ebx, [hdaudio_widget_data+edx+HDAUDIO_WIDCAPS_IDX*4]
			and ebx, HDAUDIO_WCAPS_DIGITAL					; skip SPDIF
			jnz	.Cont
.EnaSense:
			; call snd_hda_enable_pin_sense (enable UNSOL!?)
			push edx
			call hdaudio_init_parse
			push eax
	%ifdef DEBUGPARSE
		push ebx
		mov ebx, dbg_parseTxt
		call gstdio_draw_text
		cmp eax, -1
		jz	.DbgFst
		mov ebx, dbg_arr_jack_txts
		shl eax, 2
		add ebx, eax
		mov ebx, [ebx]
		jmp .DbgDr
.DbgFst	mov ebx, dbg_FirstTxt
.DbgDr	call gstdio_draw_text
		pop ebx
	%endif
			call hdaudio_parse_output_path
	%ifdef DEBUGPARSE
		call gutil_press_a_key
	%endif
			cmp BYTE [hdaudio_tree_depth], 0
			pop eax
			pop edx
			jnz	.Back
.Cont		add edx, HDAUDIO_WIDGET_REQ_NUM*4
			inc ecx
			cmp ecx, [hdaudio_afg_total_widget_num]
			jnz	.NextNode
.Back		popad
			ret


; IN: ECX(nodeId-startNodeId); ESI(depth in tree); EDI(offset in DWORDs of widget-data)
;	Note that EDI could be calculated from ECX, but it's faster this way
; OUT: tree_depth is 0 if not fnd, also fills tree-path-array
hdaudio_parse_output_path:
			push ecx
			push edi
			push esi
	%ifdef DEBUGPARSE
		push edx
		push ebx
		mov ebx, ecx
		add ebx, [hdaudio_afg_start_widget_id]
		mov dh, bl
		call gstdio_draw_hex8
		mov ebx, ' '
		call gstdio_draw_char
		pop ebx
		pop edx
	%endif

	%ifndef DEBUGPARSE
		cmp BYTE[hdaudio_tree_path_fnd], 1
		jz	.Back
	%endif
			mov ebp, 0
			cmp BYTE [hdaudio_widgets_checked+ecx], 1		; e.g. prevent a loop
			jz	.NotFnd
			mov BYTE [hdaudio_widgets_checked+ecx], 1
			inc esi											; inc Depth in tree
			; save path
			push ebx
			mov ebx, [hdaudio_tree_path]
			add ecx, [hdaudio_afg_start_widget_id]
			mov [ebx+esi], cl
			sub ecx, [hdaudio_afg_start_widget_id]
			pop ebx
			; end of saving
			mov eax, HDAUDIO_WIDGET_REQ_NUM*4
			mov ebx, ecx
			mul ebx
			mov edi, eax
			mov ebx, [hdaudio_widget_data+edi+HDAUDIO_WIDCAPS_IDX*4]
			and ebx, HDAUDIO_WCAPS_TYPE
			shr ebx, HDAUDIO_WCAPS_TYPE_SHIFT
			cmp ebx, HDAUDIO_WIDGET_AUD_OUT
			jnz	.NotDAC
			mov ebx, [hdaudio_widget_data+edi+HDAUDIO_WIDCAPS_IDX*4]
			and ebx, HDAUDIO_WCAPS_DIGITAL					; skip SPDIF
			jnz	.NotFnd
			jmp .Fnd
			; search conn-list of node, if node is not a DAC
.NotDAC		mov ebx, [hdaudio_widget_data+edi+HDAUDIO_WIDCAPS_IDX*4]				; WCaps, bit8: isthereAConnlist?
			and ebx, HDAUDIO_WCAPS_CONN_LIST
			jz	.NotFnd
			; check ConnListEntries
			mov edx, [hdaudio_widget_data+edi+HDAUDIO_CONNLISTLEN_IDX*4]			; connlistlen
			and edx, HDAUDIO_CONN_LIST_LEN
			cmp edx, 0
			jz	.NotFnd
			cmp edx, HDAUDIO_MAX_CONN_LIST_LEN
			jle	.ConnList
			mov edx, HDAUDIO_MAX_CONN_LIST_LEN
.ConnList	mov ebx, [hdaudio_widget_data+edi+HDAUDIO_CONNLSTENTCTRL_IDX*4]			; connlistentry1
			cmp ebp, 0
			jz	.GetNode
			xor eax, eax
.NextEntry	shr	ebx, 8
			inc eax
			cmp eax, HDAUDIO_MAX_ENTRYNUM_PER_DWORD
			jnz	.Chk
			mov ebx, [hdaudio_widget_data+edi+HDAUDIO_CONNLSTENTCTRL2_IDX*4]			; connlistentry2
.Chk		cmp eax, ebp
			jnz	.NextEntry
.GetNode	and bl, ~HDAUDIO_CONN_LIST_ENTRY_RANGE			; remove RANGE indicator
			mov cl, bl
			; chk if zero, if yes: NotFnd
			cmp ecx, 0
			jz	.NotFnd
			sub ecx, [hdaudio_afg_start_widget_id]
			; recurse
			push edx
			push ebp
			mov ebp, 0			; this is not necessary
			call hdaudio_parse_output_path
			pop ebp
			pop edx
	%ifndef DEBUGPARSE
		cmp BYTE[hdaudio_tree_path_fnd], 1
		jz	.Back
	%endif
			inc ebp	
			cmp ebp, edx
			jnz	.ConnList	
.NotFnd		mov BYTE [hdaudio_tree_depth], 0
	%ifdef DEBUGPARSE
		push ebx
		mov ebx, '*'										; path not found
		call gstdio_draw_char
		pop ebx
	%endif
			jmp .Back
.Fnd		inc	esi
			mov eax, esi
			mov [hdaudio_tree_depth], al
			mov BYTE[hdaudio_tree_path_fnd], 1
	%ifdef DEBUGPARSE
		push ebx
		mov ebx, '+'										; path found
		call gstdio_draw_char
		pop ebx
	%endif
.Back		pop esi
			pop edi
			pop ecx
			ret


; IN: ECX(NID)
hdaudio_set_pin_ctrl:
			push eax
			push ebx
			push edx
			push ebp
			; is widget a PinComplex?
			mov eax, HDAUDIO_WIDGET_REQ_NUM*4
			mov ebx, ecx
			sub ebx, [hdaudio_afg_start_widget_id]
			mul ebx
			mov ebx, [hdaudio_widget_data+eax+HDAUDIO_WIDCAPS_IDX*4]
			and ebx, HDAUDIO_WCAPS_TYPE
			shr ebx, HDAUDIO_WCAPS_TYPE_SHIFT
			cmp ebx, HDAUDIO_WIDGET_PIN
			jnz	.Back

			; find data of PinOut
			mov eax, ecx
			sub eax, [hdaudio_afg_start_widget_id]
			mov ebx, HDAUDIO_WIDGET_REQ_NUM*4
			mul ebx
			; set PinOut enable
			xor ebp, ebp
			mov ebp, (HDAUDIO_PINCTL_OUT_ENABLE | HDAUDIO_PINCTL_IN_ENABLE)
			mov ebx, [hdaudio_widget_data+eax+HDAUDIO_PINCAPS_IDX*4]			; PinCaps: HP-Drive capable?
			and ebx, HDAUDIO_PIN_CAPS_HEADPH_CAP
			jz	.OutEna
			or	ebp, HDAUDIO_PINCTL_HP_ENABLE
.OutEna		mov edx, HDAUDIO_CMD_SET_PIN_WIDGET_CTRL
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
.Back		pop ebp
			pop edx
			pop ebx
			pop eax
			ret


; IN: EBX(addr of path), EDX(depth of path)
; unmutes and connects widgets in the given path
; also enables output
hdaudio_prepare_path:
			pushad
			xor ecx, ecx
.NextUnm	xor eax, eax
			mov al, [ebx+ecx]
			push ecx
			mov ecx, eax
			call hdaudio_unmute_output
			pop ecx
			cmp BYTE [hdaudio_error], 0
			jnz	.ErrUnM
			mov DWORD [hdaudio_mutegain], HDAUDIO_DEF_GAIN		; same as in hdaudio_unmute_output
			push ecx
			mov ecx, eax
			call hdaudio_set_pin_ctrl
			pop ecx
			cmp BYTE [hdaudio_error], 0
			jnz	.ErrPinWid

			push ebx
			push edx
			; Select in connlistcontrol the next node in the path, if there is a connlistcontrol
			; check if connlistlen is 1, if yes ==> no connlistcontrol
			sub eax, [hdaudio_afg_start_widget_id]
			mov ebx, HDAUDIO_WIDGET_REQ_NUM*4
			mul ebx
			mov edx, [hdaudio_widget_data+eax+HDAUDIO_CONNLISTLEN_IDX*4]			; Connlistlen
			and edx, HDAUDIO_CONN_LIST_LEN
			cmp edx, 1	
			pop edx
			pop ebx
			jna	.Cont

			; find Id of previous-node in the path
			inc ecx
			cmp ecx, edx
			jz	.Back			; If last node in the path, then no prev node (and DAC has no Connlist)
			dec ecx
			push edx
			xor eax, eax
			mov al, [ebx+ecx]
			mov edx, eax		; currNodeId in EDX
			xor eax, eax
			mov al, [ebx+ecx+1]	; prevNodeId in EAX
			call hdaudio_get_connlist_idx
			pop edx
			cmp ebp, -1
			jz	.Cont 

			xor eax, eax
			mov al, [ebx+ecx]
			call hdaudio_unmute_mixer
			cmp BYTE [hdaudio_error], 0
			jnz	.ErrUnM2

			; select connection (EBP)
			push ecx
			push edx
			xor eax, eax
			mov al, [ebx+ecx]
			mov ecx, eax
			mov edx, HDAUDIO_CMD_SET_CONN_SEL_CTRL
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			pop edx
			pop ecx
			cmp BYTE [hdaudio_error], 0
			jnz	.ErrSelConn
.Cont 		inc ecx
			cmp ecx, edx
			jc	.NextUnm
			jmp .Back
.ErrPinWid	mov ebx, hdaudio_SetPinWidCtrlTxt
			call gstdio_draw_text
			jmp .Back
.ErrUnM		mov ebx, hdaudio_UnmuteOutpErrTxt
			call gstdio_draw_text
			jmp .Back
.ErrSelConn mov ebx, hdaudio_SelectInpConnErrTxt
			call gstdio_draw_text
			jmp .Back
.ErrUnM2	mov ebx, hdaudio_UnmuteOutp2ErrTxt
			call gstdio_draw_text
.Back		popad
			ret


; See in specs: p138, p175, p214
; The Knob has a connectionlist showing which widgets it controls(volume).
; Can be direct or not direct (bit7). No connectionSelector.
; IN: - 
hdaudio_prepare_knob:
			pushad
			mov ecx, [hdaudio_afg_start_widget_id]
			xor edi, edi
.NextWid	mov ebx, [hdaudio_widget_data+edi+HDAUDIO_WIDCAPS_IDX*4]	; WCaps
			and ebx, HDAUDIO_WCAPS_TYPE
			shr ebx, HDAUDIO_WCAPS_TYPE_SHIFT
			cmp ebx, HDAUDIO_WIDGET_VOL_KNOB
			jnz	.Cont
			mov edx, HDAUDIO_CMD_SET_VOLUME_KNOB
			mov ebp, (HDAUDIO_VOL_KNOB_CAP_DELTA | HDAUDIO_DEF_GAIN)
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
.Cont		add edi, HDAUDIO_WIDGET_REQ_NUM*4
			inc ecx
			cmp ecx, [hdaudio_afg_total_widget_num]
			jc	.NextWid
.Back		popad
			ret


; IN: EDX(nodeId), EAX(prevNodeId)
; OUT: EBP (zero-based index in conn-list), -1 if not found
hdaudio_get_connlist_idx:
			push eax
			push ebx
			push ecx
			push edx
			push eax
			mov eax, edx
			sub eax, [hdaudio_afg_start_widget_id]
			mov ebx, HDAUDIO_WIDGET_REQ_NUM*4
			mul ebx
			mov edx, [hdaudio_widget_data+eax+HDAUDIO_CONNLSTENTCTRL_IDX*4]			; Connlist1
			mov [hdaudio_connlistentries], edx
			mov edx, [hdaudio_widget_data+eax+HDAUDIO_CONNLSTENTCTRL2_IDX*4]		; Connlist2
			mov [hdaudio_connlistentries+4], edx
			mov edx, [hdaudio_widget_data+eax+HDAUDIO_CONNLISTLEN_IDX*4]			; Connlistlength
			and edx, HDAUDIO_CONN_LIST_LEN
			pop eax
			mov ebp, -1
			xor ecx, ecx
			mov ebx, hdaudio_connlistentries
.Next		push edx
			mov dl, [ebx+ecx]
			and dl, ~HDAUDIO_CONN_LIST_ENTRY_RANGE
			cmp dl, al
			pop edx
			jz	.Fnd
			inc ecx
			cmp ecx, edx
			jc	.Next
			mov ebp, -1
			jmp	.Back
.Fnd		mov ebp, ecx
.Back		pop edx
			pop ecx
			pop ebx
			pop eax
			ret


; IN: -
; OUT: - (hdaudio_error)
hdaudio_prepare_afg:
			push eax
			push ecx
			push edx
			push ebp
			mov ecx, [hdaudio_afg_id]
			mov edx, HDAUDIO_CMD_SET_AMP_GAINMUTE
			mov ebp, (HDAUDIO_AMP_SET_OUTPUT | HDAUDIO_AMP_SET_INPUT | HDAUDIO_AMP_SET_LEFT | HDAUDIO_AMP_SET_RIGHT)
			or	ebp, 0x0F ; HDAUDIO_AMP_GAIN
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			pop ebp
			pop edx
			pop ecx
			pop eax
			ret


; IN: ECX(nodeId)
; unmute (and set vol) the output/input amplifier
hdaudio_unmute_output:
			pushad
			mov eax, HDAUDIO_WIDGET_REQ_NUM*4
			mov ebx, ecx
			sub ebx, [hdaudio_afg_start_widget_id]
			mul ebx
			mov ebx, [hdaudio_widget_data+eax+HDAUDIO_WIDCAPS_IDX*4]
			mov edx, ebx
			and ebx, (HDAUDIO_WCAPS_OUT_AMP_PRES | HDAUDIO_WCAPS_IN_AMP_PRES)
			jz	.Back
			and edx, HDAUDIO_WCAPS_TYPE
			shr edx, HDAUDIO_WCAPS_TYPE_SHIFT
			cmp edx, HDAUDIO_WIDGET_AUD_MIX
			jz	.Back

			call hdaudio_set_eapd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov edx, HDAUDIO_CMD_SET_AMP_GAINMUTE
			mov ebp, (HDAUDIO_AMP_SET_OUTPUT | HDAUDIO_AMP_SET_INPUT | HDAUDIO_AMP_SET_LEFT | HDAUDIO_AMP_SET_RIGHT)
			or	ebp, HDAUDIO_DEF_GAIN
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
.Back		popad
			ret


; NOTE: A Mixer behaves differently: 
;		It has no ConnSelCtrl.
; 		From its ConnectionList get the index of the IdOfThePrevNode, and set it here as the index(bits 11:8)
;		This way we set the Mixer's AmpGain for the connection.
; IN: EAX(NID), EBP(connselIdx)
hdaudio_unmute_mixer:
			pushad
			shl ebp, HDAUDIO_AMP_INDEX_SHIFT
			mov ecx, eax
			sub eax, [hdaudio_afg_start_widget_id]
			mov ebx, HDAUDIO_WIDGET_REQ_NUM*4
			mul ebx
			; Mixer?
			mov ebx, [hdaudio_widget_data+eax+HDAUDIO_WIDCAPS_IDX*4]
			mov edx, ebx
			and ebx, HDAUDIO_WCAPS_TYPE
			shr ebx, HDAUDIO_WCAPS_TYPE_SHIFT
			cmp ebx, HDAUDIO_WIDGET_AUD_MIX
			jnz	.Back
			and edx, (HDAUDIO_WCAPS_OUT_AMP_PRES | HDAUDIO_WCAPS_IN_AMP_PRES)
			jz	.Back
			mov edx, HDAUDIO_CMD_SET_AMP_GAINMUTE
			or	ebp, (HDAUDIO_AMP_SET_OUTPUT | HDAUDIO_AMP_SET_INPUT | HDAUDIO_AMP_SET_LEFT | HDAUDIO_AMP_SET_RIGHT)
			or	ebp, HDAUDIO_DEF_GAIN
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
.Back		popad
			ret


; IN: ECX(nodeId) ; nodeId is widgetId
hdaudio_set_eapd:
			pushad
			; is widget a Pin?
			mov eax, HDAUDIO_WIDGET_REQ_NUM*4
			mov ebx, ecx
			sub ebx, [hdaudio_afg_start_widget_id]
			mul ebx
			mov ebx, [hdaudio_widget_data+eax+HDAUDIO_WIDCAPS_IDX*4]
			and ebx, HDAUDIO_WCAPS_TYPE
			shr ebx, HDAUDIO_WCAPS_TYPE_SHIFT
			cmp ebx, HDAUDIO_WIDGET_PIN
			jnz	.Back
			; EAPD capable? (Pin Caps)
			mov ebx, [hdaudio_widget_data+eax+HDAUDIO_PINCAPS_IDX*4]
			and ebx, HDAUDIO_PIN_CAPS_EAPD
			jz	.Back
			; set EAPD
			mov edx, HDAUDIO_CMD_SET_EAPDBTL_ENABLE
			mov	ebp, HDAUDIO_EAPDBTL_EAPD
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
.Back		popad
			ret


hdaudio_init_parse:
			push eax
			push ecx
			mov BYTE [hdaudio_tree_path_fnd], 0
			mov BYTE [hdaudio_tree_depth], 0
			mov edi, hdaudio_widgets_checked
			mov ecx, HDAUDIO_MAX_WIDGET_NUM
			mov eax, 0
			rep stosb
			mov esi, -1		; depth in tree
			mov edi, 0
			pop ecx
			pop eax
			ret


; *************** print-funcs for DEBUGGING
; FORTH -WORD
hdaudio_codecs_info:
;	%ifdef DEBUGPARSE
			pushad

			cmp BYTE [hdaudio_inited], 1
			jnz	.Back

;			call hdaudio_get_codecs_data

			call gstdio_new_line
			mov ebx, hdaudio_CodecMaskTxt
			call gstdio_draw_text
			xor edx, edx
			mov dx, [hdaudio_codecs_mask]
			call gstdio_draw_hex16
			call gstdio_new_line

			call gstdio_new_line

			; Root Node
			mov ebx, hdaudio_RootNodeTxt
			call gstdio_draw_text

			; VendorId
			mov ebx, hdaudio_RootNodeVIdTxt
			call gstdio_draw_text
			mov edx, [hdaudio_codec_devid]
			call gstdio_draw_hex
			call gstdio_new_line

			; RevisionId
			mov ebx, hdaudio_RootNodeRevIdTxt
			call gstdio_draw_text
			mov edx, [hdaudio_codec_revid]
			call gstdio_draw_hex
			call gstdio_new_line

			; NumberOfFGs
			mov ebx, hdaudio_RootNodeFGNumTxt
			call gstdio_draw_text
			mov edx, [hdaudio_codec_fg_num]
			call gstdio_draw_hex
			call gstdio_new_line

			; AFG
			mov ebx, hdaudio_AFGFndTxt
			call gstdio_draw_text
			mov edx, [hdaudio_afg_id]
			shl	edx, 8
			call gstdio_draw_hex8
			call gstdio_new_line

			; number of widgets
			mov ebx, hdaudio_AFGNodeWidgetNumTxt
			call gstdio_draw_text
			mov edx, [hdaudio_afg_start_widget_id]
			call gstdio_draw_hex
			mov ebx, ' '
			call gstdio_draw_char
			mov edx, [hdaudio_afg_total_widget_num]
			call gstdio_draw_hex
			call gstdio_new_line

			; widget data
			mov eax, 0				; EAX(WId)
.PrWdgt		mov ecx, 0				; ECX(ParamIdx)
			add eax, [hdaudio_afg_start_widget_id]
			mov dh, al
			call gstdio_draw_hex8
			call gstdio_new_line
			sub eax, [hdaudio_afg_start_widget_id]
.PrPars		mov ebx, eax
			push eax
			mov eax, ecx
			shl	eax, 2
			push ebx
			mov ebx, hdaudio_wid_txts_arr
			mov ebx, [ebx+eax]
			call gstdio_draw_text
			pop ebx
			mov eax, HDAUDIO_WIDGET_REQ_NUM*4
			mul ebx
			mov ebx, eax
			pop eax
			mov edx, [hdaudio_widget_data+ebx+ecx*4]
			call gstdio_draw_hex
			mov ebx, ' '
			call gstdio_draw_char
			inc ecx
			cmp ecx, HDAUDIO_WIDGET_REQ_NUM
			jnz	.PrPars
			call gstdio_new_line
			call gutil_press_a_key
			inc eax
			cmp eax, [hdaudio_afg_total_widget_num]
			jnz	.PrWdgt

.Back		popad
;	%endif
			ret


; FORTH_WORD
hdaudio_info:
			pushad
			cmp BYTE [hdaudio_inited], 1
			jnz	.Back
			; print DMA positions
			call gstdio_new_line
			mov ebx, hdaudio_DMAPosTxt
			call gstdio_draw_text
			mov ebx, HDAUDIO_DPL_BUFF
			mov edx, [ebx]
			call gstdio_draw_hex
			call gstdio_new_line
			mov edx, [ebx+8]
			call gstdio_draw_hex
			call gstdio_new_line
			mov edx, [ebx+16]
			call gstdio_draw_hex
			call gstdio_new_line
			mov edx, [ebx+24]
			call gstdio_draw_hex
			call gstdio_new_line
			; second 4
			mov edx, [ebx+32]
			call gstdio_draw_hex
			call gstdio_new_line
			mov edx, [ebx+40]
			call gstdio_draw_hex
			call gstdio_new_line
			mov edx, [ebx+48]
			call gstdio_draw_hex
			call gstdio_new_line
			mov edx, [ebx+56]
			call gstdio_draw_hex
			call gstdio_new_line

			; print registers
			call hdaudio_print_regs
.Back		popad
			ret


; prints the contents of all the registers
hdaudio_print_regs:
			pushad
			; registers
			mov ebx, hdaudio_RegsTxt
			call gstdio_draw_text
			mov eax, [hdaudio_bar_lo]
			mov ecx, 0
.Next		mov ebx, [hdaudio_txtarr+ecx*4]
			call gstdio_draw_text
			mov ebx, [hdaudio_idarr+ecx*4]
			mov ebp, [hdaudio_lenarr+ecx*4]
			cmp ebp, 1
			jz	.Byte
			cmp ebp, 2
			jz	.Word
			cmp ebp, 3
			jz	.Three
			cmp ebp, 4
			jz	.DWord
.Byte		mov dh, [eax+ebx]
			call gstdio_draw_hex8
			jmp .Inc
.Word		mov dx, [eax+ebx]
			call gstdio_draw_hex16
			jmp .Inc
.Three		mov edx, [eax+ebx]				; one of the register's length is 3 bytes !?
			and edx, 0x00FFFFFF
			call gstdio_draw_hex
			jmp .Inc
.DWord		mov edx, [eax+ebx]
			call gstdio_draw_hex
.Inc		mov ebx, ' '
			call gstdio_draw_char
			inc ecx
			cmp ecx, 43
			jnz	.Next
			popad
			ret


; in reverse order (i.e. from DAC to PinOut)
hdaudio_print_out_path:
			pushad
			call gstdio_new_line
			mov ebx, hdaudio_OutPathTxt
			call gstdio_draw_text
			cmp BYTE [hdaudio_tree_out_depth], 0
			jnz	.Print
			mov ebx, hdaudio_NotFndTxt
			call gstdio_draw_text
			jmp .Back
.Print		xor ecx, ecx
			mov cl, [hdaudio_tree_out_depth]
			mov edx, hdaudio_tree_out_path
.Next		push edx
			dec ecx
			mov dh, [edx+ecx]
			inc ecx
			call gstdio_draw_hex8
			pop edx
			mov ebx, ' '
			call gstdio_draw_char
			dec ecx
			cmp cl, 0
			jnz	.Next
			call gstdio_new_line
.Back		popad
			ret


; in reverse order (i.e. from DAC to PinOut)
hdaudio_print_hp_path:
			pushad
			mov ebx, hdaudio_HPPathTxt
			call gstdio_draw_text
			cmp BYTE [hdaudio_tree_hp_depth], 0
			jnz	.Print
			mov ebx, hdaudio_NotFndTxt
			call gstdio_draw_text
			jmp .Back
.Print		xor ecx, ecx
			mov cl, [hdaudio_tree_hp_depth]
			mov edx, hdaudio_tree_hp_path
.Next		push edx
			dec ecx
			mov dh, [edx+ecx]
			inc ecx
			call gstdio_draw_hex8
			pop edx
			mov ebx, ' '
			call gstdio_draw_char
			dec ecx
			cmp cl, 0
			jnz	.Next
			call gstdio_new_line
.Back		popad
			ret


%ifdef DEBUG_SETTINGS
hdaudio_print_settings:
			pushad
			call hdaudio_print_out_path	
			call hdaudio_print_hp_path	
			; AFG
			mov ebx, hdaudio_DbgAFGTxt
			call gstdio_draw_text 
				; power-state
			mov ecx, [hdaudio_afg_id]
			mov [hdaudio_dbg_nid], ecx
			call hdaudio_print_pwr
				; volume
			mov ecx, [hdaudio_afg_id]
			mov [hdaudio_dbg_nid], ecx
			call hdaudio_print_gain
;*********************************
			; get parameters of the AFG
			xor edi, edi
.NextAFGPar	mov ecx, [hdaudio_afg_id]
			mov edx, [hdaudio_afg_verbs+edi]
			mov ebp, [hdaudio_afg_params+edi]
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Wait
			mov ebx, [hdaudio_afg_texts+edi]
			call gstdio_draw_text
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
			add edi, 4
			cmp DWORD [hdaudio_afg_verbs+edi], 0xFFFFFFFF
			jnz	.NextAFGPar
;*********************************
.Wait		call gutil_press_a_key
			; widgets in tree 
			mov ebx, hdaudio_DbgWidgetsTxt
			call gstdio_draw_text 
			; Out-path
			xor edx, edx
			cmp BYTE [hdaudio_tree_out_depth], 0
			jz	.HP
			mov ebx, hdaudio_DbgOutTreeTxt
			call gstdio_draw_text 
			mov dl, [hdaudio_tree_out_depth]
			mov ebx, hdaudio_tree_out_path
			call hdaudio_print_tree_settings
			; HP-path
.HP			xor edx, edx
			cmp BYTE [hdaudio_tree_hp_depth], 0
			jz	.Back
			mov ebx, hdaudio_DbgHPTreeTxt
			call gstdio_draw_text 
			mov dl, [hdaudio_tree_hp_depth]
			mov ebx, hdaudio_tree_hp_path
			call hdaudio_print_tree_settings
.Back		call gutil_press_a_key
			popad
			ret


; IN: hdaudio_dbg_nid
hdaudio_print_pwr:
			pushad
			mov ebx, hdaudio_DbgGetPwrTxt
			call gstdio_draw_text 
			mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_POWER_STATE
			xor ebp, ebp
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov ebx, hdaudio_DbgPwrTxt
			call gstdio_draw_text 
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
.Back		popad
			ret


; IN: hdaudio_dbg_nid
hdaudio_print_gain:
			pushad
			; input-right
			mov ebx, hdaudio_DbgGetGainTxt
			call gstdio_draw_text 
			mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_AMP_GAINMUTE
			mov ebp, (HDAUDIO_AMP_GET_INPUT | HDAUDIO_AMP_GET_RIGHT)		; input, right
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov ebx, hdaudio_DbgGainInpRightTxt
			call gstdio_draw_text 
			and eax, (HDAUDIO_AMP_MUTE | HDAUDIO_AMP_GAIN)
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
			; input-left
			mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_AMP_GAINMUTE
			mov ebp, (HDAUDIO_AMP_GET_INPUT | HDAUDIO_AMP_GET_LEFT)		; input, left
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov ebx, hdaudio_DbgGainInpLeftTxt
			call gstdio_draw_text 
			and eax, (HDAUDIO_AMP_MUTE | HDAUDIO_AMP_GAIN)
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
			; output-right
			mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_AMP_GAINMUTE
			mov ebp, (HDAUDIO_AMP_GET_OUTPUT | HDAUDIO_AMP_GET_RIGHT)	; output, right	
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov ebx, hdaudio_DbgGainOutpRightTxt
			call gstdio_draw_text 
			and eax, (HDAUDIO_AMP_MUTE | HDAUDIO_AMP_GAIN)
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
			; output-left
			mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_AMP_GAINMUTE
			mov ebp, (HDAUDIO_AMP_GET_OUTPUT | HDAUDIO_AMP_GET_LEFT)	; output, left
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov ebx, hdaudio_DbgGainOutpLeftTxt
			call gstdio_draw_text 
			and eax, (HDAUDIO_AMP_MUTE | HDAUDIO_AMP_GAIN)
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
.Back		popad
			ret


; IN: EBX(addr of path), EDX(depth of path)
hdaudio_print_tree_settings:
			xor ecx, ecx
.NextW		xor eax, eax
			mov al, [ebx+ecx]
			push ebx
			mov ebx, hdaudio_DbgNidTxt
			call gstdio_draw_text 
			pop ebx
			push edx
			mov edx, eax
			call gstdio_draw_hex
			pop edx
			call gstdio_new_line
			; power-setting
			mov [hdaudio_dbg_nid], eax
			call hdaudio_print_pwr
			; gain-setting
				; Mixer?	(Mixer is different: no ConnSelCtrl)
		; IN: hdaudio_dbg_nid
		; OUT: EBP(1 if yes)
			mov [hdaudio_dbg_nid], eax
			call hdaudio_is_widget_mixer
			cmp ebp, 1
			jnz	.Gain
		; IN: hdaudio_dbg_nid, EBX(addr of path), EDX(depth of path), ECX(idxOfNodeInPath)
			mov [hdaudio_dbg_nid], eax
			call hdaudio_print_gain_mixer
			jmp	.PinCtrl
.Gain		mov [hdaudio_dbg_nid], eax
			call hdaudio_print_gain
			; connection-setting
			mov [hdaudio_dbg_nid], eax
			call hdaudio_print_wid_connection
			; EAPD, if PinCaps-EAPD-capable(bit16)
			mov [hdaudio_dbg_nid], eax
			call hdaudio_print_wid_eapd

.PinCtrl	mov [hdaudio_dbg_nid], eax
			call hdaudio_print_pin_ctrl

			call gutil_press_a_key
	 		inc ecx
			cmp ecx, edx
			jnz	.NextW
			ret


; IN: hdaudio_dbg_nid
hdaudio_print_pin_ctrl:
			push eax
			push ebx
			push edx
			push ebp
			mov ebx, hdaudio_DbgWidGetPinCtrlTxt
			call gstdio_draw_text 

			; is widget a PinComplex?
			mov eax, HDAUDIO_WIDGET_REQ_NUM*4
			mov ebx, [hdaudio_dbg_nid]
			sub ebx, [hdaudio_afg_start_widget_id]
			mul ebx
			mov ebx, [hdaudio_widget_data+eax+HDAUDIO_WIDCAPS_IDX*4]
			and ebx, HDAUDIO_WCAPS_TYPE
			shr ebx, HDAUDIO_WCAPS_TYPE_SHIFT
			cmp ebx, HDAUDIO_WIDGET_PIN
			jz	.GetData
			mov ebx, hdaudio_DbgNotPinCompTxt
			call gstdio_draw_text
			jmp .Back
.GetData	mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_PIN_WIDGET_CTRL
			xor ebp, ebp
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
.Back		pop ebp
			pop edx
			pop ebx
			pop eax
			ret


; IN: hdaudio_dbg_nid
; OUT: EBP(1 if yes)
hdaudio_is_widget_mixer:
			push eax
			push ebx
			push edx
			xor ebp, ebp
			mov eax, HDAUDIO_WIDGET_REQ_NUM*4
			mov ebx, [hdaudio_dbg_nid]
			sub ebx, [hdaudio_afg_start_widget_id]
			mul ebx
			mov ebx, [hdaudio_widget_data+eax+HDAUDIO_WIDCAPS_IDX*4]
			and ebx, HDAUDIO_WCAPS_TYPE
			shr ebx, HDAUDIO_WCAPS_TYPE_SHIFT
			cmp ebx, HDAUDIO_WIDGET_AUD_MIX
			jnz	.Back
			mov ebp, 1
.Back		pop edx
			pop ebx
			pop eax
			ret


; NOTE: A Mixer behaves differently: 
;		It has no ConnSelCtrl.
; 		From its ConnectionList get the index of the IdOfThePrevNode, and set it here as the index(bits 11:8)
;		This way we get the Mixer's AmpGain for the connection.
; IN: hdaudio_dbg_nid, EBX(addr of path), EDX(depth of path), ECX(idxOfNodeInPath)
hdaudio_print_gain_mixer:
			pushad
			push ebx
			mov ebx, hdaudio_DbgGetMixerGainTxt
			call gstdio_draw_text 
			pop ebx
			inc ecx
			cmp ecx, edx
			jz	.Back											; If last node in the path, then no prev node 

			mov edx, [hdaudio_dbg_nid]
			xor eax, eax
			mov al, [ebx+ecx]									; PrevNodeId in EAX
		; IN: EDX(nodeId), EAX(prevNodeId)
		; OUT: EBP (zero-based index in conn-list), -1 if not found
			call hdaudio_get_connlist_idx
			cmp ebp, -1
			jz	.Back
			mov ebx, hdaudio_DbgGetMixerConnListIdxTxt
			call gstdio_draw_text 
			mov edx, ebp
			call gstdio_draw_hex
			call gstdio_new_line
			mov esi, ebp
			; input-right
			mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_AMP_GAINMUTE
			mov ebp, (HDAUDIO_AMP_GET_INPUT | HDAUDIO_AMP_GET_RIGHT)		; input, right
			or	ebp, esi
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov ebx, hdaudio_DbgGainInpRightTxt
			call gstdio_draw_text 
			and eax, (HDAUDIO_AMP_MUTE | HDAUDIO_AMP_GAIN)
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
			; input-left
			mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_AMP_GAINMUTE
			mov ebp, (HDAUDIO_AMP_GET_INPUT | HDAUDIO_AMP_GET_LEFT)		; input, left
			or	ebp, esi
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov ebx, hdaudio_DbgGainInpLeftTxt
			call gstdio_draw_text 
			and eax, (HDAUDIO_AMP_MUTE | HDAUDIO_AMP_GAIN)
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
			; output-right
			mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_AMP_GAINMUTE
			mov ebp, (HDAUDIO_AMP_GET_OUTPUT | HDAUDIO_AMP_GET_RIGHT)	; output, right	
			or	ebp, esi
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov ebx, hdaudio_DbgGainOutpRightTxt
			call gstdio_draw_text 
			and eax, (HDAUDIO_AMP_MUTE | HDAUDIO_AMP_GAIN)
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
			; output-left
			mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_AMP_GAINMUTE
			mov ebp, (HDAUDIO_AMP_GET_OUTPUT | HDAUDIO_AMP_GET_LEFT)	; output, left
			or	ebp, esi
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov ebx, hdaudio_DbgGainOutpLeftTxt
			call gstdio_draw_text 
			and eax, (HDAUDIO_AMP_MUTE | HDAUDIO_AMP_GAIN)
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
.Back		popad
			ret


; IN: hdaudio_dbg_nid
hdaudio_print_wid_eapd:
			pushad
			mov ebx, hdaudio_DbgWidGetEAPDTxt
			call gstdio_draw_text 
			mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_PARAMETER
			mov ebp, HDAUDIO_PARAM_WIDGET_CAPS
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			and eax, HDAUDIO_WCAPS_TYPE
			shr	eax, HDAUDIO_WCAPS_TYPE_SHIFT
			cmp eax, HDAUDIO_WIDGET_PIN
			jz	.GetPCaps
			mov ebx, hdaudio_DbgNotPinCompTxt
			call gstdio_draw_text
			jmp .Back
.GetPCaps	mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_PARAMETER
			mov ebp, HDAUDIO_PARAM_PIN_CAPS
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov ebx, hdaudio_DbgPinCapsTxt
			call gstdio_draw_text
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
			and eax, HDAUDIO_PIN_CAPS_EAPD
			jz	.Back				; Not EAPD-capable
			; get EAPD
			mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_EAPDBTL_ENABLE
			xor ebp, ebp
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			;response bit1 is EAPD
			and eax, HDAUDIO_EAPDBTL_EAPD
			jz	.NoEAPD
			mov ebx, hdaudio_DbgEAPDSetTxt
			call gstdio_draw_text
			jmp .Back
.NoEAPD		mov ebx, hdaudio_DbgEAPDNotSetTxt
			call gstdio_draw_text
.Back		popad
			ret


; IN: hdaudio_dbg_nid
hdaudio_print_wid_connection:
			pushad
			mov ebx, hdaudio_DbgWidGetConnTxt
			call gstdio_draw_text 
			mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_PARAMETER
			mov ebp, HDAUDIO_PARAM_CONN_LIST_LEN
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			and eax, HDAUDIO_CONN_LIST_LEN
			cmp eax, 0
			jz	.PrLen0
			cmp eax, 1
			jz	.PrLen1
			jmp .GetConn
.PrLen0		mov ebx, hdaudio_DbgGetWConnListlen0Txt
			call gstdio_draw_text 
			jmp .Back		; !?
.PrLen1		mov ebx, hdaudio_DbgGetWConnListlen1Txt
			call gstdio_draw_text 
			jmp .Back
			; connection
.GetConn	mov ecx, [hdaudio_dbg_nid]
			mov edx, HDAUDIO_CMD_GET_CONN_SEL_CTRL
			xor ebp, ebp
	; IN: ECX(NID), EDX(Verb), EBP(param)
	; OUT: EAX(response, verb); ECX(responseextended)
			call hdaudio_send_cmd
			cmp BYTE [hdaudio_error], 0
			jnz	.Back
			mov ebx, hdaudio_DbgWidConnTxt
			call gstdio_draw_text 
			mov edx, eax
			call gstdio_draw_hex
			call gstdio_new_line
.Back		popad
			ret

%endif	; DEBUG_SETTINGS


section .data


hdaudio_input_cnt	dd	0
; Output0 (80h+(ISS*20h), ISS is the number of input-streams in GCAP)
hdaudio_output_base	dd	0

hdaudio_detected	db	0
hdaudio_inited	db	0

hdaudio_bar_lo	dd	0
hdaudio_bar_hi	dd	0

hdaudio_codecs_mask		dw	0
hdaudio_codec_id		dd	0
hdaudio_codec_devid		dd	0
hdaudio_codec_revid		dd	0
hdaudio_codec_fg_num	dd	0
hdaudio_afg_id			dd	0
hdaudio_afg_start_widget_id		dd	0
hdaudio_afg_total_widget_num	dd	0

hdaudio_connlistlen		dd 0
hdaudio_wcaps			dd 0

hdaudio_corb_size	db	0
hdaudio_rirb_size	db	0

hdaudio_rirb_wp		db	0

hdaudio_afg_supported_pcm_fmt		dd 0
hdaudio_afg_supported_stream_fmt	dd 0
hdaudio_format						dw 0
hdaudio_mutegain					dd 0

hdaudio_paused	db 0

; to get the path(sequence of NodeIds) from PinOut to DAC
hdaudio_tree_depth		db 0
hdaudio_tree_out_depth	db 0
hdaudio_tree_hp_depth	db 0
hdaudio_tree_path		dd 0
hdaudio_tree_out_path	times HDAUDIO_MAX_WIDGET_NUM db 0
hdaudio_tree_hp_path	times HDAUDIO_MAX_WIDGET_NUM db 0
hdaudio_tree_path_fnd	db	0
hdaudio_widgets_checked	times HDAUDIO_MAX_WIDGET_NUM db 0
HDAUDIO_MAX_ENTRYNUM_PER_DWORD	equ	4
; for testing
;hdaudio_tree_depthX	db 4
;hdaudio_tree_pathX	db 0x0E, 0x0B, 0x07, 0x02	;times HDAUDIO_MAX_WIDGET_NUM db 0

; to get the data of the widgets
hdaudio_widget_verbs	dd	HDAUDIO_CMD_GET_PARAMETER, HDAUDIO_CMD_GET_PARAMETER, HDAUDIO_CMD_GET_PARAMETER, HDAUDIO_CMD_GET_PARAMETER, 
						dd	HDAUDIO_CMD_GET_PARAMETER, HDAUDIO_CMD_GET_PARAMETER, HDAUDIO_CMD_GET_PARAMETER, HDAUDIO_CMD_GET_PARAMETER 
						dd	HDAUDIO_CMD_GET_CONFIG_DEFAULT, HDAUDIO_CMD_GET_CONN_LIST_ENTRY_CTRL, HDAUDIO_CMD_GET_CONN_LIST_ENTRY_CTRL, 0xFFFFFFFF
hdaudio_widget_params	dd	HDAUDIO_PARAM_WIDGET_CAPS, HDAUDIO_PARAM_SUPP_STREAM_FORMATS, HDAUDIO_PARAM_SUPP_PCM_SIZE, 
						dd	HDAUDIO_PARAM_PIN_CAPS, HDAUDIO_PARAM_INP_AMP_CAPS, HDAUDIO_PARAM_OUTP_AMP_CAPS 
						dd	HDAUDIO_PARAM_CONN_LIST_LEN, HDAUDIO_PARAM_VOLUME_KNOB_CAPS, 0, 0, 4, 0xFFFFFFFF
hdaudio_widget_data	times HDAUDIO_MAX_WIDGET_NUM*HDAUDIO_WIDGET_REQ_NUM dd 0
; END OF "to get the data of the widgets"

hdaudio_wid_txt1	db "WCaps:", 0
hdaudio_wid_txt2	db "SuppStrmFmt:", 0
hdaudio_wid_txt3	db "SuppPCMSize:", 0
hdaudio_wid_txt4	db "PinCaps:", 0
hdaudio_wid_txt5	db "ImpAmpCaps:", 0
hdaudio_wid_txt6	db "OutpAmpCaps:", 0
hdaudio_wid_txt7	db "ConnListLen:", 0
hdaudio_wid_txt8	db "KnobCaps:", 0
hdaudio_wid_txt9	db "ConfigDef:", 0
hdaudio_wid_txt10	db "ConnListEnt:", 0
hdaudio_wid_txt11	db "ConnListEnt2:", 0

hdaudio_wid_txts_arr	dd hdaudio_wid_txt1, hdaudio_wid_txt2, hdaudio_wid_txt3, hdaudio_wid_txt4, hdaudio_wid_txt5, hdaudio_wid_txt6, hdaudio_wid_txt7, hdaudio_wid_txt8, hdaudio_wid_txt9, hdaudio_wid_txt10, hdaudio_wid_txt11


hdaudio_txt1	db	"GCAP:", 0
hdaudio_txt2	db	"VMIN:", 0
hdaudio_txt3	db	"VMAJ:", 0
hdaudio_txt4	db	"OUTPAY:", 0
hdaudio_txt5	db	"INPAY:", 0
hdaudio_txt6	db	"GCTL:", 0
hdaudio_txt7	db	"WAKEEN:", 0
hdaudio_txt8	db	"STATESTS:", 0
hdaudio_txt9	db	"GSTS:", 0
hdaudio_txt10	db	"OUTSTRMPAY:", 0
hdaudio_txt11	db	"INSTRMPAY:", 0
hdaudio_txt12	db	"INTCTL:", 0
hdaudio_txt13	db	"INTSTS:", 0
hdaudio_txt14	db	"WALCLK:", 0
hdaudio_txt15	db	"SSYNC:", 0
hdaudio_txt16	db	"CORBLBASE:", 0
hdaudio_txt17	db	"CORBUBASE:", 0
hdaudio_txt18	db	"CORBWP:", 0
hdaudio_txt19	db	"CORBRP:", 0
hdaudio_txt20	db	"CORBCTL:", 0
hdaudio_txt21	db	"CORBSTS:", 0
hdaudio_txt22	db	"CORBSIZE:", 0
hdaudio_txt23	db	"RIRBLBASE:", 0
hdaudio_txt24	db	"RIRBUBASE:", 0
hdaudio_txt25	db	"RIRBWP:", 0
hdaudio_txt26	db	"RINTCNT:", 0
hdaudio_txt27	db	"RIRBCTL:", 0
hdaudio_txt28	db	"RIRBSTS:", 0
hdaudio_txt29	db	"RIRBSIZE:", 0
hdaudio_txt30	db	"ICOI:", 0
hdaudio_txt31	db	"ICII:", 0
hdaudio_txt32	db	"ICIS:", 0
hdaudio_txt33	db	"DPIBLBASE:", 0
hdaudio_txt34	db	"DPIBUBASE:", 0
hdaudio_txt35	db	"SD0CTL:", 0
hdaudio_txt36	db	"SD0STS:", 0
hdaudio_txt37	db	"SD0LPIB:", 0
hdaudio_txt38	db	"SD0CBL:", 0
hdaudio_txt39	db	"SD0LVI:", 0
hdaudio_txt40	db	"SD0FIFOD:", 0
hdaudio_txt41	db	"SD0FMT:", 0
hdaudio_txt42	db	"SD0BDPL:", 0
hdaudio_txt43	db	"SD0BDPU:", 0

hdaudio_txtarr	dd	hdaudio_txt1, hdaudio_txt2, hdaudio_txt3, hdaudio_txt4, hdaudio_txt5, hdaudio_txt6, hdaudio_txt7, hdaudio_txt8
		dd	hdaudio_txt9, hdaudio_txt10, hdaudio_txt11, hdaudio_txt12, hdaudio_txt13, hdaudio_txt14, hdaudio_txt15, hdaudio_txt16
		dd	hdaudio_txt17, hdaudio_txt18, hdaudio_txt19, hdaudio_txt20, hdaudio_txt21, hdaudio_txt22, hdaudio_txt23, hdaudio_txt24
		dd	hdaudio_txt25, hdaudio_txt26, hdaudio_txt27, hdaudio_txt28, hdaudio_txt29, hdaudio_txt30, hdaudio_txt31, hdaudio_txt32
		dd	hdaudio_txt33, hdaudio_txt34, hdaudio_txt35, hdaudio_txt36, hdaudio_txt37, hdaudio_txt38, hdaudio_txt39, hdaudio_txt40
		dd	hdaudio_txt41, hdaudio_txt42, hdaudio_txt43

hdaudio_idarr	dd	HDAUDIO_GCAP_OFFS, HDAUDIO_VMIN_OFFS, HDAUDIO_VMAJ_OFFS, HDAUDIO_OUTPAY_OFFS, HDAUDIO_INPAY_OFFS, HDAUDIO_GCTL_OFFS
		dd	HDAUDIO_WAKEEN_OFFS, HDAUDIO_STATESTS_OFFS, HDAUDIO_GSTS_OFFS, HDAUDIO_OUTSTRMPAY_OFFS, HDAUDIO_INSTRMPAY_OFFS
		dd	HDAUDIO_INTCTL_OFFS, HDAUDIO_INTSTS_OFFS, HDAUDIO_WALCLK_OFFS, HDAUDIO_SSYNC_OFFS, HDAUDIO_CORBLBASE_OFFS
		dd	HDAUDIO_CORBUBASE_OFFS, HDAUDIO_CORBWP_OFFS, HDAUDIO_CORBRP_OFFS, HDAUDIO_CORBCTL_OFFS, HDAUDIO_CORBSTS_OFFS
		dd	HDAUDIO_CORBSIZE_OFFS, HDAUDIO_RIRBLBASE_OFFS, HDAUDIO_RIRBUBASE_OFFS, HDAUDIO_RIRBWP_OFFS, HDAUDIO_RINTCNT_OFFS
		dd	HDAUDIO_RIRBCTL_OFFS, HDAUDIO_RIRBSTS_OFFS, HDAUDIO_RIRBSIZE_OFFS, HDAUDIO_ICOI_OFFS, HDAUDIO_ICII_OFFS, HDAUDIO_ICIS_OFFS
		dd	HDAUDIO_DPIBLBASE_OFFS, HDAUDIO_DPIBUBASE_OFFS, HDAUDIO_SD0CTL_OFFS, HDAUDIO_SD0STS_OFFS, HDAUDIO_SD0LPIB_OFFS
		dd	HDAUDIO_SD0CBL_OFFS, HDAUDIO_SD0LVI_OFFS, HDAUDIO_SD0FIFOD_OFFS, HDAUDIO_SD0FMT_OFFS, HDAUDIO_SD0BDPL_OFFS, HDAUDIO_SD0BDPU_OFFS

; bytelength of regs (dword:4, word:2, ...)
hdaudio_lenarr	dd	2, 1, 1, 2, 2, 4, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 2, 2, 1, 1, 1, 4, 4, 2, 2, 1, 1, 1, 4, 4, 2, 4, 4, 3, 1, 4, 4, 2, 2, 2, 4, 4

hdaudio_CodecMaskTxt		db "Codecs-mask: ", 0
hdaudio_RootNodeTxt			db "Root node", 0x0A, 0
hdaudio_RootNodeVIdTxt		db "VenId DevId: ", 0
hdaudio_RootNodeRevIdTxt	db "RevId: ", 0
hdaudio_RootNodeFGNumTxt	db "FG-num: ", 0
hdaudio_AFGFndTxt			db "AFG-node found (id): ", 0
hdaudio_AFGNodeWidgetNumTxt	db "AFG-node wigdets: ", 0

hdaudio_RegsTxt				db "Registers", 0x0A, 0
hdaudio_DMAPosTxt			db "DMA positions", 0x0A, 0

hdaudio_OutPathTxt			db "Out-path: ", 0
hdaudio_HPPathTxt			db "HP-path: ", 0
hdaudio_NotFndTxt			db "not found", 0x0A, 0

hdaudio_DACPowerStateTxt	db "DAC PowerState: ", 0
hdaudio_GainMuteTxt			db "GainMute: ", 0
hdaudio_FormatTxt			db "Format: ", 0
hdaudio_EAPDTxt				db "EAPD: ", 0
hdaudio_ConnectionTxt		db "Connection: ", 0
hdaudio_ConvStreamChanTxt 	db "Converter stream, chan: ", 0
hdaudio_PinCtrlTxt			db "PinCtrl: ", 0
hdaudio_AFGSupportsTxt		db "AFGSupports: ", 0
hdaudio_AFGPowerStateTxt	db "AFGPwrState: ", 0

hdaudio_base_bits4		dd	0	; bits2:1=00 the address is <4GB; bits2:1=01 it is <1MB; bits2:1=10 it is 64bits (get the high 32bits of the address from next base address field of the PCI); bit3 is reserved
hdaudio_NotMemMappedIOTxt	db "Not memory mapped IO. ", 0

hdaudio_64bitBase0Txt		db "Base0 is 64-bits (32bit OS). ", 0

hdaudio_OutputStreamsNotSuppErrTxt	db "Output-streams not supported by hardware! Exiting.", 0x0A, 0
hdaudio_InitErrorTxt				db "Init error", 0x0A, 0
hdaudio_ResetCORBFailedTxt			db "Reset CORB failed. ", 0
hdaudio_ResetRIRBFailedTxt			db "Reset RIRB failed. ", 0
hdaudio_ResetControllerFailed1Txt	db "Reset controller failed 1. ", 0
hdaudio_ResetControllerFailed2Txt	db "Reset controller failed 2. ", 0
hdaudio_ResetRPErrorTxt				db "Reset read pointer failed. ", 0
hdaudio_ResetStreamErrorTxt			db "Reset stream failed. ", 0
hdaudio_SetConvStreamErrTxt			db "Error: SetConvStream", 0x0A, 0
hdaudio_GetSuppStreamFmtErrTxt		db "Error: Getting supported stream format.", 0x0A, 0
hdaudio_GetSuppPCMFmtErrTxt			db "Error: Getting supported PCM format.", 0x0A, 0
hdaudio_PrepareAFGErrTxt			db "Error: Prepare AFG", 0x0A, 0
hdaudio_PreparePathErrTxt			db "Error: PreparePath", 0x0A, 0
hdaudio_PrepareKnobErrTxt			db "Error: PrepareKnob", 0x0A, 0
hdaudio_UnmuteOutpErrTxt			db "Error: UnmuteOutput", 0x0A, 0
hdaudio_UnmuteOutp2ErrTxt			db "Error: UnmuteMixer", 0x0A, 0
hdaudio_SelectInpConnErrTxt			db "Error: SelectInpConn", 0x0A, 0
hdaudio_SetPinWidCtrlTxt			db "Error: Set PinWidCtrl", 0x0A, 0
hdaudio_SetPwrStateErrTxt			db "Error: Set PowerState", 0x0A, 0
hdaudio_SetVolErrTxt				db "Error: Set volume", 0x0A, 0
hdaudio_GetVolErrTxt				db "Error: Get volume", 0x0A, 0

hdaudio_error				db	0

hdaudio_64ok	db 0

; It is easier to parse the two DWORDS in ConnListEntry1 and 2 if we put the data in consecutive memory loactions
hdaudio_connlistentries	dd	0
						dd	0

%ifdef DEBUGPARSE
	dbg_parseTxt	db "parsing", 0
	dbg_LineOutTxt	db "(LineOut): ", 0
	dbg_SpeakerTxt	db "(Speaker): ", 0
	dbg_HPTxt		db "(HPhone): ", 0
	dbg_FirstTxt	db "(First): ", 0

	dbg_arr_jack_txts	dd	dbg_LineOutTxt, dbg_SpeakerTxt, dbg_HPTxt
%endif

%ifdef DEBUG_SETTINGS
	hdaudio_dbg_nid	dd 0

; to get the data of the AFG
hdaudio_afg_verbs	dd	HDAUDIO_CMD_GET_PARAMETER, HDAUDIO_CMD_GET_PARAMETER, HDAUDIO_CMD_GET_PARAMETER, HDAUDIO_CMD_GET_PARAMETER  
					dd	HDAUDIO_CMD_GET_PARAMETER, HDAUDIO_CMD_GET_PARAMETER, HDAUDIO_CMD_GET_PARAMETER, HDAUDIO_CMD_GET_CONFIG_DEFAULT 
					dd	0xFFFFFFFF
hdaudio_afg_params	dd	HDAUDIO_PARAM_WIDGET_CAPS, HDAUDIO_PARAM_SUPP_STREAM_FORMATS, HDAUDIO_PARAM_SUPP_PCM_SIZE, 
					dd	HDAUDIO_PARAM_PIN_CAPS, HDAUDIO_PARAM_INP_AMP_CAPS, HDAUDIO_PARAM_OUTP_AMP_CAPS 
					dd	HDAUDIO_PARAM_VOLUME_KNOB_CAPS, 0, 0xFFFFFFFF
;hdaudio_afg_data	times 8 dd 0
hdaudio_afg_texts	dd hdaudio_afg_txt1, hdaudio_afg_txt2, hdaudio_afg_txt3, hdaudio_afg_txt4, hdaudio_afg_txt5, hdaudio_afg_txt6 
					dd hdaudio_afg_txt7, hdaudio_afg_txt8, 0xFFFFFFFF
hdaudio_afg_txt1 db "WCaps: ", 0
hdaudio_afg_txt2 db "SuppStrmFmt :", 0
hdaudio_afg_txt3 db "SuppPCMSize :", 0
hdaudio_afg_txt4 db "PinCaps :", 0
hdaudio_afg_txt5 db "InpAmpCaps :", 0
hdaudio_afg_txt6 db "OutpAmpCaps :", 0
hdaudio_afg_txt7 db "VolumeCaps :", 0
hdaudio_afg_txt8 db "ConfigDef :", 0
; END OF "to get the data of the AFG"

	hdaudio_DbgAFGTxt					db "Dbg: ***AFG***", 0x0A, 0
	hdaudio_DbgWidgetsTxt				db "Dbg: ***Widget***", 0x0A, 0
	hdaudio_DbgOutTreeTxt				db "Dbg: OutTree settings", 0x0A, 0
	hdaudio_DbgHPTreeTxt				db "Dbg: HPTree settings", 0x0A, 0
	hdaudio_DbgGetPwrTxt				db "Dbg: get power", 0x0A, 0
	hdaudio_DbgGetPwrErrorTxt			db "Dbg: GetPower error", 0x0A, 0
	hdaudio_DbgPwrTxt					db "Dbg: powerstate=", 0
	hdaudio_DbgGetGainTxt				db "Dbg: get gain", 0x0A, 0
	hdaudio_DbgGainInpRightTxt			db "Dbg: gaininpright=", 0
	hdaudio_DbgGainInpLeftTxt			db "Dbg: gaininpleft=", 0
	hdaudio_DbgGainOutpLeftTxt			db "Dbg: gainoutpleft=", 0
	hdaudio_DbgGainOutpRightTxt			db "Dbg: gainoutpright=", 0
	hdaudio_DbgGetGainInpRightErrorTxt	db "Dbg: GetGainInpRight error", 0x0A, 0
	hdaudio_DbgGetGainInpLeftErrorTxt	db "Dbg: GetGainInpLeft error", 0x0A, 0
	hdaudio_DbgGetGainOutpRightErrorTxt	db "Dbg: GetGainOutpRight error", 0x0A, 0
	hdaudio_DbgGetGainOutpLeftErrorTxt	db "Dbg: GetGainOutpLeftError", 0x0A, 0
	hdaudio_DbgNidTxt					db "Dbg: +++++Nid=", 0
	hdaudio_DbgWidGetConnTxt			db "Dbg: get connection", 0x0A, 0
	hdaudio_DbgGetWConnListLenErrorTxt	db "Dbg: Get widget connlistlen error", 0x0A, 0
	hdaudio_DbgGetWConnListlen0Txt		db "Dbg: get widget connlistlen is 0", 0x0A, 0
	hdaudio_DbgGetWConnListlen1Txt		db "Dbg: get widget connlistlen is 1", 0x0A, 0
	hdaudio_DbgGetWConnErrorTxt			db "Dbg: get widget connection error", 0x0A, 0
	hdaudio_DbgWidConnTxt				db "Dbg: widget connection=", 0
	hdaudio_DbgWidGetEAPDTxt			db "Dbg: get EAPD", 0x0A, 0
	hdaudio_DbgGetWCapsErrorTxt			db "Dbg: wcaps error", 0x0A, 0
	hdaudio_DbgNotPinCompTxt			db "Dbg: widget is not a pincomplex", 0x0A, 0
	hdaudio_DbgGetPinCapsErrorTxt		db "Dbg: get pincaps error", 0x0A, 0
	hdaudio_DbgPinCapsTxt				db "Dbg: pincaps=", 0
	hdaudio_DbgGetEAPDErrorTxt			db "Dbg: get EAPD error", 0x0A, 0
	hdaudio_DbgEAPDSetTxt				db "Dbg: EAPD set", 0x0A, 0
	hdaudio_DbgEAPDNotSetTxt			db "Dbg: EAPD not set", 0x0A, 0
	hdaudio_DbgSendCmdErrorTxt			db "Dbg: sendcmd error", 0x0A, 0
	hdaudio_DbgGetMixerGainTxt			db "Dbg: get mixer gain", 0x0A, 0
	hdaudio_DbgGetMixerConnListIdxTxt	db "Dbg: *+*+*+*+*+*Mixer connlistIdx=", 0
	hdaudio_DbgWidGetPinCtrlTxt			db "Dbg: PinCtrl=", 0
%endif


%endif


