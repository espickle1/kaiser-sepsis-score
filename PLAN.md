# Plan: iOS Neonatal Early-Onset Sepsis Risk Calculator

Independent SwiftUI implementation of the published Kaiser Permanente EOS risk model
(original 2017 and updated 2024 versions). This file tracks scope, decisions and status.

## Goals

- Reproduce the KP calculator's outputs (risk at birth, composite risk per presentation,
  recommendation and vitals) for both model versions and all incidence options.
- Be auditable: every constant traceable to a KP publication or FAQ (`docs/MODEL.md`), with
  tests against KP's own spreadsheet values and a documented manual check against the live site.
- Be safe to ship: clinician gate, clear disclaimers, no PHI stored or transmitted, no KP branding.

## Non-goals (for v1)

- EHR integration, saving patients, history, sharing results.
- Serving as a general sepsis guideline; it computes one published model only.
- Android / web versions (the core package is pure Swift and could be reused later).

## Decisions

| Topic | Decision | Why |
|---|---|---|
| Legal basis | Reimplement the published equations; do not copy site text, assets or code; no KP marks | KP FAQ: "calculator is open source. Please attribute appropriately." KP Terms restrict copying site content and use of marks |
| Permission | Email PerinatalResearchUnit@kp.org before App Store submission (`docs/KP-permission-email.md`) | Written confirmation protects against App Review IP questions and resolves two intercept ambiguities |
| Architecture | `Packages/EOSCalculatorCore` (pure Swift, no UI) + `EOSCalculator` SwiftUI app; XcodeGen `project.yml` instead of a committed `.xcodeproj` | Core is unit-testable on macOS without a simulator; project file stays diff-friendly |
| Minimum iOS | 17.0 | `@Observable`, `@Bindable`, modern pickers |
| Default model | Updated (2024), incidence 0.3/1000 (KPNC) | Matches the web calculator's defaults |
| 2024 intercepts | Formula-derived from 57.29929499 @ 0.2763/1000 for all options | Reproduces KP's published table; see ambiguity in `docs/MODEL.md` §1 |
| 2017 intercepts | KP's four published values; formula-derived for the other eight | Only four are published; formula matches them within 0.003 |
| 34 weeks + 2024 model | Allowed with a warning | Web form accepts 34 weeks; 2024 cohort was ≥ 35 weeks |
| Persistence | Only model version, incidence and temperature unit (UserDefaults) | No PHI at rest |
| Naming | App display name "EOS Risk"; bundle id placeholder `org.example.eoscalculator` | No KP branding; owner sets real bundle id |

## Phases

### Phase 1 — Research and legal check ✅
- [x] Read calculator pages, FAQs, Terms and Conditions
- [x] Obtain coefficients, LRs, intercept formula, decision diagram, classification definitions
- [x] Download KP's two implementation spreadsheets; extract exact formulas and cached values

### Phase 2 — Core model ✅ (written; needs first compile on a Mac)
- [x] `tools/reference_model.py` — independent Python implementation; self-check vs spreadsheets passes
- [x] Shared test vectors generated (`test_vectors.json`, 26 cases)
- [x] Swift core: models, inputs, incidence/intercepts, calculator, recommendations, validation
- [x] XCTest suite: spreadsheet parity, intercept table, vectors, recommendation boundaries, validation
- [ ] `swift test` passes on macOS (cannot be run on the Windows authoring machine)

### Phase 3 — App ✅ (written; needs first compile on a Mac)
- [x] Clinician acknowledgement gate (versioned)
- [x] Calculator form with live results, colour + symbol tiers, warnings
- [x] Classification reference, About/references, privacy statement
- [x] XcodeGen project definition, asset catalog placeholders
- [ ] Build and run in Simulator; fix any compile issues
- [ ] App icon (1024×1024) — must not resemble KP's logo
- [ ] Dynamic Type / VoiceOver pass; iPad layout check
- [ ] Localisation decision (en only for v1)

### Phase 4 — Verification
- [ ] Manual comparison against the live calculator (`docs/VERIFICATION.md`), both models
- [ ] Resolve the 57.3 vs 57.38 intercept question (manual comparison + KP reply)
- [ ] Confirm 2017 intercepts for non-published incidences
- [ ] Clinical review of wording by a neonatologist / NICU pharmacist

### Phase 5 — Release readiness
- [ ] Send permission/attribution email to KP; record the reply in the repo
- [ ] Regulatory review: FDA CDS guidance (clinician-facing, basis of recommendations displayed) — confirm exemption posture with institutional/legal expertise
- [ ] App Store: medical-app guidelines, privacy nutrition label (no data collected), review notes with citations and KP correspondence
- [ ] Licence: repo is already **GPL-3.0**. As sole copyright holder you can distribute the App Store binary on any terms, but (a) the FSF's view is that App Store terms conflict with GPL-3 for *third-party* redistribution, so contributors' code would complicate App Store distribution — consider a CLA or a more permissive licence (MIT/Apache-2.0) before accepting outside contributions; (b) GPL §5(d) "Appropriate Legal Notices" → add the licence and no-warranty notice to the About screen
- [ ] TestFlight with a few clinicians; collect feedback
- [ ] Tag v1.0

## Build instructions (macOS)

```bash
brew install xcodegen
xcodegen generate
open EOSCalculator.xcodeproj          # run the EOSCalculator scheme

# core tests without Xcode UI
cd Packages/EOSCalculatorCore && swift test
```

Regenerate test vectors after any model change:

```bash
python tools/reference_model.py --write
```

## Open questions for KP

1. Intercept used by the live 2024 calculator for the 0.3/1000 option (57.3 vs 57.4).
2. 2017 intercepts for incidences other than 0.3–0.6/1000.
3. Confirmation that recommendation thresholds are unchanged for the 2024 model.
4. Preferred attribution wording.
