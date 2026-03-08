import SwiftData
import SwiftUI

@main
struct PortfolioApp: App {
    @UIApplicationDelegateAdaptor(PortfolioAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var lockManager = AppLockManager()
    @StateObject private var notificationScheduler = PortfolioNotificationScheduler.shared

    init() {
        MockDataService.bootstrapDefaultsForTesting()
    }

    private let modelContainer: ModelContainer = {
        let schema = Schema([
            FinancialAccount.self,
            BalanceSnapshot.self,
            ExpenseSnapshot.self,
            FinancialGoal.self,
            RecurringContributionPlan.self,
            TaxEstimateLog.self,
            ScheduledItem.self,
            FXRateEntry.self,
            AccountTransfer.self,
            FinancialReviewSnapshot.self,
            QuickCaptureTemplate.self,
            AppSettings.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to initialize data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(lockManager)
                .environmentObject(notificationScheduler)
                .task {
                    await notificationScheduler.requestAuthorizationIfNeeded()
                    let context = ModelContext(modelContainer)
                    _ = try? MockDataService.seedIfNeeded(in: context, now: .now)
                    let settings = fetchOrCreateSettings(in: context)
                    notificationScheduler.isWeekendReminderEnabled = settings.weekendReminderEnabled
                    let scheduledItems = fetchActiveScheduledItems(in: context)
                    notificationScheduler.refreshSchedules(
                        lastStatusUpdate: settings.lastFinancialUpdate,
                        scheduledItems: scheduledItems,
                        now: .now
                    )
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        Task {
                            let context = ModelContext(modelContainer)
                            let settings = fetchOrCreateSettings(in: context)
                            let scheduledItems = fetchActiveScheduledItems(in: context)
                            notificationScheduler.isWeekendReminderEnabled = settings.weekendReminderEnabled
                            await lockManager.unlockIfNeeded(isEnabled: settings.isAppLockEnabled)
                            notificationScheduler.refreshSchedules(
                                lastStatusUpdate: settings.lastFinancialUpdate,
                                scheduledItems: scheduledItems,
                                now: .now
                            )
                        }
                    case .background:
                        lockManager.lock()
                    default:
                        break
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
