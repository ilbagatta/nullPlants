import SwiftUI

/// A generic photo gallery view displaying photo thumbnails in a grid.
/// The generic `Item` must be Identifiable and have properties `imageFilename` and `date`.
struct PhotoGalleryView<Item: Identifiable>: View {
    
    let photos: [Item]
    let imageFilenameKeyPath: KeyPath<Item, String>
    let dateKeyPath: KeyPath<Item, Date>
    let onSelect: (Item) -> Void
    let onClose: () -> Void
    
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    
    /// Initialize the view
    /// - Parameters:
    ///   - photos: The array of photo items to display
    ///   - imageFilename: KeyPath to the image filename property on the item (default \.imageFilename)
    ///   - date: KeyPath to the date property on the item (default \.date)
    ///   - onSelect: Closure called when a photo is tapped
    ///   - onClose: Closure called when the Close button is tapped
    init(
        photos: [Item],
        imageFilename: KeyPath<Item, String> = \Item.imageFilename,
        date: KeyPath<Item, Date> = \Item.date,
        onSelect: @escaping (Item) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.photos = photos
        self.imageFilenameKeyPath = imageFilename
        self.dateKeyPath = date
        self.onSelect = onSelect
        self.onClose = onClose
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(photos.sorted(by: { $0[keyPath: dateKeyPath] > $1[keyPath: dateKeyPath] })) { photo in
                        ThumbnailView(imageFilename: photo[keyPath: imageFilenameKeyPath])
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                            .cornerRadius(8)
                            .onTapGesture {
                                onSelect(photo)
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Photos")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onClose()
                    }
                }
            }
        }
    }
}

/// A view for displaying a square thumbnail from a filename.
/// Uses ImageStorage.loadImage(filename:) to load the UIImage.
private struct ThumbnailView: View {
    let imageFilename: String
    
    var body: some View {
        if let uiImage = ImageStorage.loadImage(filename: imageFilename) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
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
