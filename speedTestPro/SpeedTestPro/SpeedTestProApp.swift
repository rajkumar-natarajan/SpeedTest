//
//  SpeedTestProApp.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import SwiftUI

@main
struct SpeedTestProApp: App {
    /// Initialize app settings and notification permissions on app launch
    @StateObject private var appSettings = AppSettings()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .onAppear {
                    // Request notification permissions if not already granted
                    appSettings.requestNotificationPermissions()
                }
        }
    }
}
