;************************
; Audio
;************************

%ifndef __FORTH_AUDIO__
%define __FORTH_AUDIO__


%include "hdaudio.asm"
%include "forth/common.asm"

audio_fmt_bps_txt db 'Supported BPS: ', 0
audio_fmt_sr_txt db 'Supported SampleRate: ', 0
audio_bps_1 db '8', 0
audio_bps_2 db '16', 0
audio_bps_3 db '20', 0
audio_bps_4 db '24', 0
audio_bps_5 db '32', 0
audio_bps_arr dd audio_bps_1, audio_bps_2, audio_bps_3, audio_bps_4, audio_bps_5

audio_sr_1 db '8.0', 0
audio_sr_2 db '11.025', 0
audio_sr_3 db '16.0', 0
audio_sr_4 db '22.05', 0
audio_sr_5 db '32.0', 0
audio_sr_6 db '44.1', 0
audio_sr_7 db '48.0', 0
audio_sr_8 db '88.2', 0
audio_sr_9 db '96.0', 0
audio_sr_10 db '176.4', 0
audio_sr_11 db '192.0', 0
audio_sr_12 db '384.0', 0
audio_sr_arr dd audio_sr_1, audio_sr_2, audio_sr_3, audio_sr_4, audio_sr_5, audio_sr_6, audio_sr_7, audio_sr_8, audio_sr_9, audio_sr_10, audio_sr_11, audio_sr_12

audio_err_msg db "Audio: unsupported format", 0x0A, 0

audio_stream_fmts_txt	db "Supported stream formats: ", 0
audio_pcm_txt			db "pcm ", 0
audio_float32_txt		db "float32 ", 0
audio_ac3_txt			db "ac3 ", 0
audio_none_txt			db "none ", 0


;*************************************************
; _audio_get_supported_format	AUGETSUPPFMT
;	( -- formatPCM formatStream )
; Page 204 of HDAudio specification
;*************************************************
_audio_get_supported_format:
			call hdaudio_get_supported_pcm_format
			PUSH_PS(eax)
			call hdaudio_get_supported_stream_format
			PUSH_PS(eax)
			ret


;*************************************************
; _audio_print_format	AUPRINTFMT
;	( formatPCM formatStream -- )
; Page 204 of HDAudio specification
;*************************************************
_audio_print_format:
			push ebp
			POP_PS(eax)
			call gstdio_new_line
			mov ebx, audio_stream_fmts_txt
			call gstdio_draw_text
			mov edx, eax
			and edx, 1
			jz	.ChkFloat32
			mov ebx, audio_pcm_txt
			call gstdio_draw_text
.ChkFloat32	mov edx, eax
			and edx, 2
			jz	.ChkAC3
			mov ebx, audio_float32_txt
			call gstdio_draw_text
.ChkAC3		mov edx, eax
			and edx, 4
			jz	.ChkNone
			mov ebx, audio_ac3_txt
			call gstdio_draw_text

.ChkNone	and eax, 7
			jnz	.NL
			mov ebx, audio_none_txt
			call gstdio_draw_text

.NL			call gstdio_new_line

			POP_PS(eax)
			; SampleRate
			mov ebx, audio_fmt_sr_txt
			call gstdio_draw_text
			mov ebx, audio_sr_arr
			mov ebp, 12
			call print_fmt
			call gstdio_new_line
			; BPS			
			shr eax, 16
			mov ebx, audio_fmt_bps_txt
			call gstdio_draw_text
			mov ebx, audio_bps_arr
			mov ebp, 5
			call print_fmt
			call gstdio_new_line
			pop ebp
			ret


print_fmt:
			xor ecx, ecx
.Test		mov edx, 1
			shl edx, cl
			test eax, edx
			jz	.Inc
			mov edx, ecx
			shl edx, 2					; *4 to get DWORD from byte
			push ebx
			add ebx, edx
			mov ebx, [ebx]
			call gstdio_draw_text
			mov ebx, ' '
			call gstdio_draw_char
			pop ebx
.Inc		inc ecx
			cmp ecx, ebp
			jnge .Test
			ret

;*************************************************
; _audio_init			AUINIT
;	( -- flag )
;*************************************************
_audio_init:
			call hdaudio_init_controller
			cmp BYTE [hdaudio_error], 0
			jnz	.Err
			PUSH_PS(TRUE)
			jmp .Back
.Err		PUSH_PS(FALSE)
.Back		ret


;*************************************************
; _audio_info			AUINFO
;	( -- )
;*************************************************
_audio_info:
			call hdaudio_info
			ret


;*************************************************
; _audio_codecs_info	AUCODECSINFO
;	( -- )
;*************************************************
_audio_codecs_info:
			call hdaudio_codecs_info
			ret


;*************************************************
; _audio_play			AUPLAY
;	( addrofPCM length format -- )
;	for format, see page 58 of HDAudio specification
;	Only PCM is supported, so bit15 is not checked 
;	but it is set to the registers
;*************************************************
_audio_play:
			POP_PS(ecx)
			POP_PS(ebx)
			POP_PS(eax)
			call hdaudio_play
			ret


;*************************************************
; _audio_stop			AUSTOP
;	( -- )
;*************************************************
_audio_stop:
			call hdaudio_stop
			ret


;*************************************************
; _audio_setvol			AUSETVOL
;	( muteandgain -- )  [bit 7 mute, 6-0 gain]	page 146 in HDAudio specification
;	from KolibriOS: ( volume -- )  [-10000 - 0]
;	sets outputamp
;*************************************************
_audio_setvol:
			POP_PS(eax)
			call hdaudio_setvol
			ret


;*************************************************
; _audio_getvol			AUGETVOL
;	( -- muteandgain)  [bit 7 mute, 6-0 gain]	page 146 in HDAudio specification
;	from KolibriOS: ( volume -- )  [-10000 - 0]
;	gets outputamp
;*************************************************
_audio_getvol:
			call hdaudio_getvol
			PUSH_PS(eax)
			ret


;*************************************************
; _audio_pause			AUPAUSE
;	( -- )
;*************************************************
_audio_pause:
			call hdaudio_pause
			ret


;*************************************************
; _audio_resume			AURESUME
;	( -- )
;*************************************************
_audio_resume:
			call hdaudio_resume
			ret


; Wav-header
; offsets in bytes
WAV_RIFF		equ 0		; "RIFF"
WAV_FILESIZE	equ 4		; DWORD (file - 8 bytes)
WAV_FILETYPE	equ 8		; "WAVE"	(always)	(Format)
WAV_CHUNKMARKER	equ 12		; "fmt " (includes 0)	(Subchunk1ID)
WAV_LENFDATA	equ 16		; 16 for PCM	DWORD	(Subchunk1Size; this is the size of the rest of the Subchunk which follows this number)
WAV_TYPE		equ 20		; 1 is PCM		WORD 	(AudioFormat; other than 1 means some form of compression)
WAV_NUMOFCHNLS	equ 22		; WORD					(Mono=1, Stereo=2, etc)
WAV_SAMPLERATE	equ 24		; DWORD					(44100, etc)
WAV_SBC			equ 28		; (SampleRate*BitsPerSample*NumChannels)/8  DWORD (ByteRate)
WAV_BPSC		equ 32		; (BitsPerSample*NumChannels/8)  WORD	(BlockAlign)
WAV_BPS			equ 34		; WORD
; 2 bytes ExtraParamSize (if PCM, then doesn't exist)
; X bytes ExtraParams	(Space for extra params)
WAV_MDATA		equ 36		; Data Chunk Header, marks the beginning of the data section  DWORD (contains the letters: "data")
WAV_SIZEOFDATA	equ 40		; Size of data section  DWORD (NumSamples*NumChannels*BitsPerSample/8; number of bytes in the data.)
WAV_DATA		equ 44		; The actual sound data
;!!!It's possible to have other chunks before 'data' (e.g. 'LIST'), we have to skip them!!!

;*************************************************
; _audio_wav				AUWAV
;	( addrofwavfile -- flag )
; pages 58 and 204 of the HDAudio specs
;*************************************************
_audio_wav:
			pushad
			call hdaudio_get_supported_stream_format		; OUT: EAX
			and eax, 1
			jz	.Err
			mov edx, [esi]
			add edx, WAV_TYPE
			cmp WORD [edx], 1		; PCM ?
			jnz	.Err
			sub edx, WAV_TYPE
			xor ebp, ebp			; PCM
			; check if format supported
			call hdaudio_get_supported_pcm_format		; OUT: EAX
			add edx, WAV_BPS
			cmp WORD [edx], 32
			je	.ChkFMT32
			cmp WORD [edx], 24
			je	.ChkFMT24
			cmp WORD [edx], 20
			je	.ChkFMT20
			cmp WORD [edx], 16
			je	.ChkFMT16
			cmp WORD [edx], 8
			je	.ChkFMT8
			jmp .Err
.ChkFMT32	test eax, (1 << 20)
			jz	.Err
			or	ebp, (4 << 4)
			jmp .ChkRate
.ChkFMT24	test eax, (1 << 19)
			jz	.Err
			or	ebp, (3 << 4)
			jmp .ChkRate
.ChkFMT20	test eax, (1 << 18)
			jz	.Err
			or	ebp, (2 << 4)
			jmp .ChkRate
.ChkFMT16	test eax, (1 << 17)
			jz	.Err
			or	ebp, (1 << 4)
			jmp .ChkRate
.ChkFMT8	test eax, (1 << 16)
			jz	.Err
.ChkRate	sub edx, WAV_BPS
			add edx, WAV_SAMPLERATE
			cmp DWORD [edx], 384000
			je	.Err
			cmp DWORD [edx], 192000
			je	.ChkR192
			cmp DWORD [edx], 176400
			je	.ChkR1764
			cmp DWORD [edx], 96000
			je	.ChkR96
			cmp DWORD [edx], 88200
			je	.ChkR882
			cmp DWORD [edx], 48000
			je	.ChkR48
			cmp DWORD [edx], 44100
			je	.ChkR441
			cmp DWORD [edx], 32000
			je	.ChkR32
			cmp DWORD [edx], 22050
			je	.ChkR2205
			cmp DWORD [edx], 16000
			je	.ChkR16
			cmp DWORD [edx], 11025
			je	.ChkR11025
			cmp DWORD [edx], 8000
			je	.ChkR8
			jmp .Err
.ChkR192	test eax, (1 << 10)
			jz	.Err
			or	ebp, (3 << 11)
			jmp .SetChNum
.ChkR1764	test eax, (1 << 9)
			jz	.Err
			or	ebp, (1 << 14)			; set base to 44.1Khz
			or	ebp, (3 << 11)
			jmp .SetChNum
.ChkR96		test eax, (1 << 8)
			jz	.Err
			or	ebp, (1 << 11)
			jmp .SetChNum
.ChkR882	test eax, (1 << 7)
			jz	.Err
			or	ebp, (1 << 14)			; set base to 44.1Khz
			or	ebp, (1 << 11)
			jmp .SetChNum
.ChkR48		test eax, (1 << 6)
			jz	.Err
			jmp .SetChNum
.ChkR441	test eax, (1 << 5)
			jz	.Err
			or	ebp, (1 << 14)			; set base to 44.1Khz
			jmp .SetChNum
.ChkR32		test eax, (1 << 4)
			jz	.Err
			or	ebp, (1 << 11)
			or	ebp, (2 << 8)
			jmp .SetChNum
.ChkR2205	test eax, (1 << 3)
			jz	.Err
			or	ebp, (1 << 14)			; set base to 44.1Khz
			or	ebp, (1 << 8)
			jmp .SetChNum
.ChkR16		test eax, (1 << 2)
			jz	.Err
			or	ebp, (3 << 8)
			jmp .SetChNum
.ChkR11025	test eax, (1 << 1)
			jz	.Err
			or	ebp, (1 << 14)			; set base to 44.1Khz
			or	ebp, (3 << 8)
			jmp .SetChNum
.ChkR8		test eax, (1 << 0)
			jz	.Err
			or	ebp, (5 << 8)
.SetChNum	sub edx, WAV_SAMPLERATE
			add edx, WAV_NUMOFCHNLS
			xor eax, eax
			mov ax, WORD [edx]
			sub eax, 1
			or	ebp, eax
			; advance memaddr to beginning of possible pcm-data
			mov edx, [esi]
			add edx, WAV_MDATA
			; check if this is the 'data'-chunk, if not then skip it
.ChkData	cmp DWORD [edx], 'data'
			je	.GetData
			add edx, 4
			add edx, [edx]
			add edx, 4
			jmp .ChkData
.GetData	add edx, 4
			mov ecx, [edx]				; length
			add edx, 4
			mov [esi], edx
			PUSH_PS(ecx)				; length
			PUSH_PS(ebp)				; format
			call _audio_play
			jmp .Ok
.Err		POP_PS(eax)
			PUSH_PS(FALSE)
			mov ebx, audio_err_msg
			call gstdio_draw_text
			jmp .Back
.Ok			PUSH_PS(TRUE)
.Back		popad
			ret


%endif





