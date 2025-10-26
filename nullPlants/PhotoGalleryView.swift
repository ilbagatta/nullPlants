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
    }

    @State private var pendingDeletion: Item? = nil
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(photos.sorted(by: { date($0) > date($1) })) { photo in
                        GeometryReader { geo in
                            let side = geo.size.width
                            Button(action: {
                                onClose()
                                DispatchQueue.main.async {
                                    onSelect(photo)
                                }
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onClose() }
                }
            }
        }
        .confirmationDialog(
            "Eliminare questa foto?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive) {
                if let item = pendingDeletion {
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
