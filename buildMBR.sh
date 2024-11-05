#!/bin/bash

nasm -f bin boot/mbr.asm -o output/mbr.bin

cp output/mbr.bin ~

