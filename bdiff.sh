cmp -l output/hdloader.bin output/hdloader2.bin | gawk '{printf "%08X %02X %02X\n", $1, strtonum(0$2), strtonum(0$3)}'
