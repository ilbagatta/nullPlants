import SwiftUI
import AVFoundation

struct PlantTimelapseView: View {
    let photos: [PlantPhoto]
    let speed: Double

    @State private var currentIndex: Int
    @State private var isPlaying = false
    @State private var timer: Timer? = nil
    @State private var perPhotoDuration: Double = 1.0 // seconds per photo (0.5 - 3.0)
    @State private var isLooping: Bool = false
    @State private var playbackSpeed: Double = 1.0
    @State private var isExporting: Bool = false
    @State private var shareURL: URL? = nil

    init(photos: [PlantPhoto], speed: Double = 1.0) {
        // Ordina le foto in ordine di data crescente
        self.photos = photos.sorted { $0.date < $1.date }
        self.speed = speed
        _currentIndex = State(initialValue: max(photos.count - 1, 0))
        _playbackSpeed = State(initialValue: speed)
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                // Speed control (label + slider)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Velocità timelapse")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text(String(format: "%.1fx", playbackSpeed))
                            .monospacedDigit()
                            .frame(minWidth: 56, alignment: .leading)
                        Stepper(value: $playbackSpeed, in: 0.25...3.0, step: 0.25) {
                            EmptyView()
                        }
                        .labelsHidden()
                    }
                }

                // Duration per photo (compact)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Durata per foto")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text(String(format: "%.1f s", perPhotoDuration))
                            .monospacedDigit()
                            .frame(minWidth: 56, alignment: .leading)
                        Stepper(value: $perPhotoDuration, in: 0.5...10.0, step: 0.5) {
                            EmptyView()
                        }
                        .labelsHidden()
                    }
                }
                .frame(width: 180, alignment: .leading)
            }
            
            if let image = loadImage(photos[safe: currentIndex]?.imageFilename ?? "") {
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 350)
                        .cornerRadius(14)
                        .shadow(radius: 8)
                    if let date = photos[safe: currentIndex]?.date {
                        Text(stringaDataOraDa(date))
                            .font(.caption2)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(6)
                            .shadow(radius: 2)
                            .padding(8)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 350)
                    .overlay(Text("Nessuna foto"))
            }

            if photos.count > 1 {
                Slider(value: Binding(
                    get: { Double(currentIndex) },
                    set: { newValue in
                        currentIndex = Int(newValue)
                    }),
                    in: 0...Double(photos.count - 1),
                    step: 1
                )
                Text(dateLabel)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                // Play/Stop circular button (larger)
                Button {
                    if isPlaying { stopTimelapse() } else { playTimelapse() }
                } label: {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.accentColor, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
                }
                .disabled(photos.count < 2)

                // Loop circular button (smaller)
                Button {
                    isLooping.toggle()
                } label: {
                    Image(systemName: isLooping ? "repeat.circle.fill" : "repeat")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1))
                }
            }
        }
        .overlay(
            Group {
                if isExporting {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView("Esportazione in corso…")
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Questo potrebbe richiedere qualche istante.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(radius: 10)
                    }
                }
            }
        )
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
            if let url = shareURL {
                ActivityView(activityItems: [url])
            }
        }
        .padding()
        .onDisappear {
            stopTimelapse()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportTimelapseVideo()
                } label: {
                    Label("Esporta", systemImage: "square.and.arrow.up")
                }
                .disabled(photos.isEmpty || isExporting)
            }
        }
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var dateLabel: String {
        guard let date = photos[safe: currentIndex]?.date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func playTimelapse() {
        guard photos.count > 1 else { return }
        isPlaying = true
        currentIndex = 0
        stopTimelapse()
        // Calcola l'intervallo in base alla durata per foto e alla velocità selezionata
        let base = max(0.1, perPhotoDuration)
        let interval = max(0.05, min(1.0, base / max(playbackSpeed, 0.1)))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if currentIndex < photos.count - 1 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentIndex += 1
                }
            } else {
                if isLooping {
                    withAnimation(.easeInOut(duration: 0.2)) { currentIndex = 0 }
                } else {
                    stopTimelapse()
                }
            }
        }
    }

    private func stopTimelapse() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    private func exportTimelapseVideo() {
        isExporting = true
        // Ensure we have images
        let ordered = photos.sorted { $0.date < $1.date }
        let uiImages: [UIImage] = ordered.compactMap { loadImage($0.imageFilename) }
        guard !uiImages.isEmpty else {
            DispatchQueue.main.async { isExporting = false }
            return
        }

        // Choose output size based on first image, limit max dimension for file size
        let first = uiImages[0]
        let maxDimension: CGFloat = 1080
        let aspect = first.size.width / max(first.size.height, 1)
        var targetSize = first.size
        if max(first.size.width, first.size.height) > maxDimension {
            if first.size.width >= first.size.height {
                targetSize = CGSize(width: maxDimension, height: maxDimension / max(aspect, 0.0001))
            } else {
                targetSize = CGSize(width: maxDimension * max(aspect, 0.0001), height: maxDimension)
            }
        }
        targetSize.width = round(targetSize.width)
        targetSize.height = round(targetSize.height)

        // Compute timing
        let durationPerImage = max(0.5, min(3.0, perPhotoDuration))
        let fps: Int32 = 30
        let framesPerImage = Int64(max(1, Int(durationPerImage * Double(fps))))

        // Output URL
        let filename = "Timelapse_\(Int(Date().timeIntervalSince1970)).mp4"
        let outputURL = documentsDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: outputURL)

        // Writer setup
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else { return }
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(targetSize.width),
            AVVideoHeightKey: Int(targetSize.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: Int(targetSize.width),
            kCVPixelBufferHeightKey as String: Int(targetSize.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: sourcePixelBufferAttributes)

        guard writer.canAdd(input) else { return }
        writer.add(input)

        writer.startWriting()
        let startTime = CMTime.zero
        writer.startSession(atSourceTime: startTime)

        let queue = DispatchQueue(label: "timelapse.export.queue")
        input.requestMediaDataWhenReady(on: queue) {
            var frameCount: Int64 = 0

            func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
                let options: [CFString: Any] = [
                    kCVPixelBufferCGImageCompatibilityKey: true,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: true
                ]
                var pxbuffer: CVPixelBuffer?
                let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, options as CFDictionary, &pxbuffer)
                guard status == kCVReturnSuccess, let buffer = pxbuffer else { return nil }

                CVPixelBufferLockBaseAddress(buffer, [])
                defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

                let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                guard let context = CGContext(
                    data: CVPixelBufferGetBaseAddress(buffer),
                    width: Int(size.width),
                    height: Int(size.height),
                    bitsPerComponent: 8,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                    space: rgbColorSpace,
                    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                ) else { return nil }

                // Fill black background
                context.setFillColor(UIColor.black.cgColor)
                context.fill(CGRect(origin: .zero, size: size))

                // Draw aspect-fit image
                let imgSize = image.size
                let scale = min(size.width / imgSize.width, size.height / imgSize.height)
                let drawW = imgSize.width * scale
                let drawH = imgSize.height * scale
                let drawX = (size.width - drawW) / 2
                let drawY = (size.height - drawH) / 2
                let rect = CGRect(x: drawX, y: drawY, width: drawW, height: drawH)
                if let cg = image.cgImage {
                    context.draw(cg, in: rect)
                }

                return buffer
            }

            var imageIndex = 0
            while input.isReadyForMoreMediaData && imageIndex < uiImages.count {
                let image = uiImages[imageIndex]
                // Append framesPerImage frames for each image
                for _ in 0..<framesPerImage {
                    let presentationTime = CMTime(value: frameCount, timescale: fps)
                    if let buffer = pixelBuffer(from: image, size: targetSize) {
                        if !adaptor.append(buffer, withPresentationTime: presentationTime) {
                            input.markAsFinished()
                            writer.cancelWriting()
                            DispatchQueue.main.async {
                                isExporting = false
                                shareURL = nil
                            }
                            return
                        }
                    }
                    frameCount += 1
                }
                imageIndex += 1
            }

            if imageIndex >= uiImages.count {
                input.markAsFinished()
                writer.finishWriting {
                    DispatchQueue.main.async {
                        isExporting = false
                        if writer.status == .completed {
                            shareURL = outputURL
                        }
                    }
                }
            }
        }
    }
}

// Helper: Array safe index access
fileprivate extension Array {
    subscript(safe index: Int) -> Element? {
        (startIndex..<endIndex).contains(index) ? self[index] : nil
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
}

#Preview {
    let photos = [
        PlantPhoto(date: Date().addingTimeInterval(-86400*2), imageFilename: "sample1.jpg"),
        PlantPhoto(date: Date().addingTimeInterval(-86400), imageFilename: "sample2.jpg"),
        PlantPhoto(date: Date(), imageFilename: "sample3.jpg")
    ]
    PlantTimelapseView(photos: photos)
}
