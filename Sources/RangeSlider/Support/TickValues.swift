import SwiftUI

/// Reads the values out of SwiftUI's `SliderTick`, which carries one but does
/// not expose it.
@available(iOS 26.0, macOS 26.0, *)
enum TickValues {
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

    /// Every value the step grid lands on, for platforms that mark the steps of
    /// a stepped slider whether or not it was given ticks.
    static func steps(of step: Double, in bounds: ClosedRange<Double>) -> [Double] {
        guard step > 0, step.isFinite else { return [] }
        let span = bounds.upperBound - bounds.lowerBound
        guard span > 0 else { return [] }
        let count = min(Int((span / step) * (1 + .ulpOfOne)), maxTickCount)
        return (0...count).map { min(bounds.lowerBound + Double($0) * step, bounds.upperBound) }
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
