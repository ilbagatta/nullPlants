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
    @State private var showingPhotoGallery = false
    @State private var selectedPhotoFilename: String? = nil
    @State private var selectedUIImage: UIImage? = nil
    @State private var showingPhotoFullScreen = false
    @State private var showingShareSheet = false
    @State private var showingDeletePhotoAlert = false
    @State private var photoToDeleteFilename: String? = nil

    @State private var showingDeleteWaterAlert = false
    @State private var pendingWaterDeleteDate: Date? = nil
    
    @State private var timelapseSpeed: Double = 1.0 // 1x by default

    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedType: String = ""
    @State private var editedDatePlanted: Date = Date()
    
    private var sortedWaterings: [WateringEvent] {
        plant.wateringLog.sorted { $0.date > $1.date }
    }
    
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
        VStack(spacing: 0) {
            // Hero photo: latest plant photo
            if let latest = plant.photoLog.sorted(by: { $0.date > $1.date }).first,
               let heroImage = ImageStorage.loadImage(latest.imageFilename) {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: heroImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPhotoFilename = latest.imageFilename
                            selectedUIImage = heroImage
                            showingPhotoFullScreen = true
                        }

                    // Gradient overlay for text legibility
                    LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 80)
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .allowsHitTesting(false)

                    // Caption with date
                    VStack(alignment: .leading, spacing: 4) {
                        Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding([.leading, .bottom], 12)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
            } else {
                ZStack {
                    // Placeholder background
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.thinMaterial)
                        .frame(height: 220)

                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Scatta la prima foto")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingPhoto = true
                }
                .padding(.horizontal)
            }

            if !isEditing {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plant.name)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                    Text(plant.type)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Divider().opacity(0.15)
                    HStack(spacing: 12) {
                        Label("Età: \(formattedAge(from: plant.datePlanted))", systemImage: "leaf.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Label("\(plant.datePlanted.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
                .padding([.horizontal, .top])
            }
            else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Modifica pianta")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 10) {
                        TextField("Nome", text: $editedName)
                            .textInputAutocapitalization(.words)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                        TextField("Tipo", text: $editedType)
                            .textInputAutocapitalization(.words)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                        DatePicker("Data di semina", selection: $editedDatePlanted, displayedComponents: .date)
                    }
                }
                .padding([.horizontal, .top])
            }

            VStack(alignment: .leading, spacing: 16) {
                // Removed HStack with "Azioni" label and spacer
                
                // Azioni principali (modern style)
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showingPhoto = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "camera.fill")
                                    .symbolRenderingMode(.hierarchical)
                                Text("Scatta foto")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
                            .contentShape(Rectangle())
                        }

                        Button {
                            showingPhotoGallery = true
                        } label: {
                            Image(systemName: "square.grid.3x3.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 48, height: 48)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .accessibilityLabel("Log foto")
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showingTimelapse = true
                        } label: {
                            Image(systemName: "film")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 48, height: 48)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .accessibilityLabel("Timelapse")
                    }

                    HStack(spacing: 12) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if !plant.wateringLog.contains(where: { Calendar.current.isDateInToday($0.date) }) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    showingWaterInput = true
                                }
                            } else {
                                showAlert = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "drop.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(Color.blue, Color.blue.opacity(0.35))
                                Text("Registra annaffiatura")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                        }
                        .disabled(plant.wateringLog.contains(where: { Calendar.current.isDateInToday($0.date) }))
                        .opacity(plant.wateringLog.contains(where: { Calendar.current.isDateInToday($0.date) }) ? 0.5 : 1.0)

                        Button {
                            showingWaterLogSheet = true
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 48, height: 48)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .accessibilityLabel("Log annaffiature")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)

                // Removed Link secondari (card style) with photo gallery and watering log buttons
                
            }
            .padding(.vertical, 12)

            Spacer(minLength: 0)

            /*
            // Bottom Timelapse button (floating style)
            VStack(spacing: 8) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingTimelapse = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "film")
                        Text("Timelapse").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.purple.opacity(0.25), lineWidth: 1))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.clear)
            */
        }
        .navigationTitle(isEditing ? "Modifica" : plant.name)
        .sheet(isPresented: $showingPhoto) {
            PhotoCaptureView(plant: $plant, store: store)
        }
        .sheet(isPresented: $showingWaterInput) {
            WaterAmountInputSheet(
                waterLitersText: $waterLitersText,
                onConfirm: {
                    let trimmed = waterLitersText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let liters: Double?
                    if trimmed.isEmpty {
                        liters = nil
                    } else {
                        let formatter = NumberFormatter()
                        formatter.locale = Locale.current
                        formatter.decimalSeparator = Locale.current.decimalSeparator
                        if let number = formatter.number(from: trimmed) {
                            liters = number.doubleValue
                        } else if let val = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
                            liters = val
                        } else {
                            liters = nil
                        }
                    }

                    // Prevent duplicate watering for today
                    if !plant.wateringLog.contains(where: { Calendar.current.isDateInToday($0.date) }) {
                        let entry = WateringEvent(date: Date(), liters: liters)
                        plant.wateringLog.append(entry)
                        // Keep log sorted newest first (optional)
                        plant.wateringLog.sort { $0.date > $1.date }
                        store.updatePlant(plant)
                    }
                    waterLitersText = ""
                    showingWaterInput = false
                },
                onCancel: {
                    waterLitersText = ""
                    showingWaterInput = false
                }
            )
        }
        .sheet(isPresented: $showingWaterLogSheet) {
            NavigationStack {
                List {
                    ForEach(sortedWaterings, id: \.date) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.body)
                                if let liters = entry.liters {
                                    Text(String(format: "%.2f L", liters))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        let dates = indexSet.map { sortedWaterings[$0].date }
                        plant.wateringLog.removeAll { entry in dates.contains(entry.date) }
                        store.updatePlant(plant)
                    }
                }
                .navigationTitle("Log annaffiature")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { showingWaterLogSheet = false } } }
            }
            .alert("Eliminare questa annaffiatura?", isPresented: $showingDeleteWaterAlert) {
                Button("Elimina", role: .destructive) {
                    if let date = pendingWaterDeleteDate {
                        plant.wateringLog.removeAll { $0.date == date }
                        store.updatePlant(plant)
                    }
                    pendingWaterDeleteDate = nil
                }
                Button("Annulla", role: .cancel) {
                    pendingWaterDeleteDate = nil
                }
            } message: {
                Text("Questa azione non può essere annullata.")
            }
        }
        .sheet(isPresented: $showingTimelapse) {
            timelapseSheet()
        }
        .sheet(isPresented: $showingPhotoGallery) {
            PhotoGalleryView(
                photos: plant.photoLog,
                filename: { $0.imageFilename },
                date: { $0.date },
                onSelect: { photo in
                    selectedPhotoFilename = photo.imageFilename
                    selectedUIImage = ImageStorage.loadImage(photo.imageFilename)
                    showingPhotoFullScreen = true
                },
                onClose: {
                    showingPhotoGallery = false
                }
            )
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
        let selectedDate = selectedPhotoFilename.flatMap { name in plant.photoLog.first { $0.imageFilename == name }?.date }
        if selectedPhotoFilename != nil || selectedUIImage != nil {
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

