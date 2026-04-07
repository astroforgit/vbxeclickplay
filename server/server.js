const fs = require('fs');
const path = require('path');
const http = require('http');
const { URL } = require('url');
const vm = require('vm');

const PORT = Number(process.env.PORT || 3000);
const IMAGE_WIDTH = 320;
const IMAGE_HEIGHT = 200;
const CLICK_MARKER_COLOR = 5;
const MAX_BODY_BYTES = 4 * 1024 * 1024;
const ROOT_DIR = path.resolve(__dirname, '..');
const DATA_DIR = path.join(ROOT_DIR, 'data');
const ROOMS_DIR = path.join(DATA_DIR, 'rooms');
const STORE_FILE = path.join(DATA_DIR, 'rooms.json');
const LEGACY_DATA_DIR = path.resolve(__dirname, '../..', 'data');
const LEGACY_ROOMS_DIR = path.join(LEGACY_DATA_DIR, 'rooms');
const LEGACY_STORE_FILE = path.join(LEGACY_DATA_DIR, 'rooms.json');
const WEB_INDEX_FILE = path.join(__dirname, 'web', 'index.html');
const WEB_APP_FILE = path.join(__dirname, 'web', 'app.js');
const DEFAULT_CLICK_SCRIPT = `// Available values: roomName, requestedRoomName, logicalX, x, y,
// roomSelections, selections, rooms, state, gameState
// Available helpers: changeRoom(name), displayText(text), replaceGraphics(payload), originalGraphics(payload)
// Examples:
//   replaceGraphics('closeeyes')
//   replaceGraphics({ selection: 'closeeyes', x: 120, y: 40 })
//   originalGraphics('closeeyes')
// Persist small JSON-safe values in state/gameState between clicks.

const hit = roomSelections.find((selection) => {
  return x >= selection.x && x < selection.x + selection.width && y >= selection.y && y < selection.y + selection.height;
});

if (hit) {
  return displayText(hit.name);
}

return null;
`;

function copyDirectoryRecursive(srcDir, destDir) {
  if (!fs.existsSync(srcDir)) return;
  fs.mkdirSync(destDir, { recursive: true });
  for (const entry of fs.readdirSync(srcDir, { withFileTypes: true })) {
    const srcPath = path.join(srcDir, entry.name);
    const destPath = path.join(destDir, entry.name);
    if (entry.isDirectory()) {
      copyDirectoryRecursive(srcPath, destPath);
    } else if (entry.isFile()) {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function migrateLegacyRoomStore() {
  if (fs.existsSync(STORE_FILE) || !fs.existsSync(LEGACY_STORE_FILE)) {
    return;
  }

  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.copyFileSync(LEGACY_STORE_FILE, STORE_FILE);
  copyDirectoryRecursive(LEGACY_ROOMS_DIR, ROOMS_DIR);
  console.log(`[INFO] Migrated room data from legacy path: ${LEGACY_DATA_DIR}`);
}

function ensureStore() {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  migrateLegacyRoomStore();
  fs.mkdirSync(ROOMS_DIR, { recursive: true });
  if (!fs.existsSync(STORE_FILE)) {
    fs.writeFileSync(STORE_FILE, JSON.stringify({ rooms: [] }, null, 2));
  }
}

function loadStore() {
  ensureStore();
  try {
    const parsed = JSON.parse(fs.readFileSync(STORE_FILE, 'utf8'));
    if (!Array.isArray(parsed.rooms)) {
      return { rooms: [], clickScript: DEFAULT_CLICK_SCRIPT, scriptState: {} };
    }
    return {
      rooms: parsed.rooms
        .filter((room) => room && typeof room.id === 'string' && typeof room.name === 'string')
        .map((room) => normalizeRoomRecord(room)),
      clickScript: typeof parsed.clickScript === 'string' ? parsed.clickScript : DEFAULT_CLICK_SCRIPT,
      scriptState: normalizeScriptState(parsed.scriptState)
    };
  } catch (error) {
    console.warn(`[WARN] Failed to load store: ${error.message}`);
    return { rooms: [], clickScript: DEFAULT_CLICK_SCRIPT, scriptState: {} };
  }
}

function saveStore(store) {
  ensureStore();
  fs.writeFileSync(STORE_FILE, JSON.stringify({
    rooms: Array.isArray(store.rooms) ? store.rooms : [],
    clickScript: typeof store.clickScript === 'string' ? store.clickScript : DEFAULT_CLICK_SCRIPT,
    scriptState: normalizeScriptState(store.scriptState)
  }, null, 2));
}

function normalizeScriptState(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }

  try {
    const serialized = JSON.stringify(value);
    const parsed = JSON.parse(serialized);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch (error) {
    console.warn(`[WARN] Failed to normalize click-script state: ${error.message}`);
    return {};
  }
}

function sanitizeTitle(title) {
  const safe = String(title || 'Untitled').replace(/[\r\n\t]+/g, ' ').trim();
  return safe.slice(0, 80) || 'Untitled';
}

function sanitizeActionText(text) {
  const safe = String(text || '')
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/[^\x20-\x7E]/g, ' ')
    .trim();
  return safe.slice(0, 19);
}

function isPngBuffer(buffer) {
  return Buffer.isBuffer(buffer)
    && buffer.length >= 8
    && buffer[0] === 0x89
    && buffer[1] === 0x50
    && buffer[2] === 0x4E
    && buffer[3] === 0x47
    && buffer[4] === 0x0D
    && buffer[5] === 0x0A
    && buffer[6] === 0x1A
    && buffer[7] === 0x0A;
}

function sanitizeRoomName(name) {
  const safe = String(name || 'room1').replace(/[^a-zA-Z0-9_-]/g, '').toLowerCase();
  return safe || 'room1';
}

function clampInteger(value, fallback = 0) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function sanitizeSelectionRecord(selection, defaults = {}) {
  const maxWidth = defaults.maxWidth || IMAGE_WIDTH;
  const maxHeight = defaults.maxHeight || IMAGE_HEIGHT;
  const type = selection?.type === 'image' ? 'image' : 'rect';
  const baseX = clampInteger(selection?.x, defaults.x ?? 24);
  const baseY = clampInteger(selection?.y, defaults.y ?? 24);
  const x = Math.max(0, Math.min(maxWidth - 1, baseX));
  const y = Math.max(0, Math.min(maxHeight - 1, baseY));
  const width = Math.max(1, Math.min(maxWidth - x, clampInteger(selection?.width, defaults.width ?? 48)));
  const height = Math.max(1, Math.min(maxHeight - y, clampInteger(selection?.height, defaults.height ?? 32)));

  return {
    id: String(selection?.id || defaults.id || `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`),
    type,
    name: sanitizeTitle(selection?.name || defaults.name || 'Selection'),
    x,
    y,
    width,
    height,
    visible: selection?.visible !== false,
    locked: type === 'image' ? selection?.locked !== false : false,
    imageFileName: type === 'image' && typeof selection?.imageFileName === 'string' ? selection.imageFileName : null,
    patchFileName: type === 'image' && typeof selection?.patchFileName === 'string' ? selection.patchFileName : null,
    createdAt: selection?.createdAt || defaults.createdAt || new Date().toISOString()
  };
}

function normalizeRoomRecord(room) {
  return {
    ...room,
    slides: Array.isArray(room.slides) ? room.slides : [],
    selections: Array.isArray(room.selections)
      ? room.selections.map((selection) => sanitizeSelectionRecord(selection))
      : []
  };
}

function getRoomFromStore(store, roomName) {
  const normalized = sanitizeRoomName(roomName);
  const exactRoom = store.rooms.find((room) => room.name === normalized);
  if (exactRoom) {
    return exactRoom;
  }

  if (normalized === 'room1' && store.rooms.length > 0) {
    return store.rooms[0];
  }

  if (store.rooms.length === 1) {
    return store.rooms[0];
  }

  return null;
}

function buildTextPayload(req, roomCount) {
  return [
    'FUJINET ROOM SERVER OK',
    `ROOMS:${roomCount}`,
    'PRESS SPACE FOR ROOM VIEW',
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
const ATARI_VISIBLE_MAX_CLICK_Y = 183;

function validateVbxePayload(buffer, options = {}) {
  const minPixels = Math.max(1, clampInteger(options.minPixels, 64));
  const minWidth = Math.max(1, clampInteger(options.minWidth, 8));
  const minHeight = Math.max(1, clampInteger(options.minHeight, 8));
  if (!Buffer.isBuffer(buffer) || buffer.length < 3 + 768 + minPixels) {
    throw new Error('VBXE payload is too small');
  }

  const width = buffer[0] | (buffer[1] << 8);
  const height = buffer[2];
  const expectedLength = 3 + 768 + (width * height);

  if (width < minWidth || width > 320) {
    throw new Error(`Invalid VBXE width: ${width}`);
  }
  if (height < minHeight || height > 208) {
    throw new Error(`Invalid VBXE height: ${height}`);
  }
  if (buffer.length !== expectedLength) {
    throw new Error(`Invalid VBXE payload length: got ${buffer.length}, expected ${expectedLength}`);
  }

  return { width, height };
}

function getRoomsWithOrder() {
  const store = loadStore();
  return store.rooms.map((room, index) => ({
    ...room,
    position: index,
    atariUrl: `/room/${encodeURIComponent(room.name)}`,
    hasImage: (room.slides || []).length > 0,
    imageCount: (room.slides || []).length
  }));
}

function getRoomImageEntry(roomName) {
  const slides = getRoomSlides(roomName);
  return slides[0] || null;
}

function getRoom(roomName) {
  const store = loadStore();
  return getRoomFromStore(store, roomName);
}

function getRoomSlides(roomName) {
  const room = getRoom(roomName);
  if (!room) return [];
  
  const roomDir = path.join(ROOMS_DIR, room.id);
  if (!fs.existsSync(roomDir)) return [];
  
  const slides = room.slides || [];
  return slides.map((slide, index) => ({
    ...slide,
    position: index,
    atariUrl: `/room/${encodeURIComponent(roomName)}/slide/${index.toString(16).padStart(2, '0').toUpperCase()}`
  }));
}

function getRoomSlidePayload(roomName, slideIndex) {
  const room = getRoom(roomName);
  if (!room) {
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

  const slides = getRoomSlides(roomName);
  if (slides.length === 0) {
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

  const normalized = ((slideIndex % slides.length) + slides.length) % slides.length;
  const slide = slides[normalized];
  const fullPath = path.join(ROOMS_DIR, room.id, slide.fileName);
  const buffer = fs.readFileSync(fullPath);
  const { width, height } = validateVbxePayload(buffer);

  return {
    ...slide,
    buffer,
    width,
    height,
    position: normalized,
    totalSlides: slides.length,
    isDemo: false
  };
}

function getRoomPreviewPayload(roomName) {
  const room = getRoom(roomName);
  if (!room) return null;

  const previewSelections = (room.selections || []).map((selection) => {
    if (selection.type !== 'image' || !selection.imageFileName) {
      return selection;
    }

    const imagePath = path.join(ROOMS_DIR, room.id, selection.imageFileName);
    return {
      ...selection,
      imagePngBase64: fs.existsSync(imagePath) ? fs.readFileSync(imagePath).toString('base64') : null,
      needsPatchRebuild: !selection.patchFileName
    };
  });

  const image = getRoomImageEntry(roomName);
  if (!image) {
    return {
      roomName: room.name,
      title: 'Demo room image',
      width: IMAGE_WIDTH,
      height: IMAGE_HEIGHT,
      atariUrl: `/room/${encodeURIComponent(roomName)}`,
      vbxeBase64: demoImagePayload.toString('base64'),
      hasCustomImage: false,
      imageTitle: null,
      selections: previewSelections,
      lastClick: roomClickState.get(room.name) || null
    };
  }

  const slide = getRoomSlidePayload(roomName, 0);
  const lastClick = roomClickState.get(room.name) || null;
  
  return {
    roomName: room.name,
    title: slide.title,
    width: slide.width,
    height: slide.height,
    atariUrl: `/room/${encodeURIComponent(roomName)}`,
    vbxeBase64: buildRoomPreviewBuffer(slide.buffer, slide.width, slide.height, lastClick).toString('base64'),
    hasCustomImage: true,
    imageTitle: slide.title,
    selections: previewSelections,
    lastClick
  };
}

function buildSelectionsForScript(store) {
  return store.rooms.flatMap((room) => (room.selections || []).map((selection) => ({
    roomName: room.name,
    id: selection.id,
    type: selection.type || 'rect',
    name: selection.name,
    x: selection.x,
    y: selection.y,
    width: selection.width,
    height: selection.height,
    visible: selection.visible !== false,
    locked: selection.locked === true
  })));
}

function buildRoomsForScript(store) {
  return store.rooms.map((room) => ({
    name: room.name,
    hasImage: (room.slides || []).length > 0,
    selections: (room.selections || []).map((selection) => ({
      id: selection.id,
      type: selection.type || 'rect',
      name: selection.name,
      x: selection.x,
      y: selection.y,
      width: selection.width,
      height: selection.height,
      visible: selection.visible !== false,
      locked: selection.locked === true
    }))
  }));
}

function formatHexByte(value) {
  return (value & 0xff).toString(16).padStart(2, '0').toUpperCase();
}

function extractPaletteColors(buffer) {
  const colors = new Array(256);
  for (let index = 0; index < 256; index += 1) {
    const offset = 3 + (index * 3);
    colors[index] = [buffer[offset], buffer[offset + 1], buffer[offset + 2]];
  }
  return colors;
}

function buildPaletteRemap(sourceBuffer, targetBuffer) {
  const sourcePalette = extractPaletteColors(sourceBuffer);
  const targetPalette = extractPaletteColors(targetBuffer);
  return sourcePalette.map(([sr, sg, sb]) => {
    let bestIndex = 0;
    let bestDistance = Number.POSITIVE_INFINITY;
    for (let index = 0; index < targetPalette.length; index += 1) {
      const [tr, tg, tb] = targetPalette[index];
      const distance = ((sr - tr) ** 2) + ((sg - tg) ** 2) + ((sb - tb) ** 2);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    return bestIndex;
  });
}

function buildRemappedPatchPayload(sourceBuffer, sourceWidth, sourceHeight, targetBuffer, width, height, sourceTitle, targetTitle) {
  const patchWidth = Math.max(1, Math.min(clampInteger(width, 1), 255, sourceWidth, IMAGE_WIDTH));
  const patchHeight = Math.max(1, Math.min(clampInteger(height, 1), 255, sourceHeight, IMAGE_HEIGHT));
  const remap = buildPaletteRemap(sourceBuffer, targetBuffer);
  const pixelOffset = 3 + 768;
  const patch = Buffer.alloc(patchWidth * patchHeight);

  for (let row = 0; row < patchHeight; row += 1) {
    const srcRowOffset = pixelOffset + (row * sourceWidth);
    const dstRowOffset = row * patchWidth;
    for (let column = 0; column < patchWidth; column += 1) {
      const sourceIndex = sourceBuffer[srcRowOffset + column];
      patch[dstRowOffset + column] = remap[sourceIndex] ?? sourceIndex;
    }
  }

  return {
    width: patchWidth,
    height: patchHeight,
    buffer: patch,
    sourceTitle,
    targetTitle
  };
}

function buildRoomGraphicsPatchPayload(sourceRoomName, targetRoomName, width, height) {
  const sourceSlide = getRoomSlidePayload(sourceRoomName, 0);
  const targetSlide = getRoomSlidePayload(targetRoomName, 0);
  return buildRemappedPatchPayload(
    sourceSlide.buffer,
    sourceSlide.width,
    sourceSlide.height,
    targetSlide.buffer,
    width,
    height,
    sourceSlide.title,
    targetSlide.title
  );
}

function findImageSelectionReference(store, selectionName, currentRoomName, explicitRoomName = null) {
  if (typeof selectionName !== 'string' || !selectionName.trim()) {
    return null;
  }

  const exactMatches = [];
  const lowerNeedle = selectionName.trim().toLowerCase();
  const looseMatches = [];

  for (const room of store.rooms) {
    if (explicitRoomName && room.name !== explicitRoomName) {
      continue;
    }
    for (const selection of room.selections || []) {
      if (selection.type !== 'image') continue;
      const reference = { room, selection };
      if (selection.name === selectionName.trim()) {
        exactMatches.push(reference);
      }
      if (selection.name.toLowerCase() === lowerNeedle) {
        looseMatches.push(reference);
      }
    }
  }

  const matches = exactMatches.length ? exactMatches : looseMatches;
  if (!matches.length) {
    return null;
  }

  const currentRoomMatch = matches.find((entry) => entry.room.name === currentRoomName);
  if (currentRoomMatch) {
    return currentRoomMatch;
  }

  return matches.length === 1 ? matches[0] : null;
}

function findImageSelectionByToken(store, sourceToken) {
  if (!String(sourceToken || '').startsWith('imgsel-')) {
    return null;
  }
  const selectionId = String(sourceToken).slice('imgsel-'.length);
  for (const room of store.rooms) {
    const selection = (room.selections || []).find((entry) => entry.id === selectionId && entry.type === 'image');
    if (selection) {
      return { room, selection };
    }
  }
  return null;
}

function buildImageSelectionGraphicsPatchPayload(sourceToken, targetRoomName, width, height) {
  const store = loadStore();
  const match = findImageSelectionByToken(store, sourceToken);
  if (!match) {
    throw new Error(`Image selection not found for ${sourceToken}`);
  }
  if (!match.selection.patchFileName) {
    throw new Error(`Image selection ${match.selection.name} has no stored graphics patch yet`);
  }

  const patchPath = path.join(ROOMS_DIR, match.room.id, match.selection.patchFileName);
  if (!fs.existsSync(patchPath)) {
    throw new Error(`Missing graphics patch file for image selection ${match.selection.name}`);
  }

  const sourceBuffer = fs.readFileSync(patchPath);
  const sourceDimensions = validateVbxePayload(sourceBuffer, { minPixels: 1, minWidth: 1, minHeight: 1 });
  const targetSlide = getRoomSlidePayload(targetRoomName, 0);
  return buildRemappedPatchPayload(
    sourceBuffer,
    sourceDimensions.width,
    sourceDimensions.height,
    targetSlide.buffer,
    width,
    height,
    `${match.room.name}/${match.selection.name}`,
    targetSlide.title
  );
}

function buildGraphicsPatchPayload(sourceToken, targetRoomName, width, height) {
  const selectionMatch = findImageSelectionByToken(loadStore(), sourceToken);
  if (selectionMatch) {
    return buildImageSelectionGraphicsPatchPayload(sourceToken, targetRoomName, width, height);
  }
  return buildRoomGraphicsPatchPayload(sourceToken, targetRoomName, width, height);
}

function normalizeReplaceGraphicsPayload(rawPayload) {
  if (typeof rawPayload === 'string') {
    return { selection: rawPayload };
  }
  if (rawPayload && typeof rawPayload === 'object') {
    return rawPayload;
  }
  return {};
}

function resolveGraphicsRect(payloadInput, currentRoomName, options = {}) {
  const payload = normalizeReplaceGraphicsPayload(payloadInput);
  const hasExplicitPayload =
    typeof payload.selection === 'string' ||
    payload.room !== undefined ||
    payload.sourceRoom !== undefined ||
    payload.x !== undefined ||
    payload.y !== undefined ||
    payload.width !== undefined ||
    payload.height !== undefined;

  if (!hasExplicitPayload) {
    return options.allowEmpty ? { empty: true } : null;
  }

  const store = loadStore();

  if (typeof payload.selection === 'string' && payload.selection.trim()) {
    const explicitRoomName = typeof payload.room === 'string' && payload.room.trim()
      ? sanitizeRoomName(payload.room)
      : null;
    const match = findImageSelectionReference(store, payload.selection, currentRoomName, explicitRoomName);
    if (!match) {
      console.warn(`[SCRIPT] image selection not found or ambiguous: ${payload.selection}`);
      return null;
    }
    if (options.requirePatch && !match.selection.patchFileName) {
      console.warn(`[SCRIPT] image selection ${match.selection.name} is missing a stored graphics patch`);
      return null;
    }

    const x = Math.max(0, Math.min(IMAGE_WIDTH - 1, clampInteger(payload.x, match.selection.x)));
    const y = Math.max(0, Math.min(IMAGE_HEIGHT - 1, clampInteger(payload.y, match.selection.y)));
    const width = Math.max(1, Math.min(255, match.selection.width, IMAGE_WIDTH - x, clampInteger(payload.width, match.selection.width)));
    const height = Math.max(1, Math.min(255, match.selection.height, IMAGE_HEIGHT - y, clampInteger(payload.height, match.selection.height)));
    return {
      x,
      y,
      width,
      height,
      sourceKey: `imgsel-${match.selection.id}`
    };
  }

  const sourceRoom = sanitizeRoomName(payload.room || payload.sourceRoom || currentRoomName);
  const sourceSlide = getRoomSlidePayload(sourceRoom, 0);
  const x = Math.max(0, Math.min(IMAGE_WIDTH - 1, clampInteger(payload.x, 0)));
  const y = Math.max(0, Math.min(IMAGE_HEIGHT - 1, clampInteger(payload.y, 0)));
  const width = Math.max(1, Math.min(255, sourceSlide.width, IMAGE_WIDTH - x, clampInteger(payload.width, sourceSlide.width)));
  const height = Math.max(1, Math.min(255, sourceSlide.height, IMAGE_HEIGHT - y, clampInteger(payload.height, sourceSlide.height)));
  return { x, y, width, height, sourceKey: sourceRoom };
}

function resolveReplaceGraphicsAction(payloadInput, currentRoomName) {
  const rect = resolveGraphicsRect(payloadInput, currentRoomName, { requirePatch: true });
  if (!rect) {
    return null;
  }
  return { type: 'replaceGraphics', sourceKey: rect.sourceKey, x: rect.x, y: rect.y, width: rect.width, height: rect.height };
}

function resolveOriginalGraphicsAction(payloadInput, currentRoomName) {
  const rect = resolveGraphicsRect(payloadInput, currentRoomName, { allowEmpty: true });
  if (!rect) {
    return null;
  }
  if (rect.empty) {
    return { type: 'originalGraphics' };
  }
  return { type: 'originalGraphics', x: rect.x, y: rect.y, width: rect.width, height: rect.height };
}

function normalizeClickActionResult(result, currentRoomName) {
  if (!result) return null;
  const candidate = Array.isArray(result) ? result.find(Boolean) : result;
  if (!candidate || typeof candidate !== 'object') {
    return null;
  }

  switch (candidate.type) {
    case 'changeRoom': {
      const room = sanitizeRoomName(candidate.room);
      return room ? { type: 'changeRoom', room } : null;
    }
    case 'displayText': {
      const text = sanitizeActionText(candidate.text);
      return text ? { type: 'displayText', text } : null;
    }
    case 'replaceGraphics':
      return resolveReplaceGraphicsAction(candidate.payload, currentRoomName);
    case 'originalGraphics':
      return resolveOriginalGraphicsAction(candidate.payload, currentRoomName);
    default:
      return null;
  }
}

function encodeClickActionText(action) {
  if (!action) return 'OK\n';
  switch (action.type) {
    case 'changeRoom':
      return `ROOM:${action.room}\n`;
    case 'displayText':
      return `TEXT:${sanitizeActionText(action.text)}\n`;
    case 'replaceGraphics':
      return `GFX:${action.sourceKey},${formatHexByte(action.x >> 8)},${formatHexByte(action.x)},${formatHexByte(action.y)},${formatHexByte(action.width)},${formatHexByte(action.height)}\n`;
    case 'originalGraphics':
      return action.x === undefined
        ? 'ORIG\n'
        : `ORIG:${formatHexByte(action.x >> 8)},${formatHexByte(action.x)},${formatHexByte(action.y)},${formatHexByte(action.width)},${formatHexByte(action.height)}\n`;
    default:
      return 'OK\n';
  }
}

function executeClickScript(requestedRoomName, room, logicalX, y) {
  const store = loadStore();
  const x = logicalX * 2;
  const persistedState = normalizeScriptState(store.scriptState);
  const persistedStateJson = JSON.stringify(persistedState);
  const roomSelections = (room.selections || []).map((selection) => ({
    id: selection.id,
    type: selection.type || 'rect',
    name: selection.name,
    x: selection.x,
    y: selection.y,
    width: selection.width,
    height: selection.height,
    visible: selection.visible !== false,
    locked: selection.locked === true
  }));

  const sandbox = {
    roomName: room.name,
    requestedRoomName,
    logicalX,
    x,
    y,
    state: persistedState,
    gameState: persistedState,
    roomSelections,
    selections: buildSelectionsForScript(store),
    rooms: buildRoomsForScript(store),
    changeRoom: (roomName) => ({ type: 'changeRoom', room: roomName }),
    displayText: (text) => ({ type: 'displayText', text }),
    replaceGraphics: (payload = {}) => ({ type: 'replaceGraphics', payload }),
    replaceGraphisc: (payload = {}) => ({ type: 'replaceGraphics', payload }),
    originalGraphics: (payload = {}) => ({ type: 'originalGraphics', payload }),
    originalGraphisc: (payload = {}) => ({ type: 'originalGraphics', payload }),
    orginalGraphics: (payload = {}) => ({ type: 'originalGraphics', payload }),
    orginalGraphisc: (payload = {}) => ({ type: 'originalGraphics', payload })
  };
  const context = vm.createContext(sandbox);

  const wrappedSource = `(function () {\n${store.clickScript || DEFAULT_CLICK_SCRIPT}\n})()`;
  try {
    const script = new vm.Script(wrappedSource, { filename: 'click-script.vm.js' });
    const result = script.runInContext(context, { timeout: 50 });
    const serializedState = vm.runInContext(
      '(typeof state === "object" && state && !Array.isArray(state)) ? JSON.stringify(state) : "{}"',
      context,
      { timeout: 10 }
    );
    const nextState = normalizeScriptState(JSON.parse(serializedState));
    if (JSON.stringify(nextState) !== persistedStateJson) {
      store.scriptState = nextState;
      saveStore(store);
    }
    return normalizeClickActionResult(result, room.name);
  } catch (error) {
    console.error(`[SCRIPT] click handler failed: ${error.stack || error.message}`);
    return { type: 'displayText', text: 'SCRIPT ERROR' };
  }
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

function calibrateAtariClickY(rawY) {
  const y = Math.max(0, Math.min(IMAGE_HEIGHT - 1, clampInteger(rawY, 0)));
  return Math.min(
    IMAGE_HEIGHT - 1,
    Math.round((y * (IMAGE_HEIGHT - 1)) / ATARI_VISIBLE_MAX_CLICK_Y)
  );
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

async function handleCreateRoom(req, res) {
  const body = await readJsonBody(req);
  const name = sanitizeRoomName(body.name);
  
  if (!name) {
    sendJson(res, 400, { error: 'Room name is required' });
    return;
  }

  const store = loadStore();
  if (store.rooms.find(r => r.name === name)) {
    sendJson(res, 400, { error: 'Room already exists' });
    return;
  }

  const id = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
  const roomDir = path.join(ROOMS_DIR, id);
  fs.mkdirSync(roomDir, { recursive: true });

  const room = {
    id,
    name,
    slides: [],
    selections: [],
    createdAt: new Date().toISOString()
  };

  store.rooms.push(room);
  saveStore(store);

  sendJson(res, 201, { ok: true, room });
}

async function handleCreateSlide(req, res) {
  const body = await readJsonBody(req);
  const roomName = sanitizeRoomName(body.roomName);
  const title = sanitizeTitle(body.title);
  const vbxeBase64 = String(body.vbxeBase64 || '');

  if (!roomName || !vbxeBase64) {
    sendJson(res, 400, { error: 'roomName and vbxeBase64 are required' });
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

  const store = loadStore();
  const room = store.rooms.find(r => r.name === roomName);
  if (!room) {
    sendJson(res, 404, { error: 'Room not found' });
    return;
  }

  const id = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
  const fileName = `${id}.vbxe`;
  const roomDir = path.join(ROOMS_DIR, room.id);
  
  if (!fs.existsSync(roomDir)) {
    fs.mkdirSync(roomDir, { recursive: true });
  }
  
  fs.writeFileSync(path.join(roomDir, fileName), buffer);

  if (!room.slides) room.slides = [];
  room.slides.push({
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

async function handleReplaceRoomImage(req, res, roomName) {
  const body = await readJsonBody(req);
  const normalizedRoomName = sanitizeRoomName(roomName);
  const title = sanitizeTitle(body.title);
  const vbxeBase64 = String(body.vbxeBase64 || '');

  if (!normalizedRoomName || !vbxeBase64) {
    sendJson(res, 400, { error: 'Room name and vbxeBase64 are required' });
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

  const store = loadStore();
  const room = getRoomFromStore(store, normalizedRoomName);
  if (!room) {
    sendJson(res, 404, { error: 'Room not found' });
    return;
  }

  const id = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
  const fileName = `${id}.vbxe`;
  const roomDir = path.join(ROOMS_DIR, room.id);

  if (!fs.existsSync(roomDir)) {
    fs.mkdirSync(roomDir, { recursive: true });
  }
  
  fs.writeFileSync(path.join(roomDir, fileName), buffer);

  room.slides = [{
    id,
    title,
    fileName,
    width: dimensions.width,
    height: dimensions.height,
    createdAt: new Date().toISOString()
  }];
  saveStore(store);

  sendJson(res, 201, {
    ok: true,
    image: {
      id,
      title,
      fileName,
      width: dimensions.width,
      height: dimensions.height,
      atariUrl: `/room/${encodeURIComponent(normalizedRoomName)}`
    }
  });
}

async function handleSaveCroppedImage(req, res, roomName) {
  const normalizedRoomName = sanitizeRoomName(roomName);
  
  const store = loadStore();
  const room = getRoomFromStore(store, normalizedRoomName);
  if (!room) {
    sendJson(res, 404, { error: 'Room not found' });
    return;
  }

  const roomDir = path.join(ROOMS_DIR, room.id);
  if (!fs.existsSync(roomDir)) {
    fs.mkdirSync(roomDir, { recursive: true });
  }

  const chunks = [];
  let total = 0;

  for await (const chunk of req) {
    total += chunk.length;
    if (total > MAX_BODY_BYTES) {
      sendJson(res, 400, { error: 'Request body too large' });
      return;
    }
    chunks.push(chunk);
  }

  const buffer = Buffer.concat(chunks);
  if (!isPngBuffer(buffer)) {
    sendJson(res, 400, { error: 'Expected raw PNG upload data' });
    return;
  }

  const croppedImagePath = path.join(roomDir, 'cropped.png');
  fs.writeFileSync(croppedImagePath, buffer);

  sendJson(res, 200, { ok: true });
}

async function handleGetCroppedImage(req, res, roomName) {
  const normalizedRoomName = sanitizeRoomName(roomName);
  
  const store = loadStore();
  const room = getRoomFromStore(store, normalizedRoomName);
  if (!room) {
    sendJson(res, 404, { error: 'Room not found' });
    return;
  }

  const roomDir = path.join(ROOMS_DIR, room.id);
  const croppedImagePath = path.join(roomDir, 'cropped.png');
  
  if (!fs.existsSync(croppedImagePath)) {
    sendJson(res, 404, { error: 'Cropped image not found' });
    return;
  }

  const buffer = fs.readFileSync(croppedImagePath);
  res.writeHead(200, {
    'Content-Type': 'image/png',
    'Content-Length': buffer.length,
    'Cache-Control': 'no-store',
    'Connection': 'close'
  });
  res.end(buffer);
}

async function handleCreateSelection(req, res, roomName) {
  const body = await readJsonBody(req);
  const store = loadStore();
  const room = getRoomFromStore(store, roomName);
  if (!room) {
    sendJson(res, 404, { error: 'Room not found' });
    return;
  }

  const selection = sanitizeSelectionRecord(body, {
    name: body.name || `Selection ${(room.selections || []).length + 1}`,
    x: 24,
    y: 24,
    width: 48,
    height: 32
  });

  if (selection.type === 'image') {
    const imagePngBase64 = typeof body.imagePngBase64 === 'string' ? body.imagePngBase64 : '';
    const imageBuffer = Buffer.from(imagePngBase64, 'base64');
    if (!isPngBuffer(imageBuffer)) {
      sendJson(res, 400, { error: 'Image selections require a valid PNG fragment.' });
      return;
    }

    const imageVbxeBase64 = typeof body.imageVbxeBase64 === 'string' ? body.imageVbxeBase64 : '';
    const patchBuffer = Buffer.from(imageVbxeBase64, 'base64');
    try {
      validateVbxePayload(patchBuffer, { minPixels: 1, minWidth: 1, minHeight: 1 });
    } catch (error) {
      sendJson(res, 400, { error: `Image selections require a valid VBXE patch: ${error.message}` });
      return;
    }

    const roomDir = path.join(ROOMS_DIR, room.id);
    if (!fs.existsSync(roomDir)) {
      fs.mkdirSync(roomDir, { recursive: true });
    }

    selection.imageFileName = `selection-${selection.id}.png`;
    selection.patchFileName = `selection-${selection.id}.vbxe`;
    fs.writeFileSync(path.join(roomDir, selection.imageFileName), imageBuffer);
    fs.writeFileSync(path.join(roomDir, selection.patchFileName), patchBuffer);
  }

  room.selections = [...(room.selections || []), selection];
  saveStore(store);
  sendJson(res, 201, { ok: true, selection });
}

function handleGetClickScript(res) {
  const store = loadStore();
  sendJson(res, 200, { script: store.clickScript || DEFAULT_CLICK_SCRIPT });
}

async function handleSaveClickScript(req, res) {
  const body = await readJsonBody(req);
  const script = typeof body.script === 'string' ? body.script : '';
  const store = loadStore();
  store.clickScript = script || DEFAULT_CLICK_SCRIPT;
  saveStore(store);
  sendJson(res, 200, { ok: true, script: store.clickScript });
}

async function handleUpdateSelection(req, res, roomName, selectionId) {
  const body = await readJsonBody(req);
  const store = loadStore();
  const room = getRoomFromStore(store, roomName);
  if (!room) {
    sendJson(res, 404, { error: 'Room not found' });
    return;
  }

  const index = (room.selections || []).findIndex((selection) => selection.id === selectionId);
  if (index === -1) {
    sendJson(res, 404, { error: 'Selection not found' });
    return;
  }

  const current = room.selections[index];
  const updated = sanitizeSelectionRecord({
    ...current,
    ...body,
    id: current.id,
    createdAt: current.createdAt
  });

  if (updated.type === 'image') {
    const roomDir = path.join(ROOMS_DIR, room.id);
    if (!fs.existsSync(roomDir)) {
      fs.mkdirSync(roomDir, { recursive: true });
    }

    if (typeof body.imagePngBase64 === 'string' && body.imagePngBase64) {
      const imageBuffer = Buffer.from(body.imagePngBase64, 'base64');
      if (!isPngBuffer(imageBuffer)) {
        sendJson(res, 400, { error: 'Image selection PNG fragment is invalid.' });
        return;
      }
      updated.imageFileName = updated.imageFileName || `selection-${updated.id}.png`;
      fs.writeFileSync(path.join(roomDir, updated.imageFileName), imageBuffer);
    }

    if (typeof body.imageVbxeBase64 === 'string' && body.imageVbxeBase64) {
      const patchBuffer = Buffer.from(body.imageVbxeBase64, 'base64');
      try {
        validateVbxePayload(patchBuffer, { minPixels: 1, minWidth: 1, minHeight: 1 });
      } catch (error) {
        sendJson(res, 400, { error: `Image selection VBXE patch is invalid: ${error.message}` });
        return;
      }
      updated.patchFileName = updated.patchFileName || `selection-${updated.id}.vbxe`;
      fs.writeFileSync(path.join(roomDir, updated.patchFileName), patchBuffer);
    }
  }

  room.selections[index] = updated;
  saveStore(store);
  sendJson(res, 200, { ok: true, selection: updated });
}

function handleDeleteSelection(res, roomName, selectionId) {
  const store = loadStore();
  const room = getRoomFromStore(store, roomName);
  if (!room) {
    sendJson(res, 404, { error: 'Room not found' });
    return;
  }

  const beforeCount = (room.selections || []).length;
  const removedSelection = (room.selections || []).find((selection) => selection.id === selectionId) || null;
  room.selections = (room.selections || []).filter((selection) => selection.id !== selectionId);
  if (room.selections.length === beforeCount) {
    sendJson(res, 404, { error: 'Selection not found' });
    return;
  }

  if (removedSelection?.imageFileName) {
    const imagePath = path.join(ROOMS_DIR, room.id, removedSelection.imageFileName);
    if (fs.existsSync(imagePath)) {
      fs.unlinkSync(imagePath);
    }
  }
  if (removedSelection?.patchFileName) {
    const patchPath = path.join(ROOMS_DIR, room.id, removedSelection.patchFileName);
    if (fs.existsSync(patchPath)) {
      fs.unlinkSync(patchPath);
    }
  }

  saveStore(store);
  sendJson(res, 200, { ok: true, deletedId: selectionId });
}

async function handleReorderSlides(req, res) {
  const body = await readJsonBody(req);
  const roomName = sanitizeRoomName(body.roomName);
  const ids = Array.isArray(body.ids) ? body.ids.map(String) : null;

  if (!roomName || !ids || ids.length === 0) {
    sendJson(res, 400, { error: 'roomName and ids array are required' });
    return;
  }

  const store = loadStore();
  const room = store.rooms.find(r => r.name === roomName);
  if (!room) {
    sendJson(res, 404, { error: 'Room not found' });
    return;
  }

  if (ids.length !== (room.slides || []).length) {
    sendJson(res, 400, { error: 'ids array length does not match current slide count' });
    return;
  }

  const byId = new Map((room.slides || []).map((slide) => [slide.id, slide]));
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

  room.slides = reordered;
  saveStore(store);
  sendJson(res, 200, { ok: true });
}

function handleDeleteSlide(res, roomName, slideId) {
  const store = loadStore();
  const room = store.rooms.find(r => r.name === roomName);
  if (!room) {
    sendJson(res, 404, { error: 'Room not found' });
    return;
  }

  const slides = room.slides || [];
  const index = slides.findIndex((slide) => slide.id === slideId);
  if (index === -1) {
    sendJson(res, 404, { error: 'Slide not found' });
    return;
  }

  const [removed] = slides.splice(index, 1);
  room.slides = slides;
  saveStore(store);

  const fullPath = path.join(ROOMS_DIR, room.id, removed.fileName);
  if (fs.existsSync(fullPath)) {
    fs.unlinkSync(fullPath);
  }

  sendJson(res, 200, { ok: true, removedId: slideId });
}

function handleDeleteRoom(res, roomName) {
  const store = loadStore();
  const index = store.rooms.findIndex(r => r.name === roomName);
  if (index === -1) {
    sendJson(res, 404, { error: 'Room not found' });
    return;
  }

  const [removed] = store.rooms.splice(index, 1);
  saveStore(store);

  const roomDir = path.join(ROOMS_DIR, removed.id);
  if (fs.existsSync(roomDir)) {
    fs.rmSync(roomDir, { recursive: true, force: true });
  }

  sendJson(res, 200, { ok: true, removedName: roomName });
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

    if (req.method === 'GET' && pathname === '/api/rooms') {
      sendJson(res, 200, { rooms: getRoomsWithOrder() });
      return;
    }

    if (req.method === 'GET' && pathname === '/api/script/click') {
      handleGetClickScript(res);
      return;
    }

    if (req.method === 'PUT' && pathname === '/api/script/click') {
      await handleSaveClickScript(req, res);
      return;
    }

    if (req.method === 'POST' && pathname === '/api/rooms') {
      await handleCreateRoom(req, res);
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

    const roomImageApiMatch = pathname.match(/^\/api\/rooms\/([^/]+)\/image$/);
    if (req.method === 'POST' && roomImageApiMatch) {
      const requestedRoom = decodeURIComponent(roomImageApiMatch[1]);
      await handleReplaceRoomImage(req, res, requestedRoom);
      return;
    }

    const croppedImageApiMatch = pathname.match(/^\/api\/rooms\/([^/]+)\/cropped-image$/);
    if (req.method === 'POST' && croppedImageApiMatch) {
      const requestedRoom = decodeURIComponent(croppedImageApiMatch[1]);
      await handleSaveCroppedImage(req, res, requestedRoom);
      return;
    }

    if (req.method === 'GET' && croppedImageApiMatch) {
      const requestedRoom = decodeURIComponent(croppedImageApiMatch[1]);
      await handleGetCroppedImage(req, res, requestedRoom);
      return;
    }

    const roomSelectionsApiMatch = pathname.match(/^\/api\/rooms\/([^/]+)\/selections$/);
    if (req.method === 'POST' && roomSelectionsApiMatch) {
      const requestedRoom = decodeURIComponent(roomSelectionsApiMatch[1]);
      await handleCreateSelection(req, res, requestedRoom);
      return;
    }

    const roomSelectionApiMatch = pathname.match(/^\/api\/rooms\/([^/]+)\/selections\/([A-Za-z0-9_-]+)$/);
    if (req.method === 'PUT' && roomSelectionApiMatch) {
      const requestedRoom = decodeURIComponent(roomSelectionApiMatch[1]);
      const selectionId = roomSelectionApiMatch[2];
      await handleUpdateSelection(req, res, requestedRoom, selectionId);
      return;
    }

    if (req.method === 'DELETE' && roomSelectionApiMatch) {
      const requestedRoom = decodeURIComponent(roomSelectionApiMatch[1]);
      const selectionId = roomSelectionApiMatch[2];
      handleDeleteSelection(res, requestedRoom, selectionId);
      return;
    }

    const roomSlidesApiMatch = pathname.match(/^\/api\/rooms\/([^/]+)\/slides$/);
    if (req.method === 'GET' && roomSlidesApiMatch) {
      const requestedRoom = decodeURIComponent(roomSlidesApiMatch[1]);
      const slides = getRoomSlides(requestedRoom);
      sendJson(res, 200, { slides });
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

    const deleteRoomMatch = pathname.match(/^\/api\/rooms\/([^/]+)$/);
    if (req.method === 'DELETE' && deleteRoomMatch) {
      const roomName = decodeURIComponent(deleteRoomMatch[1]);
      handleDeleteRoom(res, roomName);
      return;
    }

    const deleteSlideMatch = pathname.match(/^\/api\/rooms\/([^/]+)\/slides\/([A-Za-z0-9_-]+)$/);
    if (req.method === 'DELETE' && deleteSlideMatch) {
      const roomName = decodeURIComponent(deleteSlideMatch[1]);
      const slideId = deleteSlideMatch[2];
      handleDeleteSlide(res, roomName, slideId);
      return;
    }

    if (req.method === 'GET' && pathname === '/image') {
      const slide = getRoomSlidePayload('room1', 0);
      sendBinary(res, slide.buffer);
      console.log(`[RES] image alias -> slide 00 (${slide.width}x${slide.height})`);
      return;
    }

    const clickMatch = pathname.match(/^\/click\/([^/]+)\/([0-9A-Fa-f]{2})\/([0-9A-Fa-f]{2})$/);
    if (req.method === 'GET' && clickMatch) {
      const requestedRoom = decodeURIComponent(clickMatch[1]);
      const logicalX = parseHexByte(clickMatch[2]);
      const rawY = parseHexByte(clickMatch[3]);
      const slide = getRoomSlidePayload(requestedRoom, 0);

      if (!slide) {
        sendText(res, 404, `Room not found: ${requestedRoom}\n`);
        return;
      }
      if (logicalX === null || rawY === null || logicalX >= 160 || rawY >= IMAGE_HEIGHT) {
        sendText(res, 400, 'Invalid click coordinates\n');
        return;
      }

      const y = calibrateAtariClickY(rawY);

      const resolvedRoom = getRoom(requestedRoom);
      const clickRoomName = (resolvedRoom && resolvedRoom.name) || sanitizeRoomName(requestedRoom);
      const clickAction = executeClickScript(requestedRoom, resolvedRoom || { name: clickRoomName, selections: [] }, logicalX, y);
      roomClickState.set(clickRoomName, {
        logicalX,
        x: logicalX * 2,
        y,
        rawY,
        updatedAt: new Date().toISOString()
      });

      sendText(res, 200, encodeClickActionText(clickAction));
      console.log(
        `[EVENT] click ${clickRoomName} logical=(${logicalX},${rawY}) calibratedY=${y} pixel=(${logicalX * 2},${y})` +
        (clickAction ? ` action=${clickAction.type}` : '')
      );
      return;
    }

    const gfxMatch = pathname.match(/^\/gfx\/([^/]+)\/([^/]+)\/([0-9A-Fa-f]{2})\/([0-9A-Fa-f]{2})$/);
    if (req.method === 'GET' && gfxMatch) {
      const sourceToken = decodeURIComponent(gfxMatch[1]);
      const targetRoom = decodeURIComponent(gfxMatch[2]);
      const width = parseHexByte(gfxMatch[3]);
      const height = parseHexByte(gfxMatch[4]);
      if (width === null || height === null || width < 1 || height < 1) {
        sendText(res, 400, 'Invalid patch dimensions\n');
        return;
      }
      const patch = buildGraphicsPatchPayload(sourceToken, targetRoom, width, height);
      sendBinary(res, patch.buffer);
      console.log(
        `[RES] gfx ${sourceToken} -> ${targetRoom} ${patch.width}x${patch.height} ${patch.buffer.length} bytes`
      );
      return;
    }

    const roomMatch = pathname.match(/^\/room\/([^/]+)$/);
    if (req.method === 'GET' && roomMatch) {
      const requestedRoom = decodeURIComponent(roomMatch[1]);
      const slide = getRoomSlidePayload(requestedRoom, 0);
      sendBinary(res, slide.buffer);
      console.log(
        `[RES] room ${requestedRoom} -> ${slide.position} ` +
        `"${slide.title}" ${slide.width}x${slide.height} ${slide.buffer.length} bytes`
      );
      return;
    }

    const roomSlideMatch = pathname.match(/^\/room\/([^/]+)\/slide\/([0-9A-Fa-f]{1,2})$/);
    if (req.method === 'GET' && roomSlideMatch) {
      const requestedRoom = decodeURIComponent(roomSlideMatch[1]);
      const requestedIndex = Number.parseInt(roomSlideMatch[2], 16);
      const slide = getRoomSlidePayload(requestedRoom, requestedIndex);
      sendBinary(res, slide.buffer);
      console.log(
        `[RES] room ${requestedRoom} slide ${requestedIndex.toString(16).padStart(2, '0').toUpperCase()} -> ${slide.position} ` +
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
      const roomCount = Math.max(getRoomsWithOrder().length, 1);
      const payloadText = buildTextPayload(req, roomCount);
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
  console.log(`FujiNet room server running on port ${PORT}`);
  console.log(`Text URL: N:http://127.0.0.1:${PORT}/`);
  console.log(`Room URL: N:http://127.0.0.1:${PORT}/room/room1`);
  console.log(`Web UI: http://127.0.0.1:${PORT}/web`);
});