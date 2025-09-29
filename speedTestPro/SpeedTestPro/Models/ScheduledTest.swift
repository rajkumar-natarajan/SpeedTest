import Foundation

/// Represents a scheduled speed test
struct ScheduledTest: Identifiable, Codable {
    let id = UUID()
    let name: String
    let schedule: TestSchedule
    let isEnabled: Bool
    let createdAt: Date
    let settings: ScheduledTestSettings
    
    init(name: String, schedule: TestSchedule, settings: ScheduledTestSettings = ScheduledTestSettings()) {
        self.name = name
        self.schedule = schedule
        self.isEnabled = true
        self.createdAt = Date()
        self.settings = settings
    }
}

/// Different types of test schedules
enum TestSchedule: Codable, Equatable {
    case once(Date)
    case daily(Date) // Time of day
    case weekly(Int, Date) // Weekday (1-7) and time
    case interval(TimeInterval) // Seconds between tests
    
    var description: String {
        switch self {
        case .once(let date):
            return "Once on \(DateFormatter.medium.string(from: date))"
        case .daily(let time):
            return "Daily at \(DateFormatter.time.string(from: time))"
        case .weekly(let weekday, let time):
            let dayName = Calendar.current.weekdaySymbols[weekday - 1]
            return "\(dayName)s at \(DateFormatter.time.string(from: time))"
        case .interval(let seconds):
            return "Every \(Int(seconds / 3600)) hours"
        }
    }
    
    var nextOccurrence: Date? {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .once(let date):
            return date > now ? date : nil
            
        case .daily(let time):
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            let nextDaily = calendar.nextDate(after: now, matching: timeComponents, matchingPolicy: .nextTime)
            return nextDaily
            
        case .weekly(let weekday, let time):
            var components = calendar.dateComponents([.hour, .minute], from: time)
            components.weekday = weekday
            let nextWeekly = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
            return nextWeekly
            
        case .interval(let seconds):
            return now.addingTimeInterval(seconds)
        }
    }
}

/// Settings for scheduled tests
struct ScheduledTestSettings: Codable {
    let runInBackground: Bool
    let notifyOnCompletion: Bool
    let saveResults: Bool
    let preferredServer: String?
    
    init(runInBackground: Bool = true, 
         notifyOnCompletion: Bool = true, 
         saveResults: Bool = true, 
         preferredServer: String? = nil) {
        self.runInBackground = runInBackground
        self.notifyOnCompletion = notifyOnCompletion
        self.saveResults = saveResults
        self.preferredServer = preferredServer
    }
}

// MARK: - DateFormatter Extensions
extension DateFormatter {
    static let medium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
