// Dettaglio, log annaffiature e foto della pianta
import SwiftUI
import UIKit

struct PlantDetailView: View {
    @Binding var plant: Plant
    @ObservedObject var store: PlantStore
    @State private var showingPhoto = false
    @State private var showAlert = false
    @State private var showingTimelapse = false
    @State private var showingWaterInput = false
    @State private var waterLitersText: String = ""
    @State private var showingWaterLogSheet = false
    @State private var selectedPhotoFilename: String? = nil
    @State private var selectedUIImage: UIImage? = nil
    @State private var showingPhotoFullScreen = false
    @State private var showingShareSheet = false
    @State private var showingDeletePhotoAlert = false
    @State private var photoToDeleteFilename: String? = nil
    
    @State private var timelapseSpeed: Double = 1.0 // 1x by default

    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedType: String = ""
    @State private var editedDatePlanted: Date = Date()
    
    // MARK: - Age formatting helper
    private func formattedAge(from startDate: Date, to endDate: Date = Date()) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .weekOfYear, .day], from: startDate, to: endDate)
        var parts: [String] = []
        if let years = comps.year, years > 0 {
            parts.append("\(years) \(years == 1 ? "anno" : "anni")")
        }
        if let months = comps.month, months > 0 {
            parts.append("\(months) \(months == 1 ? "mese" : "mesi")")
        }
        if (comps.year ?? 0) == 0, (comps.month ?? 0) == 0, let weeks = comps.weekOfYear, weeks > 0 {
            parts.append("\(weeks) \(weeks == 1 ? "settimana" : "settimane")")
        }
        if let days = comps.day, days > 0 {
            parts.append("\(days) \(days == 1 ? "giorno" : "giorni")")
        }
        if parts.isEmpty { return "0 giorni" }
        return parts.prefix(2).joined(separator: " e ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isEditing {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.name)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(plant.type)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Età: \(formattedAge(from: plant.datePlanted)) • Seminata il \(plant.datePlanted.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .padding([.horizontal, .top])
            }

            Form {
                Section(header: Text("Info")) {
                    if isEditing {
                        TextField("Nome", text: $editedName)
                        TextField("Tipologia", text: $editedType)
                        DatePicker("Data di semina", selection: $editedDatePlanted, displayedComponents: .date)
                    } else {
                        EmptyView()
                    }
                }
                
                Section(header: Text("Annaffiature")) {
                    Button("Registra annaffiatura di oggi") {
                        if !plant.wateringLog.contains(where: { Calendar.current.isDateInToday($0.date) }) {
                            showingWaterInput = true
                        } else {
                            showAlert = true
                        }
                    }
                    .alert("Annaffiatura già registrata per oggi", isPresented: $showAlert) {
                        Button("OK", role: .cancel) {}
                    }
                    .disabled(plant.wateringLog.contains(where: { Calendar.current.isDateInToday($0.date) }))
                    Button("Log annaffiature") {
                        showingWaterLogSheet = true
                    }
                    .sheet(isPresented: $showingWaterLogSheet) {
                        NavigationView {
                            List {
                                ForEach(plant.wateringLog.sorted(by: { $0.date > $1.date })) { event in
                                    HStack {
                                        Image(systemName: "drop.fill").foregroundStyle(.blue)
                                        let dateText = event.date.formatted(date: .abbreviated, time: .omitted)
                                        if let liters = event.liters {
                                            Text("\(dateText) (\(String(format: "%.2f", liters)) L)")
                                        } else {
                                            Text(dateText)
                                        }
                                    }
                                }
                                .onDelete { indexSet in
                                    let sorted = plant.wateringLog.sorted(by: { $0.date > $1.date })
                                    var base = plant.wateringLog
                                    for index in indexSet {
                                        let toRemove = sorted[index]
                                        if let origIndex = base.firstIndex(where: { $0.id == toRemove.id }) {
                                            base.remove(at: origIndex)
                                        }
                                    }
                                    plant.wateringLog = base
                                    store.updatePlant(plant)
                                }
                            }
                            .navigationTitle("Log annaffiature")
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Chiudi") { showingWaterLogSheet = false }
                                }
                            }
                        }
                    }
                    .sheet(isPresented: $showingWaterInput) {
                        WaterAmountInputSheet(waterLitersText: $waterLitersText) {
                            // Conferma: registra annaffiatura (litri opzionali)
                            let liters: Double? = Double(waterLitersText.replacingOccurrences(of: ",", with: "."))
                            plant.wateringLog.append(WateringEvent(date: Date(), liters: liters))
                            store.updatePlant(plant)
                            waterLitersText = ""
                            showingWaterInput = false
                        } onCancel: {
                            showingWaterInput = false
                            waterLitersText = ""
                        }
                    }
                }
                
                Section(header: Text("Storico foto")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(plant.photoLog.sorted(by: { $0.date > $1.date })) { photo in
                                Button {
                                    selectedPhotoFilename = photo.imageFilename
                                    selectedUIImage = ImageStorage.loadImage(photo.imageFilename)
                                    // Apri sempre la fullscreen: FullScreenPhotoView gestirà il lazy load se necessario
                                    showingPhotoFullScreen = true
                                } label: {
                                    PlantPhotoThumbnail(filename: photo.imageFilename)
                                }
                                .simultaneousGesture(LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                                    photoToDeleteFilename = photo.imageFilename
                                    showingDeletePhotoAlert = true
                                })
                            }
                        }
                    }
                    Button("Aggiungi foto di oggi") {
                        showingPhoto = true
                    }
                    Button("Timelapse", systemImage: "play.rectangle") {
                        showingTimelapse = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Modifica" : plant.name)
        .sheet(isPresented: $showingPhoto) {
            PhotoCaptureView(plant: $plant, store: store)
        }
        .sheet(isPresented: $showingTimelapse) {
            timelapseSheet()
        }
        .fullScreenCover(isPresented: $showingPhotoFullScreen) {
            fullScreenContent()
        }
        .alert("Eliminare questa foto?", isPresented: $showingDeletePhotoAlert) {
            Button("Elimina", role: .destructive) {
                if let filename = photoToDeleteFilename {
                    if let index = plant.photoLog.firstIndex(where: { $0.imageFilename == filename }) {
                        let removed = plant.photoLog.remove(at: index)
                        ImageStorage.deleteImage(removed.imageFilename)
                        store.updatePlant(plant)
                    }
                    photoToDeleteFilename = nil
                }
            }
            Button("Annulla", role: .cancel) {
                photoToDeleteFilename = nil
            }
        } message: {
            Text("Questa azione non può essere annullata.")
        }
        .onDisappear {
            store.updatePlant(plant)
        }
        .onChange(of: plant.photoLog) { _ in
            // If the selected photo was removed or not found, ensure the cover can recover
            if let sel = selectedPhotoFilename, !plant.photoLog.contains(where: { $0.imageFilename == sel }) {
                showingPhotoFullScreen = false
                selectedPhotoFilename = nil
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Salva") {
                        plant.name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                        plant.type = editedType.trimmingCharacters(in: .whitespacesAndNewlines)
                        plant.datePlanted = editedDatePlanted
                        store.updatePlant(plant)
                        isEditing = false
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editedType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button {
                        editedName = plant.name
                        editedType = plant.type
                        editedDatePlanted = plant.datePlanted
                        isEditing = true
                    } label: {
                        Label("Modifica", systemImage: "pencil")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func fullScreenContent() -> some View {
        if selectedPhotoFilename != nil || selectedUIImage != nil {
            let selectedDate = plant.photoLog.first { $0.imageFilename == selectedPhotoFilename }?.date
            FullScreenPhotoView(
                filename: selectedPhotoFilename,
                initialImage: selectedUIImage,
                date: selectedDate,
                onShare: { _ in
                    if let img = selectedUIImage { showingShareSheet = true }
                }
            )
            .sheet(isPresented: $showingShareSheet) {
                if let img = selectedUIImage {
                    ActivityView(activityItems: [img])
                }
            }
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("Immagine non disponibile").foregroundColor(.white)
                    Button("Chiudi") { showingPhotoFullScreen = false }
                        .padding(.top, 8)
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private func timelapseSheet() -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    let speedText = String(format: "%.1fx", timelapseSpeed)
                    Text("Velocità timelapse: \(speedText)")
                    Slider(value: $timelapseSpeed, in: 0.25...3.0, step: 0.25)
                }
                .padding(.horizontal)

                PlantTimelapseView(photos: plant.photoLog, speed: timelapseSpeed)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Timelapse")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { showingTimelapse = false }
                }
            }
        }
    }
}

struct PlantPhotoThumbnail: View {
    let filename: String
    var body: some View {
        if let uiImage = ImageStorage.loadImage(filename) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay(Image(systemName: "photo").foregroundColor(.gray))
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct WaterAmountInputSheet: View {
    @Binding var waterLitersText: String
    var onConfirm: () -> Void
    var onCancel: () -> Void
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Quantità (litri) - opzionale")) {
                    TextField("Es. 0.5", text: $waterLitersText)
                        .keyboardType(.decimalPad)
                }
                Section(footer: Text("Se lasci vuoto, verrà registrata solo l'annaffiatura senza quantità.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Annaffiatura di oggi")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Registra") { onConfirm() }
                }
            }
        }
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

struct CameraCaptureFlow: View {
    @Binding var capturedImage: UIImage?
    var onRetake: () -> Void
    var onSave: (UIImage) -> Void
    var onCancel: () -> Void

    var body: some View {
        Group {
            if let image = capturedImage {
                previewView(for: image)
            } else {
                cameraView()
            }
        }
    }

    @ViewBuilder
    private func cameraView() -> some View {
        InlineCameraView(onCapture: { img in
            capturedImage = img
        }, onCancel: {
            onCancel()
        })
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func previewView(for image: UIImage) -> some View {
        VStack(spacing: 0) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .background(Color.black)
                .ignoresSafeArea()
            HStack {
                Button(role: .cancel) {
                    onRetake()
                } label: {
                    Label("Riscatta", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Spacer()

                Button {
                    onSave(image)
                } label: {
                    Label("Salva", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

// A minimal camera wrapper that captures a UIImage and returns via callback
struct InlineCameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: InlineCameraView
        init(_ parent: InlineCameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

#Preview {
    let store = PlantStore()
    let plant = Plant(name: "Basilico", type: "Aromatiche", datePlanted: Date(), wateringLog: [], photoLog: [])
    PlantDetailView(plant: .constant(plant), store: store)
}
