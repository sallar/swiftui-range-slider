import SwiftUI

/// The macOS 26 look: a small glass knob riding a thin track, with steps marked
/// as dots beneath it.
///
/// It is the same Liquid Glass the iOS slider wears, at the size a pointer
/// calls for. The knob grows a little when it is grabbed and turns clear, but
/// it does not balloon the way it does under a finger — nothing is hidden
/// beneath a pointer — and it does not stretch with the speed of the drag.
/// Pressing the track carries the nearest knob to the pointer, the way every
/// other macOS slider behaves.
@available(iOS 26.0, macOS 26.0, *)
struct MacSliderStyle: RangeSliderStyle {
    var metrics: RangeSliderMetrics {
        RangeSliderMetrics(
            thumbSize: CGSize(width: 20, height: 16),
            pressedThumbSize: CGSize(width: 24, height: 20),
            trackHeight: 6,
            controlHeight: 16,
            canvasHeight: 40,
            valueLabelSpacing: 6,
            pressAnimation: .smooth(duration: 0.2),
            stretch: nil,
            jumpsToPress: true,
            marksSteps: true,
            drawsLabel: true,
            valueLabelStyle: .secondary
        )
    }

    func track(_ configuration: RangeSliderTrackConfiguration) -> some View {
        MacTrack(configuration: configuration, metrics: metrics)
    }

    func thumb(_ configuration: RangeSliderThumbConfiguration) -> some View {
        MacKnob(configuration: configuration)
    }
}

// MARK: - Track

@available(iOS 26.0, macOS 26.0, *)
private struct MacTrack: View {
    var configuration: RangeSliderTrackConfiguration
    var metrics: RangeSliderMetrics

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let size = configuration.size

        rails
            .frame(width: size.width, height: size.height)
            .padding(.horizontal, Self.lensCanvasInset)
            .modifier(
                PressedThumbLens(
                    center: CGPoint(
                        x: configuration.activeThumbX + Self.lensCanvasInset,
                        y: size.height / 2
                    ),
                    tintSide: configuration.selectedSide,
                    progress: configuration.pressProgress,
                    stretch: configuration.stretch,
                    isEnabled: !reduceTransparency,
                    isDark: colorScheme == .dark,
                    normalSize: metrics.thumbSize,
                    pressedSize: metrics.pressedThumbSize,
                    stretchMetrics: metrics.stretch,
                    sampleOffset: CGSize(width: Self.lensCanvasInset, height: 16),
                    bodyGain: 1.8
                )
            )
            // The padding above is only canvas for the lens. Clamping back to
            // the control's own width keeps it out of the layout.
            .frame(width: size.width, height: size.height)
    }

    private var rails: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.sliderTrack)
                .frame(height: metrics.trackHeight)

            Capsule()
                .fill(.tint)
                .frame(
                    width: max(
                        configuration.upperX - configuration.lowerX,
                        metrics.trackHeight
                    ),
                    height: metrics.trackHeight
                )
                .offset(x: configuration.lowerX - metrics.trackHeight / 2)

            // Steps are marked with small dots below the track, the same color
            // on both sides of the selection so a knob passing over one does
            // not make it jump. They are drawn rather than laid out because a
            // dot this small would lose its softness to the pixel grid.
            if !configuration.tickPositions.isEmpty {
                Canvas { context, size in
                    let color = Color.sliderTick
                    let y = size.height / 2 + Self.tickCenterOffset
                    for x in configuration.tickPositions {
                        let rect = CGRect(
                            x: x - Self.tickDiameter / 2,
                            y: y - Self.tickDiameter / 2,
                            width: Self.tickDiameter,
                            height: Self.tickDiameter
                        )
                        context.fill(Circle().path(in: rect), with: .color(color))
                    }
                }
            }
        }
    }

    /// How much room the lens needs on either side of the track to render.
    static let lensCanvasInset: CGFloat = 24

    static let tickDiameter: CGFloat = 2
    /// The gap between the bottom of the track and the top of a dot.
    static let tickSpacing: CGFloat = 3
    static let tickCenterOffset: CGFloat = 6 / 2 + tickSpacing + tickDiameter / 2
}

// MARK: - Knob

@available(iOS 26.0, macOS 26.0, *)
private struct MacKnob: View {
    var configuration: RangeSliderThumbConfiguration

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Capsule()
            .fill(fill)
            // While the knob is held, the glass lens drawn over the track
            // stands in for it.
            .opacity(configuration.isPressed && !reduceTransparency ? 0 : 1)
            .frame(width: configuration.size.width, height: configuration.size.height)
            .shadow(color: .black.opacity(0.13), radius: 3.5, y: 1.5)
    }

    /// White on a light appearance. On a dark one the system holds the knob
    /// just short of white, so it reads as glass rather than as a lamp.
    private var fill: Color {
        colorScheme == .dark ? Color(white: 0.871) : .white
    }
}
