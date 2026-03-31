#!/usr/bin/env python3
"""
VBXE Image Converter for Atari 8-bit Browser

Converts web images to VBXE-compatible format:
- Header: [width_lo] [width_hi] [height]  (3 bytes)
- Palette: 256 colors × 3 RGB bytes (768 bytes)
- Pixels: raw 8-bit indexed (w × h bytes)

Usage:
    python vbxe_converter.py <image_url> [width] [height]
    
    image_url: URL of the image to convert
    width: max output width (default: 320)
    height: max output height (default: 208)
    
Example:
    python vbxe_converter.py https://example.com/image.jpg
    python vbxe_converter.py https://example.com/image.jpg 160 100
"""

import sys
import io
import math
from PIL import Image
import requests

# VBXE palette indices 0-7 are reserved for text, so we use 8-255 for image
PALETTE_START = 8


def fetch_image(url: str) -> Image.Image:
    """Download and return PIL Image from URL."""
    headers = {
        'User-Agent': 'VBXE Browser/1.0 Atari-Image-Converter'
    }
    response = requests.get(url, headers=headers, timeout=30)
    response.raise_for_status()
    return Image.open(io.BytesIO(response.content)).convert('RGBA')


def resize_image(img: Image.Image, max_w: int, max_h: int) -> Image.Image:
    """Resize image to fit within max dimensions, centered on black background."""
    # Calculate scale to fit
    scale_w = max_w / img.width
    scale_h = max_h / img.height
    scale = min(scale_w, scale_h, 1.0)  # Don't upscale
    
    new_w = max(1, int(img.width * scale))
    new_h = max(1, int(img.height * scale))
    
    # Resize with high quality
    resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Center on black background
    result = Image.new('RGBA', (max_w, max_h), (0, 0, 0, 255))
    x_offset = (max_w - new_w) // 2
    y_offset = (max_h - new_h) // 2
    result.paste(resized, (x_offset, y_offset))
    
    return result


def quantize_to_256(img: Image.Image) -> tuple:
    """
    Quantize image to 256 colors using median cut.
    Returns: (palette_data, pixel_data, width, height)
    """
    # Convert to RGB for processing
    rgb_img = img.convert('RGB')
    pixels = list(rgb_img.getdata())
    
    width, height = img.size
    
    # Median cut color quantization
    def median_cut(pixels_list, depth):
        if depth == 0 or len(pixels_list) <= 1:
            # Calculate average color
            r_sum = g_sum = b_sum = 0
            for r, g, b in pixels_list:
                r_sum += r
                g_sum += g
                b_sum += b
            count = len(pixels_list) or 1
            return [(r_sum // count, g_sum // count, b_sum // count)]
        
        # Find the channel with the largest range
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
    
    # Generate 248 colors (8 reserved for text)
    colors = median_cut(pixels, 8)  # 256 colors, but reserve 8
    colors = colors[:248]  # Ensure we have exactly 248
    
    # Pad to 248 if needed
    while len(colors) < 248:
        colors.append((0, 0, 0))
    
    # Build color lookup
    color_map = {}
    def color_distance(c1, c2):
        return math.sqrt(sum((a - b) ** 2 for a, b in zip(c1, c2)))
    
    # Create indexed pixel data
    index_data = []
    for pixel in pixels:
        # Find closest color in palette
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
    
    # Convert palette to RGB bytes
    palette_data = bytearray()
    for r, g, b in colors:
        palette_data.append(r)
        palette_data.append(g)
        palette_data.append(b)
    
    return palette_data, index_data, width, height


def output_vbxe_format(width: int, height: int, palette: bytes, pixels: list):
    """Output the VBXE binary format to stdout."""
    # Header: width_lo, width_hi, height
    sys.stdout.buffer.write(bytes([width & 0xFF, (width >> 8) & 0xFF, height & 0xFF]))
    
    # Palette: 768 bytes (256 colors × 3)
    # First 8 colors (indices 0-7) are reserved, we fill with black
    reserved = bytes(24)  # 8 colors × 3 bytes
    sys.stdout.buffer.write(reserved)
    sys.stdout.buffer.write(palette)
    
    # Pad palette to 256 colors (768 bytes total)
    # We already wrote 24 bytes + 744 bytes = 768, but need to ensure exactly 768
    # Actually our palette is 248 colors = 744 bytes, plus 24 reserved = 768
    # But we need to write exactly 768 bytes for palette
    # The above should be correct: 8 reserved + 248 image colors = 256 total
    
    # Pixels: raw 8-bit indexed
    sys.stdout.buffer.write(bytes(pixels))


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    image_url = sys.argv[1]
    max_width = int(sys.argv[2]) if len(sys.argv) > 2 else 320
    max_height = int(sys.argv[3]) if len(sys.argv) > 3 else 208
    
    # Clamp dimensions
    max_width = max(8, min(320, max_width))
    max_height = max(8, min(208, max_height))
    
    try:
        # Fetch and process image
        img = fetch_image(image_url)
        img = resize_image(img, max_width, max_height)
        palette, pixels, width, height = quantize_to_256(img)
        
        # Output VBXE format
        output_vbxe_format(width, height, bytes(palette), pixels)
        
    except requests.RequestException as e:
        sys.stderr.write(f"Error fetching image: {e}\n")
        sys.exit(1)
    except Exception as e:
        sys.stderr.write(f"Error processing image: {e}\n")
        sys.exit(1)


if __name__ == '__main__':
    main()