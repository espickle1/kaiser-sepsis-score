import Foundation
import Observation
import EOSCalculatorCore

/// Holds the form state for one calculation.
///
/// Only *settings* (model version, incidence, temperature unit) are persisted.
/// Patient-specific entries are kept in memory and cleared with `reset()`; the app
/// never writes them to disk or sends them anywhere.
@MainActor
@Observable
final class CalculatorViewModel {

    private enum Keys {
        static let modelVersion = "settings.modelVersion"
        static let incidencePer1000 = "settings.incidencePer1000"
        static let temperatureUnit = "settings.temperatureUnit"
    }

    // MARK: Persisted preferences

    var modelVersion: ModelVersion {
        didSet { defaults.set(modelVersion.rawValue, forKey: Keys.modelVersion) }
    }

    var incidence: Incidence {
        didSet { defaults.set(incidence.per1000, forKey: Keys.incidencePer1000) }
    }

    var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit) }
    }

    // MARK: Per-patient entries (never persisted)

    var gestationalWeeks: Int = 40
    var gestationalDays: Int = 0
    var temperatureText: String = ""
    var ruptureOfMembranesText: String = ""
    var gbsStatus: GBSStatus?
    var antibiotics: IntrapartumAntibiotics?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.modelVersion = defaults.string(forKey: Keys.modelVersion)
            .flatMap(ModelVersion.init(rawValue:)) ?? .updated2024
        let storedIncidence = defaults.object(forKey: Keys.incidencePer1000) as? Double
        self.incidence = Incidence.options.first { $0.per1000 == storedIncidence } ?? .kpnc
        self.temperatureUnit = defaults.string(forKey: Keys.temperatureUnit)
            .flatMap(TemperatureUnit.init(rawValue:)) ?? .fahrenheit
    }

    // MARK: Derived state

    var temperature: Temperature? {
        Self.parseNumber(temperatureText).map { Temperature($0, unit: temperatureUnit) }
    }

    var ruptureOfMembranesHours: Double? {
        Self.parseNumber(ruptureOfMembranesText)
    }

    var inputs: EOSInputs? {
        guard let temperature,
              let rom = ruptureOfMembranesHours,
              let gbsStatus,
              let antibiotics
        else { return nil }

        return EOSInputs(
            gestationalAge: GestationalAge(weeks: gestationalWeeks, days: gestationalDays),
            temperature: temperature,
            ruptureOfMembranesHours: rom,
            gbsStatus: gbsStatus,
            antibiotics: antibiotics,
            incidence: incidence
        )
    }

    /// Human-readable list of what still needs to be entered before a result can be shown.
    var missingFields: [String] {
        var missing: [String] = []
        if temperature == nil {
            missing.append(Self.isBlank(temperatureText) ? "Maternal temperature" : "Maternal temperature (not a valid number)")
        }
        if ruptureOfMembranesHours == nil {
            missing.append(Self.isBlank(ruptureOfMembranesText) ? "ROM hours" : "ROM hours (not a valid number)")
        }
        if gbsStatus == nil { missing.append("Maternal GBS status") }
        if antibiotics == nil { missing.append("Intrapartum antibiotics") }
        return missing
    }

    var issues: [ValidationIssue] {
        guard let inputs else { return [] }
        return EOSInputValidator.validate(inputs, model: modelVersion)
    }

    var errors: [ValidationIssue] { issues.filter { $0.severity == .error } }

    var result: EOSRiskResult? {
        guard let inputs else { return nil }
        return try? EOSCalculator.calculate(inputs, model: modelVersion)
    }

    // MARK: Actions

    func reset() {
        gestationalWeeks = 40
        gestationalDays = 0
        temperatureText = ""
        ruptureOfMembranesText = ""
        gbsStatus = nil
        antibiotics = nil
    }

    // MARK: Parsing

    /// Accepts "." or "," as the decimal separator; rejects empty, non-numeric and non-finite
    /// input, and input mixing both separators (so "1,000" is not silently read as 1.0).
    static func parseNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !(trimmed.contains(",") && trimmed.contains(".")),
              trimmed.filter({ $0 == "," }).count <= 1
        else { return nil }
        let cleaned = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
