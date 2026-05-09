import Foundation

enum Systems {

    static let all: [DithertronSettings] = [
        // ----- Free palette systems (DitheringCanvas) -----
        DithertronSettings(
            id: "pico8", name: "PICO-8",
            width: 128, height: 128,
            conv: "DitheringCanvas",
            pal: Palettes.pico8
        ),
        DithertronSettings(
            id: "tic80", name: "TIC-80",
            width: 240, height: 136,
            conv: "DitheringCanvas",
            pal: Palettes.tic80
        ),
        DithertronSettings(
            id: "gb", name: "Game Boy",
            width: 160, height: 144,
            conv: "DitheringCanvas",
            pal: Palettes.gameboyGreen,
            scaleX: 10.0/9.0
        ),
        DithertronSettings(
            id: "gbc", name: "Game Boy Color",
            width: 160, height: 144,
            conv: "DitheringCanvas",
            pal: Palettes.gameboyColor,
            reduce: 16
        ),
        DithertronSettings(
            id: "atarist", name: "Atari ST",
            width: 320, height: 200,
            conv: "DitheringCanvas",
            pal: Palettes.atariST,
            reduce: 16
        ),
        DithertronSettings(
            id: "amiga.lores", name: "Amiga (Lores)",
            width: 320, height: 256,
            conv: "DitheringCanvas",
            pal: Palettes.amigaOCS,
            reduce: 32
        ),
        DithertronSettings(
            id: "amiga.lores.ham6", name: "Amiga HAM6",
            width: 320, height: 256,
            conv: "HAM6Canvas",
            pal: Palettes.amigaOCS,
            reduce: 16,
            extraColors: 48
        ),
        DithertronSettings(
            id: "appleiigs.320.16", name: "Apple IIGS (16 colors)",
            width: 320, height: 200,
            conv: "DitheringCanvas",
            pal: Palettes.iigs,
            reduce: 16
        ),
        DithertronSettings(
            id: "mac128", name: "Mac 128K",
            width: 512, height: 342,
            conv: "DitheringCanvas",
            pal: Palettes.mono
        ),
        DithertronSettings(
            id: "atari8.d", name: "Atari ANTIC (Mode D)",
            width: 160, height: 96,
            conv: "DitheringCanvas",
            pal: Palettes.vcs,
            scaleX: 0.8571,
            reduce: 4
        ),
        DithertronSettings(
            id: "atari8.f10", name: "Atari ANTIC (Mode F/10)",
            width: 80, height: 192,
            conv: "DitheringCanvas",
            pal: Palettes.vcs,
            scaleX: 0.8571 * 4,
            reduce: 9
        ),
        DithertronSettings(
            id: "atari7800.160a", name: "Atari 7800 (160A)",
            width: 160, height: 240,
            conv: "DitheringCanvas",
            pal: Palettes.vcs,
            scaleX: 2,
            reduce: 4
        ),
        DithertronSettings(
            id: "vcs", name: "Atari VCS",
            width: 40, height: 192,
            conv: "DitheringCanvas",
            pal: Palettes.vcs,
            scaleX: 6,
            reduce: 2
        ),
        DithertronSettings(
            id: "vcs.color", name: "Atari VCS (Color Playfield)",
            width: 40, height: 192,
            conv: "VCSColorPlayfieldCanvas",
            pal: Palettes.vcs,
            scaleX: 6
        ),
        DithertronSettings(
            id: "vcs.color.il", name: "Atari VCS (Interlaced)",
            width: 40, height: 192,
            conv: "VCSInterlacedCanvas",
            pal: Palettes.vcs,
            scaleX: 6
        ),
        DithertronSettings(
            id: "astrocade", name: "Bally Astrocade",
            width: 160, height: 98,
            conv: "DitheringCanvas",
            pal: Palettes.astrocade,
            reduce: 4
        ),
        DithertronSettings(
            id: "nes", name: "NES (4 color, 240 tiles)",
            width: 160, height: 96,
            conv: "DitheringCanvas",
            pal: Palettes.nes,
            scaleX: 8.0/7.0,
            reduce: 4
        ),
        DithertronSettings(
            id: "nes.full", name: "NES (4 color, full screen)",
            width: 256, height: 240,
            conv: "DitheringCanvas",
            pal: Palettes.nes,
            scaleX: 8.0/7.0,
            reduce: 4
        ),
        DithertronSettings(
            id: "nes5f", name: "NES (5 color, full screen)",
            width: 256, height: 240,
            conv: "NESCanvas",
            pal: Palettes.nes,
            scaleX: 8.0/7.0,
            reduce: 5
        ),
        DithertronSettings(
            id: "sms", name: "Sega Master System",
            width: 176, height: 144,
            conv: "DitheringCanvas",
            pal: Palettes.sms,
            scaleX: 8.0/7.0,
            reduce: 16
        ),
        DithertronSettings(
            id: "sms-gg", name: "Sega Game Gear",
            width: 160, height: 144,
            conv: "DitheringCanvas",
            pal: Palettes.gameGear,
            scaleX: 1.2,
            reduce: 16
        ),
        DithertronSettings(
            id: "williams", name: "Williams Arcade",
            width: 304, height: 256,
            conv: "DitheringCanvas",
            pal: Palettes.williams,
            reduce: 16
        ),
        DithertronSettings(
            id: "channelf", name: "Fairchild Channel F",
            width: 102, height: 58,
            conv: "DitheringCanvas",
            pal: Palettes.channelF,
            reduce: 4
        ),
        DithertronSettings(
            id: "bbcmicro.mode1", name: "BBC Micro (Mode 1)",
            width: 320, height: 256,
            conv: "DitheringCanvas",
            pal: Palettes.teletext,
            reduce: 4
        ),
        DithertronSettings(
            id: "bbcmicro.mode2", name: "BBC Micro (Mode 2)",
            width: 160, height: 256,
            conv: "DitheringCanvas",
            pal: Palettes.teletext,
            scaleX: 2
        ),
        DithertronSettings(
            id: "bbcmicro.mode5", name: "BBC Micro (Mode 5)",
            width: 160, height: 256,
            conv: "DitheringCanvas",
            pal: Palettes.teletext,
            scaleX: 2,
            reduce: 4
        ),
        DithertronSettings(
            id: "msx2.screen5", name: "MSX2 (Screen 5)",
            width: 256, height: 212,
            conv: "DitheringCanvas",
            pal: Palettes.msx2,
            reduce: 16
        ),
        DithertronSettings(
            id: "lynx", name: "Atari Lynx",
            width: 160, height: 102,
            conv: "DitheringCanvas",
            pal: Palettes.lynx,
            reduce: 16
        ),
        DithertronSettings(
            id: "vectrex", name: "Vectrex",
            width: 330, height: 410,
            conv: "DitheringCanvas",
            pal: Palettes.vectrex
        ),
        DithertronSettings(
            id: "phomemo.landscape", name: "Phomemo D30 (landscape)",
            width: 288, height: 88,
            conv: "DitheringCanvas",
            pal: Palettes.mono
        ),
        DithertronSettings(
            id: "phomemo.portrait", name: "Phomemo D30 (portrait)",
            width: 88, height: 288,
            conv: "DitheringCanvas",
            pal: Palettes.mono
        ),

        // ----- CGA / EGA -----
        DithertronSettings(
            id: "x86.cga.04h.1", name: "PC CGA (Mode 04h, palette 1)",
            width: 320, height: 200,
            conv: "DitheringCanvas",
            pal: Palettes.cga1,
            scaleX: 200.0/320.0 * 1.37
        ),
        DithertronSettings(
            id: "x86.cga.04h.1B", name: "PC CGA (Mode 04h, bright 1)",
            width: 320, height: 200,
            conv: "DitheringCanvas",
            pal: Palettes.cga1H,
            scaleX: 200.0/320.0 * 1.37
        ),
        DithertronSettings(
            id: "x86.cga.04h.2", name: "PC CGA (Mode 04h, palette 2)",
            width: 320, height: 200,
            conv: "DitheringCanvas",
            pal: Palettes.cga2,
            scaleX: 200.0/320.0 * 1.37
        ),
        DithertronSettings(
            id: "x86.cga.04h.2B", name: "PC CGA (Mode 04h, bright 2)",
            width: 320, height: 200,
            conv: "DitheringCanvas",
            pal: Palettes.cga2H,
            scaleX: 200.0/320.0 * 1.37
        ),
        DithertronSettings(
            id: "x86.ega.0dh", name: "PC EGA (Mode 0Dh)",
            width: 320, height: 200,
            conv: "DitheringCanvas",
            pal: Palettes.cga,
            scaleX: 200.0/320.0 * 1.37
        ),

        // ----- Amstrad CPC -----
        DithertronSettings(
            id: "cpc.mode0", name: "Amstrad CPC (mode 0)",
            width: 160, height: 200,
            conv: "DitheringCanvas",
            pal: Palettes.amstradCPC,
            scaleX: 2,
            reduce: 16
        ),
        DithertronSettings(
            id: "cpc.mode1", name: "Amstrad CPC (mode 1)",
            width: 320, height: 200,
            conv: "DitheringCanvas",
            pal: Palettes.amstradCPC,
            reduce: 4
        ),

        // ----- Cell-constrained systems -----
        DithertronSettings(
            id: "c64.multi", name: "C-64 Multicolor",
            width: 160, height: 200,
            conv: "VICIICanvas",
            pal: Palettes.vicPAL,
            scaleX: 0.936 * 2,
            block: BlockSpec(w: 4, h: 8, colors: 4, xb: 1, yb: 2),
            cell: CellSpec(w: 4, h: 8),
            cb: CbSpec(w: 4, h: 8, xb: 1, yb: 2),
            paletteChoices: PartialPaletteChoices(background: true),
            param: ParamSpec(extra: 1)
        ),
        DithertronSettings(
            id: "c64.hires", name: "C-64 Hires",
            width: 320, height: 200,
            conv: "VICIICanvas",
            pal: Palettes.vicPAL,
            scaleX: 0.936,
            block: BlockSpec(w: 8, h: 8, colors: 2),
            cell: CellSpec(w: 8, h: 8),
            param: ParamSpec(extra: 1)
        ),
        DithertronSettings(
            id: "c64.multi.fli", name: "C-64 Multi FLI (no bug)",
            width: 160, height: 200,
            conv: "VICIICanvas",
            pal: Palettes.vicPAL,
            scaleX: 0.936 * 2,
            block: BlockSpec(w: 4, h: 1, colors: 4, xb: 1),
            cell: CellSpec(w: 4, h: 8),
            cb: CbSpec(w: 4, h: 8, xb: 1, yb: 2),
            paletteChoices: PartialPaletteChoices(background: true),
            param: ParamSpec(extra: 1),
            fli: FliSpec(bug: false, blankLeft: false, blankRight: false, blankColumns: 3)
        ),
        DithertronSettings(
            id: "c64.multi.fli.bug", name: "C-64 Multi FLI (with bug)",
            width: 160, height: 200,
            conv: "VICIICanvas",
            pal: Palettes.vicPAL,
            scaleX: 0.936 * 2,
            block: BlockSpec(w: 4, h: 1, colors: 4, xb: 1),
            cell: CellSpec(w: 4, h: 8),
            cb: CbSpec(w: 4, h: 8, xb: 1, yb: 2),
            paletteChoices: PartialPaletteChoices(background: true),
            param: ParamSpec(extra: 1),
            fli: FliSpec(bug: true, blankLeft: false, blankRight: false, blankColumns: 3)
        ),
        DithertronSettings(
            id: "c64.multi.fli.blank", name: "C-64 Multi FLI (L/R blank)",
            width: 160, height: 200,
            conv: "VICIICanvas",
            pal: Palettes.vicPAL,
            scaleX: 0.936 * 2,
            block: BlockSpec(w: 4, h: 1, colors: 4, xb: 1),
            cell: CellSpec(w: 4, h: 8),
            cb: CbSpec(w: 4, h: 8, xb: 1, yb: 2),
            paletteChoices: PartialPaletteChoices(background: true),
            param: ParamSpec(extra: 1),
            fli: FliSpec(bug: false, blankLeft: true, blankRight: true, blankColumns: 3)
        ),

        // ----- ZX Spectrum -----
        DithertronSettings(
            id: "zx", name: "ZX Spectrum",
            width: 256, height: 192,
            conv: "ZXSpectrumCanvas",
            pal: Palettes.zxSpectrum,
            block: BlockSpec(w: 8, h: 8, colors: 2),
            cell: CellSpec(w: 8, h: 8)
        ),
        DithertronSettings(
            id: "zx.dark", name: "ZX Spectrum (dark only)",
            width: 256, height: 192,
            conv: "ZXSpectrumCanvas",
            pal: Palettes.zxSpectrum,
            block: BlockSpec(w: 8, h: 8, colors: 2),
            cell: CellSpec(w: 8, h: 8),
            paletteChoices: PartialPaletteChoices(colorsRange: PaletteRange(min: 0, max: 7))
        ),
        DithertronSettings(
            id: "zx.bright", name: "ZX Spectrum (bright only)",
            width: 256, height: 192,
            conv: "ZXSpectrumCanvas",
            pal: Palettes.zxSpectrum,
            block: BlockSpec(w: 8, h: 8, colors: 2),
            cell: CellSpec(w: 8, h: 8),
            paletteChoices: PartialPaletteChoices(colorsRange: PaletteRange(min: 8, max: 15))
        ),

        // ----- MSX -----
        DithertronSettings(
            id: "msx", name: "MSX/Coleco (TMS9918A)",
            width: 256, height: 192,
            conv: "MSXCanvas",
            pal: Palettes.tms9918,
            block: BlockSpec(w: 8, h: 1, colors: 2),
            cell: CellSpec(w: 8, h: 8)
        ),

        // ----- Apple II -----
        DithertronSettings(
            id: "apple2.hires", name: "Apple ][ (Hires)",
            width: 140, height: 192,
            conv: "Apple2Canvas",
            pal: Palettes.ap2hires,
            scaleX: 2,
            block: BlockSpec(w: 7, h: 1, colors: 4)
        ),
        DithertronSettings(
            id: "apple2.lores", name: "Apple ][ (Lores)",
            width: 40, height: 48,
            conv: "DitheringCanvas",
            pal: Palettes.ap2lores,
            scaleX: 1.5
        ),
        DithertronSettings(
            id: "apple2.dblhires", name: "Apple ][ (Double-Hires)",
            width: 140, height: 192,
            conv: "DitheringCanvas",
            pal: Palettes.ap2lores,
            scaleX: 2
        ),

        // ----- Compucolor / Teletext -----
        DithertronSettings(
            id: "compucolor", name: "Compucolor",
            width: 160, height: 192,
            conv: "CompucolorCanvas",
            pal: Palettes.zxSpectrum,
            scaleX: 1.6,
            block: BlockSpec(w: 2, h: 4, colors: 2)
        ),
        DithertronSettings(
            id: "teletext", name: "Teletext",
            width: 80, height: 72,
            conv: "TeletextCanvas",
            pal: Palettes.teletext,
            scaleX: 4.0/3.0,
            block: BlockSpec(w: 2, h: 3, colors: 2)
        ),

        // ----- MC6847 -----
        DithertronSettings(
            id: "mc6847.cg2.0", name: "MC6847 (CG2, palette 0)",
            width: 128, height: 64,
            conv: "DitheringCanvas",
            pal: Palettes.mc6847_palette0,
            scaleX: 1.0/1.3,
            reduce: 4
        ),
        DithertronSettings(
            id: "mc6847.cg6.0", name: "MC6847 (CG6, palette 0)",
            width: 128, height: 192,
            conv: "DitheringCanvas",
            pal: Palettes.mc6847_palette0,
            scaleX: 1.0/1.3 * 192.0/64.0,
            reduce: 4
        ),
    ]

    static let lookup: [String: DithertronSettings] = {
        var m = [String: DithertronSettings]()
        for sys in all { m[sys.id] = sys }
        return m
    }()
}
