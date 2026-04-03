const MAX_WIDTH = 320;
const MAX_HEIGHT = 200;
const RESERVED_COLORS = 8;
const PALETTE_COLORS = 256 - RESERVED_COLORS;

const fileInput = document.getElementById('file-input');
const uploadForm = document.getElementById('upload-form');
const uploadButton = document.getElementById('upload-button');
const refreshButton = document.getElementById('refresh-button');
const statusNode = document.getElementById('status');
const slideList = document.getElementById('slide-list');
const roomPreviewCanvas = document.getElementById('room-preview');
const roomPreviewMeta = document.getElementById('room-preview-meta');

uploadForm.addEventListener('submit', onUploadSubmit);
refreshButton.addEventListener('click', refreshSlides);

void refreshSlides();
window.setInterval(() => {
  void refreshRoomPreview(true);
}, 1500);

async function refreshSlides() {
  setStatus('Loading slideshow state...');
  try {
    const data = await fetchJson('/api/slides');
    renderSlides(data.slides || []);
    await refreshRoomPreview(true);
    if ((data.slides || []).length === 0) {
      setStatus('No uploaded slides yet. The server will use its generated demo image until you upload one.');
    } else {
      setStatus(`Loaded ${data.slides.length} slide(s).`);
    }
  } catch (error) {
    setStatus(error.message, true);
  }
}

async function refreshRoomPreview(silent = false) {
  try {
    const room = await fetchJson('/api/rooms/room1');
    renderRoomPreview(room);
  } catch (error) {
    if (!silent) {
      throw error;
    }
    roomPreviewMeta.textContent = `Room preview refresh failed: ${error.message}`;
  }
}

function renderSlides(slides) {
  slideList.innerHTML = '';
  if (!slides.length) {
    const empty = document.createElement('li');
    empty.textContent = 'No uploaded slides.';
    slideList.appendChild(empty);
    return;
  }

  slides.forEach((slide, index) => {
    const item = document.createElement('li');

    const title = document.createElement('strong');
    title.textContent = slide.title;
    item.appendChild(title);

    const meta = document.createElement('div');
    meta.className = 'meta';
    meta.textContent = `${slide.width}x${slide.height} • Atari URL ${slide.atariUrl}`;
    item.appendChild(meta);

    const actions = document.createElement('div');
    actions.className = 'actions';

    actions.appendChild(makeButton('↑', index === 0, () => moveSlide(index, -1)));
    actions.appendChild(makeButton('↓', index === slides.length - 1, () => moveSlide(index, 1)));
    actions.appendChild(makeButton('Delete', false, () => deleteSlide(slide.id, slide.title)));
    item.appendChild(actions);

    slideList.appendChild(item);
  });
}

function renderRoomPreview(room) {
  const vbxe = base64ToBytes(room.vbxeBase64 || '');
  drawVbxeToCanvas(roomPreviewCanvas, vbxe, room.lastClick || null);

  const clickText = room.lastClick
    ? `Last click: ${room.lastClick.x}, ${room.lastClick.y}`
    : 'Last click: none yet';
  roomPreviewMeta.textContent = `${room.title} • ${room.width}x${room.height} • Atari URL ${room.atariUrl} • ${clickText}`;
}

function makeButton(label, disabled, handler) {
  const button = document.createElement('button');
  button.type = 'button';
  button.textContent = label;
  button.disabled = disabled;
  button.addEventListener('click', handler);
  return button;
}

async function moveSlide(index, delta) {
  const data = await fetchJson('/api/slides');
  const ids = data.slides.map((slide) => slide.id);
  const newIndex = index + delta;
  if (newIndex < 0 || newIndex >= ids.length) {
    return;
  }
  [ids[index], ids[newIndex]] = [ids[newIndex], ids[index]];
  setStatus('Saving new slideshow order...');
  await fetchJson('/api/slides/reorder', {
    method: 'POST',
    body: JSON.stringify({ ids })
  });
  await refreshSlides();
}

async function deleteSlide(id, title) {
  if (!window.confirm(`Delete slide "${title}"?`)) {
    return;
  }
  setStatus(`Deleting ${title}...`);
  await fetchJson(`/api/slides/${encodeURIComponent(id)}`, { method: 'DELETE' });
  await refreshSlides();
}

async function onUploadSubmit(event) {
  event.preventDefault();
  const files = Array.from(fileInput.files || []);
  if (!files.length) {
    setStatus('Choose at least one image file first.', true);
    return;
  }

  uploadButton.disabled = true;
  refreshButton.disabled = true;

  try {
    for (let i = 0; i < files.length; i += 1) {
      const file = files[i];
      setStatus(`Converting ${file.name} (${i + 1}/${files.length})...`);
      const vbxe = await convertFileToVbxe(file);
      setStatus(`Uploading ${file.name} (${i + 1}/${files.length})...`);
      await fetchJson('/api/slides', {
        method: 'POST',
        body: JSON.stringify({
          title: stripExtension(file.name),
          vbxeBase64: bytesToBase64(vbxe)
        })
      });
    }

    fileInput.value = '';
    await refreshSlides();
    setStatus('Upload complete. The Atari slideshow can use the new order immediately.');
  } catch (error) {
    setStatus(error.message, true);
  } finally {
    uploadButton.disabled = false;
    refreshButton.disabled = false;
  }
}

function stripExtension(fileName) {
  return fileName.replace(/\.[^.]+$/, '') || fileName;
}

async function convertFileToVbxe(file) {
  const img = await loadImageFromFile(file);
  const { imageData, width, height } = drawContainedImage(img, MAX_WIDTH, MAX_HEIGHT);
  return convertImageDataToVbxe(imageData, width, height);
}

function loadImageFromFile(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error(`Failed to read ${file.name}`));
    reader.onload = () => {
      const img = new Image();
      img.onerror = () => reject(new Error(`Failed to decode ${file.name}`));
      img.onload = () => resolve(img);
      img.src = reader.result;
    };
    reader.readAsDataURL(file);
  });
}

function drawContainedImage(img, maxWidth, maxHeight) {
  const scale = Math.min(maxWidth / img.width, maxHeight / img.height, 1);
  const drawWidth = Math.max(1, Math.round(img.width * scale));
  const drawHeight = Math.max(1, Math.round(img.height * scale));
  const x = Math.floor((maxWidth - drawWidth) / 2);
  const y = Math.floor((maxHeight - drawHeight) / 2);

  const canvas = document.createElement('canvas');
  canvas.width = maxWidth;
  canvas.height = maxHeight;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  ctx.fillStyle = '#000';
  ctx.fillRect(0, 0, maxWidth, maxHeight);
  ctx.drawImage(img, x, y, drawWidth, drawHeight);

  return {
    imageData: ctx.getImageData(0, 0, maxWidth, maxHeight),
    width: maxWidth,
    height: maxHeight
  };
}

function convertImageDataToVbxe(imageData, width, height) {
  const pixels = extractRgbPixels(imageData.data);
  let colors = medianCut(pixels.slice(), 8).slice(0, PALETTE_COLORS);
  while (colors.length < PALETTE_COLORS) {
    colors.push([0, 0, 0]);
  }

  const cache = new Map();
  const indexedPixels = new Uint8Array(width * height);
  for (let i = 0; i < pixels.length; i += 1) {
    const key = pixels[i].join(',');
    let paletteIndex = cache.get(key);
    if (paletteIndex === undefined) {
      paletteIndex = findNearestColorIndex(pixels[i], colors);
      cache.set(key, paletteIndex);
    }
    indexedPixels[i] = RESERVED_COLORS + paletteIndex;
  }

  const vbxe = new Uint8Array(3 + 768 + indexedPixels.length);
  vbxe[0] = width & 0xff;
  vbxe[1] = (width >> 8) & 0xff;
  vbxe[2] = height & 0xff;

  for (let i = 0; i < colors.length; i += 1) {
    const offset = 3 + ((RESERVED_COLORS + i) * 3);
    vbxe[offset] = colors[i][0];
    vbxe[offset + 1] = colors[i][1];
    vbxe[offset + 2] = colors[i][2];
  }

  vbxe.set(indexedPixels, 3 + 768);
  return vbxe;
}

function extractRgbPixels(rgba) {
  const pixels = [];
  for (let i = 0; i < rgba.length; i += 4) {
    const alpha = rgba[i + 3] / 255;
    pixels.push([
      Math.round(rgba[i] * alpha),
      Math.round(rgba[i + 1] * alpha),
      Math.round(rgba[i + 2] * alpha)
    ]);
  }
  return pixels;
}

function medianCut(pixels, depth) {
  if (depth === 0 || pixels.length <= 1) {
    return [averageColor(pixels)];
  }

  const ranges = [0, 1, 2].map((channel) => {
    let min = 255;
    let max = 0;
    for (const pixel of pixels) {
      if (pixel[channel] < min) min = pixel[channel];
      if (pixel[channel] > max) max = pixel[channel];
    }
    return max - min;
  });

  const channel = ranges.indexOf(Math.max(...ranges));
  pixels.sort((a, b) => a[channel] - b[channel]);

  const mid = Math.floor(pixels.length / 2);
  return medianCut(pixels.slice(0, mid), depth - 1)
    .concat(medianCut(pixels.slice(mid), depth - 1));
}

function averageColor(pixels) {
  if (!pixels.length) {
    return [0, 0, 0];
  }
  let r = 0;
  let g = 0;
  let b = 0;
  for (const pixel of pixels) {
    r += pixel[0];
    g += pixel[1];
    b += pixel[2];
  }
  return [
    Math.round(r / pixels.length),
    Math.round(g / pixels.length),
    Math.round(b / pixels.length)
  ];
}

function findNearestColorIndex(pixel, colors) {
  let bestIndex = 0;
  let bestDistance = Infinity;
  for (let i = 0; i < colors.length; i += 1) {
    const dr = pixel[0] - colors[i][0];
    const dg = pixel[1] - colors[i][1];
    const db = pixel[2] - colors[i][2];
    const distance = (dr * dr) + (dg * dg) + (db * db);
    if (distance < bestDistance) {
      bestDistance = distance;
      bestIndex = i;
    }
  }
  return bestIndex;
}

function bytesToBase64(bytes) {
  let binary = '';
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

function base64ToBytes(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function drawVbxeToCanvas(canvas, vbxe, lastClick) {
  const width = vbxe[0] | (vbxe[1] << 8);
  const height = vbxe[2];
  const paletteOffset = 3;
  const pixelOffset = 3 + 768;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });

  canvas.width = width;
  canvas.height = height;

  const imageData = ctx.createImageData(width, height);
  for (let i = 0; i < width * height; i += 1) {
    const colorIndex = vbxe[pixelOffset + i];
    const paletteIndex = paletteOffset + (colorIndex * 3);
    const out = i * 4;
    imageData.data[out] = vbxe[paletteIndex];
    imageData.data[out + 1] = vbxe[paletteIndex + 1];
    imageData.data[out + 2] = vbxe[paletteIndex + 2];
    imageData.data[out + 3] = 255;
  }
  ctx.putImageData(imageData, 0, 0);

  if (lastClick) {
    ctx.fillStyle = '#ff3b30';
    ctx.fillRect(lastClick.x, lastClick.y, 2, 2);
  }
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    ...options
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    throw new Error(data.error || `${response.status} ${response.statusText}`);
  }
  return data;
}

function setStatus(message, isError = false) {
  statusNode.textContent = message;
  statusNode.classList.toggle('error', isError);
}