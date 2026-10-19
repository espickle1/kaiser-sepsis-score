import Foundation

/// Posterior risk and recommendation for one clinical presentation.
public struct PresentationResult: Hashable, Codable, Sendable, Identifiable {
    public let presentation: ClinicalPresentation
    public let likelihoodRatio: Double
    /// Posterior probability of EOS.
    public let risk: Double
    public let recommendation: Recommendation

    public var id: ClinicalPresentation { presentation }
    public var riskPer1000: Double { risk * 1000.0 }
}

/// Full output of one calculation.
public struct EOSRiskResult: Hashable, Codable, Sendable {
    public let modelVersion: ModelVersion
    public let inputs: EOSInputs
    public let intercept: Double
    public let linearPredictor: Double
    /// Prior probability of EOS from maternal factors alone.
    public let riskAtBirth: Double
    public let vitalsAtBirth: VitalsRecommendation
    /// Ordered: well appearing, equivocal, clinical illness.
    public let presentations: [PresentationResult]
    public let warnings: [ValidationIssue]

    public var riskAtBirthPer1000: Double { riskAtBirth * 1000.0 }

    public func result(for presentation: ClinicalPresentation) -> PresentationResult {
        // All three are always present.
        presentations.first { $0.presentation == presentation }!
    }
}

public enum EOSCalculator {
    /// Calculates EOS risk at birth and for each clinical presentation.
    /// - Throws: `EOSCalculatorError.invalidInputs` when any validation error is present.
    public static func calculate(_ inputs: EOSInputs, model version: ModelVersion) throws -> EOSRiskResult {
        let issues = EOSInputValidator.validate(inputs, model: version)
        if EOSInputValidator.hasErrors(issues) {
            throw EOSCalculatorError.invalidInputs(issues)
        }

        let model = EOSModel.model(for: version)
        let intercept = model.intercept(for: inputs.incidence)
        let bx = linearPredictor(model: model, intercept: intercept, inputs: inputs)
        let prior = logistic(bx)
        let priorPer1000 = prior * 1000.0

        let presentations = ClinicalPresentation.allCases.map { presentation -> PresentationResult in
            let lr = model.likelihoodRatios.ratio(for: presentation)
            let post = posterior(prior: prior, likelihoodRatio: lr)
            let rec = Recommendation.make(
                riskAtBirthPer1000: priorPer1000,
                compositeRiskPer1000: post * 1000.0,
                presentation: presentation
            )
            return PresentationResult(presentation: presentation, likelihoodRatio: lr, risk: post, recommendation: rec)
        }

        return EOSRiskResult(
            modelVersion: version,
            inputs: inputs,
            intercept: intercept,
            linearPredictor: bx,
            riskAtBirth: prior,
            vitalsAtBirth: Recommendation.vitalsAtBirth(riskAtBirthPer1000: priorPer1000),
            presentations: presentations,
            warnings: issues.filter { $0.severity == .warning }
        )
    }

    // MARK: - Building blocks (internal for testing against KP spreadsheet values)

    /// βx, exactly as in the KP spreadsheets' "Sum of Betas".
    static func linearPredictor(model: EOSModel, intercept: Double, inputs: EOSInputs) -> Double {
        let c = model.coefficients
        let ga = inputs.gestationalAge.totalWeeks
        var bx = intercept
        bx += c.temperatureFahrenheit * inputs.temperature.fahrenheit
        bx += c.gestationalAgeWeeks * ga
        bx += c.gestationalAgeWeeksSquared * ga * ga
        bx += c.ruptureOfMembranes * pow(inputs.ruptureOfMembranesHours + 0.05, 0.2)

        switch inputs.antibiotics {
        case .broadSpectrumOver4Hours:
            bx += c.antibioticsBroadOver4Hours
        case .broadSpectrum2To4Hours, .gbsSpecificOver2Hours:
            bx += c.antibioticsGBSOrBroad2To4Hours
        case .noneOrLessThan2Hours:
            break
        }

        switch inputs.gbsStatus {
        case .positive:
            bx += c.gbsPositive
        case .unknown:
            bx += c.gbsUnknown
        case .negative:
            break
        }
        return bx
    }

    static func logistic(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-x))
    }

    /// Bayes' theorem on odds: posterior odds = prior odds × LR.
    static func posterior(prior: Double, likelihoodRatio: Double) -> Double {
        let priorOdds = prior / (1.0 - prior)
        let postOdds = priorOdds * likelihoodRatio
        return postOdds / (1.0 + postOdds)
    }
}
