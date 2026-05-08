import SwiftUI

/// Quick "jump to" picker for the dithering system. Reached by long-pressing
/// the photo viewport. Avoids the slow swipe-through-all-48 dance.
///
/// Free systems are listed first; Pro-only systems show a small lock badge.
struct SystemPickerSheet: View {
    let systems: [DithertronSettings]
    let currentId: String
    let isPro: Bool
    let isFree: (String) -> Bool
    let onPick: (DithertronSettings) -> Void
    let onLockedPick: () -> Void

    @State private var query: String = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [DithertronSettings] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return systems }
        return systems.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { sys in
                        let locked = !isPro && !isFree(sys.id)
                        Button {
                            if locked {
                                onLockedPick()
                            } else {
                                onPick(sys)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text(sys.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                if sys.id == currentId {
                                    Image(systemName: "checkmark")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(Color(red: 0.99, green: 0.78, blue: 0.27))
                                }
                                Spacer()
                                if locked {
                                    Image(systemName: "lock.fill")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Pick System")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $query, prompt: "Search systems")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
