//
//  NetworkUtils.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import Foundation
import Network
import SystemConfiguration
import os.log

/// Network utility functions for connectivity and server management
class NetworkUtils {
    static let shared = NetworkUtils()
    
    private let logger = Logger(subsystem: "SpeedTestPro", category: "NetworkUtils")
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkUtilsQueue")
    
    /// Current network path
    @Published var currentPath: NWPath?
    
    /// Test server configurations
    struct TestServer {
        let name: String
        let url: String
        let location: String
        let region: String
        
        static let defaultServers = [
            TestServer(name: "Google", url: "https://www.google.com", location: "Global", region: "US"),
            TestServer(name: "Cloudflare", url: "https://www.cloudflare.com", location: "Global", region: "US"),
            TestServer(name: "Amazon", url: "https://www.amazon.com", location: "Global", region: "US"),
            TestServer(name: "Microsoft", url: "https://www.microsoft.com", location: "Global", region: "US"),
            TestServer(name: "Apple", url: "https://www.apple.com", location: "Global", region: "US")
        ]
    }
    
    private init() {
        startNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Network Monitoring
    
    /// Start monitoring network changes
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.currentPath = path
                self?.logger.info("Network path updated: \(path.debugDescription)")
            }
        }
        
        networkMonitor.start(queue: networkQueue)
    }
    
    /// Check if network is available
    func isNetworkAvailable() -> Bool {
        guard let path = currentPath else { return false }
        return path.status == .satisfied
    }
    
    /// Get current connection type
    func getCurrentConnectionType() -> ConnectionType {
        guard let path = currentPath, path.status == .satisfied else {
            return .unavailable
        }
        
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else {
            return .wifi // Default for other types (ethernet, etc.)
        }
    }
    
    /// Get network interface information
    func getNetworkInterfaceInfo() -> NetworkInterfaceInfo {
        var info = NetworkInterfaceInfo()
        
        guard let path = currentPath else {
            return info
        }
        
        info.isConnected = path.status == .satisfied
        info.isExpensive = path.isExpensive
        info.isConstrained = path.isConstrained
        info.supportsIPv4 = path.supportsIPv4
        info.supportsIPv6 = path.supportsIPv6
        info.supportsDNS = path.supportsDNS
        
        // Get available interfaces
        path.availableInterfaces.forEach { interface in
            switch interface.type {
            case .wifi:
                info.hasWiFi = true
            case .cellular:
                info.hasCellular = true
            case .wiredEthernet:
                info.hasEthernet = true
            case .loopback:
                info.hasLoopback = true
            case .other:
                info.hasOther = true
            @unknown default:
                break
            }
        }
        
        return info
    }
    
    // MARK: - Server Selection
    
    /// Get the best server for testing based on location (if available)
    func getBestTestServer() async -> TestServer {
        // For now, return a default server
        // In a production app, this would use location services to find the nearest server
        return TestServer.defaultServers.randomElement() ?? TestServer.defaultServers[0]
    }
    
    /// Test server connectivity
    func testServerConnectivity(server: TestServer) async throws -> ServerConnectivity {
        guard let url = URL(string: server.url) else {
            throw NetworkError.invalidURL
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringCacheData
        request.timeoutInterval = 10.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds
            
            if let httpResponse = response as? HTTPURLResponse {
                return ServerConnectivity(
                    server: server,
                    isReachable: httpResponse.statusCode < 400,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode
                )
            }
            
            return ServerConnectivity(
                server: server,
                isReachable: true,
                responseTime: responseTime,
                statusCode: 200
            )
            
        } catch {
            logger.error("Server connectivity test failed for \(server.name): \(error.localizedDescription)")
            return ServerConnectivity(
                server: server,
                isReachable: false,
                responseTime: 0,
                statusCode: 0
            )
        }
    }
    
    /// Test multiple servers and return the best one
    func findBestServer(from servers: [TestServer] = TestServer.defaultServers) async -> TestServer {
        logger.info("Testing connectivity to \(servers.count) servers")
        
        var bestServer = servers[0]
        var bestResponseTime = Double.infinity
        
        // Test servers concurrently
        await withTaskGroup(of: ServerConnectivity.self) { group in
            for server in servers {
                group.addTask {
                    do {
                        return try await self.testServerConnectivity(server: server)
                    } catch {
                        return ServerConnectivity(
                            server: server,
                            isReachable: false,
                            responseTime: Double.infinity,
                            statusCode: 0
                        )
                    }
                }
            }
            
            for await connectivity in group {
                if connectivity.isReachable && connectivity.responseTime < bestResponseTime {
                    bestServer = connectivity.server
                    bestResponseTime = connectivity.responseTime
                }
            }
        }
        
        logger.info("Best server selected: \(bestServer.name) with response time: \(bestResponseTime)ms")
        return bestServer
    }
    
    // MARK: - DNS Resolution
    
    /// Resolve hostname to IP addresses
    func resolveHostname(_ hostname: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
            
            var context = CFHostClientContext()
            CFHostSetClient(host, { (host, infoType, error, info) in
                guard let info = info else {
                    continuation.resume(throwing: NetworkError.dnsResolutionFailed)
                    return
                }
                
                let continuation = Unmanaged<CheckedContinuation<[String], Error>>.fromOpaque(info).takeRetainedValue()
                
                if let error = error?.pointee {
                    continuation.resume(throwing: NetworkError.dnsResolutionFailed)
                    return
                }
                
                var addresses: CFArray?
                let success = CFHostGetAddressing(host, &addresses)
                
                guard success, let addressArray = addresses else {
                    continuation.resume(throwing: NetworkError.dnsResolutionFailed)
                    return
                }
                
                var ipAddresses: [String] = []
                let count = CFArrayGetCount(addressArray)
                
                for i in 0..<count {
                    let addressData = CFArrayGetValueAtIndex(addressArray, i)
                    let data = Unmanaged<CFData>.fromOpaque(addressData!).takeUnretainedValue()
                    
                    let bytes = CFDataGetBytePtr(data)
                    let sockAddr = bytes!.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0.pointee }
                    
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = getnameinfo(&sockAddr, socklen_t(sockAddr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    
                    if result == 0 {
                        ipAddresses.append(String(cString: hostname))
                    }
                }
                
                continuation.resume(returning: ipAddresses)
            }, &context)
            
            let continuationPtr = Unmanaged.passRetained(continuation).toOpaque()
            var context2 = CFHostClientContext(version: 0, info: continuationPtr, retain: nil, release: nil, copyDescription: nil)
            CFHostSetClient(host, { (host, infoType, error, info) in
                // Handle the callback
            }, &context2)
            
            CFHostScheduleWithRunLoop(host, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            
            var error: CFStreamError = CFStreamError()
            let success = CFHostStartInfoResolution(host, .addresses, &error)
            
            if !success {
                continuation.resume(throwing: NetworkError.dnsResolutionFailed)
            }
        }
    }
}

// MARK: - Supporting Structures

/// Network interface information
struct NetworkInterfaceInfo {
    var isConnected = false
    var isExpensive = false
    var isConstrained = false
    var supportsIPv4 = false
    var supportsIPv6 = false
    var supportsDNS = false
    var hasWiFi = false
    var hasCellular = false
    var hasEthernet = false
    var hasLoopback = false
    var hasOther = false
}

/// Server connectivity test result
struct ServerConnectivity {
    let server: NetworkUtils.TestServer
    let isReachable: Bool
    let responseTime: Double // in milliseconds
    let statusCode: Int
}

/// Network-related errors
enum NetworkError: LocalizedError {
    case invalidURL
    case dnsResolutionFailed
    case connectionTimeout
    case noInternetConnection
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .dnsResolutionFailed:
            return "Failed to resolve hostname"
        case .connectionTimeout:
            return "Connection timed out"
        case .noInternetConnection:
            return "No internet connection available"
        }
    }
}

// MARK: - Extensions

extension NWPath {
    /// Debug description for network path
    var debugDescription: String {
        var description = "NWPath("
        description += "status: \(status), "
        description += "interfaces: \(availableInterfaces.count), "
        description += "expensive: \(isExpensive), "
        description += "constrained: \(isConstrained)"
        description += ")"
        return description
    }
}
