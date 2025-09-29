//
//  SpeedTestProTests.swift
//  SpeedTestProTests
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import XCTest
@testable import SpeedTestPro

/// Unit tests for SpeedTest Pro
final class SpeedTestProTests: XCTestCase {
    
    var appSettings: AppSettings!
    var testHistory: TestHistory!
    
    override func setUp() {
        super.setUp()
        appSettings = AppSettings()
        testHistory = TestHistory.shared
        
        // Clear any existing test data
        testHistory.clearAllResults()
        appSettings.resetToDefaults()
    }
    
    override func tearDown() {
        testHistory.clearAllResults()
        appSettings.resetToDefaults()
        appSettings = nil
        testHistory = nil
        super.tearDown()
    }
    
    // MARK: - App Settings Tests
    
    func testAppSettingsDefaults() {
        XCTAssertFalse(appSettings.isDarkMode, "Dark mode should be false by default")
        XCTAssertEqual(appSettings.speedUnit, .mbps, "Speed unit should be Mbps by default")
        XCTAssertTrue(appSettings.useLocationForServer, "Location usage should be true by default")
        XCTAssertFalse(appSettings.autoTestOnLaunch, "Auto-test should be false by default")
        XCTAssertFalse(appSettings.lowSpeedNotifications, "Low speed notifications should be false by default")
        XCTAssertEqual(appSettings.lowSpeedThreshold, 5.0, accuracy: 0.1, "Low speed threshold should be 5.0 by default")
    }
    
    func testAppSettingsPersistence() {
        // Change settings
        appSettings.isDarkMode = true
        appSettings.speedUnit = .kbps
        appSettings.lowSpeedThreshold = 10.0
        
        // Create new instance to test persistence
        let newSettings = AppSettings()
        
        XCTAssertTrue(newSettings.isDarkMode, "Dark mode setting should persist")
        XCTAssertEqual(newSettings.speedUnit, .kbps, "Speed unit setting should persist")
        XCTAssertEqual(newSettings.lowSpeedThreshold, 10.0, accuracy: 0.1, "Threshold setting should persist")
    }
    
    func testSpeedUnitConversion() {
        let mbpsValue = 100.0
        
        XCTAssertEqual(SpeedUnit.mbps.convert(from: mbpsValue), 100.0, accuracy: 0.1)
        XCTAssertEqual(SpeedUnit.kbps.convert(from: mbpsValue), 100000.0, accuracy: 0.1)
        XCTAssertEqual(SpeedUnit.mbytes.convert(from: mbpsValue), 12.5, accuracy: 0.1)
    }
    
    func testFormattedSpeed() {
        let speed = 25.5
        
        appSettings.speedUnit = .mbps
        XCTAssertEqual(appSettings.formattedSpeed(speed), "25.5 Mbps")
        
        appSettings.speedUnit = .kbps
        XCTAssertEqual(appSettings.formattedSpeed(speed), "25500 Kbps")
        
        appSettings.speedUnit = .mbytes
        XCTAssertEqual(appSettings.formattedSpeed(speed), "3.19 MB/s")
    }
    
    // MARK: - Connection Quality Tests
    
    func testConnectionQualityClassification() {
        XCTAssertEqual(ConnectionQuality.from(downloadSpeed: 60.0), .excellent)
        XCTAssertEqual(ConnectionQuality.from(downloadSpeed: 35.0), .good)
        XCTAssertEqual(ConnectionQuality.from(downloadSpeed: 15.0), .fair)
        XCTAssertEqual(ConnectionQuality.from(downloadSpeed: 5.0), .poor)
    }
    
    // MARK: - Test History Tests
    
    func testAddTestResult() {
        let result = SpeedTestResult(
            downloadSpeed: 50.0,
            uploadSpeed: 10.0,
            ping: 25.0,
            jitter: 2.0,
            connectionType: "Wi-Fi",
            serverLocation: "Test Server"
        )
        
        testHistory.addResult(result)
        
        let allResults = testHistory.getAllResults()
        XCTAssertEqual(allResults.count, 1, "Should have one result")
        XCTAssertEqual(allResults.first?.downloadSpeed, 50.0, accuracy: 0.1)
    }
    
    func testTestHistoryPersistence() {
        let result = SpeedTestResult(
            downloadSpeed: 25.0,
            uploadSpeed: 5.0,
            ping: 30.0,
            jitter: 1.5,
            connectionType: "Cellular",
            serverLocation: "Test Server"
        )
        
        testHistory.addResult(result)
        
        // Create new instance to test persistence
        let newHistory = TestHistory.shared
        let results = newHistory.getAllResults()
        
        XCTAssertEqual(results.count, 1, "Result should persist")
        XCTAssertEqual(results.first?.downloadSpeed, 25.0, accuracy: 0.1)
        XCTAssertEqual(results.first?.connectionType, "Cellular")
    }
    
    func testDeleteTestResult() {
        let result1 = SpeedTestResult(downloadSpeed: 50.0, uploadSpeed: 10.0, ping: 25.0, jitter: 2.0)
        let result2 = SpeedTestResult(downloadSpeed: 30.0, uploadSpeed: 8.0, ping: 35.0, jitter: 3.0)
        
        testHistory.addResult(result1)
        testHistory.addResult(result2)
        
        XCTAssertEqual(testHistory.getAllResults().count, 2)
        
        testHistory.deleteResult(result1)
        
        let remainingResults = testHistory.getAllResults()
        XCTAssertEqual(remainingResults.count, 1)
        XCTAssertEqual(remainingResults.first?.downloadSpeed, 30.0, accuracy: 0.1)
    }
    
    func testClearAllResults() {
        let result1 = SpeedTestResult(downloadSpeed: 50.0, uploadSpeed: 10.0, ping: 25.0, jitter: 2.0)
        let result2 = SpeedTestResult(downloadSpeed: 30.0, uploadSpeed: 8.0, ping: 35.0, jitter: 3.0)
        
        testHistory.addResult(result1)
        testHistory.addResult(result2)
        
        XCTAssertEqual(testHistory.getAllResults().count, 2)
        
        testHistory.clearAllResults()
        
        XCTAssertEqual(testHistory.getAllResults().count, 0)
    }
    
    func testHistoryLimit() {
        // Add more than the limit
        for i in 0..<105 {
            let result = SpeedTestResult(
                downloadSpeed: Double(i),
                uploadSpeed: Double(i) * 0.2,
                ping: 25.0,
                jitter: 2.0
            )
            testHistory.addResult(result)
        }
        
        XCTAssertEqual(testHistory.getAllResults().count, 100, "Should limit to 100 results")
    }
    
    // MARK: - Statistics Tests
    
    func testStatisticsCalculation() {
        let results = [
            SpeedTestResult(downloadSpeed: 50.0, uploadSpeed: 10.0, ping: 25.0, jitter: 2.0),
            SpeedTestResult(downloadSpeed: 30.0, uploadSpeed: 8.0, ping: 35.0, jitter: 3.0),
            SpeedTestResult(downloadSpeed: 40.0, uploadSpeed: 12.0, ping: 20.0, jitter: 1.5)
        ]
        
        for result in results {
            testHistory.addResult(result)
        }
        
        let stats = testHistory.getStatistics()
        
        XCTAssertEqual(stats.totalTests, 3)
        XCTAssertEqual(stats.averageDownloadSpeed, 40.0, accuracy: 0.1)
        XCTAssertEqual(stats.averageUploadSpeed, 10.0, accuracy: 0.1)
        XCTAssertEqual(stats.averagePing, 26.67, accuracy: 0.1)
        XCTAssertEqual(stats.maxDownloadSpeed, 50.0, accuracy: 0.1)
        XCTAssertEqual(stats.minPing, 20.0, accuracy: 0.1)
    }
    
    // MARK: - CSV Export Tests
    
    func testCSVExport() {
        let result = SpeedTestResult(
            downloadSpeed: 50.0,
            uploadSpeed: 10.0,
            ping: 25.0,
            jitter: 2.0,
            connectionType: "Wi-Fi",
            serverLocation: "Test Server"
        )
        
        testHistory.addResult(result)
        
        let csv = testHistory.exportResultsAsCSV()
        
        XCTAssertTrue(csv.contains("Date,Time,Download Speed (Mbps)"), "CSV should contain headers")
        XCTAssertTrue(csv.contains("50.00"), "CSV should contain download speed")
        XCTAssertTrue(csv.contains("10.00"), "CSV should contain upload speed")
        XCTAssertTrue(csv.contains("Wi-Fi"), "CSV should contain connection type")
    }
    
    // MARK: - Performance Tests
    
    func testSpeedTestResultPerformance() {
        measure {
            for _ in 0..<1000 {
                let result = SpeedTestResult(
                    downloadSpeed: Double.random(in: 1...100),
                    uploadSpeed: Double.random(in: 1...50),
                    ping: Double.random(in: 10...100),
                    jitter: Double.random(in: 1...10)
                )
                testHistory.addResult(result)
            }
            testHistory.clearAllResults()
        }
    }
    
    func testStatisticsPerformance() {
        // Add many results
        for i in 0..<1000 {
            let result = SpeedTestResult(
                downloadSpeed: Double(i % 100),
                uploadSpeed: Double(i % 50),
                ping: Double(i % 100 + 10),
                jitter: Double(i % 10)
            )
            testHistory.addResult(result)
        }
        
        measure {
            _ = testHistory.getStatistics()
        }
    }
}
