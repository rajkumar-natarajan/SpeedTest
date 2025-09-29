//
//  TestResultsView.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import SwiftUI

struct TestResultsView: View {
    let result: SpeedTestResult
    @Binding var isPresented: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header with overall quality
                    VStack(spacing: 10) {
                        Text("Test Results")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(result.connectionQuality.rawValue)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(qualityColor)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(qualityColor.opacity(0.1))
                            .cornerRadius(20)
                    }
                    .padding(.top, 20)
                    
                    // Speed cards
                    VStack(spacing: 20) {
                        // Download speed card
                        SpeedCard(
                            title: "Download",
                            speed: result.downloadSpeed,
                            unit: appSettings.speedUnit.rawValue,
                            icon: "arrow.down.circle.fill",
                            color: .green
                        )
                        
                        // Upload speed card
                        SpeedCard(
                            title: "Upload",
                            speed: result.uploadSpeed,
                            unit: appSettings.speedUnit.rawValue,
                            icon: "arrow.up.circle.fill",
                            color: .blue
                        )
                    }
                    
                    // Additional metrics
                    VStack(spacing: 15) {
                        MetricRow(
                            title: "Ping",
                            value: String(format: "%.0f ms", result.ping),
                            icon: "timer"
                        )
                        
                        MetricRow(
                            title: "Jitter",
                            value: String(format: "%.1f ms", result.jitter),
                            icon: "waveform"
                        )
                        
                        MetricRow(
                            title: "Connection",
                            value: result.connectionType,
                            icon: result.connectionType == "Wi-Fi" ? "wifi" : "antenna.radiowaves.left.and.right"
                        )
                        
                        MetricRow(
                            title: "Server",
                            value: result.serverLocation,
                            icon: "server.rack"
                        )
                        
                        MetricRow(
                            title: "Test Time",
                            value: formatDate(result.timestamp),
                            icon: "clock"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Speed comparison chart
                    SpeedComparisonChart(result: result)
                    
                    // Action buttons
                    HStack(spacing: 20) {
                        // Retest button
                        Button(action: {
                            isPresented = false
                            // Trigger new test (handled by parent view)
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Test Again")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        
                        // Share button
                        Button(action: shareResults) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    
                    Spacer()
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
    
    // MARK: - Helper Methods
    
    private var qualityColor: Color {
        switch result.connectionQuality {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func shareResults() {
        let shareText = """
        SpeedTest Pro Results
        
        Download: \(String(format: "%.1f", result.downloadSpeed)) Mbps
        Upload: \(String(format: "%.1f", result.uploadSpeed)) Mbps
        Ping: \(String(format: "%.0f", result.ping)) ms
        Connection Quality: \(result.connectionQuality.rawValue)
        
        Tested on \(formatDate(result.timestamp))
        """
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

// MARK: - Speed Card Component

struct SpeedCard: View {
    let title: String
    let speed: Double
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack {
                Text(String(format: "%.1f", speed))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Metric Row Component

struct MetricRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Speed Comparison Chart

struct SpeedComparisonChart: View {
    let result: SpeedTestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Speed Comparison")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Download speed bar
                SpeedBar(
                    title: "Download",
                    speed: result.downloadSpeed,
                    maxSpeed: max(result.downloadSpeed, result.uploadSpeed, 100),
                    color: .green
                )
                
                // Upload speed bar
                SpeedBar(
                    title: "Upload",
                    speed: result.uploadSpeed,
                    maxSpeed: max(result.downloadSpeed, result.uploadSpeed, 100),
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Speed Bar Component

struct SpeedBar: View {
    let title: String
    let speed: Double
    let maxSpeed: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(String(format: "%.1f Mbps", speed))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * (speed / maxSpeed), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    TestResultsView(
        result: SpeedTestResult(
            downloadSpeed: 45.2,
            uploadSpeed: 12.8,
            ping: 28,
            jitter: 2.1,
            connectionType: "Wi-Fi",
            serverLocation: "Test Server"
        ),
        isPresented: .constant(true)
    )
    .environmentObject(AppSettings())
}
