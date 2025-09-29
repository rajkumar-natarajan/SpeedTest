//
//  HistoryView.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import SwiftUI

struct HistoryView: View {
    @State private var testHistory: [SpeedTestResult] = []
    @State private var selectedResult: SpeedTestResult?
    @State private var showingResultDetail = false
    @State private var sortOption: SortOption = .dateDescending
    @EnvironmentObject var appSettings: AppSettings
    
    enum SortOption: String, CaseIterable {
        case dateDescending = "Date (Newest)"
        case dateAscending = "Date (Oldest)"
        case downloadSpeed = "Download Speed"
        case uploadSpeed = "Upload Speed"
        case ping = "Ping"
    }
    
    var sortedHistory: [SpeedTestResult] {
        switch sortOption {
        case .dateDescending:
            return testHistory.sorted { $0.timestamp > $1.timestamp }
        case .dateAscending:
            return testHistory.sorted { $0.timestamp < $1.timestamp }
        case .downloadSpeed:
            return testHistory.sorted { $0.downloadSpeed > $1.downloadSpeed }
        case .uploadSpeed:
            return testHistory.sorted { $0.uploadSpeed > $1.uploadSpeed }
        case .ping:
            return testHistory.sorted { $0.ping < $1.ping }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if testHistory.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Test History")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Your speed test results will appear here after you run your first test.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else {
                    // Sort picker
                    VStack {
                        HStack {
                            Text("Sort by:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("Sort", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Statistics overview
                        if !testHistory.isEmpty {
                            HistoryStatsView(results: testHistory)
                                .padding(.horizontal)
                        }
                    }
                    
                    // History list
                    List {
                        ForEach(sortedHistory, id: \.id) { result in
                            HistoryRowView(result: result)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedResult = result
                                    showingResultDetail = true
                                }
                        }
                        .onDelete(perform: deleteResults)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !testHistory.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Clear All History", role: .destructive) {
                                clearAllHistory()
                            }
                            
                            Button("Export History") {
                                exportHistory()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onAppear {
                loadHistory()
            }
            .sheet(isPresented: $showingResultDetail) {
                if let result = selectedResult {
                    TestResultsView(result: result, isPresented: $showingResultDetail)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadHistory() {
        testHistory = TestHistory.shared.getAllResults()
    }
    
    private func deleteResults(at offsets: IndexSet) {
        let resultsToDelete = offsets.map { sortedHistory[$0] }
        
        for result in resultsToDelete {
            TestHistory.shared.deleteResult(result)
        }
        
        loadHistory()
    }
    
    private func clearAllHistory() {
        TestHistory.shared.clearAllResults()
        testHistory = []
    }
    
    private func exportHistory() {
        let csvContent = generateCSV(from: testHistory)
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
}

// MARK: - History Row Component

struct HistoryRowView: View {
    let result: SpeedTestResult
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Quality indicator
                Circle()
                    .fill(qualityColor)
                    .frame(width: 12, height: 12)
                
                Text(formatDate(result.timestamp))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(result.connectionType)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("\(String(format: "%.1f", result.downloadSpeed)) Mbps")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Image(systemName: "arrow.up")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(String(format: "%.1f", result.uploadSpeed)) Mbps")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text("\(String(format: "%.0f", result.ping)) ms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Image(systemName: "timer")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Text(result.connectionQuality.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(qualityColor)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
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
}

// MARK: - History Statistics View

struct HistoryStatsView: View {
    let results: [SpeedTestResult]
    
    private var averageDownload: Double {
        guard !results.isEmpty else { return 0 }
        return results.map(\.downloadSpeed).reduce(0, +) / Double(results.count)
    }
    
    private var averageUpload: Double {
        guard !results.isEmpty else { return 0 }
        return results.map(\.uploadSpeed).reduce(0, +) / Double(results.count)
    }
    
    private var averagePing: Double {
        guard !results.isEmpty else { return 0 }
        return results.map(\.ping).reduce(0, +) / Double(results.count)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                StatBox(
                    title: "Avg Download",
                    value: String(format: "%.1f Mbps", averageDownload),
                    color: .green
                )
                
                StatBox(
                    title: "Avg Upload",
                    value: String(format: "%.1f Mbps", averageUpload),
                    color: .blue
                )
                
                StatBox(
                    title: "Avg Ping",
                    value: String(format: "%.0f ms", averagePing),
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Stat Box Component

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppSettings())
}
