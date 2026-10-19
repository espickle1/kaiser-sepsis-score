import SwiftUI
import EOSCalculatorCore

/// Live results for the current form state: prompts for missing fields, shows
/// validation errors, or shows risk at birth plus the three clinical presentations.
struct ResultsSection: View {
    let model: CalculatorViewModel

    var body: some View {
        Section {
            if let result = model.result {
                RiskAtBirthRow(result: result)
                ForEach(result.presentations) { presentation in
                    PresentationRow(result: presentation)
                }
                ForEach(result.warnings) { issue in
                    IssueRow(issue: issue)
                }
            } else if !model.errors.isEmpty {
                ForEach(model.errors) { issue in
                    IssueRow(issue: issue)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enter the remaining fields to see the risk estimate:")
                        .foregroundStyle(.secondary)
                    ForEach(model.missingFields, id: \.self) { field in
                        Label(field, systemImage: "circle.dotted")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("EOS risk per 1000 live births")
        }
    }
}

// MARK: - Rows

struct RiskAtBirthRow: View {
    let result: EOSRiskResult

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("EOS risk at birth")
                    .font(.headline)
                Label(result.vitalsAtBirth.title, systemImage: result.vitalsAtBirth.tier.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(RiskFormatter.string(result.riskAtBirthPer1000))
                .font(.title2.weight(.semibold).monospacedDigit())
        }
        .padding(.vertical, 4)
        .listRowBackground(result.vitalsAtBirth.tier.color.opacity(0.18))
        .accessibilityElement(children: .combine)
    }
}

struct PresentationRow: View {
    let result: PresentationResult

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.presentation.title)
                    .font(.headline)
                Label(result.recommendation.care.title, systemImage: result.recommendation.tier.symbolName)
                    .font(.subheadline)
                Text(result.recommendation.vitals.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(RiskFormatter.string(result.riskPer1000))
                .font(.title2.weight(.semibold).monospacedDigit())
        }
        .padding(.vertical, 4)
        .listRowBackground(result.recommendation.tier.color.opacity(0.18))
        .accessibilityElement(children: .combine)
    }
}

struct IssueRow: View {
    let issue: ValidationIssue

    var body: some View {
        Label {
            Text(issue.message)
        } icon: {
            Image(systemName: issue.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(issue.severity == .error ? .red : .orange)
        }
        .font(.callout)
    }
}

// MARK: - Presentation helpers

enum RiskFormatter {
    /// Two decimals, matching the KP web calculator's display.
    static func string(_ per1000: Double) -> String {
        per1000.formatted(.number.precision(.fractionLength(2)))
    }
}

extension RiskTier {
    /// Green / yellow / red, as in the KP decision diagram. Always paired with text or a symbol.
    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .red
        }
    }

    var symbolName: String {
        switch self {
        case .low: return "checkmark.circle"
        case .moderate: return "exclamationmark.triangle"
        case .high: return "exclamationmark.octagon"
        }
    }
}
