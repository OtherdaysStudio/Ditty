# Ditty — App Review Reply (Build 12, v1.1)

Paste the body below into the App Review **Notes** field (and the
"Reply" thread on the rejection). Every numbered item from Apple's 2.1
request is answered.

---

Hi App Review team,

Thanks for the careful look. Below is everything you asked for. We've
also added these details to the App Review Information / Notes field
in App Store Connect for future submissions.

## 1. Screen recording

A screen recording captured on a physical iPhone running iOS 18.2 is
attached to this reply. It begins with launching Ditty and walks
through the full first-run flow:

- Cold launch → splash → first-run onboarding cards (4 cards, swipe to
  advance, Skip available)
- Camera permission prompt (NSCameraUsageDescription) — granted
- Live camera feed dithered as a Game Boy in real time
- Swipe through several built-in retro systems (NES, C-64 Multicolor,
  ZX Spectrum); long-press the photo to open the searchable system
  picker
- Tap **FX** to open the inline effect editor; scrub diffuse and
  diversity sliders, switch dither kernel, apply a custom palette
  preset
- Tap-to-focus and pinch-to-zoom on the live preview
- Tap the shutter to capture a still; choose an export aspect; image
  is saved to Photos (NSPhotoLibraryAddUsageDescription) and the
  share sheet appears
- Press-and-hold the shutter to record a 3-second animated GIF; share
  sheet hands off the GIF
- Long-press the FX button to capture a 5-frame burst contact sheet
- Open Settings (top-right): toggle save-original, watermark, etc.;
  view the per-system preset list
- Open the Pro paywall, tap Restore Purchases (StoreKit; no purchase
  is completed in the recording)

## 2. Devices and OS versions tested

- **Primary physical test device:** iPhone 16 Pro, iOS 18.2
- **Additional physical devices:** iPhone 14, iOS 17.6
- **Simulators:** iPhone 17 Pro (iOS 26.4) and iPad Pro 13" M5
  (iPadOS 26.4) for layout verification
- **Minimum supported OS:** iOS 16.0 (declared in the Info.plist)

## 3. App purpose, audience, problem, and value

Ditty is a real-time camera app that re-renders whatever your phone's
camera sees as if it were running on a vintage console — Game Boy,
NES, Commodore 64, ZX Spectrum, Amiga, Atari ST, and 40+ more. Each
system is reproduced authentically: native pixel grid, native palette,
native attribute-clash constraints (cell-based color limits on the
C-64, ZX, NES, etc.). The static-photo path runs to convergence; the
live path runs one engine iteration per camera frame.

**Target audience:** retro-computing and pixel-art enthusiasts;
photographers exploring stylised output; anyone who grew up with these
machines and wants their everyday photos to look like the games they
played.

**Problem solved:** existing "8-bit filter" apps fake the look with
generic lookup tables. Ditty actually performs the system-correct
dithering algorithms (Floyd-Steinberg, Atkinson, ordered Bayer, etc.)
inside each system's hardware constraints, so the output is what the
original hardware would have produced.

**Value:** indistinguishable-from-emulator-grade retro output, free
for four classic systems, optional one-time Pro purchase to unlock the
remaining 40+. No subscriptions. No accounts. No data collection.

## 4. Setup, login, and sample content

- **No account or login is required.** All core features are
  available immediately on first launch.
- **No demo credentials required** — there is no sign-in flow at all.
- The first-run onboarding (4 cards) can be skipped via the **Skip**
  button in the top-right.
- **Sample image without granting camera access:** if camera access is
  denied, the empty viewport shows an **Upload** button (PHPicker;
  read-only photo selection, no library write permission needed at
  pick time) and a **Samples** button that opens a small bundled
  library of curated images. This lets reviewers exercise every
  feature without granting any permissions.
- **Free vs. Pro:** four systems are free (Game Boy, NES, C-64
  Multicolor, ZX Spectrum). Pro is a single one-time non-consumable
  IAP (`studio.otherdays.ditty.pro`) that unlocks every other system.
  No subscriptions.

## 5. External services and dependencies

Ditty does **not** use any external services for its core
functionality. Specifically:

- **No remote API.** The dithering engine, palette reduction, smart
  crop, and GIF encoder all run fully on-device.
- **No analytics SDKs.** No Firebase, Mixpanel, Sentry, or comparable.
- **No authentication providers.** There is no account system.
- **No AI services.** Smart-crop uses Apple's on-device Vision
  framework (`VNGenerateAttentionBasedSaliencyImageRequest`); no
  network calls.
- **No third-party data providers.**
- **Apple StoreKit 2** handles the single non-consumable Pro purchase.
  No third-party payment processor.

The only third-party Swift Package dependency is **Lottie**
([airbnb/lottie-ios](https://github.com/airbnb/lottie-ios), MIT
licensed), used solely to play a small bundled splash animation —
zero network calls, no telemetry.

## 6. Regional differences

Ditty's features and content are identical across all regions. The
only regionally-conditioned behavior is that on iOS, the system
camera-shutter sound (`AudioServicesPlaySystemSound(1108)`) is played
when "Shutter sound" is enabled in Settings. Per Apple's audio session
documentation, this sound is mandatory in Japan and South Korea
regardless of the device's silent switch. Outside those regions the
sound is suppressed by the silent switch (we use an `.ambient` audio
session category to make this explicit). All other features are
identical worldwide.

## 7. Regulated industry / protected material

Ditty does not operate in a regulated industry, does not handle
medical, financial, or government-issued identity data, does not
target children specifically, and does not include any protected
third-party material.

The names of historical computing systems (Game Boy, NES, Commodore
64, ZX Spectrum, etc.) are referenced descriptively to identify the
visual style being reproduced. No copyrighted artwork, ROMs,
trademarks, or assets from any of these systems are bundled or
displayed. The dithering algorithm is original Swift code, ported
from the open-source [dithertron](https://github.com/sehugg/dithertron)
project (MIT licensed).

## Purpose strings (Info.plist)

For reference, our purpose strings are:

- `NSCameraUsageDescription`: "Ditty uses your camera to apply retro
  dithering effects in real time."
- `NSPhotoLibraryUsageDescription`: "Ditty needs access to your photo
  library to dither your photos."
- `NSPhotoLibraryAddUsageDescription`: "Ditty saves your dithered
  creation to your photo library."

Each describes the specific feature requesting access; we use only
PHPickerViewController (no read entitlement required at pick) and
`UIImageWriteToSavedPhotosAlbum` for save (covered by the Add string).

## Encryption export compliance

Build 12+ has `ITSAppUsesNonExemptEncryption = false` in Info.plist.
Ditty uses only Apple's stock cryptography (StoreKit, NSURLSession
HTTPS); no third-party crypto libraries; no proprietary algorithms.

## Contact

Any follow-up questions, please reach me directly at
**lovish@otherdays.studio**. I can usually reply same-day.

Thank you,
Lovish — Otherdays Studio

---

# Screen-recording shot list (≈75 seconds)

Record on a physical iPhone with iOS Screen Recording (Control Centre).
Hold camera over a colorful object so the dither output is visually
interesting.

| Time | Action |
|---|---|
| 0:00 | Tap Ditty icon → splash plays for ~2s |
| 0:02 | Onboarding card 1 visible → swipe through cards 2, 3, 4 → tap **Start dithering** |
| 0:10 | Camera permission alert → tap **Allow** |
| 0:12 | Live Game Boy dithering of whatever's in front of camera. Hold the phone over a colorful subject. |
| 0:18 | Swipe right on photo → NES → swipe right → C-64 Multicolor |
| 0:24 | Long-press the photo → searchable picker opens → tap **ZX Spectrum** |
| 0:30 | Tap **FX** → scrub the diffuse slider → tap **Diversity** pill → scrub → tap **Palette** → apply the **Sunset** preset → tap ✓ |
| 0:46 | Two-finger pinch on the photo → zoom in to ~2× |
| 0:50 | Tap once on the photo → yellow focus ring appears |
| 0:53 | Tap shutter → flash + sound → save dialog → tap **Square (1:1)** → photo saved → share sheet appears → tap **Cancel** |
| 1:02 | Press and hold shutter → red ring fills as it records → release after 3s → share sheet for the GIF → tap **Cancel** |
| 1:10 | Tap the gear icon (top-right) → Settings opens → scroll to **Watermark** and **Per-system presets** sections → tap close |
| 1:18 | Tap **Get Ditty Pro** (within Settings) → paywall appears → tap **Restore Purchases** → tap close |
| 1:25 | Stop recording |

Save as `.mov` or `.mp4` and upload to the rejection reply in App
Store Connect (or attach to the Notes field as a link).

# How to upload the reply in App Store Connect

1. App Store Connect → **My Apps** → **Ditty** → the rejected version
2. **App Review** tab on the left → scroll to the rejection message
3. Click **Reply**
4. Paste the body above (Sections 1–7) into the message field
5. Click **Add Files** → attach the screen recording
6. Click **Send**

Also, copy Sections 1–7 into **App Review Information → Notes** so
future submissions don't trigger the same request.
