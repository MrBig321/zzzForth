%ifndef __VGA2__
%define	__VGA2__ 

%include "stdio16.asm"
 
bits 16	
 
 
;**VBE return status** 
;	AL  	= 0x4Fh - Function is supported
;			!= 0x4Fh - Function is not supported
;	AH  	0x00 - Function call successful 
;			0x01 - Function call failed 
;			0x02 - Software supports this function, but the hardware does not support function
;			0x03 - Function call invalid in current video mode 


; *****Retrieve VESA Information*****:
; Input 	AX = 4F00h	Return VBE Controller Information
;			ES:DI		Pointer to buffer in which to place VbeInfoBlock structure (VbeSignature should be set to 'VBE2' when function is called to indicate VBE 2.0 information is desired and the information block is 512 bytes in size.)

; Output:  	AX 	VBE Return Status (AL == 4Fh [func exists]; AH == 00h [success] AH == 01h failed)

;VbeInfoBlock
;    char VbeSignature[4] = {'V', 'E', 'S', 'A};        // VBE Signature
;    short VbeVersion = 0x0200;                         // VBE Version
;    char *OemStringPtr;                                // Pointer to OEM String			(4 bytes)
;    unsigned long Capabilities;                        // Capabilities of graphics cont.	(4 bytes)
;    short *VideoModePtr;                               // Pointer to Video Mode List		(4 bytes)
;    unsigned short TotalMemory;                        // Number of 64kb memory blocks

;    // Added for VBE 2.0
;    short OemSoftwareRev;                              // VBE implementation Software revision
;    char *OemVendorNamePtr;                            // Pointer to Vendor Name String
;    char *OemProductNamePtr;                           // Pointer to Product Name String
;    char *OemProductRevPtr;                            // Pointer to Product Revision String

;    char Reserved[222];                                // Reserved for VBE implementation

;    // scratch area
;    char OemData[256];                                 // Data Area for OEM Strings
; End of VbeInfoBlock


;Description of the VbeInfoBlock structure fields:

;   VbeSignature
;        The VbeSignature field is filled with the ASCII characters 'VESA' by the VBE implementation.  VBE 2.0 applications should preset this field with the ASCII characters 'VBE2' to indicate to the VBE implementation that the VBE 2.0 extended information is desired, and the VbeInfoBlock is 512 bytes in size.  Upon return from VBE Function 00h, this field should always be set to 'VESA' by the VBE implementation.
;    VbeVersion
;        VbeVersion is a BCD value which specifies what level of the VBE standard is implemented in the software. The higher byte specifies the major version number. The lower byte specifies the minor version number.
;        The BCD value for VBE 2.0 is 0200h and the BCD value for VBE 1.2 is 0102h. In the past we have had some applications misinterpreting these BCD values.  For example, BCD 0102h was interpreted as 1.02, which is incorrect.
;    OemStringPtr
;        The OemStringPtr is a Real Mode far pointer to a null terminated OEM-defined string. This string may be used to identify the graphics controller chip or OEM product family for hardware specific display drivers. There are no restrictions on the format of the string.  This pointer may point into either ROM or RAM, depending on the specific implementation.  VBE 2.0 BIOS implementations must place this string in the OemData area within the VbeInfoBlock if 'VBE2' is preset in the VbeSignature field on entry to Function 00h.  This makes it possible to convert the RealMode address to an offset within the VbeInfoBlock for Protected mode applications.
;        The length of the OEMString is not defined, but for space considerations, we recommend a string length of less than 256 bytes.
;    Capabilities
;        The Capabilities field indicates the support of specific features in the graphics environment. The bits are defined as follows:

 
;		D0 	0 - DAC is fixed width, with 6 bits per primary color 
;			1 - DAC width is switchable to 8 bits per primary color 
;		D1 	0 - Controller is VGA compatible 
;			1 - Controller is not VGA compatible 
;		D2 	0 - Normal RAMDAC operation 
;			1 - When programming large blocks of information to the RAMDAC use blank bit in Function 09h. i.e. RAMDAC recommends programming during blank period only. 
;		D3-31  	Reserved
 

;        BIOS Implementation Note: The DAC must always be restored to 6 bits per primary as default upon a mode set.  If the DAC has been switched to 8 bits per primary, the mode set must restore the DAC to 6 bits per primary to ensure the application developer that he does not have to reset it.
;        Application Developer's Note:  If a DAC is switchable, you can assume that the DAC will be restored to 6 bits per primary upon a mode set. For an application to use a DAC the application program is responsible for setting the DAC to 8 bits per primary mode using Function 08h.
;        VGA compatibility is defined as supporting all standard IBM VGA modes, fonts and I/O ports; however, VGA compatibility doesn't guarantee that all modes which can be set are VGA compatible, or that the 8x14 font is available.
;        The need for D2 = 1 is for older style RAMDAC's where programming the RAM values during display time causes a "snow-like" effect on the screen. Newer style RAMDAC's don't have this limitation and can easily be programmed at any time, but older RAMDAC's require the that they be blanked so as not to display the snow while values change during display time..  This bit informs the software that they should make the function call with 80h rather than 00h to ensure the minimization of the "snow-like" effect.
;    VideoModePtr
;        The VideoModePtr points to a list of  mode numbers for all  display modes supported by the VBE implementation.  Each mode number occupies one word (16 bits). The list of mode numbers is terminated by a -1 (0FFFFh).  The mode numbers in this list represent all of the potentially supported modes by the display controller.  Please refer to Chapter 3 for a description of VESA VBE mode numbers.  VBE 2.0 BIOS implementations must place this mode list in the Reserved area in the VbeInfoBlock or have it statically stored within the VBE implementation if 'VBE2' is preset in the VbeSignature field on entry to Function 00h.
;        It is the application's responsibility to verify the actual availability of any mode returned by this function through the Return VBE Mode Information (VBE Function 01h) call. Some of the returned modes may not be available due to the actual amount of memory physically installed on the display board or due to the capabilities of the attached monitor.
;        If a VideoModeList is found to contain no entries (starts with 0FFFFh), it can be assumed that the VBE implementation is a "stub" implementation where only Function 00h is supported for diagnostic or "Plug and Play" reasons.  These stub implementations are not VBE 2.0 compliant and should only be implemented in cases where no space is available to implement the whole VBE.
;    TotalMemory
;        The TotalMemory field indicates the maximum amount of memory physically installed and available to the frame buffer in 64KB units. (e.g. 256KB = 4, 512KB = 8)  Not all video modes can address all this memory, see the ModeInfoBlock for detailed information about the addressible memory for a given mode.
;    OemSoftwareRev
;        The OemSoftwareRev field is a BCD value which specifies the OEM revision level of the VBE software.  The higher byte specifies the major version number. The lower byte specifies the minor version number.  This field can be used to identify the OEM's VBE software release.  This field is only filled in when 'VBE2' is preset in the VbeSignature field on entry to Function 00h.
;    OemVendorNamePtr
;        The OemVendorNamePtr is a pointer to  a null-terminated string containing the name of the vendor who produced the display controller board product.  (This string may be contained in the VbeInfoBlock or the VBE implementation.)  This field is only filled in when 'VBE2' is preset in the VbeSignature field on entry to Function 00h.  (Note: the length of the strings OemProductRev, OemProductName and OemVendorName (including terminators) summed, must fit within a 256 byte buffer; this is to allow for return in the OemData field if necessary.)
;    OemProductNamePtr
;        The OemProductNamePtr is a pointer to  a null-terminated string containing the product name of the display controller board.  (This string may be contained in the VbeInfoBlock or the VBE implementation.)  This field is only filled in when 'VBE2' is preset in the VbeSignature field on entry to Function 00h.  (Note:  the length of the strings OemProductRev, OemProductName and OemVendorName (including terminators) summed, must fit within a 256 byte buffer; this is to allow for return in the OemData field if necessary.)
;    OemProductRevPtr
;        The OemProductRevPtr is a pointer to a null-terminated string containing the revision or manufacturing level of the display controller board product.  (This string may be contained in the VbeInfoBlock or the VBE implementation.)  This field can be used to determine which production revision of the display controller board is installed.  This field is only filled in when 'VBE2' is preset in the VbeSignature field on entry to Function 00h.  (Note:  the length of the strings OemProductRev, OemProductName and OemVendorName (including terminators) summed, must fit within a 256 byte buffer; this is to allow for return in the OemData field if necessary.)
;    Reserved
;        The Reserved field is a space reserved for dynamically building the VideoModeList if necessary if the VideoModeList is not statically stored within the VBE implementation.  This field should not be used for anything else, and may be reassigned in the future.  Application software should not assume that information in this field is valid.
;    OemData
;        The OemData field is a 256 byte data area that is used to return OEM information returned by VBE Function 00h when 'VBE2' is preset in the VbeSignature field.  The OemVendorName string, OemProductName string and OemProductRev string are copied into this area by the VBE implementation.  This area will only be used by VBE implementations 2.0 and above when 'VBE2' is preset in the VbeSignature field.


;*****Return VBE Mode Information*****:
;Input: 	AX 	0x4F01 - Return VBE mode information
;			CX 	Mode number
;			ES:DI 	Pointer to ModeInfoBlock structure
;Output: 	AX 	VBE Return Status  (if AL==4Fh then OK)

;Note: All other registers are preserved.

;The mode information block has the following structure:
;ModeInfoBlock
;    // Mandatory information for all VBE revisions
;    unsigned short ModeAttributes;                    // mode attributes
;    unsigned char WinAAttributes;                     // window A attributes
;    unsigned char WinBAttributes;                     // window B attributes
;    unsigned short WinGranularity;                    // window granularity
;    unsigned short WinSize;                           // window size
;    unsigned short WinASegment;                       // window A start segment
;    unsigned short WinBSegment;                       // window B start segment
;    void (*WinFuncPtr)();                             // pointer to window function (4 bytes)
;    unsigned short BytesPerScanLine;                  // bytes per scan line

;    // Mandatory information for VBE 1.2 and above
;    unsigned short XResolution;                       // horizontal resolution in pixels or chars
;    unsigned short YResolution;                       // vertical resolution in pixels or chars
;    unsigned char XCharSize;                          // character cell width in pixels
;    unsigned char YCharSize;                          // character cell height in pixels
;    unsigned char NumberOfPlanes;                     // number of memory planes
;    unsigned char BitsPerPixel;                       // bits per pixel
;    unsigned char NumberOfBanks;                      // number of banks
;    unsigned char MemoryModel;                        // memory model type
;    unsigned char BankSize;                           // bank size in KB
;    unsigned char NumberOfImagePages;                 // number of images
;    unsigned char Reserved;                           // reserved for page function

;    // Direct Color fields (required for direct/6 and YUV/7 memory models)
;    unsigned char RedMaskSize;                        // size of direct color red mask in bits
;    unsigned char RedFieldPosition;                   // bit position of lsb of red mask
;    unsigned char GreenMaskSize;                      // size of direct color green mask in bits
;    unsigned char GreenFieldPosition;                 // bit position of lsb of green mask
;    unsigned char BlueMaskSize;                       // size of direct color blue mask in bits
;    unsigned char BlueFieldPosition;                  // bit position of lsb of blue mask
;    unsigned char RsvdMaskSize;                       // size of direct color reserved mask in bits
;    unsigned char RsvdFieldPosition;                  // bit position of lsb of reserved mask
;    unsigned char DirectColorModeInfo;                // direct color mode attributes

;    // Mandatory information for VBE 2.0 and above
;    char *PhysBasePtr;                                // physical address for flat frame buffer (4 bytes)
;    char *OffScreenMemOffset;                         // pointer to start of off screen memory
;    unsigned short OffScreenMemSize;                  // amount of off screen memory in 1k units

;    char Reserved[206];                               // remainder of ModeInfoBlock
; End of ModeInfoBlock

;Field descriptions:

;The ModeAttributes field describes certain important characteristics
;of the graphics mode.
 
;    ModeAttributes
;        The ModeAttributes field is defined as follows:

;			D0 	Mode supported by hardware configuration 
;				0 - Not supported 
;				1 - Supported 

;				This bit is reset to indicate the unavailability of a graphics mode if it requires a certain monitor type, more memory than is physically installed, etc
;			D1 	Reserved (=1) 

;			Was used by VBE 1.0 and 1.1 to indicate that the optional information following the BytesPerScanLine field were present in the data structure.  This information became mandatory with VBE version 1.2 and above, so D1 is no longer used and should be set to 1.  The Direct Color fields are valid only if the MemoryModel field is set to a 6 (Direct Color) or 7 (YUV)
;			D2 	TTY Output functions supported by BIOS 
;				0 - Not supported 
;				1 - Supported 

;				Indicates whether the video BIOS has support for output functions like TTY output, scroll, etc. in this mode.  TTY support is recommended but not required for all extended text and graphic modes. If bit D2 is set to 1, then the INT 10h BIOS must support all of the standard output functions listed below. 

;			All of the following TTY functions must be supported when this bit is set: 

;			01   Set Cursor Size 
;			02   Set Cursor Position 
;			06   Scroll TTY window up or Blank Window 
;			07   Scroll TTY window down or Blank Window 
;			09   Write character and attribute at cursor position 
;			0A   Write character only at cursor position 
;			0E   Write character and advance cursor
;			D3 	Monochrome/color mode (see note below) 
;				0 - Monochrome mode 
;				1 - Color mode 

;				Set to indicate color modes, and cleared for monochrome modes
;			D4 	Mode type 
;				0 - Text mode 
;				1 - Graphics mode 

;				Set to indicate graphics modes, and cleared for text modes 

;				Note: Monochrome modes map their CRTC address at 3B4h. Color modes map their CRTC address at 3D4h. Monochrome modes have attributes in which only bit 3 (video) and bit 4 (intensity) of the attribute controller output are significant. Therefore, monochrome text modes have attributes of off, video, high intensity, blink, etc. Monochrome graphics modes are two plane graphics modes and have attributes of off, video, high intensity, and blink. Extended two color modes that have their CRTC address at 3D4h, are color modes with one bit per pixel and one plane. The standard VGA modes, 06h and 11h would be classified as color modes, while the standard VGA modes 07h and 0Fh would be classified as monochrome modes. 
;			D5 	VGA compatible mode 
;				0 - Yes 
;				1 - No 

;				Used to indicate if the mode is compatible with the VGA hardware registers and I/O ports.  If this bit is set, then the mode is NOT VGA compatible and no assumptions should be made about the availability of any VGA registers.   If clear, then the standard VGA I/O ports and frame buffer address defined in WinASegment and/or WinBSegment can be assumed
;			D6 	VGA compatible windowed memory mode is available 
;				0 - Yes 
;				1 - No 

;				Used to indicate if the mode provides Windowing or Banking of the frame buffer into the frame buffer memory region specified by WinASegment and WinBSegment.  If set, then Windowing of the frame buffer is NOT possible.  If clear, then the device is capable of mapping the frame buffer into the segment specified in WinASegment and/or WinBSegment.  (This bit is used in conjunction with bit D7, see table following D7 for usage)
;			D7 	Linear frame buffer mode is available 
;				0 - No 
;				1 - Yes 

;				Indicates the presence of a Linear Frame Buffer memory model. If this bit is set, the display controller can be put into a flat memory model by setting the mode (VBE Function 02h) with the Flat Memory Model bit set. (This bit is used in conjunction with bit D6, see following table for usage)
;			D8-D15  	Reserved 

;     Window access mode description

;											D7 	D6 
;			Windowed frame buffer only  	0 	0
;			n/a				 				0 	1
;			Both windowed adn linear 		1 	0
;			Linear frame buffer only 		1 	1

;     BytesPerScanLine

;        The BytesPerScanLine field specifies how many full bytes are in each logical scanline. The logical scanline could be equal to or larger than the displayed scanline.

;    WinAAttributes & WinBAttributes
;        The WinAAttributes and WinBAttributes describe the characteristics of the CPU windowing scheme such as whether the windows exist and are read/writeable, as follows:

 
;		D0 	Relocatable window(s) supported 
;			0 - Single non-relocatable window only 
;			1 -  Relocatable window(s) are supported
;		D1 	Window readable 
;			0 - Window is not readable 
;			1 - Window is readable
;		D2 	Window writeable 
; 			0 - Window is not writeable 
; 			1 - Window is writeable
;		D3-D7  	Reserved
 

;        Even if windowing is not supported, (bit D0 = 0 for both Window A and Window B), then an application can assume that the display memory buffer resides at the location specified by WinASegment and/or WinBSegment.

;    WinGranularity
;        WinGranularity specifies the smallest boundary, in KB, on which the window can be placed in the frame buffer memory. The value of this field is undefined if Bit D0 of the appropriate WinAttributes field is not set.

;    WinSize
;         specifies the size of the window in KB.

;    WinASegment and WinBSegment
;        WinASegment and WinBSegment address specify the segment addresses where the windows are located in the CPU address space.
;        Use D14 of the Mode Number to select the Linear Buffer on a mode set (Function 02h).

;    WinFuncPtr
;        WinFuncPtr specifies the segment:offset of the VBE memory windowing function. The windowing function can be invoked either through VBE Function 05h, or by calling the function directly. A direct call will provide faster access to the hardware paging registers than using VBE Function 05h, and is intended to be used by high performance applications. If this field is NULL, then VBE Function 05h must be used to set the memory window when paging is supported.  This direct call method uses the same parameters as VBE Function 05h including AX and for VBE 2.0 implementations will return the correct Return Status. VBE 1.2 implementations and earlier, did not require the Return Status information to be returned.  For more information on the direct call method, see the notes in VBE Function 05h and the sample code in Appendix 5.

;    XResolution and YResolution
;        The XResolution and YResolution specify the width and height in pixel elements or characters for this display mode. In graphics modes, these fields indicate the number of horizontal and vertical pixels that may be displayed. In text modes, these fields indicate the number of horizontal and vertical character positions.  The number of pixel positions for text modes may be calculated by multiplying the returned XResolution and YResolution values by the character cell width and height indicated in the XCharSize and YCharSize fields described below.

;    XCharSize and YCharSize
;        The XCharSize and YCharSize specify the size of the character cell in pixels.  (This value is not zero based)  e.g. XCharSize for Mode 3 using the 9 point font will have a value of 9.

;    NumberOfPlanes
;        The NumberOfPlanes field specifies the number of memory planes available to software in that mode. For standard 16-color VGA graphics, this would be set to 4. For standard packed pixel modes, the field would be set to 1.  For 256-color non-chain-4 modes, where you need to do banking to address all pixels this value should be set to the number of banks required to get to all the pixels (typically this will be 4 or 8).

;    BitsPerPixel
;        The BitsPerPixel field specifies the total number of bits allocated to one pixel. For example, a standard VGA 4 Plane 16-color graphics mode would have a 4 in this field and a packed pixel 256-color graphics mode would specify 8 in this field. The number of bits per pixel per plane can normally be derived by dividing the BitsPerPixel field by the NumberOfPlanes field.

;    MemoryModel
;        The MemoryModel field specifies the general type of memory organization used in this mode. The following models have been defined:

;			0x00 	Text mode
;			0x01 	CGA graphics
;			0x02 	Hercules graphics
;			0x03 	Planar
;			0x04 	Packed pixel
;			0x05 	Non-chain 4, 256 color
;			0x06 	Direct Color
;			0x07 	YUV
;			0x08-0x0F 	Reserved, to be defined by VESA
;			0x10-0xFF 	To be defined by OEM

;        VBE Version 1.1 and earlier defined Direct Color graphics modes with pixel formats 1:5:5:5, 8:8:8, and 8:8:8:8  as a Packed Pixel model with 16, 24, and 32 bits per pixel, respectively. In VBE Version 1.2 and later, the Direct Color modes use the Direct Color memory model and use the MaskSize and FieldPosition fields of the ModeInfoBlock to describe the pixel format. BitsPerPixel is always defined to be the total memory size of the pixel, in bits.

;    NumberOfBanks
;        NumberOfBanks. This is the number of banks in which the scan lines are grouped. The quotient from dividing the scan line number by the number of banks is the bank that contains the scan line and the remainder is the scan line number within the bank. For example, CGA graphics modes have two banks and Hercules graphics mode has four banks. For modes that don't have scanline banks (such as VGA modes 0Dh-13h), this field should be set to 1.

;    BankSize
;        The BankSize field specifies the size of a bank (group of scan lines) in units of 1 KB. For CGA and Hercules graphics modes this is 8, as each bank is 8192 bytes in length. For modes that don't have scanline banks (such as VGA modes 0Dh-13h), this field should be set to 0.

;    NumberOfImagePages
;        The NumberOfImagePages field specifies the "total number minus one (- 1)"of complete display images that will fit into the frame buffer memory. The application may load more than one image into the frame buffer memory if this field is non-zero, and move the display window within each of those pages.  This should only be used for determining the additional display pages which are available to the application; to determine the available off screen memory, use the OffScreenMemOffset and OffScreenMemSize information.
;        Note: If the ModeInfoBlock is for an IBM Standard VGA mode and the NumberOfImagePages field contains more pages than would be found in a 256KB implementation, the TTY support described in the ModeAttributes must be accurate.  i.e. if the TTY functions are claimed to be supported, they must be supported in all pages, not just the pages normally found in the 256KB implementation.

;    Reserved
;        The Reserved field has been defined to support a future VBE feature and will always be set to one in this version.

;    RedMaskSize, GreenMaskSize, BlueMaskSize, and RsvdMaskSize
;        The RedMaskSize, GreenMaskSize, BlueMaskSize, and RsvdMaskSize fields define the size, in bits, of the red, green, and blue components of a direct color pixel. A bit mask can be constructed from the MaskSize fields using simple shift arithmetic. For example, the MaskSize values for a Direct Color 5:6:5 mode would be 5, 6, 5, and 0, for the red, green, blue, and reserved fields, respectively. Note that in the YUV MemoryModel, the red field is used for V, the green field is used for Y, and the blue field is used for U. The MaskSize fields should be set to 0 in modes using a memory model that does not have pixels with component fields.

;    RedFieldPosition, GreenFieldPosition, BlueFieldPosition, and RsvdFieldPosition
;        The RedFieldPosition, GreenFieldPosition, BlueFieldPosition, and RsvdFieldPosition fields define the bit position within the direct color pixel or YUV pixel of the least significant bit of the respective color component. A color value can be aligned with its pixel field by shifting the value left by the FieldPosition. For example, the FieldPosition values for a Direct Color 5:6:5 mode would be 11, 5, 0, and 0, for the red, green, blue, and reserved fields, respectively. Note that in the YUV MemoryModel, the red field is used for V, the green field is used for Y, and the blue field is used for U. The FieldPosition fields should be set to 0 in modes using a memory model that does not have pixels with component fields.

;    DirectColorModeInfo
;        The DirectColorModeInfo field describes important characteristics of direct color modes.  Bit D0 specifies whether the color ramp of the DAC is fixed or programmable. If the color ramp is fixed, then it can not be changed. If the color ramp is programmable, it is assumed that the red, green, and blue lookup tables can be loaded by using VBE Function 09h.  Bit D1 specifies whether the bits in the Rsvd field of the direct color pixel can be used by the application or are reserved, and thus unusable.

;			D0 	0 - Color ramp is fixed 
;				1 - Color ramp is programmable 
;			D1 	0 - Bits in Rsvd field are reserved 
;				1 - Bits in Rsvd field are usable by the application 

;     PhysBasePtr

;        The PhysBasePtr is a 32 bit physical address of the start of frame buffer memory when the controller is in flat frame buffer memory mode. If this mode is not available, then this field will be zero.

;    OffScreenMemOffset
;        The OffScreenMemOffset is a 32 bit offset from the start of the frame buffer memory.  Extra off-screen memory that is needed by the controller may be located either before or after this off screen memory, be sure to check OffScreenMemSize to determine the amount of off-screen memory which is available to the application.

;    OffScreenMemSize
;        The OffScreenMemSize contains the amount of available, contiguous off- screen memory in 1k units, which can be used by the application.
;        Note: Version 1.1 and later VBE will zero out all unused fields in the Mode Information Block, always returning exactly 256 bytes. This facilitates upward compatibility with future versions of the standard, as any newly added fields will be designed such that values of zero will indicate nominal defaults or non-implementation of optional features. (For example, a field containing a bit-mask of extended capabilities would reflect the absence of all such capabilities.) Applications that wish to be backwards compatible to Version 1.0 VBE should pre-initialize the 256 byte buffer before calling the Return VBE Mode Information function.


;*****Set VBE Mode*****
;This required function initializes the controller and sets a VBE mode. The format of VESA VBE mode numbers is described earlier in this document. If the mode cannot be set, the BIOS should leave the graphics environment unchanged and return a failure error code.
 
;Input: 	AX 	0x4F02 - Set VBE Mode
;			BX  	D0-D8 	Mode number
;					D9-D13  Reserved (must be 0)
;					D14 	0 - Use windowed frame buffer model 
;							1 - Use linear/flat frame buffer model 

;							If set, the mode will be initialized for use with a flat frame buffer model.  The base address of the frame buffer can be determined from the extended mode information returned by VBE Function 01h.  If D14 is set, and a linear frame buffer model is not available then the call will fail, returning AH=01h to the application.
;					D15 	Clear display memory 

;							If bit D15 is not set, all reported image pages, based on Function 00h returned information NumberOfImagePages, will be cleared to 00h in graphics mode, and 20 07 in text mode.  Memory over and above the reported image pages will not be changed.  If bit D15 is set, then the contents of the frame buffer after the mode change is undefined. Note, the 1-byte mode numbers used in Function 00h of an IBM VGA compatible BIOS use D7 to signify the same thing as D15 does in this function.  If D7 is set for an IBM compatible mode set using this Function (02), this mode set will fail.  VBE aware applications must use the memory clear bit in D15.
;Output: 	AX  	VBE Return Status 

;					If the requested mode number is not available, then the call will fail, returning AH=01h to indicate the failure to the application.
;Notes:

;    All other registers are preserved.
;    VBE BIOS 2.0 implementations should also update the BIOS Data Area 40:87 memory clear bit so that VBE Function 03h can return this flag. VBE BIOS 1.2 and earlier implementations ignore the memory clear bit.
;    This call should not set modes not listed in the list of supported modes.  In addition all modes (including IBM standard VGA modes), if listed as supported, must have ModeInfoBlock structures associated with them.  Required ModeInfoBlock values for the IBM Standard Modes are listed in Appendix 2.
;    If there is a failure when selecting an unsupported D14 value, the error return should be 02h.


VGA2_MODE_SUPPORTED		equ	0x0001
VGA2_MODE_COLOR			equ	0x0008	; !? is this necessary (Monochrome or color)
VGA2_MODE_GRAPHICAL		equ	0x0010
VGA2_MODE_VGA_COMPAT	equ	0x0020
							; bit 6: VGA compatWindowed, would be necessary!?
VGA2_MODE_LFB			equ	0x0080


section .text

;****************************************************
; vga2_info
;****************************************************
vga2_info:
			pusha
			mov	si, vga2_msg
			call stdio16_puts
 
			; set 'VBE2' in vga2_info_arr!?
			mov BYTE [vga2_info_arr], 'V'
			mov BYTE [vga2_info_arr+1], 'B'
			mov BYTE [vga2_info_arr+2], 'E'
			mov BYTE [vga2_info_arr+3], '2'

			; retrieve vgainfo
			mov ax, 4f00h	
			mov di, vga2_info_arr		; set es:di to vga2_info_arr (segment registers cannot be set directly)
			int 10h

			; print vga2_info_arr

			; print array of 4 chars (vesasigniture)
			mov	si, vga2_vesa_signature_txt
			call stdio16_puts
			mov cx, 4					; print 4 chars (bytes)
			mov si, vga2_info_arr
			call stdio16_put_chs
			call stdio16_new_line

			; print VBE version
			mov	si, vga2_vesa_version_txt
			call stdio16_puts
			mov bx, WORD [es:di+4]
			call stdio16_put_bcd
			shl	bx, 8
			call stdio16_put_bcd
			call stdio16_put_h
			call stdio16_new_line

			; print OEMString
			push ds
			mov	si, vga2_oem_str_txt
			call stdio16_puts
			mov ax, WORD [es:di+8]
			mov ds, ax
			mov ax, WORD [es:di+6]
			mov si, ax
			call stdio16_puts
			call stdio16_new_line
			pop ds

			; print Capabilities (4 bytes) (Little Endian)
			mov	si, vga2_capabilities_txt
			call stdio16_puts
			mov cx, 4
			mov dx, WORD [es:di+12]
			call stdio16_put_hex
			mov dx, WORD [es:di+10]
			mov cx, 4
			call stdio16_put_hex
			call stdio16_put_h
			call stdio16_new_line

			; print VideoModes and copy them to modelist
			mov	si, vga2_video_modes_txt
			call stdio16_puts
			mov ax, WORD [es:di+16]
			mov bx, WORD [es:di+14]
			push es
			push di
			mov es, ax
			mov di, bx
			mov bx, 0
.VMsChk		cmp WORD [es:di+bx], 0xFFFF
			jz	.VMsEnd
			mov dx, WORD [es:di+bx]
			mov [vga2_mode_list+bx], dx
			mov cx, 4
			call stdio16_put_hex
			call stdio16_put_h
			add bx, 2
			cmp bx, 254
			jnge .VMsChk
.VMsEnd		pop di
			pop es
			mov WORD [vga2_mode_list+bx], 0xFFFF
			call stdio16_new_line

			; print TotalMemory (2 bytes)
			mov	si, vga2_total_memory_txt
			call stdio16_puts
			mov dx, WORD [es:di+18]
			mov cx, 4
			call stdio16_put_hex
			call stdio16_put_h
			call stdio16_new_line

			; print OEMSoftwareRev
			mov	si, vga2_oem_software_rev_txt
			call stdio16_puts
			mov bx, WORD [es:di+20]
			call stdio16_put_bcd
			shl	bx, 8
			call stdio16_put_bcd
			call stdio16_put_h
			call stdio16_new_line

			; print OEMVendorName
			cmp WORD [es:di+24], 0						; check if ptr is zero
			jne	.VenName
			cmp WORD [es:di+22], 0
			je	.Back
.VenName	push ds
			mov	si, vga2_oem_vendor_name_txt
			call stdio16_puts
			mov ax, WORD [es:di+24]
			mov ds, ax
			mov ax, WORD [es:di+22]
			mov si, ax
			call stdio16_puts
			call stdio16_new_line
			pop ds

			; print OEMProductName
			cmp WORD [es:di+28], 0						; check if ptr is zero
			jne	.ProdName
			cmp WORD [es:di+26], 0
			je	.Back
.ProdName	push ds
			mov	si, vga2_oem_product_name_txt
			call stdio16_puts
			mov ax, WORD [es:di+28]
			mov ds, ax
			mov ax, WORD [es:di+26]
			mov si, ax
			call stdio16_puts
			call stdio16_new_line
			pop ds

			; print OEMProductRev
			cmp WORD [es:di+32], 0						; check if ptr is zero
			jne	.ProdRev
			cmp WORD [es:di+30], 0
			je	.Back
.ProdRev	push ds
			mov	si, vga2_oem_product_rev_txt
			call stdio16_puts
			mov ax, WORD [es:di+32]
			mov ds, ax
			mov ax, WORD [es:di+30]
			mov si, ax
			call stdio16_puts
			call stdio16_new_line
			pop ds

			; print vga2_modelist array
;			mov	si, vga2_mode_list_txt
;			call stdio16_puts
;			xor bx, bx
;.MLChk		cmp WORD [vga2_mode_list+bx], 0xFFFF
;			jz	.MLEnd
;			mov dx, WORD [vga2_mode_list+bx]
;			mov cx, 4
;			call stdio16_put_hex
;			call stdio16_put_h
;			inc bx
;			inc bx
;			cmp bx, 254
;			jnge .MLChk
;.MLEnd		call stdio16_new_line

.Back		popa
			ret


;****************************************************
; vga2_modes
; Modes that are LFB compatible and //(at least 1024*768)
;****************************************************
vga2_modes:
			pusha
			mov	si, vga2_modes_lfb_txt
			call stdio16_puts
			call stdio16_new_line
			xor bx, bx
.NextMode	cmp WORD [vga2_mode_list+bx], 0xFFFF
			jz	.MLEnd
			mov dx, WORD [vga2_mode_list+bx]
			; get vga2_mode_info
			mov ax, 0x4F01
			mov di, vga2_info_arr
			mov cx, dx
			int 10h					; result in ES:DI
			cmp ax, 0x004F			; if AL != 4F then the mode doesn't exist; AH == 0 function call successful
			jz	.Exists			
			jmp .Skip
.Exists		mov cx, WORD [es:di]	; check ModeAttributes
			test cx, VGA2_MODE_SUPPORTED
			jnz .Attr2
			jmp .Skip
.Attr2		test cx, VGA2_MODE_COLOR
			jnz .Attr3
			jmp .Skip
.Attr3		test cx, VGA2_MODE_GRAPHICAL
			jnz .Attr4
			jmp .Skip
.Attr4		test cx, VGA2_MODE_LFB
			jnz .AttribsOk
			jmp .Skip
;.AttribsOk	mov ax, WORD [es:di+18]	; X Resolution
;			cmp ax, 1024
;			jnge .Skip
;			mov ax, WORD [es:di+20]	; Y Resolution
;			cmp ax, 768
;			jnge .Skip
;			mov al, BYTE [es:di+25]	; BPP
;			cmp al, 16
;			jnge .Skip
.AttribsOk:
			mov ax, WORD [es:di+42]	; LinearFrameBuffer
			cmp ax, 0
			jz	.Skip
.Print		mov dx, WORD [vga2_mode_list+bx]
			mov cx, 4				; print mode
			call stdio16_put_hex
			call stdio16_put_h
			mov ax, WORD [es:di+18]	; X Resolution
			call stdio16_put_dec
			mov al, '*'
			call stdio16_put_ch
			mov ax, WORD [es:di+20]	; Y Resolution
			call stdio16_put_dec
			mov al, '*'
			call stdio16_put_ch
			xor ax, ax
			mov al, BYTE [es:di+25]	; BPP
			call stdio16_put_dec
			mov al, ' '
			call stdio16_put_ch
			mov dx, WORD [es:di+42]	; LinearFrameBuffer
			mov cx, 4
			call stdio16_put_hex
			mov dx, WORD [es:di+40]	
			mov cx, 4
			call stdio16_put_hex
			call stdio16_put_h
			mov al, ' '
			call stdio16_put_ch
			mov dx, WORD [es:di+46]	; Off-screen mem offset
			mov cx, 4
			call stdio16_put_hex
			mov dx, WORD [es:di+44]	
			mov cx, 4
			call stdio16_put_hex
			call stdio16_put_h
			mov al, ' '
			call stdio16_put_ch
			mov dx, WORD [es:di+48]	; Amount of off-screen mem in 1kb units
			mov cx, 4
			call stdio16_put_hex
			call stdio16_put_h
			mov al, ';'
			call stdio16_put_ch
			mov al, ' '
			call stdio16_put_ch
.Skip		inc bx
			inc bx
			jmp .NextMode
.MLEnd		call stdio16_new_line
			popa
			ret


section .data

vga2_msg					db "Retrieving VGAInfo ...", 13, 10, 0

vga2_vesa_signature_txt	db "VESASignature: ", 0
vga2_vesa_version_txt	db "VesaVersion: ", 0
vga2_oem_str_txt	 		db "OEMString: ", 0
vga2_capabilities_txt	db "Capabilities: ", 0
vga2_video_modes_txt 	db "VideoModes: ", 0
vga2_total_memory_txt	db "TotalMemory: ", 0
; added for VBE 2.0
vga2_oem_software_rev_txt	db "OEMSoftwareRev: ", 0
vga2_oem_vendor_name_txt		db "OEMVendorName: ", 0
vga2_oem_product_name_txt	db "OEMProductName: ", 0
vga2_oem_product_rev_txt		db "OEMProductRev: ", 0

vga2_modes_lfb_txt		db "LFB-capable modes (X*Y*BPP LFB OffScrMemOffs AmountOfOffScrMemIn1kbUnits):", 0
vga2_mode_list_txt	db "List of VGA-modes: ", 0

vga2_info_arr		times 512 db 0	; VBEInfoBlock
vga2_mode_list		times 256 db 0	; a copy of the list of modes which is stored in the reserved area of VBEInfoBlock (infoar)
vga2_mode_list_lfb	times 256 db 0	; LFB capable modes //(and at least 1024*768)
vga2_mode_arr		times 256 db 0	; ModeInfoBlock

vga2_doesnt_exist_txt	db "Doesn't exist", 0
vga2_attribs_not_ok_txt	db "Attribs not ok", 0


%endif

