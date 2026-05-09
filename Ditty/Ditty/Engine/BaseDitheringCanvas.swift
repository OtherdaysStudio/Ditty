import Foundation

private let THRESHOLD_MAP_4X4: [Double] = [
    0, 8, 2, 10,
    12, 4, 14, 6,
    3, 11, 1, 9,
    15, 7, 13, 5,
]

class BaseDitheringCanvas {
    var sys: DithertronSettings
    var pal: [UInt32]
    var img: [UInt32]
    var ref: [UInt32]
    var alt: [UInt32]
    var err: [Float]   // 3 channels per pixel
    var indexed: [Int]
    var width: Int
    var height: Int

    var changes: Int = 0
    var noise: Int = 0
    var diffuse: Double = 0.8
    var ordered: Double = 0.0
    var ditherfn: DitherKernel = []
    var errfn: RGBDistanceFunction = getRGBAErrorPerceptual
    var errorThreshold: Double = 0
    var iterateCount: Int = 0

    var params: [UInt32] = []

    /// RGB → palette index memo cache. Persists across all iterations of a
    /// canvas's lifetime — the palette doesn't change while a single
    /// Dithertron is alive, so cached lookups remain valid. Only consulted
    /// when `getValidColors()` returns the full palette (free-palette
    /// systems); block-aware canvases short-circuit past it.
    private var closestCache: [UInt32: Int] = [:]
    /// Cached "is full palette" decision for the current frame (set in iterate()).
    fileprivate var fullPaletteCache: Bool = false

    /// True when every pixel in the source already exists in the palette. The
    /// dither pass becomes a direct index lookup — no diffusion, no error,
    /// pixel-perfect passthrough. Detected lazily on first iterate().
    private var isPixelExact: Bool? = nil

    init(img: [UInt32], width: Int, pal: [UInt32], sys: DithertronSettings) {
        self.img = img
        self.ref = img
        self.alt = img
        self.width = width
        self.height = img.count / max(1, width)
        self.pal = pal.map { $0 | 0xff000000 }
        self.err = [Float](repeating: 0, count: img.count * 3)
        self.indexed = [Int](repeating: 0, count: img.count)
        self.sys = sys
    }

    func reset() {
        self.img = self.ref
        self.alt = self.ref
        for i in 0..<err.count { err[i] = 0 }
        for i in 0..<indexed.count { indexed[i] = 0 }
        changes = 0
    }

    func initialize() {
        // override
    }

    func iterate() {
        changes = 0
        commit()
        // First call: check if the source is already pixel-exact in the palette.
        // If so, skip dithering entirely — direct map and mark final.
        if isPixelExact == nil { isPixelExact = detectPixelExact() }
        if isPixelExact == true {
            applyPixelExactPass()
            iterateCount += 1
            return
        }
        // Cache covers the common free-palette case where `getValidColors`
        // returns the full palette. Block-aware subclasses override that, so
        // we detect it once per pass to avoid the dictionary entirely when
        // it'd be unsafe.
        let valid = getValidColors(0)
        fullPaletteCache = (valid.count == pal.count) && Array(0..<pal.count) == valid
        for i in 0..<img.count {
            update(i)
        }
        iterateCount += 1
    }

    private func detectPixelExact() -> Bool {
        // Build a small set of palette colors (alpha-stripped) and check every
        // source pixel against it. Bails out early on the first miss so the
        // common "no" case stays fast even for big images.
        var palSet = Set<UInt32>(minimumCapacity: pal.count)
        for c in pal { palSet.insert(c & 0x00ffffff) }
        for px in ref where !palSet.contains(px & 0x00ffffff) {
            return false
        }
        return true
    }

    private func applyPixelExactPass() {
        // O(n) lookup map: palette color (RGB only) → index. Built once.
        var palIndex: [UInt32: Int] = [:]
        palIndex.reserveCapacity(pal.count)
        for (i, c) in pal.enumerated() { palIndex[c & 0x00ffffff] = i }
        for i in 0..<ref.count {
            let key = ref[i] & 0x00ffffff
            let idx = palIndex[key] ?? 0
            indexed[i] = idx
            img[i] = pal[idx]
        }
    }

    func commit() { /* override */ }

    func getValidColors(_ imageIndex: Int) -> [Int] {
        // default: full palette
        return Array(0..<pal.count)
    }

    func getClosest(_ rgb: UInt32, _ inds: [Int]) -> Int {
        if fullPaletteCache {
            if let cached = closestCache[rgb] { return cached }
            let result = getClosestRGB(rgb, inds, pal, errfn)
            closestCache[rgb] = result
            return result
        }
        return getClosestRGB(rgb, inds, pal, errfn)
    }

    func update(_ offset: Int) {
        let errofs = offset * 3
        let rgbref = ref[offset]
        var ko: Double = 1
        if ordered > 0 {
            let x = (offset % width) & 3
            let y = (offset / width) & 3
            ko = 1 + (THRESHOLD_MAP_4X4[x + y * 4] / 15.0 - 0.5) * ordered
        }
        // tmp[0..2] are clamped 0-255 = (rgbref channel * ko + err). Use the
        // Double-taking overload of clampByte: with high diffuse settings the
        // err accumulator can grow past Int.max, so an intermediate Int cast
        // would crash before the clamp can kick in.
        let tr = clampByte(Double(r(rgbref)) * ko + Double(err[errofs]))
        let tg = clampByte(Double(g(rgbref)) * ko + Double(err[errofs + 1]))
        let tb = clampByte(Double(b(rgbref)) * ko + Double(err[errofs + 2]))
        let modifiedRGB: UInt32 = tr | (tg << 8) | (tb << 16)
        alt[offset] = modifiedRGB

        let valid = getValidColors(offset)
        let palidx = getClosest(modifiedRGB, valid)
        let rgbimg = palidx >= 0 ? pal[palidx] : pal[0]

        // compute error
        let dErr = getRGBADiff(rgbref, rgbimg)
        for i in 0..<3 {
            let k = (Double(err[errofs + i]) + Double(dErr[i])) * diffuse
            // distribute through dither kernel
            for df in ditherfn {
                let dx = Int(df[0])
                let dy = Int(df[1])
                let weight = df[2]
                let neighborOfs = errofs + i + (dx + dy * width) * 3
                if neighborOfs >= 0 && neighborOfs < err.count {
                    err[neighborOfs] += Float(k * weight)
                }
            }
            err[errofs + i] = 0
        }

        let errmag = (abs(Double(dErr[0])) + abs(Double(dErr[1]) * 2.0) + abs(Double(dErr[2]))) / (256.0 * 4.0)
        if indexed[offset] != palidx {
            var shouldChange = (errmag >= errorThreshold)
            if !shouldChange {
                let existing = indexed[offset]
                if !valid.contains(existing) {
                    shouldChange = true
                }
            }
            if shouldChange {
                indexed[offset] = palidx
                changes += 1
            }
        }
        img[offset] = rgbimg
    }
}

class ParamDitherCanvas: BaseDitheringCanvas {
    override func commit() {
        for i in 0..<params.count {
            guessParam(i)
        }
    }
    func guessParam(_ paramIndex: Int) { /* override */ }
}

class BasicParamDitherCanvas: ParamDitherCanvas {
    var w: Int = 8
    var h: Int = 8

    override func initialize() {
        params = [UInt32](repeating: 0, count: (width * height) / max(1, w))
        for i in 0..<params.count { guessParam(i) }
    }
}
