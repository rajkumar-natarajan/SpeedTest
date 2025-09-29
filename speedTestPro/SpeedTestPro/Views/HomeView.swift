//
//  HomeView.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import SwiftUI
import Network

struct HomeView: View {
    @StateObject private var speedTestViewModel = SpeedTestViewModel()
    @EnvironmentObject var appSettings: AppSettings
    @State private var showingResults = false
    @State private var lastTestResult: SpeedTestResult?
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 30) {
                    // App title and connection status
                    VStack(spacing: 10) {
                        Text("SpeedTest Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: connectionIcon)
                                .foregroundColor(connectionColor)
                            Text(connectionStatus)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // Main test button or progress indicator
                    if speedTestViewModel.isTestingInProgress {
                        // Testing in progress view
                        VStack(spacing: 20) {
                            // Animated progress ring
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                    .frame(width: 200, height: 200)
                                
                                Circle()
                                    .trim(from: 0, to: speedTestViewModel.testProgress)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .green]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                    )
                                    .frame(width: 200, height: 200)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut, value: speedTestViewModel.testProgress)
                                
                                VStack {
                                    Text(speedTestViewModel.currentTestPhase.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if speedTestViewModel.currentSpeed > 0 {
                                        Text(String(format: "%.1f Mbps", speedTestViewModel.currentSpeed))
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            // Cancel button
                            Button("Cancel Test") {
                                speedTestViewModel.cancelTest()
                            }
                            .foregroundColor(.red)
                        }
                        
                    } else {
                        // Start test button
                        Button(action: startSpeedTest) {
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white)
                                
                                Text("Start Test")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 200, height: 200)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .green]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                            .scaleEffect(speedTestViewModel.isTestingInProgress ? 0.95 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: speedTestViewModel.isTestingInProgress)
                        }
                        .disabled(speedTestViewModel.connectionType == .unavailable)
                    }
                    
                    Spacer()
                    
                    // Last test results summary (if available)
                    if let lastResult = lastTestResult, !speedTestViewModel.isTestingInProgress {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Test Results")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Download")
                                    Text("\(String(format: "%.1f", lastResult.downloadSpeed)) Mbps")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("Upload")
                                    Text("\(String(format: "%.1f", lastResult.uploadSpeed)) Mbps")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Ping")
                                    Text("\(String(format: "%.0f", lastResult.ping)) ms")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("Quality")
                                    Text(lastResult.connectionQuality.rawValue)
                                        .font(.caption)
                                        .foregroundColor(qualityColor(for: lastResult.connectionQuality))
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .onTapGesture {
                            // Navigate to detailed results
                            showingResults = true
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
            .onAppear {
                loadLastTestResult()
            }
            .onChange(of: speedTestViewModel.latestResult) { _, newResult in
                if let result = newResult {
                    lastTestResult = result
                    showingResults = true
                }
            }
            .sheet(isPresented: $showingResults) {
                if let result = lastTestResult {
                    TestResultsView(result: result, isPresented: $showingResults)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Start the speed test
    private func startSpeedTest() {
        Task {
            await speedTestViewModel.startSpeedTest()
        }
    }
    
    /// Load the last test result from storage
    private func loadLastTestResult() {
        lastTestResult = TestHistory.shared.getLastResult()
    }
    
    /// Get connection status icon
    private var connectionIcon: String {
        switch speedTestViewModel.connectionType {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .unavailable:
            return "wifi.slash"
        }
    }
    
    /// Get connection status text
    private var connectionStatus: String {
        switch speedTestViewModel.connectionType {
        case .wifi:
            return "Connected via Wi-Fi"
        case .cellular:
            return "Connected via Cellular"
        case .unavailable:
            return "No Internet Connection"
        }
    }
    
    /// Get connection status color
    private var connectionColor: Color {
        switch speedTestViewModel.connectionType {
        case .wifi, .cellular:
            return .green
        case .unavailable:
            return .red
        }
    }
    
    /// Get color for connection quality
    private func qualityColor(for quality: ConnectionQuality) -> Color {
        switch quality {
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
}

#Preview {
    HomeView()
        .environmentObject(AppSettings())
}
