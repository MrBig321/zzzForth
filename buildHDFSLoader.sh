#!/bin/bash

nasm -f bin boot/hdfsmbr.asm -o output/hdfsmbr.bin
nasm -f bin boot/hdfsboot.asm -o output/hdfsboot.bin
nasm -f bin boot/hdfsloader.asm -o output/HDFSLODR.SYS

