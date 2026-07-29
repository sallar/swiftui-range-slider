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

    /// The gray the iOS 18 slider leaves its unselected track in.
    ///
    /// Measured off the system control in both appearances: a translucent
    /// (120, 120, 128) at 20%, which is what `systemFill` comes to in a light
    /// appearance — and, unlike that dynamic color, what the slider keeps in a
    /// dark one. Staying translucent is what lets it read correctly over a
    /// grouped background rather than only over white.
    static let classicSliderTrack = Color(
        red: 120 / 255,
        green: 120 / 255,
        blue: 128 / 255,
        opacity: 0.2
    )
}
