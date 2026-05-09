import Foundation
import SwiftUI

/// User-favorited system IDs. Backed by UserDefaults so the carousel
/// remembers favorites across launches. Long-press a pill in the carousel
/// to toggle favorite state.
@MainActor
final class SystemFavorites: ObservableObject {
    @Published private(set) var ids: Set<String>

    private static let key = "ditty.favoriteSystemIds"

    init() {
        let arr = UserDefaults.standard.stringArray(forKey: SystemFavorites.key) ?? []
        self.ids = Set(arr)
    }

    func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        UserDefaults.standard.set(Array(ids), forKey: SystemFavorites.key)
    }

    func contains(_ id: String) -> Bool { ids.contains(id) }
}
