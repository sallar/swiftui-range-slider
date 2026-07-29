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
///
/// The control draws itself the way the OS it is running on draws its own
/// slider: a Liquid Glass thumb on iOS 26 and macOS 26, and the opaque knob on a
/// thin track that iOS 18 wears.
///
/// The initializers that take ticks are gated on iOS 26, which is the SDK that
/// introduced `SliderTick`; everything else is available from iOS 18.
@available(iOS 18.0, macOS 26.0, *)
public struct RangeSlider<Label: View, ValueLabel: View>: View {
    @Binding private var range: ClosedRange<Double>
    private let bounds: ClosedRange<Double>
    private let step: Double?
    private let ticks: [Double]
    private let label: Label
    private let minimumValueLabel: ValueLabel
    private let maximumValueLabel: ValueLabel
    private let onEditingChanged: (Bool) -> Void

    @State private var drag: DragState?
    @State private var lastDraggedThumb = Thumb.lower
    @State private var stretch: CGFloat = 0

    private let style = PlatformSliderStyle.current
    private var metrics: RangeSliderMetrics { style.metrics }

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
        let control = HStack(spacing: metrics.valueLabelSpacing) {
            // macOS draws the label ahead of the control; iOS does not draw it
            // at all.
            if metrics.drawsLabel {
                label
            }
            metrics.valueLabelStyle.apply(to: minimumValueLabel)
            slider
            metrics.valueLabelStyle.apply(to: maximumValueLabel)
        }

        // Where the label is not drawn — as on the system control on iOS — it
        // only names the control for VoiceOver, which needs the text rather
        // than the view.
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
            let trackWidth = max(proxy.size.width - metrics.thumbSize.width, 0)
            let lowerX = position(of: range.lowerBound, trackWidth: trackWidth)
            let upperX = position(of: range.upperBound, trackWidth: trackWidth)
            let midY = proxy.size.height / 2
            let activeThumb = drag?.thumb ?? lastDraggedThumb

            ZStack(alignment: .leading) {
                style.track(
                    RangeSliderTrackConfiguration(
                        size: proxy.size,
                        lowerX: lowerX,
                        upperX: upperX,
                        tickPositions: markedTicks(trackWidth: trackWidth)
                            .map { position(of: $0, trackWidth: trackWidth) },
                        activeThumbX: activeThumb == .lower ? lowerX : upperX,
                        selectedSide: activeThumb == .lower ? 1 : -1,
                        pressProgress: drag == nil ? 0 : 1,
                        stretch: stretch
                    )
                )

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
        // The style may need more room to draw than the control occupies. The
        // negative padding hands that room back to the layout.
        .frame(height: metrics.canvasHeight)
        .padding(.vertical, -(metrics.canvasHeight - metrics.controlHeight) / 2)
    }

    /// The values the style marks on the track.
    ///
    /// Where the platform marks the steps of a stepped slider by itself — macOS
    /// does — the steps stand in for ticks that were never asked for. They only
    /// affect the drawing: a slider stepping without ticks still comes to rest
    /// wherever the step grid allows, marked or not. Steps too crowded to tell
    /// apart are left out rather than drawn as a solid line.
    private func markedTicks(trackWidth: CGFloat) -> [Double] {
        guard ticks.isEmpty, metrics.marksSteps, let step, step > 0 else { return ticks }
        let steps = TickValues.steps(of: step, in: bounds)
        guard steps.count > 1 else { return [] }
        return trackWidth / CGFloat(steps.count - 1) >= minimumTickSpacing ? steps : []
    }

    // MARK: - Thumb

    private func thumb(_ thumb: Thumb) -> some View {
        style.thumb(
            RangeSliderThumbConfiguration(
                size: thumbSize(of: thumb),
                isPressed: drag?.thumb == thumb
            )
        )
        .accessibilityElement()
        .accessibilityLabel(thumb == .lower ? "Minimum" : "Maximum")
        .accessibilityValue(Text(value(of: thumb).formatted()))
        .accessibilityAdjustableAction { direction in
            adjust(thumb, direction)
        }
    }

    private func thumbSize(of thumb: Thumb) -> CGSize {
        let base = drag?.thumb == thumb ? metrics.pressedThumbSize : metrics.thumbSize
        // Only the thumb the press effect is tracking carries the squash and
        // stretch, including while it settles after the drag ends.
        guard let stretchMetrics = metrics.stretch,
              thumb == (drag?.thumb ?? lastDraggedThumb)
        else { return base }
        return stretchMetrics.apply(base, stretch)
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
                    // Editing has begun before the press lands, so a caller
                    // watching the binding never sees a value change arrive
                    // ahead of it.
                    onEditingChanged(true)
                    if metrics.jumpsToPress, trackWidth > 0 {
                        // Where the platform's slider jumps to the pointer, the
                        // press itself is a value change, and the drag that may
                        // follow starts from where the thumb landed.
                        setImmediately(
                            value(atX: gesture.startLocation.x, trackWidth: trackWidth),
                            for: thumb
                        )
                    }
                    withAnimation(metrics.pressAnimation) {
                        drag = DragState(
                            thumb: thumb,
                            initialValue: value(of: thumb),
                            lastFraction: fraction(of: value(of: thumb)),
                            lastTime: gesture.time
                        )
                    }
                }
                guard let drag, trackWidth > 0 else { return }
                let span = bounds.upperBound - bounds.lowerBound
                let delta = Double(gesture.translation.width / trackWidth) * span
                // The value has to track the pointer exactly. Only the stretch
                // is allowed to spring, so this update opts out of the
                // animation `updateStretch` opens below.
                setImmediately(drag.initialValue + delta, for: drag.thumb)
                updateStretch(at: gesture.time, trackWidth: trackWidth)
            }
            .onEnded { _ in
                if drag != nil {
                    withAnimation(metrics.pressAnimation) { drag = nil }
                    // Releasing drops the target to rest. The spring carries
                    // its momentum through, which is what produces the smoosh.
                    if let stretchMetrics = metrics.stretch {
                        withAnimation(stretchMetrics.spring) { stretch = 0 }
                    }
                    onEditingChanged(false)
                }
            }
    }

    /// Stretches the thumb along the direction of travel, in proportion to how
    /// fast it is moving.
    ///
    /// The speed is measured from the thumb's own position rather than the
    /// pointer's, so the thumb stays at rest once the value is pinned against a
    /// bound or against the other thumb. Retargeting a bouncy spring every
    /// event means a sudden stop leaves the spring with momentum it has to
    /// spend, which compresses the capsule past its resting size before it
    /// settles — the same read as the system control.
    private func updateStretch(at time: Date, trackWidth: CGFloat) {
        guard let stretchMetrics = metrics.stretch, var state = drag else { return }

        let currentFraction = fraction(of: value(of: state.thumb))
        let elapsed = max(time.timeIntervalSince(state.lastTime), 1.0 / 120.0)
        let travelled = abs(currentFraction - state.lastFraction) * trackWidth
        let speed = travelled / CGFloat(elapsed)

        state.speed += (speed - state.speed) * stretchMetrics.speedSmoothing
        state.lastFraction = currentFraction
        state.lastTime = time

        var immediate = Transaction()
        immediate.disablesAnimations = true
        withTransaction(immediate) { drag = state }

        let target = min(state.speed / stretchMetrics.referenceSpeed, 1) * stretchMetrics.maxStretch
        withAnimation(stretchMetrics.spring) { stretch = target }
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

    private func setImmediately(_ newValue: Double, for thumb: Thumb) {
        var immediate = Transaction()
        immediate.disablesAnimations = true
        withTransaction(immediate) {
            set(newValue, for: thumb)
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

    /// The value a thumb centered on `x` would take.
    private func value(atX x: CGFloat, trackWidth: CGFloat) -> Double {
        let fraction = (x - metrics.thumbSize.width / 2) / trackWidth
        let span = bounds.upperBound - bounds.lowerBound
        return bounds.lowerBound + Double(min(max(fraction, 0), 1)) * span
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
        metrics.thumbSize.width / 2 + trackWidth * fraction(of: value)
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

/// How close together marked steps may sit before they stop being worth
/// drawing.
private let minimumTickSpacing: CGFloat = 4

#Preview("RangeSlider vs Slider") {
    @Previewable @State var range = 0.2...0.8
    @Previewable @State var value = 0.5
    @Previewable @State var stepped = 2.0...8.0
    @Previewable @State var steppedValue = 5.0

    if #available(iOS 18.0, macOS 26.0, *) {
        VStack(spacing: 40) {
            RangeSlider(range: $range)
            Slider(value: $value)

            // Ticks came with iOS 26; below it neither control has them.
            if #available(iOS 26.0, *) {
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
        }
        .padding()
        .frame(width: 320)
    } else {
        Text("RangeSlider requires iOS 18 or macOS 26")
    }
}
