#!/usr/bin/env node
/**
 * VBXE Image Converter for Atari 8-bit Browser
 * 
 * Converts web images to VBXE-compatible format:
 * - Header: [width_lo] [width_hi] [height]  (3 bytes)
 * - Palette: 256 colors × 3 RGB bytes (768 bytes)
 * - Pixels: raw 8-bit indexed (w × h bytes)
 * 
 * Usage:
 *   node vbxe_converter.js <image_url> [width] [height]
 * 
 * Example:
 *   node vbxe_converter.js https://example.com/image.jpg
 *   node vbxe_converter.js https://example.com/image.jpg 160 100
 */

const https = require('https');
const http = require('http');
const { Image } = require('image-js');

// VBXE palette indices 0-7 are reserved for text
const PALETTE_START = 8;

async function fetchImage(url) {
    return new Promise((resolve, reject) => {
        const protocol = url.startsWith('https') ? https : http;
        const request = protocol.get(url, {
            headers: {
                'User-Agent': 'VBXE Browser/1.0 Atari-Image-Converter'
            },
            timeout: 30000
        }, (response) => {
            if (response.statusCode !== 200) {
                reject(new Error(`HTTP ${response.statusCode}`));
                return;
            }
            
            const chunks = [];
            response.on('data', chunk => chunks.push(chunk));
            response.on('end', () => {
                const buffer = Buffer.concat(chunks);
                Image.load(buffer).then(resolve).catch(reject);
            });
            response.on('error', reject);
        });
        request.on('error', reject);
        request.on('timeout', () => {
            request.destroy();
            reject(new Error('Request timeout'));
        });
    });
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

// Simple median cut color quantization
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
    
    // Find channel with largest range
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
    
    // Extract RGB pixels
    const pixels = [];
    for (let i = 0; i < width * height; i++) {
        const r = img.data[i * 4];
        const g = img.data[i * 4 + 1];
        const b = img.data[i * 4 + 2];
        pixels.push([r, g, b]);
    }
    
    // Generate 248 colors (indices 8-255)
    let colors = medianCut(pixels, 8);
    colors = colors.slice(0, 248);
    
    // Pad to 248 if needed
    while (colors.length < 248) {
        colors.push([0, 0, 0]);
    }
    
    // Color distance for nearest match
    const colorDist = (c1, c2) => 
        Math.sqrt((c1[0] - c2[0]) ** 2 + (c1[1] - c2[1]) ** 2 + (c1[2] - c2[2]) ** 2);
    
    // Build pixel index data
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
    
    // Build palette as RGB bytes
    const paletteData = Buffer.alloc(768);
    for (let i = 0; i < 248; i++) {
        paletteData[i * 3] = colors[i][0];
        paletteData[i * 3 + 1] = colors[i][1];
        paletteData[i * 3 + 2] = colors[i][2];
    }
    
    return { paletteData, indexData, width, height };
}

function outputVBXE(width, height, palette, pixels) {
    const parts = [];
    
    // Header: width_lo, width_hi, height
    parts.push(Buffer.from([width & 0xFF, (width >> 8) & 0xFF, height & 0xFF]));
    
    // Palette: 8 reserved + 248 image colors = 256 colors = 768 bytes
    // Reserved colors (0-7) are black
    const reserved = Buffer.alloc(24); // 8 colors × 3 bytes
    parts.push(reserved);
    parts.push(palette);
    
    // Pixel data
    parts.push(Buffer.from(pixels));
    
    // Output to stdout
    process.stdout.write(Buffer.concat(parts));
}

async function main() {
    const args = process.argv.slice(2);
    if (args.length < 1) {
        console.error('Usage: node vbxe_converter.js <image_url> [width] [height]');
        process.exit(1);
    }
    
    const imageUrl = args[0];
    let maxWidth = parseInt(args[1]) || 320;
    let maxHeight = parseInt(args[2]) || 208;
    
    maxWidth = Math.max(8, Math.min(320, maxWidth));
    maxHeight = Math.max(8, Math.min(208, maxHeight));
    
    try {
        const img = await fetchImage(imageUrl);
        const resized = resizeImage(img, maxWidth, maxHeight);
        const { paletteData, indexData, width, height } = quantizeTo256(resized);
        outputVBXE(width, height, paletteData, indexData);
    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
}

main();