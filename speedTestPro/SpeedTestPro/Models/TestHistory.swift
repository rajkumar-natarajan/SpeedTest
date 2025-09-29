//
//  TestHistory.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import Foundation
import os.log

/// Singleton class for managing speed test history using UserDefaults
class TestHistory: ObservableObject {
    static let shared = TestHistory()
    
    private let logger = Logger(subsystem: "SpeedTestPro", category: "TestHistory")
    private let userDefaults = UserDefaults.standard
    private let testHistoryKey = "speedtest_history"
    private let maxHistoryItems = 100 // Limit history to prevent excessive storage
    
    @Published var results: [SpeedTestResult] = []
    
    private init() {
        loadResults()
    }
    
    // MARK: - Public Methods
    
    /// Add a new test result to history
    func addResult(_ result: SpeedTestResult) {
        results.insert(result, at: 0) // Insert at beginning for newest first
        
        // Limit history size
        if results.count > maxHistoryItems {
            results = Array(results.prefix(maxHistoryItems))
        }
        
        saveResults()
        logger.info("Added new test result to history. Total count: \(self.results.count)")
    }
    
    /// Get all test results sorted by date (newest first)
    func getAllResults() -> [SpeedTestResult] {
        return results.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Get the most recent test result
    func getLastResult() -> SpeedTestResult? {
        return results.first
    }
    
    /// Get results filtered by date range
    func getResults(from startDate: Date, to endDate: Date) -> [SpeedTestResult] {
        return results.filter { result in
            result.timestamp >= startDate && result.timestamp <= endDate
        }
    }
    
    /// Get results filtered by connection type
    func getResults(for connectionType: String) -> [SpeedTestResult] {
        return results.filter { $0.connectionType == connectionType }
    }
    
    /// Get results filtered by connection quality
    func getResults(for quality: ConnectionQuality) -> [SpeedTestResult] {
        return results.filter { $0.connectionQuality == quality }
    }
    
    /// Delete a specific test result
    func deleteResult(_ result: SpeedTestResult) {
        results.removeAll { $0.id == result.id }
        saveResults()
        logger.info("Deleted test result. Remaining count: \(self.results.count)")
    }
    
    /// Delete results older than specified days
    func deleteResultsOlderThan(days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let originalCount = results.count
        
        results.removeAll { $0.timestamp < cutoffDate }
        saveResults()
        
        let deletedCount = originalCount - results.count
        logger.info("Deleted \(deletedCount) results older than \(days) days")
    }
    
    /// Clear all test results
    func clearAllResults() {
        results.removeAll()
        saveResults()
        logger.info("Cleared all test results")
    }
    
    /// Get statistics for all results
    func getStatistics() -> TestStatistics {
        return TestStatistics(results: results)
    }
    
    /// Get statistics for results in date range
    func getStatistics(from startDate: Date, to endDate: Date) -> TestStatistics {
        let filteredResults = getResults(from: startDate, to: endDate)
        return TestStatistics(results: filteredResults)
    }
    
    /// Export results as CSV string
    func exportResultsAsCSV() -> String {
        var csv = "Date,Time,Download Speed (Mbps),Upload Speed (Mbps),Ping (ms),Jitter (ms),Connection Type,Quality\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .medium
        
        let sortedResults = getAllResults()
        
        for result in sortedResults {
            let dateString = dateFormatter.string(from: result.timestamp)
            let timeString = timeFormatter.string(from: result.timestamp)
            
            let row = [
                dateString,
                timeString,
                String(format: "%.2f", result.downloadSpeed),
                String(format: "%.2f", result.uploadSpeed),
                String(format: "%.1f", result.ping),
                String(format: "%.1f", result.jitter),
                result.connectionType,
                result.connectionQuality.rawValue
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
    
    // MARK: - Private Methods
    
    /// Load results from UserDefaults
    private func loadResults() {
        guard let data = userDefaults.data(forKey: testHistoryKey) else {
            logger.info("No existing test history found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            results = try decoder.decode([SpeedTestResult].self, from: data)
            logger.info("Loaded \(self.results.count) test results from storage")
        } catch {
            logger.error("Failed to load test history: \(error.localizedDescription)")
            results = []
        }
    }
    
    /// Save results to UserDefaults
    private func saveResults() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(results)
            userDefaults.set(data, forKey: testHistoryKey)
            logger.debug("Saved \(self.results.count) test results to storage")
        } catch {
            logger.error("Failed to save test history: \(error.localizedDescription)")
        }
    }
}

// MARK: - Test Statistics

/// Statistics calculated from test results
struct TestStatistics {
    let totalTests: Int
    let averageDownloadSpeed: Double
    let averageUploadSpeed: Double
    let averagePing: Double
    let averageJitter: Double
    let maxDownloadSpeed: Double
    let maxUploadSpeed: Double
    let minPing: Double
    let connectionTypeBreakdown: [String: Int]
    let qualityBreakdown: [ConnectionQuality: Int]
    let dateRange: DateInterval?
    
    init(results: [SpeedTestResult]) {
        totalTests = results.count
        
        guard !results.isEmpty else {
            averageDownloadSpeed = 0
            averageUploadSpeed = 0
            averagePing = 0
            averageJitter = 0
            maxDownloadSpeed = 0
            maxUploadSpeed = 0
            minPing = 0
            connectionTypeBreakdown = [:]
            qualityBreakdown = [:]
            dateRange = nil
            return
        }
        
        // Calculate averages
        averageDownloadSpeed = results.map(\.downloadSpeed).reduce(0, +) / Double(results.count)
        averageUploadSpeed = results.map(\.uploadSpeed).reduce(0, +) / Double(results.count)
        averagePing = results.map(\.ping).reduce(0, +) / Double(results.count)
        averageJitter = results.map(\.jitter).reduce(0, +) / Double(results.count)
        
        // Calculate extremes
        maxDownloadSpeed = results.map(\.downloadSpeed).max() ?? 0
        maxUploadSpeed = results.map(\.uploadSpeed).max() ?? 0
        minPing = results.map(\.ping).min() ?? 0
        
        // Calculate breakdowns
        connectionTypeBreakdown = Dictionary(grouping: results, by: \.connectionType)
            .mapValues { $0.count }
        
        qualityBreakdown = Dictionary(grouping: results, by: \.connectionQuality)
            .mapValues { $0.count }
        
        // Calculate date range
        if let earliestDate = results.map(\.timestamp).min(),
           let latestDate = results.map(\.timestamp).max() {
            dateRange = DateInterval(start: earliestDate, end: latestDate)
        } else {
            dateRange = nil
        }
    }
    
    /// Get formatted summary string
    var summary: String {
        guard totalTests > 0 else {
            return "No test results available"
        }
        
        return """
        Total Tests: \(totalTests)
        Average Download: \(String(format: "%.1f", averageDownloadSpeed)) Mbps
        Average Upload: \(String(format: "%.1f", averageUploadSpeed)) Mbps
        Average Ping: \(String(format: "%.1f", averagePing)) ms
        Best Download: \(String(format: "%.1f", maxDownloadSpeed)) Mbps
        Best Upload: \(String(format: "%.1f", maxUploadSpeed)) Mbps
        Best Ping: \(String(format: "%.1f", minPing)) ms
        """
    }
}
