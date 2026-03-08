import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\FinancialAccount.createdAt, order: .forward)]) private var accounts: [FinancialAccount]
    @Query(sort: [SortDescriptor(\BalanceSnapshot.date, order: .forward)]) private var snapshots: [BalanceSnapshot]
    @Query(sort: [SortDescriptor(\ExpenseSnapshot.monthStart, order: .forward)]) private var expenses: [ExpenseSnapshot]
    @Query(sort: [SortDescriptor(\FinancialGoal.createdAt, order: .forward)]) private var goals: [FinancialGoal]
    @Query(sort: [SortDescriptor(\ScheduledItem.startDate, order: .forward)]) private var scheduledItems: [ScheduledItem]
    @Query(sort: [SortDescriptor(\FXRateEntry.asOfDate, order: .reverse)]) private var fxRates: [FXRateEntry]

    @State private var projectionYears = 3
    @State private var scenarioYears = 5
    @State private var scenarioReturn = 0.06
    @State private var scenarioMonthlyContribution = 500.0

    private var fullHistoryMonths: Int {
        let calendar = Calendar.current
        let earliestSnapshot = snapshots.map(\.date).min()
        let earliestAccount = accounts.map(\.createdAt).min()
        let earliestDate = [earliestSnapshot, earliestAccount].compactMap { $0 }.min() ?? .now
        let months = calendar.dateComponents([.month], from: earliestDate.monthStart, to: Date().monthStart).month ?? 0
        return max(months + 1, 1)
    }

    private var settings: AppSettings {
        fetchOrCreateSettings(in: modelContext)
    }

    private var baseCurrency: CurrencyCode { settings.baseCurrency }

    private var timeline: [NetWorthPoint] {
        FinanceAnalytics.netWorthTimeline(
            accounts: accounts,
            snapshots: snapshots,
            monthsBack: fullHistoryMonths,
            baseCurrency: baseCurrency,
            usdToCadRate: settings.usdToCadRate,
            fxRates: fxRates
        )
    }

    private var currentNetWorth: Double {
        FinanceAnalytics.netWorth(
            accounts: accounts,
            snapshots: snapshots,
            baseCurrency: baseCurrency,
            usdToCadRate: settings.usdToCadRate,
            fxRates: fxRates
        )
    }

    private var projectedLine: [NetWorthPoint] {
        FinanceAnalytics.projectedNetWorth(from: timeline, years: projectionYears, monthlyContribution: scenarioMonthlyContribution)
    }

    private var projectedLineWithAnchor: [NetWorthPoint] {
        guard let latestHistory = timeline.last else { return projectedLine }
        return [latestHistory] + projectedLine
    }

    private var investmentSummary: (currentValue: Double, contributions: Double, growth: Double, cagr: Double, allocation: [AllocationSlice]) {
        FinanceAnalytics.investmentSummary(
            accounts: accounts,
            snapshots: snapshots,
            baseCurrency: baseCurrency,
            usdToCadRate: settings.usdToCadRate,
            fxRates: fxRates
        )
    }

    private var dueEvents: [ScheduledDueEvent] {
        FinanceAnalytics.upcomingDueEvents(
            scheduledItems: scheduledItems.filter(\.isActive),
            now: .now,
            daysAhead: 45
        )
    }

    private var cashflowForecast: [CashflowForecastPoint] {
        FinanceAnalytics.cashflowForecast(
            accounts: accounts,
            snapshots: snapshots,
            scheduledItems: scheduledItems.filter(\.isActive),
            baseCurrency: baseCurrency,
            usdToCadRate: settings.usdToCadRate,
            fxRates: fxRates,
            daysAhead: 45
        )
    }

    private var scenarioLine: [ProjectionPoint] {
        FinanceAnalytics.scenarioProjection(
            currentNetWorth: currentNetWorth,
            monthlyContribution: scenarioMonthlyContribution,
            years: scenarioYears,
            baseAnnualReturn: scenarioReturn
        )
    }

    private var expenseTrend: [NetWorthPoint] {
        FinanceAnalytics.expenseByMonth(expenses: expenses, monthsBack: 6)
    }

    private var monthlyExpenseTotal: Double {
        FinanceAnalytics.expenseByCategoryCurrentMonth(expenses: expenses)
            .map(\.value)
            .reduce(0, +)
    }

    private var driftItems: [RebalanceDriftItem] {
        FinanceAnalytics.rebalancingDrift(
            accounts: accounts,
            snapshots: snapshots,
            baseCurrency: baseCurrency,
            usdToCadRate: settings.usdToCadRate,
            fxRates: fxRates
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    heroCard
                    netWorthCard
                    forecastCard
                    investmentCard
                    expenseCard
                    goalsCard
                    scenarioCard
                    rebalancingCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Overview")
            .toolbarTitleDisplayMode(.large)
        }
        .portfolioScreenBackground()
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Portfolio Health")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)

            Text(PortfolioFormatters.currency(currentNetWorth, code: baseCurrency))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))

            HStack(spacing: 8) {
                MetricChip(
                    title: "Investments",
                    value: PortfolioFormatters.currency(investmentSummary.currentValue, code: baseCurrency),
                    valueColor: PortfolioTheme.accent
                )
                MetricChip(
                    title: "Monthly Spend",
                    value: PortfolioFormatters.currency(monthlyExpenseTotal, code: baseCurrency),
                    valueColor: PortfolioTheme.danger
                )
            }
        }
        .cardStyle()
    }

    private var forecastCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Cashflow Forecast Calendar", systemImage: "calendar.badge.clock")

            if cashflowForecast.count > 1 {
                Chart {
                    ForEach(cashflowForecast) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Projected Cash", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(PortfolioTheme.accentTertiary)
                    }
                }
                .frame(height: 150)
            } else {
                Text("Add scheduled bills or reminders to project upcoming cashflow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if dueEvents.isEmpty {
                Text("No upcoming due items in the next 45 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dueEvents.prefix(4)) { event in
                    HStack {
                        Text(event.title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if event.kind == .bill {
                            Text(PortfolioFormatters.currency(event.amount, code: event.currency))
                                .font(.caption)
                        }
                        Text(event.dueDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var netWorthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Net Worth History + Projection", systemImage: "chart.line.uptrend.xyaxis")

            Text(PortfolioFormatters.currency(currentNetWorth, code: baseCurrency))
                .font(.system(.title2, design: .rounded).weight(.bold))

            HStack(spacing: 8) {
                MetricChip(title: "History", value: "All")
                MetricChip(title: "Projection", value: "\(projectionYears)Y")
            }

            Picker("Projection", selection: $projectionYears) {
                Text("1Y").tag(1)
                Text("3Y").tag(3)
                Text("5Y").tag(5)
            }
            .pickerStyle(.segmented)

            Chart {
                ForEach(timeline) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Net Worth", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(PortfolioTheme.accent)
                }

                ForEach(timeline) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Net Worth", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PortfolioTheme.accent.opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                ForEach(projectedLineWithAnchor) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Projected", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(PortfolioTheme.success)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }
            }
            .frame(height: 180)

            HStack(spacing: 8) {
                Label("History", systemImage: "line.diagonal")
                    .font(.caption)
                    .foregroundStyle(PortfolioTheme.accent)
                Label("Projected", systemImage: "waveform.path.ecg")
                    .font(.caption)
                    .foregroundStyle(PortfolioTheme.success)
            }

            Text("History uses saved snapshots. Projection starts from the latest historical point.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var investmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Investment Growth", systemImage: "dollarsign.gauge.chart.lefthalf.righthalf")

            HStack(spacing: 8) {
                MetricChip(title: "Current", value: PortfolioFormatters.currency(investmentSummary.currentValue, code: baseCurrency))
                MetricChip(title: "Contributed", value: PortfolioFormatters.currency(investmentSummary.contributions, code: baseCurrency))
            }

            HStack(spacing: 8) {
                MetricChip(
                    title: "Growth",
                    value: PortfolioFormatters.currency(investmentSummary.growth, code: baseCurrency),
                    valueColor: investmentSummary.growth >= 0 ? PortfolioTheme.success : PortfolioTheme.danger
                )
                MetricChip(
                    title: "CAGR",
                    value: PortfolioFormatters.percent(investmentSummary.cagr),
                    valueColor: investmentSummary.cagr >= 0 ? PortfolioTheme.success : PortfolioTheme.danger
                )
            }

            if !investmentSummary.allocation.isEmpty {
                Chart(investmentSummary.allocation) { item in
                    SectorMark(
                        angle: .value("Value", item.value),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Account", item.name))
                }
                .frame(height: 180)
            }
        }
        .cardStyle()
    }

    private var expenseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Expense Calculator", systemImage: "creditcard.and.123")
            Text("Current month total: \(PortfolioFormatters.currency(monthlyExpenseTotal, code: baseCurrency))")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))

            Chart {
                ForEach(expenseTrend) { point in
                    BarMark(
                        x: .value("Month", point.date, unit: .month),
                        y: .value("Total", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PortfolioTheme.accentSecondary, PortfolioTheme.accent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .frame(height: 150)
        }
        .cardStyle()
    }

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Goals Projection", systemImage: "target")

            if goals.isEmpty {
                Text("Create goals in the Planner tab to track funding progress.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(goals.prefix(3)) { goal in
                    let projection = FinanceAnalytics.goalProjection(goal: goal)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(goal.title)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                        ProgressView(value: projection.progress)
                            .tint(PortfolioTheme.accent)
                        Text("\(Int(projection.progress * 100))% complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let projected = projection.projectedCompletion {
                            Text("Projected completion: \(projected.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    private var scenarioCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Scenario Sandbox", systemImage: "waveform.path.ecg.rectangle")

            VStack(alignment: .leading) {
                Text("Monthly contribution: \(PortfolioFormatters.currency(scenarioMonthlyContribution, code: baseCurrency))")
                    .font(.caption)
                Slider(value: $scenarioMonthlyContribution, in: 0...10_000, step: 50)
                    .tint(PortfolioTheme.accent)

                Text("Base annual return: \(PortfolioFormatters.percent(scenarioReturn))")
                    .font(.caption)
                Slider(value: $scenarioReturn, in: -0.05...0.15, step: 0.005)
                    .tint(PortfolioTheme.accentSecondary)

                Picker("Years", selection: $scenarioYears) {
                    Text("3Y").tag(3)
                    Text("5Y").tag(5)
                    Text("10Y").tag(10)
                }
                .pickerStyle(.segmented)
            }

            Chart {
                ForEach(scenarioLine) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Scenario", point.scenario))
                }
            }
            .frame(height: 180)
        }
        .cardStyle()
    }

    private var rebalancingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Rebalancing Drift", systemImage: "arrow.left.arrow.right.circle")

            if driftItems.isEmpty {
                Text("Set target allocation percentages on investment accounts to track drift.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(driftItems.prefix(5)) { item in
                    HStack {
                        Text(item.accountName)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Spacer()
                        Text("Current \(PortfolioFormatters.percent(item.currentWeight))")
                            .font(.caption)
                        Text("Target \(PortfolioFormatters.percent(item.targetWeight))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .cardStyle()
    }
}
