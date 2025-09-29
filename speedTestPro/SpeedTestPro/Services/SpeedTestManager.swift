//
//  SpeedTestManager.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import Foundation
import Network
import os.log

/// Speed test errors
enum SpeedTestError: LocalizedError {
    case networkUnavailable
    case testCancelled
    case invalidResponse
    case timeoutError
    case serverUnavailable
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection is not available"
        case .testCancelled:
            return "Speed test was cancelled"
        case .invalidResponse:
            return "Invalid response from server"
        case .timeoutError:
            return "Test timed out"
        case .serverUnavailable:
            return "Test server is unavailable"
        }
    }
}

/// Ping test result
struct PingResult {
    let ping: Double // milliseconds
    let jitter: Double // milliseconds
}

/// Speed test result
struct SpeedResult {
    let speed: Double // Mbps
    let serverLocation: String
}

/// Core speed test manager using URLSession and Network framework
class SpeedTestManager: NSObject {
    // MARK: - Properties
    
    /// Progress callback
    var onProgressUpdate: ((TestPhase, Double, Double) -> Void)?
    
    private let logger = Logger(subsystem: "SpeedTestPro", category: "SpeedTest")
    private var isCancelled = false
    private let session: URLSession
    
    // Test configuration
    private let testServers = [
        "https://www.google.com",
        "https://httpbin.org",
        "https://www.cloudflare.com",
        "https://www.amazon.com"
    ]
    
    private let downloadTestURL = "https://httpbin.org/bytes/10000000" // 10MB test file
    private let uploadTestURL = "https://httpbin.org/post"
    private let pingTestHost = "8.8.8.8" // Google DNS
    
    // MARK: - Initialization
    
    override init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: configuration)
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Test ping latency and jitter
    func testPing() async throws -> PingResult {
        logger.info("Starting ping test")
        
        var pings: [Double] = []
        let pingCount = 5
        
        for i in 0..<pingCount {
            if isCancelled { throw SpeedTestError.testCancelled }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Use URL request to measure round-trip time
            var request = URLRequest(url: URL(string: testServers[0])!)
            request.httpMethod = "HEAD"
            request.cachePolicy = .reloadIgnoringCacheData
            
            do {
                let (_, response) = try await session.data(for: request)
                let endTime = CFAbsoluteTimeGetCurrent()
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let pingTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    pings.append(pingTime)
                    
                    // Update progress
                    let progress = 0.2 + (Double(i + 1) / Double(pingCount)) * 0.2
                    onProgressUpdate?(.ping, progress, pingTime)
                    
                    logger.debug("Ping \(i + 1): \(pingTime, privacy: .public)ms")
                }
            } catch {
                logger.error("Ping test failed: \(error.localizedDescription)")
                // Continue with other pings
            }
            
            // Wait between pings
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        
        guard !pings.isEmpty else {
            throw SpeedTestError.serverUnavailable
        }
        
        let averagePing = pings.reduce(0, +) / Double(pings.count)
        let jitter = calculateJitter(from: pings)
        
        logger.info("Ping test completed - Average: \(averagePing, privacy: .public)ms, Jitter: \(jitter, privacy: .public)ms")
        
        return PingResult(ping: averagePing, jitter: jitter)
    }
    
    /// Test download speed
    func testDownloadSpeed() async throws -> SpeedResult {
        logger.info("Starting download speed test")
        
        guard let url = URL(string: downloadTestURL) else {
            throw SpeedTestError.invalidResponse
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var totalBytes: Int64 = 0
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringCacheData
        
        do {
            let (asyncBytes, response) = try await session.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw SpeedTestError.invalidResponse
            }
            
            let expectedBytes = Int64(httpResponse.expectedContentLength)
            
            for try await _ in asyncBytes {
                if isCancelled { throw SpeedTestError.testCancelled }
                
                totalBytes += 1
                
                // Update progress every 100KB
                if totalBytes % 100_000 == 0 {
                    let currentTime = CFAbsoluteTimeGetCurrent()
                    let elapsed = currentTime - startTime
                    
                    if elapsed > 0 {
                        let speedMbps = (Double(totalBytes) * 8) / (elapsed * 1_000_000) // Convert to Mbps
                        let progress = 0.4 + (Double(totalBytes) / Double(expectedBytes)) * 0.4
                        onProgressUpdate?(.download, progress, speedMbps)
                    }
                }
            }
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let totalTime = endTime - startTime
            
            guard totalTime > 0 else {
                throw SpeedTestError.invalidResponse
            }
            
            // Calculate final speed in Mbps
            let speedMbps = (Double(totalBytes) * 8) / (totalTime * 1_000_000)
            
            logger.info("Download speed test completed - Speed: \(speedMbps, privacy: .public) Mbps")
            
            return SpeedResult(speed: speedMbps, serverLocation: "Test Server")
            
        } catch {
            logger.error("Download speed test failed: \(error.localizedDescription)")
            throw SpeedTestError.serverUnavailable
        }
    }
    
    /// Test upload speed
    func testUploadSpeed() async throws -> SpeedResult {
        logger.info("Starting upload speed test")
        
        guard let url = URL(string: uploadTestURL) else {
            throw SpeedTestError.invalidResponse
        }
        
        // Create test data (1MB)
        let testDataSize = 1_000_000
        let testData = Data(repeating: 0xAA, count: testDataSize)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = testData
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let (_, response) = try await session.data(for: request)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw SpeedTestError.invalidResponse
            }
            
            let totalTime = endTime - startTime
            
            guard totalTime > 0 else {
                throw SpeedTestError.invalidResponse
            }
            
            // Calculate speed in Mbps
            let speedMbps = (Double(testDataSize) * 8) / (totalTime * 1_000_000)
            
            onProgressUpdate?(.upload, 1.0, speedMbps)
            
            logger.info("Upload speed test completed - Speed: \(speedMbps, privacy: .public) Mbps")
            
            return SpeedResult(speed: speedMbps, serverLocation: "Test Server")
            
        } catch {
            logger.error("Upload speed test failed: \(error.localizedDescription)")
            throw SpeedTestError.serverUnavailable
        }
    }
    
    /// Cancel the current test
    func cancelTest() {
        logger.info("Speed test cancelled")
        isCancelled = true
        session.invalidateAndCancel()
    }
    
    // MARK: - Private Methods
    
    /// Calculate jitter from ping results
    private func calculateJitter(from pings: [Double]) -> Double {
        guard pings.count > 1 else { return 0.0 }
        
        var differences: [Double] = []
        
        for i in 1..<pings.count {
            let diff = abs(pings[i] - pings[i-1])
            differences.append(diff)
        }
        
        return differences.reduce(0, +) / Double(differences.count)
    }
}
