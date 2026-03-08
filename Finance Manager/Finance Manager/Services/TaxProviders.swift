import Foundation

enum TaxProviderError: Error {
    case missingAPIKey
    case invalidResponse
}

private struct TaxBracket {
    let upperBound: Double
    let rate: Double
}

final class OfflineTaxProvider: TaxProvider {
    func estimate(_ request: TaxEstimateRequest) async throws -> TaxEstimateResult {
        let brackets: [TaxBracket]
        let standardDeduction: Double

        switch request.jurisdiction {
        case .us:
            // Simplified U.S. federal single-filer style brackets for estimate-only usage.
            standardDeduction = 14_600
            brackets = [
                TaxBracket(upperBound: 11_600, rate: 0.10),
                TaxBracket(upperBound: 47_150, rate: 0.12),
                TaxBracket(upperBound: 100_525, rate: 0.22),
                TaxBracket(upperBound: 191_950, rate: 0.24),
                TaxBracket(upperBound: 243_725, rate: 0.32),
                TaxBracket(upperBound: 609_350, rate: 0.35),
                TaxBracket(upperBound: .greatestFiniteMagnitude, rate: 0.37)
            ]
        case .canada:
            // Simplified Canada federal brackets for estimate-only usage.
            standardDeduction = 15_705
            brackets = [
                TaxBracket(upperBound: 55_867, rate: 0.15),
                TaxBracket(upperBound: 111_733, rate: 0.205),
                TaxBracket(upperBound: 173_205, rate: 0.26),
                TaxBracket(upperBound: 246_752, rate: 0.29),
                TaxBracket(upperBound: .greatestFiniteMagnitude, rate: 0.33)
            ]
        }

        let taxable = max(request.annualIncome - max(request.deductions, standardDeduction), 0)
        let tax = Self.progressiveTax(income: taxable, brackets: brackets)
        let effective = request.annualIncome > 0 ? tax / request.annualIncome : 0

        return TaxEstimateResult(
            jurisdiction: request.jurisdiction,
            annualIncome: request.annualIncome,
            estimatedTax: tax,
            effectiveRate: effective,
            source: .offline,
            updatedAt: .now,
            details: [
                "taxable_income": taxable,
                "standard_deduction": standardDeduction,
                "provided_deductions": request.deductions
            ]
        )
    }

    private static func progressiveTax(income: Double, brackets: [TaxBracket]) -> Double {
        guard income > 0 else { return 0 }

        var remaining = income
        var lower = 0.0
        var tax = 0.0

        for bracket in brackets {
            let width = bracket.upperBound - lower
            let taxedAmount = min(remaining, width)
            if taxedAmount <= 0 { break }

            tax += taxedAmount * bracket.rate
            remaining -= taxedAmount
            lower = bracket.upperBound

            if remaining <= 0 { break }
        }

        return tax
    }
}

final class APINinjasTaxProvider: TaxProvider {
    private let apiKeyProvider: () -> String?
    private let session: URLSession

    init(apiKeyProvider: @escaping () -> String?, session: URLSession = .shared) {
        self.apiKeyProvider = apiKeyProvider
        self.session = session
    }

    func estimate(_ request: TaxEstimateRequest) async throws -> TaxEstimateResult {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw TaxProviderError.missingAPIKey
        }

        let country = request.jurisdiction == .us ? "US" : "CA"
        var components = URLComponents(string: "https://api.api-ninjas.com/v1/incometax")
        components?.queryItems = [
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "income", value: String(Int(request.annualIncome)))
        ]

        guard let url = components?.url else {
            throw TaxProviderError.invalidResponse
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TaxProviderError.invalidResponse
        }

        let payload = try JSONSerialization.jsonObject(with: data)
        let parsed = Self.parsePayload(payload)

        guard let estimatedTax = parsed.totalTax else {
            throw TaxProviderError.invalidResponse
        }

        let effective = request.annualIncome > 0 ? estimatedTax / request.annualIncome : 0

        return TaxEstimateResult(
            jurisdiction: request.jurisdiction,
            annualIncome: request.annualIncome,
            estimatedTax: estimatedTax,
            effectiveRate: effective,
            source: .apiNinjas,
            updatedAt: .now,
            details: parsed.details
        )
    }

    private static func parsePayload(_ payload: Any) -> (totalTax: Double?, details: [String: Double]) {
        let dictionary: [String: Any]?

        if let array = payload as? [[String: Any]] {
            dictionary = array.first
        } else {
            dictionary = payload as? [String: Any]
        }

        guard let dictionary else { return (nil, [:]) }

        var details: [String: Double] = [:]
        var totalTax: Double?

        for (key, value) in dictionary {
            let number: Double?
            if let value = value as? NSNumber {
                number = value.doubleValue
            } else if let value = value as? Double {
                number = value
            } else if let value = value as? Int {
                number = Double(value)
            } else if let value = value as? String, let parsed = Double(value) {
                number = parsed
            } else {
                number = nil
            }

            guard let number else { continue }
            details[key] = number

            if ["tax", "total_tax", "federal_tax_total"].contains(key.lowercased()) {
                totalTax = number
            }
        }

        if totalTax == nil {
            let taxLike = details
                .filter { $0.key.lowercased().contains("tax") && !$0.key.lowercased().contains("rate") }
                .map(\.value)
            if !taxLike.isEmpty {
                totalTax = taxLike.reduce(0, +)
            }
        }

        return (totalTax, details)
    }
}

final class HybridTaxProvider: TaxProvider {
    private let apiProvider: APINinjasTaxProvider
    private let offlineProvider: OfflineTaxProvider

    init(apiProvider: APINinjasTaxProvider, offlineProvider: OfflineTaxProvider = OfflineTaxProvider()) {
        self.apiProvider = apiProvider
        self.offlineProvider = offlineProvider
    }

    func estimate(_ request: TaxEstimateRequest) async throws -> TaxEstimateResult {
        do {
            return try await apiProvider.estimate(request)
        } catch {
            return try await offlineProvider.estimate(request)
        }
    }
}
