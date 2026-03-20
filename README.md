# VBXE Web Browser for Atari XE/XL

80-column web browser for Atari 8-bit computers with VBXE graphics expansion.

## Status

**Alpha** - early development, not fully functional yet. Help is welcome!

## Requirements

- Atari XE/XL (or emulator like [Altirra](https://www.virtualdub.org/altirra.html))
- [VBXE](http://lotharek.pl/productdetail.php?id=46) (VideoBoard XE)
- [FujiNet](https://fujinet.online/) or Atari 850 Interface Module

## Features

- 80-column text display using VBXE overlay mode
- HTML parser: headings, links, lists, bold, entities
- URL navigation with history
- Dual network support: FujiNet (N:) and 850 Interface Module (R:)

## Building

Requires [MADS](https://github.com/tebe6502/Mad-Assembler) assembler.

```
mads src/browser.asm -o:bin/browser.xex
```

## License

MIT
