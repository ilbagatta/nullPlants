// Vista per aggiungere una nuova pianta nell'app nullPlants
import SwiftUI

struct AddPlantView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlantStore
    
    @State private var name = ""
    @State private var type = ""
    @State private var datePlanted = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Nome")) {
                    TextField("Nome pianta", text: $name)
                }
                Section(header: Text("Tipologia")) {
                    TextField("Tipo (es: basilico, cactus)", text: $type)
                }
                Section(header: Text("Data di semina")) {
                    DatePicker("", selection: $datePlanted, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }
            .navigationTitle("Aggiungi Pianta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aggiungi") {
                        let newPlant = Plant(name: name, type: type, datePlanted: datePlanted)
                        store.addPlant(newPlant)
                        dismiss()
                    }
                    .disabled(name.isEmpty || type.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddPlantView(store: PlantStore())
}
