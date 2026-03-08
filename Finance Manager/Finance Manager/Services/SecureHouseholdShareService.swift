import CryptoKit
import Foundation
import SwiftData

enum SecureHouseholdShareService {
    static func exportEncrypted(
        accounts: [FinancialAccount],
        snapshots: [BalanceSnapshot],
        expenses: [ExpenseSnapshot],
        goals: [FinancialGoal],
        plans: [RecurringContributionPlan],
        scheduledItems: [ScheduledItem],
        fxRates: [FXRateEntry],
        transfers: [AccountTransfer],
        reviews: [FinancialReviewSnapshot],
        templates: [QuickCaptureTemplate],
        passphrase: String
    ) throws -> URL {
        let payload = SecureSharePayload(
            exportedAt: .now,
            accounts: accounts.map(AccountDTO.init),
            snapshots: snapshots.map(SnapshotDTO.init),
            expenses: expenses.map(ExpenseDTO.init),
            goals: goals.map(GoalDTO.init),
            plans: plans.map(PlanDTO.init),
            scheduledItems: scheduledItems.map(ScheduledItemDTO.init),
            fxRates: fxRates.map(FXRateDTO.init),
            transfers: transfers.map(TransferDTO.init),
            reviews: reviews.map(ReviewDTO.init),
            templates: templates.map(TemplateDTO.init)
        )

        let encoded = try JSONEncoder().encode(payload)
        let encrypted = try encrypt(data: encoded, passphrase: passphrase)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("portfolio-household-\(Int(Date().timeIntervalSince1970)).portfoliosecure")
        try encrypted.write(to: url, options: .atomic)
        return url
    }

    static func importEncrypted(
        from url: URL,
        passphrase: String,
        context: ModelContext
    ) throws -> Int {
        let encrypted = try Data(contentsOf: url)
        let decrypted = try decrypt(data: encrypted, passphrase: passphrase)
        let payload = try JSONDecoder().decode(SecureSharePayload.self, from: decrypted)

        var accountMap: [UUID: UUID] = [:]
        var imported = 0

        for dto in payload.accounts {
            let model = dto.model(newID: UUID())
            context.insert(model)
            accountMap[dto.id] = model.id
            imported += 1
        }

        for dto in payload.snapshots {
            guard let mappedAccount = accountMap[dto.accountID] else { continue }
            context.insert(dto.model(newID: UUID(), accountID: mappedAccount))
            imported += 1
        }

        for dto in payload.expenses {
            context.insert(dto.model(newID: UUID()))
            imported += 1
        }

        for dto in payload.goals {
            context.insert(dto.model(newID: UUID()))
            imported += 1
        }

        for dto in payload.plans {
            let mappedTarget = accountMap[dto.targetID] ?? dto.targetID
            context.insert(dto.model(newID: UUID(), targetID: mappedTarget))
            imported += 1
        }

        for dto in payload.scheduledItems {
            let linkedAccount = dto.linkedAccountID.flatMap { accountMap[$0] }
            context.insert(dto.model(newID: UUID(), linkedAccountID: linkedAccount))
            imported += 1
        }

        for dto in payload.fxRates {
            context.insert(dto.model(newID: UUID()))
            imported += 1
        }

        for dto in payload.transfers {
            guard
                let from = accountMap[dto.fromAccountID],
                let to = accountMap[dto.toAccountID]
            else { continue }
            context.insert(dto.model(newID: UUID(), fromAccountID: from, toAccountID: to))
            imported += 1
        }

        for dto in payload.reviews {
            context.insert(dto.model(newID: UUID()))
            imported += 1
        }

        for dto in payload.templates {
            guard let mappedAccount = accountMap[dto.accountID] else { continue }
            context.insert(dto.model(newID: UUID(), accountID: mappedAccount))
            imported += 1
        }

        try context.save()
        return imported
    }

    private static func encrypt(data: Data, passphrase: String) throws -> Data {
        let key = deriveKey(passphrase: passphrase)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw SecureShareError.encryptionFailed
        }
        return combined
    }

    private static func decrypt(data: Data, passphrase: String) throws -> Data {
        let key = deriveKey(passphrase: passphrase)
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    private static func deriveKey(passphrase: String) -> SymmetricKey {
        let salted = Data(("portfolio.household.\(passphrase)").utf8)
        let digest = SHA256.hash(data: salted)
        return SymmetricKey(data: Data(digest))
    }
}

enum SecureShareError: LocalizedError {
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to create encrypted household package."
        }
    }
}

private struct SecureSharePayload: Codable {
    let exportedAt: Date
    let accounts: [AccountDTO]
    let snapshots: [SnapshotDTO]
    let expenses: [ExpenseDTO]
    let goals: [GoalDTO]
    let plans: [PlanDTO]
    let scheduledItems: [ScheduledItemDTO]
    let fxRates: [FXRateDTO]
    let transfers: [TransferDTO]
    let reviews: [ReviewDTO]
    let templates: [TemplateDTO]
}

private struct AccountDTO: Codable {
    let id: UUID
    let name: String
    let categoryRaw: String
    let typeRaw: String
    let currencyRaw: String
    let customTypeName: String?
    let notes: String
    let targetAllocationPercent: Double?
    let aprPercent: Double?
    let minimumMonthlyPayment: Double?
    let createdAt: Date
    let updatedAt: Date
    let isArchived: Bool

    init(_ account: FinancialAccount) {
        id = account.id
        name = account.name
        categoryRaw = account.categoryRaw
        typeRaw = account.typeRaw
        currencyRaw = account.currencyRaw
        customTypeName = account.customTypeName
        notes = account.notes
        targetAllocationPercent = account.targetAllocationPercent
        aprPercent = account.aprPercent
        minimumMonthlyPayment = account.minimumMonthlyPayment
        createdAt = account.createdAt
        updatedAt = account.updatedAt
        isArchived = account.isArchived
    }

    func model(newID: UUID) -> FinancialAccount {
        FinancialAccount(
            id: newID,
            name: name,
            category: AccountCategory(rawValue: categoryRaw) ?? .asset,
            type: AccountType(rawValue: typeRaw) ?? .custom,
            currency: CurrencyCode(rawValue: currencyRaw) ?? .usd,
            customTypeName: customTypeName,
            notes: notes,
            targetAllocationPercent: targetAllocationPercent,
            aprPercent: aprPercent,
            minimumMonthlyPayment: minimumMonthlyPayment,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isArchived: isArchived
        )
    }
}

private struct SnapshotDTO: Codable {
    let id: UUID
    let accountID: UUID
    let date: Date
    let balance: Double
    let contribution: Double
    let note: String

    init(_ snapshot: BalanceSnapshot) {
        id = snapshot.id
        accountID = snapshot.accountID
        date = snapshot.date
        balance = snapshot.balance
        contribution = snapshot.contribution
        note = snapshot.note
    }

    func model(newID: UUID, accountID: UUID) -> BalanceSnapshot {
        BalanceSnapshot(
            id: newID,
            accountID: accountID,
            date: date,
            balance: balance,
            contribution: contribution,
            note: note
        )
    }
}

private struct ExpenseDTO: Codable {
    let id: UUID
    let monthStart: Date
    let categoryRaw: String
    let amount: Double
    let createdAt: Date

    init(_ expense: ExpenseSnapshot) {
        id = expense.id
        monthStart = expense.monthStart
        categoryRaw = expense.categoryRaw
        amount = expense.amount
        createdAt = expense.createdAt
    }

    func model(newID: UUID) -> ExpenseSnapshot {
        ExpenseSnapshot(
            id: newID,
            monthStart: monthStart,
            category: ExpenseCategory(rawValue: categoryRaw) ?? .other,
            amount: amount,
            createdAt: createdAt
        )
    }
}

private struct GoalDTO: Codable {
    let id: UUID
    let title: String
    let typeRaw: String
    let targetAmount: Double
    let currentAmount: Double
    let monthlyContribution: Double
    let targetDate: Date
    let createdAt: Date
    let note: String

    init(_ goal: FinancialGoal) {
        id = goal.id
        title = goal.title
        typeRaw = goal.typeRaw
        targetAmount = goal.targetAmount
        currentAmount = goal.currentAmount
        monthlyContribution = goal.monthlyContribution
        targetDate = goal.targetDate
        createdAt = goal.createdAt
        note = goal.note
    }

    func model(newID: UUID) -> FinancialGoal {
        FinancialGoal(
            id: newID,
            title: title,
            type: GoalType(rawValue: typeRaw) ?? .custom,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            monthlyContribution: monthlyContribution,
            targetDate: targetDate,
            createdAt: createdAt,
            note: note
        )
    }
}

private struct PlanDTO: Codable {
    let id: UUID
    let title: String
    let targetID: UUID
    let targetKindRaw: String
    let monthlyAmount: Double
    let startDate: Date
    let createdAt: Date

    init(_ plan: RecurringContributionPlan) {
        id = plan.id
        title = plan.title
        targetID = plan.targetID
        targetKindRaw = plan.targetKindRaw
        monthlyAmount = plan.monthlyAmount
        startDate = plan.startDate
        createdAt = plan.createdAt
    }

    func model(newID: UUID, targetID: UUID) -> RecurringContributionPlan {
        RecurringContributionPlan(
            id: newID,
            title: title,
            targetID: targetID,
            targetKind: ContributionTargetKind(rawValue: targetKindRaw) ?? .goal,
            monthlyAmount: monthlyAmount,
            startDate: startDate,
            createdAt: createdAt
        )
    }
}

private struct ScheduledItemDTO: Codable {
    let id: UUID
    let title: String
    let kindRaw: String
    let categoryRaw: String
    let recurrenceRaw: String
    let amount: Double
    let currencyRaw: String
    let startDate: Date
    let reminderHour: Int
    let reminderMinute: Int
    let remindDaysBefore: Int
    let linkedAccountID: UUID?
    let note: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    init(_ item: ScheduledItem) {
        id = item.id
        title = item.title
        kindRaw = item.kindRaw
        categoryRaw = item.categoryRaw
        recurrenceRaw = item.recurrenceRaw
        amount = item.amount
        currencyRaw = item.currencyRaw
        startDate = item.startDate
        reminderHour = item.reminderHour
        reminderMinute = item.reminderMinute
        remindDaysBefore = item.remindDaysBefore
        linkedAccountID = item.linkedAccountID
        note = item.note
        isActive = item.isActive
        createdAt = item.createdAt
        updatedAt = item.updatedAt
    }

    func model(newID: UUID, linkedAccountID: UUID?) -> ScheduledItem {
        ScheduledItem(
            id: newID,
            title: title,
            kind: ScheduledItemKind(rawValue: kindRaw) ?? .bill,
            category: ScheduledItemCategory(rawValue: categoryRaw) ?? .custom,
            recurrence: ScheduleRecurrence(rawValue: recurrenceRaw) ?? .monthly,
            amount: amount,
            currency: CurrencyCode(rawValue: currencyRaw) ?? .usd,
            startDate: startDate,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            remindDaysBefore: remindDaysBefore,
            linkedAccountID: linkedAccountID,
            note: note,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct FXRateDTO: Codable {
    let id: UUID
    let fromCurrencyRaw: String
    let toCurrencyRaw: String
    let rate: Double
    let asOfDate: Date
    let sourceDescription: String
    let note: String
    let createdAt: Date

    init(_ rateModel: FXRateEntry) {
        id = rateModel.id
        fromCurrencyRaw = rateModel.fromCurrencyRaw
        toCurrencyRaw = rateModel.toCurrencyRaw
        rate = rateModel.rate
        asOfDate = rateModel.asOfDate
        sourceDescription = rateModel.sourceDescription
        note = rateModel.note
        createdAt = rateModel.createdAt
    }

    func model(newID: UUID) -> FXRateEntry {
        FXRateEntry(
            id: newID,
            fromCurrency: CurrencyCode(rawValue: fromCurrencyRaw) ?? .usd,
            toCurrency: CurrencyCode(rawValue: toCurrencyRaw) ?? .cad,
            rate: rate,
            asOfDate: asOfDate,
            sourceDescription: sourceDescription,
            note: note,
            createdAt: createdAt
        )
    }
}

private struct TransferDTO: Codable {
    let id: UUID
    let fromAccountID: UUID
    let toAccountID: UUID
    let fromAmount: Double
    let toAmount: Double
    let fxRate: Double
    let transferDate: Date
    let note: String
    let createdAt: Date

    init(_ transfer: AccountTransfer) {
        id = transfer.id
        fromAccountID = transfer.fromAccountID
        toAccountID = transfer.toAccountID
        fromAmount = transfer.fromAmount
        toAmount = transfer.toAmount
        fxRate = transfer.fxRate
        transferDate = transfer.transferDate
        note = transfer.note
        createdAt = transfer.createdAt
    }

    func model(newID: UUID, fromAccountID: UUID, toAccountID: UUID) -> AccountTransfer {
        AccountTransfer(
            id: newID,
            fromAccountID: fromAccountID,
            toAccountID: toAccountID,
            fromAmount: fromAmount,
            toAmount: toAmount,
            fxRate: fxRate,
            transferDate: transferDate,
            note: note,
            createdAt: createdAt
        )
    }
}

private struct ReviewDTO: Codable {
    let id: UUID
    let label: String
    let periodStart: Date
    let periodEnd: Date
    let netWorthStart: Double
    let netWorthEnd: Double
    let totalExpenses: Double
    let totalContributions: Double
    let createdAt: Date
    let note: String

    init(_ review: FinancialReviewSnapshot) {
        id = review.id
        label = review.label
        periodStart = review.periodStart
        periodEnd = review.periodEnd
        netWorthStart = review.netWorthStart
        netWorthEnd = review.netWorthEnd
        totalExpenses = review.totalExpenses
        totalContributions = review.totalContributions
        createdAt = review.createdAt
        note = review.note
    }

    func model(newID: UUID) -> FinancialReviewSnapshot {
        FinancialReviewSnapshot(
            id: newID,
            label: label,
            periodStart: periodStart,
            periodEnd: periodEnd,
            netWorthStart: netWorthStart,
            netWorthEnd: netWorthEnd,
            totalExpenses: totalExpenses,
            totalContributions: totalContributions,
            createdAt: createdAt,
            note: note
        )
    }
}

private struct TemplateDTO: Codable {
    let id: UUID
    let title: String
    let accountID: UUID
    let balanceDelta: Double
    let contribution: Double
    let note: String
    let createdAt: Date
    let lastUsedAt: Date?

    init(_ template: QuickCaptureTemplate) {
        id = template.id
        title = template.title
        accountID = template.accountID
        balanceDelta = template.balanceDelta
        contribution = template.contribution
        note = template.note
        createdAt = template.createdAt
        lastUsedAt = template.lastUsedAt
    }

    func model(newID: UUID, accountID: UUID) -> QuickCaptureTemplate {
        QuickCaptureTemplate(
            id: newID,
            title: title,
            accountID: accountID,
            balanceDelta: balanceDelta,
            contribution: contribution,
            note: note,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt
        )
    }
}
