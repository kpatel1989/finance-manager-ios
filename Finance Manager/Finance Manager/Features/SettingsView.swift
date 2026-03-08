import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationScheduler: PortfolioNotificationScheduler

    @State private var loaded = false
    @State private var baseCurrency: CurrencyCode = .usd
    @State private var usdToCadRate = 1.35
    @State private var appLockEnabled = true
    @State private var weekendReminderEnabled = true
    @State private var mockDataModeEnabled = MockDataService.isMockModeEnabled
    @State private var mockDataStatusMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Currency") {
                    Picker("Base currency", selection: $baseCurrency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }

                    HStack {
                        Text("USD to CAD")
                        Spacer()
                        TextField("1.35", value: $usdToCadRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }

                    Text("Used for multi-currency net worth conversion with no external FX feed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Security") {
                    Toggle("Face ID / Passcode Lock", isOn: $appLockEnabled)
                        .tint(PortfolioTheme.accent)
                    Text("When enabled, Portfolio locks whenever app enters background.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Reminders") {
                    Toggle("Weekend reminder", isOn: $weekendReminderEnabled)
                        .tint(PortfolioTheme.accent)
                    Text("Weekly reminder: Sunday 9:00 PM local time. If not updated for 7 days, daily 9:00 PM reminders are scheduled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Testing") {
                    Toggle("Mock Data Mode", isOn: $mockDataModeEnabled)
                        .tint(PortfolioTheme.accentSecondary)
                    Text("Loads deterministic local testing data only. No network sync is used.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Reload 2 Years of Mock Data") {
                        reloadMockData()
                    }

                    if !mockDataStatusMessage.isEmpty {
                        Text(mockDataStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Tax API") {
                    let settings = fetchOrCreateSettings(in: modelContext)
                    Text("Mode: API key embedded in app bundle settings.")
                    Text("Security risk: embedded API keys can be extracted from app binaries.")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text("Embedded key value: \(settings.embeddedTaxAPIKey)")
                        .font(.caption2)
                        .textSelection(.enabled)

                    if let lastSync = settings.lastTaxSyncAt {
                        Text("Last tax sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listStyle(.insetGrouped)
            .onAppear {
                guard !loaded else { return }
                let settings = fetchOrCreateSettings(in: modelContext)
                baseCurrency = settings.baseCurrency
                usdToCadRate = settings.usdToCadRate
                appLockEnabled = settings.isAppLockEnabled
                weekendReminderEnabled = settings.weekendReminderEnabled
                mockDataModeEnabled = MockDataService.isMockModeEnabled
                loaded = true
            }
            .onChange(of: baseCurrency) { _, _ in persist() }
            .onChange(of: usdToCadRate) { _, _ in persist() }
            .onChange(of: appLockEnabled) { _, _ in persist() }
            .onChange(of: weekendReminderEnabled) { _, _ in persist() }
            .onChange(of: mockDataModeEnabled) { _, _ in persistMockMode() }
        }
        .portfolioScreenBackground()
    }

    private func persist() {
        guard loaded else { return }
        let settings = fetchOrCreateSettings(in: modelContext)
        settings.baseCurrency = baseCurrency
        settings.usdToCadRate = usdToCadRate
        settings.isAppLockEnabled = appLockEnabled
        settings.weekendReminderEnabled = weekendReminderEnabled

        try? modelContext.save()
        notificationScheduler.isWeekendReminderEnabled = weekendReminderEnabled
        notificationScheduler.refreshSchedules(
            lastStatusUpdate: settings.lastFinancialUpdate,
            scheduledItems: fetchActiveScheduledItems(in: modelContext),
            now: .now
        )
    }

    private func persistMockMode() {
        guard loaded else { return }
        MockDataService.setMockModeEnabled(mockDataModeEnabled)

        guard mockDataModeEnabled else {
            mockDataStatusMessage = "Mock data mode disabled."
            return
        }

        do {
            let inserted = try MockDataService.seedIfNeeded(in: modelContext, now: .now)
            mockDataStatusMessage = inserted
                ? "Loaded 24 months of mock data."
                : "Mock data mode enabled."

            let settings = fetchOrCreateSettings(in: modelContext)
            settings.lastFinancialUpdate = .now
            try? modelContext.save()
            notificationScheduler.refreshSchedules(
                lastStatusUpdate: settings.lastFinancialUpdate,
                scheduledItems: fetchActiveScheduledItems(in: modelContext),
                now: .now
            )
        } catch {
            mockDataStatusMessage = "Failed to load mock data."
        }
    }

    private func reloadMockData() {
        do {
            MockDataService.setMockModeEnabled(true)
            if !mockDataModeEnabled {
                mockDataModeEnabled = true
            }
            try MockDataService.resetAndSeed(in: modelContext, now: .now)
            mockDataStatusMessage = "Reloaded two years of mock data."

            let settings = fetchOrCreateSettings(in: modelContext)
            settings.lastFinancialUpdate = .now
            try? modelContext.save()
            notificationScheduler.refreshSchedules(
                lastStatusUpdate: settings.lastFinancialUpdate,
                scheduledItems: fetchActiveScheduledItems(in: modelContext),
                now: .now
            )
        } catch {
            mockDataStatusMessage = "Mock data reload failed."
        }
    }
}
