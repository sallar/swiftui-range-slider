import SwiftUI

/// A platform's look for the slider: how big its parts are, and how the track
/// and thumbs draw.
///
/// The control itself only does arithmetic — positions, values, gestures and
/// accessibility. Everything that differs between platforms and OS versions
/// lives behind this protocol, so a new look is a new conformance rather than a
/// thicket of `#if` inside the control.
@available(iOS 26.0, macOS 26.0, *)
protocol RangeSliderStyle {
    associatedtype TrackBody: View
    associatedtype ThumbBody: View

    var metrics: RangeSliderMetrics { get }

    /// The full width of the control behind the thumbs: the unselected track,
    /// the selected span, the ticks, and any effect the style draws around the
    /// thumb being pressed.
    func track(_ configuration: RangeSliderTrackConfiguration) -> TrackBody

    /// One thumb, drawn at the size the control has resolved for it.
    func thumb(_ configuration: RangeSliderThumbConfiguration) -> ThumbBody
}

// MARK: - Metrics

/// The measurements a style lays the control out with.
@available(iOS 26.0, macOS 26.0, *)
struct RangeSliderMetrics {
    /// The size of a thumb at rest. Its width also sets how far the track is
    /// inset, so a thumb at either bound sits fully inside the control.
    var thumbSize: CGSize

    /// The size of the thumb being dragged. Equal to `thumbSize` on platforms
    /// whose thumb does not grow while it is held.
    var pressedThumbSize: CGSize

    var trackHeight: CGFloat

    /// The height the control takes up in a layout.
    var controlHeight: CGFloat

    /// The height the style needs to draw in. Anything beyond `controlHeight`
    /// is canvas for effects that spill past the track, and is kept out of the
    /// layout.
    var canvasHeight: CGFloat

    /// The gap the system control leaves between a value label and the track.
    var valueLabelSpacing: CGFloat

    /// How a thumb grows and shrinks as it is pressed and released.
    var pressAnimation: Animation

    /// How the thumb deforms with the speed of the drag, or `nil` on platforms
    /// where it does not deform at all.
    var stretch: ThumbStretch?

    /// Whether pressing the track carries the nearest thumb to that point, the
    /// way a macOS slider does. Where this is `false` a press only picks a
    /// thumb up, and the value follows the movement from there.
    var jumpsToPress: Bool

    /// Whether a stepped slider marks every step even when no ticks were asked
    /// for. macOS does; iOS leaves the track clean until it is given ticks.
    var marksSteps: Bool

    /// Whether the label is drawn ahead of the control, the way macOS draws it,
    /// or left undrawn to name the control for VoiceOver, the way iOS does.
    var drawsLabel: Bool

    /// How the minimum and maximum value labels are drawn.
    var valueLabelStyle: ValueLabelStyle
}

/// How a platform draws the labels at either end of the track.
@available(iOS 26.0, macOS 26.0, *)
enum ValueLabelStyle {
    /// Drawn as they come, the way iOS draws them.
    case plain

    /// Small and secondary, the way macOS draws them. A label that sets its own
    /// font or color still wins — this only supplies what it does not say.
    case secondary

    @ViewBuilder
    func apply(to content: some View) -> some View {
        switch self {
        case .plain:
            content
        case .secondary:
            content
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Squash and stretch applied to the thumb, preserving its rough area so a
/// wider capsule also reads as a shorter one.
@available(iOS 26.0, macOS 26.0, *)
struct ThumbStretch {
    /// The widest the thumb stretches, as a fraction of its resting width.
    var maxStretch: CGFloat

    /// The thumb speed, in points per second, that stretches it the full
    /// `maxStretch`.
    var referenceSpeed: CGFloat

    /// How much of each new speed measurement to take, smoothing out the jitter
    /// between individual drag events.
    var speedSmoothing: CGFloat

    /// How much of the stretch is paid back in height.
    var verticalRatio: CGFloat

    var spring: Animation

    func apply(_ size: CGSize, _ stretch: CGFloat) -> CGSize {
        CGSize(
            width: size.width * (1 + stretch),
            height: size.height * (1 - stretch * verticalRatio)
        )
    }
}

// MARK: - Configurations

/// The geometry and interaction state a style needs to draw the track.
///
/// All coordinates are in the control's own space, where `0` is its leading
/// edge and `size.height / 2` the center of the track.
@available(iOS 26.0, macOS 26.0, *)
struct RangeSliderTrackConfiguration {
    var size: CGSize

    /// The centers of the two thumbs.
    var lowerX: CGFloat
    var upperX: CGFloat

    /// Where each tick sits, already resolved to the same positions the thumbs
    /// can rest on.
    var tickPositions: [CGFloat]

    /// The center of the thumb the press effect follows. It outlives the drag,
    /// so the effect has something to settle back onto.
    var activeThumbX: CGFloat

    /// Which side of the active thumb the selected span lies on: `1` for the
    /// lower thumb, `-1` for the upper one.
    var selectedSide: CGFloat

    /// How far the press effect has come in, from `0` at rest to `1` held.
    var pressProgress: CGFloat

    /// The current squash and stretch of the active thumb.
    var stretch: CGFloat
}

/// The size and state of a single thumb.
@available(iOS 26.0, macOS 26.0, *)
struct RangeSliderThumbConfiguration {
    /// The size the control has resolved for this thumb, with the press and any
    /// stretch already applied.
    var size: CGSize

    var isPressed: Bool
}

// MARK: - Resolution

/// The style the running platform calls for.
///
/// Selection has to survive into the view body — a future iOS 18 look is chosen
/// at runtime, not at compile time — so the cases are switched over rather than
/// resolved to a single concrete type. Each branch keeps its own static type,
/// which leaves the view identity of a given platform's slider stable.
@available(iOS 26.0, macOS 26.0, *)
struct PlatformSliderStyle: RangeSliderStyle {
    enum Kind {
        /// The iOS 26 look: a Liquid Glass thumb that grows under the finger.
        case liquidGlass
        /// The macOS 26 look: a small round knob on a thin track.
        case mac
    }

    var kind: Kind

    static var current: PlatformSliderStyle {
        #if os(macOS)
        PlatformSliderStyle(kind: .mac)
        #else
        PlatformSliderStyle(kind: .liquidGlass)
        #endif
    }

    var metrics: RangeSliderMetrics {
        switch kind {
        case .liquidGlass: LiquidGlassSliderStyle().metrics
        case .mac: MacSliderStyle().metrics
        }
    }

    @ViewBuilder
    func track(_ configuration: RangeSliderTrackConfiguration) -> some View {
        switch kind {
        case .liquidGlass: LiquidGlassSliderStyle().track(configuration)
        case .mac: MacSliderStyle().track(configuration)
        }
    }

    @ViewBuilder
    func thumb(_ configuration: RangeSliderThumbConfiguration) -> some View {
        switch kind {
        case .liquidGlass: LiquidGlassSliderStyle().thumb(configuration)
        case .mac: MacSliderStyle().thumb(configuration)
        }
    }
}
