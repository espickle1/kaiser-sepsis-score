import SwiftUI
import EOSCalculatorCore

struct CalculatorView: View {
    @Bindable var model: CalculatorViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case temperature
        case ruptureOfMembranes
    }

    var body: some View {
        NavigationStack {
            Form {
                scenarioSection
                maternalSection
                ResultsSection(model: model)
                footerSection
            }
            .navigationTitle("EOS Risk")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", systemImage: "eraser") {
                        focusedField = nil
                        model.reset()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
    }

    // MARK: Sections

    private var scenarioSection: some View {
        Section {
            Picker("Calculator version", selection: $model.modelVersion) {
                ForEach(ModelVersion.allCases) { version in
                    VStack(alignment: .leading) {
                        Text(version.title)
                        Text(version.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(version)
                }
            }
            .pickerStyle(.navigationLink)

            Picker("Incidence of EOS", selection: $model.incidence) {
                ForEach(Incidence.options) { incidence in
                    Text(incidence.label).tag(incidence)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Scenario")
        } footer: {
            Text(scenarioFooter)
        }
    }

    private var scenarioFooter: String {
        switch model.modelVersion {
        case .updated2024:
            return "The 2024 model was developed from a 2010–2020 cohort with universal GBS screening. If practising where universal GBS screening is not used, KP suggests the original 2017 model; otherwise estimates for GBS-unknown mothers may be higher than justified."
        case .original2017:
            return "The original model was developed from 1993–2007 births, before universal GBS screening, and uses the upper 95% CI of each likelihood ratio."
        }
    }

    private var maternalSection: some View {
        Section {
            HStack {
                Text("Gestational age")
                Spacer()
                Picker("Weeks", selection: $model.gestationalWeeks) {
                    ForEach(EOSInputValidator.gestationalWeeksRange, id: \.self) { weeks in
                        Text("\(weeks) wk").tag(weeks)
                    }
                }
                .labelsHidden()
                Picker("Days", selection: $model.gestationalDays) {
                    ForEach(EOSInputValidator.gestationalDaysRange, id: \.self) { days in
                        Text("\(days) d").tag(days)
                    }
                }
                .labelsHidden()
            }

            HStack {
                Text("Highest maternal temp.")
                Spacer()
                TextField(model.temperatureUnit == .fahrenheit ? "98.6" : "37.0", text: $model.temperatureText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .temperature)
                    .frame(maxWidth: 80)
                    .accessibilityLabel("Highest maternal antepartum temperature")
                Picker("Unit", selection: $model.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.symbol).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 100)
            }

            HStack {
                Text("ROM (hours)")
                Spacer()
                TextField("0", text: $model.ruptureOfMembranesText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .ruptureOfMembranes)
                    .frame(maxWidth: 80)
                    .accessibilityLabel("Duration of rupture of membranes in hours")
            }

            Picker("Maternal GBS status", selection: $model.gbsStatus) {
                Text("Select").tag(nil as GBSStatus?)
                ForEach(GBSStatus.allCases) { status in
                    Text(status.title).tag(Optional(status))
                }
            }

            Picker("Intrapartum antibiotics", selection: $model.antibiotics) {
                Text("Select").tag(nil as IntrapartumAntibiotics?)
                ForEach(IntrapartumAntibiotics.allCases) { option in
                    Text(option.title).tag(Optional(option))
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Maternal risk factors")
        } footer: {
            Text("Use the highest antepartum/intrapartum temperature (a fever within 1 h after delivery may reasonably be used). Only penicillin, ampicillin or cefazolin count as GBS-specific antibiotics; clindamycin or vancomycin alone should be entered as no antibiotics. If maternal antipyretics were given, the model may under-estimate risk.")
        }
    }

    private var footerSection: some View {
        Section {
            NavigationLink {
                ClassificationView(modelVersion: model.modelVersion)
            } label: {
                Label("Clinical presentation definitions", systemImage: "stethoscope")
            }
        } footer: {
            Text("For clinicians trained and experienced in the care of newborn infants. This tool supports, and does not replace, clinical judgement. Independent implementation of the published Kaiser Permanente EOS risk model; not affiliated with or endorsed by Kaiser Permanente.")
        }
    }
}

#Preview {
    CalculatorView(model: CalculatorViewModel())
}
