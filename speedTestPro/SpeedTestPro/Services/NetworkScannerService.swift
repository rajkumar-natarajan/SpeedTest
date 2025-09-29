//
//  NetworkScannerService.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import Foundation
import Network
import SystemConfiguration
import os.log

/// Service for scanning and discovering devices on the local network
@MainActor
class NetworkScannerService: ObservableObject {
    @Published var isScanning = false
    @Published var lastScanResult: NetworkScanResult?
    @Published var scanProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let logger = Logger(subsystem: "SpeedTestPro", category: "NetworkScanner")
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "LastNetworkScan"
    
    // Network scanning parameters
    private let scanTimeout: TimeInterval = 2.0
    private let maxConcurrentScans = 50
    
    init() {
        loadCachedScanResult()
    }
    
    // MARK: - Public Methods
    
    /// Scan the local network for connected devices
    func scanNetwork() async {
        guard !isScanning else { return }
        
        isScanning = true
        scanProgress = 0.0
        errorMessage = nil
        
        logger.info("Starting network scan...")
        
        do {
            let scanResult = try await performNetworkScan()
            lastScanResult = scanResult
            cacheScanResult(scanResult)
            logger.info("Network scan completed. Found \(scanResult.deviceCount) devices")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Network scan failed: \(error.localizedDescription)")
        }
        
        isScanning = false
        scanProgress = 1.0
    }
    
    /// Get current WiFi network information
    func getCurrentNetworkInfo() -> (ssid: String?, routerIP: String?) {
        var ssid: String?
        var routerIP: String?
        
        // Get WiFi SSID (requires entitlements in real app)
        if let interfaces = CNCopySupportedInterfaces() as? [String] {
            for interface in interfaces {
                if let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: AnyObject] {
                    ssid = info[kCNNetworkInfoKeySSID as String] as? String
                }
            }
        }
        
        // Get router IP (gateway)
        routerIP = getGatewayIP()
        
        return (ssid, routerIP)
    }
    
    // MARK: - Private Methods
    
    private func performNetworkScan() async throws -> NetworkScanResult {
        let startTime = Date()
        let networkInfo = getCurrentNetworkInfo()
        
        // Get local IP and subnet
        guard let localIP = getLocalIPAddress(),
              let subnet = getSubnetFromIP(localIP) else {
            throw NetworkScanError.noLocalNetwork
        }
        
        logger.info("Scanning subnet: \(subnet)")
        
        // Generate IP addresses to scan
        let ipAddresses = generateIPAddresses(for: subnet)
        let totalIPs = ipAddresses.count
        
        var discoveredDevices: [ConnectedDevice] = []
        var scannedCount = 0
        
        // Scan IPs in batches to avoid overwhelming the network
        let batchSize = min(maxConcurrentScans, totalIPs)
        
        for batch in ipAddresses.chunked(into: batchSize) {
            let batchResults = await withTaskGroup(of: ConnectedDevice?.self) { group in
                var results: [ConnectedDevice] = []
                
                for ip in batch {
                    group.addTask {
                        return await self.scanDevice(at: ip, isCurrentDevice: ip == localIP)
                    }
                }
                
                for await device in group {
                    if let device = device {
                        results.append(device)
                    }
                    scannedCount += 1
                    await MainActor.run {
                        self.scanProgress = Double(scannedCount) / Double(totalIPs)
                    }
                }
                
                return results
            }
            
            discoveredDevices.append(contentsOf: batchResults)
        }
        
        let scanDuration = Date().timeIntervalSince(startTime)
        
        return NetworkScanResult(
            scanDate: Date(),
            networkName: networkInfo.ssid,
            networkSSID: networkInfo.ssid,
            routerIP: networkInfo.routerIP,
            subnet: subnet,
            connectedDevices: discoveredDevices.sorted { $0.ipAddress.localizedStandardCompare($1.ipAddress) == .orderedAscending },
            scanDuration: scanDuration
        )
    }
    
    private func scanDevice(at ipAddress: String, isCurrentDevice: Bool) async -> ConnectedDevice? {
        // Try to ping the device
        let responseTime = await pingDevice(at: ipAddress)
        
        guard responseTime != nil else { return nil }
        
        // Try to resolve hostname
        let hostname = await resolveHostname(for: ipAddress)
        
        // Estimate device type and manufacturer
        let deviceType = estimateDeviceType(ip: ipAddress, hostname: hostname, isCurrentDevice: isCurrentDevice)
        let manufacturer = estimateManufacturer(hostname: hostname, deviceType: deviceType)
        
        return ConnectedDevice(
            ipAddress: ipAddress,
            macAddress: nil, // MAC address requires root privileges
            hostname: hostname,
            deviceType: deviceType,
            manufacturer: manufacturer,
            isCurrentDevice: isCurrentDevice,
            lastSeen: Date(),
            responseTime: responseTime
        )
    }
    
    private func pingDevice(at ipAddress: String) async -> TimeInterval? {
        return await withCheckedContinuation { continuation in
            let startTime = Date()
            
            // Create a simple TCP connection test
            let host = NWEndpoint.Host(ipAddress)
            guard let port = NWEndpoint.Port(rawValue: 80) else {
                continuation.resume(returning: nil)
                return
            }
            let endpoint = NWEndpoint.hostPort(host: host, port: port)
            
            let connection = NWConnection(to: endpoint, using: .tcp)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let responseTime = Date().timeIntervalSince(startTime)
                    connection.cancel()
                    continuation.resume(returning: responseTime)
                case .failed, .cancelled:
                    connection.cancel()
                    continuation.resume(returning: nil)
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            // Timeout after scanTimeout seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + scanTimeout) {
                connection.cancel()
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func resolveHostname(for ipAddress: String) async -> String? {
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue.global()
            queue.async {
                var hints = addrinfo()
                hints.ai_family = AF_INET
                hints.ai_socktype = SOCK_STREAM
                
                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(ipAddress, nil, &hints, &result)
                
                defer {
                    if let result = result {
                        freeaddrinfo(result)
                    }
                }
                
                if status == 0, let result = result {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let status = getnameinfo(result.pointee.ai_addr, result.pointee.ai_addrlen,
                                           &hostname, socklen_t(hostname.count),
                                           nil, 0, NI_NAMEREQD)
                    
                    if status == 0 {
                        let name = String(cString: hostname)
                        continuation.resume(returning: name.isEmpty ? nil : name)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func estimateDeviceType(ip: String, hostname: String?, isCurrentDevice: Bool) -> ConnectedDevice.DeviceType {
        if isCurrentDevice {
            return .smartphone // Assuming iOS device
        }
        
        guard let hostname = hostname?.lowercased() else {
            // Try to guess from IP patterns
            if ip.contains(".1") || ip.contains(".254") {
                return .router
            }
            return .unknown
        }
        
        // Device type estimation based on hostname patterns
        if hostname.contains("router") || hostname.contains("gateway") || hostname.contains("modem") {
            return .router
        } else if hostname.contains("iphone") || hostname.contains("android") || hostname.contains("mobile") {
            return .smartphone
        } else if hostname.contains("ipad") || hostname.contains("tablet") {
            return .tablet
        } else if hostname.contains("macbook") || hostname.contains("laptop") {
            return .laptop
        } else if hostname.contains("imac") || hostname.contains("desktop") || hostname.contains("pc") {
            return .desktop
        } else if hostname.contains("tv") || hostname.contains("roku") || hostname.contains("chromecast") {
            return .smartTV
        } else if hostname.contains("xbox") || hostname.contains("playstation") || hostname.contains("nintendo") {
            return .gameConsole
        } else if hostname.contains("printer") || hostname.contains("canon") || hostname.contains("hp") || hostname.contains("epson") {
            return .printer
        } else if hostname.contains("echo") || hostname.contains("homepod") || hostname.contains("speaker") {
            return .speaker
        } else if hostname.contains("thermostat") || hostname.contains("camera") || hostname.contains("sensor") {
            return .iotDevice
        }
        
        return .unknown
    }
    
    private func estimateManufacturer(hostname: String?, deviceType: ConnectedDevice.DeviceType) -> String? {
        guard let hostname = hostname?.lowercased() else { return nil }
        
        if hostname.contains("apple") || hostname.contains("iphone") || hostname.contains("ipad") || hostname.contains("macbook") || hostname.contains("imac") {
            return "Apple"
        } else if hostname.contains("samsung") {
            return "Samsung"
        } else if hostname.contains("google") || hostname.contains("chromecast") {
            return "Google"
        } else if hostname.contains("amazon") || hostname.contains("echo") {
            return "Amazon"
        } else if hostname.contains("microsoft") || hostname.contains("xbox") {
            return "Microsoft"
        } else if hostname.contains("sony") || hostname.contains("playstation") {
            return "Sony"
        } else if hostname.contains("nintendo") {
            return "Nintendo"
        } else if hostname.contains("roku") {
            return "Roku"
        }
        
        return nil
    }
    
    // MARK: - Network Utility Methods
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" { // WiFi interfaces
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        
        return address
    }
    
    private func getGatewayIP() -> String? {
        // This is a simplified implementation
        // In a real app, you'd need to parse routing table
        guard let localIP = getLocalIPAddress() else { return nil }
        
        let components = localIP.components(separatedBy: ".")
        guard components.count == 4 else { return nil }
        
        // Assume gateway is .1 in the subnet
        return "\(components[0]).\(components[1]).\(components[2]).1"
    }
    
    private func getSubnetFromIP(_ ip: String) -> String? {
        let components = ip.components(separatedBy: ".")
        guard components.count == 4 else { return nil }
        
        // Assume /24 subnet (255.255.255.0)
        return "\(components[0]).\(components[1]).\(components[2])"
    }
    
    private func generateIPAddresses(for subnet: String) -> [String] {
        var addresses: [String] = []
        
        // Scan common IP ranges (skip .0 and .255)
        for i in 1...254 {
            addresses.append("\(subnet).\(i)")
        }
        
        return addresses
    }
    
    // MARK: - Caching
    
    private func cacheScanResult(_ result: NetworkScanResult) {
        do {
            let data = try JSONEncoder().encode(result)
            userDefaults.set(data, forKey: cacheKey)
        } catch {
            logger.error("Failed to cache scan result: \(error)")
        }
    }
    
    private func loadCachedScanResult() {
        guard let data = userDefaults.data(forKey: cacheKey) else { return }
        
        do {
            let result = try JSONDecoder().decode(NetworkScanResult.self, from: data)
            // Only use cache if it's less than 1 hour old
            if Date().timeIntervalSince(result.scanDate) < 3600 {
                lastScanResult = result
            }
        } catch {
            logger.error("Failed to load cached scan result: \(error)")
        }
    }
}

// MARK: - Error Types

enum NetworkScanError: Error, LocalizedError {
    case noLocalNetwork
    case scanTimeout
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noLocalNetwork:
            return "No local network connection found"
        case .scanTimeout:
            return "Network scan timed out"
        case .permissionDenied:
            return "Network access permission denied"
        }
    }
}

// MARK: - Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// Import for network info (requires adding SystemConfiguration.framework)
import SystemConfiguration.CaptiveNetwork
