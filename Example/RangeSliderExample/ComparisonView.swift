import SwiftUI

/// The example app's window: the comparisons, plus the controls that make them
/// easier to read.
struct ComparisonView: View {
    @State private var appearance = Appearance.system
    @State private var showsBounds = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                settings
                ComparisonRows(showsBounds: showsBounds)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .preferredColorScheme(appearance.colorScheme)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Appearance", selection: $appearance) {
                ForEach(Appearance.allCases, id: \.self) { appearance in
                    Text(appearance.name).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Toggle("Outline each control's layout bounds", isOn: $showsBounds)
                .font(.callout)
        }
    }
}

private enum Appearance: CaseIterable {
    case system, light, dark

    var name: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

#Preview {
    ComparisonView()
}
