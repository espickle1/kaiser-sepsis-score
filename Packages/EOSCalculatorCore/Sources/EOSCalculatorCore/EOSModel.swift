import Foundation

/// Logistic-regression coefficients for the EOS "risk at birth" model.
///
/// βx = intercept
///      + temperatureFahrenheit · T(°F)
///      + gestationalAgeWeeks · GA + gestationalAgeWeeksSquared · GA²
///      + ruptureOfMembranes · (ROM hours + 0.05)^0.2
///      + antibiotic term + GBS term
///
/// P(EOS at birth) = 1 / (1 + e^−βx)
public struct Coefficients: Hashable, Sendable {
    public let temperatureFahrenheit: Double
    public let gestationalAgeWeeks: Double
    public let gestationalAgeWeeksSquared: Double
    public let ruptureOfMembranes: Double
    /// "approptx1"/"Abx1": GBS-specific antibiotics ≥ 2 h before delivery, or broad-spectrum 2–3.9 h.
    public let antibioticsGBSOrBroad2To4Hours: Double
    /// "approptx2"/"Abx2": broad-spectrum antibiotics ≥ 4 h before delivery.
    public let antibioticsBroadOver4Hours: Double
    public let gbsPositive: Double
    public let gbsUnknown: Double

    public init(
        temperatureFahrenheit: Double,
        gestationalAgeWeeks: Double,
        gestationalAgeWeeksSquared: Double,
        ruptureOfMembranes: Double,
        antibioticsGBSOrBroad2To4Hours: Double,
        antibioticsBroadOver4Hours: Double,
        gbsPositive: Double,
        gbsUnknown: Double
    ) {
        self.temperatureFahrenheit = temperatureFahrenheit
        self.gestationalAgeWeeks = gestationalAgeWeeks
        self.gestationalAgeWeeksSquared = gestationalAgeWeeksSquared
        self.ruptureOfMembranes = ruptureOfMembranes
        self.antibioticsGBSOrBroad2To4Hours = antibioticsGBSOrBroad2To4Hours
        self.antibioticsBroadOver4Hours = antibioticsBroadOver4Hours
        self.gbsPositive = gbsPositive
        self.gbsUnknown = gbsUnknown
    }
}

/// Likelihood ratios applied to the risk at birth via Bayes' theorem to obtain the
/// posterior ("composite") risk for each clinical presentation.
public struct LikelihoodRatios: Hashable, Sendable {
    public let wellAppearing: Double
    public let equivocal: Double
    public let clinicalIllness: Double

    public init(wellAppearing: Double, equivocal: Double, clinicalIllness: Double) {
        self.wellAppearing = wellAppearing
        self.equivocal = equivocal
        self.clinicalIllness = clinicalIllness
    }

    public func ratio(for presentation: ClinicalPresentation) -> Double {
        switch presentation {
        case .wellAppearing: return wellAppearing
        case .equivocal: return equivocal
        case .clinicalIllness: return clinicalIllness
        }
    }
}

/// A fully specified model version: coefficients, likelihood ratios, and how the
/// intercept is adjusted for the local EOS incidence.
public struct EOSModel: Sendable {
    public let version: ModelVersion
    public let coefficients: Coefficients
    public let likelihoodRatios: LikelihoodRatios

    /// Fitted intercept at the derivation cohort's EOS rate.
    public let anchorIntercept: Double
    /// Derivation cohort EOS rate as a probability.
    public let anchorIncidence: Double
    /// Intercepts KP published verbatim for specific incidences (per 1000). Used in
    /// preference to the adjustment formula when available.
    public let publishedIntercepts: [Double: Double]

    /// Intercept for the selected baseline incidence.
    public func intercept(for incidence: Incidence) -> Double {
        if let published = publishedIntercepts[incidence.per1000] {
            return published
        }
        return Self.adjustedIntercept(
            anchor: anchorIntercept,
            anchorIncidence: anchorIncidence,
            targetIncidence: incidence.probability
        )
    }

    /// KP 2024 model-update FAQ:  β₁ = β₀ − ln[ ((1−τ)/τ) · (ȳ/(1−ȳ)) ]
    /// where ȳ is the derivation cohort rate and τ the target population rate.
    public static func adjustedIntercept(anchor beta0: Double, anchorIncidence ybar: Double, targetIncidence tau: Double) -> Double {
        beta0 - log(((1.0 - tau) / tau) * (ybar / (1.0 - ybar)))
    }

    public static func model(for version: ModelVersion) -> EOSModel {
        switch version {
        case .original2017: return .original2017
        case .updated2024: return .updated2024
        }
    }

    // MARK: Published models

    /// Source: KP EMR Implementation FAQ, "Raw equations for the calculator" (corrects the
    /// sign of the GBS-unknown term misprinted in the Puopolo 2011 supplement), and the
    /// KP spreadsheet "Worksheet in KP EOS Calculator Guidance for EMR Implementation 2021-0506 rev.xlsm".
    public static let original2017 = EOSModel(
        version: .original2017,
        coefficients: Coefficients(
            temperatureFahrenheit: 0.8680,
            gestationalAgeWeeks: -6.9325,
            gestationalAgeWeeksSquared: 0.0877,
            ruptureOfMembranes: 1.2256,
            antibioticsGBSOrBroad2To4Hours: -1.0488,
            antibioticsBroadOver4Hours: -1.1861,
            gbsPositive: 0.5771,
            gbsUnknown: 0.0427
        ),
        // The original calculator deliberately used the upper limit of each LR's 95% CI.
        likelihoodRatios: LikelihoodRatios(wellAppearing: 0.41, equivocal: 5.0, clinicalIllness: 21.2),
        anchorIntercept: 40.0528,
        anchorIncidence: 0.3 / 1000.0,
        publishedIntercepts: [
            0.3: 40.0528,
            0.4: 40.3415,
            0.5: 40.5656,
            0.6: 40.7489,
        ]
    )

    /// Source: KP "2024 EOS Calculator Model Update" FAQ and the spreadsheet
    /// "Updated Excel EOS Calc 2024 Model for Web.xlsm". The intercept 57.29929499 is the
    /// fit at the KPNC rate of 0.2763/1000; other incidences use the adjustment formula,
    /// which reproduces KP's published intercept table when rounded to one decimal.
    public static let updated2024 = EOSModel(
        version: .updated2024,
        coefficients: Coefficients(
            temperatureFahrenheit: 0.85194656,
            gestationalAgeWeeks: -7.72247124,
            gestationalAgeWeeksSquared: 0.09842383,
            ruptureOfMembranes: 0.86770862,
            antibioticsGBSOrBroad2To4Hours: -2.13142945,
            antibioticsBroadOver4Hours: -2.33985917,
            gbsPositive: 1.02265353,
            gbsUnknown: 1.13710111
        ),
        // The updated calculator uses LR point estimates.
        likelihoodRatios: LikelihoodRatios(wellAppearing: 0.36, equivocal: 3.65, clinicalIllness: 14.5),
        anchorIntercept: 57.29929499,
        anchorIncidence: 0.0002763,
        publishedIntercepts: [:]
    )
}
