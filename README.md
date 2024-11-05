 # zzzFORTH

Also called ZFOS, an operating system, Written in 32-bit Intel-assembly and FORTH

The best FORTH tutorial is "Starting FORTH by Leo Brodie":
https://www.forth.com/starting-forth/

## Features

- Resolutions: 1024x768x16 or 640x480x16 (for Eee PC) 
- IDE hard disk driver
- Multitasking (but only one core or CPU is used)
- USB(EHCI, XHCI) driver (can read/write files from/to pendrive formatted to FAT32) 
- HDAUDIO driver (very limited)
- Can boot from Floppy/HD/USB-MSD
In FORTH (in ZFOS/fthsrc/):
- BLOCK
- HEXVW, HEXED
- TXTVW, TXTED
- SIN, COS, TAN, SQRT (fixed point math)
- LINE, POLYGON(can be filled), CIRCLE(can be filled), PAINT
- Sutherland-Cohen line-clipping 
- Sutherland-Hodgman polygon clipping
- BEZIERQ, BEZIERC
- QOI image format (decode/code) supported
- 3D (fixed point math) (e.g. rotating cubes)

See ZFOS/docs for details

Add executable permission to scripts (in zzzFORTH folder):

chmod +x [star].sh

## License

This project is licensed under the MIT License - see the LICENSE.md file for details

