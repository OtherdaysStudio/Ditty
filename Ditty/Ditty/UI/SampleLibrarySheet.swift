import SwiftUI
import UIKit

/// Curated sample image library — gives users a quick way to try systems
/// without pointing the camera at their desk. Images are bundled with the app
/// under `Sample.bundle/`. Drop new JPGs into that folder and they'll appear
/// here automatically.
struct SampleLibrarySheet: View {
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var samples: [SampleImage] = []

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(samples) { sample in
                        Button {
                            if let img = UIImage(contentsOfFile: sample.url.path) {
                                onPick(img)
                                dismiss()
                            }
                        } label: {
                            tile(for: sample)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)

                if samples.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Samples coming soon")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Curated photos that look great after dithering.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 32)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Samples")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { loadSamples() }
    }

    private func tile(for sample: SampleImage) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let preview = sample.preview {
                Image(uiImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 160)
                    .overlay(ProgressView().tint(.white.opacity(0.6)))
            }
            Text(sample.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(8)
                .background(.black.opacity(0.4), in: Capsule())
                .padding(8)
        }
    }

    private func loadSamples() {
        guard let bundleURL = Bundle.main.url(forResource: "Sample", withExtension: "bundle") else {
            samples = []
            return
        }
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: bundleURL,
                                                 includingPropertiesForKeys: nil)) ?? []
        let imageURLs = files.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "heic"
        }
        samples = imageURLs.map { url in
            let title = url.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            return SampleImage(url: url, title: title)
        }
        // Lazy thumbnail load — bigger images would otherwise stall the open.
        let urls = samples.map { $0.url }
        Task { @MainActor in
            for (i, url) in urls.enumerated() {
                let preview: UIImage? = await Task.detached(priority: .userInitiated) {
                    guard let data = try? Data(contentsOf: url),
                          let img = UIImage(data: data) else { return nil }
                    return img.preparingThumbnail(of: CGSize(width: 320, height: 320)) ?? img
                }.value
                if let preview, i < samples.count, samples[i].url == url {
                    samples[i].preview = preview
                }
            }
        }
    }
}

struct SampleImage: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let title: String
    var preview: UIImage? = nil

    static func == (lhs: SampleImage, rhs: SampleImage) -> Bool {
        lhs.url == rhs.url
    }
}
