import Foundation
import SwiftUI

/// User-built palette saved across launches. Colors are 0xRRGGBB UInt32 values
/// matching the engine's palette format. Length is bounded to 4...16.
struct UserPalette: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var colors: [UInt32]

    init(id: UUID = UUID(), name: String, colors: [UInt32]) {
        self.id = id
        self.name = name
        self.colors = colors
    }
}

/// Persistent store for user-built palettes. Backed by UserDefaults — small
/// enough that JSON encoding fits comfortably.
@MainActor
final class CustomPaletteStore: ObservableObject {
    @Published private(set) var palettes: [UserPalette]

    private static let key = "ditty.userPalettes.v1"

    init() {
        let data = UserDefaults.standard.data(forKey: CustomPaletteStore.key) ?? Data()
        if let decoded = try? JSONDecoder().decode([UserPalette].self, from: data) {
            self.palettes = decoded
        } else {
            self.palettes = []
        }
    }

    func add(_ palette: UserPalette) {
        palettes.append(palette)
        persist()
    }

    func update(_ palette: UserPalette) {
        guard let i = palettes.firstIndex(where: { $0.id == palette.id }) else { return }
        palettes[i] = palette
        persist()
    }

    func remove(_ id: UUID) {
        palettes.removeAll { $0.id == id }
        persist()
    }

    /// Wipe every saved palette. Used by Settings → Reset Ditty.
    func resetAll() {
        palettes.removeAll()
        UserDefaults.standard.removeObject(forKey: CustomPaletteStore.key)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(palettes) {
            UserDefaults.standard.set(data, forKey: CustomPaletteStore.key)
        }
    }
}
