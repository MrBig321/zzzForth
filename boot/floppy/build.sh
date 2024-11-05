#!/bin/bash

nasm -f bin kernel.asm -o output/KRNL.SYS
sudo mount -o loop output/file.img /media/floppy
sleep 2
sudo cp output/KRNL.SYS /media/floppy
sleep 2
sudo umount /media/floppy
cp output/file.img ~

