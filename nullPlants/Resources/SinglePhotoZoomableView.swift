import SwiftUI
import UIKit

public struct SinglePhotoZoomableView: View {
    public let filename: String?
    public let initialImage: UIImage?
    public var date: Date? = nil
    public var onShare: (UIImage) -> Void
    public var onImageLoaded: (UIImage) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    @State private var zoomScale: CGFloat = 1.0
    @State private var steadyZoomScale: CGFloat = 1.0
    @State private var pinchZoomDelta: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    @State private var currentImage: UIImage? = nil
    @State private var isLoading: Bool = false
    @State private var loadError: Bool = false

    private func fittedSize(for image: UIImage, in container: CGSize) -> CGSize {
        let imageRatio = image.size.width / image.size.height
        let containerRatio = container.width / container.height
        if imageRatio > containerRatio {
            let width = container.width
            let height = width / imageRatio
            return CGSize(width: width, height: height)
        } else {
            let height = container.height
            let width = height * imageRatio
            return CGSize(width: width, height: height)
        }
    }

    private func clampedOffset(_ offset: CGSize, image: UIImage, container: CGSize, scale: CGFloat) -> CGSize {
        let fitted = fittedSize(for: image, in: container)
        let scaledImageSize = CGSize(width: fitted.width * scale, height: fitted.height * scale)

        var newOffset = offset

        let horizontalOverflow = max(0, (scaledImageSize.width - container.width) / 2)
        let verticalOverflow = max(0, (scaledImageSize.height - container.height) / 2)

        newOffset.width = min(horizontalOverflow, max(-horizontalOverflow, offset.width))
        newOffset.height = min(verticalOverflow, max(-verticalOverflow, offset.height))

        return newOffset
    }

    private func loadImageIfNeeded(force: Bool = false) {
        guard !isLoading else { return }
        guard currentImage == nil || force else { return }
        guard let filename = filename else {
            loadError = true
            return
        }
        isLoading = true
        loadError = false
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = ImageStorage.loadImage(filename)
            DispatchQueue.main.async {
                isLoading = false
                if let loadedImage = loadedImage {
                    currentImage = loadedImage
                    onImageLoaded(loadedImage)
                } else {
                    loadError = true
                }
            }
        }
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    if let image = currentImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(steadyZoomScale * pinchZoomDelta)
                            .offset(x: panOffset.width, y: panOffset.height)
                            .allowsHitTesting((steadyZoomScale * pinchZoomDelta) > 1.01)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        pinchZoomDelta = value
                                    }
                                    .onEnded { value in
                                        let newScale = steadyZoomScale * value
                                        steadyZoomScale = max(1, newScale)
                                        pinchZoomDelta = 1.0
                                        panOffset = clampedOffset(panOffset, image: image, container: geo.size, scale: steadyZoomScale)
                                        lastPan = panOffset
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 5)
                                    .onChanged { value in
                                        let effectiveScale = steadyZoomScale * pinchZoomDelta
                                        guard effectiveScale > 1.01 else { return }
                                        let dx = value.translation.width
                                        let dy = value.translation.height
                                        // Allow pan for both horizontal and vertical dominant gestures when zoomed
                                        let newOffset = CGSize(width: lastPan.width + dx, height: lastPan.height + dy)
                                        panOffset = clampedOffset(newOffset, image: image, container: geo.size, scale: steadyZoomScale * pinchZoomDelta)
                                    }
                                    .onEnded { value in
                                        let effectiveScale = steadyZoomScale
                                        guard effectiveScale > 1.01 else {
                                            panOffset = .zero
                                            lastPan = .zero
                                            return
                                        }
                                        let finalOffset = CGSize(width: lastPan.width + value.translation.width, height: lastPan.height + value.translation.height)
                                        panOffset = clampedOffset(finalOffset, image: image, container: geo.size, scale: effectiveScale)
                                        lastPan = panOffset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.easeInOut) {
                                    if steadyZoomScale > 1 {
                                        steadyZoomScale = 1
                                        panOffset = .zero
                                        lastPan = .zero
                                    } else {
                                        steadyZoomScale = 2
                                    }
                                }
                            }
                            .animation(.easeInOut, value: steadyZoomScale)
                    } else if isLoading {
                        ProgressView()
                    } else if loadError {
                        VStack(spacing: 10) {
                            Text("Immagine non disponibile")
                                .foregroundColor(.white)
                            Button("Riprova") {
                                loadImageIfNeeded(force: true)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            let isNotZoomed = (steadyZoomScale * pinchZoomDelta) <= 1.01
                            let vertical = value.translation.height
                            let horizontal = value.translation.width
                            if isNotZoomed && vertical > 80 && abs(horizontal) < 60 {
                                dismiss()
                            }
                        }
                )
                .onAppear {
                    zoomScale = 1.0
                    steadyZoomScale = 1.0
                    pinchZoomDelta = 1.0
                    panOffset = .zero
                    lastPan = .zero
                    if let initialImage = initialImage {
                        currentImage = initialImage
                        onImageLoaded(initialImage)
                    } else {
                        loadImageIfNeeded()
                    }
                }
            }

            if let date = date {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(date, style: .date)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.5))
                            .foregroundColor(.white)
                            .font(.caption)
                            .cornerRadius(6)
                            .padding()
                    }
                }
            }
        }
    }
}
