//
//  SettingsView.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var showingPrivacyPolicy = false
    @State private var showingAbout = false
    @State private var showingExportAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // Appearance section
                Section("Appearance") {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Dark Mode")
                        
                        Spacer()
                        
                        Toggle("", isOn: $appSettings.isDarkMode)
                    }
                    
                    HStack {
                        Image(systemName: "textformat")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        Text("Speed Unit")
                        
                        Spacer()
                        
                        Picker("Speed Unit", selection: $appSettings.speedUnit) {
                            ForEach(SpeedUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                // Test settings section
                Section("Advanced Features") {
                    NavigationLink(destination: ServerSelectionView()) {
                        Label("Server Selection", systemImage: "server.rack")
                    }
                    
                    NavigationLink(destination: ScheduledTestsView()) {
                        Label("Scheduled Tests", systemImage: "clock.badge.plus")
                    }
                    
                    NavigationLink(destination: NetworkDiagnosticsView()) {
                        Label("Network Diagnostics", systemImage: "network")
                    }
                    
                    NavigationLink(destination: HistoricalChartsView(testHistory: TestHistory.shared)) {
                        Label("Speed History Charts", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }
                
                Section("Test Settings") {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Use Location for Server Selection")
                        
                        Spacer()
                        
                        Toggle("", isOn: $appSettings.useLocationForServer)
                    }
                    
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        Text("Auto-test on Launch")
                        
                        Spacer()
                        
                        Toggle("", isOn: $appSettings.autoTestOnLaunch)
                    }
                    
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        Text("Low Speed Notifications")
                        
                        Spacer()
                        
                        Toggle("", isOn: $appSettings.lowSpeedNotifications)
                    }
                    
                    if appSettings.lowSpeedNotifications {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            
                            Text("Threshold")
                            
                            Spacer()
                            
                            Text("\(Int(appSettings.lowSpeedThreshold)) Mbps")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $appSettings.lowSpeedThreshold,
                            in: 1...50,
                            step: 1
                        ) {
                            Text("Speed Threshold")
                        }
                        .accentColor(.blue)
                    }
                }
                
                // Data & Privacy section
                Section("Data & Privacy") {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Privacy Policy")
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingPrivacyPolicy = true
                    }
                    
                    HStack {
                        Image(systemName: "square.and.arrow.up.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        Text("Export Data")
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        exportAllData()
                    }
                    
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        Text("Clear All Data")
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingExportAlert = true
                    }
                }
                
                // About section
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("About SpeedTest Pro")
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingAbout = true
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 24)
                        
                        Text("Rate This App")
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        rateApp()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            
                            Text("Version")
                            
                            Spacer()
                            
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            
                            Text("Build")
                            
                            Spacer()
                            
                            Text("1")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView(isPresented: $showingPrivacyPolicy)
        }
        .sheet(isPresented: $showingAbout) {
            AboutView(isPresented: $showingAbout)
        }
        .alert("Clear All Data", isPresented: $showingExportAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllAppData()
            }
        } message: {
            Text("This will permanently delete all your speed test history and reset all settings. This action cannot be undone.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func exportAllData() {
        let allResults = TestHistory.shared.getAllResults()
        let csvContent = generateCSV(from: allResults)
        
        let activityViewController = UIActivityViewController(
            activityItems: [csvContent],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func generateCSV(from results: [SpeedTestResult]) -> String {
        var csv = "Date,Download Speed (Mbps),Upload Speed (Mbps),Ping (ms),Jitter (ms),Connection Type,Quality\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        for result in results {
            let row = "\(dateFormatter.string(from: result.timestamp)),\(result.downloadSpeed),\(result.uploadSpeed),\(result.ping),\(result.jitter),\(result.connectionType),\(result.connectionQuality.rawValue)\n"
            csv += row
        }
        
        return csv
    }
    
    private func clearAllAppData() {
        TestHistory.shared.clearAllResults()
        appSettings.resetToDefaults()
    }
    
    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/id123456789") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Group {
                        PolicySection(
                            title: "Data Collection",
                            content: "SpeedTest Pro does not collect any personal information. All speed test results are stored locally on your device and are not transmitted to any external servers."
                        )
                        
                        PolicySection(
                            title: "Location Data",
                            content: "If you enable location services, we use your approximate location only to select the nearest test server for more accurate results. This location data is not stored or transmitted."
                        )
                        
                        PolicySection(
                            title: "Network Information",
                            content: "The app accesses your network connection to perform speed tests. No network data is collected beyond what's necessary for the speed test functionality."
                        )
                        
                        PolicySection(
                            title: "Data Storage",
                            content: "All test results are stored locally using iOS UserDefaults and are never shared with third parties. You can delete this data at any time through the app's settings."
                        )
                        
                        PolicySection(
                            title: "Third-Party Services",
                            content: "SpeedTest Pro does not integrate with any third-party analytics or advertising services. Your privacy is our priority."
                        )
                    }
                    
                    Text("Last updated: September 29, 2025")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // App icon and name
                    VStack(spacing: 15) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("SpeedTest Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Test Your Speed in Seconds")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Features")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        FeatureRow(icon: "speedometer", title: "Accurate Speed Testing", description: "Measure download, upload speeds, ping, and jitter")
                        
                        FeatureRow(icon: "clock.arrow.circlepath", title: "Test History", description: "Track your internet performance over time")
                        
                        FeatureRow(icon: "lock.shield", title: "Privacy First", description: "All data stays on your device - no tracking")
                        
                        FeatureRow(icon: "moon", title: "Dark Mode Support", description: "Beautiful interface in light and dark themes")
                        
                        FeatureRow(icon: "square.and.arrow.up", title: "Export & Share", description: "Share results and export your data")
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text("Made with ❤️ for iOS")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("© 2025 SpeedTest Pro")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Components

struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
