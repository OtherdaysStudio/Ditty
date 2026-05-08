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
