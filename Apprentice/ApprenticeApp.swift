//
//  ApprenticeApp.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//

import SwiftUI

@main
struct ApprenticeApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
