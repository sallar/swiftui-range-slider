import SwiftUI

/// A control for selecting a closed range of values from a bounded linear
/// range of values, styled to match the system `Slider`.
///
/// ```swift
/// @State private var range = 0.2...0.8
///
/// var body: some View {
///     RangeSlider(range: $range)
/// }
/// ```
@available(iOS 26.0, *)
public struct RangeSlider: View {
    @Binding private var range: ClosedRange<Double>
    private let bounds: ClosedRange<Double>
    private let step: Double?
    private let onEditingChanged: (Bool) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var drag: DragState?
    @State private var lastDraggedThumb = Thumb.lower
    @State private var stretch: CGFloat = 0

    /// Creates a range slider to select a closed range from a given bounded range.
    ///
    /// - Parameters:
    ///   - range: The selected range within `bounds`.
    ///   - bounds: The full range of the valid values. Defaults to `0...1`.
    ///   - step: The distance between each valid value.
    ///   - onEditingChanged: A callback for when editing begins and ends.
    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _range = range
        self.bounds = bounds
        self.step = step
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(proxy.size.width - Self.thumbSize.width, 0)
            let lowerX = Self.thumbSize.width / 2 + trackWidth * fraction(of: range.lowerBound)
            let upperX = Self.thumbSize.width / 2 + trackWidth * fraction(of: range.upperBound)
            let midY = proxy.size.height / 2
            let lensThumb = drag?.thumb ?? lastDraggedThumb
            let lensX = lensThumb == .lower ? lowerX : upperX
            let lensTintSide: CGFloat = lensThumb == .lower ? 1 : -1

            ZStack(alignment: .leading) {
                track(lowerX: lowerX, upperX: upperX)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .padding(.horizontal, Self.lensCanvasInset)
                    .modifier(
                        PressedThumbLensModifier(
                            center: CGPoint(x: lensX + Self.lensCanvasInset, y: midY),
                            tintSide: lensTintSide,
                            progress: drag == nil ? 0 : 1,
                            stretch: stretch,
                            isEnabled: !reduceTransparency,
                            isDark: colorScheme == .dark,
                            normalSize: Self.thumbSize,
                            pressedSize: Self.pressedThumbSize
                        )
                    )
                    // The horizontal padding above only exists to give the
                    // lens room to render. Clamping back to the control's own
                    // width keeps that extra canvas out of the layout, so the
                    // enclosing ZStack is not widened and re-centered.
                    .frame(width: proxy.size.width, height: proxy.size.height)

                thumb(.lower)
                    .position(x: lowerX, y: midY)

                thumb(.upper)
                    .position(x: upperX, y: midY)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            // The press and the stretch animate on different curves, so each is
            // opened explicitly where its state changes. A blanket
            // `.animation(_:value:)` here would override the stretch spring on
            // the frame the press starts or ends.
            .contentShape(.rect)
            .gesture(dragGesture(trackWidth: trackWidth, lowerX: lowerX, upperX: upperX))
        }
        .frame(height: Self.lensCanvasHeight)
        .padding(.vertical, -(Self.lensCanvasHeight - Self.controlHeight) / 2)
    }

    // MARK: - Track

    private func track(lowerX: CGFloat, upperX: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.primary.opacity(0.1))
                .frame(height: Self.trackHeight)

            Capsule()
                .fill(.tint)
                .frame(width: max(upperX - lowerX, Self.trackHeight), height: Self.trackHeight)
                .offset(x: lowerX - Self.trackHeight / 2)
        }
    }

    // MARK: - Thumb

    private func thumb(_ thumb: Thumb) -> some View {
        let isPressed = drag?.thumb == thumb
        let size = thumbSize(of: thumb)

        return Capsule()
            .fill(.white)
            .opacity(isPressed && !reduceTransparency ? 0 : 1)
            .frame(width: size.width, height: size.height)
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        .accessibilityElement()
        .accessibilityLabel(thumb == .lower ? "Minimum" : "Maximum")
        .accessibilityValue(Text(value(of: thumb).formatted()))
        .accessibilityAdjustableAction { direction in
            let increment = step ?? (bounds.upperBound - bounds.lowerBound) / 10
            switch direction {
            case .increment: set(value(of: thumb) + increment, for: thumb)
            case .decrement: set(value(of: thumb) - increment, for: thumb)
            @unknown default: break
            }
        }
    }

    private func thumbSize(of thumb: Thumb) -> CGSize {
        let base = drag?.thumb == thumb ? Self.pressedThumbSize : Self.thumbSize
        // Only the thumb the lens is tracking carries the squash and stretch,
        // including while it settles after the drag ends.
        guard thumb == (drag?.thumb ?? lastDraggedThumb) else { return base }
        return ThumbStretch.apply(base, stretch)
    }

    // MARK: - Dragging

    private func dragGesture(trackWidth: CGFloat, lowerX: CGFloat, upperX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if drag == nil {
                    guard let thumb = pickThumb(for: gesture, lowerX: lowerX, upperX: upperX) else { return }
                    lastDraggedThumb = thumb
                    withAnimation(Self.pressAnimation) {
                        drag = DragState(
                            thumb: thumb,
                            initialValue: value(of: thumb),
                            lastFraction: fraction(of: value(of: thumb)),
                            lastTime: gesture.time
                        )
                    }
                    onEditingChanged(true)
                }
                guard let drag, trackWidth > 0 else { return }
                let span = bounds.upperBound - bounds.lowerBound
                let delta = Double(gesture.translation.width / trackWidth) * span
                // The value has to track the finger exactly. Only the stretch
                // is allowed to spring, so this update opts out of the
                // animation `updateStretch` opens below.
                var immediate = Transaction()
                immediate.disablesAnimations = true
                withTransaction(immediate) {
                    set(drag.initialValue + delta, for: drag.thumb)
                }
                updateStretch(at: gesture.time, trackWidth: trackWidth)
            }
            .onEnded { _ in
                if drag != nil {
                    withAnimation(Self.pressAnimation) { drag = nil }
                    // Releasing drops the target to rest. The spring carries
                    // its momentum through, which is what produces the smoosh.
                    withAnimation(Self.stretchSpring) { stretch = 0 }
                    onEditingChanged(false)
                }
            }
    }

    /// Stretches the thumb along the direction of travel, in proportion to how
    /// fast it is moving.
    ///
    /// The speed is measured from the thumb's own position rather than the
    /// finger's, so the thumb stays at rest once the value is pinned against a
    /// bound or against the other thumb. Retargeting a bouncy spring every
    /// event means a sudden stop leaves the spring with momentum it has to
    /// spend, which compresses the capsule past its resting size before it
    /// settles — the same read as the system control.
    private func updateStretch(at time: Date, trackWidth: CGFloat) {
        guard var state = drag else { return }

        let currentFraction = fraction(of: value(of: state.thumb))
        let elapsed = max(time.timeIntervalSince(state.lastTime), 1.0 / 120.0)
        let travelled = abs(currentFraction - state.lastFraction) * trackWidth
        let speed = travelled / CGFloat(elapsed)

        state.speed += (speed - state.speed) * Self.speedSmoothing
        state.lastFraction = currentFraction
        state.lastTime = time

        var immediate = Transaction()
        immediate.disablesAnimations = true
        withTransaction(immediate) { drag = state }

        let target = min(state.speed / Self.stretchReferenceSpeed, 1) * Self.maxStretch
        withAnimation(Self.stretchSpring) { stretch = target }
    }

    /// Picks the thumb nearest to where the drag started. When the thumbs
    /// overlap, the first direction of movement decides which one to pick.
    private func pickThumb(for gesture: DragGesture.Value, lowerX: CGFloat, upperX: CGFloat) -> Thumb? {
        let x = gesture.startLocation.x
        if abs(x - lowerX) < abs(x - upperX) { return .lower }
        if abs(x - upperX) < abs(x - lowerX) { return .upper }
        if gesture.translation.width == 0 { return nil }
        return gesture.translation.width < 0 ? .lower : .upper
    }

    private func set(_ newValue: Double, for thumb: Thumb) {
        var newValue = snap(newValue)
        switch thumb {
        case .lower:
            newValue = min(max(newValue, bounds.lowerBound), range.upperBound)
            range = newValue...range.upperBound
        case .upper:
            newValue = max(min(newValue, bounds.upperBound), range.lowerBound)
            range = range.lowerBound...newValue
        }
    }

    // MARK: - Values

    private struct DragState {
        var thumb: Thumb
        var initialValue: Double
        var lastFraction: CGFloat
        var lastTime: Date
        var speed: CGFloat = 0
    }

    private enum Thumb {
        case lower, upper
    }

    private func value(of thumb: Thumb) -> Double {
        thumb == .lower ? range.lowerBound : range.upperBound
    }

    private func fraction(of value: Double) -> CGFloat {
        let span = bounds.upperBound - bounds.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat((value - bounds.lowerBound) / span)
    }

    private func snap(_ value: Double) -> Double {
        guard let step, step > 0 else { return value }
        return bounds.lowerBound + (((value - bounds.lowerBound) / step).rounded() * step)
    }

    // MARK: - Metrics

    private static let thumbSize = CGSize(width: 37, height: 24)
    private static let pressedThumbSize = CGSize(width: 56, height: 38)
    private static let trackHeight: CGFloat = 17.0 / 3
    private static let controlHeight: CGFloat = 35
    private static let lensCanvasHeight: CGFloat = 58
    private static let lensCanvasInset: CGFloat = 44

    private static let pressAnimation = Animation.smooth(duration: 0.25)

    /// The thumb speed, in points per second, that stretches it the full
    /// `maxStretch`.
    private static let stretchReferenceSpeed: CGFloat = 1200
    private static let maxStretch: CGFloat = 0.22
    private static let speedSmoothing: CGFloat = 0.6
    private static let stretchSpring = Animation.spring(duration: 0.25, bounce: 0.5)
}

/// Squash and stretch applied to the thumb, preserving its rough area so a
/// wider capsule also reads as a shorter one.
@available(iOS 26.0, *)
private enum ThumbStretch {
    static let verticalRatio: CGFloat = 0.6

    static func apply(_ size: CGSize, _ stretch: CGFloat) -> CGSize {
        CGSize(
            width: size.width * (1 + stretch),
            height: size.height * (1 - stretch * verticalRatio)
        )
    }
}

@available(iOS 26.0, *)
@Animatable
private struct PressedThumbLensModifier: AnimatableModifier {
    @AnimatableIgnored var center: CGPoint
    @AnimatableIgnored var tintSide: CGFloat
    var progress: CGFloat
    var stretch: CGFloat
    @AnimatableIgnored var isEnabled: Bool
    @AnimatableIgnored var isDark: Bool
    @AnimatableIgnored var normalSize: CGSize
    @AnimatableIgnored var pressedSize: CGSize

    func body(content: Content) -> some View {
        let size = ThumbStretch.apply(
            CGSize(
                width: normalSize.width + (pressedSize.width - normalSize.width) * progress,
                height: normalSize.height + (pressedSize.height - normalSize.height) * progress
            ),
            stretch
        )

        // Native glass inherits the sheet's glass compositing context. Sampling
        // only this slider's track keeps the pressed lens optically consistent.
        content.layerEffect(
            ShaderLibrary.bundle(.module).rangeSliderThumbLens(
                .float2(center.x, center.y),
                .float2(size.width, size.height),
                .float(tintSide),
                .float(progress),
                .float(isDark ? 1 : 0)
            ),
            maxSampleOffset: CGSize(width: 44, height: 30),
            isEnabled: isEnabled && progress > 0
        )
    }
}

#Preview("RangeSlider vs Slider") {
    @Previewable @State var range = 0.2...0.8
    @Previewable @State var value = 0.5

    if #available(iOS 26.0, *) {
        VStack(spacing: 40) {
            RangeSlider(range: $range)
            Slider(value: $value)
        }
        .padding()
    } else {
        Text("RangeSlider requires iOS 26")
    }
}
