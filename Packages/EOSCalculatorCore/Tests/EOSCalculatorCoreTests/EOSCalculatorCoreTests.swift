import XCTest
@testable import EOSCalculatorCore

// MARK: - Helpers

private func assertClose(
    _ actual: Double, _ expected: Double, rel: Double = 1e-9,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath, line: UInt = #line
) {
    XCTAssertEqual(actual, expected, accuracy: max(1e-12, abs(expected) * rel), message(), file: file, line: line)
}

private func inputs(
    weeks: Int, days: Int, tempF: Double, rom: Double,
    gbs: GBSStatus, abx: IntrapartumAntibiotics, incidence: Double
) -> EOSInputs {
    EOSInputs(
        gestationalAge: GestationalAge(weeks: weeks, days: days),
        temperature: .fahrenheit(tempF),
        ruptureOfMembranesHours: rom,
        gbsStatus: gbs,
        antibiotics: abx,
        incidence: Incidence(per1000: incidence)
    )
}

// MARK: - Parity with KP's own spreadsheets (cached cell values)

final class SpreadsheetParityTests: XCTestCase {

    /// "Worksheet in KP EOS Calculator Guidance for EMR Implementation 2021-0506 rev.xlsm"
    /// Inputs: GA 40 6/7, 98.6 °F, ROM 8 h, GBS negative, broad-spectrum 2–3.9 h, intercept 40.7489.
    func testOriginal2017MatchesSpreadsheet() {
        let model = EOSModel.original2017
        let x = inputs(weeks: 40, days: 6, tempF: 98.6, rom: 8, gbs: .negative, abx: .broadSpectrum2To4Hours, incidence: 0.6)

        let bx = EOSCalculator.linearPredictor(model: model, intercept: 40.7489, inputs: x)
        assertClose(bx, -9.69911740019207)

        let prior = EOSCalculator.logistic(bx)
        assertClose(prior, 6.133384565922623e-05)
        assertClose(EOSCalculator.posterior(prior: prior, likelihoodRatio: 0.41) * 1000, 0.025147786742460484)
        assertClose(EOSCalculator.posterior(prior: prior, likelihoodRatio: 5.0) * 1000, 0.306594009937389)
        assertClose(EOSCalculator.posterior(prior: prior, likelihoodRatio: 21.2) * 1000, 1.2986685507791853)

        // The published 0.6/1000 intercept is exactly the spreadsheet's.
        assertClose(model.intercept(for: Incidence(per1000: 0.6)), 40.7489)
    }

    /// "Updated Excel EOS Calc 2024 Model for Web.xlsm"
    /// Inputs: GA 40 3/7, 99 °F, ROM 16 h, GBS negative, broad-spectrum 2–3.9 h, intercept 57.3.
    func testUpdated2024MatchesSpreadsheet() {
        let model = EOSModel.updated2024
        let x = inputs(weeks: 40, days: 3, tempF: 99.0, rom: 16, gbs: .negative, abx: .broadSpectrum2To4Hours, incidence: 0.3)

        let bx = EOSCalculator.linearPredictor(model: model, intercept: 57.3, inputs: x)
        assertClose(bx, -10.314751472775248)

        let prior = EOSCalculator.logistic(bx)
        assertClose(prior, 3.313950068804753e-05)
        assertClose(EOSCalculator.posterior(prior: prior, likelihoodRatio: 0.36) * 1000, 0.011930473284450786)
        assertClose(EOSCalculator.posterior(prior: prior, likelihoodRatio: 3.65) * 1000, 0.12094855584828663)
        assertClose(EOSCalculator.posterior(prior: prior, likelihoodRatio: 14.5) * 1000, 0.4803078782726455)
    }

    func testCelsiusConversionMatchesSpreadsheet() {
        // Spreadsheet: =(C*9/5)+32
        assertClose(Temperature.celsius(38.0).fahrenheit, 100.4)
        assertClose(Temperature.celsius(37.0).fahrenheit, 98.6)
        assertClose(Temperature.fahrenheit(98.6).celsius, 37.0)
    }
}

// MARK: - Intercept adjustment

final class InterceptTests: XCTestCase {

    /// KP 2024 model-update FAQ table of adjusted intercepts (rounded to one decimal).
    func testUpdated2024InterceptTableReproduces() {
        let table: [Double: Double] = [
            5.0: 60.2, 4.0: 60.0, 2.0: 59.3, 1.0: 58.6, 0.9: 58.5, 0.8: 58.4, 0.7: 58.2,
            0.6: 58.1, 0.5: 57.9, 0.4: 57.7, 0.3: 57.4, 0.2: 57.0, 0.1: 56.3, 0.05: 55.6,
        ]
        for (per1000, expected) in table {
            let got = EOSModel.updated2024.intercept(for: Incidence(per1000: per1000))
            XCTAssertEqual((got * 10).rounded() / 10, expected, "incidence \(per1000)/1000")
        }
    }

    /// The 2017 model uses published intercepts where available; the adjustment formula
    /// anchored at 0.3/1000 lands within 0.003 of each of them (largest gap 0.00265 at 0.6/1000).
    func testOriginal2017PublishedInterceptsAreUsed() {
        let m = EOSModel.original2017
        assertClose(m.intercept(for: Incidence(per1000: 0.3)), 40.0528)
        assertClose(m.intercept(for: Incidence(per1000: 0.4)), 40.3415)
        assertClose(m.intercept(for: Incidence(per1000: 0.5)), 40.5656)
        assertClose(m.intercept(for: Incidence(per1000: 0.6)), 40.7489)

        for (per1000, published) in m.publishedIntercepts {
            let derived = EOSModel.adjustedIntercept(anchor: m.anchorIntercept, anchorIncidence: m.anchorIncidence, targetIncidence: per1000 / 1000)
            XCTAssertLessThan(abs(derived - published), 0.005, "incidence \(per1000)/1000")
        }
    }

    func testHigherIncidenceGivesHigherRisk() throws {
        for version in ModelVersion.allCases {
            var previous = -Double.infinity
            for incidence in Incidence.options {
                let x = inputs(weeks: 39, days: 0, tempF: 99.0, rom: 12, gbs: .unknown, abx: .noneOrLessThan2Hours, incidence: incidence.per1000)
                let r = try EOSCalculator.calculate(x, model: version)
                XCTAssertGreaterThan(r.riskAtBirth, previous, "\(version) \(incidence.shortLabel)")
                previous = r.riskAtBirth
            }
        }
    }
}

// MARK: - Shared test vectors (generated by tools/reference_model.py)

final class TestVectorTests: XCTestCase {

    private struct VectorFile: Decodable { let cases: [Vector] }

    private struct Vector: Decodable {
        struct Expected: Decodable {
            struct Presentation: Decodable {
                let riskPer1000: Double
                let care: String
                let vitals: String
            }
            let intercept: Double
            let riskAtBirthPer1000: Double
            let vitalsAtBirth: String
            let presentations: [String: Presentation]
        }
        let label: String
        let model: String
        let incidencePer1000: Double
        let gestationalAgeWeeks: Int
        let gestationalAgeDays: Int
        let temperatureF: Double
        let romHours: Double
        let gbs: String
        let antibiotics: String
        let expected: Expected
    }

    private func loadVectors() throws -> [Vector] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "test_vectors", withExtension: "json"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VectorFile.self, from: data).cases
    }

    func testAllVectors() throws {
        let vectors = try loadVectors()
        XCTAssertGreaterThanOrEqual(vectors.count, 20)

        for v in vectors {
            let version = try XCTUnwrap(ModelVersion(rawValue: v.model), v.label)
            let gbs = try XCTUnwrap(GBSStatus(rawValue: v.gbs), v.label)
            let abx = try XCTUnwrap(IntrapartumAntibiotics(rawValue: v.antibiotics), v.label)

            let x = inputs(weeks: v.gestationalAgeWeeks, days: v.gestationalAgeDays, tempF: v.temperatureF,
                           rom: v.romHours, gbs: gbs, abx: abx, incidence: v.incidencePer1000)
            let r = try EOSCalculator.calculate(x, model: version)

            assertClose(r.intercept, v.expected.intercept, v.label)
            assertClose(r.riskAtBirthPer1000, v.expected.riskAtBirthPer1000, v.label)
            XCTAssertEqual(r.vitalsAtBirth.rawValue, v.expected.vitalsAtBirth, v.label)

            for (key, expected) in v.expected.presentations {
                let presentation = try XCTUnwrap(ClinicalPresentation(rawValue: key), v.label)
                let got = r.result(for: presentation)
                assertClose(got.riskPer1000, expected.riskPer1000, "\(v.label) / \(key)")
                XCTAssertEqual(got.recommendation.care.rawValue, expected.care, "\(v.label) / \(key)")
                XCTAssertEqual(got.recommendation.vitals.rawValue, expected.vitals, "\(v.label) / \(key)")
            }
        }
    }
}

// MARK: - Recommendation logic

final class RecommendationTests: XCTestCase {

    func testVitalsAtBirthThreshold() {
        XCTAssertEqual(Recommendation.vitalsAtBirth(riskAtBirthPer1000: 0.999), .routine)
        XCTAssertEqual(Recommendation.vitalsAtBirth(riskAtBirthPer1000: 1.0), .every4hFor24h)
    }

    func testLowCompositeRiskFollowsRiskAtBirthForVitals() {
        let low = Recommendation.make(riskAtBirthPer1000: 0.5, compositeRiskPer1000: 0.2, presentation: .wellAppearing)
        XCTAssertEqual(low, Recommendation(care: .noCultureNoAntibiotics, vitals: .routine))

        let elevatedPrior = Recommendation.make(riskAtBirthPer1000: 1.5, compositeRiskPer1000: 0.6, presentation: .wellAppearing)
        XCTAssertEqual(elevatedPrior, Recommendation(care: .noCultureNoAntibiotics, vitals: .every4hFor24h))
    }

    func testBloodCultureBand() {
        let r = Recommendation.make(riskAtBirthPer1000: 0.4, compositeRiskPer1000: 1.0, presentation: .equivocal)
        XCTAssertEqual(r, Recommendation(care: .bloodCulture, vitals: .every4hFor24h))

        let justBelowAntibiotics = Recommendation.make(riskAtBirthPer1000: 0.4, compositeRiskPer1000: 2.999, presentation: .wellAppearing)
        XCTAssertEqual(justBelowAntibiotics.care, .bloodCulture)
    }

    func testEmpiricAntibioticsAtOrAboveThree() {
        for presentation in ClinicalPresentation.allCases {
            let r = Recommendation.make(riskAtBirthPer1000: 0.2, compositeRiskPer1000: 3.0, presentation: presentation)
            XCTAssertEqual(r, Recommendation(care: .empiricAntibiotics, vitals: .perNICU), "\(presentation)")
        }
    }

    func testClinicalIllnessBelowThreeStronglyConsiders() {
        for composite in [0.1, 0.99, 1.0, 2.99] {
            let r = Recommendation.make(riskAtBirthPer1000: 0.05, compositeRiskPer1000: composite, presentation: .clinicalIllness)
            XCTAssertEqual(r, Recommendation(care: .stronglyConsiderEmpiricAntibiotics, vitals: .perNICU), "composite \(composite)")
        }
    }

    func testTiers() {
        XCTAssertEqual(Recommendation(care: .noCultureNoAntibiotics, vitals: .routine).tier, .low)
        XCTAssertEqual(Recommendation(care: .noCultureNoAntibiotics, vitals: .every4hFor24h).tier, .moderate)
        XCTAssertEqual(Recommendation(care: .bloodCulture, vitals: .every4hFor24h).tier, .moderate)
        XCTAssertEqual(Recommendation(care: .empiricAntibiotics, vitals: .perNICU).tier, .high)
    }
}

// MARK: - Validation

final class ValidationTests: XCTestCase {

    func testValidInputsHaveNoIssues() {
        let x = inputs(weeks: 39, days: 2, tempF: 98.6, rom: 6, gbs: .negative, abx: .noneOrLessThan2Hours, incidence: 0.5)
        XCTAssertTrue(EOSInputValidator.validate(x, model: .original2017).isEmpty)
        XCTAssertTrue(EOSInputValidator.validate(x, model: .updated2024).isEmpty)
    }

    func testGestationalAgeBounds() {
        let tooLow = inputs(weeks: 33, days: 6, tempF: 98.6, rom: 6, gbs: .negative, abx: .noneOrLessThan2Hours, incidence: 0.5)
        XCTAssertTrue(EOSInputValidator.hasErrors(EOSInputValidator.validate(tooLow, model: .original2017)))
        XCTAssertThrowsError(try EOSCalculator.calculate(tooLow, model: .original2017))

        let tooHigh = inputs(weeks: 44, days: 0, tempF: 98.6, rom: 6, gbs: .negative, abx: .noneOrLessThan2Hours, incidence: 0.5)
        XCTAssertTrue(EOSInputValidator.hasErrors(EOSInputValidator.validate(tooHigh, model: .original2017)))

        let badDays = inputs(weeks: 40, days: 7, tempF: 98.6, rom: 6, gbs: .negative, abx: .noneOrLessThan2Hours, incidence: 0.5)
        XCTAssertTrue(EOSInputValidator.hasErrors(EOSInputValidator.validate(badDays, model: .original2017)))
    }

    func testThirtyFourWeeksWarnsOnlyForUpdatedModel() throws {
        let x = inputs(weeks: 34, days: 0, tempF: 98.6, rom: 6, gbs: .negative, abx: .noneOrLessThan2Hours, incidence: 0.5)

        let original = EOSInputValidator.validate(x, model: .original2017)
        XCTAssertTrue(original.isEmpty)

        let updated = EOSInputValidator.validate(x, model: .updated2024)
        XCTAssertFalse(EOSInputValidator.hasErrors(updated))
        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(updated.first?.severity, .warning)
        XCTAssertEqual(updated.first?.field, .model)

        // Warnings are surfaced on the result, not thrown.
        let r = try EOSCalculator.calculate(x, model: .updated2024)
        XCTAssertEqual(r.warnings.count, 1)
    }

    func testTemperatureBounds() {
        let impossible = inputs(weeks: 40, days: 0, tempF: 80, rom: 6, gbs: .negative, abx: .noneOrLessThan2Hours, incidence: 0.5)
        XCTAssertTrue(EOSInputValidator.hasErrors(EOSInputValidator.validate(impossible, model: .original2017)))

        let unusual = inputs(weeks: 40, days: 0, tempF: 95.5, rom: 6, gbs: .negative, abx: .noneOrLessThan2Hours, incidence: 0.5)
        let issues = EOSInputValidator.validate(unusual, model: .original2017)
        XCTAssertFalse(EOSInputValidator.hasErrors(issues))
        XCTAssertEqual(issues.first?.severity, .warning)
        XCTAssertEqual(issues.first?.field, .temperature)

        let celsiusOK = EOSInputs(
            gestationalAge: GestationalAge(weeks: 40, days: 0), temperature: .celsius(38.2),
            ruptureOfMembranesHours: 6, gbsStatus: .negative, antibiotics: .noneOrLessThan2Hours, incidence: .kpnc
        )
        XCTAssertTrue(EOSInputValidator.validate(celsiusOK, model: .original2017).isEmpty)
    }

    func testRuptureOfMembranesBounds() {
        let negative = inputs(weeks: 40, days: 0, tempF: 98.6, rom: -1, gbs: .negative, abx: .noneOrLessThan2Hours, incidence: 0.5)
        XCTAssertTrue(EOSInputValidator.hasErrors(EOSInputValidator.validate(negative, model: .original2017)))

        let tooLong = inputs(weeks: 40, days: 0, tempF: 98.6, rom: 240.1, gbs: .negative, abx: .noneOrLessThan2Hours, incidence: 0.5)
        XCTAssertTrue(EOSInputValidator.hasErrors(EOSInputValidator.validate(tooLong, model: .original2017)))

        let max = inputs(weeks: 40, days: 0, tempF: 98.6, rom: 240, gbs: .negative, abx: .noneOrLessThan2Hours, incidence: 0.5)
        XCTAssertFalse(EOSInputValidator.hasErrors(EOSInputValidator.validate(max, model: .original2017)))
    }
}

// MARK: - Misc

final class ModelMetadataTests: XCTestCase {

    func testIncidenceLabels() {
        XCTAssertEqual(Incidence(per1000: 0.3).label, "0.3/1000 live births (KPNC incidence)")
        XCTAssertEqual(Incidence(per1000: 0.5).label, "0.5/1000 live births (CDC national incidence)")
        XCTAssertEqual(Incidence(per1000: 1.0).label, "1/1000 live births")
        XCTAssertEqual(Incidence(per1000: 4.0).shortLabel, "4/1000")
        XCTAssertEqual(Incidence.options.count, 12)
    }

    func testGestationalAgeDecimalWeeks() {
        assertClose(GestationalAge(weeks: 40, days: 3).totalWeeks, 40.42857142857143)
        XCTAssertEqual(GestationalAge(weeks: 37, days: 0).formatted, "37 0/7 weeks")
    }

    func testResultIsStableAndCodable() throws {
        let x = inputs(weeks: 38, days: 4, tempF: 100.8, rom: 20, gbs: .positive, abx: .gbsSpecificOver2Hours, incidence: 0.5)
        let a = try EOSCalculator.calculate(x, model: .updated2024)
        let b = try EOSCalculator.calculate(x, model: .updated2024)
        XCTAssertEqual(a, b)

        let data = try JSONEncoder().encode(a)
        let decoded = try JSONDecoder().decode(EOSRiskResult.self, from: data)
        XCTAssertEqual(decoded, a)
    }
}
