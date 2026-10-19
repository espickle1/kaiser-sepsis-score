"""
Reference implementation of the Kaiser Permanente neonatal early-onset sepsis
(EOS) risk models, used to (a) cross-check the Swift implementation and
(b) generate the shared test vectors in
Packages/EOSCalculatorCore/Tests/EOSCalculatorCoreTests/Resources/test_vectors.json.

Sources (see docs/MODEL.md for details):
  * 2017 model coefficients: KP EMR Implementation FAQ, "Raw equations for the
    calculator" (corrects the sign error in the Puopolo 2011 supplement).
  * 2024 model coefficients + intercept adjustment: KP "2024 EOS Calculator
    Model Update" FAQ.
  * Bayes step and likelihood ratios: KP spreadsheets
    "Worksheet in KP EOS Calculator Guidance for EMR Implementation 2021-0506 rev.xlsm"
    and "Updated Excel EOS Calc 2024 Model for Web.xlsm".

Run:  python tools/reference_model.py            (self-check against spreadsheet values)
      python tools/reference_model.py --write    (also regenerate test_vectors.json)
"""
from __future__ import annotations

import json
import math
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

# --------------------------------------------------------------------------- #
# Model definitions
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class Coefficients:
    temperature_f: float
    gestational_age: float
    gestational_age_squared: float
    rom: float
    abx_gbs_or_broad_2_to_4h: float   # "approptx1" / "Abx1"
    abx_broad_over_4h: float          # "approptx2" / "Abx2"
    gbs_positive: float
    gbs_unknown: float


@dataclass(frozen=True)
class LikelihoodRatios:
    well_appearing: float
    equivocal: float
    clinical_illness: float


@dataclass(frozen=True)
class Model:
    name: str
    coefficients: Coefficients
    likelihood_ratios: LikelihoodRatios
    # Intercept anchor: fitted intercept at the derivation cohort's EOS rate.
    anchor_intercept: float
    anchor_incidence: float  # as a probability (cases / live birth)
    # Explicitly published intercepts for selected incidences (per 1000), used
    # verbatim when available instead of the adjustment formula.
    published_intercepts: dict[float, float]

    def intercept(self, incidence_per_1000: float) -> float:
        if incidence_per_1000 in self.published_intercepts:
            return self.published_intercepts[incidence_per_1000]
        return adjusted_intercept(
            self.anchor_intercept, self.anchor_incidence, incidence_per_1000 / 1000.0
        )


def adjusted_intercept(beta0: float, ybar: float, tau: float) -> float:
    """KP 2024 FAQ: β1 = β0 − ln[((1−τ)/τ) · (ȳ/(1−ȳ))]."""
    return beta0 - math.log(((1.0 - tau) / tau) * (ybar / (1.0 - ybar)))


MODEL_2017 = Model(
    name="original2017",
    coefficients=Coefficients(
        temperature_f=0.8680,
        gestational_age=-6.9325,
        gestational_age_squared=0.0877,
        rom=1.2256,
        abx_gbs_or_broad_2_to_4h=-1.0488,
        abx_broad_over_4h=-1.1861,
        gbs_positive=0.5771,
        gbs_unknown=0.0427,
    ),
    # Original calculator used the upper limit of the 95% CI of each LR.
    likelihood_ratios=LikelihoodRatios(well_appearing=0.41, equivocal=5.0, clinical_illness=21.2),
    anchor_intercept=40.0528,
    anchor_incidence=0.3 / 1000.0,
    published_intercepts={0.3: 40.0528, 0.4: 40.3415, 0.5: 40.5656, 0.6: 40.7489},
)

MODEL_2024 = Model(
    name="updated2024",
    coefficients=Coefficients(
        temperature_f=0.85194656,
        gestational_age=-7.72247124,
        gestational_age_squared=0.09842383,
        rom=0.86770862,
        abx_gbs_or_broad_2_to_4h=-2.13142945,
        abx_broad_over_4h=-2.33985917,
        gbs_positive=1.02265353,
        gbs_unknown=1.13710111,
    ),
    # Updated calculator uses LR point estimates.
    likelihood_ratios=LikelihoodRatios(well_appearing=0.36, equivocal=3.65, clinical_illness=14.5),
    anchor_intercept=57.29929499,
    anchor_incidence=0.0002763,  # KPNC rate, 0.2763 / 1000
    published_intercepts={},
)

MODELS = {m.name: m for m in (MODEL_2017, MODEL_2024)}

# Incidence options offered by the web calculator (per 1000 live births).
INCIDENCE_OPTIONS = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 2.0, 4.0]

GBS = ("negative", "positive", "unknown")
ABX = ("broadOver4h", "broad2to4h", "gbsSpecificOver2h", "none")
PRESENTATION = ("wellAppearing", "equivocal", "clinicalIllness")


# --------------------------------------------------------------------------- #
# Calculation
# --------------------------------------------------------------------------- #


def celsius_to_fahrenheit(c: float) -> float:
    return c * 9.0 / 5.0 + 32.0


def linear_predictor(model: Model, intercept: float, ga_weeks: float, temp_f: float,
                     rom_hours: float, gbs: str, abx: str) -> float:
    c = model.coefficients
    bx = intercept
    bx += c.temperature_f * temp_f
    bx += c.gestational_age * ga_weeks
    bx += c.gestational_age_squared * ga_weeks ** 2
    bx += c.rom * (rom_hours + 0.05) ** 0.2
    if abx in ("broad2to4h", "gbsSpecificOver2h"):
        bx += c.abx_gbs_or_broad_2_to_4h
    elif abx == "broadOver4h":
        bx += c.abx_broad_over_4h
    if gbs == "positive":
        bx += c.gbs_positive
    elif gbs == "unknown":
        bx += c.gbs_unknown
    return bx


def risk_at_birth(model: Model, incidence_per_1000: float, ga_weeks: float, temp_f: float,
                  rom_hours: float, gbs: str, abx: str) -> float:
    bx = linear_predictor(model, model.intercept(incidence_per_1000), ga_weeks, temp_f, rom_hours, gbs, abx)
    return 1.0 / (1.0 + math.exp(-bx))


def posterior(prior: float, lr: float) -> float:
    odds = prior / (1.0 - prior)
    post_odds = odds * lr
    return post_odds / (1.0 + post_odds)


def posterior_for(model: Model, prior: float, presentation: str) -> float:
    lr = getattr(model.likelihood_ratios, {
        "wellAppearing": "well_appearing",
        "equivocal": "equivocal",
        "clinicalIllness": "clinical_illness",
    }[presentation])
    return posterior(prior, lr)


# --------------------------------------------------------------------------- #
# Recommendations (KP EMR FAQ decision diagram, Kuzniewicz 2017)
# --------------------------------------------------------------------------- #


def vitals_at_birth(risk_at_birth_per_1000: float) -> str:
    return "routine" if risk_at_birth_per_1000 < 1.0 else "every4hFor24h"


def recommendation(risk_birth_per_1000: float, composite_per_1000: float, presentation: str) -> dict:
    if composite_per_1000 >= 3.0:
        return {"care": "empiricAntibiotics", "vitals": "perNICU"}
    if presentation == "clinicalIllness":
        return {"care": "stronglyConsiderEmpiricAntibiotics", "vitals": "perNICU"}
    if composite_per_1000 >= 1.0:
        return {"care": "bloodCulture", "vitals": "every4hFor24h"}
    return {"care": "noCultureNoAntibiotics", "vitals": vitals_at_birth(risk_birth_per_1000)}


# --------------------------------------------------------------------------- #
# Self-check against KP spreadsheet cached values
# --------------------------------------------------------------------------- #


def approx(a: float, b: float, rel: float = 1e-9) -> bool:
    return math.isclose(a, b, rel_tol=rel, abs_tol=1e-12)


def self_check() -> None:
    # 2017 spreadsheet example: GA 40 6/7, 98.6F, ROM 8h, GBS neg, broad 2-3.9h, intercept 40.7489 (0.6/1000)
    m = MODEL_2017
    bx = linear_predictor(m, 40.7489, 40 + 6 / 7, 98.6, 8, "negative", "broad2to4h")
    assert approx(bx, -9.69911740019207), bx
    p = 1 / (1 + math.exp(-bx))
    assert approx(p, 6.133384565922623e-05), p
    assert approx(posterior(p, 0.41) * 1000, 0.025147786742460484)
    assert approx(posterior(p, 5.0) * 1000, 0.306594009937389)
    assert approx(posterior(p, 21.2) * 1000, 1.2986685507791853)

    # 2024 spreadsheet example: GA 40 3/7, 99F, ROM 16h, GBS neg, broad 2-3.9h, intercept 57.3
    m = MODEL_2024
    bx = linear_predictor(m, 57.3, 40 + 3 / 7, 99.0, 16, "negative", "broad2to4h")
    assert approx(bx, -10.314751472775248), bx
    p = 1 / (1 + math.exp(-bx))
    assert approx(p, 3.313950068804753e-05), p
    assert approx(posterior(p, 0.36) * 1000, 0.011930473284450786)
    assert approx(posterior(p, 3.65) * 1000, 0.12094855584828663)
    assert approx(posterior(p, 14.5) * 1000, 0.4803078782726455)

    # 2024 FAQ intercept table (rounded to 1 decimal) reproduces from the formula.
    table = {5.0: 60.2, 4.0: 60.0, 2.0: 59.3, 1.0: 58.6, 0.9: 58.5, 0.8: 58.4, 0.7: 58.2,
             0.6: 58.1, 0.5: 57.9, 0.4: 57.7, 0.3: 57.4, 0.2: 57.0, 0.1: 56.3, 0.05: 55.6}
    for inc, expected in table.items():
        got = MODEL_2024.intercept(inc)
        assert round(got, 1) == expected, (inc, got, expected)

    # 2017: the adjustment formula anchored at 0.3/1000 lands within 0.003 of the published intercepts.
    for inc, published in MODEL_2017.published_intercepts.items():
        derived = adjusted_intercept(MODEL_2017.anchor_intercept, MODEL_2017.anchor_incidence, inc / 1000)
        assert abs(derived - published) < 0.003, (inc, derived, published)

    print("self-check OK")


# --------------------------------------------------------------------------- #
# Test vector generation
# --------------------------------------------------------------------------- #


def make_vectors() -> list[dict]:
    cases = []

    def add(model_name, incidence, ga_weeks, ga_days, temp_f, rom, gbs, abx, label):
        model = MODELS[model_name]
        ga = ga_weeks + ga_days / 7.0
        prior = risk_at_birth(model, incidence, ga, temp_f, rom, gbs, abx)
        prior_1000 = prior * 1000
        out = {
            "label": label,
            "model": model_name,
            "incidencePer1000": incidence,
            "gestationalAgeWeeks": ga_weeks,
            "gestationalAgeDays": ga_days,
            "temperatureF": temp_f,
            "romHours": rom,
            "gbs": gbs,
            "antibiotics": abx,
            "expected": {
                "intercept": model.intercept(incidence),
                "riskAtBirthPer1000": prior_1000,
                "vitalsAtBirth": vitals_at_birth(prior_1000),
                "presentations": {},
            },
        }
        for pres in PRESENTATION:
            post_1000 = posterior_for(model, prior, pres) * 1000
            rec = recommendation(prior_1000, post_1000, pres)
            out["expected"]["presentations"][pres] = {
                "riskPer1000": post_1000,
                "care": rec["care"],
                "vitals": rec["vitals"],
            }
        cases.append(out)

    # Spreadsheet examples (intercepts here are the published/derived ones for the
    # matching incidence; the raw spreadsheet numbers are checked in self_check()).
    add("original2017", 0.6, 40, 6, 98.6, 8, "negative", "broad2to4h", "2017 spreadsheet example (0.6/1000)")
    add("updated2024", 0.3, 40, 3, 99.0, 16, "negative", "broad2to4h", "2024 spreadsheet example (0.3/1000)")

    # Boundary / clinically interesting cases for both models.
    scenarios = [
        (0.5, 40, 0, 98.6, 0, "negative", "none", "term, afebrile, no ROM, GBS neg"),
        (0.5, 40, 0, 102.5, 24, "positive", "none", "term, maternal fever 102.5F, ROM 24h, GBS pos, no abx"),
        (0.5, 40, 0, 102.5, 24, "positive", "broadOver4h", "same as above with broad abx >4h"),
        (0.5, 40, 0, 102.5, 24, "positive", "gbsSpecificOver2h", "same as above with GBS-specific abx >2h"),
        (0.5, 35, 0, 99.5, 18, "unknown", "none", "35 wk, 99.5F, ROM 18h, GBS unknown"),
        (0.5, 34, 0, 98.6, 240, "unknown", "none", "34 wk, ROM 240h (max), GBS unknown"),
        (0.5, 43, 6, 98.6, 2, "negative", "none", "43 6/7 wk (max GA)"),
        (0.5, 37, 3, 100.4, 12.5, "positive", "broad2to4h", "37 3/7, 100.4F, ROM 12.5h, GBS pos, broad 2-3.9h"),
        (0.3, 39, 2, 101.0, 30, "negative", "none", "0.3/1000 incidence"),
        (1.0, 39, 2, 101.0, 30, "negative", "none", "1/1000 incidence"),
        (4.0, 39, 2, 101.0, 30, "negative", "none", "4/1000 incidence"),
        (0.1, 39, 2, 101.0, 30, "negative", "none", "0.1/1000 incidence"),
    ]
    for model_name in MODELS:
        for inc, w, d, t, rom, gbs, abx, label in scenarios:
            add(model_name, inc, w, d, t, rom, gbs, abx, f"{model_name}: {label}")

    # Celsius conversion check: 38.0 C == 100.4 F
    assert approx(celsius_to_fahrenheit(38.0), 100.4)
    return cases


def main(argv: list[str]) -> int:
    self_check()
    vectors = make_vectors()
    if "--write" in argv:
        out = Path(__file__).resolve().parents[1] / "Packages" / "EOSCalculatorCore" / "Tests" \
            / "EOSCalculatorCoreTests" / "Resources" / "test_vectors.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps({"generatedBy": "tools/reference_model.py", "cases": vectors}, indent=2) + "\n")
        print(f"wrote {len(vectors)} cases to {out}")
    else:
        for c in vectors[:2]:
            print(json.dumps(c, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
