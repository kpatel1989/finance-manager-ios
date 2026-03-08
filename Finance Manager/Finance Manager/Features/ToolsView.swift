import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum ReviewPreset: String, CaseIterable, Identifiable {
    case ytd
    case qtd
    case rolling12
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ytd: return "YTD"
        case .qtd: return "QTD"
        case .rolling12: return "Rolling 12M"
        case .custom: return "Custom"
        }
    }
}

struct ToolsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationScheduler: PortfolioNotificationScheduler

    @Query(sort: [SortDescriptor(\FinancialAccount.createdAt, order: .forward)]) private var accounts: [FinancialAccount]
    @Query(sort: [SortDescriptor(\BalanceSnapshot.date, order: .forward)]) private var snapshots: [BalanceSnapshot]
    @Query(sort: [SortDescriptor(\ExpenseSnapshot.monthStart, order: .forward)]) private var expenses: [ExpenseSnapshot]
    @Query(sort: [SortDescriptor(\FinancialGoal.createdAt, order: .forward)]) private var goals: [FinancialGoal]
    @Query(sort: [SortDescriptor(\RecurringContributionPlan.createdAt, order: .forward)]) private var plans: [RecurringContributionPlan]
    @Query(sort: [SortDescriptor(\ScheduledItem.startDate, order: .forward)]) private var scheduledItems: [ScheduledItem]
    @Query(sort: [SortDescriptor(\FXRateEntry.asOfDate, order: .reverse)]) private var fxRates: [FXRateEntry]
    @Query(sort: [SortDescriptor(\AccountTransfer.transferDate, order: .reverse)]) private var transfers: [AccountTransfer]
    @Query(sort: [SortDescriptor(\FinancialReviewSnapshot.createdAt, order: .reverse)]) private var reviews: [FinancialReviewSnapshot]
    @Query(sort: [SortDescriptor(\QuickCaptureTemplate.createdAt, order: .forward)]) private var templates: [QuickCaptureTemplate]

    @State private var debtStrategy: DebtStrategy = .snowball
    @State private var extraPayment = 200.0

    @State private var importMessage = ""
    @State private var showImporter = false
    @State private var exportURL: URL?

    @State private var showSecureImporter = false
    @State private var securePassphrase = ""
    @State private var secureStatus = ""
    @State private var secureExportURL: URL?

    @State private var reviewPreset: ReviewPreset = .qtd
    @State private var reviewLabel = "Quarterly Review"
    @State private var reviewStart = Date().quarterStart
    @State private var reviewEnd = Date()

    @State private var fromCurrency: CurrencyCode = .usd
    @State private var toCurrency: CurrencyCode = .cad
    @State private var fxRateValue = 1.35
    @State private var fxAsOfDate = Date()

    @State private var transferFromAccountID: UUID?
    @State private var transferToAccountID: UUID?
    @State private var transferAmount = 0.0
    @State private var transferRate = 1.0
    @State private var transferDate = Date()
    @State private var transferNote = ""

    @State private var templateTitle = ""
    @State private var templateAccountID: UUID?
    @State private var templateBalanceDelta = 0.0
    @State private var templateContribution = 0.0
    @State private var templateNote = ""

    private var settings: AppSettings {
        fetchOrCreateSettings(in: modelContext)
    }

    private var baseCurrency: CurrencyCode {
        settings.baseCurrency
    }

    private var snowballPlan: DebtPayoffPlan {
        FinanceAnalytics.debtPayoffPlan(
            accounts: accounts,
            snapshots: snapshots,
            strategy: .snowball,
            extraMonthlyPayment: extraPayment
        )
    }

    private var avalanchePlan: DebtPayoffPlan {
        FinanceAnalytics.debtPayoffPlan(
            accounts: accounts,
            snapshots: snapshots,
            strategy: .avalanche,
            extraMonthlyPayment: extraPayment
        )
    }

    private var debtPlan: DebtPayoffPlan {
        debtStrategy == .snowball ? snowballPlan : avalanchePlan
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        TaxCalculatorView()
                    }
                    .cardStyle()

                    debtPlannerCard
                    advancedReviewCard
                    fxRatesCard
                    transferCard
                    quickTemplateCard
                    dataTransferCard
                    secureShareCard
                    quickUpdateCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Tools")
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let url = urls.first {
                    do {
                        let count = try CSVTransferService.importCSV(from: url, context: modelContext)
                        importMessage = "Imported \(count) records"
                        markUpdated()
                    } catch {
                        importMessage = "Import failed: \(error.localizedDescription)"
                    }
                }
            }
            .fileImporter(
                isPresented: $showSecureImporter,
                allowedContentTypes: [UTType.data],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let url = urls.first {
                    guard !securePassphrase.isEmpty else {
                        secureStatus = "Enter a passphrase before importing."
                        return
                    }
                    do {
                        let count = try SecureHouseholdShareService.importEncrypted(
                            from: url,
                            passphrase: securePassphrase,
                            context: modelContext
                        )
                        secureStatus = "Secure import complete (\(count) records)."
                        markUpdated()
                    } catch {
                        secureStatus = "Secure import failed: \(error.localizedDescription)"
                    }
                }
            }
            .onAppear {
                applyReviewPreset(reviewPreset)
            }
            .onChange(of: reviewPreset) { _, newValue in
                applyReviewPreset(newValue)
            }
        }
        .portfolioScreenBackground()
    }

    private var debtPlannerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Debt Payoff Planner 2.0", systemImage: "figure.run.square.stack")

            Picker("Strategy", selection: $debtStrategy) {
                ForEach(DebtStrategy.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Text("Extra payment: \(formattedCurrency(extraPayment))")
                .font(.caption)
            Slider(value: $extraPayment, in: 0...5_000, step: 25)
                .tint(PortfolioTheme.accent)

            HStack(spacing: 8) {
                MetricChip(
                    title: "Snowball",
                    value: "\(snowballPlan.monthsToDebtFree)m / \(formattedCurrency(snowballPlan.totalInterest))"
                )
                MetricChip(
                    title: "Avalanche",
                    value: "\(avalanchePlan.monthsToDebtFree)m / \(formattedCurrency(avalanchePlan.totalInterest))"
                )
            }

            Text("Selected plan: debt-free in \(debtPlan.monthsToDebtFree) months")
                .font(.subheadline.bold())
        }
        .cardStyle()
    }

    private var advancedReviewCard: some View {
        let metrics = FinanceAnalytics.reviewMetrics(
            accounts: accounts,
            snapshots: snapshots,
            expenses: expenses,
            baseCurrency: baseCurrency,
            usdToCadRate: settings.usdToCadRate,
            fxRates: fxRates,
            periodStart: reviewStart,
            periodEnd: reviewEnd
        )

        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Advanced Reviews", systemImage: "chart.bar.doc.horizontal")

            Picker("Preset", selection: $reviewPreset) {
                ForEach(ReviewPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            TextField("Review label", text: $reviewLabel)

            DatePicker("Start", selection: $reviewStart, displayedComponents: [.date])
                .disabled(reviewPreset != .custom)
            DatePicker("End", selection: $reviewEnd, displayedComponents: [.date])
                .disabled(reviewPreset != .custom)

            HStack(spacing: 8) {
                MetricChip(title: "NW Start", value: formattedCurrency(metrics.netWorthStart))
                MetricChip(title: "NW End", value: formattedCurrency(metrics.netWorthEnd))
            }

            HStack(spacing: 8) {
                MetricChip(title: "Expenses", value: formattedCurrency(metrics.totalExpenses), valueColor: PortfolioTheme.danger)
                MetricChip(title: "Contributions", value: formattedCurrency(metrics.totalContributions), valueColor: PortfolioTheme.success)
            }

            Button("Save Review Snapshot") {
                let snapshot = FinancialReviewSnapshot(
                    label: reviewLabel.isEmpty ? reviewPreset.displayName : reviewLabel,
                    periodStart: reviewStart,
                    periodEnd: reviewEnd,
                    netWorthStart: metrics.netWorthStart,
                    netWorthEnd: metrics.netWorthEnd,
                    totalExpenses: metrics.totalExpenses,
                    totalContributions: metrics.totalContributions
                )
                modelContext.insert(snapshot)
                try? modelContext.save()
            }
            .buttonStyle(.borderedProminent)
            .tint(PortfolioTheme.accent)

            if !reviews.isEmpty {
                Divider()
                ForEach(reviews.prefix(3)) { review in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(review.label)
                                .font(.subheadline.weight(.semibold))
                            Text("\(review.periodStart.formatted(date: .abbreviated, time: .omitted)) → \(review.periodEnd.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        let delta = review.netWorthEnd - review.netWorthStart
                        Text(formattedCurrency(delta))
                            .font(.caption.bold())
                            .foregroundStyle(delta >= 0 ? PortfolioTheme.success : PortfolioTheme.danger)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var fxRatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Multi-Currency FX Table", systemImage: "arrow.left.arrow.right.circle")

            HStack {
                Picker("From", selection: $fromCurrency) {
                    ForEach(CurrencyCode.allCases) { currency in
                        Text(currency.rawValue).tag(currency)
                    }
                }
                Picker("To", selection: $toCurrency) {
                    ForEach(CurrencyCode.allCases) { currency in
                        Text(currency.rawValue).tag(currency)
                    }
                }
            }

            HStack {
                Text("Rate")
                Spacer()
                TextField("1.00", value: $fxRateValue, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }
            DatePicker("As of", selection: $fxAsOfDate, displayedComponents: [.date])

            Button("Save FX Rate") {
                guard fromCurrency != toCurrency, fxRateValue > 0 else { return }
                modelContext.insert(
                    FXRateEntry(
                        fromCurrency: fromCurrency,
                        toCurrency: toCurrency,
                        rate: fxRateValue,
                        asOfDate: fxAsOfDate,
                        sourceDescription: "Manual entry"
                    )
                )
                try? modelContext.save()
            }
            .buttonStyle(.borderedProminent)
            .tint(PortfolioTheme.accentSecondary)

            if fxRates.isEmpty {
                Text("No FX rates yet. Add dated rates for USD/CAD and other manual conversions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(fxRates.prefix(5)) { rate in
                    HStack {
                        Text("\(rate.fromCurrency.rawValue)→\(rate.toCurrency.rawValue)")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(String(format: "%.4f", rate.rate))
                            .font(.caption)
                        Text(rate.asOfDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var transferCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Transfer Handling", systemImage: "arrow.left.arrow.right.square")

            Picker("From account", selection: $transferFromAccountID) {
                Text("Select").tag(UUID?.none)
                ForEach(accounts.filter { !$0.isArchived }) { account in
                    Text(account.name).tag(Optional(account.id))
                }
            }

            Picker("To account", selection: $transferToAccountID) {
                Text("Select").tag(UUID?.none)
                ForEach(accounts.filter { !$0.isArchived }) { account in
                    Text(account.name).tag(Optional(account.id))
                }
            }

            HStack {
                Text("From amount")
                Spacer()
                TextField("0", value: $transferAmount, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }

            HStack {
                Text("FX rate")
                Spacer()
                TextField("1.0", value: $transferRate, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }

            DatePicker("Date", selection: $transferDate, displayedComponents: [.date])
            TextField("Note", text: $transferNote)

            Button("Record Transfer + Apply Snapshots") {
                saveTransfer()
            }
            .buttonStyle(.borderedProminent)
            .tint(PortfolioTheme.accent)

            if !transfers.isEmpty {
                ForEach(transfers.prefix(3)) { transfer in
                    HStack {
                        Text(transfer.transferDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                        Spacer()
                        Text(formattedCurrency(transfer.fromAmount))
                            .font(.caption)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var quickTemplateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Quick Capture Templates", systemImage: "bolt.horizontal.circle")

            TextField("Template title", text: $templateTitle)
            Picker("Account", selection: $templateAccountID) {
                Text("Select").tag(UUID?.none)
                ForEach(accounts.filter { !$0.isArchived }) { account in
                    Text(account.name).tag(Optional(account.id))
                }
            }

            HStack {
                Text("Balance delta")
                Spacer()
                TextField("0", value: $templateBalanceDelta, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }

            HStack {
                Text("Contribution")
                Spacer()
                TextField("0", value: $templateContribution, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }

            TextField("Default note", text: $templateNote)

            Button("Save Template") {
                guard let accountID = templateAccountID else { return }
                modelContext.insert(
                    QuickCaptureTemplate(
                        title: templateTitle,
                        accountID: accountID,
                        balanceDelta: templateBalanceDelta,
                        contribution: templateContribution,
                        note: templateNote
                    )
                )
                try? modelContext.save()
                templateTitle = ""
                templateNote = ""
            }
            .buttonStyle(.borderedProminent)
            .tint(PortfolioTheme.accent)
            .disabled(templateTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || templateAccountID == nil)

            if templates.isEmpty {
                Text("No templates yet. Save one-tap entries for weekly or monthly updates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(templates) { template in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.title)
                                .font(.subheadline.weight(.semibold))
                            Text("Δ \(formattedCurrency(template.balanceDelta)) • +\(formattedCurrency(template.contribution))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Run") {
                            runTemplate(template)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var dataTransferCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Local CSV Transfer", systemImage: "arrow.left.arrow.right.doc")

            Text("Everything stays local to your device. Export for personal backup or migration.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Export CSV") {
                    exportURL = try? CSVTransferService.exportURL(
                        accounts: accounts,
                        snapshots: snapshots,
                        expenses: expenses,
                        goals: goals
                    )
                }
                .buttonStyle(.borderedProminent)

                Button("Import CSV") {
                    showImporter = true
                }
                .buttonStyle(.bordered)
            }

            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Share CSV File", systemImage: "square.and.arrow.up")
                }
            }

            if !importMessage.isEmpty {
                Text(importMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var secureShareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Private Household Share", systemImage: "lock.doc")

            SecureField("Passphrase", text: $securePassphrase)
                .textContentType(.password)

            HStack {
                Button("Export Encrypted Package") {
                    exportSecurePackage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(securePassphrase.isEmpty)

                Button("Import Encrypted Package") {
                    showSecureImporter = true
                }
                .buttonStyle(.bordered)
                .disabled(securePassphrase.isEmpty)
            }

            if let secureExportURL {
                ShareLink(item: secureExportURL) {
                    Label("Share Encrypted File", systemImage: "square.and.arrow.up")
                }
            }

            if !secureStatus.isEmpty {
                Text(secureStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Package is encrypted locally using your passphrase. No cloud sync required.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var quickUpdateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Quick Actions", systemImage: "bolt.fill")

            Text("Home-screen quick actions now include: Quick Update, Add Bill Reminder, and Open Tools.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Tip: keep 2-3 templates for weekend updates and recurring contribution entries.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private func saveTransfer() {
        guard
            let fromID = transferFromAccountID,
            let toID = transferToAccountID,
            fromID != toID,
            let fromAccount = accounts.first(where: { $0.id == fromID }),
            let toAccount = accounts.first(where: { $0.id == toID }),
            transferAmount > 0,
            transferRate > 0
        else {
            return
        }

        let toAmount = transferAmount * transferRate
        modelContext.insert(
            AccountTransfer(
                fromAccountID: fromID,
                toAccountID: toID,
                fromAmount: transferAmount,
                toAmount: toAmount,
                fxRate: transferRate,
                transferDate: transferDate,
                note: transferNote
            )
        )

        let fromCurrent = FinanceAnalytics.latestBalance(account: fromAccount, snapshots: snapshots, asOf: transferDate)
        let toCurrent = FinanceAnalytics.latestBalance(account: toAccount, snapshots: snapshots, asOf: transferDate)

        modelContext.insert(
            BalanceSnapshot(
                accountID: fromID,
                date: transferDate,
                balance: fromCurrent - transferAmount,
                contribution: 0,
                note: "Transfer out to \(toAccount.name)"
            )
        )

        modelContext.insert(
            BalanceSnapshot(
                accountID: toID,
                date: transferDate,
                balance: toCurrent + toAmount,
                contribution: 0,
                note: "Transfer in from \(fromAccount.name)"
            )
        )

        transferNote = ""
        markUpdated()
    }

    private func runTemplate(_ template: QuickCaptureTemplate) {
        guard let account = accounts.first(where: { $0.id == template.accountID }) else { return }
        let latest = FinanceAnalytics.latestBalance(account: account, snapshots: snapshots)
        modelContext.insert(
            BalanceSnapshot(
                accountID: account.id,
                date: .now,
                balance: latest + template.balanceDelta,
                contribution: template.contribution,
                note: template.note
            )
        )
        template.lastUsedAt = .now
        markUpdated()
    }

    private func exportSecurePackage() {
        do {
            secureExportURL = try SecureHouseholdShareService.exportEncrypted(
                accounts: accounts,
                snapshots: snapshots,
                expenses: expenses,
                goals: goals,
                plans: plans,
                scheduledItems: scheduledItems,
                fxRates: fxRates,
                transfers: transfers,
                reviews: reviews,
                templates: templates,
                passphrase: securePassphrase
            )
            secureStatus = "Encrypted package ready."
        } catch {
            secureStatus = "Export failed: \(error.localizedDescription)"
        }
    }

    private func applyReviewPreset(_ preset: ReviewPreset) {
        let now = Date()
        switch preset {
        case .ytd:
            reviewStart = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: now)) ?? now
            reviewEnd = now
            reviewLabel = "YTD Review"
        case .qtd:
            reviewStart = now.quarterStart
            reviewEnd = now
            reviewLabel = "Quarterly Review"
        case .rolling12:
            reviewStart = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
            reviewEnd = now
            reviewLabel = "Rolling 12M Review"
        case .custom:
            break
        }
    }

    private func markUpdated() {
        settings.lastFinancialUpdate = .now
        let activeItems = fetchActiveScheduledItems(in: modelContext)
        notificationScheduler.refreshSchedules(
            lastStatusUpdate: settings.lastFinancialUpdate,
            scheduledItems: activeItems,
            now: .now
        )
        try? modelContext.save()
    }

    private func formattedCurrency(_ value: Double) -> String {
        PortfolioFormatters.currency(value, code: baseCurrency)
    }
}
