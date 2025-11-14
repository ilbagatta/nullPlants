import SwiftUI
import UIKit

struct FullScreenPhotoItem: Identifiable, Hashable {
    let id = UUID()
    let filename: String
    let date: Date?
}

struct FullScreenPhotoView: View {
    let items: [FullScreenPhotoItem]
    let initialIndex: Int
    var onShare: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int
    @State private var currentImageForShare: UIImage? = nil
    
    init(items: [FullScreenPhotoItem], initialIndex: Int, onShare: @escaping (UIImage) -> Void) {
        self.items = items
        self.initialIndex = initialIndex
        self.onShare = onShare
        _selection = State(initialValue: initialIndex)
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(items.indices, id: \.self) { idx in
                    SinglePhotoZoomableView(
                        filename: items[idx].filename,
                        initialImage: nil,
                        date: items[idx].date,
                        onShare: onShare,
                        onImageLoaded: { img in
                            if selection == idx {
                                currentImageForShare = img
                            }
                        }
                    )
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .navigationTitle(items[safe: selection]?.date?.formatted(date: .abbreviated, time: .omitted) ?? "Foto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Label("Indietro", systemImage: "chevron.backward")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if let img = currentImageForShare { onShare(img) }
                    }) {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                if items.indices.contains(initialIndex) {
                    selection = initialIndex
                } else {
                    selection = items.startIndex
                }
                currentImageForShare = nil
            }
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
