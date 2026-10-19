import Foundation

/// Which published version of the Kaiser Permanente neonatal early-onset sepsis
/// (EOS) risk model to use. Both are offered side by side on the KP web calculator.
public enum ModelVersion: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Puopolo et al. 2011 / Escobar et al. 2014 / Kuzniewicz et al. 2017.
    /// Derived from 1993–2007 births, before universal antepartum GBS screening.
    case original2017

    /// Kuzniewicz et al. 2024. Derived from 2010–2020 births with universal GBS
    /// screening and current ACOG definitions of adequate GBS prophylaxis.
    case updated2024

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .original2017: return "Original (2017)"
        case .updated2024: return "Updated (2024)"
        }
    }

    public var subtitle: String {
        switch self {
        case .original2017: return "No universal GBS screening"
        case .updated2024: return "Universal GBS screening"
        }
    }

    /// Lowest gestational age (completed weeks) in the derivation cohort.
    /// The web calculator accepts 34 weeks for both versions; the 2024 cohort
    /// excluded 34-week infants, so we warn (not block) below 35 weeks.
    public var derivationMinimumGestationalWeeks: Int {
        switch self {
        case .original2017: return 34
        case .updated2024: return 35
        }
    }
}
