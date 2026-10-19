# Manual verification against the KP web calculator

The automated tests prove the app matches KP's published spreadsheets. They cannot prove
it matches the *live web calculator*, whose server-side code is not public. Before any
clinical use, enter each row below at <https://neonatalsepsiscalculator.kaiserpermanente.org/>
by hand and compare. (Do not script this: KP's Terms and Conditions prohibit automated access.)

Expected values are what the app computes (per 1000 live births, two decimals, as displayed).
Tick the box when the web calculator agrees to the displayed precision.

## Updated (2024) model

| ✓ | Incidence | GA | Temp °F | ROM h | GBS | Antibiotics | Risk @ birth | Well | Equivocal | Clinical illness |
|---|---|---|---|---|---|---|---:|---:|---:|---:|
| ☐ | 0.3 | 40 0/7 | 98.6 | 0 | Negative | None | 0.07 | 0.03 | 0.26 | 1.02 |
| ☐ | 0.3 | 40 0/7 | 102.5 | 24 | Positive | None | 17.08 | 6.22 | 59.63 | 201.22 |
| ☐ | 0.3 | 40 0/7 | 102.5 | 24 | Positive | Broad > 4 h | 1.67 | 0.60 | 6.07 | 23.69 |
| ☐ | 0.5 | 35 0/7 | 99.5 | 18 | Unknown | None | 12.48 | 4.53 | 44.09 | 154.85 |
| ☐ | 0.5 | 39 2/7 | 101.0 | 30 | Negative | None | 2.94 | 1.06 | 10.66 | 41.03 |
| ☐ | 1 | 37 3/7 | 100.4 | 12.5 | Positive | Broad 2–3.9 h | 1.22 | 0.44 | 4.44 | 17.41 |

**What to look for:** if the 0.3/1000 rows are consistently ≈ 8% *higher* in the app than on the
website, the website is using intercept 57.3 rather than the formula value 57.38 for that option
(see "Known ambiguity" in `docs/MODEL.md`). Switch `EOSModel.updated2024.publishedIntercepts`
to `[0.3: 57.3]` and re-run the tests (the Python reference and vectors must be updated to match).

## Original (2017) model

| ✓ | Incidence | GA | Temp °F | ROM h | GBS | Antibiotics | Risk @ birth | Well | Equivocal | Clinical illness |
|---|---|---|---|---|---|---|---:|---:|---:|---:|
| ☐ | 0.5 | 40 0/7 | 98.6 | 0 | Negative | None | 0.04 | 0.02 | 0.19 | 0.82 |
| ☐ | 0.5 | 40 0/7 | 102.5 | 24 | Positive | None | 10.43 | 4.30 | 50.08 | 182.70 |
| ☐ | 0.5 | 40 0/7 | 102.5 | 24 | Positive | Broad > 4 h | 3.21 | 1.32 | 15.85 | 63.91 |
| ☐ | 0.5 | 35 0/7 | 99.5 | 18 | Unknown | None | 2.36 | 0.97 | 11.71 | 47.85 |
| ☐ | 0.3 | 39 2/7 | 101.0 | 30 | Negative | None | 1.05 | 0.43 | 5.25 | 21.89 |
| ☐ | 1 | 37 3/7 | 100.4 | 12.5 | Positive | Broad 2–3.9 h | 1.29 | 0.53 | 6.43 | 26.72 |

**What to look for:** rows with incidence 0.3–0.6 use KP's published intercepts and should match
exactly. The 1/1000 row uses an intercept the app derives with KP's adjustment formula; a
discrepancy there (but not in the others) means KP's unpublished intercepts differ from the
formula and we should ask them for the full table.

## Recommendations and vitals

For each row also confirm the recommendation text and vitals the site shows for each presentation
match the app's (No culture + no antibiotics / Blood culture / Empiric antibiotics / Strongly consider
starting empiric antibiotics; Routine / every 4 h × 24 h / per NICU).

## Boundary behaviour

- [ ] 34 0/7 weeks accepted by the website on the **2024** tab? (App allows it with a warning.)
- [ ] ROM 240 h accepted; 240.1 rejected.
- [ ] Temperature entry in °C: 38.0 °C produces the same result as 100.4 °F.
- [ ] Risk exactly 1.00 at birth → "Vitals every 4 hours for 24 hours" (threshold is ≥ 1).

## Record

| Date | Tester | App build | Result / notes |
|---|---|---|---|
| | | | |
