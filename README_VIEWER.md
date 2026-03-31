# VBXE Image Viewer - Standalone Tool

A simple image viewer for Atari 8-bit computers with VBXE graphics expansion.

## Workflow

```
Your Image (JPG/PNG/etc.)
       ↓
  vbxe_server.py (Python converter)
       ↓
  Image.VBXE (binary format)
       ↓
  img_view.xex (Atari program)
       ↓
  Display on Atari!
```

## Files

| File | Description |
|------|-------------|
| `img_viewer.asm` | Atari 6502 assembly source code |
| `vbxe_server.py` | Python image converter |
| `build_viewer.sh` | Build script |

## Setup

### 1. Build the Atari Program

```bash
# Requires MADS assembler (https://github.com/tebe6502/Mad-Assembler)
chmod +x build_viewer.sh
./build_viewer.sh
```

This produces `bin/img_view.xex`.

### 2. Convert an Image

```bash
# Convert any image to VBXE format
python vbxe_server.py photo.jpg > D1:IMAGE.VBXE
python vbxe_server.py photo.jpg 160 100 > D1:SMALL.VBXE
```

## Usage

### On Real Hardware

1. Copy `img_view.xex` to your SD card
2. Copy `IMAGE.VBXE` to the same location
3. Run from SpartaDOS X:
   ```
   D1:IMG_VIEW.XEX
   ```

### On Altirra Emulator

1. File → Open → select `bin/img_view.xex`
2. Image loads automatically (D1:IMAGE.VBXE)
3. Press any key to exit

## VBXE Binary Format

```
Offset 0:   [1 byte]   Width low byte
Offset 1:   [1 byte]   Width high byte
Offset 2:   [1 byte]   Height
Offset 3:   [768 bytes] Palette (256 colors × 3 RGB)
Offset 771: [w×h bytes] Pixel data (8-bit indexed)
```

### Palette Notes
- Indices 0-7: Reserved for text display
- Indices 8-255: Image colors (248 colors max)
- Each color: 3 bytes (R, G, B)

### Image Dimensions
- Max width: 320 pixels
- Max height: 208 pixels
- Max size: 320 × 208 = 66,560 bytes

## Dependencies

### Atari Side
- VBXE hardware (FX core)
- 6502 processor

### Python Side
- Python 3.6+
- Pillow (image processing)

Install:
```bash
pip install pillow