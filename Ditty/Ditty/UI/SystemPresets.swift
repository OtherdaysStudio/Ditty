import Foundation

/// Saved per-system FX defaults — the user can save "my Game Boy look" and
/// every time they switch back to that system the diffuse / ordered / noise /
/// diversity / kernel values get restored.
struct SystemFXPreset: Codable, Hashable {
    var ditherKernelId: String
    var diffuse: Double
    var ordered: Double
    var noise: Int
    var diversity: Double
}

/// Persistent store for per-system FX presets, keyed by system id.
@MainActor
final class SystemFXPresetStore: ObservableObject {
    @Published private(set) var presets: [String: SystemFXPreset]

    private static let key = "ditty.systemFXPresets.v1"

    init() {
        let data = UserDefaults.standard.data(forKey: SystemFXPresetStore.key) ?? Data()
        if let decoded = try? JSONDecoder().decode([String: SystemFXPreset].self, from: data) {
            self.presets = decoded
        } else {
            self.presets = [:]
        }
    }

    func save(systemId: String, preset: SystemFXPreset) {
        presets[systemId] = preset
        persist()
    }

    func reset(systemId: String) {
        presets.removeValue(forKey: systemId)
        persist()
    }

    func preset(for systemId: String) -> SystemFXPreset? {
        presets[systemId]
    }

    /// Wipe every saved preset. Used by Settings → Reset Ditty.
    func resetAll() {
        presets.removeAll()
        UserDefaults.standard.removeObject(forKey: SystemFXPresetStore.key)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: SystemFXPresetStore.key)
        }
    }
}
