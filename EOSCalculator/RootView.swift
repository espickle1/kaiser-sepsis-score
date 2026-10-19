import SwiftUI

struct RootView: View {
    let viewModel: CalculatorViewModel

    var body: some View {
        TabView {
            CalculatorView(model: viewModel)
                .tabItem { Label("Calculator", systemImage: "function") }

            NavigationStack {
                ClassificationView(modelVersion: viewModel.modelVersion)
            }
            .tabItem { Label("Classification", systemImage: "stethoscope") }

            NavigationStack {
                AboutView()
            }
            .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}

#Preview {
    RootView(viewModel: CalculatorViewModel())
}
