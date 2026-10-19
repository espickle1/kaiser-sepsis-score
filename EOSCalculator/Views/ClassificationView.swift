import SwiftUI
import EOSCalculatorCore

/// Definitions of the infant's clinical presentation, as published by KP
/// (Escobar 2014, Kuzniewicz 2017) and shown on the calculator's Classification page.
struct ClassificationView: View {
    let modelVersion: ModelVersion

    private var likelihoodRatios: LikelihoodRatios {
        EOSModel.model(for: modelVersion).likelihoodRatios
    }

    var body: some View {
        List {
            Section {
                bullet("Persistent need for NCPAP / HFNC / mechanical ventilation (outside of the delivery room)")
                bullet("Hemodynamic instability requiring vasoactive drugs")
                bullet("Neonatal encephalopathy / perinatal depression")
                bullet("Seizure")
                bullet("Apgar score at 5 minutes < 5")
                bullet("Need for supplemental O₂ > 2 hours to maintain oxygen saturations > 90% (outside of the delivery room)")
            } header: {
                header(.clinicalIllness, lr: likelihoodRatios.clinicalIllness)
            }

            Section {
                Text("A single persistent physiologic abnormality lasting > 4 hours, **or** two or more physiologic abnormalities lasting > 2 hours:")
                bullet("Tachycardia (HR > 160)")
                bullet("Tachypnea (RR > 60)")
                bullet("Temperature instability (≥ 100.4 °F / 38.0 °C, or < 97.5 °F / 36.4 °C)")
                bullet("Respiratory distress (grunting, flaring, or retracting) not requiring supplemental O₂")
                Text("Abnormalities can be intermittent.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                header(.equivocal, lr: likelihoodRatios.equivocal)
            }

            Section {
                bullet("No persistent physiologic abnormalities")
            } header: {
                header(.wellAppearing, lr: likelihoodRatios.wellAppearing)
            } footer: {
                Text("KP applies the classification over the first 24 hours after birth and recalculates if the infant's status changes. Likelihood ratios shown are those used by the \(modelVersion.title) model.")
            }
        }
        .navigationTitle("Clinical presentation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ presentation: ClinicalPresentation, lr: Double) -> some View {
        HStack {
            Text(presentation.title)
            Spacer()
            Text("LR \(lr.formatted(.number.precision(.fractionLength(0...2))))")
                .monospacedDigit()
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
}

#Preview {
    NavigationStack {
        ClassificationView(modelVersion: .updated2024)
    }
}
