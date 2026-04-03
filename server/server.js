const fs = require('fs');
const path = require('path');
const http = require('http');
const { URL } = require('url');

const PORT = Number(process.env.PORT || 3000);
const IMAGE_WIDTH = 320;
const IMAGE_HEIGHT = 200;
const CLICK_MARKER_COLOR = 5;
const MAX_BODY_BYTES = 4 * 1024 * 1024;
const ROOT_DIR = path.resolve(__dirname, '../..');
const DATA_DIR = path.join(ROOT_DIR, 'data');
const SLIDES_DIR = path.join(DATA_DIR, 'slides');
const STORE_FILE = path.join(DATA_DIR, 'slides.json');
const WEB_INDEX_FILE = path.join(__dirname, 'web', 'index.html');
const WEB_APP_FILE = path.join(__dirname, 'web', 'app.js');

function ensureStore() {
    fs.mkdirSync(SLIDES_DIR, { recursive: true });
    if (!fs.existsSync(STORE_FILE)) {
        fs.writeFileSync(STORE_FILE, JSON.stringify({ slides: [] }, null, 2));
    }
}

function loadStore() {
    ensureStore();
    try {
        const parsed = JSON.parse(fs.readFileSync(STORE_FILE, 'utf8'));
        if (!Array.isArray(parsed.slides)) {
            return { slides: [] };
        }
        return {
            slides: parsed.slides.filter((slide) =>
                slide && typeof slide.id === 'string' && typeof slide.fileName === 'string'
            )
        };
    } catch (error) {
        console.warn(`[WARN] Failed to load store: ${error.message}`);
        return { slides: [] };
    }
}

function saveStore(store) {
    ensureStore();
    fs.writeFileSync(STORE_FILE, JSON.stringify(store, null, 2));
}

function sanitizeTitle(title) {
    const safe = String(title || 'Untitled slide').replace(/[\r\n\t]+/g, ' ').trim();
    return safe.slice(0, 80) || 'Untitled slide';
}

function buildTextPayload(req, slideCount) {
    return [
        'FUJINET SLIDESHOW OK',
        `SLIDES:${slideCount}`,
        'PRESS SPACE FOR SLIDESHOW',
        `PATH:${req.url}`,
        'WEB:/web',
        ''
    ].join('\n');
}

function buildDemoImagePayload() {
    const header = Buffer.from([
        IMAGE_WIDTH & 0xff,
        (IMAGE_WIDTH >> 8) & 0xff,
        IMAGE_HEIGHT & 0xff
    ]);

    const palette = Buffer.alloc(768, 0);
    for (let i = 8; i < 256; i += 1) {
        const c = i - 8;
        palette[i * 3] = c;
        palette[i * 3 + 1] = (c * 5) & 0xff;
        palette[i * 3 + 2] = 255 - c;
    }

    const pixels = Buffer.alloc(IMAGE_WIDTH * IMAGE_HEIGHT);
    for (let y = 0; y < IMAGE_HEIGHT; y += 1) {
        for (let x = 0; x < IMAGE_WIDTH; x += 1) {
            const band = ((x >> 3) ^ (y >> 3)) & 0x1f;
            const color = 8 + ((band * 7 + (x >> 4) + (y >> 4)) % 248);
            pixels[y * IMAGE_WIDTH + x] = color;
        }
    }

    return Buffer.concat([header, palette, pixels]);
}

const demoImagePayload = buildDemoImagePayload();
const roomClickState = new Map();

function validateVbxePayload(buffer) {
    if (!Buffer.isBuffer(buffer) || buffer.length < 3 + 768 + 64) {
        throw new Error('VBXE payload is too small');
    }

    const width = buffer[0] | (buffer[1] << 8);
    const height = buffer[2];
    const expectedLength = 3 + 768 + (width * height);

    if (width < 8 || width > 320) {
        throw new Error(`Invalid VBXE width: ${width}`);
    }
    if (height < 8 || height > 208) {
        throw new Error(`Invalid VBXE height: ${height}`);
    }
    if (buffer.length !== expectedLength) {
        throw new Error(`Invalid VBXE payload length: got ${buffer.length}, expected ${expectedLength}`);
    }

    return { width, height };
}

function getSlidesWithOrder() {
    const store = loadStore();
    return store.slides.map((slide, index) => ({
        ...slide,
        position: index,
        atariUrl: `/slide/${index.toString(16).padStart(2, '0').toUpperCase()}`
    }));
}

function normalizeRoomName(name) {
    return String(name || '').trim().toLowerCase();
}

function getSlidePayload(index) {
    const store = loadStore();
    if (store.slides.length === 0) {
        return {
            title: 'Generated demo slide',
            buffer: demoImagePayload,
            width: IMAGE_WIDTH,
            height: IMAGE_HEIGHT,
            position: 0,
            totalSlides: 1,
            isDemo: true
        };
    }

    const normalized = ((index % store.slides.length) + store.slides.length) % store.slides.length;
    const slide = store.slides[normalized];
    const fullPath = path.join(SLIDES_DIR, slide.fileName);
    const buffer = fs.readFileSync(fullPath);
    const { width, height } = validateVbxePayload(buffer);

    return {
        ...slide,
        buffer,
        width,
        height,
        position: normalized,
        totalSlides: store.slides.length,
        isDemo: false
    };
}

function getRoomPayload(roomName) {
    const normalized = normalizeRoomName(roomName);
    const store = loadStore();

    const namedIndex = store.slides.findIndex((slide) => normalizeRoomName(slide.title) === normalized);
    if (namedIndex !== -1) {
        return getSlidePayload(namedIndex);
    }

    const numberedMatch = normalized.match(/^room([1-9][0-9]*)$/);
    if (numberedMatch) {
        const roomIndex = Number.parseInt(numberedMatch[1], 10) - 1;
        return getSlidePayload(roomIndex);
    }

    return null;
}

function getRoomPreviewPayload(roomName) {
    const slide = getRoomPayload(roomName);
    if (!slide) {
        return null;
    }

    const normalized = normalizeRoomName(roomName);
    const lastClick = roomClickState.get(normalized) || null;
    return {
        roomName: normalized,
        title: slide.title,
        width: slide.width,
        height: slide.height,
        atariUrl: `/room/${normalized}`,
        vbxeBase64: buildRoomPreviewBuffer(slide.buffer, slide.width, slide.height, lastClick).toString('base64'),
        lastClick
    };
}

function buildRoomPreviewBuffer(buffer, width, height, lastClick) {
    if (!lastClick) {
        return buffer;
    }

    const preview = Buffer.from(buffer);
    const pixelOffset = 3 + 768;
    for (let dy = 0; dy < 2; dy += 1) {
        const y = lastClick.y + dy;
        if (y < 0 || y >= height) {
            continue;
        }
        for (let dx = 0; dx < 2; dx += 1) {
            const x = lastClick.x + dx;
            if (x < 0 || x >= width) {
                continue;
            }
            preview[pixelOffset + (y * width) + x] = CLICK_MARKER_COLOR;
        }
    }
    return preview;
}

function parseHexByte(value) {
    if (!/^[0-9a-fA-F]{2}$/.test(value)) {
        return null;
    }
    return Number.parseInt(value, 16);
}

function sendJson(res, statusCode, payload) {
    const body = Buffer.from(JSON.stringify(payload, null, 2));
    res.writeHead(statusCode, {
        'Content-Type': 'application/json; charset=utf-8',
        'Content-Length': body.length,
        'Cache-Control': 'no-store',
        Connection: 'close'
    });
    res.end(body);
}

function sendText(res, statusCode, text) {
    const body = Buffer.from(text, 'ascii');
    res.writeHead(statusCode, {
        'Content-Type': 'text/plain; charset=us-ascii',
        'Content-Length': body.length,
        'Cache-Control': 'no-store',
        Connection: 'close'
    });
    res.end(body);
}

function sendBinary(res, buffer) {
    res.writeHead(200, {
        'Content-Type': 'application/octet-stream',
        'Content-Length': buffer.length,
        'Cache-Control': 'no-store',
        Connection: 'close'
    });
    res.end(buffer);
}

function sendFile(res, filePath, contentType) {
    try {
        const body = fs.readFileSync(filePath);
        res.writeHead(200, {
            'Content-Type': contentType,
            'Content-Length': body.length,
            'Cache-Control': 'no-store',
            Connection: 'close'
        });
        res.end(body);
    } catch (error) {
        sendText(res, 500, `File error: ${error.message}\n`);
    }
}

function readJsonBody(req) {
    return new Promise((resolve, reject) => {
        const chunks = [];
        let total = 0;

        req.on('data', (chunk) => {
            total += chunk.length;
            if (total > MAX_BODY_BYTES) {
                reject(new Error('Request body too large'));
                req.destroy();
                return;
            }
            chunks.push(chunk);
        });

        req.on('end', () => {
            try {
                const raw = Buffer.concat(chunks).toString('utf8');
                resolve(raw ? JSON.parse(raw) : {});
            } catch (error) {
                reject(new Error(`Invalid JSON body: ${error.message}`));
            }
        });

        req.on('error', reject);
    });
}

async function handleCreateSlide(req, res) {
    const body = await readJsonBody(req);
    const title = sanitizeTitle(body.title);
    const vbxeBase64 = String(body.vbxeBase64 || '');

    if (!vbxeBase64) {
        sendJson(res, 400, { error: 'vbxeBase64 is required' });
        return;
    }

    let buffer;
    try {
        buffer = Buffer.from(vbxeBase64, 'base64');
    } catch (error) {
        sendJson(res, 400, { error: `Invalid base64 payload: ${error.message}` });
        return;
    }

    let dimensions;
    try {
        dimensions = validateVbxePayload(buffer);
    } catch (error) {
        sendJson(res, 400, { error: error.message });
        return;
    }

    const id = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
    const fileName = `${id}.vbxe`;
    fs.writeFileSync(path.join(SLIDES_DIR, fileName), buffer);

    const store = loadStore();
    store.slides.push({
        id,
        title,
        fileName,
        width: dimensions.width,
        height: dimensions.height,
        createdAt: new Date().toISOString()
    });
    saveStore(store);

    sendJson(res, 201, {
        ok: true,
        slide: {
            id,
            title,
            fileName,
            width: dimensions.width,
            height: dimensions.height
        }
    });
}

async function handleReorderSlides(req, res) {
    const body = await readJsonBody(req);
    const ids = Array.isArray(body.ids) ? body.ids.map(String) : null;

    if (!ids || ids.length === 0) {
        sendJson(res, 400, { error: 'ids array is required' });
        return;
    }

    const store = loadStore();
    if (ids.length !== store.slides.length) {
        sendJson(res, 400, { error: 'ids array length does not match current slide count' });
        return;
    }

    const byId = new Map(store.slides.map((slide) => [slide.id, slide]));
    const reordered = [];
    for (const id of ids) {
        const slide = byId.get(id);
        if (!slide) {
            sendJson(res, 400, { error: `Unknown slide id: ${id}` });
            return;
        }
        reordered.push(slide);
        byId.delete(id);
    }

    if (byId.size !== 0) {
        sendJson(res, 400, { error: 'ids array did not include all slides' });
        return;
    }

    store.slides = reordered;
    saveStore(store);
    sendJson(res, 200, { ok: true });
}

function handleDeleteSlide(res, slideId) {
    const store = loadStore();
    const index = store.slides.findIndex((slide) => slide.id === slideId);
    if (index === -1) {
        sendJson(res, 404, { error: 'Slide not found' });
        return;
    }

    const [removed] = store.slides.splice(index, 1);
    saveStore(store);

    const fullPath = path.join(SLIDES_DIR, removed.fileName);
    if (fs.existsSync(fullPath)) {
        fs.unlinkSync(fullPath);
    }

    sendJson(res, 200, { ok: true, removedId: slideId });
}

ensureStore();

const server = http.createServer(async (req, res) => {
    const requestUrl = new URL(req.url || '/', `http://${req.headers.host || '127.0.0.1'}`);
    const pathname = requestUrl.pathname;
    const userAgent = req.headers['user-agent'] || '(none)';

    console.log(`[REQ] ${new Date().toISOString()} ${req.method} ${pathname}`);
    console.log(`[REQ] user-agent: ${userAgent}`);

    try {
        if (req.method === 'GET' && (pathname === '/web' || pathname === '/web/')) {
            sendFile(res, WEB_INDEX_FILE, 'text/html; charset=utf-8');
            return;
        }

        if (req.method === 'GET' && pathname === '/web/app.js') {
            sendFile(res, WEB_APP_FILE, 'text/javascript; charset=utf-8');
            return;
        }

        if (req.method === 'GET' && pathname === '/api/slides') {
            sendJson(res, 200, {
                slides: getSlidesWithOrder(),
                fallbackSlideCount: 1
            });
            return;
        }

        const roomApiMatch = pathname.match(/^\/api\/rooms\/([^/]+)$/);
        if (req.method === 'GET' && roomApiMatch) {
            const requestedRoom = decodeURIComponent(roomApiMatch[1]);
            const payload = getRoomPreviewPayload(requestedRoom);
            if (!payload) {
                sendJson(res, 404, { error: `Room not found: ${requestedRoom}` });
                return;
            }
            sendJson(res, 200, payload);
            return;
        }

        if (req.method === 'POST' && pathname === '/api/slides') {
            await handleCreateSlide(req, res);
            return;
        }

        if (req.method === 'POST' && pathname === '/api/slides/reorder') {
            await handleReorderSlides(req, res);
            return;
        }

        const deleteMatch = pathname.match(/^\/api\/slides\/([A-Za-z0-9_-]+)$/);
        if (req.method === 'DELETE' && deleteMatch) {
            handleDeleteSlide(res, deleteMatch[1]);
            return;
        }

        if (req.method === 'GET' && pathname === '/image') {
            const slide = getSlidePayload(0);
            sendBinary(res, slide.buffer);
            console.log(`[RES] image alias -> slide 00 (${slide.width}x${slide.height})`);
            return;
        }

        const clickMatch = pathname.match(/^\/click\/([^/]+)\/([0-9A-Fa-f]{2})\/([0-9A-Fa-f]{2})$/);
        if (req.method === 'GET' && clickMatch) {
            const requestedRoom = decodeURIComponent(clickMatch[1]);
            const logicalX = parseHexByte(clickMatch[2]);
            const y = parseHexByte(clickMatch[3]);
            const slide = getRoomPayload(requestedRoom);

            if (!slide) {
                sendText(res, 404, `Room not found: ${requestedRoom}\n`);
                return;
            }
            if (logicalX === null || y === null || logicalX >= 160 || y >= IMAGE_HEIGHT) {
                sendText(res, 400, 'Invalid click coordinates\n');
                return;
            }

            const normalizedRoom = normalizeRoomName(requestedRoom);
            roomClickState.set(normalizedRoom, {
                logicalX,
                x: logicalX * 2,
                y,
                updatedAt: new Date().toISOString()
            });

            sendText(res, 200, 'OK\n');
            console.log(
                `[EVENT] click ${normalizedRoom} logical=(${logicalX},${y}) pixel=(${logicalX * 2},${y})`
            );
            return;
        }

        const roomMatch = pathname.match(/^\/room\/([^/]+)$/);
        if (req.method === 'GET' && roomMatch) {
            const requestedRoom = decodeURIComponent(roomMatch[1]);
            const slide = getRoomPayload(requestedRoom);
            if (!slide) {
                sendText(res, 404, `Room not found: ${requestedRoom}\n`);
                return;
            }
            sendBinary(res, slide.buffer);
            console.log(
                `[RES] room ${requestedRoom} -> ${slide.position} ` +
                `"${slide.title}" ${slide.width}x${slide.height} ${slide.buffer.length} bytes`
            );
            return;
        }

        const slideMatch = pathname.match(/^\/slide\/([0-9A-Fa-f]{1,2})$/);
        if (req.method === 'GET' && slideMatch) {
            const requestedIndex = Number.parseInt(slideMatch[1], 16);
            const slide = getSlidePayload(requestedIndex);
            sendBinary(res, slide.buffer);
            console.log(
                `[RES] slide ${requestedIndex.toString(16).padStart(2, '0').toUpperCase()} -> ${slide.position} ` +
                `"${slide.title}" ${slide.width}x${slide.height} ${slide.buffer.length} bytes`
            );
            return;
        }

        if (req.method === 'GET' && pathname === '/favicon.ico') {
            res.writeHead(204, { 'Cache-Control': 'no-store', Connection: 'close' });
            res.end();
            return;
        }

        if (req.method === 'GET' && pathname === '/') {
            const slideCount = Math.max(getSlidesWithOrder().length, 1);
            const payloadText = buildTextPayload(req, slideCount);
            sendText(res, 200, payloadText);
            console.log(`[RES] text ${Buffer.byteLength(payloadText, 'ascii')} bytes`);
            console.log(payloadText);
            return;
        }

        sendText(res, 404, 'Not found\n');
    } catch (error) {
        console.error(`[ERR] ${error.stack || error.message}`);
        sendJson(res, 500, { error: error.message });
    }
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`FujiNet slideshow server running on port ${PORT}`);
    console.log(`Text URL:   N:http://127.0.0.1:${PORT}/`);
    console.log(`Slide URL:  N:http://127.0.0.1:${PORT}/slide/00`);
    console.log(`Room URL:   N:http://127.0.0.1:${PORT}/room/room1`);
    console.log(`Image URL:  N:http://127.0.0.1:${PORT}/image`);
    console.log(`Web UI:     http://127.0.0.1:${PORT}/web`);
});