import Foundation

struct BlockInfo {
    var w: Int
    var h: Int
    var xb: Int = 0
    var yb: Int = 0
    var msbToLsb: Bool = true
    var columns: Int = 0
    var rows: Int = 0
    var size: Int = 0
    var colors: Int = 0
}

struct ClosestScore {
    var closestColor: Int
    var closestScore: Double
}

struct ResolvedParamInfo {
    var block: Bool
    var cb: Bool
    var cell: Bool
    var extra: Int
}

class CommonBlockParamDitherCanvas: BaseDitheringCanvas {
    var block = BlockInfo(w: 8, h: 8)
    var cb = BlockInfo(w: 8, h: 8)
    var cell = BlockInfo(w: 8, h: 8)

    var fliMode: Bool = false
    var fullPaletteMode: Bool = false

    var paramInfo = ResolvedParamInfo(block: false, cb: false, cell: false, extra: 0)
    var bitsPerColor: Int = 1
    var pixelsPerByte: Int = 8

    var paletteChoices = PaletteChoices()
    var paletteBits: Int = 4
    var paletteBitFilter: Int = 0xf

    var backgroundColor: Int = 0
    var auxColor: Int = 0
    var borderColor: Int = 0

    var pixelPaletteChoices: [Int] = []
    var allColors: [Int] = []
    var backgroundColors: [Int] = []
    var auxColors: [Int] = []
    var borderColors: [Int] = []
    var blockColors: [Int] = []
    var globalValid: [Int] = []

    var foundColorsByUsage: [ColorChoice] = []
    var foundColorsByColorIntensity: [ColorChoice] = []
    var histogramScoreCurrent: Int = 100

    var histogram: [Int] = []
    var scores: [Int] = []

    var firstCommit = false

    var blockParams: [UInt32] = []
    var cbParams: [UInt32] = []
    var cellParams: [UInt32] = []
    var extraParams: [UInt32] = []

    override init(img: [UInt32], width: Int, pal: [UInt32], sys: DithertronSettings) {
        super.init(img: img, width: width, pal: pal, sys: sys)
        paletteBits = max(1, Int(ceil(log2(Double(self.pal.count)))))
        paletteBitFilter = (1 << paletteBits) - 1
        histogram = [Int](repeating: 0, count: self.pal.count)
        scores = [Int](repeating: 0, count: self.pal.count)
    }

    override func initialize() {
        prepare()
    }

    func prepare() {
        // mirror BaseDitheringCanvas.init for the basics
        prepareDefaults()
        prepareGlobalColorChoices()
        allocateParams()

        let prefill: Int
        if let first = pixelPaletteChoices.first { prefill = first }
        else if let firstAll = allColors.first { prefill = firstAll }
        else { prefill = backgroundColor }
        for i in 0..<indexed.count { indexed[i] = prefill }
    }

    func prepareDefaults() {
        let sBlock = sys.block
        let sCell = sys.cell
        let sCb = sys.cb

        let bw = sBlock?.w ?? sCell?.w ?? sCb?.w ?? 8
        let bh = sBlock?.h ?? sCell?.h ?? sCb?.h ?? 8
        let bcolors = sBlock?.colors ?? 2
        let bxb = sBlock?.xb ?? sCb?.xb ?? 0
        let byb = sBlock?.yb ?? sCb?.yb ?? 0
        let bmsb = sBlock?.msbToLsb ?? true

        block = BlockInfo(w: bw, h: bh, xb: bxb, yb: byb, msbToLsb: bmsb,
                          columns: Int(ceil(Double(width) / Double(bw))),
                          rows: Int(ceil(Double(height) / Double(bh))),
                          size: 0,
                          colors: bcolors)
        block.size = block.columns * block.rows

        let cbw = sCb?.w ?? block.w
        let cbh = sCb?.h ?? block.h
        let cbxb = sCb?.xb ?? block.xb
        let cbyb = sCb?.yb ?? block.yb
        let cbmsb = sCb?.msbToLsb ?? true
        cb = BlockInfo(w: cbw, h: cbh, xb: cbxb, yb: cbyb, msbToLsb: cbmsb,
                       columns: Int(ceil(Double(width) / Double(cbw))),
                       rows: Int(ceil(Double(height) / Double(cbh))),
                       size: 0,
                       colors: 0)
        cb.size = cb.columns * cb.rows

        let cellw = sCell?.w ?? cb.w
        let cellh = sCell?.h ?? cb.h
        let cellxb = sCell?.xb ?? block.xb
        let cellyb = sCell?.yb ?? block.yb
        let cellmsb = sCell?.msbToLsb ?? true
        cell = BlockInfo(w: cellw, h: cellh, xb: cellxb, yb: cellyb, msbToLsb: cellmsb,
                         columns: Int(ceil(Double(width) / Double(cellw))),
                         rows: Int(ceil(Double(height) / Double(cellh))),
                         size: 0,
                         colors: 0)
        cell.size = cell.columns * cell.rows

        fliMode = (sys.fli != nil)
        let p = sys.param
        paramInfo = ResolvedParamInfo(
            block: p?.block ?? (sys.block != nil),
            cb: p?.cb ?? (sys.cb != nil),
            cell: p?.cell ?? false,
            extra: p?.extra ?? 0
        )

        bitsPerColor = max(1, Int(ceil(log2(Double(block.colors)))))
        pixelsPerByte = max(1, 8 / bitsPerColor)

        preparePaletteChoices(sys.paletteChoices)
        fullPaletteMode = (paletteChoices.colors >= pal.count)
        firstCommit = paletteChoices.prefillReference
    }

    func preparePaletteChoices(_ options: PartialPaletteChoices?) {
        let palMax = pal.count - 1
        var pc = PaletteChoices()
        pc.prefillReference = options?.prefillReference ?? false
        pc.background = options?.background ?? false
        pc.aux = options?.aux ?? false
        pc.border = options?.border ?? false
        pc.backgroundRange = options?.backgroundRange ?? PaletteRange(min: 0, max: palMax)
        pc.auxRange = options?.auxRange ?? PaletteRange(min: 0, max: palMax)
        pc.borderRange = options?.borderRange ?? PaletteRange(min: 0, max: palMax)
        pc.colorsRange = options?.colorsRange ?? PaletteRange(min: 0, max: palMax)
        pc.colors = block.colors

        if let cc = options?.colors {
            pc.colors = cc
        } else {
            pc.colors = block.colors
                - (pc.background ? 1 : 0)
                - (pc.aux ? 1 : 0)
                - (pc.border ? 1 : 0)
        }

        paletteChoices = pc
        preparePixelPaletteChoices()
    }

    func preparePixelPaletteChoices() {
        pixelPaletteChoices = Array(paletteChoices.colorsRange.min...paletteChoices.colorsRange.max)
        allColors = Array(0..<pal.count)
        backgroundColors = Array(paletteChoices.backgroundRange.min...paletteChoices.backgroundRange.max)
        auxColors = Array(paletteChoices.auxRange.min...paletteChoices.auxRange.max)
        borderColors = Array(paletteChoices.borderRange.min...paletteChoices.borderRange.max)
        blockColors = Array(paletteChoices.colorsRange.min...paletteChoices.colorsRange.max)
    }

    func chooseMin(_ available: Bool, _ rng: PaletteRange, _ current: Int? = nil) -> Int? {
        if !available { return current }
        if let c = current { return min(c, rng.min) }
        return rng.min
    }
    func chooseMax(_ available: Bool, _ rng: PaletteRange, _ current: Int? = nil) -> Int? {
        if !available { return current }
        if let c = current { return max(c, rng.max) }
        return rng.max
    }

    func prepareMinMax(_ background: Bool, _ aux: Bool, _ border: Bool) -> PaletteRange {
        var minV = chooseMin(background, paletteChoices.backgroundRange)
        minV = chooseMin(aux, paletteChoices.auxRange, minV)
        minV = chooseMin(border, paletteChoices.borderRange, minV)
        var maxV = chooseMax(background, paletteChoices.backgroundRange)
        maxV = chooseMax(aux, paletteChoices.auxRange, maxV)
        maxV = chooseMax(border, paletteChoices.borderRange, maxV)
        return PaletteRange(min: minV ?? 0, max: maxV ?? (pal.count - 1))
    }

    func spliceColor(_ color: Int, _ colors: [Int]) -> [Int] {
        guard let i = colors.firstIndex(of: color) else { return colors }
        var out = colors; out.remove(at: i); return out
    }

    func prepareGlobalColorChoices() {
        let rng = prepareMinMax(true, true, true)
        let palSubset = Array(pal[rng.min...rng.max])

        var choices = reducePaletteChoices(
            imageData: ref,
            colors: palSubset,
            count: palSubset.count,
            diversity: 1,
            distfn: errfn
        )

        var histoRanked = choices
        histoRanked.sort { $0.count > $1.count }

        foundColorsByUsage = histoRanked
        foundColorsByColorIntensity = choices

        struct Opt {
            var id: Int
            var selectable: Bool
            var range: PaletteRange
        }
        var ranges: [Opt] = [
            Opt(id: 0, selectable: paletteChoices.background, range: paletteChoices.backgroundRange),
            Opt(id: 1, selectable: paletteChoices.aux, range: paletteChoices.auxRange),
            Opt(id: 2, selectable: paletteChoices.border, range: paletteChoices.borderRange),
        ]
        ranges.sort { a, b in
            if a.selectable == b.selectable {
                let aw = a.range.max - a.range.min
                let bw = b.range.max - b.range.min
                return aw == bw ? a.id < b.id : aw < bw
            }
            return a.selectable && !b.selectable
        }

        let assignId: (ColorChoice, Opt) -> Bool = { [weak self] choice, opt in
            guard let self = self else { return false }
            let index = choice.ind + rng.min
            if index < opt.range.min || index > opt.range.max { return false }
            switch opt.id {
            case 0: self.backgroundColor = index
            case 1: self.auxColor = index
            case 2: self.borderColor = index
            default: break
            }
            return true
        }

        let findBest: (inout [ColorChoice], inout [ColorChoice], Opt) -> Void = { search, alt, opt in
            for c in 0..<search.count {
                let choice = search[c]
                if !assignId(choice, opt) { continue }
                if let foundIdx = alt.firstIndex(where: { $0.ind == choice.ind }) {
                    alt.remove(at: foundIdx)
                }
                search.remove(at: c)
                break
            }
        }

        var firstNonSelectableFound = false

        for i in 0..<ranges.count {
            let opt = ranges[i]
            if !opt.selectable && !firstNonSelectableFound {
                var topN: [(priority: Int, choice: ColorChoice)] = []
                let remaining = ranges.count - i
                for c in 0..<min(remaining, histoRanked.count) {
                    let topChoice = histoRanked[c]
                    if let priority = choices.firstIndex(where: { $0.ind == topChoice.ind }) {
                        topN.append((priority, topChoice))
                        choices.remove(at: priority)
                    }
                }
                topN.sort { $0.priority < $1.priority }
                choices = topN.map { $0.choice } + choices
                firstNonSelectableFound = true
            }
            if opt.selectable {
                findBest(&histoRanked, &choices, opt)
            } else {
                findBest(&choices, &histoRanked, opt)
            }
        }

        if paletteChoices.background { globalValid.append(backgroundColor) }
        if paletteChoices.aux { globalValid.append(auxColor) }
        if paletteChoices.border { globalValid.append(borderColor) }

        if paletteChoices.background {
            pixelPaletteChoices = spliceColor(backgroundColor, pixelPaletteChoices)
        }
        if paletteChoices.aux {
            pixelPaletteChoices = spliceColor(auxColor, pixelPaletteChoices)
        }
        if paletteChoices.border {
            pixelPaletteChoices = spliceColor(borderColor, pixelPaletteChoices)
        }
    }

    func allocateParams() {
        blockParams = [UInt32](repeating: 0, count: paramInfo.block ? block.size : 0)
        cbParams = [UInt32](repeating: 0, count: paramInfo.cb ? cb.size : 0)
        cellParams = [UInt32](repeating: 0, count: paramInfo.cell ? cell.size : 0)
        extraParams = [UInt32](repeating: 0, count: paramInfo.extra)
        params = blockParams
    }

    // -- Coordinate helpers --

    func imageIndexToInfo(_ index: Int, _ info: BlockInfo) -> (column: Int, row: Int) {
        let column = (index / info.w) % info.columns
        let row = index / (width * info.h)
        return (column, row)
    }

    func imageIndexToBlockOffset(_ index: Int) -> Int {
        let i = imageIndexToInfo(index, block); return i.row * block.columns + i.column
    }
    func imageIndexToCbOffset(_ index: Int) -> Int {
        let i = imageIndexToInfo(index, cb); return i.row * cb.columns + i.column
    }
    func imageIndexToCellOffset(_ index: Int) -> Int {
        let i = imageIndexToInfo(index, cell); return i.row * cell.columns + i.column
    }
    func imageIndexToBlockInfo(_ index: Int) -> (column: Int, row: Int) {
        return imageIndexToInfo(index, block)
    }

    func offsetToImageIndex(_ offset: Int, _ info: BlockInfo) -> Int {
        let column = offset % info.columns
        let row = offset / info.columns
        return row * width * info.h + column * info.w
    }
    func blockOffsetToImageIndex(_ offset: Int) -> Int { return offsetToImageIndex(offset, block) }
    func cbOffsetToImageIndex(_ offset: Int) -> Int { return offsetToImageIndex(offset, cb) }
    func cellOffsetToImageIndex(_ offset: Int) -> Int { return offsetToImageIndex(offset, cell) }

    func imageIndexToXY(_ index: Int) -> (x: Int, y: Int) {
        return (index % width, index / width)
    }
    func xyToImageIndex(_ x: Int, _ y: Int) -> Int? {
        if x < 0 || y < 0 || x >= width || y >= height { return nil }
        return y * width + x
    }

    // -- Histogram helpers --

    func currentColorAtXY(_ x: Int, _ y: Int, _ orColor: Int? = nil) -> Int? {
        if let i = xyToImageIndex(x, y) { return indexed[i] }
        return orColor
    }

    func addToHistogramFromCurrentColor(_ color: Int, _ histogram: inout [Int]) {
        if color >= 0 && color < histogram.count {
            histogram[color] += histogramScoreCurrent
        }
    }

    func addToHistogramAtOffsetFromCurrentColor(
        _ offset: Int,
        _ info: BlockInfo,
        _ histogram: inout [Int],
        _ colors: [Int]? = nil,
        _ orColor: Int? = nil,
        _ fnAdd: ((Int, Int, Int?, inout [Int]) -> Void)? = nil
    ) {
        let imageIndex = offsetToImageIndex(offset, info)
        let start = imageIndexToXY(imageIndex)
        for y in (start.y - info.yb)..<(start.y + info.h + info.yb) {
            for x in (start.x - info.xb)..<(start.x + info.w + info.xb) {
                let color = currentColorAtXY(x, y, orColor)
                if let allowed = colors {
                    if let c = color, !allowed.contains(c) { continue }
                    if color == nil { continue }
                }
                if let fn = fnAdd {
                    fn(x, y, color, &histogram)
                } else {
                    if let c = color { addToHistogramFromCurrentColor(c, &histogram) }
                }
            }
        }
    }

    func addToBlockHistogramFromCurrentColor(_ offset: Int, _ histogram: inout [Int],
                                             _ colors: [Int]? = nil, _ orColor: Int? = nil,
                                             _ fnAdd: ((Int, Int, Int?, inout [Int]) -> Void)? = nil) {
        addToHistogramAtOffsetFromCurrentColor(offset, block, &histogram, colors, orColor, fnAdd)
    }
    func addToCbHistogramFromCurrentColor(_ offset: Int, _ histogram: inout [Int],
                                          _ colors: [Int]? = nil, _ orColor: Int? = nil,
                                          _ fnAdd: ((Int, Int, Int?, inout [Int]) -> Void)? = nil) {
        addToHistogramAtOffsetFromCurrentColor(offset, cb, &histogram, colors, orColor, fnAdd)
    }
    func addToCellHistogramFromCurrentColor(_ offset: Int, _ histogram: inout [Int],
                                            _ colors: [Int]? = nil, _ orColor: Int? = nil,
                                            _ fnAdd: ((Int, Int, Int?, inout [Int]) -> Void)? = nil) {
        addToHistogramAtOffsetFromCurrentColor(offset, cell, &histogram, colors, orColor, fnAdd)
    }

    func scoreColorAtXYFrom(_ x: Int, _ y: Int, _ scores: inout [Int],
                            _ colors: [Int]?, _ from: [UInt32]) -> ClosestScore? {
        guard let imageIndex = xyToImageIndex(x, y) else { return nil }
        let rgb = from[imageIndex]
        let upper = colors?.count ?? scores.count
        var closestColor = -1
        var closestScore = Double.greatestFiniteMagnitude
        for i in 0..<upper {
            let palIdx = colors == nil ? i : colors![i]
            let rgbPal = pal[palIdx]
            let sc = errfn(rgb, rgbPal)
            if palIdx >= 0 && palIdx < scores.count {
                scores[palIdx] += Int(sc)
            }
            if sc < closestScore {
                closestScore = sc
                closestColor = palIdx
            }
        }
        return closestColor < 0 ? nil : ClosestScore(closestColor: closestColor, closestScore: closestScore)
    }

    func addToHistogramFromClosest(_ closest: ClosestScore, _ histogram: inout [Int]) {
        let i = closest.closestColor
        if i >= 0 && i < histogram.count {
            histogram[i] += 1 + noise
        }
    }

    func addToHistogramAtOffsetFrom(
        _ offset: Int, _ info: BlockInfo,
        _ histogram: inout [Int], _ scores: inout [Int],
        _ colors: [Int]?, _ from: [UInt32]
    ) -> [ScoredColorChoice] {
        let imageIndex = offsetToImageIndex(offset, info)
        let start = imageIndexToXY(imageIndex)
        for y in (start.y - info.yb)..<(start.y + info.h + info.yb) {
            for x in (start.x - info.xb)..<(start.x + info.w + info.xb) {
                if let closest = scoreColorAtXYFrom(x, y, &scores, colors, from) {
                    addToHistogramFromClosest(closest, &histogram)
                }
            }
        }
        if let cs = colors {
            return cs.map { ScoredColorChoice(ind: $0, count: histogram[$0], score: scores[$0]) }
        }
        return (0..<scores.count).map { ScoredColorChoice(ind: $0, count: histogram[$0], score: scores[$0]) }
    }

    func addToBlockHistogramFrom(_ offset: Int, _ histogram: inout [Int], _ scores: inout [Int],
                                 _ colors: [Int]?, _ from: [UInt32]) -> [ScoredColorChoice] {
        return addToHistogramAtOffsetFrom(offset, block, &histogram, &scores, colors, from)
    }
    func addToBlockHistogramFromAlt(_ offset: Int, _ histogram: inout [Int], _ scores: inout [Int],
                                    _ colors: [Int]? = nil) -> [ScoredColorChoice] {
        return addToHistogramAtOffsetFrom(offset, block, &histogram, &scores, colors, alt)
    }
    func addToBlockHistogramFromRef(_ offset: Int, _ histogram: inout [Int], _ scores: inout [Int],
                                    _ colors: [Int]? = nil) -> [ScoredColorChoice] {
        return addToHistogramAtOffsetFrom(offset, block, &histogram, &scores, colors, ref)
    }
    func addToCbHistogramFrom(_ offset: Int, _ histogram: inout [Int], _ scores: inout [Int],
                              _ colors: [Int]?, _ from: [UInt32]) -> [ScoredColorChoice] {
        return addToHistogramAtOffsetFrom(offset, cb, &histogram, &scores, colors, from)
    }
    func addToCbHistogramFromAlt(_ offset: Int, _ histogram: inout [Int], _ scores: inout [Int],
                                 _ colors: [Int]? = nil) -> [ScoredColorChoice] {
        return addToHistogramAtOffsetFrom(offset, cb, &histogram, &scores, colors, alt)
    }
    func addToCbHistogramFromRef(_ offset: Int, _ histogram: inout [Int], _ scores: inout [Int],
                                 _ colors: [Int]? = nil) -> [ScoredColorChoice] {
        return addToHistogramAtOffsetFrom(offset, cb, &histogram, &scores, colors, ref)
    }
    func addToCellHistogramFromAlt(_ offset: Int, _ histogram: inout [Int], _ scores: inout [Int],
                                   _ colors: [Int]? = nil) -> [ScoredColorChoice] {
        return addToHistogramAtOffsetFrom(offset, cell, &histogram, &scores, colors, alt)
    }

    func getScoredChoicesByCount(_ scored: [ScoredColorChoice]) -> [ScoredColorChoice] {
        return scored.filter { $0.count > 0 }.sorted { $0.count > $1.count }
    }
    func getScoredChoicesByScore(_ scored: [ScoredColorChoice]) -> [ScoredColorChoice] {
        return scored.filter { $0.count > 0 }.sorted { $0.score < $1.score }
    }

    // -- Param storage helpers --

    func updateColorParam(_ offset: Int, _ params: inout [UInt32], _ colorChoices: [Int],
                          _ overrideFilter: Int? = nil, _ overrideBits: Int? = nil) {
        if offset < 0 || offset >= params.count { return }
        if colorChoices.isEmpty { params[offset] = 0; return }
        var value: UInt32 = 0
        let bits = overrideBits ?? paletteBits
        let filter = UInt32(overrideFilter ?? paletteBitFilter)
        var i = colorChoices.count - 1
        while i >= 0 {
            value <<= UInt32(bits)
            value |= (UInt32(colorChoices[i]) & filter)
            i -= 1
        }
        params[offset] = value
    }

    func updateBlockColorParam(_ offset: Int, _ colors: [Int],
                               _ overrideFilter: Int? = nil, _ overrideBits: Int? = nil) {
        updateColorParam(offset, &blockParams, colors, overrideFilter, overrideBits)
    }
    func updateCbColorParam(_ offset: Int, _ colors: [Int],
                            _ overrideFilter: Int? = nil, _ overrideBits: Int? = nil) {
        updateColorParam(offset, &cbParams, colors, overrideFilter, overrideBits)
    }
    func updateCellColorParam(_ offset: Int, _ colors: [Int],
                              _ overrideFilter: Int? = nil, _ overrideBits: Int? = nil) {
        updateColorParam(offset, &cellParams, colors, overrideFilter, overrideBits)
    }
    func updateExtraColorParam(_ offset: Int, _ colors: [Int],
                               _ overrideFilter: Int? = nil, _ overrideBits: Int? = nil) {
        updateColorParam(offset, &extraParams, colors, overrideFilter, overrideBits)
    }

    func extractColorsFromParams(_ offset: Int, _ params: [UInt32], _ totalToExtract: Int,
                                 _ overrideFilter: Int? = nil, _ overrideBits: Int? = nil) -> [Int] {
        if totalToExtract == 0 || offset < 0 || offset >= params.count { return [] }
        let bits = overrideBits ?? paletteBits
        let filter = UInt32(overrideFilter ?? paletteBitFilter)
        var value = params[offset]
        var out: [Int] = []
        var n = totalToExtract
        while n > 0 {
            out.append(Int(value & filter))
            value >>= UInt32(bits)
            n -= 1
        }
        return out
    }
    func extractColorsFromBlockParams(_ offset: Int, _ total: Int,
                                      _ filter: Int? = nil, _ bits: Int? = nil) -> [Int] {
        return extractColorsFromParams(offset, blockParams, total, filter, bits)
    }
    func extractColorsFromCbParams(_ offset: Int, _ total: Int,
                                   _ filter: Int? = nil, _ bits: Int? = nil) -> [Int] {
        return extractColorsFromParams(offset, cbParams, total, filter, bits)
    }
    func extractColorsFromCellParams(_ offset: Int, _ total: Int,
                                     _ filter: Int? = nil, _ bits: Int? = nil) -> [Int] {
        return extractColorsFromParams(offset, cellParams, total, filter, bits)
    }

    // -- Commit / iterate --

    override func commit() {
        guessExtraParams()
        guessCellParams()
        guessCbParams()
        guessBlockParams()
        firstCommit = false
    }

    override func getValidColors(_ imageIndex: Int) -> [Int] {
        let offset = imageIndexToBlockOffset(imageIndex)
        if fullPaletteMode { return pixelPaletteChoices }
        let extracted = extractColorsFromBlockParams(offset, paletteChoices.colors)
        if globalValid.isEmpty && extracted.count <= paletteChoices.colors {
            return extracted
        }
        var valid = globalValid
        valid.append(contentsOf: extracted)
        let limit = globalValid.count + paletteChoices.colors
        if valid.count > limit { valid = Array(valid.prefix(limit)) }
        return valid
    }

    func guessBlockParams() {
        for i in 0..<blockParams.count { guessBlockParam(i) }
    }
    func guessCbParams() {
        for i in 0..<cbParams.count { guessCbParam(i) }
    }
    func guessCellParams() {
        for i in 0..<cellParams.count { guessCellParam(i) }
    }
    func guessExtraParams() {
        for i in 0..<extraParams.count { guessExtraParam(i) }
    }

    func guessBlockParam(_ offset: Int) {
        if fullPaletteMode { return }
        for i in 0..<histogram.count { histogram[i] = 0 }
        for i in 0..<scores.count { scores[i] = 0 }

        if !firstCommit {
            addToBlockHistogramFromCurrentColor(offset, &histogram, pixelPaletteChoices)
        }
        let from = firstCommit ? ref : alt
        let scored = addToBlockHistogramFrom(offset, &histogram, &scores, pixelPaletteChoices, from)
        let choices = getScoredChoicesByCount(scored)
        var colors = choices.map { $0.ind }.prefix(block.colors - globalValid.count).map { $0 }
        while colors.count < (block.colors - globalValid.count) {
            colors.append(pixelPaletteChoices.first ?? backgroundColor)
        }
        colors.sort()
        updateBlockColorParam(offset, colors)
    }
    func guessCbParam(_ offset: Int) { /* override */ }
    func guessCellParam(_ offset: Int) { /* override */ }
    func guessExtraParam(_ offset: Int) { /* override */ }
}
