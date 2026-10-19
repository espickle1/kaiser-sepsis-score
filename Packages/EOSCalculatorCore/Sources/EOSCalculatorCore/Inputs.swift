import Foundation

// MARK: - Maternal GBS status

public enum GBSStatus: String, CaseIterable, Codable, Sendable, Identifiable {
    case negative
    case positive
    case unknown

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .negative: return "Negative"
        case .positive: return "Positive"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Intrapartum antibiotics

/// Categories exactly as offered by the KP web calculator. Only three distinct
/// coefficients exist in the model: `broadSpectrum2To4Hours` and
/// `gbsSpecificOver2Hours` share one.
public enum IntrapartumAntibiotics: String, CaseIterable, Codable, Sendable, Identifiable {
    case broadSpectrumOver4Hours = "broadOver4h"
    case broadSpectrum2To4Hours = "broad2to4h"
    case gbsSpecificOver2Hours = "gbsSpecificOver2h"
    /// Named to avoid colliding with `Optional.none` in optional pickers.
    case noneOrLessThan2Hours = "none"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .broadSpectrumOver4Hours: return "Broad spectrum antibiotics > 4 hrs prior to birth"
        case .broadSpectrum2To4Hours: return "Broad spectrum antibiotics 2–3.9 hrs prior to birth"
        case .gbsSpecificOver2Hours: return "GBS specific antibiotics > 2 hrs prior to birth"
        case .noneOrLessThan2Hours: return "No antibiotics or any antibiotics < 2 hrs prior to birth"
        }
    }

    public var shortTitle: String {
        switch self {
        case .broadSpectrumOver4Hours: return "Broad > 4 h"
        case .broadSpectrum2To4Hours: return "Broad 2–3.9 h"
        case .gbsSpecificOver2Hours: return "GBS-specific > 2 h"
        case .noneOrLessThan2Hours: return "None / < 2 h"
        }
    }
}

// MARK: - Infant clinical presentation

public enum ClinicalPresentation: String, CaseIterable, Codable, Sendable, Identifiable {
    case wellAppearing
    case equivocal
    case clinicalIllness

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wellAppearing: return "Well Appearing"
        case .equivocal: return "Equivocal"
        case .clinicalIllness: return "Clinical Illness"
        }
    }
}

// MARK: - Temperature

public enum TemperatureUnit: String, CaseIterable, Codable, Sendable, Identifiable {
    case fahrenheit
    case celsius

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }
}

public struct Temperature: Hashable, Codable, Sendable {
    public var value: Double
    public var unit: TemperatureUnit

    public init(_ value: Double, unit: TemperatureUnit) {
        self.value = value
        self.unit = unit
    }

    public static func fahrenheit(_ value: Double) -> Temperature { Temperature(value, unit: .fahrenheit) }
    public static func celsius(_ value: Double) -> Temperature { Temperature(value, unit: .celsius) }

    /// The model is fit on °F. Conversion matches the KP spreadsheet (`C*9/5+32`), with no rounding.
    public var fahrenheit: Double {
        switch unit {
        case .fahrenheit: return value
        case .celsius: return value * 9.0 / 5.0 + 32.0
        }
    }

    public var celsius: Double {
        switch unit {
        case .celsius: return value
        case .fahrenheit: return (value - 32.0) * 5.0 / 9.0
        }
    }
}

// MARK: - Gestational age

public struct GestationalAge: Hashable, Codable, Sendable {
    public var weeks: Int
    public var days: Int

    public init(weeks: Int, days: Int) {
        self.weeks = weeks
        self.days = days
    }

    /// Decimal weeks (e.g. 40 3/7 → 40.428…), the form the model uses.
    public var totalWeeks: Double { Double(weeks) + Double(days) / 7.0 }

    public var formatted: String { "\(weeks) \(days)/7 weeks" }
}

// MARK: - Aggregate inputs

public struct EOSInputs: Hashable, Codable, Sendable {
    public var gestationalAge: GestationalAge
    /// Highest maternal antepartum/intrapartum temperature.
    public var temperature: Temperature
    /// Duration of rupture of membranes before delivery, in hours.
    public var ruptureOfMembranesHours: Double
    public var gbsStatus: GBSStatus
    public var antibiotics: IntrapartumAntibiotics
    /// Baseline EOS incidence in the population being served.
    public var incidence: Incidence

    public init(
        gestationalAge: GestationalAge,
        temperature: Temperature,
        ruptureOfMembranesHours: Double,
        gbsStatus: GBSStatus,
        antibiotics: IntrapartumAntibiotics,
        incidence: Incidence
    ) {
        self.gestationalAge = gestationalAge
        self.temperature = temperature
        self.ruptureOfMembranesHours = ruptureOfMembranesHours
        self.gbsStatus = gbsStatus
        self.antibiotics = antibiotics
        self.incidence = incidence
    }
}
