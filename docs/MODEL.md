# Model specification

This document records exactly what the app computes and where each number comes from,
so the implementation can be audited without reading Swift.

## 1. Risk at birth (prior probability)

Logistic regression on maternal intrapartum factors:

```
βx = β₀
   + β_temp · T            T   = highest maternal antepartum/intrapartum temperature, °F (to 0.1)
   + β_ga   · GA           GA  = gestational age in decimal weeks (weeks + days/7)
   + β_ga²  · GA²
   + β_rom  · (ROM + 0.05)^0.2   ROM = hours of rupture of membranes before delivery
   + β_abx1 · [GBS-specific abx ≥ 2 h  OR  broad-spectrum abx 2–3.9 h before delivery]
   + β_abx2 · [broad-spectrum abx ≥ 4 h before delivery]
   + β_gbs+ · [maternal GBS positive]
   + β_gbs? · [maternal GBS unknown]

P(EOS at birth) = 1 / (1 + e^(−βx))
```

Temperature entered in °C is converted as `F = C × 9/5 + 32` with no rounding (as in KP's spreadsheets).

### Coefficients

| Term | Original (2017) | Updated (2024) |
|---|---:|---:|
| β_temp (°F) | 0.8680 | 0.85194656 |
| β_ga (weeks) | −6.9325 | −7.72247124 |
| β_ga² | 0.0877 | 0.09842383 |
| β_rom | 1.2256 | 0.86770862 |
| β_abx1 (GBS-specific ≥ 2 h / broad 2–3.9 h) | −1.0488 | −2.13142945 |
| β_abx2 (broad ≥ 4 h) | −1.1861 | −2.33985917 |
| β_gbs+ | +0.5771 | +1.02265353 |
| β_gbs? (unknown) | **+0.0427** | +1.13710111 |

Sources:
- 2017: KP *EMR Implementation FAQ*, "Raw equations for the calculator" — which explicitly corrects the Puopolo 2011 supplement, where the GBS-unknown term was misprinted with a negative sign. Confirmed against the cached values in KP's spreadsheet *Worksheet in KP EOS Calculator Guidance for EMR Implementation 2021-0506 rev.xlsm*.
- 2024: KP *2024 EOS Calculator Model Update FAQ*, "What are the coefficients in the new model?" Confirmed against *Updated Excel EOS Calc 2024 Model for Web.xlsm*.

### Intercept (β₀) and baseline incidence

The intercept sets the baseline EOS incidence for the population being served. The app offers the same incidence options as the web calculator: 0.1, 0.2, 0.3 (KPNC), 0.4, 0.5 (CDC national), 0.6, 0.7, 0.8, 0.9, 1, 2, 4 per 1000 live births.

KP's published adjustment (2024 FAQ):

```
β₁ = β₀ − ln[ ((1 − τ) / τ) · (ȳ / (1 − ȳ)) ]
     τ = target population incidence (probability)
     ȳ = derivation cohort incidence (probability)
```

**Original (2017).** KP publishes intercepts for four incidences; the app uses these verbatim:

| Incidence /1000 | β₀ |
|---:|---:|
| 0.3 | 40.0528 |
| 0.4 | 40.3415 |
| 0.5 | 40.5656 |
| 0.6 | 40.7489 |

For the other eight options the app applies the adjustment formula anchored at 0.3/1000 → 40.0528. The formula reproduces the four published values to within 0.003, so the extrapolation is well behaved, **but these eight intercepts are the app's derivation, not KP's published numbers** (see `docs/VERIFICATION.md`).

**Updated (2024).** The fitted intercept is 57.29929499 at the KPNC rate ȳ = 0.0002763 (0.2763/1000). The app applies the adjustment formula for every incidence option. Rounded to one decimal this reproduces KP's published table exactly (0.1→56.3, 0.2→57.0, 0.3→57.4, 0.4→57.7, 0.5→57.9, 0.6→58.1, 0.7→58.2, 0.8→58.4, 0.9→58.5, 1→58.6, 2→59.3, 4→60.0).

> **Known ambiguity.** KP's 2024 spreadsheet and FAQ text use 57.3 for "0.3/1000", whereas the FAQ table and formula give 57.4 (57.38 unrounded). 57.3 is the fit at 0.2763/1000, not 0.3/1000. The app follows the formula (57.38). The difference is ≈ 8% in risk at birth. Which value the live web calculator uses for the 0.3 option should be confirmed by manual comparison and, ideally, by asking KP (PerinatalResearchUnit@kp.org).

## 2. Posterior ("composite") risk by clinical presentation

Bayes' theorem on odds, as in KP's spreadsheets:

```
prior odds     = P / (1 − P)
posterior odds = prior odds × LR(presentation)
posterior P    = posterior odds / (1 + posterior odds)
```

| Presentation | LR, Original (upper 95% CI) | LR, Updated (point estimate) |
|---|---:|---:|
| Well appearing | 0.41 | 0.36 |
| Equivocal | 5.0 | 3.65 |
| Clinical illness | 21.2 | 14.5 |

Presentation definitions (KP Classification page; Kuzniewicz 2017):

- **Clinical illness** — any of: persistent need for NCPAP/HFNC/mechanical ventilation (outside the delivery room); hemodynamic instability requiring vasoactive drugs; neonatal encephalopathy/perinatal depression; seizure; 5-minute Apgar < 5; supplemental O₂ > 2 h to keep SpO₂ > 90% (outside the delivery room).
- **Equivocal** — one persistent physiologic abnormality > 4 h, or two or more lasting > 2 h: tachycardia (HR > 160), tachypnea (RR > 60), temperature instability (≥ 100.4 °F or < 97.5 °F), respiratory distress (grunting, flaring, retracting) not requiring O₂. Abnormalities may be intermittent.
- **Well appearing** — no persistent physiologic abnormalities.

## 3. Recommendations

From the KP EMR Implementation FAQ decision diagram (Kuzniewicz 2017). All values per 1000 live births.

| Condition | Care | Vitals |
|---|---|---|
| Composite ≥ 3 | Empiric antibiotics | Per NICU |
| Clinical illness and composite < 3 | Strongly consider starting empiric antibiotics | Per NICU |
| 1 ≤ composite < 3 | Blood culture | Every 4 h for 24 h |
| Composite < 1 and risk at birth ≥ 1 | No culture, no antibiotics | Every 4 h for 24 h |
| Composite < 1 and risk at birth < 1 | No culture, no antibiotics | Routine |

The "risk at birth" row shown above the presentations reports the vitals recommendation alone (< 1 → routine; ≥ 1 → every 4 h for 24 h).

> KP's spreadsheets contain a mix of "16 hours" and "24 hours" in their recommendation strings; the FAQ diagram, the Kuzniewicz 2017 paper and the General FAQ all say 24 hours, which the app uses.

> The 2024 publication re-estimated the model but did not change the action thresholds; the app applies the same thresholds to both model versions. Confirm against the live calculator.

## 4. Input ranges

| Field | Range | Source |
|---|---|---|
| Gestational age | 34–43 weeks, 0–6 days | Web form validators |
| ROM | 0–240 hours | Web form validators |
| Temperature | one decimal; app rejects < 90 or > 110 °F, warns outside 96–105 °F | Web form constrains only the format |
| 2024 model and GA < 35 weeks | allowed with a warning | 2024 cohort excluded 34-week infants (Model Update FAQ) |

## 5. Verification

`tools/reference_model.py` is an independent Python implementation whose `self_check()` reproduces KP's spreadsheet cached values to ~1e-9 and regenerates `test_vectors.json`. The Swift tests check the same spreadsheet values directly and then every shared vector. Manual comparison against the live site is described in `docs/VERIFICATION.md`.
