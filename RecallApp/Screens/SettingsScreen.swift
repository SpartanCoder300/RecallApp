import SwiftUI

struct SettingsScreen: View {
    @AppStorage(AppSettings.reviewReminderEnabledKey) private var reviewReminderEnabled = false
    @AppStorage(AppSettings.reviewReminderHourKey) private var reviewReminderHour = 21
    @AppStorage(AppSettings.reviewReminderMinuteKey) private var reviewReminderMinute = 0
    @AppStorage(AppSettings.reviewCadenceKey) private var reviewCadenceRawValue = ReviewCadence.standard.rawValue

    @State private var showingReminderError = false
    @State private var reminderErrorMessage = ""

    private var reviewTime: Binding<Date> {
        Binding {
            let calendar = Calendar.current
            return calendar.date(
                bySettingHour: reviewReminderHour,
                minute: reviewReminderMinute,
                second: 0,
                of: Date()
            ) ?? Date()
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reviewReminderHour = components.hour ?? 21
            reviewReminderMinute = components.minute ?? 0

            if reviewReminderEnabled {
                Task {
                    try? await ReminderManager.scheduleDailyReminder(
                        hour: reviewReminderHour,
                        minute: reviewReminderMinute
                    )
                }
            }
        }
    }

    private var reviewCadence: Binding<ReviewCadence> {
        Binding {
            ReviewCadence(rawValue: reviewCadenceRawValue) ?? .standard
        } set: { newValue in
            reviewCadenceRawValue = newValue.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Review Reminder") {
                    Toggle("Daily reminder", isOn: reminderToggleBinding)

                    if reviewReminderEnabled {
                        DatePicker(
                            "Time",
                            selection: reviewTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                Section("Rating Cadence") {
                    Picker("Cadence", selection: reviewCadence) {
                        ForEach(ReviewCadence.allCases) { cadence in
                            Text(cadence.title).tag(cadence)
                        }
                    }

                    Text(reviewCadence.wrappedValue.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Subscription") {
                    Text("Daily Recall Pro — coming soon")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text(appVersionText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Settings")
            .formStyle(.grouped)
            .alert("Notifications Unavailable", isPresented: $showingReminderError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(reminderErrorMessage)
            }
            .task {
                await syncReminderState()
            }
        }
    }

    private var reminderToggleBinding: Binding<Bool> {
        Binding {
            reviewReminderEnabled
        } set: { newValue in
            if newValue {
                Task {
                    do {
                        let granted = try await ReminderManager.requestPermissionIfNeeded()
                        await MainActor.run {
                            if granted {
                                reviewReminderEnabled = true
                                Task {
                                    try? await ReminderManager.scheduleDailyReminder(
                                        hour: reviewReminderHour,
                                        minute: reviewReminderMinute
                                    )
                                }
                            } else {
                                reviewReminderEnabled = false
                                reminderErrorMessage = "Enable notifications in Settings to get review reminders."
                                showingReminderError = true
                            }
                        }
                    } catch {
                        await MainActor.run {
                            reviewReminderEnabled = false
                            reminderErrorMessage = "The app couldn’t request notification access."
                            showingReminderError = true
                        }
                    }
                }
            } else {
                reviewReminderEnabled = false
                ReminderManager.cancelReminder()
            }
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    private func syncReminderState() async {
        let status = await ReminderManager.authorizationStatus()
        let hasScheduledReminder = await ReminderManager.hasScheduledReminder()

        switch status {
        case .authorized, .provisional, .ephemeral:
            if reviewReminderEnabled, !hasScheduledReminder {
                try? await ReminderManager.scheduleDailyReminder(
                    hour: reviewReminderHour,
                    minute: reviewReminderMinute
                )
            }
        case .denied, .notDetermined:
            if reviewReminderEnabled {
                reviewReminderEnabled = false
            }
        @unknown default:
            reviewReminderEnabled = false
        }
    }
}

#Preview {
    SettingsScreen()
}
