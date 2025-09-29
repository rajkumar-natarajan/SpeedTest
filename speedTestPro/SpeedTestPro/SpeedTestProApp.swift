//
//  SpeedTestProApp.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import SwiftUI
import UserNotifications

@main
struct SpeedTestProApp: App {
    /// Initialize app settings and notification permissions on app launch
    @StateObject private var appSettings = AppSettings()
    @StateObject private var notificationService = NotificationService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .onAppear {
                    setupNotifications()
                    // Request notification permissions if not already granted
                    appSettings.requestNotificationPermissions()
                }
                .onReceive(NotificationCenter.default.publisher(for: .scheduledTestTriggered)) { notification in
                    handleScheduledTest(notification)
                }
        }
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = notificationService
    }
    
    private func handleScheduledTest(_ notification: Notification) {
        // Handle scheduled test trigger
        if let scheduledTest = notification.object as? ScheduledTest {
            print("Triggered scheduled test: \(scheduledTest.name)")
            // Here you would trigger the actual speed test
        }
    }
}
