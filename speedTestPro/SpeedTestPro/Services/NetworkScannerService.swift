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
import UIKit
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
    private let scanTimeout: TimeInterval = 1.0 // Reduced from 2.0
    private let maxConcurrentScans = 20 // Reduced from 50
    
    init() {
        loadCachedScanResult()
    }
    
    // MARK: - Public Methods
    
    /// Scan the local network for connected devices
    func scanNetwork() async {
        guard !isScanning else { 
            logger.info("Scan already in progress, ignoring request")
            return 
        }
        
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
        
        // Try multiple methods to get device name
        let deviceInfo = await getDeviceInfo(for: ipAddress, isCurrentDevice: isCurrentDevice)
        
        return ConnectedDevice(
            ipAddress: ipAddress,
            macAddress: nil, // MAC address requires root privileges
            hostname: deviceInfo.name,
            deviceType: deviceInfo.type,
            manufacturer: deviceInfo.manufacturer,
            isCurrentDevice: isCurrentDevice,
            lastSeen: Date(),
            responseTime: responseTime
        )
    }
    
    private func getDeviceInfo(for ipAddress: String, isCurrentDevice: Bool) async -> (name: String?, type: ConnectedDevice.DeviceType, manufacturer: String?) {
        if isCurrentDevice {
            return (
                name: UIDevice.current.name,
                type: .smartphone,
                manufacturer: "Apple"
            )
        }
        
        // Try multiple resolution methods
        var deviceName: String?
        var detectedType: ConnectedDevice.DeviceType = .unknown
        var manufacturer: String?
        
        // Method 1: Try hostname resolution
        deviceName = await resolveHostname(for: ipAddress)
        
        // Method 2: Try Bonjour/mDNS resolution if hostname failed
        if deviceName == nil {
            deviceName = await resolveBonjourName(for: ipAddress)
        }
        
        // Method 3: Try NETBIOS name resolution if others failed
        if deviceName == nil {
            deviceName = await resolveNetBIOSName(for: ipAddress)
        }
        
        // Method 4: Try to get device info from HTTP headers/server responses
        if deviceName == nil {
            let httpInfo = await getDeviceInfoFromHTTP(for: ipAddress)
            deviceName = httpInfo.name
            if detectedType == .unknown && httpInfo.type != .unknown {
                detectedType = httpInfo.type
            }
        }
        
        // Estimate device type and manufacturer from the resolved name
        if let name = deviceName {
            let typeAndManufacturer = estimateDeviceTypeAndManufacturer(from: name, ip: ipAddress)
            detectedType = typeAndManufacturer.type
            manufacturer = typeAndManufacturer.manufacturer
        } else {
            // Generate a friendly name based on IP and type
            detectedType = estimateDeviceType(ip: ipAddress, hostname: nil, isCurrentDevice: false)
            deviceName = generateFriendlyName(for: ipAddress, type: detectedType)
        }
        
        return (name: deviceName, type: detectedType, manufacturer: manufacturer)
    }
    
    private func pingDevice(at ipAddress: String) async -> TimeInterval? {
        return await withCheckedContinuation { continuation in
            let startTime = Date()
            var hasResumed = false
            let lock = NSLock()
            
            func resumeOnce(with value: TimeInterval?) {
                lock.lock()
                defer { lock.unlock() }
                
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: value)
                }
            }
            
            // Use a simpler approach with URLSession for better compatibility
            guard let url = URL(string: "http://\(ipAddress)") else {
                resumeOnce(with: nil)
                return
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = scanTimeout
            request.httpMethod = "HEAD"
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                let responseTime = Date().timeIntervalSince(startTime)
                
                // If we get any response (even error responses), the device is reachable
                if response != nil || (error as? NSError)?.code != NSURLErrorCannotConnectToHost {
                    resumeOnce(with: responseTime)
                } else {
                    resumeOnce(with: nil)
                }
            }
            
            task.resume()
            
            // Timeout fallback
            DispatchQueue.global().asyncAfter(deadline: .now() + scanTimeout + 0.1) {
                task.cancel()
                resumeOnce(with: nil)
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
    
    private func resolveBonjourName(for ipAddress: String) async -> String? {
        // Try to resolve using Bonjour/mDNS
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue.global()
            queue.async {
                // Simplified Bonjour resolution - in a real implementation,
                // you might use Network.framework or DNSServiceRef
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func resolveNetBIOSName(for ipAddress: String) async -> String? {
        // Try NetBIOS name resolution (for Windows devices)
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue.global()
            queue.async {
                // This would require more complex implementation
                // For now, return nil as NetBIOS is less common on modern networks
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func getDeviceInfoFromHTTP(for ipAddress: String) async -> (name: String?, type: ConnectedDevice.DeviceType) {
        // Try to get device information from HTTP responses
        return await withCheckedContinuation { continuation in
            guard let url = URL(string: "http://\(ipAddress)") else {
                continuation.resume(returning: (nil, .unknown))
                return
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 2.0
            request.setValue("SpeedTestPro/1.0", forHTTPHeaderField: "User-Agent")
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                var deviceName: String?
                var deviceType: ConnectedDevice.DeviceType = .unknown
                
                if let httpResponse = response as? HTTPURLResponse {
                    // Check for device-specific headers
                    if let server = httpResponse.allHeaderFields["Server"] as? String {
                        deviceName = self.extractDeviceNameFromServer(server)
                        deviceType = self.extractDeviceTypeFromServer(server)
                    }
                    
                    // Check for other identifying headers
                    if deviceName == nil {
                        for (key, value) in httpResponse.allHeaderFields {
                            if let keyStr = key as? String,
                               let valueStr = value as? String {
                                if keyStr.lowercased().contains("device") ||
                                   keyStr.lowercased().contains("model") ||
                                   keyStr.lowercased().contains("product") {
                                    deviceName = valueStr
                                    break
                                }
                            }
                        }
                    }
                }
                
                // Try to extract device info from HTML content
                if deviceName == nil, let data = data, let html = String(data: data, encoding: .utf8) {
                    deviceName = self.extractDeviceNameFromHTML(html)
                    if deviceType == .unknown {
                        deviceType = self.extractDeviceTypeFromHTML(html)
                    }
                }
                
                continuation.resume(returning: (deviceName, deviceType))
            }
            
            task.resume()
            
            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) {
                task.cancel()
                continuation.resume(returning: (nil, .unknown))
            }
        }
    }
    
    private func estimateDeviceTypeAndManufacturer(from name: String, ip: String) -> (type: ConnectedDevice.DeviceType, manufacturer: String?) {
        let lowercaseName = name.lowercased()
        
        // Device type estimation based on hostname patterns
        var deviceType: ConnectedDevice.DeviceType = .unknown
        var manufacturer: String?
        
        if lowercaseName.contains("router") || lowercaseName.contains("gateway") || lowercaseName.contains("modem") {
            deviceType = .router
        } else if lowercaseName.contains("iphone") {
            deviceType = .smartphone
            manufacturer = "Apple"
        } else if lowercaseName.contains("android") || lowercaseName.contains("mobile") {
            deviceType = .smartphone
        } else if lowercaseName.contains("ipad") {
            deviceType = .tablet
            manufacturer = "Apple"
        } else if lowercaseName.contains("tablet") {
            deviceType = .tablet
        } else if lowercaseName.contains("macbook") {
            deviceType = .laptop
            manufacturer = "Apple"
        } else if lowercaseName.contains("laptop") {
            deviceType = .laptop
        } else if lowercaseName.contains("imac") {
            deviceType = .desktop
            manufacturer = "Apple"
        } else if lowercaseName.contains("desktop") || lowercaseName.contains("pc") {
            deviceType = .desktop
        } else if lowercaseName.contains("tv") || lowercaseName.contains("roku") || lowercaseName.contains("chromecast") {
            deviceType = .smartTV
        } else if lowercaseName.contains("xbox") {
            deviceType = .gameConsole
            manufacturer = "Microsoft"
        } else if lowercaseName.contains("playstation") {
            deviceType = .gameConsole
            manufacturer = "Sony"
        } else if lowercaseName.contains("nintendo") {
            deviceType = .gameConsole
            manufacturer = "Nintendo"
        } else if lowercaseName.contains("printer") || lowercaseName.contains("canon") || lowercaseName.contains("hp") || lowercaseName.contains("epson") {
            deviceType = .printer
        } else if lowercaseName.contains("echo") || lowercaseName.contains("homepod") || lowercaseName.contains("speaker") {
            deviceType = .speaker
        } else if lowercaseName.contains("thermostat") || lowercaseName.contains("camera") || lowercaseName.contains("sensor") {
            deviceType = .iotDevice
        }
        
        // Try to extract manufacturer if not already set
        if manufacturer == nil {
            manufacturer = extractManufacturer(from: lowercaseName)
        }
        
        // If still unknown, try to guess from IP patterns
        if deviceType == .unknown {
            deviceType = estimateDeviceType(ip: ip, hostname: name, isCurrentDevice: false)
        }
        
        return (type: deviceType, manufacturer: manufacturer)
    }
    
    private func extractManufacturer(from name: String) -> String? {
        let lowercaseName = name.lowercased()
        
        if lowercaseName.contains("apple") || lowercaseName.contains("iphone") || lowercaseName.contains("ipad") || lowercaseName.contains("macbook") || lowercaseName.contains("imac") {
            return "Apple"
        } else if lowercaseName.contains("samsung") {
            return "Samsung"
        } else if lowercaseName.contains("google") || lowercaseName.contains("chromecast") {
            return "Google"
        } else if lowercaseName.contains("amazon") || lowercaseName.contains("echo") {
            return "Amazon"
        } else if lowercaseName.contains("microsoft") || lowercaseName.contains("xbox") {
            return "Microsoft"
        } else if lowercaseName.contains("sony") || lowercaseName.contains("playstation") {
            return "Sony"
        } else if lowercaseName.contains("nintendo") {
            return "Nintendo"
        } else if lowercaseName.contains("roku") {
            return "Roku"
        } else if lowercaseName.contains("hp") {
            return "HP"
        } else if lowercaseName.contains("canon") {
            return "Canon"
        } else if lowercaseName.contains("epson") {
            return "Epson"
        }
        
        return nil
    }
    
    private func generateFriendlyName(for ipAddress: String, type: ConnectedDevice.DeviceType) -> String {
        let lastOctet = ipAddress.components(separatedBy: ".").last ?? "X"
        
        switch type {
        case .router:
            return "Router (.1)" // Usually the router
        case .smartphone:
            return "Phone (.x\(lastOctet))"
        case .tablet:
            return "Tablet (.x\(lastOctet))"
        case .laptop:
            return "Laptop (.x\(lastOctet))"
        case .desktop:
            return "Computer (.x\(lastOctet))"
        case .smartTV:
            return "Smart TV (.x\(lastOctet))"
        case .gameConsole:
            return "Game Console (.x\(lastOctet))"
        case .iotDevice:
            return "Smart Device (.x\(lastOctet))"
        case .printer:
            return "Printer (.x\(lastOctet))"
        case .speaker:
            return "Speaker (.x\(lastOctet))"
        case .unknown:
            return "Device (.x\(lastOctet))"
        }
    }
    
    private func extractDeviceNameFromServer(_ server: String) -> String? {
        let lowercaseServer = server.lowercased()
        
        // Common device identifiers in server headers
        if lowercaseServer.contains("router") {
            return "Router"
        } else if lowercaseServer.contains("printer") {
            return "Network Printer"
        } else if lowercaseServer.contains("camera") {
            return "IP Camera"
        } else if lowercaseServer.contains("nas") {
            return "NAS Device"
        }
        
        return nil
    }
    
    private func extractDeviceTypeFromServer(_ server: String) -> ConnectedDevice.DeviceType {
        let lowercaseServer = server.lowercased()
        
        if lowercaseServer.contains("router") {
            return .router
        } else if lowercaseServer.contains("printer") {
            return .printer
        } else if lowercaseServer.contains("camera") {
            return .iotDevice
        } else if lowercaseServer.contains("nas") {
            return .iotDevice
        }
        
        return .unknown
    }
    
    private func extractDeviceNameFromHTML(_ html: String) -> String? {
        let lowercaseHTML = html.lowercased()
        
        // Look for common device identification patterns in HTML
        if lowercaseHTML.contains("<title>") {
            let titleRange = lowercaseHTML.range(of: "<title>")
            let endTitleRange = lowercaseHTML.range(of: "</title>")
            
            if let start = titleRange?.upperBound, let end = endTitleRange?.lowerBound {
                let title = String(html[start..<end])
                if !title.isEmpty && title.count < 50 { // Reasonable title length
                    return title
                }
            }
        }
        
        return nil
    }
    
    private func extractDeviceTypeFromHTML(_ html: String) -> ConnectedDevice.DeviceType {
        let lowercaseHTML = html.lowercased()
        
        if lowercaseHTML.contains("router") || lowercaseHTML.contains("gateway") {
            return .router
        } else if lowercaseHTML.contains("printer") {
            return .printer
        } else if lowercaseHTML.contains("camera") {
            return .iotDevice
        } else if lowercaseHTML.contains("thermostat") {
            return .iotDevice
        }
        
        return .unknown
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

// MARK: - Additional Helper Methods

extension NetworkScannerService {
    private func estimateDeviceType(ip: String, hostname: String?, isCurrentDevice: Bool) -> ConnectedDevice.DeviceType {
        if isCurrentDevice {
            return .smartphone // Assuming iOS device
        }
        
        // Try to guess from IP patterns if no hostname
        if hostname == nil {
            if ip.hasSuffix(".1") || ip.hasSuffix(".254") {
                return .router
            }
            return .unknown
        }
        
        // If we have a hostname, use the full analysis
        let result = estimateDeviceTypeAndManufacturer(from: hostname!, ip: ip)
        return result.type
    }
}

// Import for network info (requires adding SystemConfiguration.framework)
import SystemConfiguration.CaptiveNetwork
