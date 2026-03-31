#!/usr/bin/env python3
"""
Script to combine all .asm files from src/ directory into a single file.
Each file will have its filename commented at the header.
"""

import os
from pathlib import Path

SRC_DIR = Path("src")
OUTPUT_FILE = "combined_asm.txt"

def main():
    # Get all .asm files in src/ sorted alphabetically
    asm_files = sorted(SRC_DIR.glob("*.asm"))
    
    if not asm_files:
        print(f"No .asm files found in {SRC_DIR}/")
        return
    
    with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
        for i, asm_file in enumerate(asm_files):
            # Write file header comment
            out.write(";" + "=" * 78 + "\n")
            out.write(f"; FILE: {asm_file.name}\n")
            out.write(";" + "=" * 78 + "\n")
            out.write("\n")
            
            # Read and write file content
            with open(asm_file, "r", encoding="utf-8") as f:
                content = f.read()
                out.write(content)
            
            # Add separator between files (but not after the last one)
            if i < len(asm_files) - 1:
                out.write("\n")
                out.write(";" + "-" * 78 + "\n")
                out.write("\n")
    
    print(f"Combined {len(asm_files)} files into {OUTPUT_FILE}")
    
    # Print summary
    total_lines = 0
    for asm_file in asm_files:
        with open(asm_file, "r", encoding="utf-8") as f:
            lines = len(f.readlines())
            total_lines += lines
            print(f"  {asm_file.name}: {lines} lines")
    print(f"  Total: {total_lines} lines")

if __name__ == "__main__":
    main()