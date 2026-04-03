const MAX_WIDTH = 320;
const MAX_HEIGHT = 200;
const RESERVED_COLORS = 8;
const PALETTE_COLORS = 256 - RESERVED_COLORS;

// UI Elements
const fileInput = document.getElementById('file-input');
const uploadForm = document.getElementById('upload-form');
const uploadButton = document.getElementById('upload-button');
const refreshButton = document.getElementById('refresh-button');
const statusNode = document.getElementById('status');
const roomUploadTabBtn = document.getElementById('room-upload-tab-btn');
const roomEditTabBtn = document.getElementById('room-edit-tab-btn');
const uploadPanel = document.getElementById('upload-panel');
const editPanel = document.getElementById('edit-panel');
const roomStage = document.getElementById('room-stage');
const roomPreviewCanvas = document.getElementById('room-preview');
const selectionOverlay = document.getElementById('selection-overlay');
const roomPreviewMeta = document.getElementById('room-preview-meta');
const roomUrlPill = document.getElementById('room-url-pill');
const roomList = document.getElementById('room-list');
const addRoomBtn = document.getElementById('add-room-btn');
const roomTitle = document.getElementById('room-title');
const roomContent = document.getElementById('room-content');
const noRoomSelected = document.getElementById('no-room-selected');
const deleteRoomBtn = document.getElementById('delete-room-btn');
const addSelectionBtn = document.getElementById('add-selection-btn');
const selectionList = document.getElementById('selection-list');
const selectionEmpty = document.getElementById('selection-empty');
const selectionForm = document.getElementById('selection-form');
const selectionFormPlaceholder = document.getElementById('selection-form-placeholder');
const selectionNameInput = document.getElementById('selection-name-input');
const selectionXInput = document.getElementById('selection-x-input');
const selectionYInput = document.getElementById('selection-y-input');
const selectionWidthInput = document.getElementById('selection-width-input');
const selectionHeightInput = document.getElementById('selection-height-input');
const deleteSelectionBtn = document.getElementById('delete-selection-btn');

// Crop elements
const cropContainer = document.getElementById('crop-container');
const cropCanvas = document.getElementById('crop-canvas');
const cropPreviewCanvas = document.getElementById('crop-preview-canvas');
const scaleSlider = document.getElementById('scale-slider');
const scaleValue = document.getElementById('scale-value');
const resetCropBtn = document.getElementById('reset-crop-btn');
const cancelCropBtn = document.getElementById('cancel-crop-btn');
const applyCropBtn = document.getElementById('apply-crop-btn');
const cropInfo = document.getElementById('crop-info');
const cropSourceMeta = document.getElementById('crop-source-meta');

// Modal elements
const addRoomModal = document.getElementById('add-room-modal');
const roomNameInput = document.getElementById('room-name-input');

// State
let currentRoom = null;
let currentRoomData = null;
let currentRoomPanel = 'upload';
let selectedSelectionId = null;
let rooms = [];
let selectionInteraction = null;
let cropState = {
  image: null,
  fileName: '',
  scale: 1,
  offsetX: 0,
  offsetY: 0,
  isDragging: false,
  dragStartX: 0,
  dragStartY: 0,
  lastOffsetX: 0,
  lastOffsetY: 0,
  pendingResolve: null
};

// Event listeners
uploadForm.addEventListener('submit', onUploadSubmit);
refreshButton.addEventListener('click', () => refreshRoomPreview());
addRoomBtn.addEventListener('click', openAddRoomModal);
deleteRoomBtn.addEventListener('click', deleteRoom);
roomUploadTabBtn.addEventListener('click', () => setRoomPanel('upload'));
roomEditTabBtn.addEventListener('click', () => setRoomPanel('edit'));
addSelectionBtn.addEventListener('click', createSelection);
selectionForm.addEventListener('input', onSelectionFormInput);
deleteSelectionBtn.addEventListener('click', deleteSelection);

// Crop event listeners
scaleSlider.addEventListener('input', onScaleChange);
resetCropBtn.addEventListener('click', resetCrop);
cancelCropBtn.addEventListener('click', cancelCrop);
applyCropBtn.addEventListener('click', applyCrop);
cropCanvas.addEventListener('mousedown', onCropMouseDown);
cropCanvas.addEventListener('mousemove', onCropMouseMove);
cropCanvas.addEventListener('mouseup', onCropMouseUp);
cropCanvas.addEventListener('mouseleave', onCropMouseUp);

// Modal event listeners
window.onclick = function(event) {
  if (event.target === addRoomModal) {
    closeAddRoomModal();
  }
};

// Initialize
refreshRooms();
setInterval(() => {
  if (currentRoom && currentRoomPanel === 'edit' && !document.hidden && !selectionInteraction) {
    refreshRoomPreview(true);
  }
}, 1500);

async function refreshRooms() {
  try {
    const data = await fetchJson('/api/rooms');
    rooms = data.rooms || [];
    renderRooms();

    if (currentRoom && !rooms.some((room) => room.name === currentRoom)) {
      currentRoom = null;
      currentRoomData = null;
    }
    
    if (rooms.length > 0 && !currentRoom) {
      await selectRoom(rooms[0].name);
      return;
    }

    if (!rooms.length) {
      noRoomSelected.style.display = 'flex';
      roomContent.style.display = 'none';
    }
  } catch (error) {
    setStatus('Failed to load rooms: ' + error.message, true);
  }
}

function renderRooms() {
  roomList.innerHTML = '';

  if (!rooms.length) {
    const empty = document.createElement('div');
    empty.className = 'empty-panel';
    empty.textContent = 'No rooms yet. Create your first room to start building screens for the game.';
    roomList.appendChild(empty);
    return;
  }
  
  rooms.forEach(room => {
    const item = document.createElement('div');
    item.className = 'room-item';
    if (currentRoom === room.name) {
      item.classList.add('active');
    }
    
    item.innerHTML = `
      <div class="room-name">${room.name}</div>
      <div class="room-meta">${room.hasImage ? 'custom image ready' : 'demo image only'}</div>
    `;
    
    item.addEventListener('click', () => selectRoom(room.name));
    roomList.appendChild(item);
  });
}

async function selectRoom(roomName) {
  currentRoom = roomName;
  selectedSelectionId = null;
  renderRooms();
  hideCropInterface();
  
  roomTitle.textContent = roomName;
  noRoomSelected.style.display = 'none';
  roomContent.style.display = 'block';
  
  await refreshRoomPreview();
  setRoomPanel(currentRoomData?.hasCustomImage ? 'edit' : 'upload');
}

async function refreshRoomPreview(silent = false) {
  if (!currentRoom) return;
  
  try {
    const room = await fetchJson(`/api/rooms/${encodeURIComponent(currentRoom)}`);
    currentRoomData = room;
    if (!getSelections().some((selection) => selection.id === selectedSelectionId)) {
      selectedSelectionId = null;
    }
    renderRoomPreview(room);
    if (!silent) {
      if (room.hasCustomImage) {
        setStatus(`Loaded room image "${room.imageTitle}" in ${currentRoom}.`);
      } else {
        setStatus('This room is still using the generated demo image. Use Upload room image to replace it.');
      }
    }
  } catch (error) {
    if (!silent) {
      throw error;
    }
    roomPreviewMeta.textContent = `Room preview refresh failed: ${error.message}`;
  }
}

function renderRoomPreview(room) {
  const vbxe = base64ToBytes(room.vbxeBase64 || '');
  drawVbxeToCanvas(roomPreviewCanvas, vbxe, room.lastClick || null);
  roomUrlPill.textContent = `Atari URL ${room.atariUrl}`;

  const clickText = room.lastClick
    ? `Last click: ${room.lastClick.x}, ${room.lastClick.y}`
    : 'Last click: none yet';
  const imageStatus = room.hasCustomImage ? `Custom image: ${room.imageTitle}` : 'Using generated demo image';
  roomPreviewMeta.textContent = `${imageStatus} • ${room.width}x${room.height} • ${clickText}`;
  renderSelectionEditor();
}

function setRoomPanel(panelName) {
  if (panelName !== 'upload' && cropState.pendingResolve) {
    cancelCrop();
  }

  currentRoomPanel = panelName;
  const isUpload = panelName === 'upload';

  roomUploadTabBtn.classList.toggle('active', isUpload);
  roomEditTabBtn.classList.toggle('active', !isUpload);
  uploadPanel.style.display = isUpload ? 'grid' : 'none';
  editPanel.style.display = isUpload ? 'none' : 'grid';

  if (!isUpload) {
    renderSelectionEditor();
  }
}

function getSelections() {
  return currentRoomData?.selections || [];
}

function getSelectionById(selectionId) {
  return getSelections().find((selection) => selection.id === selectionId) || null;
}

function clampSelection(selection) {
  const maxWidth = currentRoomData?.width || MAX_WIDTH;
  const maxHeight = currentRoomData?.height || MAX_HEIGHT;
  const x = Math.max(0, Math.min(maxWidth - 1, Number.parseInt(selection.x, 10) || 0));
  const y = Math.max(0, Math.min(maxHeight - 1, Number.parseInt(selection.y, 10) || 0));
  const width = Math.max(1, Math.min(maxWidth - x, Number.parseInt(selection.width, 10) || 1));
  const height = Math.max(1, Math.min(maxHeight - y, Number.parseInt(selection.height, 10) || 1));
  return {
    ...selection,
    name: String(selection.name || 'Selection').slice(0, 80) || 'Selection',
    x,
    y,
    width,
    height
  };
}

function updateSelectionInState(selectionId, updater) {
  if (!currentRoomData) return null;
  const index = getSelections().findIndex((selection) => selection.id === selectionId);
  if (index === -1) return null;
  const nextSelection = clampSelection(updater(getSelections()[index]));
  currentRoomData.selections[index] = nextSelection;
  return nextSelection;
}

function renderSelectionEditor() {
  renderSelectionOverlay();
  renderSelectionList();
  renderSelectionForm();
}

function renderSelectionOverlay() {
  selectionOverlay.innerHTML = '';
  if (!currentRoomData) return;

  const width = currentRoomData.width || MAX_WIDTH;
  const height = currentRoomData.height || MAX_HEIGHT;
  getSelections().forEach((selection) => {
    const box = document.createElement('div');
    box.className = 'selection-box';
    if (selection.id === selectedSelectionId) {
      box.classList.add('active');
    }
    box.style.left = `${(selection.x / width) * 100}%`;
    box.style.top = `${(selection.y / height) * 100}%`;
    box.style.width = `${(selection.width / width) * 100}%`;
    box.style.height = `${(selection.height / height) * 100}%`;

    const label = document.createElement('div');
    label.className = 'selection-label';
    label.textContent = selection.name;
    box.appendChild(label);

    const handle = document.createElement('div');
    handle.className = 'selection-handle';
    handle.addEventListener('pointerdown', (event) => beginSelectionInteraction(event, selection.id, 'resize'));
    box.appendChild(handle);

    box.addEventListener('pointerdown', (event) => beginSelectionInteraction(event, selection.id, 'move'));
    box.addEventListener('click', (event) => {
      event.stopPropagation();
      setSelectedSelection(selection.id);
    });

    selectionOverlay.appendChild(box);
  });
}

function renderSelectionList() {
  selectionList.innerHTML = '';
  const selections = getSelections();
  selectionEmpty.style.display = selections.length ? 'none' : 'block';

  selections.forEach((selection) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = selection.name;
    if (selection.id === selectedSelectionId) {
      button.classList.add('active');
    }
    button.addEventListener('click', () => setSelectedSelection(selection.id));
    selectionList.appendChild(button);
  });
}

function renderSelectionForm() {
  const selection = getSelectionById(selectedSelectionId);
  if (!selection) {
    selectionForm.style.display = 'none';
    selectionFormPlaceholder.style.display = 'block';
    return;
  }

  selectionForm.style.display = 'grid';
  selectionFormPlaceholder.style.display = 'none';
  selectionNameInput.value = selection.name;
  selectionXInput.value = selection.x;
  selectionYInput.value = selection.y;
  selectionWidthInput.value = selection.width;
  selectionHeightInput.value = selection.height;
}

function setSelectedSelection(selectionId) {
  selectedSelectionId = selectionId;
  renderSelectionEditor();
}

function onSelectionFormInput() {
  const selection = getSelectionById(selectedSelectionId);
  if (!selection) return;

  const updated = updateSelectionInState(selectedSelectionId, (current) => ({
    ...current,
    name: selectionNameInput.value,
    x: selectionXInput.value,
    y: selectionYInput.value,
    width: selectionWidthInput.value,
    height: selectionHeightInput.value
  }));

  if (!updated) return;
  renderSelectionOverlay();
  renderSelectionList();
  saveSelection(updated).catch((error) => setStatus(error.message, true));
}

function beginSelectionInteraction(event, selectionId, mode) {
  event.preventDefault();
  event.stopPropagation();

  const selection = getSelectionById(selectionId);
  if (!selection || !roomStage) return;

  setSelectedSelection(selectionId);
  selectionInteraction = {
    mode,
    selectionId,
    startX: event.clientX,
    startY: event.clientY,
    origin: { ...selection }
  };

  window.addEventListener('pointermove', onSelectionPointerMove);
  window.addEventListener('pointerup', onSelectionPointerUp, { once: true });
}

function onSelectionPointerMove(event) {
  if (!selectionInteraction || !roomStage || !currentRoomData) return;
  const rect = roomStage.getBoundingClientRect();
  if (!rect.width || !rect.height) return;

  const dx = Math.round(((event.clientX - selectionInteraction.startX) * currentRoomData.width) / rect.width);
  const dy = Math.round(((event.clientY - selectionInteraction.startY) * currentRoomData.height) / rect.height);

  updateSelectionInState(selectionInteraction.selectionId, (current) => {
    if (selectionInteraction.mode === 'resize') {
      return {
        ...current,
        width: selectionInteraction.origin.width + dx,
        height: selectionInteraction.origin.height + dy
      };
    }

    return {
      ...current,
      x: selectionInteraction.origin.x + dx,
      y: selectionInteraction.origin.y + dy
    };
  });

  renderSelectionEditor();
}

async function onSelectionPointerUp() {
  window.removeEventListener('pointermove', onSelectionPointerMove);
  const activeInteraction = selectionInteraction;
  selectionInteraction = null;
  if (!activeInteraction) return;

  const selection = getSelectionById(activeInteraction.selectionId);
  if (!selection) return;

  try {
    await saveSelection(selection);
  } catch (error) {
    setStatus(error.message, true);
  }
}

async function onUploadSubmit(event) {
  event.preventDefault();
  const file = fileInput.files?.[0];
  if (!file) {
    setStatus('Choose a room image first.', true);
    return;
  }

  uploadButton.disabled = true;
  refreshButton.disabled = true;

  try {
    setStatus(`Adjusting ${file.name} before VBXE conversion...`);
    const croppedImage = await openCropSession(file);
    if (!croppedImage) {
      setStatus('Upload cancelled.', true);
      return;
    }

    setStatus(`Converting ${file.name} to VBXE...`);
    const vbxe = await convertImageToVbxe(croppedImage);
    await uploadRoomImage(file.name, vbxe);

    fileInput.value = '';
    await refreshRoomPreview();
    setRoomPanel('edit');
    setStatus('Room image uploaded. The Atari room view will use it immediately.');
  } catch (error) {
    setStatus(error.message, true);
  } finally {
    uploadButton.disabled = false;
    refreshButton.disabled = false;
    hideCropInterface();
  }
}

async function openCropSession(file) {
  const img = await loadImageFromFile(file);
  cropState.image = img;
  cropState.fileName = file.name;
  cropState.scale = 1;
  cropState.offsetX = 0;
  cropState.offsetY = 0;
  cropState.lastOffsetX = 0;
  cropState.lastOffsetY = 0;
  cropState.isDragging = false;
  cropSourceMeta.textContent = `${file.name} • ${img.width}×${img.height}`;
  cropContainer.style.display = 'block';
  resetCrop();
  setStatus(`Previewing ${file.name}. Drag to pan and use zoom before applying the 320×200 crop.`);

  return new Promise((resolve) => {
    cropState.pendingResolve = resolve;
  });
}

function getCropBaseScale() {
  if (!cropState.image) return 1;
  return Math.max(MAX_WIDTH / cropState.image.width, MAX_HEIGHT / cropState.image.height);
}

function getCropDrawMetrics() {
  const baseScale = getCropBaseScale();
  const effectiveScale = baseScale * cropState.scale;
  return {
    effectiveScale,
    drawWidth: cropState.image.width * effectiveScale,
    drawHeight: cropState.image.height * effectiveScale
  };
}

function clampCropOffsets() {
  if (!cropState.image) return;
  const { drawWidth, drawHeight } = getCropDrawMetrics();

  if (drawWidth <= MAX_WIDTH) {
    cropState.offsetX = (MAX_WIDTH - drawWidth) / 2;
  } else {
    cropState.offsetX = Math.min(0, Math.max(MAX_WIDTH - drawWidth, cropState.offsetX));
  }

  if (drawHeight <= MAX_HEIGHT) {
    cropState.offsetY = (MAX_HEIGHT - drawHeight) / 2;
  } else {
    cropState.offsetY = Math.min(0, Math.max(MAX_HEIGHT - drawHeight, cropState.offsetY));
  }
}

function hideCropInterface() {
  cropContainer.style.display = 'none';
  cropState.image = null;
  cropState.fileName = '';
  cropState.pendingResolve = null;
  cropSourceMeta.textContent = 'No image loaded';
}

function drawCropCanvas() {
  if (!cropState.image) return;
  cropCanvas.width = 640;
  cropCanvas.height = 400;
  renderCropSurface(cropCanvas, true);
  updateCropPreview();
}

function renderCropSurface(canvas, showGuides = false) {
  if (!cropState.image) return;

  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  const renderScaleX = canvas.width / MAX_WIDTH;
  const renderScaleY = canvas.height / MAX_HEIGHT;
  const { drawWidth, drawHeight } = getCropDrawMetrics();

  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = '#020617';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(
    cropState.image,
    cropState.offsetX * renderScaleX,
    cropState.offsetY * renderScaleY,
    drawWidth * renderScaleX,
    drawHeight * renderScaleY
  );

  if (showGuides) {
    ctx.strokeStyle = 'rgba(59, 130, 246, 0.95)';
    ctx.lineWidth = 2;
    ctx.strokeRect(1, 1, canvas.width - 2, canvas.height - 2);

    ctx.strokeStyle = 'rgba(148, 163, 184, 0.45)';
    ctx.lineWidth = 1;
    ctx.setLineDash([8, 8]);
    for (let i = 1; i <= 2; i += 1) {
      const x = (canvas.width / 3) * i;
      const y = (canvas.height / 3) * i;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, canvas.height);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(canvas.width, y);
      ctx.stroke();
    }
    ctx.setLineDash([]);
  }

  cropInfo.textContent = `${cropState.fileName} • source ${cropState.image.width}×${cropState.image.height} • output ${MAX_WIDTH}×${MAX_HEIGHT} • zoom ${Math.round(cropState.scale * 100)}%`;
}

function updateCropPreview() {
  if (!cropState.image) return;
  renderCropSurface(cropPreviewCanvas, false);
}

function onScaleChange() {
  if (!cropState.image) return;

  const nextScale = parseFloat(scaleSlider.value);
  const previousMetrics = getCropDrawMetrics();
  const sourceCenterX = (MAX_WIDTH / 2 - cropState.offsetX) / previousMetrics.effectiveScale;
  const sourceCenterY = (MAX_HEIGHT / 2 - cropState.offsetY) / previousMetrics.effectiveScale;

  cropState.scale = nextScale;
  const nextMetrics = getCropDrawMetrics();
  cropState.offsetX = MAX_WIDTH / 2 - (sourceCenterX * nextMetrics.effectiveScale);
  cropState.offsetY = MAX_HEIGHT / 2 - (sourceCenterY * nextMetrics.effectiveScale);
  clampCropOffsets();
  scaleValue.textContent = `${Math.round(cropState.scale * 100)}%`;
  drawCropCanvas();
}

function onCropMouseDown(e) {
  cropState.isDragging = true;
  const rect = cropCanvas.getBoundingClientRect();
  cropState.dragStartX = e.clientX - rect.left;
  cropState.dragStartY = e.clientY - rect.top;
  cropState.lastOffsetX = cropState.offsetX;
  cropState.lastOffsetY = cropState.offsetY;
}

function onCropMouseMove(e) {
  if (!cropState.isDragging) return;
  
  const rect = cropCanvas.getBoundingClientRect();
  const currentX = e.clientX - rect.left;
  const currentY = e.clientY - rect.top;
  
  const deltaX = currentX - cropState.dragStartX;
  const deltaY = currentY - cropState.dragStartY;

  const previewScale = cropCanvas.width / MAX_WIDTH;
  cropState.offsetX = cropState.lastOffsetX + (deltaX / previewScale);
  cropState.offsetY = cropState.lastOffsetY + (deltaY / previewScale);
  clampCropOffsets();
  
  drawCropCanvas();
}

function onCropMouseUp() {
  cropState.isDragging = false;
}

function resetCrop() {
  if (!cropState.image) return;

  cropState.scale = 1;
  scaleSlider.value = 1;
  const { drawWidth, drawHeight } = getCropDrawMetrics();
  cropState.offsetX = (MAX_WIDTH - drawWidth) / 2;
  cropState.offsetY = (MAX_HEIGHT - drawHeight) / 2;
  cropState.lastOffsetX = cropState.offsetX;
  cropState.lastOffsetY = cropState.offsetY;
  clampCropOffsets();
  scaleValue.textContent = '100%';
  drawCropCanvas();
}

function cancelCrop() {
  if (!cropState.pendingResolve) {
    hideCropInterface();
    return;
  }

  const resolve = cropState.pendingResolve;
  hideCropInterface();
  resolve(null);
}

function applyCrop() {
  if (!cropState.image || !cropState.pendingResolve) return;

  const canvas = document.createElement('canvas');
  canvas.width = MAX_WIDTH;
  canvas.height = MAX_HEIGHT;
  renderCropSurface(canvas, false);

  const resolve = cropState.pendingResolve;
  hideCropInterface();
  resolve(canvas);
}

async function convertImageToVbxe(canvas) {
  const ctx = canvas.getContext('2d');
  const imageData = ctx.getImageData(0, 0, MAX_WIDTH, MAX_HEIGHT);
  return convertImageDataToVbxe(imageData, MAX_WIDTH, MAX_HEIGHT);
}

async function uploadRoomImage(filename, vbxeData) {
  await fetchJson(`/api/rooms/${encodeURIComponent(currentRoom)}/image`, {
    method: 'POST',
    body: JSON.stringify({
      title: stripExtension(filename),
      vbxeBase64: bytesToBase64(vbxeData)
    })
  });
}

async function createSelection() {
  if (!currentRoom || !currentRoomData) return;

  const response = await fetchJson(`/api/rooms/${encodeURIComponent(currentRoom)}/selections`, {
    method: 'POST',
    body: JSON.stringify({
      name: `Selection ${getSelections().length + 1}`,
      x: 24,
      y: 24,
      width: 48,
      height: 32
    })
  });

  currentRoomData.selections = [...getSelections(), response.selection];
  selectedSelectionId = response.selection.id;
  renderSelectionEditor();
  setStatus(`Added selection "${response.selection.name}".`);
}

async function saveSelection(selection) {
  await fetchJson(`/api/rooms/${encodeURIComponent(currentRoom)}/selections/${encodeURIComponent(selection.id)}`, {
    method: 'PUT',
    body: JSON.stringify({
      name: selection.name,
      x: selection.x,
      y: selection.y,
      width: selection.width,
      height: selection.height
    })
  });
}

async function deleteSelection() {
  const selection = getSelectionById(selectedSelectionId);
  if (!selection || !currentRoomData) return;
  if (!window.confirm(`Delete selection "${selection.name}"?`)) {
    return;
  }

  await fetchJson(`/api/rooms/${encodeURIComponent(currentRoom)}/selections/${encodeURIComponent(selection.id)}`, {
    method: 'DELETE'
  });

  currentRoomData.selections = getSelections().filter((entry) => entry.id !== selection.id);
  selectedSelectionId = null;
  renderSelectionEditor();
  setStatus(`Deleted selection "${selection.name}".`);
}

// Room management
function openAddRoomModal() {
  addRoomModal.style.display = 'block';
  roomNameInput.focus();
}

function closeAddRoomModal() {
  addRoomModal.style.display = 'none';
  roomNameInput.value = '';
}

async function createRoom() {
  const name = roomNameInput.value.trim().toLowerCase();
  if (!name) {
    alert('Please enter a room name');
    return;
  }
  
  try {
    const result = await fetchJson('/api/rooms', {
      method: 'POST',
      body: JSON.stringify({ name })
    });
    
    closeAddRoomModal();
    await refreshRooms();
    await selectRoom(result.room.name);
  } catch (error) {
    alert('Failed to create room: ' + error.message);
  }
}

async function deleteRoom() {
  if (!currentRoom) return;
  
  if (!window.confirm(`Delete room "${currentRoom}" and its room image?`)) {
    return;
  }
  
  try {
    await fetchJson(`/api/rooms/${encodeURIComponent(currentRoom)}`, { method: 'DELETE' });
    currentRoom = null;
    currentRoomData = null;
    selectedSelectionId = null;
    await refreshRooms();
    
    if (rooms.length > 0) {
      await selectRoom(rooms[0].name);
    } else {
      noRoomSelected.style.display = 'flex';
      roomContent.style.display = 'none';
    }
  } catch (error) {
    alert('Failed to delete room: ' + error.message);
  }
}

// Utility functions
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