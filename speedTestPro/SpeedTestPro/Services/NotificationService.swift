import Foundation
import UserNotifications
import UIKit

/// Notification service for scheduling speed tests
@MainActor
class NotificationService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var scheduledTests: [ScheduledTest] = []
    
    static let shared = NotificationService()
    
    override init() {
        super.init()
        checkAuthorizationStatus()
        loadScheduledTests()
    }
    
    /// Request notification permission
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    /// Check current authorization status
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// Schedule a speed test notification
    func scheduleTest(_ test: ScheduledTest) async -> Bool {
        if !isAuthorized {
            let granted = await requestPermission()
            guard granted else { return false }
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Speed Test Reminder"
        content.body = "Time to run your scheduled speed test"
        content.sound = .default
        content.badge = 1
        content.userInfo = [
            "testId": test.id.uuidString,
            "action": "runTest"
        ]
        
        // Create trigger based on schedule type
        let trigger: UNNotificationTrigger
        
        switch test.schedule {
        case .once(let date):
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
        case .daily(let time):
            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
        case .weekly(let weekday, let time):
            var components = Calendar.current.dateComponents([.hour, .minute], from: time)
            components.weekday = weekday
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
        case .interval(let seconds):
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: true)
        }
        
        let request = UNNotificationRequest(
            identifier: test.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            scheduledTests.append(test)
            saveScheduledTests()
            return true
        } catch {
            print("Failed to schedule notification: \(error)")
            return false
        }
    }
    
    /// Cancel a scheduled test
    func cancelTest(_ test: ScheduledTest) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [test.id.uuidString])
        scheduledTests.removeAll { $0.id == test.id }
        saveScheduledTests()
    }
    
    /// Cancel all scheduled tests
    func cancelAllTests() {
        let identifiers = scheduledTests.map { $0.id.uuidString }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        scheduledTests.removeAll()
        saveScheduledTests()
    }
    
    /// Get pending notifications
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    
    /// Handle notification response
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        if let testIdString = userInfo["testId"] as? String,
           let testId = UUID(uuidString: testIdString),
           let action = userInfo["action"] as? String,
           action == "runTest" {
            
            // Find the scheduled test
            if let test = scheduledTests.first(where: { $0.id == testId }) {
                // Trigger the speed test
                NotificationCenter.default.post(
                    name: .scheduledTestTriggered,
                    object: test
                )
            }
        }
    }
    
    /// Load scheduled tests from UserDefaults
    private func loadScheduledTests() {
        if let data = UserDefaults.standard.data(forKey: "scheduledTests"),
           let tests = try? JSONDecoder().decode([ScheduledTest].self, from: data) {
            scheduledTests = tests
        }
    }
    
    /// Save scheduled tests to UserDefaults
    private func saveScheduledTests() {
        if let data = try? JSONEncoder().encode(scheduledTests) {
            UserDefaults.standard.set(data, forKey: "scheduledTests")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification, 
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              didReceive response: UNNotificationResponse, 
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            handleNotificationResponse(response)
        }
        completionHandler()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let scheduledTestTriggered = Notification.Name("scheduledTestTriggered")
}
