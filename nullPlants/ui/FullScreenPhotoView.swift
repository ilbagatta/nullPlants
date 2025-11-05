import SwiftUI
import UIKit

// This view can lazy-load the image.

struct FullScreenPhotoView: View {
    let filename: String?
    let initialImage: UIImage?
    var date: Date? = nil
    var onShare: (UIImage) -> Void
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
        let imgW = image.size.width
        let imgH = image.size.height
        guard imgW > 0 && imgH > 0 && container.width > 0 && container.height > 0 else { return container }
        let imgAspect = imgW / imgH
        let containerAspect = container.width / container.height
        if imgAspect > containerAspect {
            // fits by width
            let width = container.width
            let height = width / imgAspect
            return CGSize(width: width, height: height)
        } else {
            // fits by height
            let height = container.height
            let width = height * imgAspect
            return CGSize(width: width, height: height)
        }
    }

    private func clampedOffset(_ offset: CGSize, image: UIImage, container: CGSize, scale: CGFloat) -> CGSize {
        let base = fittedSize(for: image, in: container)
        let contentW = base.width * scale
        let contentH = base.height * scale
        let viewW = container.width
        let viewH = container.height
        // If content smaller than view, no pan in that axis
        let maxX = max(0, (contentW - viewW) / 2)
        let maxY = max(0, (contentH - viewH) / 2)
        let clampedX = min(max(offset.width, -maxX), maxX)
        let clampedY = min(max(offset.height, -maxY), maxY)
        return CGSize(width: clampedX, height: clampedY)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()

                GeometryReader { proxy in
                    let size = proxy.size
                    ZStack {
                        if let img = currentImage {
                            Color.black.ignoresSafeArea()
                            // Zoom & Pan
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: size.width, height: size.height)
                                .scaleEffect(steadyZoomScale * pinchZoomDelta)
                                .offset(panOffset)
                                .contentShape(Rectangle())
                                .gesture(
                                    SimultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                let proposed = (steadyZoomScale * value).clamped(to: 1.0...6.0)
                                                pinchZoomDelta = proposed / steadyZoomScale
                                                panOffset = clampedOffset(panOffset, image: img, container: size, scale: steadyZoomScale * pinchZoomDelta)
                                            }
                                            .onEnded { value in
                                                let newScale = (steadyZoomScale * value).clamped(to: 1.0...6.0)
                                                steadyZoomScale = newScale
                                                pinchZoomDelta = 1.0
                                                panOffset = clampedOffset(panOffset, image: img, container: size, scale: steadyZoomScale)
                                                if steadyZoomScale <= 1.0 { panOffset = .zero }
                                            },
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                // enable pan only when zoomed in
                                                guard steadyZoomScale * pinchZoomDelta > 1.0 else { return }
                                                let provisional = CGSize(width: lastPan.width + value.translation.width, height: lastPan.height + value.translation.height)
                                                panOffset = clampedOffset(provisional, image: img, container: size, scale: steadyZoomScale * pinchZoomDelta)
                                            }
                                            .onEnded { value in
                                                guard steadyZoomScale > 1.0 else { panOffset = .zero; lastPan = .zero; return }
                                                panOffset = clampedOffset(panOffset, image: img, container: size, scale: steadyZoomScale)
                                                lastPan = panOffset
                                            }
                                    )
                                )
                                .highPriorityGesture(
                                    SpatialTapGesture(count: 2)
                                        .onEnded { value in
                                            let location = value.location
                                            let currentScale = steadyZoomScale * pinchZoomDelta
                                            withAnimation(.easeInOut) {
                                                if currentScale > 1.01 {
                                                    // Reset to 1x
                                                    steadyZoomScale = 1.0
                                                    pinchZoomDelta = 1.0
                                                    panOffset = .zero
                                                    lastPan = .zero
                                                } else {
                                                    // Zoom in to 2x centered on tapped point
                                                    let targetScale: CGFloat = 2.0
                                                    steadyZoomScale = targetScale
                                                    pinchZoomDelta = 1.0
                                                    // Compute offset so that tapped point moves toward center when scaling
                                                    let dx = location.x - (size.width / 2)
                                                    let dy = location.y - (size.height / 2)
                                                    let added = CGSize(width: -dx * (targetScale - 1), height: -dy * (targetScale - 1))
                                                    let newOffset = CGSize(width: panOffset.width + added.width, height: panOffset.height + added.height)
                                                    panOffset = clampedOffset(newOffset, image: img, container: size, scale: targetScale)
                                                    lastPan = panOffset
                                                }
                                            }
                                        }
                                )
                        } else if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if loadError {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.yellow)
                                    .font(.title2)
                                Text("Immagine non disponibile")
                                    .foregroundColor(.white)
                                if let filename {
                                    Button("Riprova") { loadImageIfNeeded(force: true) }
                                        .buttonStyle(.borderedProminent)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .task { loadImageIfNeeded() }
                        }
                    }
                }
                .gesture(
                    SimultaneousGesture(
                        DragGesture(minimumDistance: 20, coordinateSpace: .local)
                            .onEnded { value in
                                // Dismiss with swipe down when not zoomed
                                if value.translation.height > 80 && abs(value.translation.width) < 60 && steadyZoomScale <= 1.01 && pinchZoomDelta <= 1.01 {
                                    dismiss()
                                }
                            },
                        DragGesture(minimumDistance: 20, coordinateSpace: .local)
                            .onEnded { value in
                                // Dismiss with swipe right when not zoomed
                                if value.translation.width > 80 && abs(value.translation.height) < 60 && steadyZoomScale <= 1.01 && pinchZoomDelta <= 1.01 {
                                    dismiss()
                                }
                            }
                    )
                )

                // Date overlay bottom-right
                if let date {
                    VStack { Spacer() }
                        .overlay(alignment: .bottomTrailing) {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding()
                        }
                        .ignoresSafeArea()
                }
            }
            .onAppear {
                steadyZoomScale = 1.0
                pinchZoomDelta = 1.0
                if currentImage == nil {
                    currentImage = initialImage
                }
                if currentImage == nil {
                    loadImageIfNeeded()
                }
            }
            .navigationTitle(date?.formatted(date: .abbreviated, time: .omitted) ?? "Foto")
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
                    Button(action: { if let img = currentImage { onShare(img) } }) {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private func loadImageIfNeeded(force: Bool = false) {
        guard let filename else { return }
        if currentImage != nil && !force { return }
        isLoading = true
        loadError = false
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = ImageStorage.loadImage(filename)
            DispatchQueue.main.async {
                self.isLoading = false
                if let loaded {
                    self.currentImage = loaded
                    self.loadError = false
                } else {
                    self.loadError = true
                }
            }
        }
    }
}

