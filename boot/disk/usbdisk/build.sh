#!/bin/bash

nasm -f bin kernel.asm -o output/KRNL.SYS
cp output/KRNL.SYS ~

