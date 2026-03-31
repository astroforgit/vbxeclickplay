#!/usr/bin/env node
/**
 * VBXE Image Converter
 * 
 * Converts local image files to VBXE binary format for Atari browser.
 * 
 * Usage:
 *   node vbxe_server.js <image_file> [width] [height]
 * 
 * Examples:
 *   node vbxe_server.js photo.jpg
 *   node vbxe_server.js photo.jpg 160 100
 *   node vbxe_server.js image.png 320 208
 * 
 * Output: binary to stdout (pipe to file or redirect as needed)
 */

const fs = require('fs');
const path = require('path');
const { Image } = require('image-js');

// Max dimensions (VBXE constraints)
const MAX_WIDTH = 320;
const MAX_HEIGHT = 208;
const MIN_DIM = 8;

function printUsage() {
    console.error('Usage: node vbxe_server.js <image_file> [width] [height]');
    console.error('');
    console.error('Arguments:');
    console.error('  image_file   Path to JPG, PNG, GIF, WebP, BMP, or TIFF image');
    console.error('  width        Max output width (default: 320, max: 320)');
    console.error('  height       Max output height (default: 208, max: 208)');
    console.error('');
    console.error('Output: binary to stdout');
    console.error('  Header (3 bytes) + Palette (768 bytes) + Pixels');
    process.exit(1);
}

function resizeImage(img, maxW, maxH) {
    const scaleW = maxW / img.width;
    const scaleH = maxH / img.height;
    const scale = Math.min(scaleW, scaleH, 1.0);
    
    const newW = Math.max(1, Math.round(img.width * scale));
    const newH = Math.max(1, Math.round(img.height * scale));
    
    // Create centered black canvas
    const canvas = new Image({
        width: maxW,
        height: maxH,
        color: [0, 0, 0, 255]
    });
    
    const resized = img.resize({ width: newW, height: newH });
    
    const xOffset = Math.floor((maxW - newW) / 2);
    const yOffset = Math.floor((maxH - newH) / 2);
    
    // Copy pixels to centered position
    for (let y = 0; y < newH; y++) {
        for (let x = 0; x < newW; x++) {
            const srcIdx = (y * newW + x) * 4;
            const dstIdx = ((yOffset + y) * maxW + (xOffset + x)) * 4;
            canvas.data[dstIdx] = resized.data[srcIdx];
            canvas.data[dstIdx + 1] = resized.data[srcIdx + 1];
            canvas.data[dstIdx + 2] = resized.data[srcIdx + 2];
            canvas.data[dstIdx + 3] = 255;
        }
    }
    
    return canvas;
}

function medianCut(pixels, depth) {
    if (depth === 0 || pixels.length <= 1) {
        const count = pixels.length || 1;
        let r = 0, g = 0, b = 0;
        for (const p of pixels) {
            r += p[0];
            g += p[1];
            b += p[2];
        }
        return [[Math.round(r / count), Math.round(g / count), Math.round(b / count)]];
    }
    
    const rVals = pixels.map(p => p[0]);
    const gVals = pixels.map(p => p[1]);
    const bVals = pixels.map(p => p[2]);
    
    const rRange = Math.max(...rVals) - Math.min(...rVals);
    const gRange = Math.max(...gVals) - Math.min(...gVals);
    const bRange = Math.max(...bVals) - Math.min(...bVals);
    
    let sortKey;
    if (rRange >= gRange && rRange >= bRange) sortKey = p => p[0];
    else if (gRange >= bRange) sortKey = p => p[1];
    else sortKey = p => p[2];
    
    pixels.sort((a, b) => sortKey(a) - sortKey(b));
    
    const mid = Math.floor(pixels.length / 2);
    return [
        ...medianCut(pixels.slice(0, mid), depth - 1),
        ...medianCut(pixels.slice(mid), depth - 1)
    ];
}

function quantizeTo256(img) {
    const width = img.width;
    const height = img.height;
    
    const pixels = [];
    for (let i = 0; i < width * height; i++) {
        pixels.push([
            img.data[i * 4],
            img.data[i * 4 + 1],
            img.data[i * 4 + 2]
        ]);
    }
    
    let colors = medianCut(pixels, 8);
    colors = colors.slice(0, 248);
    
    while (colors.length < 248) {
        colors.push([0, 0, 0]);
    }
    
    const colorDist = (c1, c2) => 
        Math.sqrt((c1[0] - c2[0]) ** 2 + (c1[1] - c2[1]) ** 2 + (c1[2] - c2[2]) ** 2);
    
    const indexData = [];
    const colorMap = new Map();
    
    for (const pixel of pixels) {
        const key = pixel.join(',');
        if (!colorMap.has(key)) {
            let minDist = Infinity;
            let bestIdx = 0;
            for (let idx = 0; idx < colors.length; idx++) {
                const dist = colorDist(pixel, colors[idx]);
                if (dist < minDist) {
                    minDist = dist;
                    bestIdx = idx;
                }
            }
            colorMap.set(key, bestIdx);
        }
        indexData.push(colorMap.get(key));
    }
    
    // Build palette as RGB bytes (indices 8-255)
    const paletteData = Buffer.alloc(744);
    for (let i = 0; i < 248; i++) {
        paletteData[i * 3] = colors[i][0];
        paletteData[i * 3 + 1] = colors[i][1];
        paletteData[i * 3 + 2] = colors[i][2];
    }
    
    return { paletteData, indexData, width, height };
}

function convertToVBXE(img, maxW, maxH) {
    const resized = resizeImage(img, maxW, maxH);
    const { paletteData, indexData, width, height } = quantizeTo256(resized);
    
    const parts = [];
    
    // Header: width_lo, width_hi, height (3 bytes)
    parts.push(Buffer.from([width & 0xFF, (width >> 8) & 0xFF, height & 0xFF]));
    
    // Palette: 256 colors × 3 bytes = 768 bytes
    // Indices 0-7 reserved (black), 8-255 = image palette
    const reserved = Buffer.alloc(24); // 8 colors × 3 bytes
    parts.push(reserved);
    parts.push(paletteData);
    
    // Pixels: raw 8-bit indexed
    parts.push(Buffer.from(indexData));
    
    return Buffer.concat(parts);
}

async function main() {
    const args = process.argv.slice(2);
    
    if (args.length < 1) {
        printUsage();
    }
    
    const inputFile = args[0];
    let maxW = args[1] ? parseInt(args[1]) : MAX_WIDTH;
    let maxH = args[2] ? parseInt(args[2]) : MAX_HEIGHT;
    
    // Clamp dimensions
    maxW = Math.max(MIN_DIM, Math.min(MAX_WIDTH, maxW));
    maxH = Math.max(MIN_DIM, Math.min(MAX_HEIGHT, maxH));
    
    // Check file exists
    if (!fs.existsSync(inputFile)) {
        console.error(`Error: File not found: ${inputFile}`);
        process.exit(1);
    }
    
    const ext = path.extname(inputFile).toLowerCase();
    const validExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.tif'];
    
    if (!validExts.includes(ext)) {
        console.error(`Error: Unsupported file type: ${ext}`);
        console.error(`Supported: ${validExts.join(', ')}`);
        process.exit(1);
    }
    
    try {
        const fileBuffer = fs.readFileSync(inputFile);
        const img = await Image.load(fileBuffer);
        
        const vbxeData = convertToVBXE(img, maxW, maxH);
        
        // Write binary to stdout
        process.stdout.write(vbxeData);
        
    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
}

main();