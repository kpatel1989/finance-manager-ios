import SwiftUI
import SwiftData

struct AppRootView: View {
    @EnvironmentObject private var lockManager: AppLockManager
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            PortfolioBackground()

            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.xyaxis.line")
                    }
                    .tag(0)

                AccountsView()
                    .tabItem {
                        Label("Accounts", systemImage: "building.columns")
                    }
                    .tag(1)

                ExpenseView()
                    .tabItem {
                        Label("Expense", systemImage: "creditcard")
                    }
                    .tag(2)

                GoalsView()
                    .tabItem {
                        Label("Goals", systemImage: "target")
                    }
                    .tag(3)

                RemindersView()
                    .tabItem {
                        Label("Reminders", systemImage: "bell.badge")
                    }
                    .tag(4)
            }
            .tint(PortfolioTheme.accent)
            .onReceive(NotificationCenter.default.publisher(for: .portfolioQuickUpdateRequested)) { _ in
                selectedTab = 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .portfolioQuickPlannerRequested)) { _ in
                selectedTab = 4
            }

            if !lockManager.isLocked {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(PortfolioTheme.accent))
                }
                .padding(.top, 8)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            if lockManager.isLocked {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 40))
                    Text("Portfolio is locked")
                        .font(.headline)
                    Text("Use Face ID or device passcode to continue.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Unlock") {
                        let settings = fetchOrCreateSettings(in: modelContext)
                        Task {
                            await lockManager.unlockIfNeeded(isEnabled: settings.isAppLockEnabled)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
                .cardStyle()
                .padding(24)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}
