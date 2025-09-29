//
//  ConnectedDevicesView.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import SwiftUI

/// View component for displaying connected devices on the network
struct ConnectedDevicesView: View {
    @StateObject private var scanner = NetworkScannerService()
    @State private var showingDeviceDetails = false
    @State private var selectedDevice: ConnectedDevice?
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with scan button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connected Devices")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let scanResult = scanner.lastScanResult {
                        Text("\(scanResult.deviceCount) devices found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await scanner.scanNetwork()
                    }
                }) {
                    HStack {
                        if scanner.isScanning {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(scanner.isScanning ? "Scanning..." : "Scan")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(20)
                }
                .disabled(scanner.isScanning)
            }
            
            // Scan progress
            if scanner.isScanning {
                VStack(spacing: 8) {
                    ProgressView(value: scanner.scanProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    Text("Scanning network... \(Int(scanner.scanProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Error message
            if let errorMessage = scanner.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Devices list
            if let scanResult = scanner.lastScanResult {
                DevicesListView(
                    scanResult: scanResult,
                    onDeviceSelected: { device in
                        selectedDevice = device
                        showingDeviceDetails = true
                    }
                )
            } else if !scanner.isScanning {
                EmptyDevicesView()
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            // Auto-scan on first appearance if no cached data
            if scanner.lastScanResult == nil {
                Task {
                    await scanner.scanNetwork()
                }
            }
        }
        .sheet(isPresented: $showingDeviceDetails) {
            if let device = selectedDevice {
                DeviceDetailsView(device: device)
            }
        }
    }
}

// MARK: - Devices List View

struct DevicesListView: View {
    let scanResult: NetworkScanResult
    let onDeviceSelected: (ConnectedDevice) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Network info card
            NetworkInfoCard(scanResult: scanResult)
            
            // Device type summary
            DeviceTypeSummaryView(scanResult: scanResult)
            
            // Devices list
            LazyVStack(spacing: 8) {
                ForEach(scanResult.connectedDevices) { device in
                    DeviceRowView(device: device) {
                        onDeviceSelected(device)
                    }
                }
            }
        }
    }
}

// MARK: - Network Info Card

struct NetworkInfoCard: View {
    let scanResult: NetworkScanResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wifi")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(scanResult.networkSSID ?? "Unknown Network")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Router: \(scanResult.routerIP ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(scanResult.deviceCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Last scan: \(scanResult.scanDate, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Scan took \(String(format: "%.1f", scanResult.scanDuration))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Device Type Summary

struct DeviceTypeSummaryView: View {
    let scanResult: NetworkScanResult
    
    var body: some View {
        let devicesByType = scanResult.devicesByType
        
        if !devicesByType.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Device Types")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(Array(devicesByType.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { deviceType in
                        let devices = devicesByType[deviceType] ?? []
                        
                        HStack {
                            Image(systemName: deviceType.iconName)
                                .foregroundColor(Color(deviceType.color))
                                .font(.subheadline)
                            
                            Text(deviceType.rawValue)
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(devices.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}

// MARK: - Device Row View

struct DeviceRowView: View {
    let device: ConnectedDevice
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Device icon
                Image(systemName: device.deviceType.iconName)
                    .foregroundColor(Color(device.deviceType.color))
                    .font(.title3)
                    .frame(width: 24, height: 24)
                
                // Device info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(device.hostname ?? "Unknown Device")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if device.isCurrentDevice {
                            Text("(This device)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text(device.ipAddress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let manufacturer = device.manufacturer {
                            Text("• \(manufacturer)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let responseTime = device.responseTime {
                            Text("\(Int(responseTime * 1000))ms")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty Devices View

struct EmptyDevicesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Devices Found")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Tap the scan button to discover devices on your network")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Device Details View

struct DeviceDetailsView: View {
    let device: ConnectedDevice
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Device header
                    VStack(spacing: 16) {
                        Image(systemName: device.deviceType.iconName)
                            .font(.system(size: 64))
                            .foregroundColor(Color(device.deviceType.color))
                        
                        VStack(spacing: 4) {
                            Text(device.hostname ?? "Unknown Device")
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text(device.deviceType.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                    // Device details
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRow(title: "IP Address", value: device.ipAddress)
                        
                        if let manufacturer = device.manufacturer {
                            DetailRow(title: "Manufacturer", value: manufacturer)
                        }
                        
                        if let responseTime = device.responseTime {
                            DetailRow(title: "Response Time", value: "\(Int(responseTime * 1000)) ms")
                        }
                        
                        DetailRow(title: "Last Seen", value: device.lastSeen.formatted(date: .abbreviated, time: .shortened))
                        
                        if device.isCurrentDevice {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("This is your current device")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Device Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConnectedDevicesView()
}
