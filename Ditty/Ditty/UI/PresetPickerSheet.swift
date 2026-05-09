import SwiftUI

/// Lists every saved per-system FX preset. Tapping one switches to that
/// system, which fires the view-model's preset-restore path. Reached from
/// the FX editor's preset row.
struct PresetPickerSheet: View {
    @ObservedObject var vm: DittyViewModel
    @Environment(\.dismiss) private var dismiss

    private var systemNamesById: [String: String] {
        Dictionary(uniqueKeysWithValues: Systems.all.map { ($0.id, $0.name) })
    }

    private var sortedEntries: [(key: String, value: SystemFXPreset)] {
        let names = systemNamesById
        return vm.presetStore.presets.sorted { lhs, rhs in
            (names[lhs.key] ?? lhs.key) < (names[rhs.key] ?? rhs.key)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if sortedEntries.isEmpty {
                        emptyState
                    } else {
                        ForEach(sortedEntries, id: \.key) { entry in
                            row(systemId: entry.key, preset: entry.value)
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 1)
                        }
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(systemId: String, preset: SystemFXPreset) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // Switching systems fires didSet → applyPresetIfAny → restores
            // the saved values. Same path used at app launch.
            vm.systemId = systemId
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(red: 0.99, green: 0.78, blue: 0.27))
                        Text(systemNamesById[systemId] ?? systemId)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        if vm.systemId == systemId {
                            Text("· current")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    Text(detailLine(for: preset))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bookmark")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.4))
            Text("No saved presets yet")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Text("In the FX panel, tap Save to bookmark the current\nsystem's diffuse, ordered, and diversity values.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 32)
    }

    private func detailLine(for preset: SystemFXPreset) -> String {
        // Compact, scannable values — kernel · diffuse · diversity. Matches the
        // detail line shown in Settings' preset rows.
        return "\(preset.ditherKernelId) · diff \(String(format: "%.2f", preset.diffuse)) · div \(String(format: "%.2f", preset.diversity))"
    }
}
