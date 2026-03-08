import Foundation

struct NetWorthPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct ProjectionPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let scenario: String
}

struct AllocationSlice: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
}

struct RebalanceDriftItem: Identifiable {
    let id = UUID()
    let accountName: String
    let currentWeight: Double
    let targetWeight: Double
    let drift: Double
}

struct ScheduledDueEvent: Identifiable {
    let id = UUID()
    let scheduledItemID: UUID
    let title: String
    let dueDate: Date
    let amount: Double
    let currency: CurrencyCode
    let category: ScheduledItemCategory
    let kind: ScheduledItemKind
}

struct CashflowForecastPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum DebtStrategy: String, CaseIterable, Identifiable {
    case snowball
    case avalanche

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .snowball: return "Snowball"
        case .avalanche: return "Avalanche"
        }
    }
}

struct DebtPayoffPlan {
    let monthsToDebtFree: Int
    let totalInterest: Double
}

private struct SimulatedDebt {
    var apr: Double
    var minimumPayment: Double
    var balance: Double
}

enum FinanceAnalytics {
    static func latestBalance(
        account: FinancialAccount,
        snapshots: [BalanceSnapshot],
        asOf: Date = .now
    ) -> Double {
        let relevant = snapshots
            .filter { $0.accountID == account.id && $0.date <= asOf }
            .sorted { $0.date < $1.date }

        return relevant.last?.balance ?? 0
    }

    static func normalize(
        value: Double,
        accountCurrency: CurrencyCode,
        baseCurrency: CurrencyCode,
        usdToCadRate: Double,
        fxRates: [FXRateEntry] = [],
        asOf: Date = .now
    ) -> Double {
        guard accountCurrency != baseCurrency else { return value }

        if let rate = fxRate(
            from: accountCurrency,
            to: baseCurrency,
            asOf: asOf,
            fxRates: fxRates,
            fallbackUSDToCAD: usdToCadRate
        ) {
            return value * rate
        }

        switch (accountCurrency, baseCurrency) {
        case (.usd, .cad):
            return value * usdToCadRate
        case (.cad, .usd):
            return usdToCadRate == 0 ? value : value / usdToCadRate
        default:
            return value
        }
    }

    static func netWorth(
        accounts: [FinancialAccount],
        snapshots: [BalanceSnapshot],
        baseCurrency: CurrencyCode,
        usdToCadRate: Double,
        fxRates: [FXRateEntry] = [],
        asOf: Date = .now
    ) -> Double {
        accounts
            .filter { !$0.isArchived }
            .reduce(0) { running, account in
                let balance = latestBalance(account: account, snapshots: snapshots, asOf: asOf)
                let normalized = normalize(
                    value: balance,
                    accountCurrency: account.currency,
                    baseCurrency: baseCurrency,
                    usdToCadRate: usdToCadRate,
                    fxRates: fxRates,
                    asOf: asOf
                )

                if account.category == .liability {
                    return running - abs(normalized)
                }
                return running + normalized
            }
    }

    static func netWorthTimeline(
        accounts: [FinancialAccount],
        snapshots: [BalanceSnapshot],
        monthsBack: Int,
        baseCurrency: CurrencyCode,
        usdToCadRate: Double,
        fxRates: [FXRateEntry] = [],
        now: Date = .now
    ) -> [NetWorthPoint] {
        let calendar = Calendar.current
        let anchors: [Date] = (0..<monthsBack).compactMap { offset in
            calendar.date(byAdding: .month, value: -(monthsBack - offset - 1), to: now)?.monthStart
        }

        return anchors.map { date in
            NetWorthPoint(
                date: date,
                value: netWorth(
                    accounts: accounts,
                    snapshots: snapshots,
                    baseCurrency: baseCurrency,
                    usdToCadRate: usdToCadRate,
                    fxRates: fxRates,
                    asOf: date
                )
            )
        }
    }

    static func projectedNetWorth(
        from timeline: [NetWorthPoint],
        years: Int,
        monthlyContribution: Double
    ) -> [NetWorthPoint] {
        guard let latest = timeline.last else { return [] }
        let calendar = Calendar.current

        let monthChanges = zip(timeline, timeline.dropFirst()).map { $1.value - $0.value }
        let avgMonthlyChange = monthChanges.isEmpty ? 0 : monthChanges.reduce(0, +) / Double(monthChanges.count)
        let projectedGrowth = avgMonthlyChange + monthlyContribution

        var points: [NetWorthPoint] = []
        var running = latest.value

        for month in 1...(years * 12) {
            running += projectedGrowth
            if let date = calendar.date(byAdding: .month, value: month, to: latest.date) {
                points.append(NetWorthPoint(date: date, value: running))
            }
        }

        return points
    }

    static func investmentSummary(
        accounts: [FinancialAccount],
        snapshots: [BalanceSnapshot],
        baseCurrency: CurrencyCode,
        usdToCadRate: Double,
        fxRates: [FXRateEntry] = [],
        asOf: Date = .now
    ) -> (currentValue: Double, contributions: Double, growth: Double, cagr: Double, allocation: [AllocationSlice]) {
        let investmentAccounts = accounts.filter { !$0.isArchived && $0.isInvestmentLike }

        let currentValue = investmentAccounts.reduce(0) { running, account in
            let value = latestBalance(account: account, snapshots: snapshots)
            let normalized = normalize(
                value: value,
                accountCurrency: account.currency,
                baseCurrency: baseCurrency,
                usdToCadRate: usdToCadRate,
                fxRates: fxRates,
                asOf: asOf
            )
            return running + max(0, normalized)
        }

        let contributions = investmentAccounts.reduce(0) { running, account in
            let accountContributions = snapshots
                .filter { $0.accountID == account.id }
                .map(\.contribution)
                .reduce(0, +)
            let normalized = normalize(
                value: accountContributions,
                accountCurrency: account.currency,
                baseCurrency: baseCurrency,
                usdToCadRate: usdToCadRate,
                fxRates: fxRates,
                asOf: asOf
            )
            return running + max(0, normalized)
        }

        let growth = currentValue - contributions

        let earliestSnapshotDate = snapshots
            .filter { snap in investmentAccounts.contains { $0.id == snap.accountID } }
            .map(\.date)
            .sorted()
            .first

        let yearsActive: Double
        if let earliestSnapshotDate {
            let months = Calendar.current.dateComponents([.month], from: earliestSnapshotDate, to: .now).month ?? 0
            yearsActive = max(Double(months) / 12, 1 / 12)
        } else {
            yearsActive = 1
        }

        let cagr: Double
        if contributions > 0 {
            cagr = pow(max(currentValue, 0.01) / contributions, 1 / yearsActive) - 1
        } else {
            cagr = 0
        }

        let allocationRaw = investmentAccounts.map { account -> AllocationSlice in
            let value = latestBalance(account: account, snapshots: snapshots)
            let normalized = normalize(
                value: value,
                accountCurrency: account.currency,
                baseCurrency: baseCurrency,
                usdToCadRate: usdToCadRate,
                fxRates: fxRates,
                asOf: asOf
            )
            return AllocationSlice(name: account.name, value: max(0, normalized))
        }

        return (currentValue, contributions, growth, cagr, allocationRaw.filter { $0.value > 0 })
    }

    static func expenseByMonth(expenses: [ExpenseSnapshot], monthsBack: Int) -> [NetWorthPoint] {
        let calendar = Calendar.current
        let now = Date().monthStart
        let anchors: [Date] = (0..<monthsBack).compactMap { offset in
            calendar.date(byAdding: .month, value: -(monthsBack - offset - 1), to: now)?.monthStart
        }

        return anchors.map { date in
            let total = expenses
                .filter { Calendar.current.isDate($0.monthStart, equalTo: date, toGranularity: .month) }
                .map(\.amount)
                .reduce(0, +)
            return NetWorthPoint(date: date, value: total)
        }
    }

    static func expenseByCategoryCurrentMonth(expenses: [ExpenseSnapshot]) -> [AllocationSlice] {
        let currentMonth = Date().monthStart
        return ExpenseCategory.allCases.map { category in
            let amount = expenses
                .filter {
                    $0.category == category &&
                    Calendar.current.isDate($0.monthStart, equalTo: currentMonth, toGranularity: .month)
                }
                .map(\.amount)
                .reduce(0, +)
            return AllocationSlice(name: category.displayName, value: amount)
        }
        .filter { $0.value > 0 }
    }

    static func goalProjection(goal: FinancialGoal, now: Date = .now) -> (progress: Double, projectedCompletion: Date?) {
        let progress = goal.targetAmount > 0 ? min(goal.currentAmount / goal.targetAmount, 1) : 0
        guard goal.monthlyContribution > 0, goal.currentAmount < goal.targetAmount else {
            return (progress, nil)
        }

        let remaining = goal.targetAmount - goal.currentAmount
        let months = Int(ceil(remaining / goal.monthlyContribution))
        let projected = Calendar.current.date(byAdding: .month, value: months, to: now)
        return (progress, projected)
    }

    static func scenarioProjection(
        currentNetWorth: Double,
        monthlyContribution: Double,
        years: Int,
        baseAnnualReturn: Double
    ) -> [ProjectionPoint] {
        let scenarios: [(name: String, annualReturn: Double)] = [
            ("Worst", max(baseAnnualReturn - 0.06, -0.20)),
            ("Base", baseAnnualReturn),
            ("Best", baseAnnualReturn + 0.05)
        ]

        let calendar = Calendar.current
        let now = Date().monthStart

        return scenarios.flatMap { scenario in
            let monthlyRate = scenario.annualReturn / 12
            var running = currentNetWorth
            return (1...(years * 12)).compactMap { month -> ProjectionPoint? in
                running = (running + monthlyContribution) * (1 + monthlyRate)
                guard let date = calendar.date(byAdding: .month, value: month, to: now) else {
                    return nil
                }
                return ProjectionPoint(date: date, value: running, scenario: scenario.name)
            }
        }
    }

    static func rebalancingDrift(
        accounts: [FinancialAccount],
        snapshots: [BalanceSnapshot],
        baseCurrency: CurrencyCode,
        usdToCadRate: Double,
        fxRates: [FXRateEntry] = [],
        asOf: Date = .now
    ) -> [RebalanceDriftItem] {
        let candidates = accounts.filter {
            !$0.isArchived &&
            $0.isInvestmentLike &&
            ($0.targetAllocationPercent ?? 0) > 0
        }

        let total = candidates.reduce(0.0) { running, account in
            let value = latestBalance(account: account, snapshots: snapshots)
            let normalized = normalize(
                value: value,
                accountCurrency: account.currency,
                baseCurrency: baseCurrency,
                usdToCadRate: usdToCadRate,
                fxRates: fxRates,
                asOf: asOf
            )
            return running + max(0, normalized)
        }

        guard total > 0 else { return [] }

        return candidates.map { account in
            let value = latestBalance(account: account, snapshots: snapshots)
            let normalized = normalize(
                value: value,
                accountCurrency: account.currency,
                baseCurrency: baseCurrency,
                usdToCadRate: usdToCadRate,
                fxRates: fxRates,
                asOf: asOf
            )
            let currentWeight = max(0, normalized) / total
            let targetWeight = (account.targetAllocationPercent ?? 0) / 100
            return RebalanceDriftItem(
                accountName: account.name,
                currentWeight: currentWeight,
                targetWeight: targetWeight,
                drift: currentWeight - targetWeight
            )
        }
        .sorted { abs($0.drift) > abs($1.drift) }
    }

    static func debtPayoffPlan(
        accounts: [FinancialAccount],
        snapshots: [BalanceSnapshot],
        strategy: DebtStrategy,
        extraMonthlyPayment: Double,
        maxMonths: Int = 360
    ) -> DebtPayoffPlan {
        var debts: [SimulatedDebt] = accounts
            .filter { !$0.isArchived && $0.category == .liability }
            .compactMap { account in
                let balance = abs(latestBalance(account: account, snapshots: snapshots))
                guard balance > 0 else { return nil }
                return SimulatedDebt(
                    apr: max(account.aprPercent ?? 8, 0),
                    minimumPayment: max(account.minimumMonthlyPayment ?? balance * 0.02, 0),
                    balance: balance
                )
            }

        guard !debts.isEmpty else { return DebtPayoffPlan(monthsToDebtFree: 0, totalInterest: 0) }

        var totalInterest = 0.0
        var month = 0

        while month < maxMonths && debts.contains(where: { $0.balance > 0.01 }) {
            month += 1

            for index in debts.indices {
                let monthlyRate = debts[index].apr / 100 / 12
                let interest = debts[index].balance * monthlyRate
                debts[index].balance += interest
                totalInterest += interest
            }

            for index in debts.indices {
                guard debts[index].balance > 0 else { continue }
                let payment = min(debts[index].minimumPayment, debts[index].balance)
                debts[index].balance -= payment
            }

            let active = debts.indices.filter { debts[$0].balance > 0.01 }
            guard let targetIndex = selectDebtIndex(debts: debts, strategy: strategy, activeIndexes: active) else {
                continue
            }

            debts[targetIndex].balance = max(debts[targetIndex].balance - extraMonthlyPayment, 0)
        }

        return DebtPayoffPlan(monthsToDebtFree: month, totalInterest: totalInterest)
    }

    static func upcomingDueEvents(
        scheduledItems: [ScheduledItem],
        now: Date = .now,
        daysAhead: Int = 90
    ) -> [ScheduledDueEvent] {
        guard let horizon = Calendar.current.date(byAdding: .day, value: daysAhead, to: now) else { return [] }
        var events: [ScheduledDueEvent] = []

        for item in scheduledItems where item.isActive {
            let occurrences = ScheduleEngine.upcomingOccurrences(for: item, after: now, count: 8)
            for dueDate in occurrences where dueDate <= horizon {
                events.append(
                    ScheduledDueEvent(
                        scheduledItemID: item.id,
                        title: item.title,
                        dueDate: dueDate,
                        amount: item.amount,
                        currency: item.currency,
                        category: item.category,
                        kind: item.kind
                    )
                )
            }
        }

        return events.sorted { $0.dueDate < $1.dueDate }
    }

    static func cashflowForecast(
        accounts: [FinancialAccount],
        snapshots: [BalanceSnapshot],
        scheduledItems: [ScheduledItem],
        baseCurrency: CurrencyCode,
        usdToCadRate: Double,
        fxRates: [FXRateEntry] = [],
        daysAhead: Int = 60,
        now: Date = .now
    ) -> [CashflowForecastPoint] {
        let cashAccounts = accounts.filter { !$0.isArchived && $0.category == .cashAndBanking }

        var running = cashAccounts.reduce(0.0) { total, account in
            let latest = latestBalance(account: account, snapshots: snapshots, asOf: now)
            return total + normalize(
                value: latest,
                accountCurrency: account.currency,
                baseCurrency: baseCurrency,
                usdToCadRate: usdToCadRate,
                fxRates: fxRates,
                asOf: now
            )
        }

        let events = upcomingDueEvents(scheduledItems: scheduledItems, now: now, daysAhead: daysAhead)
        var points: [CashflowForecastPoint] = [CashflowForecastPoint(date: now.dayStart, value: running)]

        for event in events where event.kind == .bill {
            let converted = normalize(
                value: event.amount,
                accountCurrency: event.currency,
                baseCurrency: baseCurrency,
                usdToCadRate: usdToCadRate,
                fxRates: fxRates,
                asOf: event.dueDate
            )
            running -= converted
            points.append(CashflowForecastPoint(date: event.dueDate, value: running))
        }

        return points
    }

    static func reviewMetrics(
        accounts: [FinancialAccount],
        snapshots: [BalanceSnapshot],
        expenses: [ExpenseSnapshot],
        baseCurrency: CurrencyCode,
        usdToCadRate: Double,
        fxRates: [FXRateEntry] = [],
        periodStart: Date,
        periodEnd: Date
    ) -> (netWorthStart: Double, netWorthEnd: Double, totalExpenses: Double, totalContributions: Double) {
        let startWorth = netWorth(
            accounts: accounts,
            snapshots: snapshots,
            baseCurrency: baseCurrency,
            usdToCadRate: usdToCadRate,
            fxRates: fxRates,
            asOf: periodStart
        )

        let endWorth = netWorth(
            accounts: accounts,
            snapshots: snapshots,
            baseCurrency: baseCurrency,
            usdToCadRate: usdToCadRate,
            fxRates: fxRates,
            asOf: periodEnd
        )

        let periodExpenses = expenses
            .filter { $0.monthStart >= periodStart.monthStart && $0.monthStart <= periodEnd.monthStart }
            .map(\.amount)
            .reduce(0, +)

        let periodContributions = snapshots
            .filter { $0.date >= periodStart && $0.date <= periodEnd }
            .map(\.contribution)
            .reduce(0, +)

        return (startWorth, endWorth, periodExpenses, periodContributions)
    }

    static func fxRate(
        from: CurrencyCode,
        to: CurrencyCode,
        asOf: Date,
        fxRates: [FXRateEntry],
        fallbackUSDToCAD: Double
    ) -> Double? {
        guard from != to else { return 1 }

        let direct = fxRates
            .filter { $0.fromCurrency == from && $0.toCurrency == to && $0.asOfDate <= asOf }
            .sorted { $0.asOfDate > $1.asOfDate }
            .first?
            .rate

        if let direct { return direct }

        let inverse = fxRates
            .filter { $0.fromCurrency == to && $0.toCurrency == from && $0.asOfDate <= asOf }
            .sorted { $0.asOfDate > $1.asOfDate }
            .first?
            .rate

        if let inverse, inverse != 0 {
            return 1 / inverse
        }

        switch (from, to) {
        case (.usd, .cad):
            return fallbackUSDToCAD
        case (.cad, .usd):
            return fallbackUSDToCAD == 0 ? nil : 1 / fallbackUSDToCAD
        default:
            return nil
        }
    }

    private static func selectDebtIndex(
        debts: [SimulatedDebt],
        strategy: DebtStrategy,
        activeIndexes: [Int]
    ) -> Int? {
        switch strategy {
        case .snowball:
            return activeIndexes.min(by: { debts[$0].balance < debts[$1].balance })
        case .avalanche:
            return activeIndexes.max(by: { debts[$0].apr < debts[$1].apr })
        }
    }
}
