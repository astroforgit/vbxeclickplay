#!/usr/bin/env python3
"""
VBXE Image Converter

Converts local image files to VBXE binary format for Atari browser.

Usage:
    python vbxe_server.py <image_file> [width] [height]

Examples:
    python vbxe_server.py photo.jpg
    python vbxe_server.py photo.jpg 160 100
    python vbxe_server.py image.png 320 208

Output: binary to stdout (pipe to file or redirect as needed)

Dependencies:
    pip install pillow image-js
"""

import sys
import io
import math
import os
from PIL import Image

# Max dimensions (VBXE constraints)
MAX_WIDTH = 320
MAX_HEIGHT = 208
MIN_DIM = 8

SUPPORTED_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.tif']


def print_usage():
    print('Usage: python vbxe_server.py <image_file> [width] [height]', file=sys.stderr)
    print('', file=sys.stderr)
    print('Arguments:', file=sys.stderr)
    print('  image_file   Path to JPG, PNG, GIF, WebP, BMP, or TIFF image', file=sys.stderr)
    print(f'  width        Max output width (default: {MAX_WIDTH}, max: {MAX_WIDTH})', file=sys.stderr)
    print(f'  height       Max output height (default: {MAX_HEIGHT}, max: {MAX_HEIGHT})', file=sys.stderr)
    print('', file=sys.stderr)
    print('Output: binary to stdout', file=sys.stderr)
    print('  Header (3 bytes) + Palette (768 bytes) + Pixels', file=sys.stderr)
    sys.exit(1)


def resize_image(img: Image.Image, max_w: int, max_h: int) -> Image.Image:
    """Resize image to fit within max dimensions, centered on black background."""
    scale_w = max_w / img.width
    scale_h = max_h / img.height
    scale = min(scale_w, scale_h, 1.0)  # Don't upscale
    
    new_w = max(1, int(img.width * scale))
    new_h = max(1, int(img.height * scale))
    
    resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Center on black background
    result = Image.new('RGBA', (max_w, max_h), (0, 0, 0, 255))
    x_offset = (max_w - new_w) // 2
    y_offset = (max_h - new_h) // 2
    result.paste(resized, (x_offset, y_offset))
    
    return result


def median_cut(pixels_list, depth):
    """Median cut color quantization."""
    if depth == 0 or len(pixels_list) <= 1:
        count = len(pixels_list) or 1
        r_sum = g_sum = b_sum = 0
        for r, g, b in pixels_list:
            r_sum += r
            g_sum += g
            b_sum += b
        return [(r_sum // count, g_sum // count, b_sum // count)]
    
    # Find channel with largest range
    r_vals = [p[0] for p in pixels_list]
    g_vals = [p[1] for p in pixels_list]
    b_vals = [p[2] for p in pixels_list]
    
    r_range = max(r_vals) - min(r_vals)
    g_range = max(g_vals) - min(g_vals)
    b_range = max(b_vals) - min(b_vals)
    
    if r_range >= g_range and r_range >= b_range:
        pixels_list.sort(key=lambda p: p[0])
    elif g_range >= b_range:
        pixels_list.sort(key=lambda p: p[1])
    else:
        pixels_list.sort(key=lambda p: p[2])
    
    mid = len(pixels_list) // 2
    left = median_cut(pixels_list[:mid], depth - 1)
    right = median_cut(pixels_list[mid:], depth - 1)
    return left + right


def quantize_to_256(img: Image.Image):
    """Quantize image to 248 colors (plus 8 reserved = 256 total)."""
    rgb_img = img.convert('RGB')
    pixels = list(rgb_img.getdata())
    
    width, height = img.size
    
    # Generate 248 colors using median cut
    colors = median_cut(pixels, 8)
    colors = colors[:248]
    
    # Pad to 248 if needed
    while len(colors) < 248:
        colors.append((0, 0, 0))
    
    # Build color lookup with nearest match
    color_map = {}
    
    def color_distance(c1, c2):
        return math.sqrt(sum((a - b) ** 2 for a, b in zip(c1, c2)))
    
    index_data = []
    for pixel in pixels:
        if pixel not in color_map:
            min_dist = float('inf')
            best_idx = 0
            for idx, c in enumerate(colors):
                dist = color_distance(pixel, c)
                if dist < min_dist:
                    min_dist = dist
                    best_idx = idx
            color_map[pixel] = best_idx
        index_data.append(color_map[pixel])
    
    # Build palette as RGB bytes (indices 8-255)
    palette_data = bytearray()
    for r, g, b in colors:
        palette_data.append(r)
        palette_data.append(g)
        palette_data.append(b)
    
    return bytes(palette_data), index_data, width, height


def convert_to_vbxe(img: Image.Image, max_w: int, max_h: int) -> bytes:
    """Convert PIL Image to VBXE binary format."""
    resized = resize_image(img, max_w, max_h)
    palette, pixels, width, height = quantize_to_256(resized)
    
    output = io.BytesIO()
    
    # Header: width_lo, width_hi, height (3 bytes)
    output.write(bytes([width & 0xFF, (width >> 8) & 0xFF, height & 0xFF]))
    
    # Palette: 256 colors × 3 bytes = 768 bytes
    # Indices 0-7 reserved (black), 8-255 = image palette
    reserved = bytes(24)  # 8 colors × 3 bytes
    output.write(reserved)
    output.write(palette)
    
    # Pixels: raw 8-bit indexed
    output.write(bytes(pixels))
    
    return output.getvalue()


def main():
    if len(sys.argv) < 2:
        print_usage()
    
    input_file = sys.argv[1]
    max_w = int(sys.argv[2]) if len(sys.argv) > 2 else MAX_WIDTH
    max_h = int(sys.argv[3]) if len(sys.argv) > 3 else MAX_HEIGHT
    
    # Clamp dimensions
    max_w = max(MIN_DIM, min(MAX_WIDTH, max_w))
    max_h = max(MIN_DIM, min(MAX_HEIGHT, max_h))
    
    # Check file exists
    if not os.path.exists(input_file):
        print(f'Error: File not found: {input_file}', file=sys.stderr)
        sys.exit(1)
    
    ext = os.path.splitext(input_file)[1].lower()
    if ext not in SUPPORTED_EXTENSIONS:
        print(f'Error: Unsupported file type: {ext}', file=sys.stderr)
        print(f'Supported: {", ".join(SUPPORTED_EXTENSIONS)}', file=sys.stderr)
        sys.exit(1)
    
    try:
        img = Image.open(input_file).convert('RGBA')
        vbxe_data = convert_to_vbxe(img, max_w, max_h)
        
        # Write binary to stdout
        sys.stdout.buffer.write(vbxe_data)
        
    except Exception as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()