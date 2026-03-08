import Foundation
import SwiftUI

enum PortfolioFormatters {
    static func currency(
        _ value: Double,
        code: CurrencyCode
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code.rawValue
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func percent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value * 100)%"
    }
}

enum PortfolioTheme {
    static let accent = Color(red: 0.04, green: 0.57, blue: 0.78)
    static let accentSecondary = Color(red: 0.10, green: 0.75, blue: 0.63)
    static let accentTertiary = Color(red: 0.17, green: 0.47, blue: 0.88)
    static let danger = Color(red: 0.87, green: 0.26, blue: 0.27)
    static let success = Color(red: 0.15, green: 0.67, blue: 0.42)

    static let canvasTop = Color(red: 0.96, green: 0.98, blue: 1.00)
    static let canvasBottom = Color(red: 0.91, green: 0.95, blue: 0.99)
}

struct PortfolioBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PortfolioTheme.canvasTop, PortfolioTheme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            PortfolioTheme.accent.opacity(0.22),
                            PortfolioTheme.accentSecondary.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 320, height: 320)
                .offset(x: 130, y: -210)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            PortfolioTheme.accentTertiary.opacity(0.16),
                            PortfolioTheme.accent.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 280, height: 280)
                .offset(x: -140, y: 290)
        }
        .ignoresSafeArea()
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.75),
                                        PortfolioTheme.accent.opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
            )
    }
}

struct ScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(PortfolioBackground())
    }
}

struct SectionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(PortfolioTheme.accent)

            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
        }
    }
}

struct MetricChip: View {
    let title: String
    let value: String
    let valueColor: Color

    init(title: String, value: String, valueColor: Color = .primary) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.70))
        )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func portfolioScreenBackground() -> some View {
        modifier(ScreenBackgroundModifier())
    }
}
