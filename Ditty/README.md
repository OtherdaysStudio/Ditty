# Ditty

iOS port of [dithertron](https://github.com/sehugg/dithertron) — converts photos into authentic retro-computer dithered images, faithfully reproducing the cell-based palette constraints of the C64, ZX Spectrum, NES, Apple II, MSX, Game Boy, PICO-8, and dozens more.

## Run it

```bash
brew install xcodegen          # if not already
cd Ditty
xcodegen generate              # regenerates the .xcodeproj
open Ditty.xcodeproj
```

Press ⌘R. Choose a photo. Pick a system. Watch it dither in real time.

### From the command line

```bash
xcodebuild -project Ditty.xcodeproj -scheme Ditty \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build

# Run the full engine test suite (4 tests + render dump to /tmp/ditty-render)
xcodebuild -project Ditty.xcodeproj -scheme Ditty \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

## What's faithful

Every algorithm from the upstream TypeScript engine is ported, not approximated:

- Iterative cell-aware dithering with per-cell palette guess + error diffusion
- Twelve dither kernels — Floyd-Steinberg, Atkinson, Sierra, Stucki, etc.
- Four error metrics — perceptual, hue-only, absolute, max-channel
- Palette reduction via k-means-on-palette-subset (`reducePaletteChoices`)
- Cell-constrained canvases:
  - **VIC-II** (C64 hires + multicolor, with full FLI mode + bug emulation + blanking)
  - **ZX Spectrum** (8x8 attribute cells, brightness-half constraint, palette swapping)
  - **Apple II hires** (7-pixel groups with hibit-selected color set)
  - **NES** (16x16 attribute tiles, 4-of-5 colors per tile)
  - **MSX/TMS9918A** (8x1 cells, 2 colors)
  - **Compucolor**, **Teletext**, **VCS color playfield**
  - **HAM6** (Amiga hold-and-modify with delta channels)
- Free-palette canvas for everything else (Game Boy, PICO-8, Atari ST, EGA, etc.)
- 40+ system presets matching the originals' resolution, aspect ratio, palette range

## Project layout

```
Ditty/
├── Engine/                 # pure-Swift dithering engine, no UIKit deps in core
│   ├── Color.swift            # error functions, palette reduction
│   ├── Kernels.swift          # 12 dither kernels
│   ├── Types.swift            # DithertronSettings, BlockSpec, etc.
│   ├── BaseDitheringCanvas.swift
│   ├── BlockParamDitherCanvas.swift  # cell-aware base
│   ├── TwoColorCanvas.swift   # Apple II / Compucolor / Teletext base
│   ├── Palettes.swift         # 30+ retro palettes
│   ├── Systems.swift          # 40+ system presets
│   ├── Dithertron.swift       # iterative driver
│   ├── ImageBridge.swift      # UIImage <-> [UInt32] pipeline
│   └── Systems/
│       ├── VICIICanvas.swift     # C64
│       ├── ZXSpectrumCanvas.swift
│       └── SimpleCanvases.swift  # MSX, SNES, HAM6, etc.
├── UI/
│   ├── DittyApp.swift         # @main entry
│   ├── ContentView.swift      # main layout + system picker + settings sheet
│   ├── DittyViewModel.swift   # background engine driver
│   └── PhotoPicker.swift      # PHPickerViewController bridge
├── Resources/
│   ├── Assets.xcassets        # AppIcon + AccentColor
│   └── Sample.bundle/         # parrot.jpg used by tests
└── Info.plist
```

## Tests

`DittyTests/EngineTests.swift` includes four engine validations that run on every build:

- Loads all 40+ system presets without crashing
- PICO-8 free-palette dithering converges within 100 iterations and produces only valid palette indices
- C64 multicolor enforces ≤4 distinct palette indices per 4x8 block
- ZX Spectrum enforces ≤2 distinct palette indices per 8x8 cell **and** that both share the same brightness half (the iconic "attribute clash" rule)

There's also `testRendersDitheredImagesForVisualInspection` which dumps a PNG per system to `/tmp/ditty-render/` for eyeballing.

## Settings exposed in the UI

- **Dither kernel** — Floyd-Steinberg (default), Atkinson, Stucki, Sierra, etc.
- **Diffuse** (0–1.5) — error diffusion strength
- **Ordered** (0–1) — adds 4x4 Bayer threshold modulation
- **Noise** (0–8) — bit-shifted noise to break up histogram ties
- **Palette diversity** (0–2) — biases the k-means reducer toward varied colors

## Acknowledgments

All of the algorithm work is the upstream [dithertron](https://github.com/sehugg/dithertron) by Steven Hugg, ported here line-for-line.
