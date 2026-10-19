# EOS Risk — iOS neonatal early-onset sepsis calculator

An independent SwiftUI implementation of the published Kaiser Permanente neonatal
early-onset sepsis (EOS) risk model for infants born at ≥ 34 weeks' gestation, offering
both the original (2017) and updated (2024) model versions.

> **Not affiliated with or endorsed by Kaiser Permanente.** The model, likelihood ratios
> and thresholds are reproduced from the peer-reviewed publications and KP's public
> implementation guidance. For clinicians trained and experienced in the care of newborn
> infants. Decision support only — not a substitute for clinical judgement.

## Status

Pre-release. Core model and app are written and the model is verified against KP's own
implementation spreadsheets, but the project has not yet been compiled on a Mac or compared
by hand against the live web calculator. See [`PLAN.md`](PLAN.md) for the roadmap and
[`docs/VERIFICATION.md`](docs/VERIFICATION.md) for the manual check.

## Layout

```
Packages/EOSCalculatorCore/   Pure-Swift model, recommendations, validation + XCTest suite
EOSCalculator/                SwiftUI app (iOS 17+)
project.yml                   XcodeGen definition (generates EOSCalculator.xcodeproj)
tools/reference_model.py      Independent Python implementation; generates shared test vectors
docs/MODEL.md                 Equations, coefficients, intercepts, thresholds, with sources
docs/VERIFICATION.md          Manual comparison checklist against the KP website
docs/KP-permission-email.md   Draft attribution/permission request to KP
```

## Build

Requires macOS with Xcode 15+.

```bash
brew install xcodegen
xcodegen generate
open EOSCalculator.xcodeproj
```

Set your team and bundle identifier in `project.yml` (search for `TODO`) and regenerate.

Run the core tests without the simulator:

```bash
cd Packages/EOSCalculatorCore
swift test
```

## Model

See [`docs/MODEL.md`](docs/MODEL.md). In short: a logistic model on gestational age,
highest maternal temperature, duration of rupture of membranes, GBS status and intrapartum
antibiotics gives the risk at birth; Bayes' theorem with published likelihood ratios for
"well appearing", "equivocal" and "clinical illness" gives the composite risk; KP's
thresholds (1 and 3 per 1000) map to vitals, blood culture and empiric antibiotics.

## Licence

GPL-3.0 (see `LICENSE`). The underlying model is the published work of the Kaiser Permanente
investigators cited below and is attributed in-app; this licence covers only this implementation.

## References

- Kuzniewicz MW, et al. Update to the Neonatal Early-Onset Sepsis Calculator Utilizing a Contemporary Cohort. *Pediatrics.* 2024;154(4):e2023065267. https://doi.org/10.1542/peds.2023-065267
- Kuzniewicz MW, et al. A Quantitative, Risk-Based Approach to the Management of Neonatal Early-Onset Sepsis. *JAMA Pediatr.* 2017;171(4):365-371. https://doi.org/10.1001/jamapediatrics.2016.4678
- Escobar GJ, et al. Stratification of risk of early-onset sepsis in newborns ≥ 34 weeks' gestation. *Pediatrics.* 2014;133(1):30-36. https://doi.org/10.1542/peds.2013-1689
- Puopolo KM, et al. Estimating the probability of neonatal early-onset infection on the basis of maternal risk factors. *Pediatrics.* 2011;128(5):e1155-1163. https://doi.org/10.1542/peds.2010-3464
- Kaiser Permanente Division of Research. Neonatal Early-Onset Sepsis Calculator. https://neonatalsepsiscalculator.kaiserpermanente.org/
