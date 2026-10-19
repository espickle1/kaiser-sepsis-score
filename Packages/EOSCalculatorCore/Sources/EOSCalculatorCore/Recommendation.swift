import Foundation

/// Risk thresholds (per 1000 live births) from Kuzniewicz et al. 2017 and the KP
/// EMR Implementation FAQ decision diagram.
public enum RiskThresholds {
    /// Risk at birth at or above this → vitals every 4 h for 24 h.
    public static let enhancedObservation: Double = 1.0
    /// Composite risk at or above this (and below `empiricAntibiotics`) → blood culture.
    public static let bloodCulture: Double = 1.0
    /// Composite risk at or above this → empiric antibiotics.
    public static let empiricAntibiotics: Double = 3.0
}

/// Colour-coding tier matching the KP diagram (green / yellow / red).
public enum RiskTier: String, Codable, Sendable {
    case low
    case moderate
    case high
}

public enum CareRecommendation: String, CaseIterable, Codable, Sendable {
    case noCultureNoAntibiotics
    case bloodCulture
    case empiricAntibiotics
    case stronglyConsiderEmpiricAntibiotics

    public var title: String {
        switch self {
        case .noCultureNoAntibiotics: return "No culture, no antibiotics"
        case .bloodCulture: return "Blood culture"
        case .empiricAntibiotics: return "Empiric antibiotics"
        case .stronglyConsiderEmpiricAntibiotics: return "Strongly consider starting empiric antibiotics"
        }
    }

    public var tier: RiskTier {
        switch self {
        case .noCultureNoAntibiotics: return .low
        case .bloodCulture: return .moderate
        case .empiricAntibiotics, .stronglyConsiderEmpiricAntibiotics: return .high
        }
    }
}

public enum VitalsRecommendation: String, CaseIterable, Codable, Sendable {
    case routine
    case every4hFor24h
    case perNICU

    public var title: String {
        switch self {
        case .routine: return "Routine vitals"
        case .every4hFor24h: return "Vitals every 4 hours for 24 hours"
        case .perNICU: return "Vitals per NICU"
        }
    }

    public var tier: RiskTier {
        switch self {
        case .routine: return .low
        case .every4hFor24h: return .moderate
        case .perNICU: return .high
        }
    }
}

public struct Recommendation: Hashable, Codable, Sendable {
    public let care: CareRecommendation
    public let vitals: VitalsRecommendation

    /// Overall tier for display: the more urgent of the two components.
    public var tier: RiskTier {
        care.tier == .high || vitals.tier == .high ? .high
            : (care.tier == .moderate || vitals.tier == .moderate ? .moderate : .low)
    }

    /// Vitals recommendation driven by the risk at birth alone (before the clinical exam).
    public static func vitalsAtBirth(riskAtBirthPer1000: Double) -> VitalsRecommendation {
        riskAtBirthPer1000 < RiskThresholds.enhancedObservation ? .routine : .every4hFor24h
    }

    /// KP decision diagram:
    /// - composite ≥ 3        → empiric antibiotics, vitals per NICU
    /// - clinical illness < 3 → strongly consider empiric antibiotics, vitals per NICU
    /// - 1 ≤ composite < 3    → blood culture, vitals q4h × 24 h
    /// - composite < 1        → no culture/antibiotics; vitals routine if risk at birth < 1, else q4h × 24 h
    public static func make(
        riskAtBirthPer1000: Double,
        compositeRiskPer1000: Double,
        presentation: ClinicalPresentation
    ) -> Recommendation {
        if compositeRiskPer1000 >= RiskThresholds.empiricAntibiotics {
            return Recommendation(care: .empiricAntibiotics, vitals: .perNICU)
        }
        if presentation == .clinicalIllness {
            return Recommendation(care: .stronglyConsiderEmpiricAntibiotics, vitals: .perNICU)
        }
        if compositeRiskPer1000 >= RiskThresholds.bloodCulture {
            return Recommendation(care: .bloodCulture, vitals: .every4hFor24h)
        }
        return Recommendation(
            care: .noCultureNoAntibiotics,
            vitals: vitalsAtBirth(riskAtBirthPer1000: riskAtBirthPer1000)
        )
    }
}
