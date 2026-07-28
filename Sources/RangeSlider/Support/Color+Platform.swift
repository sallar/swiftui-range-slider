import SwiftUI

extension Color {
    /// The gray the system slider marks its ticks with.
    static var sliderTick: Color {
        #if os(macOS)
        Color(nsColor: .tertiaryLabelColor)
        #else
        Color(uiColor: .opaqueSeparator)
        #endif
    }

    /// The gray the system slider leaves its unselected track in.
    static var sliderTrack: Color {
        #if os(macOS)
        Color(nsColor: .quaternaryLabelColor)
        #else
        .primary.opacity(0.1)
        #endif
    }
}
