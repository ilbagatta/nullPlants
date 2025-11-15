// Vista di scatto foto con overlay dell'ultima foto precedente della pianta
import SwiftUI

struct PhotoCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var plant: Plant
    @ObservedObject var store: PlantStore
    @State private var newImage: UIImage? = nil
    @State private var newImageDate: Date? = nil
    @State private var showCamera = false
    @State private var showOverlay = true
    @State private var savingErrorMessage: String? = nil
    @State private var showSavingError = false
    @State private var startCameraOnAppear = true
    
    // Trova la foto più recente (se c'è)
    var previousImage: UIImage? {
        guard let prev = plant.photoLog.sorted(by: { $0.date > $1.date }).first else { return nil }
        return ImageStorage.loadImage(prev.imageFilename)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                if showCamera {
                    CustomCameraView(
                        capturedImage: $newImage,
                        captureDate: $newImageDate,
                        previousImage: previousImage,
                        showOverlay: $showOverlay
                    )
                } else {
                    Rectangle()
                        .fill(Color.black.opacity(0.9))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(Text("Apertura fotocamera...").font(.caption).foregroundStyle(.white))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            
            // Controls
            if !showCamera && newImage == nil {
                Button {
                    showCamera = true
                } label: {
                    Label("Scatta foto", systemImage: "camera")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .background(Color.black)
        .navigationTitle("Nuova foto")
        .onAppear {
            if startCameraOnAppear {
                startCameraOnAppear = false
                showCamera = true
            }
        }
        .onChange(of: newImage) {
            // When a new image is captured, save automatically
            if let imageToSave = newImage {
                do {
                    let date = newImageDate ?? Date()
                    let filename = try ImageStorage.saveImage(imageToSave, date: date)
                    plant.photoLog.append(PlantPhoto(date: date, imageFilename: filename))
                    store.updatePlant(plant)
                    dismiss()
                } catch {
                    savingErrorMessage = error.localizedDescription
                    showSavingError = true
                }
                // Stop camera/preview after handling
                showCamera = false
            }
        }
        .alert("Errore nel salvataggio foto", isPresented: $showSavingError, presenting: savingErrorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }
}

// Helper: formatta la data/ora in stringa
private func formatDateTime(_ date: Date) -> String {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .short
    return df.string(from: date)
}
