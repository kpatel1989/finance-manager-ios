import Foundation
import Testing
@testable import Finance_Manager

struct PortfolioAnalyticsTests {
    @Test
    func netWorthAggregatesAssetsAndLiabilities() {
        let cash = FinancialAccount(name: "Cash", category: .cashAndBanking, type: .checking, currency: .usd)
        let mortgage = FinancialAccount(name: "Mortgage", category: .liability, type: .mortgage, currency: .usd, aprPercent: 5.5, minimumMonthlyPayment: 2_000)

        let snapshots = [
            BalanceSnapshot(accountID: cash.id, date: Date(), balance: 25_000),
            BalanceSnapshot(accountID: mortgage.id, date: Date(), balance: 180_000)
        ]

        let netWorth = FinanceAnalytics.netWorth(
            accounts: [cash, mortgage],
            snapshots: snapshots,
            baseCurrency: .usd,
            usdToCadRate: 1.35
        )

        #expect(netWorth == -155_000)
    }

    @Test
    func investmentGrowthDecomposesContributions() {
        let account = FinancialAccount(name: "Brokerage", category: .investment, type: .brokerage, currency: .usd)
        let snapshots = [
            BalanceSnapshot(accountID: account.id, date: Date().addingTimeInterval(-3600 * 24 * 365), balance: 10_000, contribution: 10_000),
            BalanceSnapshot(accountID: account.id, date: Date(), balance: 13_000, contribution: 2_000)
        ]

        let summary = FinanceAnalytics.investmentSummary(
            accounts: [account],
            snapshots: snapshots,
            baseCurrency: .usd,
            usdToCadRate: 1.35
        )

        #expect(summary.currentValue == 13_000)
        #expect(summary.contributions == 12_000)
        #expect(summary.growth == 1_000)
    }

    @Test
    func expenseAggregationByCurrentMonth() {
        let month = Date().monthStart
        let expenses = [
            ExpenseSnapshot(monthStart: month, category: .housing, amount: 1_200),
            ExpenseSnapshot(monthStart: month, category: .food, amount: 500),
            ExpenseSnapshot(monthStart: month, category: .food, amount: 100)
        ]

        let totals = FinanceAnalytics.expenseByCategoryCurrentMonth(expenses: expenses)
        let totalAmount = totals.map(\.value).reduce(0, +)
        #expect(totalAmount == 1_800)
    }

    @Test
    func goalProjectionComputesCompletionDate() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let goal = FinancialGoal(
            title: "Emergency",
            type: .emergencyFund,
            targetAmount: 12_000,
            currentAmount: 6_000,
            monthlyContribution: 500,
            targetDate: now.addingTimeInterval(3600 * 24 * 365)
        )

        let projection = FinanceAnalytics.goalProjection(goal: goal, now: now)
        #expect(projection.progress == 0.5)
        #expect(projection.projectedCompletion != nil)
    }

    @Test
    func debtPlannerImprovesWithExtraPayment() {
        let debt = FinancialAccount(
            name: "Credit Card",
            category: .liability,
            type: .creditCard,
            currency: .usd,
            aprPercent: 19,
            minimumMonthlyPayment: 80
        )

        let snapshots = [BalanceSnapshot(accountID: debt.id, date: .now, balance: 4_000)]

        let lowExtra = FinanceAnalytics.debtPayoffPlan(
            accounts: [debt],
            snapshots: snapshots,
            strategy: .avalanche,
            extraMonthlyPayment: 50
        )

        let highExtra = FinanceAnalytics.debtPayoffPlan(
            accounts: [debt],
            snapshots: snapshots,
            strategy: .avalanche,
            extraMonthlyPayment: 200
        )

        #expect(highExtra.monthsToDebtFree < lowExtra.monthsToDebtFree)
    }

    @Test
    @MainActor
    func notificationEscalationThreshold() {
        let now = Date()
        let recent = now.addingTimeInterval(-5 * 24 * 60 * 60)
        let stale = now.addingTimeInterval(-8 * 24 * 60 * 60)

        #expect(PortfolioNotificationScheduler.shouldScheduleDailyEscalation(lastStatusUpdate: recent, now: now) == false)
        #expect(PortfolioNotificationScheduler.shouldScheduleDailyEscalation(lastStatusUpdate: stale, now: now) == true)
    }

    @Test
    func offlineTaxEstimatorReturnsPositiveTax() async throws {
        let provider = OfflineTaxProvider()
        let result = try await provider.estimate(
            TaxEstimateRequest(
                jurisdiction: .us,
                annualIncome: 120_000,
                filingLabel: "Single",
                deductions: 0
            )
        )

        #expect(result.estimatedTax > 0)
        #expect(result.source == .offline)
    }
}
