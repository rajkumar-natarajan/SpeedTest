import SwiftUI

struct ScheduledTestsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingAddTest = false
    @State private var selectedTest: ScheduledTest?
    
    var body: some View {
        NavigationView {
            VStack {
                if !notificationService.isAuthorized {
                    permissionPrompt
                } else {
                    testsList
                }
            }
            .navigationTitle("Scheduled Tests")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddTest = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(!notificationService.isAuthorized)
                }
            }
            .sheet(isPresented: $showingAddTest) {
                AddScheduledTestView()
            }
            .sheet(item: $selectedTest) { test in
                EditScheduledTestView(test: test)
            }
        }
    }
    
    private var permissionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Notifications Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enable notifications to schedule automatic speed tests")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Enable Notifications") {
                Task {
                    await notificationService.requestPermission()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var testsList: some View {
        Group {
            if notificationService.scheduledTests.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(notificationService.scheduledTests) { test in
                        ScheduledTestRow(test: test) {
                            selectedTest = test
                        }
                    }
                    .onDelete(perform: deleteTests)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Scheduled Tests")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the + button to schedule automatic speed tests")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func deleteTests(at offsets: IndexSet) {
        for index in offsets {
            let test = notificationService.scheduledTests[index]
            notificationService.cancelTest(test)
        }
    }
}

struct ScheduledTestRow: View {
    let test: ScheduledTest
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(test.name)
                    .font(.headline)
                
                Text(test.schedule.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let nextRun = test.schedule.nextOccurrence {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("Next: \(DateFormatter.medium.string(from: nextRun))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Toggle("", isOn: .constant(test.isEnabled))
                    .labelsHidden()
                
                Button("Edit") {
                    onEdit()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddScheduledTestView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationService = NotificationService.shared
    
    @State private var testName = ""
    @State private var selectedScheduleType = 0
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var selectedWeekday = 1
    @State private var intervalHours = 6
    
    private let scheduleTypes = ["Once", "Daily", "Weekly", "Interval"]
    private let weekdays = Calendar.current.weekdaySymbols
    
    var body: some View {
        NavigationView {
            Form {
                Section("Test Details") {
                    TextField("Test Name", text: $testName)
                }
                
                Section("Schedule") {
                    Picker("Type", selection: $selectedScheduleType) {
                        ForEach(0..<scheduleTypes.count, id: \.self) { index in
                            Text(scheduleTypes[index]).tag(index)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Group {
                        switch selectedScheduleType {
                        case 0: // Once
                            DatePicker("Date & Time", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                            
                        case 1: // Daily
                            DatePicker("Time", selection: $selectedTime, displayedComponents: [.hourAndMinute])
                            
                        case 2: // Weekly
                            Picker("Day of Week", selection: $selectedWeekday) {
                                ForEach(1...7, id: \.self) { day in
                                    Text(weekdays[day - 1]).tag(day)
                                }
                            }
                            DatePicker("Time", selection: $selectedTime, displayedComponents: [.hourAndMinute])
                            
                        case 3: // Interval
                            Stepper("Every \(intervalHours) hours", value: $intervalHours, in: 1...24)
                            
                        default:
                            EmptyView()
                        }
                    }
                }
                
                Section("Settings") {
                    HStack {
                        Text("Run in Background")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Notify on Completion")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Save Results")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("New Scheduled Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTest()
                    }
                    .disabled(testName.isEmpty)
                }
            }
        }
    }
    
    private func saveTest() {
        let schedule: TestSchedule
        
        switch selectedScheduleType {
        case 0: // Once
            schedule = .once(selectedDate)
        case 1: // Daily
            schedule = .daily(selectedTime)
        case 2: // Weekly
            schedule = .weekly(selectedWeekday, selectedTime)
        case 3: // Interval
            schedule = .interval(TimeInterval(intervalHours * 3600))
        default:
            return
        }
        
        let test = ScheduledTest(name: testName, schedule: schedule)
        
        Task {
            let success = await notificationService.scheduleTest(test)
            if success {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}

struct EditScheduledTestView: View {
    let test: ScheduledTest
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationService = NotificationService.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section("Test Details") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(test.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Schedule")
                        Spacer()
                        Text(test.schedule.description)
                            .foregroundColor(.secondary)
                    }
                    
                    if let nextRun = test.schedule.nextOccurrence {
                        HStack {
                            Text("Next Run")
                            Spacer()
                            Text(DateFormatter.medium.string(from: nextRun))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section("Actions") {
                    Button("Delete Test", role: .destructive) {
                        notificationService.cancelTest(test)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Scheduled Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ScheduledTestsView()
}
