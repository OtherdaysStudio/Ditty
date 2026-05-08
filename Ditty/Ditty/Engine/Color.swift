import Foundation

@inline(__always)
func RGB(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
    return UInt32(r & 0xff) | (UInt32(g & 0xff) << 8) | (UInt32(b & 0xff) << 16)
}

@inline(__always)
func clampByte(_ v: Int) -> UInt32 {
    return UInt32(max(0, min(255, v)))
}

/// Same clamp but takes a Double so callers don't have to do `Int(double)` first
/// — that conversion crashes when the dithering error accumulator overflows
/// `Int.max` (which can happen with `diffuse > 1` for many iterations).
@inline(__always)
func clampByte(_ v: Double) -> UInt32 {
    if !v.isFinite { return 0 }
    return UInt32(max(0, min(255, v)))
}

typealias RGBDistanceFunction = (UInt32, UInt32) -> Double

@inline(__always)
func r(_ rgb: UInt32) -> Int { return Int(rgb & 0xff) }
@inline(__always)
func g(_ rgb: UInt32) -> Int { return Int((rgb >> 8) & 0xff) }
@inline(__always)
func b(_ rgb: UInt32) -> Int { return Int((rgb >> 16) & 0xff) }

@inline(__always)
func sqr(_ x: Double) -> Double { return x * x }

/// Clamp a Double to a safe Int-castable range. The error accumulator in
/// `reducePaletteChoices` can grow geometrically when the user's diversity
/// setting drives `decay > 1`, eventually exceeding `Int.max`. Anything past
/// ±1e15 is way out of useful range anyway.
@inline(__always)
func saturatingInt(_ d: Double) -> Int {
    let limit: Double = 1e15
    if d.isNaN { return 0 }
    if d > limit { return Int(limit) }
    if d < -limit { return -Int(limit) }
    return Int(d)
}

func getRGBADiff(_ rgbref: UInt32, _ rgbimg: UInt32) -> [Int] {
    return [
        r(rgbref) - r(rgbimg),
        g(rgbref) - g(rgbimg),
        b(rgbref) - b(rgbimg)
    ]
}

func getRGBAErrorAbsolute(_ a: UInt32, _ bb: UInt32) -> Double {
    let dr = Double(r(a) - r(bb))
    let dg = Double(g(a) - g(bb))
    let db = Double(b(a) - b(bb))
    return (dr*dr + dg*dg + db*db).squareRoot()
}

func getRGBAErrorPerceptual(_ a: UInt32, _ bb: UInt32) -> Double {
    let r1 = Double(r(a)), g1 = Double(g(a)), b1 = Double(b(a))
    let r2 = Double(r(bb)), g2 = Double(g(bb)), b2 = Double(b(bb))
    let rmean = (r1 + r2) / 2.0
    let dr = r1 - r2
    let dg = g1 - g2
    let db = b1 - b2
    return (((512.0 + rmean) * dr * dr) / 256.0 + 4.0 * dg * dg + (((767.0 - rmean) * db * db) / 256.0)).squareRoot()
}

func getRGBAErrorHue(_ a: UInt32, _ bb: UInt32) -> Double {
    var r1 = Double(r(a)), g1 = Double(g(a)), b1 = Double(b(a))
    var r2 = Double(r(bb)), g2 = Double(g(bb)), b2 = Double(b(bb))
    let bias: Double = 256
    let avg1 = (r1 + g1 + b1) / 3.0 + bias
    let avg2 = (r2 + g2 + b2) / 3.0 + bias
    r1 /= avg1; g1 /= avg1; b1 /= avg1
    r2 /= avg2; g2 /= avg2; b2 /= avg2
    return (sqr(r1 - r2) + sqr(g1 - g2) + sqr(b1 - b2)).squareRoot() * 256.0
}

func getRGBAErrorMax(_ a: UInt32, _ bb: UInt32) -> Double {
    let dr = abs(r(a) - r(bb))
    let dg = abs(g(a) - g(bb))
    let db = abs(b(a) - b(bb))
    return Double(max(dr, max(dg, db)))
}

func intensity(_ rgb: UInt32) -> Double { return getRGBAErrorPerceptual(0, rgb) }

enum ErrorFunctionKind: String {
    case perceptual, hue, dist, max
    var fn: RGBDistanceFunction {
        switch self {
        case .perceptual: return getRGBAErrorPerceptual
        case .hue: return getRGBAErrorHue
        case .dist: return getRGBAErrorAbsolute
        case .max: return getRGBAErrorMax
        }
    }
}

func getClosestRGB(_ rgb: UInt32, _ inds: [Int], _ pal: [UInt32], _ distfn: RGBDistanceFunction) -> Int {
    var best = Double.greatestFiniteMagnitude
    var bestIdx = -1
    inds.withUnsafeBufferPointer { ip in
        pal.withUnsafeBufferPointer { pp in
            let n = ip.count
            for i in 0..<n {
                let ind = ip[i]
                if ind < 0 { continue }
                let score = distfn(rgb, pp[ind])
                if score < best {
                    best = score
                    bestIdx = ind
                }
            }
        }
    }
    return bestIdx
}

struct ColorChoice {
    var ind: Int
    var count: Int
}

struct ScoredColorChoice {
    var ind: Int
    var count: Int
    var score: Int
}

final class Centroid {
    var r: Double = 0, g: Double = 0, b: Double = 0, n: Double = 0
    func add(_ rgb: UInt32) {
        r += Double(rgb & 0xff)
        g += Double((rgb >> 8) & 0xff)
        b += Double((rgb >> 16) & 0xff)
        n += 1
    }
    func avgRGB(_ k: Double) -> UInt32 {
        guard n > 0 else { return 0 }
        let rr = max(0, min(255, r * k / n))
        let gg = max(0, min(255, g * k / n))
        let bb = max(0, min(255, b * k / n))
        return UInt32(rr) | (UInt32(gg) << 8) | (UInt32(bb) << 16)
    }
}

func reducePaletteChoices(
    imageData: [UInt32],
    colors: [UInt32],
    count: Int,
    diversity: Double,
    distfn: RGBDistanceFunction
) -> [ColorChoice] {
    var histo = [Int](repeating: 0, count: colors.count)
    var err = [Int](repeating: 0, count: 4)
    let bias = diversity * 0.5 + 0.5
    let decay = diversity * 0.25 + 0.65
    var inds = [Int]()
    var centroids = [Centroid]()
    for i in 0..<count {
        inds.append((i * (colors.count - 1)) / max(1, count))
        centroids.append(Centroid())
    }
    for iter in 0..<10 {
        // skip-around iteration matching the JS version
        var i = iter
        while i < imageData.count {
            let rgbref = imageData[i]
            err[0] += Int(rgbref & 0xff)
            err[1] += Int((rgbref >> 8) & 0xff)
            err[2] += Int((rgbref >> 16) & 0xff)
            let rc = clampByte(err[0])
            let gc = clampByte(err[1])
            let bc = clampByte(err[2])
            let modified = rc | (gc << 8) | (bc << 16)
            let ind1 = getClosestRGB(modified, inds, colors, distfn)
            if ind1 >= 0, let ci = inds.firstIndex(of: ind1) {
                let alt = colors[ind1]
                centroids[ci].add(modified)
                let score = distfn(modified, alt)
                histo[ind1] += max(0, 256 - Int(score))
                err[0] -= Int(alt & 0xff)
                err[1] -= Int((alt >> 8) & 0xff)
                err[2] -= Int((alt >> 16) & 0xff)
                // When diversity > 1.4, decay > 1 and err accumulates geometrically.
                // Clamp the running error to a finite range so we never overflow Int.
                err[0] = saturatingInt(Double(err[0]) * decay)
                err[1] = saturatingInt(Double(err[1]) * decay)
                err[2] = saturatingInt(Double(err[2]) * decay)
            }
            i += (i & 15) + 1
        }
        var allInds = Array(0..<colors.count)
        var nchanged = 0
        for j in 0..<count {
            let cent = centroids[j]
            let current = colors[inds[j]]
            let target = cent.avgRGB(bias)
            let ind2 = getClosestRGB(target, allInds, colors, distfn)
            if ind2 >= 0 {
                let better = colors[ind2]
                if better != current {
                    inds[j] = ind2
                    nchanged += 1
                }
                for k in 0..<colors.count where colors[k] == better {
                    allInds[k] = -1
                }
            }
        }
        if nchanged == 0 { break }
    }
    var result = inds.map { ColorChoice(ind: $0, count: histo[$0]) }
    result.sort { intensity(colors[$0.ind]) < intensity(colors[$1.ind]) }
    return result
}

func reducePalette(
    imageData: [UInt32],
    colors: [UInt32],
    count: Int,
    diversity: Double,
    distfn: RGBDistanceFunction
) -> [UInt32] {
    if colors.count == count { return colors }
    let choices = reducePaletteChoices(imageData: imageData, colors: colors, count: count, diversity: diversity, distfn: distfn)
    return choices.map { colors[$0.ind] }
}

func getChoices(_ histo: [Int]) -> [ColorChoice] {
    var out: [ColorChoice] = []
    for (i, c) in histo.enumerated() where c > 0 {
        out.append(ColorChoice(ind: i, count: c))
    }
    out.sort { $0.count > $1.count }
    return out
}
