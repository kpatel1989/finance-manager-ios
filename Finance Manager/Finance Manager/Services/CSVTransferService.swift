import Foundation
import SwiftData

enum CSVTransferService {
    static func exportURL(
        accounts: [FinancialAccount],
        snapshots: [BalanceSnapshot],
        expenses: [ExpenseSnapshot],
        goals: [FinancialGoal]
    ) throws -> URL {
        let iso = ISO8601DateFormatter()
        var rows: [String] = [
            "record_type,id,parent_id,name,category,type,currency,date,amount,contribution,target_amount,current_amount,monthly_amount,target_date,notes"
        ]

        for account in accounts {
            rows.append(
                [
                    "ACCOUNT",
                    account.id.uuidString,
                    "",
                    csvEscape(account.name),
                    account.category.rawValue,
                    account.type.rawValue,
                    account.currency.rawValue,
                    "",
                    "",
                    "",
                    "",
                    "",
                    "",
                    "",
                    csvEscape(account.notes)
                ].joined(separator: ",")
            )
        }

        for snapshot in snapshots {
            rows.append(
                [
                    "SNAPSHOT",
                    snapshot.id.uuidString,
                    snapshot.accountID.uuidString,
                    "",
                    "",
                    "",
                    "",
                    iso.string(from: snapshot.date),
                    String(snapshot.balance),
                    String(snapshot.contribution),
                    "",
                    "",
                    "",
                    "",
                    csvEscape(snapshot.note)
                ].joined(separator: ",")
            )
        }

        for expense in expenses {
            rows.append(
                [
                    "EXPENSE",
                    expense.id.uuidString,
                    "",
                    expense.category.rawValue,
                    "",
                    "",
                    "",
                    iso.string(from: expense.monthStart),
                    String(expense.amount),
                    "",
                    "",
                    "",
                    "",
                    "",
                    ""
                ].joined(separator: ",")
            )
        }

        for goal in goals {
            rows.append(
                [
                    "GOAL",
                    goal.id.uuidString,
                    "",
                    csvEscape(goal.title),
                    "",
                    goal.type.rawValue,
                    "",
                    "",
                    "",
                    "",
                    String(goal.targetAmount),
                    String(goal.currentAmount),
                    String(goal.monthlyContribution),
                    iso.string(from: goal.targetDate),
                    csvEscape(goal.note)
                ].joined(separator: ",")
            )
        }

        let csv = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("portfolio-export-\(Int(Date().timeIntervalSince1970)).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func importCSV(from url: URL, context: ModelContext) throws -> Int {
        let contents = try String(contentsOf: url)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count > 1 else { return 0 }

        let iso = ISO8601DateFormatter()
        let existingAccounts = (try? context.fetch(FetchDescriptor<FinancialAccount>())) ?? []
        var accountIDs = Set(existingAccounts.map(\.id))
        var imported = 0

        for line in lines.dropFirst() {
            let values = parseCSVLine(String(line))
            guard values.count >= 15 else { continue }

            switch values[0] {
            case "ACCOUNT":
                guard let id = UUID(uuidString: values[1]), !accountIDs.contains(id) else { continue }
                let category = AccountCategory(rawValue: values[4]) ?? .asset
                let type = AccountType(rawValue: values[5]) ?? .custom
                let currency = CurrencyCode(rawValue: values[6]) ?? .usd

                let account = FinancialAccount(
                    id: id,
                    name: values[3],
                    category: category,
                    type: type,
                    currency: currency,
                    notes: values[14]
                )
                context.insert(account)
                accountIDs.insert(id)
                imported += 1

            case "SNAPSHOT":
                guard
                    let id = UUID(uuidString: values[1]),
                    let accountID = UUID(uuidString: values[2]),
                    accountIDs.contains(accountID),
                    let date = iso.date(from: values[7]),
                    let amount = Double(values[8])
                else {
                    continue
                }

                let contribution = Double(values[9]) ?? 0
                context.insert(BalanceSnapshot(id: id, accountID: accountID, date: date, balance: amount, contribution: contribution, note: values[14]))
                imported += 1

            case "EXPENSE":
                guard
                    let id = UUID(uuidString: values[1]),
                    let month = iso.date(from: values[7]),
                    let amount = Double(values[8])
                else {
                    continue
                }

                let category = ExpenseCategory(rawValue: values[3]) ?? .other
                context.insert(ExpenseSnapshot(id: id, monthStart: month, category: category, amount: amount))
                imported += 1

            case "GOAL":
                guard
                    let id = UUID(uuidString: values[1]),
                    let targetAmount = Double(values[10]),
                    let currentAmount = Double(values[11]),
                    let monthlyAmount = Double(values[12]),
                    let targetDate = iso.date(from: values[13])
                else {
                    continue
                }

                let type = GoalType(rawValue: values[5]) ?? .custom
                context.insert(
                    FinancialGoal(
                        id: id,
                        title: values[3],
                        type: type,
                        targetAmount: targetAmount,
                        currentAmount: currentAmount,
                        monthlyContribution: monthlyAmount,
                        targetDate: targetDate,
                        note: values[14]
                    )
                )
                imported += 1

            default:
                continue
            }
        }

        try? context.save()
        return imported
    }

    private static func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var field = ""
        var isInQuotes = false
        var iterator = line.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if isInQuotes, let next = iterator.next() {
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        isInQuotes.toggle()
                        if next == "," {
                            fields.append(field)
                            field = ""
                        } else {
                            field.append(next)
                        }
                    }
                } else {
                    isInQuotes.toggle()
                }
            } else if character == ",", !isInQuotes {
                fields.append(field)
                field = ""
            } else {
                field.append(character)
            }
        }

        fields.append(field)
        return fields
    }
}
