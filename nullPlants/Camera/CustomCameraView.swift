//
//  CustomCameraView.swift
//  nullPlants
//
//  Created by ilbagatta on 19/10/25.
//


import SwiftUI
import AVFoundation
import Combine

struct CustomCameraView: View {
    @Binding var capturedImage: UIImage?
    @Binding var captureDate: Date?
    let previousImage: UIImage?
    @Binding var showOverlay: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var isPresentingPhoto = false
    @StateObject private var camera = CameraModel()
    @State private var overlayOpacity: Double = 0.3
    @State private var showSystemNavBar: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                GeometryReader { proxy in
                    VStack {
                        Spacer(minLength: 0)
                        VStack(spacing: 8) {
                            if showOverlay {
                                HStack(spacing: 8) {
                                    Image(systemName: "circle.lefthalf.filled").foregroundColor(.white.opacity(0.9))
                                    Slider(value: $overlayOpacity, in: 0...1)
                                        .tint(.white)
                                        .frame(width: min(proxy.size.width - 48, 280))
                                    Image(systemName: "circle.righthalf.filled").foregroundColor(.white.opacity(0.9))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.45))
                                .clipShape(Capsule())
                                .accessibilityLabel("Opacità overlay")
                                .accessibilityValue(Text(String(format: "%.0f%%", overlayOpacity * 100)))
                            }
                            ZStack {
                                let width = proxy.size.width
                                let height = width * 4.0/3.0
                                CameraPreview(session: camera.session)
                                    .onAppear { camera.start() }
                                    .onDisappear { camera.stopSession() }
                                    .frame(width: width, height: height)
                                    .clipped()

                                if showOverlay, let prev = previousImage {
                                    Image(uiImage: prev)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: width, height: height)
                                        .opacity(overlayOpacity)
                                        .clipped()
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                LinearGradient(colors: [Color.clear, Color.black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 170)
                    .overlay(
                        HStack {
                            Spacer()
                            Button(action: {
                                camera.takePhoto { image in
                                    if let image = image {
                                        capturedImage = image
                                        captureDate = Date()
                                        dismiss()
                                    }
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.18))
                                        .frame(width: 84, height: 84)
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 6)
                                        .frame(width: 72, height: 72)
                                }
                            }
                            .disabled(!camera.isRunning)
                            .padding(.bottom, 16)
                            Spacer()
                        }
                    )
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Fotocamera")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showOverlay.toggle()
                    } label: {
                        Image(systemName: showOverlay ? "eye.slash" : "eye")
                    }
                    .tint(.white)
                    .accessibilityLabel(showOverlay ? "Nascondi overlay" : "Mostra overlay")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.6), for: .navigationBar)
        }
    }
}

// MARK: - Camera Model
class CameraModel: ObservableObject {
    @Published var isRunning = false
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "camera.queue")
    private var photoDelegate: AVCapturePhotoCaptureDelegate?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted { self.configure() } else { print("Camera access denied") }
            }
        default:
            print("Camera access not authorized")
        }
    }

    func configure() {
        queue.async {
            self.session.beginConfiguration()
            // Use .photo (4:3) so preview and captured photos share proportions
            self.session.sessionPreset = .photo

            // Input
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .back
            )
            guard let device = discovery.devices.first else {
                print("No back wide-angle camera")
                self.session.commitConfiguration()
                return
            }
            guard let input = try? AVCaptureDeviceInput(device: device) else {
                print("Cannot create input")
                self.session.commitConfiguration()
                return
            }
            self.session.inputs.forEach { self.session.removeInput($0) }
            guard self.session.canAddInput(input) else {
                print("Cannot add input")
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)

            // Output
            self.session.outputs.forEach { self.session.removeOutput($0) }
            guard self.session.canAddOutput(self.output) else {
                print("Cannot add photo output")
                self.session.commitConfiguration()
                return
            }
            self.session.addOutput(self.output)
            
            // Configure output photo dimensions (use legacy high-res flag only on < iOS 16)
            if #available(iOS 16.0, *) {
                // On iOS 16+, let the system choose optimal photo dimensions. No explicit configuration needed here.
            } else {
                if self.output.isHighResolutionCaptureEnabled == false {
                    self.output.isHighResolutionCaptureEnabled = true
                }
            }

            self.session.commitConfiguration()
            print("Session configured, starting...")
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    func stopSession() {
        queue.async {
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    func takePhoto(completion: @escaping (UIImage?) -> Void) {
        print("Capturing photo...")
        let settings = AVCapturePhotoSettings()
        if #available(iOS 16.0, *) {
            // Use default max dimensions chosen by the system.
        } else {
            if self.output.isHighResolutionCaptureEnabled {
                settings.isHighResolutionPhotoEnabled = true
            }
        }

        let delegate = CameraPhotoDelegate { [weak self] image in
            print("Photo processed, image: \(image != nil)")
            completion(image)
            self?.photoDelegate = nil
        }
        self.photoDelegate = delegate
        self.output.capturePhoto(with: settings, delegate: delegate)
    }
}

private class CameraPhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (UIImage?) -> Void
    init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("didFinishProcessingPhoto, error: \(String(describing: error))")
        if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            completion(image)
        } else {
            completion(nil)
        }
    }
}

// MARK: - CameraPreview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection {
            if #available(iOS 17.0, *) {
                let angle: CGFloat = 0 // portrait
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }
        view.previewLayer = layer
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer?.session = session
        if let connection = uiView.previewLayer?.connection {
            if #available(iOS 17.0, *) {
                let angle: CGFloat = 0 // portrait
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }
        uiView.setNeedsLayout()
        uiView.layoutIfNeeded()
        uiView.previewLayer?.frame = uiView.bounds
    }
}

final class PreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let layer = previewLayer {
                layer.frame = bounds
                self.layer.addSublayer(layer)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

