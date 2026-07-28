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
///
/// The initializers mirror `Slider`, including stepping, tick marks, and
/// minimum and maximum value labels:
///
/// ```swift
/// RangeSlider(
///     range: $range,
///     in: 0...10,
///     step: 1,
///     minimumValueLabel: { Text("0") },
///     maximumValueLabel: { Text("10") },
///     tick: { SliderTick($0) }
/// )
/// ```
@available(iOS 26.0, *)
public struct RangeSlider<Label: View, ValueLabel: View>: View {
    @Binding private var range: ClosedRange<Double>
    private let bounds: ClosedRange<Double>
    private let step: Double?
    private let ticks: [Double]
    private let label: Label
    private let minimumValueLabel: ValueLabel
    private let maximumValueLabel: ValueLabel
    private let onEditingChanged: (Bool) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var drag: DragState?
    @State private var lastDraggedThumb = Thumb.lower
    @State private var stretch: CGFloat = 0

    init(
        range: Binding<ClosedRange<Double>>,
        bounds: ClosedRange<Double>,
        step: Double?,
        ticks: [Double],
        label: Label,
        minimumValueLabel: ValueLabel,
        maximumValueLabel: ValueLabel,
        onEditingChanged: @escaping (Bool) -> Void
    ) {
        _range = range
        self.bounds = bounds
        self.step = step
        self.ticks = ticks
        self.label = label
        self.minimumValueLabel = minimumValueLabel
        self.maximumValueLabel = maximumValueLabel
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        let control = HStack(spacing: Metrics.valueLabelSpacing) {
            minimumValueLabel
            slider
            maximumValueLabel
        }

        // Like the system control on iOS, the label is not drawn — it only
        // names the control for VoiceOver, which needs the text rather than
        // the view.
        if let text = label as? Text {
            control
                .accessibilityElement(children: .contain)
                .accessibilityLabel(text)
        } else {
            control
        }
    }

    private var slider: some View {
        GeometryReader { proxy in
            let trackWidth = max(proxy.size.width - Metrics.thumbSize.width, 0)
            let lowerX = position(of: range.lowerBound, trackWidth: trackWidth)
            let upperX = position(of: range.upperBound, trackWidth: trackWidth)
            let midY = proxy.size.height / 2
            let lensThumb = drag?.thumb ?? lastDraggedThumb
            let lensX = lensThumb == .lower ? lowerX : upperX
            let lensTintSide: CGFloat = lensThumb == .lower ? 1 : -1

            ZStack(alignment: .leading) {
                track(lowerX: lowerX, upperX: upperX, trackWidth: trackWidth)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .padding(.horizontal, Metrics.lensCanvasInset)
                    .modifier(
                        PressedThumbLensModifier(
                            center: CGPoint(x: lensX + Metrics.lensCanvasInset, y: midY),
                            tintSide: lensTintSide,
                            progress: drag == nil ? 0 : 1,
                            stretch: stretch,
                            isEnabled: !reduceTransparency,
                            isDark: colorScheme == .dark,
                            normalSize: Metrics.thumbSize,
                            pressedSize: Metrics.pressedThumbSize
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
        .frame(height: Metrics.lensCanvasHeight)
        .padding(.vertical, -(Metrics.lensCanvasHeight - Metrics.controlHeight) / 2)
    }

    // MARK: - Track

    private func track(lowerX: CGFloat, upperX: CGFloat, trackWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.primary.opacity(0.1))
                .frame(height: Metrics.trackHeight)

            Capsule()
                .fill(.tint)
                .frame(width: max(upperX - lowerX, Metrics.trackHeight), height: Metrics.trackHeight)
                .offset(x: lowerX - Metrics.trackHeight / 2)

            // Ticks sit below the track and keep the same color on both sides
            // of the selection, so the thumbs pass over them. They are drawn
            // rather than laid out because a tick is smaller than a point:
            // rounding its frame to the pixel grid would cost it its softness.
            if !ticks.isEmpty {
                Canvas { context, size in
                    let color = Color(uiColor: .opaqueSeparator)
                    let y = size.height / 2 + Metrics.tickCenterOffset
                    for tick in ticks {
                        let rect = CGRect(
                            x: position(of: tick, trackWidth: trackWidth) - Metrics.tickDiameter / 2,
                            y: y - Metrics.tickDiameter / 2,
                            width: Metrics.tickDiameter,
                            height: Metrics.tickDiameter
                        )
                        context.fill(Circle().path(in: rect), with: .color(color))
                    }
                }
            }
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
            adjust(thumb, direction)
        }
    }

    private func thumbSize(of thumb: Thumb) -> CGSize {
        let base = drag?.thumb == thumb ? Metrics.pressedThumbSize : Metrics.thumbSize
        // Only the thumb the lens is tracking carries the squash and stretch,
        // including while it settles after the drag ends.
        guard thumb == (drag?.thumb ?? lastDraggedThumb) else { return base }
        return ThumbStretch.apply(base, stretch)
    }

    /// Steps a thumb to the next valid value. Ticks take precedence over the
    /// step, since a slider with ticks can only rest on one of them.
    private func adjust(_ thumb: Thumb, _ direction: AccessibilityAdjustmentDirection) {
        let current = value(of: thumb)
        guard ticks.isEmpty else {
            switch direction {
            case .increment:
                if let next = ticks.first(where: { $0 > current }) { set(next, for: thumb) }
            case .decrement:
                if let previous = ticks.last(where: { $0 < current }) { set(previous, for: thumb) }
            @unknown default: break
            }
            return
        }

        let increment = step ?? (bounds.upperBound - bounds.lowerBound) / 10
        switch direction {
        case .increment: set(current + increment, for: thumb)
        case .decrement: set(current - increment, for: thumb)
        @unknown default: break
        }
    }

    // MARK: - Dragging

    private func dragGesture(trackWidth: CGFloat, lowerX: CGFloat, upperX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if drag == nil {
                    guard let thumb = pickThumb(for: gesture, lowerX: lowerX, upperX: upperX) else { return }
                    lastDraggedThumb = thumb
                    withAnimation(Metrics.pressAnimation) {
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
                    withAnimation(Metrics.pressAnimation) { drag = nil }
                    // Releasing drops the target to rest. The spring carries
                    // its momentum through, which is what produces the smoosh.
                    withAnimation(Metrics.stretchSpring) { stretch = 0 }
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

        state.speed += (speed - state.speed) * Metrics.speedSmoothing
        state.lastFraction = currentFraction
        state.lastTime = time

        var immediate = Transaction()
        immediate.disablesAnimations = true
        withTransaction(immediate) { drag = state }

        let target = min(state.speed / Metrics.stretchReferenceSpeed, 1) * Metrics.maxStretch
        withAnimation(Metrics.stretchSpring) { stretch = target }
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

    /// The center of a thumb resting on `value`, in the slider's own
    /// coordinate space. Ticks use it too, so a tick always sits directly
    /// under the thumb that can rest on it.
    private func position(of value: Double, trackWidth: CGFloat) -> CGFloat {
        Metrics.thumbSize.width / 2 + trackWidth * fraction(of: value)
    }

    /// Ticks constrain the values a thumb can take, the same way the system
    /// control does — a slider with ticks only rests on one of them.
    private func snap(_ value: Double) -> Double {
        if let nearest = ticks.min(by: { abs($0 - value) < abs($1 - value) }) {
            return nearest
        }
        guard let step, step > 0 else { return value }
        return bounds.lowerBound + (((value - bounds.lowerBound) / step).rounded() * step)
    }
}

// MARK: - Initializers

@available(iOS 26.0, *)
extension RangeSlider where Label == EmptyView, ValueLabel == EmptyView {
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
        self.init(
            range: range,
            bounds: bounds,
            step: step,
            ticks: [],
            label: EmptyView(),
            minimumValueLabel: EmptyView(),
            maximumValueLabel: EmptyView(),
            onEditingChanged: onEditingChanged
        )
    }

    /// Creates a range slider that marks — and snaps to — the given ticks.
    ///
    /// - Parameters:
    ///   - range: The selected range within `bounds`.
    ///   - bounds: The full range of the valid values. Defaults to `0...1`.
    ///   - ticks: The values to mark on the track.
    ///   - onEditingChanged: A callback for when editing begins and ends.
    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double> = 0...1,
        @SliderTickBuilder<Double> ticks: () -> some SliderTickContent<Double>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            range: range,
            bounds: bounds,
            step: nil,
            ticks: TickValues.from(ticks(), in: bounds),
            label: EmptyView(),
            minimumValueLabel: EmptyView(),
            maximumValueLabel: EmptyView(),
            onEditingChanged: onEditingChanged
        )
    }

    /// Creates a range slider that steps through `bounds`, marking the steps
    /// `tick` returns a tick for.
    ///
    /// - Parameters:
    ///   - range: The selected range within `bounds`.
    ///   - bounds: The full range of the valid values. Defaults to `0...1`.
    ///   - step: The distance between each valid value.
    ///   - tick: A tick to mark the given step value with, or `nil` to leave
    ///     that step unmarked.
    ///   - onEditingChanged: A callback for when editing begins and ends.
    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double,
        tick: (Double) -> SliderTick<Double>?,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            range: range,
            bounds: bounds,
            step: step,
            ticks: TickValues.from(tick, steppingBy: step, in: bounds),
            label: EmptyView(),
            minimumValueLabel: EmptyView(),
            maximumValueLabel: EmptyView(),
            onEditingChanged: onEditingChanged
        )
    }
}

@available(iOS 26.0, *)
extension RangeSlider where Label == EmptyView {
    /// Creates a range slider with labels for its minimum and maximum values.
    ///
    /// - Parameters:
    ///   - range: The selected range within `bounds`.
    ///   - bounds: The full range of the valid values. Defaults to `0...1`.
    ///   - step: The distance between each valid value.
    ///   - minimumValueLabel: A view that describes `bounds.lowerBound`.
    ///   - maximumValueLabel: A view that describes `bounds.upperBound`.
    ///   - onEditingChanged: A callback for when editing begins and ends.
    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double? = nil,
        @ViewBuilder minimumValueLabel: () -> ValueLabel,
        @ViewBuilder maximumValueLabel: () -> ValueLabel,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            range: range,
            bounds: bounds,
            step: step,
            ticks: [],
            label: EmptyView(),
            minimumValueLabel: minimumValueLabel(),
            maximumValueLabel: maximumValueLabel(),
            onEditingChanged: onEditingChanged
        )
    }

    /// Creates a range slider with value labels that marks — and snaps to —
    /// the given ticks.
    ///
    /// - Parameters:
    ///   - range: The selected range within `bounds`.
    ///   - bounds: The full range of the valid values. Defaults to `0...1`.
    ///   - minimumValueLabel: A view that describes `bounds.lowerBound`.
    ///   - maximumValueLabel: A view that describes `bounds.upperBound`.
    ///   - ticks: The values to mark on the track.
    ///   - onEditingChanged: A callback for when editing begins and ends.
    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double> = 0...1,
        @ViewBuilder minimumValueLabel: () -> ValueLabel,
        @ViewBuilder maximumValueLabel: () -> ValueLabel,
        @SliderTickBuilder<Double> ticks: () -> some SliderTickContent<Double>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            range: range,
            bounds: bounds,
            step: nil,
            ticks: TickValues.from(ticks(), in: bounds),
            label: EmptyView(),
            minimumValueLabel: minimumValueLabel(),
            maximumValueLabel: maximumValueLabel(),
            onEditingChanged: onEditingChanged
        )
    }

    /// Creates a range slider with value labels that steps through `bounds`,
    /// marking the steps `tick` returns a tick for.
    ///
    /// - Parameters:
    ///   - range: The selected range within `bounds`.
    ///   - bounds: The full range of the valid values. Defaults to `0...1`.
    ///   - step: The distance between each valid value.
    ///   - minimumValueLabel: A view that describes `bounds.lowerBound`.
    ///   - maximumValueLabel: A view that describes `bounds.upperBound`.
    ///   - tick: A tick to mark the given step value with, or `nil` to leave
    ///     that step unmarked.
    ///   - onEditingChanged: A callback for when editing begins and ends.
    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double,
        @ViewBuilder minimumValueLabel: () -> ValueLabel,
        @ViewBuilder maximumValueLabel: () -> ValueLabel,
        tick: (Double) -> SliderTick<Double>?,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            range: range,
            bounds: bounds,
            step: step,
            ticks: TickValues.from(tick, steppingBy: step, in: bounds),
            label: EmptyView(),
            minimumValueLabel: minimumValueLabel(),
            maximumValueLabel: maximumValueLabel(),
            onEditingChanged: onEditingChanged
        )
    }
}

@available(iOS 26.0, *)
extension RangeSlider where ValueLabel == EmptyView {
    /// Creates a labeled range slider.
    ///
    /// - Parameters:
    ///   - range: The selected range within `bounds`.
    ///   - bounds: The full range of the valid values. Defaults to `0...1`.
    ///   - step: The distance between each valid value.
    ///   - label: A view that describes the control. Like the system slider on
    ///     iOS, it is not drawn; it names the control for VoiceOver.
    ///   - onEditingChanged: A callback for when editing begins and ends.
    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double? = nil,
        @ViewBuilder label: () -> Label,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            range: range,
            bounds: bounds,
            step: step,
            ticks: [],
            label: label(),
            minimumValueLabel: EmptyView(),
            maximumValueLabel: EmptyView(),
            onEditingChanged: onEditingChanged
        )
    }

    /// Creates a labeled range slider that marks — and snaps to — the given
    /// ticks.
    ///
    /// - Parameters:
    ///   - range: The selected range within `bounds`.
    ///   - bounds: The full range of the valid values. Defaults to `0...1`.
    ///   - label: A view that describes the control. Like the system slider on
    ///     iOS, it is not drawn; it names the control for VoiceOver.
    ///   - ticks: The values to mark on the track.
    ///   - onEditingChanged: A callback for when editing begins and ends.
    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double> = 0...1,
        @ViewBuilder label: () -> Label,
        @SliderTickBuilder<Double> ticks: () -> some SliderTickContent<Double>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            range: range,
            bounds: bounds,
            step: nil,
            ticks: TickValues.from(ticks(), in: bounds),
            label: label(),
            minimumValueLabel: EmptyView(),
            maximumValueLabel: EmptyView(),
            onEditingChanged: onEditingChanged
        )
    }

    /// Creates a labeled range slider that steps through `bounds`, marking the
    /// steps `tick` returns a tick for.
    ///
    /// - Parameters:
    ///   - range: The selected range within `bounds`.
    ///   - bounds: The full range of the valid values. Defaults to `0...1`.
    ///   - step: The distance between each valid value.
    ///   - label: A view that describes the control. Like the system slider on
    ///     iOS, it is not drawn; it names the control for VoiceOver.
    ///   - tick: A tick to mark the given step value with, or `nil` to leave
    ///     that step unmarked.
    ///   - onEditingChanged: A callback for when editing begins and ends.
    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double,
        @ViewBuilder label: () -> Label,
        tick: (Double) -> SliderTick<Double>?,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            range: range,
            bounds: bounds,
            step: step,
            ticks: TickValues.from(tick, steppingBy: step, in: bounds),
            label: label(),
            minimumValueLabel: EmptyView(),
            maximumValueLabel: EmptyView(),
            onEditingChanged: onEditingChanged
        )
    }
}

@available(iOS 26.0, *)
extension RangeSlider {
    /// Creates a labeled range slider with labels for its minimum and maximum
    /// values.
    ///
    /// - Parameters:
    ///   - range: The selected range within `bounds`.
    ///   - bounds: The full range of the valid values. Defaults to `0...1`.
    ///   - step: The distance between each valid value.
    ///   - label: A view that describes the control. Like the system slider on
    ///     iOS, it is not drawn; it names the control for VoiceOver.
    ///   - minimumValueLabel: A view that describes `bounds.lowerBound`.
    ///   - maximumValueLabel: A view that describes `bounds.upperBound`.
    ///   - onEditingChanged: A callback for when editing begins and ends.
    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double? = nil,
        @ViewBuilder label: () -> Label,
        @ViewBuilder minimumValueLabel: () -> ValueLabel,
        @ViewBuilder maximumValueLabel: () -> ValueLabel,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            range: range,
            bounds: bounds,
            step: step,
            ticks: [],
            label: label(),
            minimumValueLabel: minimumValueLabel(),
            maximumValueLabel: maximumValueLabel(),
            onEditingChanged: onEditingChanged
        )
    }

    /// Creates a labeled range slider that marks — and snaps to — the given
    /// ticks.
    ///
    /// - Parameters:
    ///   - range: The selected range within `bounds`.
    ///   - bounds: The full range of the valid values. Defaults to `0...1`.
    ///   - label: A view that describes the control. Like the system slider on
    ///     iOS, it is not drawn; it names the control for VoiceOver.
    ///   - minimumValueLabel: A view that describes `bounds.lowerBound`.
    ///   - maximumValueLabel: A view that describes `bounds.upperBound`.
    ///   - ticks: The values to mark on the track.
    ///   - onEditingChanged: A callback for when editing begins and ends.
    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double> = 0...1,
        @ViewBuilder label: () -> Label,
        @ViewBuilder minimumValueLabel: () -> ValueLabel,
        @ViewBuilder maximumValueLabel: () -> ValueLabel,
        @SliderTickBuilder<Double> ticks: () -> some SliderTickContent<Double>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            range: range,
            bounds: bounds,
            step: nil,
            ticks: TickValues.from(ticks(), in: bounds),
            label: label(),
            minimumValueLabel: minimumValueLabel(),
            maximumValueLabel: maximumValueLabel(),
            onEditingChanged: onEditingChanged
        )
    }

    /// Creates a labeled range slider that steps through `bounds`, marking the
    /// steps `tick` returns a tick for.
    ///
    /// - Parameters:
    ///   - range: The selected range within `bounds`.
    ///   - bounds: The full range of the valid values. Defaults to `0...1`.
    ///   - step: The distance between each valid value.
    ///   - label: A view that describes the control. Like the system slider on
    ///     iOS, it is not drawn; it names the control for VoiceOver.
    ///   - minimumValueLabel: A view that describes `bounds.lowerBound`.
    ///   - maximumValueLabel: A view that describes `bounds.upperBound`.
    ///   - tick: A tick to mark the given step value with, or `nil` to leave
    ///     that step unmarked.
    ///   - onEditingChanged: A callback for when editing begins and ends.
    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double,
        @ViewBuilder label: () -> Label,
        @ViewBuilder minimumValueLabel: () -> ValueLabel,
        @ViewBuilder maximumValueLabel: () -> ValueLabel,
        tick: (Double) -> SliderTick<Double>?,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            range: range,
            bounds: bounds,
            step: step,
            ticks: TickValues.from(tick, steppingBy: step, in: bounds),
            label: label(),
            minimumValueLabel: minimumValueLabel(),
            maximumValueLabel: maximumValueLabel(),
            onEditingChanged: onEditingChanged
        )
    }
}

// MARK: - Ticks

/// Reads the values out of SwiftUI's `SliderTick`, which carries one but does
/// not expose it.
@available(iOS 26.0, *)
private enum TickValues {
    static func from(
        _ content: some SliderTickContent<Double>,
        in bounds: ClosedRange<Double>
    ) -> [Double] {
        sorted(content.body.map { value(of: $0, in: bounds) }, in: bounds)
    }

    static func from(
        _ tick: (Double) -> SliderTick<Double>?,
        steppingBy step: Double,
        in bounds: ClosedRange<Double>
    ) -> [Double] {
        guard step > 0, step.isFinite else { return [] }
        let span = bounds.upperBound - bounds.lowerBound
        guard span > 0 else { return [] }
        // The nudge absorbs the division's rounding error, so a step that
        // divides the span evenly keeps its last tick. A step small enough to
        // put a tick on every pixel is already past the point of being
        // readable, and generating them all would stall.
        let count = min(Int((span / step) * (1 + .ulpOfOne)), maxTickCount)

        let values = (0...count).compactMap { index -> Double? in
            let stepValue = min(bounds.lowerBound + Double(index) * step, bounds.upperBound)
            return tick(stepValue).map { value(of: $0, in: bounds) }
        }
        return sorted(values, in: bounds)
    }

    private static let maxTickCount = 1000

    private static func sorted(_ values: [Double], in bounds: ClosedRange<Double>) -> [Double] {
        Array(Set(values.filter { bounds.contains($0) })).sorted()
    }

    /// Reflection reads the stored value directly. If a future SDK renames it,
    /// `SliderTick`'s `Comparable` conformance still orders ticks by value,
    /// which is enough to recover it by bisecting the bounds.
    private static func value(of tick: SliderTick<Double>, in bounds: ClosedRange<Double>) -> Double {
        for child in Mirror(reflecting: tick).children where child.label == "value" {
            if let value = child.value as? Double { return value }
        }

        // Bisection can only find a tick that lies within the bounds. NaN
        // drops the ones that do not, rather than placing them wrongly.
        guard !(tick < SliderTick(bounds.lowerBound)), !(SliderTick(bounds.upperBound) < tick) else {
            return .nan
        }

        var low = bounds.lowerBound
        var high = bounds.upperBound
        for _ in 0..<64 {
            let middle = low + (high - low) / 2
            guard middle > low, middle < high else { break }
            if SliderTick(middle) < tick { low = middle } else { high = middle }
        }
        return low + (high - low) / 2
    }
}

// MARK: - Metrics

@available(iOS 26.0, *)
private enum Metrics {
    static let thumbSize = CGSize(width: 37, height: 24)
    static let pressedThumbSize = CGSize(width: 56, height: 38)
    static let trackHeight: CGFloat = 17.0 / 3
    static let controlHeight: CGFloat = 35
    static let lensCanvasHeight: CGFloat = 58
    static let lensCanvasInset: CGFloat = 44

    /// The gap the system control leaves between a value label and the track.
    static let valueLabelSpacing: CGFloat = 8

    static let tickDiameter: CGFloat = trackHeight / 2
    /// The gap between the bottom of the track and the top of a tick.
    static let tickSpacing: CGFloat = 4.25
    static let tickCenterOffset: CGFloat = trackHeight / 2 + tickSpacing + tickDiameter / 2

    static let pressAnimation = Animation.smooth(duration: 0.25)

    /// The thumb speed, in points per second, that stretches it the full
    /// `maxStretch`.
    static let stretchReferenceSpeed: CGFloat = 1200
    static let maxStretch: CGFloat = 0.22
    static let speedSmoothing: CGFloat = 0.6
    static let stretchSpring = Animation.spring(duration: 0.25, bounce: 0.5)
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
    @Previewable @State var stepped = 2.0...8.0
    @Previewable @State var steppedValue = 5.0

    if #available(iOS 26.0, *) {
        VStack(spacing: 40) {
            RangeSlider(range: $range)
            Slider(value: $value)

            RangeSlider(
                range: $stepped,
                in: 0...10,
                step: 1,
                minimumValueLabel: { Text("0") },
                maximumValueLabel: { Text("10") },
                tick: { SliderTick($0) }
            )
            Slider(
                value: $steppedValue,
                in: 0...10,
                step: 1,
                label: { Text("Value") },
                minimumValueLabel: { Text("0") },
                maximumValueLabel: { Text("10") },
                tick: { SliderTick($0) }
            )
        }
        .padding()
    } else {
        Text("RangeSlider requires iOS 26")
    }
}
