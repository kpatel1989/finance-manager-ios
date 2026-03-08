import Foundation
import SwiftData

enum AccountCategory: String, Codable, CaseIterable, Identifiable {
    case cashAndBanking
    case asset
    case liability
    case investment

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cashAndBanking: return "Cash & Banking"
        case .asset: return "Asset"
        case .liability: return "Liability"
        case .investment: return "Investment"
        }
    }
}

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case checking
    case savings
    case moneyMarket
    case cash
    case creditCard
    case personalLoan
    case mortgage
    case autoLoan
    case studentLoan
    case lineOfCredit
    case brokerage
    case pension
    case retirement401k
    case retirement403b
    case ira
    case rothIRA
    case rrsp
    case tfsa
    case resp
    case realEstate
    case vehicle
    case businessEquity
    case privateEquity
    case stockOptions
    case cryptoWallet
    case collectible
    case insuranceCashValue
    case preciousMetals
    case hsa
    case fsa
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .checking: return "Checking"
        case .savings: return "Savings"
        case .moneyMarket: return "Money Market"
        case .cash: return "Cash"
        case .creditCard: return "Credit Card"
        case .personalLoan: return "Personal Loan"
        case .mortgage: return "Mortgage"
        case .autoLoan: return "Auto Loan"
        case .studentLoan: return "Student Loan"
        case .lineOfCredit: return "Line of Credit"
        case .brokerage: return "Brokerage"
        case .pension: return "Pension"
        case .retirement401k: return "401(k)"
        case .retirement403b: return "403(b)"
        case .ira: return "IRA"
        case .rothIRA: return "Roth IRA"
        case .rrsp: return "RRSP"
        case .tfsa: return "TFSA"
        case .resp: return "RESP"
        case .realEstate: return "Real Estate"
        case .vehicle: return "Vehicle"
        case .businessEquity: return "Business Equity"
        case .privateEquity: return "Private Equity"
        case .stockOptions: return "Stock Options"
        case .cryptoWallet: return "Crypto Wallet"
        case .collectible: return "Collectible"
        case .insuranceCashValue: return "Insurance Cash Value"
        case .preciousMetals: return "Precious Metals"
        case .hsa: return "HSA"
        case .fsa: return "FSA"
        case .custom: return "Custom"
        }
    }
}

enum CurrencyCode: String, Codable, CaseIterable, Identifiable {
    case usd = "USD"
    case cad = "CAD"

    var id: String { rawValue }
}

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case emergencyFund
    case retirement
    case homeDownPayment
    case debtFree
    case education
    case travel
    case majorPurchase
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .emergencyFund: return "Emergency Fund"
        case .retirement: return "Retirement"
        case .homeDownPayment: return "Home Down Payment"
        case .debtFree: return "Debt Free"
        case .education: return "Education"
        case .travel: return "Travel"
        case .majorPurchase: return "Major Purchase"
        case .custom: return "Custom"
        }
    }
}

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case housing
    case transport
    case food
    case utilities
    case healthcare
    case insurance
    case debt
    case savings
    case entertainment
    case education
    case travel
    case other

    var id: String { rawValue }

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

enum TaxJurisdiction: String, Codable, CaseIterable, Identifiable {
    case us
    case canada

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .us: return "United States"
        case .canada: return "Canada"
        }
    }
}

enum TaxComputationSource: String, Codable, CaseIterable, Identifiable {
    case apiNinjas
    case offline

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apiNinjas: return "API Ninjas"
        case .offline: return "Offline"
        }
    }
}

enum ContributionTargetKind: String, Codable, CaseIterable, Identifiable {
    case account
    case goal

    var id: String { rawValue }
}

enum ScheduledItemKind: String, Codable, CaseIterable, Identifiable {
    case bill
    case reminder

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bill: return "Bill"
        case .reminder: return "Reminder"
        }
    }
}

enum ScheduledItemCategory: String, Codable, CaseIterable, Identifiable {
    case creditCard
    case mortgage
    case rent
    case propertyTax
    case utility
    case insurance
    case subscription
    case loanPayment
    case investmentContribution
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .creditCard: return "Credit Card"
        case .mortgage: return "Mortgage"
        case .rent: return "Rent"
        case .propertyTax: return "Property Tax"
        case .utility: return "Utility"
        case .insurance: return "Insurance"
        case .subscription: return "Subscription"
        case .loanPayment: return "Loan Payment"
        case .investmentContribution: return "Investment Contribution"
        case .custom: return "Custom"
        }
    }
}

enum ScheduleRecurrence: String, Codable, CaseIterable, Identifiable {
    case oneTime
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneTime: return "One Time"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }
}

struct TaxEstimateRequest: Codable, Hashable {
    var jurisdiction: TaxJurisdiction
    var annualIncome: Double
    var filingLabel: String
    var deductions: Double
}

struct TaxEstimateResult: Codable, Hashable {
    var jurisdiction: TaxJurisdiction
    var annualIncome: Double
    var estimatedTax: Double
    var effectiveRate: Double
    var source: TaxComputationSource
    var updatedAt: Date
    var details: [String: Double]
}

protocol TaxProvider {
    func estimate(_ request: TaxEstimateRequest) async throws -> TaxEstimateResult
}

@MainActor
protocol ReminderScheduler {
    func refreshSchedules(lastStatusUpdate: Date, now: Date)
}

@Model
final class FinancialAccount {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String
    var typeRaw: String
    var currencyRaw: String
    var customTypeName: String?
    var notes: String
    var targetAllocationPercent: Double?
    var aprPercent: Double?
    var minimumMonthlyPayment: Double?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        category: AccountCategory,
        type: AccountType,
        currency: CurrencyCode,
        customTypeName: String? = nil,
        notes: String = "",
        targetAllocationPercent: Double? = nil,
        aprPercent: Double? = nil,
        minimumMonthlyPayment: Double? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.typeRaw = type.rawValue
        self.currencyRaw = currency.rawValue
        self.customTypeName = customTypeName
        self.notes = notes
        self.targetAllocationPercent = targetAllocationPercent
        self.aprPercent = aprPercent
        self.minimumMonthlyPayment = minimumMonthlyPayment
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
    }

    var category: AccountCategory {
        get { AccountCategory(rawValue: categoryRaw) ?? .asset }
        set { categoryRaw = newValue.rawValue }
    }

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    var currency: CurrencyCode {
        get { CurrencyCode(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }

    var displayTypeName: String {
        if type == .custom {
            return customTypeName?.isEmpty == false ? customTypeName ?? type.displayName : type.displayName
        }
        return type.displayName
    }

    var isInvestmentLike: Bool {
        category == .investment || [.brokerage, .retirement401k, .retirement403b, .ira, .rothIRA, .rrsp, .tfsa, .resp, .privateEquity, .stockOptions, .cryptoWallet].contains(type)
    }
}

@Model
final class BalanceSnapshot {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var date: Date
    var balance: Double
    var contribution: Double
    var note: String

    init(
        id: UUID = UUID(),
        accountID: UUID,
        date: Date,
        balance: Double,
        contribution: Double = 0,
        note: String = ""
    ) {
        self.id = id
        self.accountID = accountID
        self.date = date
        self.balance = balance
        self.contribution = contribution
        self.note = note
    }
}

@Model
final class ExpenseSnapshot {
    @Attribute(.unique) var id: UUID
    var monthStart: Date
    var categoryRaw: String
    var amount: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        monthStart: Date,
        category: ExpenseCategory,
        amount: Double,
        createdAt: Date = .now
    ) {
        self.id = id
        self.monthStart = monthStart
        self.categoryRaw = category.rawValue
        self.amount = amount
        self.createdAt = createdAt
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model
final class FinancialGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var typeRaw: String
    var targetAmount: Double
    var currentAmount: Double
    var monthlyContribution: Double
    var targetDate: Date
    var createdAt: Date
    var note: String

    init(
        id: UUID = UUID(),
        title: String,
        type: GoalType,
        targetAmount: Double,
        currentAmount: Double,
        monthlyContribution: Double,
        targetDate: Date,
        createdAt: Date = .now,
        note: String = ""
    ) {
        self.id = id
        self.title = title
        self.typeRaw = type.rawValue
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.monthlyContribution = monthlyContribution
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.note = note
    }

    var type: GoalType {
        get { GoalType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }
}

@Model
final class RecurringContributionPlan {
    @Attribute(.unique) var id: UUID
    var title: String
    var targetID: UUID
    var targetKindRaw: String
    var monthlyAmount: Double
    var startDate: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        targetID: UUID,
        targetKind: ContributionTargetKind,
        monthlyAmount: Double,
        startDate: Date,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.targetID = targetID
        self.targetKindRaw = targetKind.rawValue
        self.monthlyAmount = monthlyAmount
        self.startDate = startDate
        self.createdAt = createdAt
    }

    var targetKind: ContributionTargetKind {
        get { ContributionTargetKind(rawValue: targetKindRaw) ?? .goal }
        set { targetKindRaw = newValue.rawValue }
    }
}

@Model
final class TaxEstimateLog {
    @Attribute(.unique) var id: UUID
    var jurisdictionRaw: String
    var annualIncome: Double
    var estimatedTax: Double
    var effectiveRate: Double
    var sourceRaw: String
    var updatedAt: Date
    var serializedDetails: String

    init(
        id: UUID = UUID(),
        jurisdiction: TaxJurisdiction,
        annualIncome: Double,
        estimatedTax: Double,
        effectiveRate: Double,
        source: TaxComputationSource,
        updatedAt: Date,
        serializedDetails: String
    ) {
        self.id = id
        self.jurisdictionRaw = jurisdiction.rawValue
        self.annualIncome = annualIncome
        self.estimatedTax = estimatedTax
        self.effectiveRate = effectiveRate
        self.sourceRaw = source.rawValue
        self.updatedAt = updatedAt
        self.serializedDetails = serializedDetails
    }

    var jurisdiction: TaxJurisdiction {
        get { TaxJurisdiction(rawValue: jurisdictionRaw) ?? .us }
        set { jurisdictionRaw = newValue.rawValue }
    }

    var source: TaxComputationSource {
        get { TaxComputationSource(rawValue: sourceRaw) ?? .offline }
        set { sourceRaw = newValue.rawValue }
    }
}

@Model
final class ScheduledItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var kindRaw: String
    var categoryRaw: String
    var recurrenceRaw: String
    var amount: Double
    var currencyRaw: String
    var startDate: Date
    var reminderHour: Int
    var reminderMinute: Int
    var remindDaysBefore: Int
    var linkedAccountID: UUID?
    var note: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        kind: ScheduledItemKind,
        category: ScheduledItemCategory,
        recurrence: ScheduleRecurrence,
        amount: Double = 0,
        currency: CurrencyCode = .usd,
        startDate: Date,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        remindDaysBefore: Int = 2,
        linkedAccountID: UUID? = nil,
        note: String = "",
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.kindRaw = kind.rawValue
        self.categoryRaw = category.rawValue
        self.recurrenceRaw = recurrence.rawValue
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.startDate = startDate
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.remindDaysBefore = remindDaysBefore
        self.linkedAccountID = linkedAccountID
        self.note = note
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: ScheduledItemKind {
        get { ScheduledItemKind(rawValue: kindRaw) ?? .bill }
        set { kindRaw = newValue.rawValue }
    }

    var category: ScheduledItemCategory {
        get { ScheduledItemCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }

    var recurrence: ScheduleRecurrence {
        get { ScheduleRecurrence(rawValue: recurrenceRaw) ?? .monthly }
        set { recurrenceRaw = newValue.rawValue }
    }

    var currency: CurrencyCode {
        get { CurrencyCode(rawValue: currencyRaw) ?? .usd }
        set { currencyRaw = newValue.rawValue }
    }
}

@Model
final class FXRateEntry {
    @Attribute(.unique) var id: UUID
    var fromCurrencyRaw: String
    var toCurrencyRaw: String
    var rate: Double
    var asOfDate: Date
    var sourceDescription: String
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        fromCurrency: CurrencyCode,
        toCurrency: CurrencyCode,
        rate: Double,
        asOfDate: Date,
        sourceDescription: String = "Manual",
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.fromCurrencyRaw = fromCurrency.rawValue
        self.toCurrencyRaw = toCurrency.rawValue
        self.rate = rate
        self.asOfDate = asOfDate
        self.sourceDescription = sourceDescription
        self.note = note
        self.createdAt = createdAt
    }

    var fromCurrency: CurrencyCode {
        get { CurrencyCode(rawValue: fromCurrencyRaw) ?? .usd }
        set { fromCurrencyRaw = newValue.rawValue }
    }

    var toCurrency: CurrencyCode {
        get { CurrencyCode(rawValue: toCurrencyRaw) ?? .cad }
        set { toCurrencyRaw = newValue.rawValue }
    }
}

@Model
final class AccountTransfer {
    @Attribute(.unique) var id: UUID
    var fromAccountID: UUID
    var toAccountID: UUID
    var fromAmount: Double
    var toAmount: Double
    var fxRate: Double
    var transferDate: Date
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        fromAccountID: UUID,
        toAccountID: UUID,
        fromAmount: Double,
        toAmount: Double,
        fxRate: Double,
        transferDate: Date,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.fromAccountID = fromAccountID
        self.toAccountID = toAccountID
        self.fromAmount = fromAmount
        self.toAmount = toAmount
        self.fxRate = fxRate
        self.transferDate = transferDate
        self.note = note
        self.createdAt = createdAt
    }
}

@Model
final class FinancialReviewSnapshot {
    @Attribute(.unique) var id: UUID
    var label: String
    var periodStart: Date
    var periodEnd: Date
    var netWorthStart: Double
    var netWorthEnd: Double
    var totalExpenses: Double
    var totalContributions: Double
    var createdAt: Date
    var note: String

    init(
        id: UUID = UUID(),
        label: String,
        periodStart: Date,
        periodEnd: Date,
        netWorthStart: Double,
        netWorthEnd: Double,
        totalExpenses: Double,
        totalContributions: Double,
        createdAt: Date = .now,
        note: String = ""
    ) {
        self.id = id
        self.label = label
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.netWorthStart = netWorthStart
        self.netWorthEnd = netWorthEnd
        self.totalExpenses = totalExpenses
        self.totalContributions = totalContributions
        self.createdAt = createdAt
        self.note = note
    }
}

@Model
final class QuickCaptureTemplate {
    @Attribute(.unique) var id: UUID
    var title: String
    var accountID: UUID
    var balanceDelta: Double
    var contribution: Double
    var note: String
    var createdAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        accountID: UUID,
        balanceDelta: Double = 0,
        contribution: Double = 0,
        note: String = "",
        createdAt: Date = .now,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.accountID = accountID
        self.balanceDelta = balanceDelta
        self.contribution = contribution
        self.note = note
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var baseCurrencyRaw: String
    var usdToCadRate: Double
    var weekendReminderEnabled: Bool
    var weekendReminderWeekday: Int
    var weekendReminderHour: Int
    var dailyEscalationHour: Int
    var lastFinancialUpdate: Date
    var isAppLockEnabled: Bool
    var apiKeySourceDescription: String
    var embeddedTaxAPIKey: String
    var lastTaxSyncAt: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        baseCurrency: CurrencyCode = .usd,
        usdToCadRate: Double = 1.35,
        weekendReminderEnabled: Bool = true,
        weekendReminderWeekday: Int = 1,
        weekendReminderHour: Int = 21,
        dailyEscalationHour: Int = 21,
        lastFinancialUpdate: Date = .now,
        isAppLockEnabled: Bool = true,
        apiKeySourceDescription: String = "Embedded API key (security risk)",
        embeddedTaxAPIKey: String = "REPLACE_WITH_API_NINJAS_KEY",
        lastTaxSyncAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.baseCurrencyRaw = baseCurrency.rawValue
        self.usdToCadRate = usdToCadRate
        self.weekendReminderEnabled = weekendReminderEnabled
        self.weekendReminderWeekday = weekendReminderWeekday
        self.weekendReminderHour = weekendReminderHour
        self.dailyEscalationHour = dailyEscalationHour
        self.lastFinancialUpdate = lastFinancialUpdate
        self.isAppLockEnabled = isAppLockEnabled
        self.apiKeySourceDescription = apiKeySourceDescription
        self.embeddedTaxAPIKey = embeddedTaxAPIKey
        self.lastTaxSyncAt = lastTaxSyncAt
    }

    var baseCurrency: CurrencyCode {
        get { CurrencyCode(rawValue: baseCurrencyRaw) ?? .usd }
        set { baseCurrencyRaw = newValue.rawValue }
    }
}

@MainActor
func fetchOrCreateSettings(in context: ModelContext) -> AppSettings {
    let fetch = FetchDescriptor<AppSettings>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
    if let existing = try? context.fetch(fetch).first {
        return existing
    }

    let settings = AppSettings()
    context.insert(settings)
    try? context.save()
    return settings
}

@MainActor
func fetchActiveScheduledItems(in context: ModelContext) -> [ScheduledItem] {
    let descriptor = FetchDescriptor<ScheduledItem>(sortBy: [SortDescriptor(\.startDate, order: .forward)])
    let items = (try? context.fetch(descriptor)) ?? []
    return items.filter(\.isActive)
}

extension Date {
    var monthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }

    var dayStart: Date {
        Calendar.current.startOfDay(for: self)
    }

    var quarterStart: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        let month = components.month ?? 1
        let quarterMonth = ((month - 1) / 3) * 3 + 1
        var quarter = DateComponents()
        quarter.year = components.year
        quarter.month = quarterMonth
        quarter.day = 1
        return calendar.date(from: quarter) ?? self.monthStart
    }
}
