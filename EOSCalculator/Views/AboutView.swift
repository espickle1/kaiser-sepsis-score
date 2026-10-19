import SwiftUI
import EOSCalculatorCore

struct AboutView: View {
    @AppStorage(DisclaimerGateView.storageKey) private var acknowledgedVersion = 0

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section("What this is") {
                Text("An independent iOS implementation of the published Kaiser Permanente neonatal early-onset sepsis (EOS) risk model for infants born at ≥ 34 weeks' gestation. It estimates the probability of culture-confirmed EOS from maternal intrapartum risk factors, then updates that estimate with the infant's clinical presentation using Bayes' theorem.")
                Text("This app is not affiliated with, endorsed by, or maintained by Kaiser Permanente. The model, likelihood ratios and clinical thresholds are reproduced from the peer-reviewed publications and KP's public implementation guidance listed below.")
                    .font(.callout)
            }

            Section("Intended use") {
                Text("For clinicians trained and experienced in the care of newborn infants. Output is a decision aid; it does not replace clinical judgement, local protocols, or evaluation of the individual infant.")
                Text("Model limitations: maternal antipyretic use lowers the recorded maximum temperature and can under-estimate risk; the 2024 model was derived from infants ≥ 35 weeks with universal GBS screening; the model does not use the obstetric diagnosis of chorioamnionitis.")
                    .font(.callout)
            }

            Section("Models") {
                modelRow(.original2017, note: "Puopolo 2011 coefficients; LRs at the upper 95% CI (0.41 / 5.0 / 21.2).")
                modelRow(.updated2024, note: "Kuzniewicz 2024 coefficients from a 2010–2020 cohort; LR point estimates (0.36 / 3.65 / 14.5).")
                Text("Recommendation thresholds (per 1000): risk at birth ≥ 1 → vitals every 4 h for 24 h; composite risk 1–< 3 → blood culture; ≥ 3 → empiric antibiotics; clinical illness with composite < 3 → strongly consider empiric antibiotics.")
                    .font(.callout)
            }

            Section("Privacy") {
                Text("Patient entries are never saved or transmitted. The app has no network access and stores only your preferred model version, incidence and temperature unit on this device.")
            }

            Section("References") {
                reference("Kuzniewicz MW et al. Update to the Neonatal Early-Onset Sepsis Calculator Utilizing a Contemporary Cohort. Pediatrics. 2024;154(4):e2023065267.",
                          url: "https://doi.org/10.1542/peds.2023-065267")
                reference("Kuzniewicz MW et al. A Quantitative, Risk-Based Approach to the Management of Neonatal Early-Onset Sepsis. JAMA Pediatr. 2017;171(4):365-371.",
                          url: "https://doi.org/10.1001/jamapediatrics.2016.4678")
                reference("Escobar GJ et al. Stratification of risk of early-onset sepsis in newborns ≥ 34 weeks' gestation. Pediatrics. 2014;133(1):30-36.",
                          url: "https://doi.org/10.1542/peds.2013-1689")
                reference("Puopolo KM et al. Estimating the probability of neonatal early-onset infection on the basis of maternal risk factors. Pediatrics. 2011;128(5):e1155-1163.",
                          url: "https://doi.org/10.1542/peds.2010-3464")
                reference("Puopolo KM, Benitz WE, Zaoutis TE; AAP COFN. Management of Neonates Born at ≥ 35 0/7 Weeks' Gestation With Suspected or Proven Early-Onset Bacterial Sepsis. Pediatrics. 2018;142(6):e20182894.",
                          url: "https://doi.org/10.1542/peds.2018-2894")
                reference("Kaiser Permanente Division of Research. Neonatal Early-Onset Sepsis Calculator and implementation FAQs.",
                          url: "https://neonatalsepsiscalculator.kaiserpermanente.org/")
            }

            Section {
                LabeledContent("Version", value: appVersion)
                Button("Show clinician acknowledgement again") {
                    acknowledgedVersion = 0
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func modelRow(_ version: ModelVersion, note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(version.title).font(.headline)
            Text(note).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func reference(_ citation: String, url: String) -> some View {
        Group {
            if let link = URL(string: url) {
                Link(destination: link) {
                    Text(citation)
                        .font(.callout)
                        .multilineTextAlignment(.leading)
                }
            } else {
                Text(citation).font(.callout)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
