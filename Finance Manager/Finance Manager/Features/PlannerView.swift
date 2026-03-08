import Charts
import SwiftData
import SwiftUI

struct PlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationScheduler: PortfolioNotificationScheduler

    @Query(sort: [SortDescriptor(\ExpenseSnapshot.monthStart, order: .reverse)]) private var expenses: [ExpenseSnapshot]
    @Query(sort: [SortDescriptor(\FinancialGoal.createdAt, order: .forward)]) private var goals: [FinancialGoal]
    @Query(sort: [SortDescriptor(\RecurringContributionPlan.createdAt, order: .forward)]) private var plans: [RecurringContributionPlan]
    @Query(sort: [SortDescriptor(\FinancialAccount.createdAt, order: .forward)]) private var accounts: [FinancialAccount]
    @Query(sort: [SortDescriptor(\ScheduledItem.startDate, order: .forward)]) private var scheduledItems: [ScheduledItem]

    @State private var showingAddExpense = false
    @State private var showingAddGoal = false
    @State private var showingAddPlan = false
    @State private var showingAddScheduledItem = false

    private var settings: AppSettings {
        fetchOrCreateSettings(in: modelContext)
    }

    private var baseCurrency: CurrencyCode { settings.baseCurrency }

    private var expenseCategories: [AllocationSlice] {
        FinanceAnalytics.expenseByCategoryCurrentMonth(expenses: expenses)
    }

    private var upcomingScheduledEvents: [ScheduledDueEvent] {
        FinanceAnalytics.upcomingDueEvents(
            scheduledItems: scheduledItems.filter(\.isActive),
            now: .now,
            daysAhead: 90
        )
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

                    Button("Add Monthly Category Total") {
                        showingAddExpense = true
                    }
                }

                Section("Scheduled Bills & Reminders") {
                    if scheduledItems.isEmpty {
                        Text("No scheduled items yet. Add credit card, mortgage, property tax, and other due-date reminders.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scheduledItems) { item in
                            let nextDate = ScheduleEngine.nextOccurrence(for: item, after: .now.addingTimeInterval(-1))
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.title)
                                        .font(.headline)
                                    Spacer()
                                    if item.kind == .bill {
                                        Text(PortfolioFormatters.currency(item.amount, code: item.currency))
                                            .font(.caption)
                                            .foregroundStyle(PortfolioTheme.danger)
                                    }
                                }
                                Text("\(item.kind.displayName) • \(item.category.displayName) • \(item.recurrence.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let nextDate {
                                    Text("Next due: \(nextDate.formatted(date: .abbreviated, time: .shortened)) • remind \(item.remindDaysBefore)d before")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("No upcoming due date")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteScheduledItems)
                    }

                    if !upcomingScheduledEvents.isEmpty {
                        Divider()
                        Text("Upcoming (90 days)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(upcomingScheduledEvents.prefix(4)) { event in
                            HStack {
                                Text(event.title)
                                    .font(.caption)
                                Spacer()
                                Text(event.dueDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button("Add Scheduled Item") {
                        showingAddScheduledItem = true
                    }
                }

                Section("Goals") {
                    if goals.isEmpty {
                        Text("No goals yet. Add one to start projection tracking.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(goals) { goal in
                        let projection = FinanceAnalytics.goalProjection(goal: goal)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(goal.title)
                                    .font(.headline)
                                Spacer()
                                Text(PortfolioFormatters.currency(goal.targetAmount, code: baseCurrency))
                            }

                            ProgressView(value: projection.progress)
                                .tint(PortfolioTheme.accent)

                            Text("Current: \(PortfolioFormatters.currency(goal.currentAmount, code: baseCurrency))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Monthly contribution: \(PortfolioFormatters.currency(goal.monthlyContribution, code: baseCurrency))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let projected = projection.projectedCompletion {
                                Text("Projected completion: \(projected.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteGoals)

                    Button("Add Goal") {
                        showingAddGoal = true
                    }
                }

                Section("Recurring Contribution Planner") {
                    if plans.isEmpty {
                        Text("No recurring plans yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(plans) { plan in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.title)
                                .font(.headline)
                            Text("\(plan.targetKind == .goal ? "Goal" : "Account") • \(PortfolioFormatters.currency(plan.monthlyAmount, code: baseCurrency))/month")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deletePlans)

                    Button("Add Recurring Plan") {
                        showingAddPlan = true
                    }
                }
            }
            .navigationTitle("Planner")
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listStyle(.insetGrouped)
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseSheet(baseCurrency: baseCurrency) { month, category, amount in
                    modelContext.insert(ExpenseSnapshot(monthStart: month.monthStart, category: category, amount: amount))
                    markUpdated()
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalSheet(baseCurrency: baseCurrency) { goal in
                    modelContext.insert(goal)
                    markUpdated()
                }
            }
            .sheet(isPresented: $showingAddPlan) {
                AddRecurringPlanSheet(accounts: accounts, goals: goals, baseCurrency: baseCurrency) { plan in
                    modelContext.insert(plan)
                    try? modelContext.save()
                }
            }
            .sheet(isPresented: $showingAddScheduledItem) {
                AddScheduledItemSheet(accounts: accounts) { item in
                    modelContext.insert(item)
                    markUpdated()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .portfolioQuickPlannerRequested)) { _ in
                showingAddScheduledItem = true
            }
        }
        .portfolioScreenBackground()
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(goals[index])
        }
        markUpdated()
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
        try? modelContext.save()
    }

    private func deleteScheduledItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(scheduledItems[index])
        }
        markUpdated()
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
}

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationScheduler: PortfolioNotificationScheduler

    @Query(sort: [SortDescriptor(\FinancialGoal.createdAt, order: .forward)]) private var goals: [FinancialGoal]
    @Query(sort: [SortDescriptor(\RecurringContributionPlan.createdAt, order: .forward)]) private var plans: [RecurringContributionPlan]
    @Query(sort: [SortDescriptor(\FinancialAccount.createdAt, order: .forward)]) private var accounts: [FinancialAccount]

    @State private var showingAddGoal = false
    @State private var showingAddPlan = false

    private var settings: AppSettings {
        fetchOrCreateSettings(in: modelContext)
    }

    private var baseCurrency: CurrencyCode { settings.baseCurrency }

    var body: some View {
        NavigationStack {
            List {
                Section("Goals") {
                    if goals.isEmpty {
                        Text("No goals yet. Add one to start projection tracking.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(goals) { goal in
                        let projection = FinanceAnalytics.goalProjection(goal: goal)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(goal.title)
                                    .font(.headline)
                                Spacer()
                                Text(PortfolioFormatters.currency(goal.targetAmount, code: baseCurrency))
                            }

                            ProgressView(value: projection.progress)
                                .tint(PortfolioTheme.accent)

                            Text("Current: \(PortfolioFormatters.currency(goal.currentAmount, code: baseCurrency))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Monthly contribution: \(PortfolioFormatters.currency(goal.monthlyContribution, code: baseCurrency))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let projected = projection.projectedCompletion {
                                Text("Projected completion: \(projected.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteGoals)

                    Button("Add Goal") {
                        showingAddGoal = true
                    }
                }

                Section("Recurring Contribution Planner") {
                    if plans.isEmpty {
                        Text("No recurring plans yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(plans) { plan in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.title)
                                .font(.headline)
                            Text("\(plan.targetKind == .goal ? "Goal" : "Account") • \(PortfolioFormatters.currency(plan.monthlyAmount, code: baseCurrency))/month")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deletePlans)

                    Button("Add Recurring Plan") {
                        showingAddPlan = true
                    }
                }
            }
            .navigationTitle("Goals")
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listStyle(.insetGrouped)
            .sheet(isPresented: $showingAddGoal) {
                AddGoalSheet(baseCurrency: baseCurrency) { goal in
                    modelContext.insert(goal)
                    markUpdated()
                }
            }
            .sheet(isPresented: $showingAddPlan) {
                AddRecurringPlanSheet(accounts: accounts, goals: goals, baseCurrency: baseCurrency) { plan in
                    modelContext.insert(plan)
                    markUpdated()
                }
            }
        }
        .portfolioScreenBackground()
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(goals[index])
        }
        markUpdated()
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
        markUpdated()
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
}

struct RemindersView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationScheduler: PortfolioNotificationScheduler

    @Query(sort: [SortDescriptor(\ScheduledItem.startDate, order: .forward)]) private var scheduledItems: [ScheduledItem]
    @Query(sort: [SortDescriptor(\FinancialAccount.createdAt, order: .forward)]) private var accounts: [FinancialAccount]

    @State private var showingAddScheduledItem = false

    private var settings: AppSettings {
        fetchOrCreateSettings(in: modelContext)
    }

    private var upcomingScheduledEvents: [ScheduledDueEvent] {
        FinanceAnalytics.upcomingDueEvents(
            scheduledItems: scheduledItems.filter(\.isActive),
            now: .now,
            daysAhead: 90
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Scheduled Bills & Reminders") {
                    if scheduledItems.isEmpty {
                        Text("No scheduled items yet. Add credit card, mortgage, property tax, and other due-date reminders.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scheduledItems) { item in
                            let nextDate = ScheduleEngine.nextOccurrence(for: item, after: .now.addingTimeInterval(-1))
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.title)
                                        .font(.headline)
                                    Spacer()
                                    if item.kind == .bill {
                                        Text(PortfolioFormatters.currency(item.amount, code: item.currency))
                                            .font(.caption)
                                            .foregroundStyle(PortfolioTheme.danger)
                                    }
                                }
                                Text("\(item.kind.displayName) • \(item.category.displayName) • \(item.recurrence.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let nextDate {
                                    Text("Next due: \(nextDate.formatted(date: .abbreviated, time: .shortened)) • remind \(item.remindDaysBefore)d before")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("No upcoming due date")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteScheduledItems)
                    }

                    Button("Add Scheduled Item") {
                        showingAddScheduledItem = true
                    }
                }

                if !upcomingScheduledEvents.isEmpty {
                    Section("Upcoming (90 days)") {
                        ForEach(upcomingScheduledEvents.prefix(12)) { event in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(event.kind.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(event.dueDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listStyle(.insetGrouped)
            .sheet(isPresented: $showingAddScheduledItem) {
                AddScheduledItemSheet(accounts: accounts) { item in
                    modelContext.insert(item)
                    markUpdated()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .portfolioQuickPlannerRequested)) { _ in
                showingAddScheduledItem = true
            }
        }
        .portfolioScreenBackground()
    }

    private func deleteScheduledItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(scheduledItems[index])
        }
        markUpdated()
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

private struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss

    let baseCurrency: CurrencyCode
    let onSave: (FinancialGoal) -> Void

    @State private var title = ""
    @State private var type: GoalType = .emergencyFund
    @State private var targetAmount = 10_000.0
    @State private var currentAmount = 0.0
    @State private var monthlyContribution = 300.0
    @State private var targetDate = Calendar.current.date(byAdding: .year, value: 2, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal title", text: $title)
                Picker("Goal type", selection: $type) {
                    ForEach(GoalType.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }

                HStack {
                    Text("Target amount")
                    Spacer()
                    TextField("0", value: $targetAmount, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }

                HStack {
                    Text("Current amount")
                    Spacer()
                    TextField("0", value: $currentAmount, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }

                HStack {
                    Text("Monthly contribution")
                    Spacer()
                    TextField("0", value: $monthlyContribution, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }

                DatePicker("Target date", selection: $targetDate, displayedComponents: [.date])
                Text("Values shown in \(baseCurrency.rawValue).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            FinancialGoal(
                                title: title,
                                type: type,
                                targetAmount: targetAmount,
                                currentAmount: currentAmount,
                                monthlyContribution: monthlyContribution,
                                targetDate: targetDate
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct AddRecurringPlanSheet: View {
    @Environment(\.dismiss) private var dismiss

    let accounts: [FinancialAccount]
    let goals: [FinancialGoal]
    let baseCurrency: CurrencyCode
    let onSave: (RecurringContributionPlan) -> Void

    @State private var title = ""
    @State private var targetKind: ContributionTargetKind = .goal
    @State private var selectedGoalID: UUID?
    @State private var selectedAccountID: UUID?
    @State private var monthlyAmount = 200.0
    @State private var startDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("Plan title", text: $title)

                Picker("Target", selection: $targetKind) {
                    Text("Goal").tag(ContributionTargetKind.goal)
                    Text("Account").tag(ContributionTargetKind.account)
                }
                .pickerStyle(.segmented)

                if targetKind == .goal {
                    Picker("Goal", selection: $selectedGoalID) {
                        Text("Select").tag(UUID?.none)
                        ForEach(goals) { goal in
                            Text(goal.title).tag(Optional(goal.id))
                        }
                    }
                } else {
                    Picker("Account", selection: $selectedAccountID) {
                        Text("Select").tag(UUID?.none)
                        ForEach(accounts.filter { !$0.isArchived }) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }
                }

                HStack {
                    Text("Monthly amount")
                    Spacer()
                    TextField("0", value: $monthlyAmount, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 150)
                }

                DatePicker("Start date", selection: $startDate, displayedComponents: [.date])
                Text("Stored in \(baseCurrency.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Recurring Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let targetID = targetKind == .goal ? selectedGoalID : selectedAccountID
                        guard let targetID else { return }
                        let plan = RecurringContributionPlan(
                            title: title,
                            targetID: targetID,
                            targetKind: targetKind,
                            monthlyAmount: monthlyAmount,
                            startDate: startDate
                        )
                        onSave(plan)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (targetKind == .goal ? selectedGoalID == nil : selectedAccountID == nil))
                }
            }
        }
    }
}

private struct AddScheduledItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    let accounts: [FinancialAccount]
    let onSave: (ScheduledItem) -> Void

    @State private var title = ""
    @State private var kind: ScheduledItemKind = .bill
    @State private var category: ScheduledItemCategory = .creditCard
    @State private var recurrence: ScheduleRecurrence = .monthly
    @State private var amount = 0.0
    @State private var currency: CurrencyCode = .usd
    @State private var startDate = Date()
    @State private var reminderHour = 9
    @State private var reminderMinute = 0
    @State private var remindDaysBefore = 2
    @State private var linkedAccountID: UUID?
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Title", text: $title)
                    Picker("Kind", selection: $kind) {
                        ForEach(ScheduledItemKind.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Category", selection: $category) {
                        ForEach(ScheduledItemCategory.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    Picker("Recurrence", selection: $recurrence) {
                        ForEach(ScheduleRecurrence.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }

                Section("Due Details") {
                    if kind == .bill {
                        HStack {
                            Text("Amount")
                            Spacer()
                            TextField("0", value: $amount, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 140)
                        }

                        Picker("Currency", selection: $currency) {
                            ForEach(CurrencyCode.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    }

                    DatePicker("First due date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])

                    Stepper("Days before reminder: \(remindDaysBefore)", value: $remindDaysBefore, in: 0...30)

                    Picker("Reminder hour", selection: $reminderHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }

                    Picker("Reminder minute", selection: $reminderMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                }

                Section("Link & Note") {
                    Picker("Linked account", selection: $linkedAccountID) {
                        Text("None").tag(UUID?.none)
                        ForEach(accounts.filter { !$0.isArchived }) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }

                    TextField("Note", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Scheduled Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var dueDate = startDate
                        if let adjusted = Calendar.current.date(
                            bySettingHour: reminderHour,
                            minute: reminderMinute,
                            second: 0,
                            of: dueDate
                        ) {
                            dueDate = adjusted
                        }

                        onSave(
                            ScheduledItem(
                                title: title,
                                kind: kind,
                                category: category,
                                recurrence: recurrence,
                                amount: kind == .bill ? amount : 0,
                                currency: currency,
                                startDate: dueDate,
                                reminderHour: reminderHour,
                                reminderMinute: reminderMinute,
                                remindDaysBefore: remindDaysBefore,
                                linkedAccountID: linkedAccountID,
                                note: note
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
