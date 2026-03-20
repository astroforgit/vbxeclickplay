# VBXE Web Browser for Atari XE/XL

80-column web browser for Atari 8-bit computers with VBXE graphics expansion.

## Requirements

- Atari XE/XL (or emulator like [Altirra](https://www.virtualdub.org/altirra.html))
- [VBXE](http://lotharek.pl/productdetail.php?id=46) (VideoBoard XE) expansion
- Network device (one of):
  - **FujiNet** - WiFi multi-peripheral with built-in HTTP support
  - **Atari 850 Interface Module** - RS-232 serial with modem/proxy

## Features

- 80-column text display using VBXE overlay mode
- HTML parser: headings, links, lists, bold, entities
- URL bar, status bar, page title
- Link navigation (press 0-9 for link number)
- History with back navigation
- Dual network support: FujiNet (N:) and 850 (R:)

## Building

Requires [MADS](https://github.com/tebe6502/Mad-Assembler) (Mad Assembler).

```
mads src/browser.asm -o:bin/browser.xex
```

Note: On Windows, pipe through `| cat` to see error messages.

## Running

### FujiNet mode

1. Boot `browser.xex` directly (File > Boot Image in Altirra)
2. Press **F** at device selection
3. Press **U** to enter URL

### 850 Interface Module mode

1. Boot from ATR disk image (`bin/browser.atr`) with MyDOS
2. Load `ATARI850.HND` first (loads R: handler from 850 hardware)
3. Load `BROWSER.XEX`
4. Press **M** at device selection
5. Press **U** to enter URL

The 850 mode requires a proxy server on the host machine that accepts
serial connections, fetches HTTP pages, and relays HTML back to the Atari.

## Keyboard

| Key | Action |
|-----|--------|
| U | Enter URL |
| B | Back (history) |
| 0-9 | Follow link |
| Q | Quit |

## Files

```
src/
  browser.asm      - Main program, entry point
  vbxe_const.asm   - VBXE constants, system equates, macros
  vbxe_detect.asm  - VBXE hardware detection
  vbxe_init.asm    - VBXE initialization (XDL, palette, font)
  vbxe_text.asm    - 80-column text rendering
  fujinet.asm      - FujiNet N: device SIO layer
  modem850.asm     - Atari 850 R: handler CIO layer
  network.asm      - Network abstraction (FujiNet/850 dispatch)
  http.asm         - HTTP GET workflow
  html_parser.asm  - HTML tag/entity parser
  renderer.asm     - Text layout and word wrapping
  keyboard.asm     - Keyboard input via CIO K: device
  ui.asm           - UI: URL bar, status bar, navigation
  history.asm      - URL history stack
  data.asm         - Buffers and string data
bin/
  disk/            - ATR disk contents (DOS, handler, browser)
Build/
  build.sh         - Build script
```

## Credits

Built with [MADS](https://github.com/tebe6502/Mad-Assembler) assembler.
850 handler approach based on [Ice-T](https://github.com/ivop/Ice-T-XE) terminal emulator by Itay Chamiel.

## License

MIT
