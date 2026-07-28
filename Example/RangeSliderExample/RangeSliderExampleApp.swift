import SwiftUI

@main
struct RangeSliderExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ComparisonView()
        }
        #if os(macOS)
        .defaultSize(width: 560, height: 760)
        #endif
    }
}
