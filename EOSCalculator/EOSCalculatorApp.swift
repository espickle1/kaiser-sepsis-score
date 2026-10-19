import SwiftUI

@main
struct EOSCalculatorApp: App {
    @State private var viewModel = CalculatorViewModel()
    @AppStorage(DisclaimerGateView.storageKey) private var acknowledgedVersion = 0

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .fullScreenCover(isPresented: needsAcknowledgement) {
                    DisclaimerGateView()
                }
        }
    }

    /// Presents the clinician acknowledgement until the current disclaimer version is accepted.
    private var needsAcknowledgement: Binding<Bool> {
        Binding(
            get: { acknowledgedVersion < DisclaimerGateView.currentVersion },
            set: { _ in }
        )
    }
}
