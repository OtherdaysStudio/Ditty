# Ditty — App Store metadata

Drop-in copy for App Store Connect. All character counts checked against
Apple's limits.

## Name (30 char max)

```
Ditty — Retro Photo Dither
```

(28 chars)

## Subtitle (30 char max)

```
Game Boy, C-64, NES camera FX
```

(29 chars)

## Promotional text (170 char max — editable without re-review)

```
Bring your photos back to 1986. Live retro dithering for the Game Boy, NES, ZX Spectrum, C-64, Apple //, Atari, and 40+ more vintage systems — straight from your camera.
```

(170 chars)

## Description (4000 char max)

```
Ditty turns your iPhone into a working retro display. Every frame from your
camera is re-dithered live, in real time, into the actual color palette and
pixel grid of a vintage system — Game Boy, NES, ZX Spectrum, Commodore 64,
Apple ][, Atari, Amiga, and 40+ more.

It is the kind of thing you'd expect to need a real CRT, a frame grabber, and
a weekend to set up. Instead it just works.

WHAT YOU GET
• Live retro camera. Tap the shutter to freeze a frame, or pick a photo from
  your library — Ditty re-dithers it the same way.
• 40+ retro systems, faithfully ported from the open-source dithertron
  project: Game Boy, NES, C-64, ZX Spectrum, Atari ST/VCS, Apple ][, MSX,
  Amiga HAM6, IIGS, Amstrad CPC, BBC Micro, EGA, CGA, Mac 128K, Pico-8,
  TIC-80, and a whole shelf of arcade and 8-bit oddities.
• Pixel-perfect dithering. Floyd-Steinberg, Atkinson, Stucki, Sierra,
  ordered, and more — pick the kernel that suits the look you're after.
• Smart crop. Vision-powered saliency picks the most interesting part of the
  shot for systems that don't share your photo's aspect ratio. Or recompose
  by hand with the crop sheet.
• Export at any aspect. Square, 4:5, 4:6, 9:16, 16:9, 3:2, or original —
  centre-cropped, no padding bars.
• Save originals too. Optional — keep both the dithered and un-dithered
  shot.
• Custom palettes. Apply curated retro palettes (Sunset, Forest, Cyberpunk,
  Sepia, Pastel, plus the original system palettes) or stick with each
  system's native lookup.
• 30 fps live preview on modern iPhones, with self-throttling for older
  devices.

DITTY PRO
The free tier ships Game Boy, NES, C-64 Multicolor, and ZX Spectrum so you
can try the look before you buy. Ditty Pro is a single one-time purchase —
no subscription, ever — and unlocks every system on every device signed in
to your Apple ID.

ABOUT
Ditty is a love letter to chunky pixels and bad CRTs. Built in Swift on top
of the open-source dithertron project. No accounts, no servers, no ads, no
trackers. Photos and camera frames never leave your device.

Privacy: github.com/OtherdaysStudio/Ditty/blob/main/Ditty/PRIVACY.md
Terms: github.com/OtherdaysStudio/Ditty/blob/main/Ditty/TERMS.md
Support: lovish@otherdays.studio
```

## Keywords (100 char max, comma-separated)

```
dither,retro,gameboy,nes,c64,zxspectrum,pixelart,filter,camera,8bit,vintage,palette,oldschool
```

(94 chars — leave room to add more if Apple rejects any)

## Category

- Primary: **Photo & Video**
- Secondary: **Graphics & Design**

## Age rating

4+ (no objectionable content; user-supplied photos may contain anything but
the app's own content is family-safe)

## Support / Marketing URL

- Support URL: `mailto:lovish@otherdays.studio` (or a future page on otherdays.studio)
- Marketing URL: `https://github.com/OtherdaysStudio/Ditty`
- Privacy Policy URL: `https://github.com/OtherdaysStudio/Ditty/blob/main/Ditty/PRIVACY.md`
- Terms (EULA) URL: `https://github.com/OtherdaysStudio/Ditty/blob/main/Ditty/TERMS.md`

## In-app purchase to register

| Field | Value |
|---|---|
| Reference name | Ditty Pro |
| Product ID | `studio.otherdays.ditty.pro` |
| Type | Non-Consumable |
| Price tier | $4.99 (Tier 5) |
| Display name (en-US) | Ditty Pro |
| Description (en-US) | Unlock every retro system: Apple ][, Atari ST, Amstrad CPC, MSX, PICO-8, TIC-80, all C-64 FLI variants, and more. |

## Reviewer notes (App Review)

```
Ditty is a self-contained on-device photo app with one in-app purchase
(Ditty Pro, $4.99 non-consumable) that unlocks the rest of the retro
systems beyond the four free ones (Game Boy, NES, C-64 Multicolor, ZX
Spectrum). The app does not require an account or a network connection.

To test:
1. Launch the app and grant camera + photo library access. (If running on
   simulator, the app shows "No camera feed — tap the gallery icon" and you
   can tap the gallery icon to import a photo for testing.)
2. Long-press the centre photo area to jump to any system in the catalog.
3. Tap "FX" (bottom left) to adjust diffusion / ordered / kernel /
   diversity inline.
4. Tap the centre shutter to capture; tap "Save" (now showing the download
   icon) to export at any aspect ratio.
5. To verify Pro: tap any locked (lock-badged) system, then tap Get Pro in
   the resulting paywall. Restore Purchases lives in Settings (top-right).

Camera errors with codes -12710 / -17281 are AVFoundation log noise from
iOS 26 simulators with no host webcam — they don't surface as runtime
issues.
```

## Privacy nutrition labels

Data collected: **None**.

If asked for "Data Used to Track You", select **None**.
If asked for "Data Linked to You", select **None**.
If asked for "Data Not Linked to You", select **None**.

(Photos and camera input are processed on device only; we do not use any
analytics, advertising, or crash-reporting SDKs.)
