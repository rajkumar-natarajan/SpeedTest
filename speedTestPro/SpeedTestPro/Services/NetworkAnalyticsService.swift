//
//  NetworkAnalyticsService.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import Foundation
import CoreLocation
import os.log

/// Network performance prediction model
struct NetworkPrediction {
    let expectedDownloadSpeed: Double
    let expectedUploadSpeed: Double
    let expectedPing: Double
    let confidence: Double // 0.0 to 1.0
    let predictedQuality: ConnectionQuality
    let factors: [String] // Contributing factors
    let timeframe: String // "next hour", "next 6 hours", etc.
}

/// Network anomaly detection
struct NetworkAnomaly {
    let id = UUID()
    let detectedAt: Date
    let type: AnomalyType
    let severity: AnomalySeverity
    let description: String
    let affectedMetrics: [String]
    let suggestedAction: String?
}

enum AnomalyType {
    case speedDegradation
    case latencySpike
    case packetLoss
    case inconsistentPerformance
    case unusualPattern
}

enum AnomalySeverity: String, CaseIterable {
    case low, medium, high, critical
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

/// AI-powered network analytics service
@MainActor
class NetworkAnalyticsService: ObservableObject {
    @Published var predictions: [NetworkPrediction] = []
    @Published var detectedAnomalies: [NetworkAnomaly] = []
    @Published var performanceInsights: [String] = []
    @Published var isAnalyzing = false
    
    private let logger = Logger(subsystem: "SpeedTestPro", category: "Analytics")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Prediction Keys
    private let lastPredictionKey = "LastNetworkPrediction"
    private let analyticsDataKey = "AnalyticsHistoryData"
    
    init() {
        loadCachedPredictions()
    }
    
    // MARK: - AI-Powered Prediction
    
    /// Generate network performance predictions using historical data
    func generatePredictions(from history: [SpeedTestResult]) async {
        guard !history.isEmpty else { return }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        logger.info("Generating AI-powered network predictions from \(history.count) historical results")
        
        // Simulate AI processing delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        let predictions = await withTaskGroup(of: NetworkPrediction?.self) { group in
            var results: [NetworkPrediction] = []
            
            // Generate multiple predictions for different timeframes
            group.addTask { await self.predictPerformance(for: "next hour", history: history) }
            group.addTask { await self.predictPerformance(for: "next 6 hours", history: history) }
            group.addTask { await self.predictPerformance(for: "tomorrow", history: history) }
            
            for await prediction in group {
                if let prediction = prediction {
                    results.append(prediction)
                }
            }
            
            return results
        }
        
        self.predictions = predictions
        savePredictions()
        
        // Generate insights based on predictions
        generatePerformanceInsights(from: predictions, history: history)
    }
    
    /// Predict network performance for a specific timeframe
    private func predictPerformance(for timeframe: String, history: [SpeedTestResult]) async -> NetworkPrediction? {
        guard history.count >= 3 else { return nil }
        
        // Simple ML-inspired algorithm using weighted moving average and trend analysis
        let recentResults = Array(history.suffix(10)) // Use last 10 results
        let weights = (1...recentResults.count).map { Double($0) }
        let totalWeight = weights.reduce(0, +)
        
        // Weighted average calculation
        var weightedDownload = 0.0
        var weightedUpload = 0.0
        var weightedPing = 0.0
        
        for (index, result) in recentResults.enumerated() {
            let weight = weights[index] / totalWeight
            weightedDownload += result.downloadSpeed * weight
            weightedUpload += result.uploadSpeed * weight
            weightedPing += result.ping * weight
        }
        
        // Trend analysis
        let trendFactor = calculateTrendFactor(from: recentResults)
        let variabilityFactor = calculateVariabilityFactor(from: recentResults)
        
        // Apply trend and time-based adjustments
        let timeAdjustment = getTimeBasedAdjustment(for: timeframe)
        
        let predictedDownload = max(0, weightedDownload * trendFactor * timeAdjustment)
        let predictedUpload = max(0, weightedUpload * trendFactor * timeAdjustment)
        let predictedPing = max(1, weightedPing * (2 - trendFactor) * timeAdjustment)
        
        // Calculate confidence based on data consistency
        let confidence = calculateConfidence(variability: variabilityFactor, dataPoints: recentResults.count)
        
        // Determine predicted quality
        let predictedQuality = ConnectionQuality.from(downloadSpeed: predictedDownload)
        
        // Generate contributing factors
        let factors = generatePredictionFactors(
            trend: trendFactor,
            variability: variabilityFactor,
            timeframe: timeframe,
            recentResults: recentResults
        )
        
        return NetworkPrediction(
            expectedDownloadSpeed: predictedDownload,
            expectedUploadSpeed: predictedUpload,
            expectedPing: predictedPing,
            confidence: confidence,
            predictedQuality: predictedQuality,
            factors: factors,
            timeframe: timeframe
        )
    }
    
    // MARK: - Anomaly Detection
    
    /// Detect network anomalies in recent test results
    func detectAnomalies(from history: [SpeedTestResult]) {
        guard history.count >= 5 else { return }
        
        logger.info("Running anomaly detection on \(history.count) results")
        
        var anomalies: [NetworkAnomaly] = []
        let recentResults = Array(history.suffix(20))
        
        // Speed degradation detection
        if let speedAnomaly = detectSpeedDegradation(in: recentResults) {
            anomalies.append(speedAnomaly)
        }
        
        // Latency spike detection
        if let latencyAnomaly = detectLatencySpikes(in: recentResults) {
            anomalies.append(latencyAnomaly)
        }
        
        // Performance inconsistency detection
        if let inconsistencyAnomaly = detectInconsistentPerformance(in: recentResults) {
            anomalies.append(inconsistencyAnomaly)
        }
        
        self.detectedAnomalies = anomalies
    }
    
    // MARK: - Helper Methods
    
    private func calculateTrendFactor(from results: [SpeedTestResult]) -> Double {
        guard results.count >= 3 else { return 1.0 }
        
        let recent = Array(results.suffix(3))
        let older = Array(results.prefix(results.count - 3))
        
        let recentAvg = recent.reduce(0) { $0 + $1.downloadSpeed } / Double(recent.count)
        let olderAvg = older.reduce(0) { $0 + $1.downloadSpeed } / Double(older.count)
        
        return recentAvg / max(olderAvg, 1.0)
    }
    
    private func calculateVariabilityFactor(from results: [SpeedTestResult]) -> Double {
        let speeds = results.map { $0.downloadSpeed }
        let average = speeds.reduce(0, +) / Double(speeds.count)
        let variance = speeds.map { pow($0 - average, 2) }.reduce(0, +) / Double(speeds.count)
        return sqrt(variance) / average
    }
    
    private func getTimeBasedAdjustment(for timeframe: String) -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch timeframe {
        case "next hour":
            // Network typically slower during peak hours (7-9 PM)
            return hour >= 19 && hour <= 21 ? 0.8 : 1.0
        case "next 6 hours":
            return 0.95 // Slight degradation over time
        case "tomorrow":
            return 0.9 // Account for potential daily variations
        default:
            return 1.0
        }
    }
    
    private func calculateConfidence(variability: Double, dataPoints: Int) -> Double {
        let variabilityScore = max(0, 1 - variability)
        let dataScore = min(1.0, Double(dataPoints) / 10.0)
        return (variabilityScore + dataScore) / 2.0
    }
    
    private func generatePredictionFactors(
        trend: Double,
        variability: Double,
        timeframe: String,
        recentResults: [SpeedTestResult]
    ) -> [String] {
        var factors: [String] = []
        
        if trend > 1.1 {
            factors.append("Improving network performance trend")
        } else if trend < 0.9 {
            factors.append("Declining network performance trend")
        }
        
        if variability < 0.2 {
            factors.append("Consistent connection quality")
        } else if variability > 0.5 {
            factors.append("High variability in performance")
        }
        
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 19 && hour <= 21 {
            factors.append("Peak usage hours may affect speeds")
        }
        
        let connectionTypes = Set(recentResults.compactMap { $0.connectionType })
        if connectionTypes.count > 1 {
            factors.append("Mixed connection types in recent tests")
        }
        
        return factors
    }
    
    // MARK: - Anomaly Detection Methods
    
    private func detectSpeedDegradation(in results: [SpeedTestResult]) -> NetworkAnomaly? {
        guard results.count >= 5 else { return nil }
        
        let recent = Array(results.suffix(3))
        let baseline = Array(results.prefix(results.count - 3))
        
        let recentAvg = recent.reduce(0) { $0 + $1.downloadSpeed } / Double(recent.count)
        let baselineAvg = baseline.reduce(0) { $0 + $1.downloadSpeed } / Double(baseline.count)
        
        let degradation = (baselineAvg - recentAvg) / baselineAvg
        
        if degradation > 0.3 { // 30% degradation
            return NetworkAnomaly(
                detectedAt: Date(),
                type: .speedDegradation,
                severity: degradation > 0.5 ? .critical : .high,
                description: "Download speed has decreased by \(Int(degradation * 100))% compared to baseline",
                affectedMetrics: ["Download Speed"],
                suggestedAction: "Check for network congestion or contact your ISP"
            )
        }
        
        return nil
    }
    
    private func detectLatencySpikes(in results: [SpeedTestResult]) -> NetworkAnomaly? {
        guard results.count >= 5 else { return nil }
        
        let pings = results.map { $0.ping }
        let average = pings.reduce(0, +) / Double(pings.count)
        let recentPings = Array(pings.suffix(3))
        
        let spikes = recentPings.filter { $0 > average * 2 }
        
        if !spikes.isEmpty {
            return NetworkAnomaly(
                detectedAt: Date(),
                type: .latencySpike,
                severity: spikes.max()! > average * 3 ? .high : .medium,
                description: "Detected \(spikes.count) latency spike(s) in recent tests",
                affectedMetrics: ["Ping", "Jitter"],
                suggestedAction: "Check for background applications or network interference"
            )
        }
        
        return nil
    }
    
    private func detectInconsistentPerformance(in results: [SpeedTestResult]) -> NetworkAnomaly? {
        let variability = calculateVariabilityFactor(from: results)
        
        if variability > 0.6 {
            return NetworkAnomaly(
                detectedAt: Date(),
                type: .inconsistentPerformance,
                severity: variability > 0.8 ? .high : .medium,
                description: "Network performance is highly inconsistent",
                affectedMetrics: ["All Metrics"],
                suggestedAction: "Monitor network stability and consider router restart"
            )
        }
        
        return nil
    }
    
    // MARK: - Insights Generation
    
    private func generatePerformanceInsights(from predictions: [NetworkPrediction], history: [SpeedTestResult]) {
        var insights: [String] = []
        
        // Trend insights
        if let nextHourPrediction = predictions.first(where: { $0.timeframe == "next hour" }) {
            if nextHourPrediction.confidence > 0.7 {
                insights.append("High confidence prediction: \(nextHourPrediction.predictedQuality.rawValue.capitalized) performance expected in the next hour")
            }
        }
        
        // Historical insights
        if history.count >= 7 {
            let recentWeek = Array(history.suffix(7))
            let averageSpeed = recentWeek.reduce(0) { $0 + $1.downloadSpeed } / Double(recentWeek.count)
            
            if averageSpeed > 50 {
                insights.append("Your network consistently delivers high-speed performance")
            } else if averageSpeed < 10 {
                insights.append("Consider upgrading your internet plan for better performance")
            }
        }
        
        // Time-based insights
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 19 && hour <= 21 {
            insights.append("You're testing during peak hours - speeds may be lower than usual")
        }
        
        self.performanceInsights = insights
    }
    
    // MARK: - Persistence
    
    private func savePredictions() {
        do {
            let data = try JSONEncoder().encode(predictions)
            userDefaults.set(data, forKey: lastPredictionKey)
        } catch {
            logger.error("Failed to save predictions: \(error.localizedDescription)")
        }
    }
    
    private func loadCachedPredictions() {
        guard let data = userDefaults.data(forKey: lastPredictionKey) else { return }
        
        do {
            predictions = try JSONDecoder().decode([NetworkPrediction].self, from: data)
        } catch {
            logger.error("Failed to load cached predictions: \(error.localizedDescription)")
        }
    }
}

// MARK: - Codable Extensions

extension NetworkPrediction: Codable {}
