import SwiftData
import SwiftUI

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationScheduler: PortfolioNotificationScheduler

    @Query(sort: [SortDescriptor(\FinancialAccount.createdAt, order: .forward)]) private var accounts: [FinancialAccount]
    @Query(sort: [SortDescriptor(\BalanceSnapshot.date, order: .reverse)]) private var snapshots: [BalanceSnapshot]

    @State private var showingAddAccount = false

    private var settings: AppSettings {
        fetchOrCreateSettings(in: modelContext)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Accounts") {
                    ForEach(accounts.filter { !$0.isArchived }) { account in
                        NavigationLink {
                            AccountDetailView(account: account)
                        } label: {
                            HStack(spacing: 10) {
                                accountBadge(for: account)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(account.name)
                                        .font(.system(.headline, design: .rounded).weight(.semibold))
                                    Text("\(account.category.displayName) • \(account.displayTypeName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()

                            let amount = FinanceAnalytics.latestBalance(account: account, snapshots: snapshots)
                            Text(PortfolioFormatters.currency(amount, code: account.currency))
                                .font(.subheadline.bold())
                                .foregroundStyle(account.category == .liability ? PortfolioTheme.danger : .primary)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteAccount)
                }
            }
            .navigationTitle("Accounts")
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountSheet { account in
                    modelContext.insert(account)
                    try? modelContext.save()
                }
            }
        }
        .portfolioScreenBackground()
    }

    private func deleteAccount(at offsets: IndexSet) {
        let active = accounts.filter { !$0.isArchived }
        for index in offsets {
            let account = active[index]
            account.isArchived = true
            account.updatedAt = .now

            for snapshot in snapshots where snapshot.accountID == account.id {
                modelContext.delete(snapshot)
            }
        }

        markUpdated()
        try? modelContext.save()
    }

    private func markUpdated() {
        let mutableSettings = settings
        mutableSettings.lastFinancialUpdate = .now
        notificationScheduler.refreshSchedules(
            lastStatusUpdate: mutableSettings.lastFinancialUpdate,
            scheduledItems: fetchActiveScheduledItems(in: modelContext),
            now: .now
        )
    }

    @ViewBuilder
    private func accountBadge(for account: FinancialAccount) -> some View {
        let palette = account.category == .liability
            ? [PortfolioTheme.danger, PortfolioTheme.danger.opacity(0.4)]
            : [PortfolioTheme.accent, PortfolioTheme.accentSecondary]

        Circle()
            .fill(
                LinearGradient(
                    colors: palette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: symbol(for: account))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }

    private func symbol(for account: FinancialAccount) -> String {
        switch account.category {
        case .cashAndBanking:
            return "banknote"
        case .asset:
            return "house"
        case .liability:
            return "minus.circle"
        case .investment:
            return "chart.line.uptrend.xyaxis"
        }
    }
}

private struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: AccountCategory = .cashAndBanking
    @State private var type: AccountType = .checking
    @State private var customTypeName = ""
    @State private var currency: CurrencyCode = .usd
    @State private var notes = ""
    @State private var targetAllocation: Double = 0
    @State private var apr: Double = 0
    @State private var minimumPayment: Double = 0

    let onSave: (FinancialAccount) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(AccountCategory.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    Picker("Type", selection: $type) {
                        ForEach(AccountType.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    if type == .custom {
                        TextField("Custom type name", text: $customTypeName)
                    }

                    Picker("Currency", selection: $currency) {
                        ForEach(CurrencyCode.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }

                Section("Planning") {
                    if category == .investment {
                        HStack {
                            Text("Target allocation %")
                            Spacer()
                            TextField("0", value: $targetAllocation, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 110)
                        }
                    }

                    if category == .liability {
                        HStack {
                            Text("APR %")
                            Spacer()
                            TextField("0", value: $apr, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 110)
                        }

                        HStack {
                            Text("Minimum monthly payment")
                            Spacer()
                            TextField("0", value: $minimumPayment, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 150)
                        }
                    }

                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("New Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let account = FinancialAccount(
                            name: name,
                            category: category,
                            type: type,
                            currency: currency,
                            customTypeName: type == .custom ? customTypeName : nil,
                            notes: notes,
                            targetAllocationPercent: category == .investment ? targetAllocation : nil,
                            aprPercent: category == .liability ? apr : nil,
                            minimumMonthlyPayment: category == .liability ? minimumPayment : nil
                        )
                        onSave(account)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct AccountDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationScheduler: PortfolioNotificationScheduler

    let account: FinancialAccount

    @Query private var snapshots: [BalanceSnapshot]
    @State private var showingAddSnapshot = false

    init(account: FinancialAccount) {
        self.account = account
        let accountID = account.id
        _snapshots = Query(
            filter: #Predicate<BalanceSnapshot> { $0.accountID == accountID },
            sort: [SortDescriptor(\BalanceSnapshot.date, order: .reverse)]
        )
    }

    private var settings: AppSettings {
        fetchOrCreateSettings(in: modelContext)
    }

    var body: some View {
        List {
            Section("Account") {
                Text(account.name)
                Text("\(account.category.displayName) • \(account.displayTypeName)")
                    .foregroundStyle(.secondary)
                Text("Currency: \(account.currency.rawValue)")
                    .foregroundStyle(.secondary)
            }

            Section("Snapshots") {
                ForEach(snapshots) { snapshot in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline.bold())
                        Text("Balance: \(PortfolioFormatters.currency(snapshot.balance, code: account.currency))")
                        if snapshot.contribution != 0 {
                            Text("Contribution: \(PortfolioFormatters.currency(snapshot.contribution, code: account.currency))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !snapshot.note.isEmpty {
                            Text(snapshot.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteSnapshot)
            }
        }
        .navigationTitle(account.name)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSnapshot = true
                } label: {
                    Label("Quick Update", systemImage: "plus.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddSnapshot) {
            AddSnapshotSheet(currency: account.currency) { snapshot in
                modelContext.insert(
                    BalanceSnapshot(
                        accountID: account.id,
                        date: snapshot.date,
                        balance: snapshot.balance,
                        contribution: snapshot.contribution,
                        note: snapshot.note
                    )
                )
                account.updatedAt = .now

                let mutableSettings = settings
                mutableSettings.lastFinancialUpdate = .now
                notificationScheduler.refreshSchedules(
                    lastStatusUpdate: mutableSettings.lastFinancialUpdate,
                    scheduledItems: fetchActiveScheduledItems(in: modelContext),
                    now: .now
                )

                try? modelContext.save()
            }
        }
    }

    private func deleteSnapshot(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(snapshots[index])
        }
        try? modelContext.save()
    }
}

private struct SnapshotDraft {
    var date: Date
    var balance: Double
    var contribution: Double
    var note: String
}

private struct AddSnapshotSheet: View {
    @Environment(\.dismiss) private var dismiss

    let currency: CurrencyCode
    let onSave: (SnapshotDraft) -> Void

    @State private var date = Date()
    @State private var balance = 0.0
    @State private var contribution = 0.0
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: [.date])

                HStack {
                    Text("Balance")
                    Spacer()
                    TextField("0", value: $balance, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 150)
                }

                HStack {
                    Text("Contribution")
                    Spacer()
                    TextField("0", value: $contribution, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 150)
                }

                TextField("Note", text: $note, axis: .vertical)
                Text("All values in \(currency.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Add Snapshot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(SnapshotDraft(date: date, balance: balance, contribution: contribution, note: note))
                        dismiss()
                    }
                }
            }
        }
    }
}
