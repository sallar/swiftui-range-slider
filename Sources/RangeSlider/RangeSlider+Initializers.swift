import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
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

@available(iOS 26.0, macOS 26.0, *)
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

@available(iOS 26.0, macOS 26.0, *)
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

@available(iOS 26.0, macOS 26.0, *)
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
