//
//  RSMSApp.swift
//  RSMS
//
//  Created by Dnyaneshwari Gogawale on 23/04/26.
//

import SwiftUI
import CoreData

@main
struct RSMSApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
