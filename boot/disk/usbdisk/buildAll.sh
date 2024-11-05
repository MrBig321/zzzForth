#!/bin/bash

nasm -f bin boot/boot.asm -o output/boot.bin

nasm -f bin boot/loader.asm -o output/LODR.SYS
nasm -f bin kernel.asm -o output/KRNL.SYS

cp output/boot.bin ~
cp output/LODR.SYS ~
cp output/KRNL.SYS ~

