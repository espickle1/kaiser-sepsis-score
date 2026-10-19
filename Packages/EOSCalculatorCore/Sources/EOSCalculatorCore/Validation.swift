import Foundation

public struct ValidationIssue: Hashable, Codable, Sendable, Identifiable {
    public enum Severity: String, Codable, Sendable {
        /// Calculation is refused.
        case error
        /// Calculation proceeds; the user should see the caveat.
        case warning
    }

    public enum Field: String, Codable, Sendable {
        case gestationalAge
        case temperature
        case ruptureOfMembranes
        case model
    }

    public let severity: Severity
    public let field: Field
    public let message: String

    public init(_ severity: Severity, _ field: Field, _ message: String) {
        self.severity = severity
        self.field = field
        self.message = message
    }

    public var id: String { "\(severity.rawValue)|\(field.rawValue)|\(message)" }
}

public enum EOSCalculatorError: Error, Equatable {
    case invalidInputs([ValidationIssue])
}

public enum EOSInputValidator {
    // Ranges enforced by the KP web calculator's form validators.
    public static let gestationalWeeksRange = 34...43
    public static let gestationalDaysRange = 0...6
    public static let ruptureOfMembranesHoursRange = 0.0...240.0

    // The web form only constrains temperature format (one decimal). These bounds
    // reject obvious entry errors and flag unusual values without blocking them.
    public static let temperatureFahrenheitHardRange = 90.0...110.0
    public static let temperatureFahrenheitPlausibleRange = 96.0...105.0

    public static func validate(_ inputs: EOSInputs, model: ModelVersion) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        let ga = inputs.gestationalAge
        if !gestationalWeeksRange.contains(ga.weeks) {
            issues.append(.init(.error, .gestationalAge,
                                "Gestational age must be between \(gestationalWeeksRange.lowerBound) and \(gestationalWeeksRange.upperBound) weeks."))
        }
        if !gestationalDaysRange.contains(ga.days) {
            issues.append(.init(.error, .gestationalAge, "Gestational age days must be between 0 and 6."))
        }
        if gestationalWeeksRange.contains(ga.weeks), ga.weeks < model.derivationMinimumGestationalWeeks {
            issues.append(.init(.warning, .model,
                                "The \(model.title) model was derived from infants born at ≥ \(model.derivationMinimumGestationalWeeks) weeks. Estimates below that are extrapolations."))
        }

        let tempF = inputs.temperature.fahrenheit
        if !tempF.isFinite || !temperatureFahrenheitHardRange.contains(tempF) {
            issues.append(.init(.error, .temperature,
                                "Temperature must be between 90.0 and 110.0 °F (32.2–43.3 °C)."))
        } else if !temperatureFahrenheitPlausibleRange.contains(tempF) {
            issues.append(.init(.warning, .temperature,
                                "Temperature is outside the usual range (96.0–105.0 °F / 35.6–40.6 °C). Please double-check the entry."))
        }

        let rom = inputs.ruptureOfMembranesHours
        if !rom.isFinite || !ruptureOfMembranesHoursRange.contains(rom) {
            issues.append(.init(.error, .ruptureOfMembranes, "Rupture of membranes must be between 0 and 240 hours."))
        }

        return issues
    }

    public static func hasErrors(_ issues: [ValidationIssue]) -> Bool {
        issues.contains { $0.severity == .error }
    }
}
