//
//  ContentView.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab - Main speed test interface
            HomeView()
                .tabItem {
                    Image(systemName: "speedometer")
                    Text("Test")
                }
                .tag(0)
            
            // History Tab - Past test results
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
                .tag(1)
            
            // Settings Tab - App preferences
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.blue) // Consistent accent color throughout the app
        .preferredColorScheme(appSettings.isDarkMode ? .dark : .light)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
}
