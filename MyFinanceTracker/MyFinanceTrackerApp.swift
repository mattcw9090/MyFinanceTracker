//
//  MyFinanceTrackerApp.swift
//  MyFinanceTracker
//
//  Created by Matthew Chew on 1/10/24.
//

import SwiftUI

@main
struct MyFinanceTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
