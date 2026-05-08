import Foundation

/// ZX Spectrum: 8x8 attribute cells, 2 colors per cell, both must be in the same brightness half.
final class ZXSpectrumCanvas: CommonBlockParamDitherCanvas {

    var darkColors: [Int] = []
    var brightColors: [Int] = []
    var flipPalette: Bool = false
    var paletteRange = PaletteRange(min: 0, max: 15)

    override func initialize() {
        prepare()
        let half = pal.count / 2
        darkColors = Array(0..<half)
        brightColors = Array(half..<pal.count)
        paletteRange = paletteChoices.colorsRange
        flipPalette = (sys.customize?["flipPalette"] as? Bool) ?? false
    }

    override func guessBlockParam(_ offset: Int) {
        func calculateHistogramForCell(_ colors: [Int], _ minV: Int, _ maxV: Int) -> [ScoredColorChoice] {
            for i in 0..<histogram.count { histogram[i] = 0 }
            for i in 0..<scores.count { scores[i] = 0 }

            // pulled-towards-reference scoring; if the original cell color got swapped to the
            // wrong half, count it as if it had been the matching color in the new half (color ^ 8)
            let addCurrent: (Int, Int, Int?, inout [Int]) -> Void = { x, y, color, histogram in
                guard let c = color else { return }
                if c < minV || c > maxV {
                    let swapped = c ^ 0b1000
                    if swapped >= 0 && swapped < histogram.count {
                        histogram[swapped] += self.histogramScoreCurrent
                    }
                } else {
                    if c >= 0 && c < histogram.count {
                        histogram[c] += self.histogramScoreCurrent
                    }
                }
            }
            addToBlockHistogramFromCurrentColor(offset, &histogram, allColors, nil, addCurrent)
            let scored = addToBlockHistogramFromAlt(offset, &histogram, &scores, colors)
            return getScoredChoicesByCount(scored)
        }

        var choices1 = Array(calculateHistogramForCell(darkColors, darkColors.first ?? 0, darkColors.last ?? 7).prefix(2))
        var choices2 = Array(calculateHistogramForCell(brightColors, brightColors.first ?? 8, brightColors.last ?? 15).prefix(2))

        if choices1.count < 2 { if let f = choices1.first { choices1.append(f) } }
        if choices2.count < 2 { if let f = choices2.first { choices2.append(f) } }
        if choices1.count < 2 || choices2.count < 2 {
            // not enough data — fall back to background
            updateBlockColorParam(offset, [backgroundColor, backgroundColor])
            return
        }

        let score1 = choices1.reduce(0) { $0 + $1.score }
        let score2 = choices2.reduce(0) { $0 + $1.score }

        var result = score2 < score1 ? choices2 : choices1
        if result[0].ind < paletteRange.min || result[0].ind > paletteRange.max {
            result = score2 < score1 ? choices1 : choices2
        }

        if flipPalette {
            result[0] = ScoredColorChoice(ind: result[0].ind ^ 0b1000, count: result[0].count, score: result[0].score)
            result[1] = ScoredColorChoice(ind: result[1].ind ^ 0b1000, count: result[1].count, score: result[1].score)
        }

        let sorted = [result[0].ind, result[1].ind].sorted()
        updateBlockColorParam(offset, sorted)
    }
}
