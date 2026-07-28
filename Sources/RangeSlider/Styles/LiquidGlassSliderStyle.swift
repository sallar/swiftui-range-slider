import SwiftUI

/// The iOS 26 look: a Liquid Glass thumb that grows under the finger, turns
/// into clear glass that refracts the track beneath it, and stretches along the
/// direction of travel.
@available(iOS 26.0, macOS 26.0, *)
struct LiquidGlassSliderStyle: RangeSliderStyle {
    var metrics: RangeSliderMetrics {
        RangeSliderMetrics(
            thumbSize: CGSize(width: 37, height: 24),
            pressedThumbSize: CGSize(width: 56, height: 38),
            trackHeight: 17.0 / 3,
            controlHeight: 35,
            canvasHeight: 58,
            valueLabelSpacing: 8,
            pressAnimation: .smooth(duration: 0.25),
            stretch: ThumbStretch(
                maxStretch: 0.22,
                referenceSpeed: 1200,
                speedSmoothing: 0.6,
                verticalRatio: 0.6,
                spring: .spring(duration: 0.25, bounce: 0.5)
            ),
            jumpsToPress: false,
            marksSteps: false,
            drawsLabel: false,
            valueLabelStyle: .plain
        )
    }

    func track(_ configuration: RangeSliderTrackConfiguration) -> some View {
        LiquidGlassTrack(configuration: configuration, metrics: metrics)
    }

    func thumb(_ configuration: RangeSliderThumbConfiguration) -> some View {
        LiquidGlassThumb(configuration: configuration)
    }
}

// MARK: - Track

@available(iOS 26.0, macOS 26.0, *)
private struct LiquidGlassTrack: View {
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
                    sampleOffset: CGSize(width: Self.lensCanvasInset, height: 30),
                    bodyGain: 1
                )
            )
            // The horizontal padding above only exists to give the lens room to
            // render. Clamping back to the control's own width keeps that extra
            // canvas out of the layout, so the enclosing ZStack is not widened
            // and re-centered.
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
                    width: max(configuration.upperX - configuration.lowerX, metrics.trackHeight),
                    height: metrics.trackHeight
                )
                .offset(x: configuration.lowerX - metrics.trackHeight / 2)

            // Ticks sit below the track and keep the same color on both sides
            // of the selection, so the thumbs pass over them. They are drawn
            // rather than laid out because a tick is smaller than a point:
            // rounding its frame to the pixel grid would cost it its softness.
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
    static let lensCanvasInset: CGFloat = 44

    static let tickDiameter: CGFloat = (17.0 / 3) / 2
    /// The gap between the bottom of the track and the top of a tick.
    static let tickSpacing: CGFloat = 4.25
    static let tickCenterOffset: CGFloat = (17.0 / 3) / 2 + tickSpacing + tickDiameter / 2
}

// MARK: - Thumb

@available(iOS 26.0, macOS 26.0, *)
private struct LiquidGlassThumb: View {
    var configuration: RangeSliderThumbConfiguration

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Capsule()
            .fill(.white)
            // While the thumb is held, the glass lens drawn over the track
            // stands in for it.
            .opacity(configuration.isPressed && !reduceTransparency ? 0 : 1)
            .frame(width: configuration.size.width, height: configuration.size.height)
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }
}
