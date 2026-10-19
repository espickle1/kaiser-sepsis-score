import SwiftUI

/// Full-screen acknowledgement shown on first launch (and again whenever
/// `currentVersion` is bumped after a wording change).
struct DisclaimerGateView: View {
    static let storageKey = "acknowledgedDisclaimerVersion"
    static let currentVersion = 1

    @AppStorage(Self.storageKey) private var acknowledgedVersion = 0
    @State private var confirmedClinician = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Clinical decision aid", systemImage: "stethoscope")
                        .font(.title2.weight(.semibold))

                    Text("This app estimates the risk of neonatal early-onset sepsis for infants born at ≥ 34 weeks' gestation using the published Kaiser Permanente risk model.")

                    Text("It is intended for clinicians trained and experienced in the care of newborn infants. The output supports clinical judgement and local protocols; it does not replace them.")

                    Text("This is an independent implementation and is not affiliated with, endorsed by, or maintained by Kaiser Permanente. Always confirm that the selected model version and baseline incidence are appropriate for your population.")

                    Text("No patient information entered here is stored or transmitted.")
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Toggle("I am a clinician trained and experienced in the care of newborn infants.", isOn: $confirmedClinician)
                    Button {
                        acknowledgedVersion = Self.currentVersion
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!confirmedClinician)
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("Before you begin")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    DisclaimerGateView()
}
