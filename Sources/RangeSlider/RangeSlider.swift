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

    @State private var drag: DragState?

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

            ZStack(alignment: .leading) {
                track(lowerX: lowerX, upperX: upperX)

                thumb(.lower)
                    .position(x: lowerX, y: midY)

                thumb(.upper)
                    .position(x: upperX, y: midY)
            }
            .animation(.smooth(duration: 0.25), value: drag?.thumb)
            .contentShape(.rect)
            .gesture(dragGesture(trackWidth: trackWidth, lowerX: lowerX, upperX: upperX))
        }
        .frame(height: Self.controlHeight)
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
            .opacity(isPressed ? 0 : 1)
            .frame(width: size.width, height: size.height)
            .glassEffect(.clear, in: .capsule)
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
        drag?.thumb == thumb ? Self.pressedThumbSize : Self.thumbSize
    }

    // MARK: - Dragging

    private func dragGesture(trackWidth: CGFloat, lowerX: CGFloat, upperX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if drag == nil {
                    guard let thumb = pickThumb(for: gesture, lowerX: lowerX, upperX: upperX) else { return }
                    drag = DragState(thumb: thumb, initialValue: value(of: thumb))
                    onEditingChanged(true)
                }
                guard let drag, trackWidth > 0 else { return }
                let span = bounds.upperBound - bounds.lowerBound
                let delta = Double(gesture.translation.width / trackWidth) * span
                set(drag.initialValue + delta, for: drag.thumb)
            }
            .onEnded { _ in
                if drag != nil {
                    drag = nil
                    onEditingChanged(false)
                }
            }
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
