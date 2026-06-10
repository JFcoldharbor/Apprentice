//
//  ApprenticeApp.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct ApprenticeApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .task {
                    // One-time migration of legacy UserDefaults sessions -> SwiftData.
                    LegacyMigrator.migrateIfNeeded(context: NoteStore.mainContext)
                    // Ensure there's a Firebase identity so proxy calls carry an ID token.
                    await AuthService.shared.bootstrap()
                }
        }
        .modelContainer(NoteStore.container)
    }
}
