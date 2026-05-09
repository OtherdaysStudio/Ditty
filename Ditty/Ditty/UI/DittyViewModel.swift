import Foundation
import UIKit
import SwiftUI
import Combine

@MainActor
final class DittyViewModel: ObservableObject {

    /// Source of the next dither. In live mode this is the latest camera frame;
    /// otherwise it's whatever the user picked from Photos.
    @Published var sourceImage: UIImage? = nil
    @Published var systemId: String = "gb" {
        didSet {
            // System switch is the most disruptive change — clear the preview
            // so the user sees instant feedback instead of the old system's
            // dither lingering while the new one converges.
            invalidate(clearPreview: true)
        }
    }
    @Published var ditherKernelId: String = "floyd" { didSet { invalidate() } }
    @Published var diffuse: Double = 0.8 { didSet { invalidate() } }
    @Published var ordered: Double = 0.0 { didSet { invalidate() } }
    @Published var noise: Int = 0 { didSet { invalidate() } }
    /// Diversity defaults to 1.0 across every system — empirically the value
    /// where reduced palettes spread enough to keep highlights, midtones and
    /// shadows visually distinct. Users can still scrub it from 0…2 in the
    /// FX editor.
    @Published var paletteDiversity: Double = 1.0 { didSet { invalidate() } }

    /// Bump the engine generation so any in-flight iteration on the work
    /// queue bails on its next check, free the live-busy flag so the next
    /// camera frame can start dithering, and kick off a new render.
    private func invalidate(clearPreview: Bool = false) {
        generation &+= 1
        liveBusy = false
        // The cached palette becomes stale whenever any param affecting
        // reduce changes (system / kernel won't help it but diversity
        // would). Clearing here is the simplest correct invalidation.
        liveCachedPalette.removeAll(keepingCapacity: true)
        if clearPreview {
            previewImage = nil
            iterationCount = 0
            isFinal = false
        }
        restartIfReady()
    }

    /// Set true when consuming live camera frames; false for the static-photo flow.
    @Published var liveMode: Bool = true
    /// True after the user taps the shutter — we freeze the current dithered image.
    @Published private(set) var captured: Bool = false

    /// When true, the dither canvas matches the source image's aspect (so
    /// portrait phone photos render portrait). When false, each system's native
    /// canvas dimensions are used (the original hardware aspect).
    var respectImageRatio: Bool = true {
        didSet { restartIfReady() }
    }

    /// User-defined crop window in normalized source coords (0…1, top-left
    /// origin). nil = let `ImageBridge` use saliency-based smart crop.
    @Published var cropRect: CGRect? = nil {
        didSet { restartIfReady() }
    }

    /// User-defined palette overriding the system's default. Setting this to
    /// nil falls back to the system's pal / reduce pipeline.
    @Published var customPalette: [UInt32]? = nil {
        didSet { restartIfReady() }
    }

    /// Replace one swatch in the custom palette. Initializes the custom
    /// palette from the active one on first edit.
    func setCustomPaletteColor(_ index: Int, rgb: UInt32) {
        var pal = customPalette ?? activePalette
        guard index >= 0, index < pal.count else { return }
        pal[index] = rgb & 0x00ffffff
        customPalette = pal
    }

    /// Drop the custom palette and return to the system default.
    func resetCustomPalette() {
        customPalette = nil
    }

    @Published private(set) var previewImage: UIImage? = nil
    @Published private(set) var iterationCount: Int = 0
    @Published private(set) var isFinal: Bool = false
    @Published private(set) var canvasWidth: Int = 0
    @Published private(set) var canvasHeight: Int = 0
    @Published private(set) var canvasScaleX: Double = 1.0
    /// Palette of the most recent dither — exposed so the FX editor can show
    /// swatches. RGB values, 0xRRGGBB style (alpha stripped at the boundary).
    @Published private(set) var activePalette: [UInt32] = []

    let systems: [DithertronSettings] = Systems.all
    let kernels: [DitherSettingDef] = DitherKernels.all

    private var dithertron = Dithertron()
    private let workQueue = DispatchQueue(label: "ditty.engine", qos: .userInitiated)
    private var workItem: DispatchWorkItem?

    /// Set true while a live frame is mid-flight so we drop incoming frames
    /// instead of queueing them — keeps latency low.
    private var liveBusy: Bool = false

    /// Bumped whenever the user changes the system / kernel / etc. Engine
    /// iteration loops check this between iterations and bail when their
    /// captured generation no longer matches, which is what makes system
    /// switches feel immediate rather than waiting for the old converge.
    /// Written from the main actor only; read from the engine queue. On 64-bit
    /// iOS an Int read is atomic, and a stale read just costs one extra
    /// iteration which is harmless.
    nonisolated(unsafe) private var generation: Int = 0

    /// Per-system cache of the reduced palette, populated on the first live
    /// frame for that system and reused for subsequent frames. Skips the
    /// k-means reduce pass (the dominant cost for systems with `reduce`,
    /// e.g. Amiga Lores, Apple IIgs, Atari ST). Cleared when systemId
    /// changes or the user customises the palette.
    private var liveCachedPalette: [String: [UInt32]] = [:]

    // MARK: - Public input

    /// Use for the static-photo flow (gallery upload).
    func setImage(_ image: UIImage) {
        liveMode = false
        captured = false
        sourceImage = image
        // A new source image invalidates any previous crop the user picked.
        cropRect = nil
        restartIfReady()
    }

    /// Use for each frame from the camera streamer. Cheap pass — runs a few
    /// iterations only and produces a preview as fast as possible.
    /// `previewImage` is the downscaled image we feed the engine; `fullRes`
    /// is the highest-fidelity copy we want to retain for "Save original".
    func ingestLiveFrame(_ previewImage: UIImage, fullRes: UIImage? = nil) {
        guard liveMode, !captured else { return }
        if liveBusy { return }
        // sourceImage is the artifact we'd save / re-dither — store the
        // highest-quality version we have on hand.
        sourceImage = fullRes ?? previewImage
        runLivePass(image: previewImage)
    }

    /// Freeze the current dithered preview as the saved/captured artifact.
    /// Future setting changes will keep dithering against the frozen sourceImage
    /// until the user explicitly returns to live mode.
    func captureCurrentFrame(highRes: UIImage? = nil) {
        if let hi = highRes { sourceImage = hi }
        captured = true
        liveMode = false
        // Run a full convergence on the captured frame for the best result.
        restartIfReady()
    }

    /// Resume live mode (return to camera stream).
    func resumeLive() {
        captured = false
        liveMode = true
        previewImage = nil
        iterationCount = 0
        isFinal = false
        workItem?.cancel()
    }

    func currentSystem() -> DithertronSettings {
        return Systems.lookup[systemId] ?? Systems.all[0]
    }

    // MARK: - Convergence (static photo flow)

    private func restartIfReady() {
        guard let img = sourceImage, !liveMode else { return }
        let sys = makeSettings()
        guard let prepared = ImageBridge.sourcePixels(from: img, target: sys, cropRect: cropRect) else { return }

        canvasWidth = sys.width
        canvasHeight = sys.height
        canvasScaleX = sys.scaleX
        iterationCount = 0
        isFinal = false

        workItem?.cancel()
        let myGen = generation
        let item = DispatchWorkItem { [weak self] in
            self?.runEngine(pixels: prepared.pixels, sys: sys, gen: myGen)
        }
        workItem = item
        workQueue.async(execute: item)
    }

    private func runEngine(pixels: [UInt32], sys: DithertronSettings, gen: Int) {
        let local = Dithertron(sysparams: sys)
        local.setSourceImage(pixels)
        local.pixelsAvailable = { [weak self] msg in
            guard let self = self else { return }
            // Drop emissions from a stale generation — by the time we hop to
            // main, the user may have already moved on.
            guard let cg = ImageBridge.cgImage(fromPixels: msg.img,
                                               width: msg.width,
                                               height: msg.height) else { return }
            let image = UIImage(cgImage: cg)
            DispatchQueue.main.async {
                if gen == self.generation {
                    self.previewImage = image
                    self.iterationCount = msg.iterationCount
                    self.isFinal = msg.final
                    self.activePalette = msg.pal.map { $0 & 0x00ffffff }
                }
            }
        }
        while local.iterate() {
            // Bail mid-converge if the user changed system/kernel/etc.
            if gen != generation { return }
        }
    }

    // MARK: - Live pass (camera flow)

    /// One short pass per frame: a couple of iterations is enough to get a usable
    /// preview because the canvas is tiny (160×144 etc.) and ordered/Floyd kernels
    /// stabilize quickly.
    private func runLivePass(image: UIImage) {
        var sys = makeSettings()
        // KEEP the authentic canvas type — the captured save uses the same
        // path, so any "swap to DitheringCanvas" optimisation here would
        // make the visual character (attribute clash, HAM chroma, etc.)
        // shift the moment the user taps the shutter. Per-frame budget
        // stays manageable thanks to:
        //   • palette cache below — k-means reduce only runs once per system
        //   • saliency skip — 50ms/frame Vision call is bypassed in live
        //   • 144px canvas cap — keeps total pixel work bounded
        // The static / captured pass still runs at full system resolution.

        // Cached reduced palette across live frames lets reduce-using systems
        // (Amiga, Apple IIgs, Atari ST, Game Boy Color, Astrocade) skip the
        // k-means pass on every frame. Cache invalidates on system/kernel/
        // diversity changes via `invalidate()`.
        if customPalette == nil, sys.reduce != nil,
           let cached = liveCachedPalette[systemId] {
            sys.customPalette = cached
            sys.reduce = nil
        }
        // Live preview now runs at the system's NATIVE resolution with the
        // authentic canvas — same algorithm and same pixel grid as the
        // captured save. The "hack" that keeps it from feeling sluggish:
        //   • Single iteration per frame (vs full convergence on capture)
        //   • Palette cache (reduce only on first frame for a system)
        //   • Saliency skip (~50ms saved per frame)
        //   • SwiftUI cross-fade between previewImage updates hides the
        //     lower frame rate visually
        //   • liveBusy gate drops camera frames the engine can't keep up with
        //
        // For slow systems (NES at 256×240, Mac 128K at 512×342) live runs
        // closer to 5–10 fps, but every frame matches what would be captured.
        guard let prepared = ImageBridge.sourcePixels(
            from: image,
            target: sys,
            cropRect: cropRect,
            useSaliency: false
        ) else { return }
        liveBusy = true
        canvasWidth = sys.width
        canvasHeight = sys.height
        canvasScaleX = sys.scaleX
        let myGen = generation
        let didReduce = sys.customPalette == nil && currentSystem().reduce != nil
        let cacheKey = systemId

        workQueue.async { [weak self] in
            guard let self = self else { return }
            let local = Dithertron(sysparams: sys)
            local.setSourceImage(prepared.pixels)
            var lastImg: [UInt32] = []
            var w = 0, h = 0, iter = 0
            var pal: [UInt32] = []
            local.pixelsAvailable = { msg in
                lastImg = msg.img
                w = msg.width
                h = msg.height
                iter = msg.iterationCount
                pal = msg.pal
            }
            // Single iteration per live frame — the captured/static path runs
            // until convergence, which is where the second-and-onward iters
            // actually settle the dither. Live can't afford them.
            if myGen == self.generation { _ = local.iterate() }

            // Stale generation: skip publishing.
            if myGen != self.generation {
                DispatchQueue.main.async { self.liveBusy = false }
                return
            }

            guard !lastImg.isEmpty,
                  let cg = ImageBridge.cgImage(fromPixels: lastImg, width: w, height: h)
            else {
                DispatchQueue.main.async { self.liveBusy = false }
                return
            }
            let preview = UIImage(cgImage: cg)
            DispatchQueue.main.async {
                if myGen == self.generation {
                    self.previewImage = preview
                    self.iterationCount = iter
                    self.isFinal = false
                    self.activePalette = pal.map { $0 & 0x00ffffff }
                    if didReduce, !pal.isEmpty {
                        self.liveCachedPalette[cacheKey] = pal
                    }
                }
                self.liveBusy = false
            }
        }
    }

    private func makeSettings() -> DithertronSettings {
        var sys = currentSystem()
        sys.diffuse = diffuse
        sys.ordered = ordered
        sys.noise = noise
        sys.paletteDiversity = paletteDiversity
        sys.ditherKernelId = ditherKernelId
        sys.customPalette = customPalette

        // Override the dither canvas to match the source image's aspect when
        // requested. Block-aligned to avoid breaking attribute-tile constraints.
        if respectImageRatio, let img = sourceImage {
            let imgW = max(1, Double(img.size.width))
            let imgH = max(1, Double(img.size.height))
            let imgAspect = imgW / imgH
            let nativeMax = max(sys.width, sys.height)
            var w: Int
            var h: Int
            if imgAspect >= 1 {
                // Landscape (or square) — match width to system's longest edge.
                w = nativeMax
                h = max(1, Int((Double(nativeMax) / imgAspect).rounded()))
            } else {
                h = nativeMax
                w = max(1, Int((Double(nativeMax) * imgAspect).rounded()))
            }
            // Round to block multiples so cell-aware systems (NES, C64, ZX)
            // still satisfy their attribute constraints.
            let blockW = max(1, sys.block?.w ?? 1)
            let blockH = max(1, sys.block?.h ?? 1)
            w = ((w + blockW - 1) / blockW) * blockW
            h = ((h + blockH - 1) / blockH) * blockH
            sys.width = w
            sys.height = h
        }
        return sys
    }

    // MARK: - Save

    func savePreviewToPhotos() {
        guard let img = previewImage else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
    }
}
