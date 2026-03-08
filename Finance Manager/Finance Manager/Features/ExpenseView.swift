import Charts
import SwiftData
import SwiftUI

struct ExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationScheduler: PortfolioNotificationScheduler

    @Query(sort: [SortDescriptor(\ExpenseSnapshot.monthStart, order: .reverse)]) private var expenses: [ExpenseSnapshot]

    @State private var showingAddExpense = false

    private var settings: AppSettings {
        fetchOrCreateSettings(in: modelContext)
    }

    private var baseCurrency: CurrencyCode { settings.baseCurrency }

    private var expenseCategories: [AllocationSlice] {
        FinanceAnalytics.expenseByCategoryCurrentMonth(expenses: expenses)
    }

    private var expenseTrend: [NetWorthPoint] {
        FinanceAnalytics.expenseByMonth(expenses: expenses, monthsBack: 6)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Expense Calculator") {
                    HStack {
                        Text("Current month total")
                        Spacer()
                        let total = expenseCategories.map(\.value).reduce(0, +)
                        Text(PortfolioFormatters.currency(total, code: baseCurrency))
                            .bold()
                    }

                    if expenseCategories.isEmpty {
                        Text("No monthly category totals yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(expenseCategories) { entry in
                            SectorMark(
                                angle: .value("Amount", entry.value),
                                innerRadius: .ratio(0.55),
                                angularInset: 1
                            )
                            .foregroundStyle(by: .value("Category", entry.name))
                        }
                        .frame(height: 180)
                    }
                }

                Section("Trend") {
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
                    .frame(height: 180)
                }

                Section {
                    Button("Add Monthly Category Total") {
                        showingAddExpense = true
                    }
                }
            }
            .navigationTitle("Expense")
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listStyle(.insetGrouped)
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseSheet(baseCurrency: baseCurrency) { month, category, amount in
                    modelContext.insert(ExpenseSnapshot(monthStart: month.monthStart, category: category, amount: amount))
                    markUpdated()
                }
            }
        }
        .portfolioScreenBackground()
    }

    private func markUpdated() {
        settings.lastFinancialUpdate = .now
        notificationScheduler.refreshSchedules(
            lastStatusUpdate: settings.lastFinancialUpdate,
            scheduledItems: fetchActiveScheduledItems(in: modelContext),
            now: .now
        )
        try? modelContext.save()
    }
}

private struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss

    let baseCurrency: CurrencyCode
    let onSave: (Date, ExpenseCategory, Double) -> Void

    @State private var month = Date().monthStart
    @State private var category: ExpenseCategory = .housing
    @State private var amount = 0.0

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Month", selection: $month, displayedComponents: [.date])
                Picker("Category", selection: $category) {
                    ForEach(ExpenseCategory.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                HStack {
                    Text("Amount")
                    Spacer()
                    TextField("0", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
                Text("Stored as monthly category total in \(baseCurrency.rawValue).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Add Expense Total")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(month, category, amount)
                        dismiss()
                    }
                }
            }
        }
    }
}
