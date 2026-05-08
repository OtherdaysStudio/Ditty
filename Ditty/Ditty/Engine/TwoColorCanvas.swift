import Foundation

class TwoColorCanvas: BasicParamDitherCanvas {
    var ncols: Int = 0
    var nrows: Int = 0
    var border: Int = 0
    var allColors: [Int]? = nil

    override func initialize() {
        if allColors == nil { allColors = Array(0..<pal.count) }
        let first = allColors?.first ?? 0
        for i in 0..<indexed.count { indexed[i] = first }
        ncols = width / w
        nrows = height / h
        params = [UInt32](repeating: 0, count: ncols * nrows)
        for i in 0..<params.count { guessParam(i) }
    }

    override func getValidColors(_ imageIndex: Int) -> [Int] {
        let col = (imageIndex / w) % ncols
        let row = imageIndex / (width * h)
        let i = col + row * ncols
        let c1 = Int(params[i] & 0xff)
        let c2 = Int((params[i] >> 8) & 0xff)
        return [c1, c2]
    }

    override func guessParam(_ p: Int) {
        let col = p % ncols
        let row = p / ncols
        let offset = col * w + row * (width * h)
        guard let colors = allColors else { return }
        var histo = [Int](repeating: 0, count: pal.count + 16)
        let bdr = border
        for y in -bdr..<(h + bdr) {
            let o = offset + y * width
            for x in -bdr..<(w + bdr) {
                let idx = o + x
                if idx < 0 || idx >= indexed.count { continue }
                let c1 = indexed[idx]
                if c1 >= 0 && c1 < histo.count { histo[c1] += 100 }
                let c2 = getClosest(alt[idx], colors)
                if c2 >= 0 && c2 < histo.count { histo[c2] += 1 + noise }
            }
        }
        let choices = getChoices(histo)
        updateParams(p, choices)
    }

    func updateParams(_ p: Int, _ choices: [ColorChoice]) {
        var ind1 = choices.first?.ind ?? 0
        var ind2 = choices.count > 1 ? choices[1].ind : ind1
        if ind1 > ind2 { swap(&ind1, &ind2) }
        params[p] = UInt32(ind1) | (UInt32(ind2) << 8)
    }
}

class OneColorCanvas: TwoColorCanvas {
    var bgColor: Int = 0

    override func initialize() {
        bgColor = 0
        super.initialize()
    }

    override func getValidColors(_ imageIndex: Int) -> [Int] {
        return [bgColor, super.getValidColors(imageIndex)[0]]
    }

    override func updateParams(_ p: Int, _ choices: [ColorChoice]) {
        for c in choices {
            if c.ind != bgColor {
                params[p] = UInt32(c.ind)
                break
            }
        }
    }
}

// Apple II hi-res: 7 pixels per byte share a "hibit" that selects color set
class Apple2Canvas: TwoColorCanvas {
    override func initialize() {
        w = 7; h = 1
        allColors = [0, 1, 2, 3, 4, 5]
        super.initialize()
    }

    override func guessParam(_ p: Int) {
        let offset = p * w
        guard let colors = allColors else { return }
        var histo = [Int](repeating: 0, count: 16)
        for i in 0..<w {
            let idx = offset + i
            if idx < 0 || idx >= indexed.count { break }
            let c1 = indexed[idx]
            if c1 >= 0 && c1 < histo.count { histo[c1] += 100 }
            let c2 = getClosest(alt[idx], colors)
            if c2 >= 0 && c2 < histo.count { histo[c2] += 1 + noise }
        }
        let hibit = (histo[3] + histo[4]) > (histo[1] + histo[2])
        params[p] = hibit ? 1 : 0
    }

    override func getValidColors(_ imageIndex: Int) -> [Int] {
        let i = imageIndex / w
        if i < 0 || i >= params.count { return [0, 1, 2, 5] }
        let hibit = (params[i] & 1) != 0
        return hibit ? [0, 3, 4, 5] : [0, 1, 2, 5]
    }
}

// NES: 16x16 cells, omit one of the 4 chosen palette colors
class NESCanvas: BasicParamDitherCanvas {
    override init(img: [UInt32], width: Int, pal: [UInt32], sys: DithertronSettings) {
        super.init(img: img, width: width, pal: pal, sys: sys)
        w = 16
        h = 16
    }

    override func initialize() {
        params = [UInt32](repeating: 0, count: (width / w) * (height / h))
        for i in 0..<params.count { guessParam(i) }
    }

    override func getValidColors(_ offset: Int) -> [Int] {
        let ncols = width / w
        let col = (offset / w) % ncols
        let row = offset / (width * h)
        let i = col + row * ncols
        if i < 0 || i >= params.count { return [0, 1, 2, 3, 4] }
        let c1 = params[i]
        switch c1 & 3 {
        case 0: return [0, 2, 3, 4]
        case 1: return [0, 1, 3, 4]
        case 2: return [0, 1, 2, 4]
        case 3: return [0, 1, 2, 3]
        default: return [0, 1, 2, 3]
        }
    }

    override func guessParam(_ p: Int) {
        let ncols = width / w
        let col = p % ncols
        let row = p / ncols
        let offset = col * w + row * width * h
        let colors = [1, 2, 3, 4]
        var histo = [Int](repeating: 0, count: 16)
        let bdr = 8
        for y in -bdr..<(h + bdr) {
            let o = offset + y * width
            for x in -bdr..<(w + bdr) {
                let idx = o + x
                if idx < 0 || idx >= indexed.count { continue }
                let c1 = indexed[idx]
                if c1 >= 0 && c1 < histo.count { histo[c1] += 100 }
                let c2 = getClosest(alt[idx], colors)
                if c2 >= 0 && c2 < histo.count { histo[c2] += 1 + noise }
            }
        }
        let choices = getChoices(histo)
        for ch in choices {
            if ch.ind >= 1 && ch.ind <= 4 {
                params[p] = UInt32(ch.ind - 1)
                return
            }
        }
    }
}
