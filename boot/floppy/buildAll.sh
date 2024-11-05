#!/bin/bash

nasm -f bin boot/boot.asm -o output/boot.bin

nasm -f bin boot/loader.asm -o output/KRNLDR.SYS
nasm -f bin kernel.asm -o output/KRNL.SYS

dd bs=512 count=2880 if=/dev/zero of=output/file.img
sudo mkdosfs output/file.img

sudo mount -o loop output/file.img /media/floppy
sleep 2
sudo cp output/KRNLDR.SYS /media/floppy
sudo cp output/KRNL.SYS /media/floppy
sleep 2
sudo umount /media/floppy
dd if=output/boot.bin of=output/file.img bs=512 count=1 conv=notrunc

cp output/file.img ~

