# VBXE Web Browser for Atari XE/XL

80-column web browser for Atari 8-bit computers with VBXE graphics expansion.

![screenshot](https://img.shields.io/badge/status-alpha-orange)

## Status

**Alpha** - early development, not fully functional yet. Help is welcome!

## Requirements

- Atari 800XL/130XE or compatible (64KB RAM minimum)
- [VBXE](http://lotharek.pl/productdetail.php?id=46) (VideoBoard XE) - FX core v1.2x
- Network device (one of):
  - [FujiNet](https://fujinet.online/) - WiFi multi-peripheral with HTTP support
  - Atari 850 Interface Module - RS-232 serial port
- Emulator: [Altirra](https://www.virtualdub.org/altirra.html) with VBXE + FujiNet-PC or 850

## Features

- **VBXE 80-column text** using overlay mode with color attributes
- **HTML parser**: headings (h1-h3), links, lists (ul/ol), bold, italic, entities
- **Image support** (infrastructure ready): mixed TMON/GMON XDL for inline images
- **URL navigation** with address bar input
- **History** with back navigation
- **Link following** - press 0-9 to follow numbered links
- **Dual network**: FujiNet N: device (SIO) or 850 R: handler (CIO)
- **Error display**: shows network errors (DNS, timeout) instead of silent fail

## VBXE Display

The browser uses VBXE overlay in text mode (TMON) for 80-column display:

- 80x24 character grid with per-character color attributes
- 7 colors: white (text), blue (links), orange (headings), green (URL bar), red (errors), gray (decorative), yellow (status/highlighted links)
- Font stored in VBXE VRAM ($2000)
- XDL supports mixed text + graphics mode for future inline image display
- 512KB VRAM available (~500KB free for image storage)

## Network Modes

### FujiNet (F)

Uses FujiNet N: device for direct HTTP via SIO. FujiNet handles DNS, TCP/IP and HTTP protocol internally.

Boot browser XEX directly and select F at startup.

### 850 Interface Module (M)

Uses R: handler for serial communication via CIO. Requires external HTTP server/proxy on the other end of the serial connection.

Boot from ATR disk image:
1. Load `ATARI850.HND` (downloads R: handler from 850 hardware)
2. Load `BROWSER.XEX`
3. Select M at startup

## Keyboard

| Key | Action |
|-----|--------|
| **U** | Enter URL |
| **B** | Back (history) |
| **0-9** | Follow link number |
| **Q** | Quit |

## Building

Requires [MADS](https://github.com/tebe6502/Mad-Assembler) (Mad Assembler).

```bash
mads src/browser.asm -o:bin/browser.xex
```

For ATR disk image (requires dir2atr and MyDOS):

```bash
dir2atr -m -b MyDos4534 720 bin/browser.atr bin/disk
```

## Source Files

| File | Description |
|------|-------------|
| `browser.asm` | Main program, entry point |
| `vbxe_const.asm` | VBXE registers, system equates, ZP variables, macros |
| `vbxe_detect.asm` | VBXE hardware detection |
| `vbxe_init.asm` | VBXE initialization (XDL, palette, font, blitter) |
| `vbxe_text.asm` | 80-column text rendering engine |
| `vbxe_gfx.asm` | Graphics mode for inline images (GMON, palette, pixel streaming) |
| `fujinet.asm` | FujiNet N: device SIO layer |
| `modem850.asm` | Atari 850 R: handler CIO layer |
| `network.asm` | Network abstraction (FujiNet/850 dispatch) |
| `http.asm` | HTTP GET workflow, URL prefix handling |
| `html_parser.asm` | Streaming HTML tag/entity parser |
| `renderer.asm` | Text layout, word wrapping, scrolling |
| `keyboard.asm` | Keyboard input via CIO K: device |
| `ui.asm` | UI: URL bar, status bar, error display |
| `history.asm` | URL history stack (16 entries) |
| `data.asm` | Buffers and string data |

## Credits

- [MADS](https://github.com/tebe6502/Mad-Assembler) assembler by Tomasz Biela
- 850 handler approach based on [Ice-T XE](https://github.com/ivop/Ice-T-XE) by Itay Chamiel
- VBXE graphics mode reference from [st2vbxe](https://github.com/pfusik/st2vbxe) by Piotr Fusik

## License

MIT
