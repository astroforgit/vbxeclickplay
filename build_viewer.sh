#!/bin/bash
# Build VBXE Image Viewer

echo "Building img_view.xex..."

# Check for MADS assembler
if ! command -v mads &> /dev/null; then
    echo "Error: MADS assembler not found"
    echo "Install from: https://github.com/tebe6502/Mad-Assembler"
    exit 1
fi

# Assemble
mads src/client.asm -o:bin/img_view.xex -l:bin/img_view.lab

if [ $? -eq 0 ]; then
    echo "Build successful: bin/img_view.xex"
else
    echo "Build failed!"
    exit 1
fi