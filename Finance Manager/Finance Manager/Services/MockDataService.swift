import Foundation
import SwiftData

@MainActor
enum MockDataService {
    static let modeKey = "portfolio.mockDataModeEnabled"

    private static let defaults = UserDefaults.standard
    private static let seedVersionKey = "portfolio.mockDataSeedVersion"
    private static let seedVersion = "2026.03.two-year-v2"
    private static let monthsOfData = 24

    static var isMockModeEnabled: Bool {
        defaults.bool(forKey: modeKey)
    }

    static func setMockModeEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: modeKey)
    }

    static func bootstrapDefaultsForTesting() {
#if targetEnvironment(simulator)
        if defaults.object(forKey: modeKey) == nil {
            defaults.set(true, forKey: modeKey)
        }
#endif
    }

    @discardableResult
    static func seedIfNeeded(in context: ModelContext, now: Date = .now) throws -> Bool {
        guard isMockModeEnabled else { return false }

        let existingSnapshots = try context.fetch(FetchDescriptor<BalanceSnapshot>())
        if defaults.string(forKey: seedVersionKey) == seedVersion || !existingSnapshots.isEmpty {
            try seedSupplementalDataIfNeeded(in: context, now: now)
            return false
        }

        try seed(in: context, now: now, replaceExisting: false)
        return true
    }

    static func resetAndSeed(in context: ModelContext, now: Date = .now) throws {
        try seed(in: context, now: now, replaceExisting: true)
    }

    private static func seed(in context: ModelContext, now: Date, replaceExisting: Bool) throws {
        if replaceExisting {
            try clearFinancialData(in: context)
        }

        let monthAnchors = monthlyAnchors(endingAt: now.monthStart, months: monthsOfData)
        guard let firstMonth = monthAnchors.first else { return }

        let accountBlueprints: [AccountBlueprint] = [
            AccountBlueprint(
                name: "Primary Checking",
                category: .cashAndBanking,
                type: .checking,
                currency: .usd,
                notes: "Daily spending account",
                targetAllocationPercent: nil,
                aprPercent: nil,
                minimumMonthlyPayment: nil,
                startingBalance: 9_500,
                endingBalance: 12_400,
                monthlyContribution: 0,
                seasonalVariance: 450
            ),
            AccountBlueprint(
                name: "High-Yield Savings",
                category: .cashAndBanking,
                type: .savings,
                currency: .usd,
                notes: "Emergency buffer",
                targetAllocationPercent: nil,
                aprPercent: nil,
                minimumMonthlyPayment: nil,
                startingBalance: 18_000,
                endingBalance: 26_600,
                monthlyContribution: 0,
                seasonalVariance: 350
            ),
            AccountBlueprint(
                name: "Taxable Brokerage",
                category: .investment,
                type: .brokerage,
                currency: .usd,
                notes: "Index funds and ETFs",
                targetAllocationPercent: 38,
                aprPercent: nil,
                minimumMonthlyPayment: nil,
                startingBalance: 52_000,
                endingBalance: 86_400,
                monthlyContribution: 700,
                seasonalVariance: 2_200
            ),
            AccountBlueprint(
                name: "Employer 401(k)",
                category: .investment,
                type: .retirement401k,
                currency: .usd,
                notes: "Employer matched retirement plan",
                targetAllocationPercent: 44,
                aprPercent: nil,
                minimumMonthlyPayment: nil,
                startingBalance: 88_000,
                endingBalance: 132_000,
                monthlyContribution: 900,
                seasonalVariance: 2_600
            ),
            AccountBlueprint(
                name: "Crypto Wallet",
                category: .investment,
                type: .cryptoWallet,
                currency: .usd,
                notes: "Long-term crypto allocation",
                targetAllocationPercent: 8,
                aprPercent: nil,
                minimumMonthlyPayment: nil,
                startingBalance: 9_000,
                endingBalance: 17_800,
                monthlyContribution: 150,
                seasonalVariance: 1_800
            ),
            AccountBlueprint(
                name: "Primary Residence",
                category: .asset,
                type: .realEstate,
                currency: .usd,
                notes: "Owner-occupied property estimate",
                targetAllocationPercent: nil,
                aprPercent: nil,
                minimumMonthlyPayment: nil,
                startingBalance: 475_000,
                endingBalance: 540_000,
                monthlyContribution: 0,
                seasonalVariance: 3_000
            ),
            AccountBlueprint(
                name: "Mortgage",
                category: .liability,
                type: .mortgage,
                currency: .usd,
                notes: "30-year fixed",
                targetAllocationPercent: nil,
                aprPercent: 5.3,
                minimumMonthlyPayment: 2_500,
                startingBalance: -365_000,
                endingBalance: -324_000,
                monthlyContribution: 0,
                seasonalVariance: 1_600
            ),
            AccountBlueprint(
                name: "Auto Loan",
                category: .liability,
                type: .autoLoan,
                currency: .usd,
                notes: "Remaining vehicle financing",
                targetAllocationPercent: nil,
                aprPercent: 6.2,
                minimumMonthlyPayment: 540,
                startingBalance: -22_000,
                endingBalance: -8_500,
                monthlyContribution: 0,
                seasonalVariance: 500
            ),
            AccountBlueprint(
                name: "Credit Card",
                category: .liability,
                type: .creditCard,
                currency: .usd,
                notes: "Rotating monthly card use",
                targetAllocationPercent: nil,
                aprPercent: 19.9,
                minimumMonthlyPayment: 220,
                startingBalance: -6_200,
                endingBalance: -1_900,
                monthlyContribution: 0,
                seasonalVariance: 750
            ),
            AccountBlueprint(
                name: "Canadian TFSA",
                category: .investment,
                type: .tfsa,
                currency: .cad,
                notes: "CAD growth sleeve",
                targetAllocationPercent: 10,
                aprPercent: nil,
                minimumMonthlyPayment: nil,
                startingBalance: 24_000,
                endingBalance: 39_000,
                monthlyContribution: 350,
                seasonalVariance: 1_400
            )
        ]

        var createdAccounts: [FinancialAccount] = []
        for blueprint in accountBlueprints {
            let account = FinancialAccount(
                name: blueprint.name,
                category: blueprint.category,
                type: blueprint.type,
                currency: blueprint.currency,
                notes: blueprint.notes,
                targetAllocationPercent: blueprint.targetAllocationPercent,
                aprPercent: blueprint.aprPercent,
                minimumMonthlyPayment: blueprint.minimumMonthlyPayment,
                createdAt: firstMonth,
                updatedAt: now
            )
            context.insert(account)
            createdAccounts.append(account)
        }

        for account in createdAccounts {
            guard let blueprint = accountBlueprints.first(where: { $0.name == account.name }) else { continue }
            for (index, date) in monthAnchors.enumerated() {
                let progress = Double(index) / Double(max(monthAnchors.count - 1, 1))
                var balance = blueprint.startingBalance + ((blueprint.endingBalance - blueprint.startingBalance) * progress)
                balance += sin(Double(index) * .pi / 6) * blueprint.seasonalVariance
                if blueprint.category == .liability {
                    balance = min(balance, -10)
                }

                let snapshot = BalanceSnapshot(
                    accountID: account.id,
                    date: date,
                    balance: roundedMoney(balance),
                    contribution: roundedMoney(blueprint.monthlyContribution),
                    note: index % 6 == 0 ? "Monthly review update" : ""
                )
                context.insert(snapshot)
            }
        }

        seedExpenseSnapshots(in: context, monthAnchors: monthAnchors)
        seedGoals(in: context, now: now, firstMonth: firstMonth, accounts: createdAccounts)
        seedTaxLogs(in: context, now: now)
        seedScheduledItems(in: context, now: now, accounts: createdAccounts)
        seedFXAndTemplates(in: context, now: now, accounts: createdAccounts)

        let settings = fetchOrCreateSettings(in: context)
        settings.lastFinancialUpdate = now
        settings.baseCurrency = .usd
        settings.usdToCadRate = 1.36
        settings.lastTaxSyncAt = now

        try context.save()
        defaults.set(seedVersion, forKey: seedVersionKey)
    }

    private static func seedExpenseSnapshots(in context: ModelContext, monthAnchors: [Date]) {
        let baseCategoryTotals: [(ExpenseCategory, Double)] = [
            (.housing, 2_650),
            (.transport, 640),
            (.food, 920),
            (.utilities, 390),
            (.healthcare, 270),
            (.insurance, 350),
            (.debt, 520),
            (.savings, 1_150),
            (.entertainment, 420),
            (.education, 180),
            (.travel, 260),
            (.other, 210)
        ]

        for (index, month) in monthAnchors.enumerated() {
            let inflationMultiplier = 1 + (Double(index) * 0.0025)
            let seasonality = sin(Double(index) * .pi / 6)

            for (category, baseAmount) in baseCategoryTotals {
                let amount = (baseAmount * inflationMultiplier) + (baseAmount * 0.05 * seasonality)
                context.insert(
                    ExpenseSnapshot(
                        monthStart: month.monthStart,
                        category: category,
                        amount: roundedMoney(max(amount, 0))
                    )
                )
            }
        }
    }

    private static func seedGoals(
        in context: ModelContext,
        now: Date,
        firstMonth: Date,
        accounts: [FinancialAccount]
    ) {
        let emergencyFund = FinancialGoal(
            title: "Emergency Fund",
            type: .emergencyFund,
            targetAmount: 30_000,
            currentAmount: 18_000,
            monthlyContribution: 800,
            targetDate: Calendar.current.date(byAdding: .month, value: 18, to: now) ?? now,
            createdAt: firstMonth,
            note: "Target 6 months of expenses"
        )
        context.insert(emergencyFund)

        let retirementGoal = FinancialGoal(
            title: "Retirement Bridge",
            type: .retirement,
            targetAmount: 250_000,
            currentAmount: 112_000,
            monthlyContribution: 1_400,
            targetDate: Calendar.current.date(byAdding: .year, value: 8, to: now) ?? now,
            createdAt: firstMonth,
            note: "Bridge account before pension age"
        )
        context.insert(retirementGoal)

        let downPayment = FinancialGoal(
            title: "Vacation Home Down Payment",
            type: .homeDownPayment,
            targetAmount: 90_000,
            currentAmount: 23_000,
            monthlyContribution: 950,
            targetDate: Calendar.current.date(byAdding: .year, value: 4, to: now) ?? now,
            createdAt: firstMonth,
            note: "Secondary property goal"
        )
        context.insert(downPayment)

        if let brokerage = accounts.first(where: { $0.type == .brokerage }) {
            context.insert(
                RecurringContributionPlan(
                    title: "Brokerage Auto-Invest",
                    targetID: brokerage.id,
                    targetKind: .account,
                    monthlyAmount: 700,
                    startDate: firstMonth
                )
            )
        }

        context.insert(
            RecurringContributionPlan(
                title: "Emergency Fund Top-Up",
                targetID: emergencyFund.id,
                targetKind: .goal,
                monthlyAmount: 800,
                startDate: firstMonth
            )
        )

        context.insert(
            RecurringContributionPlan(
                title: "Retirement Monthly Contribution",
                targetID: retirementGoal.id,
                targetKind: .goal,
                monthlyAmount: 1_400,
                startDate: firstMonth
            )
        )
    }

    private static func seedTaxLogs(in context: ModelContext, now: Date) {
        context.insert(
            TaxEstimateLog(
                jurisdiction: .us,
                annualIncome: 145_000,
                estimatedTax: 31_420,
                effectiveRate: 0.2167,
                source: .offline,
                updatedAt: now,
                serializedDetails: "{\"federal\":24480,\"state\":6940}"
            )
        )

        context.insert(
            TaxEstimateLog(
                jurisdiction: .canada,
                annualIncome: 155_000,
                estimatedTax: 41_260,
                effectiveRate: 0.2662,
                source: .offline,
                updatedAt: now,
                serializedDetails: "{\"federal\":24310,\"provincial\":16950}"
            )
        )
    }

    private static func seedScheduledItems(in context: ModelContext, now: Date, accounts: [FinancialAccount]) {
        let calendar = Calendar.current
        let creditCardStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now.monthStart) ?? now
        let mortgageStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now.monthStart) ?? now
        let propertyTaxStart = calendar.date(byAdding: .month, value: 1, to: now.quarterStart) ?? now

        let creditCardAccountID = accounts.first(where: { $0.type == .creditCard })?.id

        context.insert(
            ScheduledItem(
                title: "Visa Credit Card",
                kind: .bill,
                category: .creditCard,
                recurrence: .monthly,
                amount: 1_050,
                currency: .usd,
                startDate: calendar.date(byAdding: .day, value: 18, to: creditCardStart) ?? now,
                reminderHour: 9,
                reminderMinute: 0,
                remindDaysBefore: 3,
                linkedAccountID: creditCardAccountID,
                note: "Autopay from checking"
            )
        )

        context.insert(
            ScheduledItem(
                title: "Mortgage Payment",
                kind: .bill,
                category: .mortgage,
                recurrence: .monthly,
                amount: 2_500,
                currency: .usd,
                startDate: calendar.date(byAdding: .day, value: 0, to: mortgageStart) ?? now,
                reminderHour: 9,
                reminderMinute: 0,
                remindDaysBefore: 2,
                linkedAccountID: accounts.first(where: { $0.type == .mortgage })?.id,
                note: "Primary home"
            )
        )

        context.insert(
            ScheduledItem(
                title: "Property Tax",
                kind: .bill,
                category: .propertyTax,
                recurrence: .quarterly,
                amount: 1_950,
                currency: .usd,
                startDate: propertyTaxStart,
                reminderHour: 9,
                reminderMinute: 0,
                remindDaysBefore: 10,
                note: "Quarterly municipality payment"
            )
        )

        context.insert(
            ScheduledItem(
                title: "Update Home Insurance Renewal",
                kind: .reminder,
                category: .insurance,
                recurrence: .yearly,
                amount: 0,
                currency: .usd,
                startDate: calendar.date(byAdding: .month, value: 2, to: now.monthStart) ?? now,
                reminderHour: 9,
                reminderMinute: 30,
                remindDaysBefore: 14,
                note: "Compare rates before renewal"
            )
        )
    }

    private static func seedFXAndTemplates(in context: ModelContext, now: Date, accounts: [FinancialAccount]) {
        context.insert(
            FXRateEntry(
                fromCurrency: .usd,
                toCurrency: .cad,
                rate: 1.36,
                asOfDate: now.dayStart,
                sourceDescription: "Manual"
            )
        )

        context.insert(
            FXRateEntry(
                fromCurrency: .cad,
                toCurrency: .usd,
                rate: 0.7353,
                asOfDate: now.dayStart,
                sourceDescription: "Manual"
            )
        )

        if let checking = accounts.first(where: { $0.type == .checking }) {
            context.insert(
                QuickCaptureTemplate(
                    title: "Weekly Balance Check",
                    accountID: checking.id,
                    balanceDelta: 0,
                    contribution: 0,
                    note: "Weekend manual update"
                )
            )
        }

        if let brokerage = accounts.first(where: { $0.type == .brokerage }) {
            context.insert(
                QuickCaptureTemplate(
                    title: "Monthly Brokerage Contribution",
                    accountID: brokerage.id,
                    balanceDelta: 0,
                    contribution: 700,
                    note: "Auto-invest contribution"
                )
            )
        }
    }

    private static func seedSupplementalDataIfNeeded(in context: ModelContext, now: Date) throws {
        let hasScheduled = !((try? context.fetch(FetchDescriptor<ScheduledItem>())) ?? []).isEmpty
        let hasFX = !((try? context.fetch(FetchDescriptor<FXRateEntry>())) ?? []).isEmpty
        let hasTemplates = !((try? context.fetch(FetchDescriptor<QuickCaptureTemplate>())) ?? []).isEmpty

        guard !hasScheduled || !hasFX || !hasTemplates else { return }

        let accounts = (try? context.fetch(FetchDescriptor<FinancialAccount>())) ?? []
        if !hasScheduled {
            seedScheduledItems(in: context, now: now, accounts: accounts)
        }
        if !hasFX || !hasTemplates {
            seedFXAndTemplates(in: context, now: now, accounts: accounts)
        }
        try context.save()
    }

    private static func clearFinancialData(in context: ModelContext) throws {
        try context.fetch(FetchDescriptor<BalanceSnapshot>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<ExpenseSnapshot>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<FinancialGoal>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<RecurringContributionPlan>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<TaxEstimateLog>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<ScheduledItem>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<FXRateEntry>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<AccountTransfer>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<FinancialReviewSnapshot>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<QuickCaptureTemplate>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<FinancialAccount>()).forEach { context.delete($0) }
        try context.save()
    }

    private static func monthlyAnchors(endingAt endMonth: Date, months: Int) -> [Date] {
        let calendar = Calendar.current
        return (0..<months).compactMap { offset in
            calendar.date(byAdding: .month, value: -(months - offset - 1), to: endMonth)?.monthStart
        }
    }

    private static func roundedMoney(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

private struct AccountBlueprint {
    let name: String
    let category: AccountCategory
    let type: AccountType
    let currency: CurrencyCode
    let notes: String
    let targetAllocationPercent: Double?
    let aprPercent: Double?
    let minimumMonthlyPayment: Double?
    let startingBalance: Double
    let endingBalance: Double
    let monthlyContribution: Double
    let seasonalVariance: Double
}
