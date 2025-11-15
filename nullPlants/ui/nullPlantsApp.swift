//
//  nullPlantsApp.swift
//  nullPlants
//
//  Created by ilbagatta on 19/10/25.
//

import SwiftUI

@main
struct nullPlantsApp: App {
    @StateObject private var theme = ThemeSettings()
    var body: some Scene {
        WindowGroup {
            PlantsListView()
                .environmentObject(theme)
        }
    }
}

