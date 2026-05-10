# Ditty — App Review Reply (Build 12, v1.1)

The block below the line is **3,830 characters**, under the ASC 4,000
limit. Paste it into the rejection Reply, attach the screen recording,
and also paste it into App Review Information → Notes for future
submissions.

---

Thanks for the review. Answers to all 7 points below; screen recording is attached.

1) SCREEN RECORDING. Captured on iPhone 16 Pro, iOS 18.2. Shows: cold launch, splash, 4-card onboarding, camera permission prompt, live Game Boy dither, swipe through NES / C-64 / ZX Spectrum, long-press for searchable picker, FX panel (diffuse, diversity, kernel, palette presets), tap-to-focus, pinch-to-zoom, tap-shutter capture, save-to-Photos + share sheet, hold-shutter for 3s GIF record, long-press FX for burst contact sheet, Settings (watermark, per-system preset list), Pro paywall + Restore Purchases. No purchase is completed.

2) DEVICES TESTED. iPhone 16 Pro (iOS 18.2), iPhone 14 (iOS 17.6), iPhone 17 Pro simulator (iOS 26.4), iPad Pro 13" M5 simulator (iPadOS 26.4). Minimum supported: iOS 16.0.

3) PURPOSE / AUDIENCE / VALUE. Ditty is a real-time camera app that re-renders whatever the camera sees as if it were running on a vintage console — Game Boy, NES, C-64, ZX Spectrum, Amiga, Atari ST, and 40+ more. Each system is reproduced authentically: native pixel grid, native palette, native attribute-clash constraints. Audience: retro-computing and pixel-art enthusiasts, photographers, anyone who grew up with these machines. Most "8-bit filter" apps fake the look with lookup tables; Ditty performs the system-correct dithering algorithms (Floyd-Steinberg, Atkinson, ordered Bayer) inside each system's hardware constraints, so the output is what the original hardware would have produced. Free for four classic systems; one-time Pro IAP unlocks the remaining 40+. No subscriptions, no accounts, no data collection.

4) SETUP / LOGIN. No account, no login, no demo credentials. Onboarding can be skipped via top-right Skip. To exercise every feature without granting camera access: deny the camera prompt, then tap **Samples** in the empty viewport to load a bundled image. Pro IAP id: studio.otherdays.ditty.pro (one-time non-consumable). Restore via Settings → Restore Purchases.

5) EXTERNAL SERVICES. None for core functionality. The dithering engine, palette reduction, smart crop, and GIF encoder all run on-device. No analytics SDKs (no Firebase / Mixpanel / Sentry). No authentication providers. No AI services — smart crop uses Apple's on-device Vision framework only. No third-party data providers. No third-party payment processor; Pro uses Apple StoreKit 2. Only third-party SPM dependency is Lottie (airbnb/lottie-ios, MIT) for a bundled splash animation; zero network calls, zero telemetry.

6) REGIONAL DIFFERENCES. Features identical worldwide. Only regionally-conditioned behavior is the system camera-shutter sound (AudioServicesPlaySystemSound 1108) which iOS plays unconditionally in Japan and South Korea per Apple's audio session policy; elsewhere it's suppressed by the silent switch (we use an .ambient session category).

7) REGULATED INDUSTRY / PROTECTED MATERIAL. None. Doesn't handle medical, financial, or government-issued identity data; doesn't target children specifically; doesn't bundle copyrighted artwork, ROMs, trademarks, or assets from any referenced system. System names (Game Boy, NES, etc.) are used descriptively. Dithering algorithm is original Swift code ported from the open-source dithertron project (MIT licensed). Build 12 has ITSAppUsesNonExemptEncryption=false; only stock Apple cryptography is used.

Contact: lovish@otherdays.studio. Same-day reply on follow-ups.

— Lovish, Otherdays Studio

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
