import SwiftUI

/// The clear glass a thumb turns into while it is held.
///
/// Both platforms draw it: it is what the system slider does on iOS 26 and on
/// macOS 26 alike, only at different sizes. The effect samples the track it is
/// laid over, so it is applied to the track rather than to the thumb — the
/// thumb itself is hidden for as long as the lens stands in for it.
///
/// Native glass inherits the sheet's glass compositing context. Sampling only
/// this slider's track keeps the pressed lens optically consistent.
@available(iOS 26.0, macOS 26.0, *)
@Animatable
struct PressedThumbLens: AnimatableModifier {
    /// The center of the thumb the lens follows, in the padded canvas's space.
    @AnimatableIgnored var center: CGPoint

    /// Which side of the thumb the selected span lies on.
    @AnimatableIgnored var tintSide: CGFloat

    var progress: CGFloat
    var stretch: CGFloat

    @AnimatableIgnored var isEnabled: Bool
    @AnimatableIgnored var isDark: Bool
    @AnimatableIgnored var normalSize: CGSize
    @AnimatableIgnored var pressedSize: CGSize
    @AnimatableIgnored var stretchMetrics: ThumbStretch?

    /// How far the effect may reach outside the thumb, and so how much canvas
    /// the style has to leave around the track.
    @AnimatableIgnored var sampleOffset: CGSize

    /// How much body the glass carries. A capsule as small as the macOS knob
    /// needs more of it to read as glass rather than as a hole.
    @AnimatableIgnored var bodyGain: CGFloat

    func body(content: Content) -> some View {
        let pressed = CGSize(
            width: normalSize.width + (pressedSize.width - normalSize.width) * progress,
            height: normalSize.height + (pressedSize.height - normalSize.height) * progress
        )
        let size = stretchMetrics?.apply(pressed, stretch) ?? pressed

        content.layerEffect(
            ShaderLibrary.bundle(.module).rangeSliderThumbLens(
                .float2(center.x, center.y),
                .float2(size.width, size.height),
                .float(tintSide),
                .float(progress),
                .float(isDark ? 1 : 0),
                .float(bodyGain)
            ),
            maxSampleOffset: sampleOffset,
            isEnabled: isEnabled && progress > 0
        )
    }
}
