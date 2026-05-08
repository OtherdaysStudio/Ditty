import Foundation

/// C64 VIC-II canvas. Hires (8x8 with 2 colors) or multicolor (4x8 with 4 colors).
/// Supports FLI mode with optional bug emulation and blanking.
final class VICIICanvas: CommonBlockParamDitherCanvas {

    var fliBug: Bool = true
    var fliBugCbColor: Int = 8
    var fliBugChoiceColor: Int = 15
    var blankLeft: Bool = false
    var blankRight: Bool = false
    var blankColumns: Int = 0

    override func initialize() {
        prepare()
        if fliMode, let fli = sys.fli {
            fliBug = fli.bug
            blankLeft = fli.blankLeft
            blankRight = fli.blankRight
            blankColumns = fli.blankColumns
            if !paletteChoices.background {
                borderColor = fliBugChoiceColor
            }
        }
    }

    func isImageIndexInFliBugBlankingArea(_ index: Int) -> (performBug: Bool, blank: Bool, leftBlank: Bool, rightBlank: Bool, column: Int) {
        let info = imageIndexToBlockInfo(index)
        let column = info.column
        let bugLogic = (fliBug && (column >= 0 && column < blankColumns)) && !blankLeft
        let leftBl = blankLeft && (column >= 0 && column < blankColumns)
        let rightBl = blankLeft && blankRight && (column >= block.columns - blankColumns && column < block.columns)
        let blank = leftBl || rightBl
        return (bugLogic, blank, leftBl, rightBl, column)
    }

    override func getValidColors(_ imageIndex: Int) -> [Int] {
        let offset = imageIndexToBlockOffset(imageIndex)
        let cbOffset = imageIndexToCbOffset(imageIndex)

        let info = isImageIndexInFliBugBlankingArea(imageIndex)
        if info.blank {
            if !paletteChoices.background { return [fliBugChoiceColor] }
            return [backgroundColor]
        }

        var extracted = extractColorsFromBlockParams(offset, paramInfo.cb ? 2 : 3)
        if paramInfo.cb {
            extracted.append(contentsOf: extractColorsFromCbParams(cbOffset, 1))
        }
        if info.performBug {
            // forced override during VIC bad-line stall
            if extracted.count < 3 {
                while extracted.count < 3 { extracted.append(0) }
            }
            extracted[0] = fliBugChoiceColor
            extracted[1] = fliBugChoiceColor
            extracted[2] = fliBugCbColor
        }
        var valid = globalValid
        valid.append(contentsOf: extracted)
        let limit = globalValid.count + paletteChoices.colors
        if valid.count > limit { valid = Array(valid.prefix(limit)) }
        return valid
    }

    override func guessBlockParam(_ offset: Int) {
        let imageIndex = blockOffsetToImageIndex(offset)
        let cbOffset = imageIndexToCbOffset(imageIndex)
        let info = isImageIndexInFliBugBlankingArea(imageIndex)

        var cbColor: Int = 0
        var pixelChoices = pixelPaletteChoices

        if paramInfo.cb {
            let cbExtracted = extractColorsFromCbParams(cbOffset, 1)
            if let first = cbExtracted.first {
                pixelChoices = spliceColor(first, pixelPaletteChoices)
            }
        }

        for i in 0..<histogram.count { histogram[i] = 0 }
        for i in 0..<scores.count { scores[i] = 0 }

        if !firstCommit {
            addToBlockHistogramFromCurrentColor(offset, &histogram, pixelChoices)
        }
        let from = firstCommit ? ref : alt
        let scored = addToBlockHistogramFrom(offset, &histogram, &scores, pixelChoices, from)

        if paramInfo.cb {
            let cbExtracted = extractColorsFromCbParams(cbOffset, 1)
            if let cbInd = cbExtracted.first, cbInd < histogram.count {
                histogram[cbInd] = 0
                cbColor = cbInd
            }
        }

        let choices = getScoredChoicesByCount(scored)
        var ind1 = (choices.count > 0) ? choices[0].ind : backgroundColor
        var ind2 = (choices.count > 1) ? choices[1].ind : backgroundColor
        var ind3 = (choices.count > 2) ? choices[2].ind : backgroundColor

        if !paramInfo.cb { cbColor = ind3 }

        if info.leftBlank {
            cbColor = backgroundColor; ind1 = backgroundColor; ind2 = backgroundColor; ind3 = backgroundColor
            if !paletteChoices.background { ind1 = fliBugChoiceColor; ind2 = fliBugChoiceColor }
        } else if info.rightBlank {
            cbColor = backgroundColor; ind1 = backgroundColor; ind2 = backgroundColor; ind3 = backgroundColor
            if !paletteChoices.background { ind1 = fliBugChoiceColor; ind2 = fliBugChoiceColor }
        }

        if info.performBug {
            ind1 = fliBugChoiceColor
            ind2 = fliBugChoiceColor
            cbColor = fliBugCbColor
        }
        _ = ind3

        var subset = [ind1, ind2]
        if subset.count > paletteChoices.colors { subset = Array(subset.prefix(paletteChoices.colors)) }
        subset.sort()
        let sorted = subset + [cbColor]
        updateBlockColorParam(offset, sorted)
    }

    override func guessCbParam(_ offset: Int) {
        if !paramInfo.cb { return }
        if iterateCount > Dithertron.maxIterateCount / 2 { return }

        let imageIndex = cbOffsetToImageIndex(offset)
        let info = isImageIndexInFliBugBlankingArea(imageIndex)

        for i in 0..<histogram.count { histogram[i] = 0 }
        for i in 0..<scores.count { scores[i] = 0 }

        if !firstCommit {
            addToCbHistogramFromCurrentColor(offset, &histogram, pixelPaletteChoices)
        }
        let from = firstCommit ? ref : alt
        let scored = addToCbHistogramFrom(offset, &histogram, &scores, pixelPaletteChoices, from)
        let choices = getScoredChoicesByCount(scored)
        var cbColor = choices.first?.ind ?? backgroundColor

        if info.leftBlank {
            cbColor = backgroundColor
            if !paletteChoices.background { cbColor = fliBugCbColor }
        } else if info.rightBlank {
            cbColor = backgroundColor
            if !paletteChoices.background { cbColor = fliBugCbColor }
        }
        if info.performBug, !paletteChoices.background { cbColor = fliBugChoiceColor }

        updateCbColorParam(offset, [cbColor])
    }
}
