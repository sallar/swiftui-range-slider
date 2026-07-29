import SwiftUI

/// The iOS 18 look: an opaque white knob on a thin track that runs the full
/// width of the control.
///
/// It is a still picture next to the iOS 26 slider. The knob keeps its size
/// while it is held, it does not turn to glass, and it does not stretch with the
/// speed of the drag — the only thing that moves is the knob itself, following
/// the finger. The track is thinner than the one iOS 26 draws, and it reaches
/// the ends of the control rather than stopping short of them: a knob at either
/// bound sits over the end of the track, not beside it.
///
/// Every measurement here was read off the system slider on iOS 18 at 3×, which
/// is where the odd ones come from — see `ClassicTrack` for the two the system
/// control does not center.
@available(iOS 18.0, macOS 26.0, *)
struct ClassicSliderStyle: RangeSliderStyle {
    var metrics: RangeSliderMetrics {
        RangeSliderMetrics(
            thumbSize: CGSize(width: 27, height: 27),
            // The knob is the same size held as at rest.
            pressedThumbSize: CGSize(width: 27, height: 27),
            trackHeight: 4,
            controlHeight: 31,
            // Nothing is drawn outside the control, so the canvas is the
            // control. The knob's shadow spills past it, which costs no layout.
            canvasHeight: 31,
            valueLabelSpacing: 8,
            // Nothing changes on a press, so there is nothing to animate.
            pressAnimation: .linear(duration: 0),
            stretch: nil,
            jumpsToPress: false,
            marksSteps: false,
            drawsLabel: false,
            valueLabelStyle: .plain
        )
    }

    func track(_ configuration: RangeSliderTrackConfiguration) -> some View {
        ClassicTrack(configuration: configuration, metrics: metrics)
    }

    func thumb(_ configuration: RangeSliderThumbConfiguration) -> some View {
        ClassicKnob(configuration: configuration)
    }
}

// MARK: - Track

@available(iOS 18.0, macOS 26.0, *)
private struct ClassicTrack: View {
    var configuration: RangeSliderTrackConfiguration
    var metrics: RangeSliderMetrics

    var body: some View {
        // Ticks are left undrawn: iOS 18 has no slider tick of its own to match,
        // and the initializers that take them are gated on the SDK that
        // introduced `SliderTick`, so this track is never handed any.
        rails
            .offset(y: Self.trackCenterOffset)
            .frame(width: configuration.size.width, height: configuration.size.height)
    }

    private var rails: some View {
        ZStack(alignment: .leading) {
            // The inset is padding rather than a narrower frame, so the stack
            // still spans the control and the selected span below can be placed
            // straight from the thumb positions.
            Capsule()
                .fill(Color.classicSliderTrack)
                .frame(height: metrics.trackHeight)
                .padding(.horizontal, Self.endInset)
                .frame(width: configuration.size.width)

            // The selected span runs between the two thumb centers. Its rounded
            // ends are covered by the knobs at every value, including where the
            // two meet and the span closes to nothing.
            Capsule()
                .fill(.tint)
                .frame(
                    width: max(configuration.upperX - configuration.lowerX, 0),
                    height: metrics.trackHeight
                )
                .offset(x: configuration.lowerX)
        }
    }

    /// How far short of each end the track stops. The knobs still travel the
    /// full width, so a knob at either bound overhangs the track by this much,
    /// the way the system control's does.
    static let endInset: CGFloat = 1

    /// The system control does not center its track in its own bounds — it sits
    /// half a point below the middle of the 31 points the slider claims. The
    /// knob misses the middle in the other direction; see `ClassicKnob`.
    static let trackCenterOffset: CGFloat = 0.5
}

// MARK: - Knob

@available(iOS 18.0, macOS 26.0, *)
private struct ClassicKnob: View {
    var configuration: RangeSliderThumbConfiguration

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: configuration.size.width, height: configuration.size.height)
            // Three shadows to land on one profile: the system knob's is dark
            // right at its edge and then carries a long, faint tail well past
            // where a single blur of either radius would have finished. The
            // last one is dropped far enough to stay out of the light above the
            // knob, which is where that tail is not.
            .shadow(color: .black.opacity(0.10), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.13), radius: 5, y: 2.5)
            .shadow(color: .black.opacity(0.07), radius: 14, y: 9)
            .offset(y: Self.centerOffset)
    }

    /// The knob rides two thirds of a point above the middle of the control,
    /// which is where UIKit's shadowed thumb image leaves it. Together with the
    /// track's own half point below the middle, that is the small gap the system
    /// slider shows between the center of its knob and the center of its track.
    static let centerOffset: CGFloat = -2.0 / 3
}
