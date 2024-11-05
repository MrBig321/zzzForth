#!/bin/bash

nasm -f bin boot/hdboot.asm -o output/hdboot.bin
nasm -f bin boot/hdloader.asm -o output/hdloader.bin

