# Ditty

Live retro photo dithering for iOS — Game Boy, NES, ZX Spectrum, C-64,
Apple ][, Atari, and 40+ more vintage systems, in real time, from your
camera.

A Swift port of the open-source [dithertron](https://github.com/sehugg/dithertron)
project, repackaged as a native iPhone app.

## Project layout

```
.
├── Ditty/                   ← the Xcode project root (regenerated with xcodegen)
│   ├── Ditty/               ← Swift sources
│   │   ├── Engine/          ← dither engine port (system canvases, kernels, palettes)
│   │   ├── UI/              ← SwiftUI surface (camera, FX editor, paywall, settings)
│   │   └── Resources/       ← assets, splash JSON, sample image
│   ├── DittyTests/          ← engine unit tests (XCTest)
│   ├── DittyUITests/        ← UI smoke tests (XCUITest)
│   ├── project.yml          ← XcodeGen project spec (canonical)
│   └── Ditty.storekit       ← local StoreKit config for testing IAP
├── Icons/                   ← source SVGs for the app's UI icons
├── ditty.png                ← source 2000×2000 app icon
├── PRIVACY.md               ← App Store privacy policy
├── TERMS.md                 ← App Store terms of service
└── AppStore.md              ← App Store Connect metadata draft
```

## Getting started

```sh
brew install xcodegen
cd Ditty
xcodegen generate
open Ditty.xcodeproj
```

## Architecture notes

- **Engine**: pure Swift port. Public entry point is `Dithertron`. Each retro
  system is a `DithertronSettings` (in `Engine/Systems.swift`) plus an
  optional specialised canvas under `Engine/Systems/`.
- **Camera**: `CameraSession` wraps `AVCaptureSession`; publishes both a
  downscaled preview frame for the dither pipeline and a full-resolution
  copy for "Save original" / capture.
- **Generation cancel**: viewmodel's `generation` counter is bumped whenever
  the user changes a parameter. In-flight engine iterations bail on their
  next check, so system switches feel instant.
- **Closest-color memo**: per-iteration RGB→index cache in
  `BaseDitheringCanvas` skips redundant lookups when the palette is fully
  available (the common free-palette case).
- **Pixel-exact passthrough**: if every source pixel is already a palette
  color, the engine skips Floyd-Steinberg and just maps directly.
- **Smart crop**: `ImageBridge.smartCropCenter` uses Vision's
  attention-based saliency to pick the centroid of the most interesting
  region in the source.

## In-app purchase

`studio.otherdays.ditty.pro` — single non-consumable, $4.99, unlocks every
non-free system. Free tier ships Game Boy, NES, C-64 Multicolor, ZX
Spectrum.

## Privacy

No accounts, no servers, no analytics. Camera frames and photos are
processed entirely on device. See `PRIVACY.md`.

## License

The Swift port and iOS app are © Other Days Studio. The dithering algorithm
ports are derived from sehugg's MIT-licensed dithertron (see upstream for
full credits).
