# Click Script Reference

The click script runs in the server sandbox on every Atari room click and popup click.

- Return `null` or `undefined` for no action.
- Return a string as a shortcut for `displayText('...')`.
- Return an action from one of the helpers below.

## Context values

- `roomName` — resolved current room name.
- `requestedRoomName` — original room token from the request.
- `logicalX` — Atari logical X in `0..159`.
- `x` — pixel X in `0..319` (`logicalX * 2`).
- `y` — calibrated pixel Y in `0..199`.
- `clickType` — `'room'` or `'popup'`.
- `popupClick` — popup click context or `null`.
- `clickedLine`, `clickedColumn` — popup line/column shortcuts.
- `clickedWord` — word under the popup cursor.
- `clickedChoice`, `clickedChoiceText` — clicked popup choice id/text.
- `state`, `gameState`, `scriptState` — the same persistent JSON-safe object saved to `data/scriptState.json`.
- `roomSelections` — selections for the current room.
- `selections` — flattened selections from all rooms.
- `rooms` — all rooms with slides and selections.

### Selection fields

Selections expose:

- `id`
- `roomName` (only in the global `selections` list)
- `type`
- `name`
- `description`
- `x`, `y`, `width`, `height`
- `visible`
- `showOnClient`
- `visibleInPage`
- `locked`

## Helpers

- `changeRoom(roomName)`
  - Reload the Atari client into another room.

- `displayText(text)`
  - Show popup text near the click/cursor.

- `displayText({ text | message | lines, clickable, selectable, choices })`
  - Advanced popup form.

- `choice(id, text, options)`
  - Build one clickable popup choice for `displayChoices()`.

- `displayChoices(choices, options)`
  - Show up to 6 popup lines total. If `options.text` is present, it is shown above the clickable choices when there is room.

- `replaceGraphics(selectionName)`
  - Draw a saved image selection patch from the current room.

- `replaceGraphics({ selection, room, x, y, width, height })`
  - Draw an image selection patch with optional room and geometry overrides.

- `replaceGraphics({ room, sourceRoom, x, y, width, height })`
  - Copy a rectangular patch from a room image.

- `originalGraphics()`
  - Restore the full original room image.

- `originalGraphics(selectionName | payload)`
  - Restore only the affected rectangle. Payload matches `replaceGraphics()`.

### Compatibility typo aliases

These still work:

- `replaceGraphisc`
- `originalGraphisc`
- `orginalGraphics`
- `orginalGraphisc`

## Return values

- `null` / `undefined` — no action
- `'hello'` — same as `displayText('hello')`
- helper action object — normal scripted action
- array — the first truthy item is used

## Limits

- Popup maximum: **6** lines
- Popup line width: **37** characters after sanitizing/wrapping
- Popup choices maximum: **6** clickable lines
- Persist only plain JSON-safe data in `state`
- Keep scripts fast; the sandbox is timed

## Server-side special

- A topmost clicked selection named `resetgame` is intercepted by the server.
- It deletes `data/scriptState.json`, clears transient popup/click state, and reloads the first room.
- It does **not** need to be handled in the click script.

## Related files and locations

- `data/clickscript.js`
  - The live click script executed by the server sandbox for room clicks and popup clicks.

- `data/scriptState.json`
  - Persistent JSON state automatically exposed as `state`, `gameState`, and `scriptState`.

- `data/rooms.json`
  - Canonical room database containing rooms, slides, selections, descriptions, visibility flags, and image-selection file references.

- `data/rooms/<roomId>/slide-*.vbxe`
  - Per-room VBXE background image files used by the Atari client.

- `data/rooms/<roomId>/selection-*.png`
  - Stored PNG fragment for an image selection, mainly used by the web editor preview.

- `data/rooms/<roomId>/selection-*.vbxe`
  - Stored VBXE patch for an image selection, used by in-game `replaceGraphics(...)`.

- `data/selections.json`
  - Legacy export file that has been removed. It is no longer used by the server or client.

- `server/server.js`
  - Main server implementation containing the click-script sandbox helpers, popup behavior, special server-side actions, and HTTP routes.

- `docs/click-script-reference.md`
  - Human-readable Markdown reference.

- `docs/click-script-reference.json`
  - Structured JSON reference used by the built-in Script help popup in the web editor.

## Examples

### Show the clicked selection name

    const hit = roomSelections.find((selection) => {
      return x >= selection.x && x < selection.x + selection.width && y >= selection.y && y < selection.y + selection.height;
    });
    if (hit) return displayText(hit.name);
    return null;

### Clickable popup choices

    if (clickType === 'popup') {
      if (clickedChoice === 'flower') return replaceGraphics('flower');
      if (clickedChoice === 'wine') return replaceGraphics('wine');
    }
    return displayChoices([
      choice('flower', 'GIVE FLOWER'),
      choice('wine', 'GIVE WINE')
    ]);

### Change room

    if (roomName === 'first' && x < 20 && y < 20) {
      return changeRoom('room2');
    }
    return null;

### Draw then restore an image selection

    if (!state.lampOn) {
      state.lampOn = true;
      return replaceGraphics('lamp_on');
    }
    state.lampOn = false;
    return originalGraphics('lamp_on');