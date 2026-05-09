import Foundation

/// Plain free-palette canvas (PICO-8, NES "free", GameBoy, Atari ST, etc).
final class DitheringCanvas: BaseDitheringCanvas {
    // identity wrapper around the base class
}

/// MSX/Coleco TMS9918A — 2 colors per 8x1 cell with 8x8 attribute color cells (handled by sys.cell).
final class MSXCanvas: CommonBlockParamDitherCanvas {
    // base behavior already handles 2-color block selection
}

/// SNES-style 2/4/8bpp planar tile color block (no dedicated logic in base TS for this here either).
final class SNESCanvas: CommonBlockParamDitherCanvas {
    // wrapper — palette range restrictions are handled by paletteChoices
}

/// Compucolor: 2x4 cell, two-color picker.
final class CompucolorCanvas: TwoColorCanvas {
    override init(img: [UInt32], width: Int, pal: [UInt32], sys: DithertronSettings) {
        super.init(img: img, width: width, pal: pal, sys: sys)
        w = 2; h = 4
    }
}

/// Teletext: 2x3 block, one foreground color over a black background.
final class TeletextCanvas: OneColorCanvas {
    override init(img: [UInt32], width: Int, pal: [UInt32], sys: DithertronSettings) {
        super.init(img: img, width: width, pal: pal, sys: sys)
        w = 2; h = 3
    }
}

/// Atari VCS color playfield: 40 pixels wide, two colors per scan line.
final class VCSColorPlayfieldCanvas: TwoColorCanvas {
    override init(img: [UInt32], width: Int, pal: [UInt32], sys: DithertronSettings) {
        super.init(img: img, width: width, pal: pal, sys: sys)
        w = 40; h = 1
    }
}

/// Atari VCS color playfield rendered as two interlaced scanlines per cell.
///
/// On real hardware the eye blends two alternating frames, each with its own
/// per-line color pair, into roughly twice the perceived chroma. We approximate
/// that statically: each 40×2 cell stores **four** palette indices, c1+c2 for
/// the top row and c3+c4 for the bottom. The base TwoColorCanvas only stores
/// two colors per cell, so this subclass packs four into the same UInt32
/// (8 bits per slot) and overrides `getValidColors` to choose the right pair
/// based on which row inside the cell we're rasterising.
final class VCSInterlacedCanvas: TwoColorCanvas {
    override init(img: [UInt32], width: Int, pal: [UInt32], sys: DithertronSettings) {
        super.init(img: img, width: width, pal: pal, sys: sys)
        w = 40
        h = 2
    }

    override func getValidColors(_ imageIndex: Int) -> [Int] {
        let col = (imageIndex / w) % ncols
        let row = imageIndex / (width * h)
        let i = col + row * ncols
        let p = params[i]
        // Top row of the 2-row cell uses (c1, c2); bottom row uses (c3, c4).
        let yWithinCell = (imageIndex / width) % h
        if yWithinCell == 0 {
            return [Int(p & 0xff), Int((p >> 8) & 0xff)]
        } else {
            return [Int((p >> 16) & 0xff), Int((p >> 24) & 0xff)]
        }
    }

    override func guessParam(_ p: Int) {
        let col = p % ncols
        let row = p / ncols
        let baseOffset = col * w + row * (width * h)
        guard let colors = allColors else { return }

        // Score the top scanline and bottom scanline independently — each gets
        // its own best-2-color pair, which is what creates the perceived
        // chroma doubling when the lines are viewed together.
        var topHisto = [Int](repeating: 0, count: pal.count + 16)
        var botHisto = [Int](repeating: 0, count: pal.count + 16)
        for x in 0..<w {
            let topIdx = baseOffset + x
            let botIdx = baseOffset + x + width
            if topIdx >= 0, topIdx < indexed.count {
                let c1 = indexed[topIdx]
                if c1 >= 0, c1 < topHisto.count { topHisto[c1] += 100 }
                let c2 = getClosest(alt[topIdx], colors)
                if c2 >= 0, c2 < topHisto.count { topHisto[c2] += 1 + noise }
            }
            if botIdx >= 0, botIdx < indexed.count {
                let c1 = indexed[botIdx]
                if c1 >= 0, c1 < botHisto.count { botHisto[c1] += 100 }
                let c2 = getClosest(alt[botIdx], colors)
                if c2 >= 0, c2 < botHisto.count { botHisto[c2] += 1 + noise }
            }
        }

        let topChoices = getChoices(topHisto)
        let botChoices = getChoices(botHisto)
        var c1 = topChoices.first?.ind ?? 0
        var c2 = topChoices.count > 1 ? topChoices[1].ind : c1
        var c3 = botChoices.first?.ind ?? 0
        var c4 = botChoices.count > 1 ? botChoices[1].ind : c3
        if c1 > c2 { swap(&c1, &c2) }
        if c3 > c4 { swap(&c3, &c4) }

        // Pack four 8-bit palette indices into the cell's UInt32 param slot.
        params[p] = UInt32(c1) | (UInt32(c2) << 8) | (UInt32(c3) << 16) | (UInt32(c4) << 24)
    }
}

/// Amiga HAM6 canvas — first pixel is from the chosen palette, subsequent pixels can modify
/// one of the previous pixel's R/G/B channels.
final class HAM6Canvas: BaseDitheringCanvas {
    override func getValidColors(_ offset: Int) -> [Int] {
        var arr = Array(0..<pal.count)
        if offset == 0 {
            arr = Array(arr.prefix(16))
        } else {
            var palindex = 16
            let prevrgb = img[offset - 1]
            for chan in 0..<3 {
                for i in 0..<16 {
                    var rgb = prevrgb
                    let mask: UInt32 = ~(UInt32(0xff) << UInt32(chan * 8))
                    rgb &= mask
                    rgb |= (UInt32(i) << 4) << UInt32(chan * 8)
                    if palindex < pal.count {
                        pal[palindex] = rgb | 0xff000000
                    }
                    palindex += 1
                }
            }
        }
        return arr
    }
}
