import SwiftData
import SwiftUI

struct TaxCalculatorView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\TaxEstimateLog.updatedAt, order: .reverse)]) private var logs: [TaxEstimateLog]

    @State private var jurisdiction: TaxJurisdiction = .us
    @State private var filingLabel = "Single"
    @State private var annualIncome = 100_000.0
    @State private var deductions = 0.0
    @State private var latestResult: TaxEstimateResult?
    @State private var isLoading = false
    @State private var apiKeyInput = ""

    private var settings: AppSettings {
        fetchOrCreateSettings(in: modelContext)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Tax Calculator", systemImage: "function")

            Text("Estimate only. Not tax advice. Use a licensed professional before filing.")
                .font(.caption)
                .foregroundStyle(PortfolioTheme.danger)

            Picker("Jurisdiction", selection: $jurisdiction) {
                ForEach(TaxJurisdiction.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Picker("Filing", selection: $filingLabel) {
                Text("Single").tag("Single")
                Text("Married").tag("Married")
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Annual income")
                    Spacer()
                TextField("0", value: $annualIncome, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150)
            }

            HStack {
                Text("Deductions")
                Spacer()
                TextField("0", value: $deductions, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150)
            }

            TextField("API Ninjas key (override embedded)", text: $apiKeyInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack {
                Button("Save API Key") {
                    KeychainStore.save(key: "portfolio.api.ninjas", value: apiKeyInput)
                }
                .buttonStyle(.bordered)

                Button(isLoading ? "Calculating..." : "Calculate") {
                    Task {
                        await calculateEstimate()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }
            .tint(PortfolioTheme.accent)

            if let latestResult {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated tax: \(formattedCurrency(latestResult.estimatedTax))")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text("Effective rate: \(PortfolioFormatters.percent(latestResult.effectiveRate))")
                    Text("Source: \(latestResult.source.displayName)")
                    Text("Updated: \(latestResult.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()
            }

            if let last = logs.first {
                Text("Last saved tax run: \(last.updatedAt.formatted(date: .abbreviated, time: .shortened)) • \(TaxComputationSource(rawValue: last.sourceRaw)?.displayName ?? "-")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            apiKeyInput = KeychainStore.read(key: "portfolio.api.ninjas") ?? ""
        }
    }

    private func calculateEstimate() async {
        isLoading = true
        defer { isLoading = false }

        let embeddedKey = settings.embeddedTaxAPIKey
        let provider = HybridTaxProvider(
            apiProvider: APINinjasTaxProvider(
                apiKeyProvider: {
                    let custom = KeychainStore.read(key: "portfolio.api.ninjas")
                    if let custom, !custom.isEmpty {
                        return custom
                    }
                    return embeddedKey
                }
            )
        )

        let request = TaxEstimateRequest(
            jurisdiction: jurisdiction,
            annualIncome: annualIncome,
            filingLabel: filingLabel,
            deductions: deductions
        )

        do {
            let result = try await provider.estimate(request)
            latestResult = result
            settings.lastTaxSyncAt = result.updatedAt

            if let data = try? JSONEncoder().encode(result.details),
               let detailString = String(data: data, encoding: .utf8) {
                let log = TaxEstimateLog(
                    jurisdiction: result.jurisdiction,
                    annualIncome: result.annualIncome,
                    estimatedTax: result.estimatedTax,
                    effectiveRate: result.effectiveRate,
                    source: result.source,
                    updatedAt: result.updatedAt,
                    serializedDetails: detailString
                )
                modelContext.insert(log)
            }
            try? modelContext.save()
        } catch {
            latestResult = nil
        }
    }

    private func formattedCurrency(_ value: Double) -> String {
        let currency = settings.baseCurrency
        return PortfolioFormatters.currency(value, code: currency)
    }
}
