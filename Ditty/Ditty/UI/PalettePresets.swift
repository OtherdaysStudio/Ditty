import Foundation

/// A named palette preset the user can apply via the Palette tab in the
/// effects editor. The colors are 0xRRGGBB UInt32 values matching the engine's
/// palette format.
struct PalettePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let colors: [UInt32]
}

enum PalettePresets {
    static let all: [PalettePreset] = [
        PalettePreset(id: "gameboy",     name: "Game Boy",      colors: Palettes.gameboyGreen),
        PalettePreset(id: "gameboy.gray",name: "Game Boy DMG",  colors: Palettes.gameboyMono),
        PalettePreset(id: "1bit",        name: "1-Bit",         colors: [0x000000, 0xFFFFFF]),
        PalettePreset(id: "c64",         name: "C-64",          colors: Palettes.vicNTSC),
        PalettePreset(id: "zx",          name: "ZX Spectrum",   colors: Palettes.zxSpectrum),
        PalettePreset(id: "cpc",         name: "Amstrad CPC",   colors: Palettes.amstradCPC),
        PalettePreset(id: "cga",         name: "PC CGA",        colors: Palettes.cga),
        PalettePreset(id: "sunset",      name: "Sunset",        colors: [0x102447, 0x4d2a52, 0x8a3a4a, 0xc94c2c, 0xf08522, 0xfdce5b]),
        PalettePreset(id: "forest",      name: "Forest",        colors: [0x1a2a1a, 0x2d4a3e, 0x537761, 0xa3b18a, 0xdde0bd]),
        PalettePreset(id: "cyberpunk",   name: "Cyberpunk",     colors: [0x0d0221, 0x261447, 0xff0080, 0x00f5ff, 0xfffe00]),
        PalettePreset(id: "sepia",       name: "Sepia",         colors: [0x1c1209, 0x462a14, 0x7d4a1f, 0xc1893a, 0xf0d4a1]),
        PalettePreset(id: "pastel",      name: "Pastel",        colors: [0xfaf3dd, 0xc8d5b9, 0x8fc0a9, 0x68b0ab, 0x4a7c59]),
    ]
}
