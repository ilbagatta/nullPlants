import SwiftUI

/// A generic photo gallery view displaying photo thumbnails in a grid.
/// Provide closures to extract filename and date from your item type.
struct PhotoGalleryView<Item: Identifiable>: View {
    let photos: [Item]
    let filename: (Item) -> String
    let date: (Item) -> Date
    let onSelect: (Item) -> Void
    let onClose: () -> Void
    let onDelete: (Item) -> Void

    // A local, mutable copy to reflect deletions immediately in the UI
    @State private var items: [Item] = []

    // Three equal columns with fixed spacing
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8, alignment: .center), count: 3)

    init(
        photos: [Item],
        filename: @escaping (Item) -> String,
        date: @escaping (Item) -> Date,
        onSelect: @escaping (Item) -> Void,
        onClose: @escaping () -> Void,
        onDelete: @escaping (Item) -> Void = { _ in }
    ) {
        self.photos = photos
        self.filename = filename
        self.date = date
        self.onSelect = onSelect
        self.onClose = onClose
        self.onDelete = onDelete

        // Initialize local state from the provided photos
        self._items = State(initialValue: photos)
    }

    @State private var pendingDeletion: Item? = nil
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(items.sorted(by: { date($0) > date($1) })) { photo in
                        GeometryReader { geo in
                            let side = geo.size.width
                            Button(action: {
                                onSelect(photo)
                            }) {
                                ZStack(alignment: .bottomLeading) {
                                    ThumbnailView(imageFilename: filename(photo))
                                        .frame(width: side, height: side)
                                        .clipped()

                                    // Date badge
                                    Text(date(photo).formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(.ultraThinMaterial, in: Capsule())
                                        .padding(6)
                                }
                                .contentShape(Rectangle())
                                .cornerRadius(8)
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    pendingDeletion = photo
                                    showDeleteConfirm = true
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding()
            }
            .navigationTitle("Photos")
        }
        .confirmationDialog(
            "Eliminare questa foto?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive) {
                if let item = pendingDeletion {
                    // Remove from disk using the provided filename extractor
                    let name = filename(item)
                    _ = ImageStorage.deleteImage(name)

                    // Remove from local list to update the grid immediately
                    if let idx = items.firstIndex(where: { $0.id == item.id }) {
                        items.remove(at: idx)
                    }

                    // Notify external handler if provided
                    onDelete(item)
                }
                pendingDeletion = nil
            }
            Button("Annulla", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("Questa azione non può essere annullata.")
        }
    }
}

/// A view for displaying a square thumbnail from a filename.
/// Uses ImageStorage.loadImage(_:) to load the UIImage.
private struct ThumbnailView: View {
    let imageFilename: String

    var body: some View {
        if let uiImage = ImageStorage.loadImage(imageFilename) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                )
        }
    }
}
