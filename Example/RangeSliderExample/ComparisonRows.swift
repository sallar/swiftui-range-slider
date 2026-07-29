import RangeSlider
import SwiftUI

/// Puts the system `Slider` directly above a `RangeSlider` in every
/// configuration the package supports, so the two can be compared at a glance
/// on whichever platform the app is running on.
struct ComparisonRows: View {
    /// Outlines what each control claims in the layout, which is the quickest
    /// way to see whether the two agree on their height.
    var showsBounds = false

    @State private var plain = 0.2...0.8
    @State private var plainValue = 0.5

    @State private var labeled = 0.3...0.7
    @State private var labeledValue = 0.5

    @State private var stepped = 2.0...8.0
    @State private var steppedValue = 5.0

    @State private var listed = 0.25...0.75
    @State private var listedValue = 0.5

    @State private var tinted = 100.0...400.0
    @State private var tintedValue = 250.0

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            comparison("Plain") {
                Slider(value: $plainValue)
            } range: {
                RangeSlider(range: $plain)
            } readout: {
                Text(plain.formatted)
            }

            comparison("Minimum and maximum value labels") {
                Slider(
                    value: $labeledValue,
                    label: { Text("Volume") },
                    minimumValueLabel: { Image(systemName: "speaker.fill") },
                    maximumValueLabel: { Image(systemName: "speaker.wave.3.fill") }
                )
            } range: {
                RangeSlider(
                    range: $labeled,
                    minimumValueLabel: { Image(systemName: "speaker.fill") },
                    maximumValueLabel: { Image(systemName: "speaker.wave.3.fill") }
                )
            } readout: {
                Text(labeled.formatted)
            }

            // Ticks arrived with `SliderTick` in the iOS 26 SDK. On an older OS
            // neither control has them, so the stepped row falls back to the
            // same slider without ticks, and the row that is only about ticks
            // drops out entirely.
            comparison(steppedTitle) {
                if #available(iOS 26.0, macOS 26.0, *) {
                    Slider(
                        value: $steppedValue,
                        in: 0...10,
                        step: 1,
                        label: { Text("Rating") },
                        minimumValueLabel: { Text("0") },
                        maximumValueLabel: { Text("10") },
                        tick: { SliderTick($0) }
                    )
                } else {
                    Slider(
                        value: $steppedValue,
                        in: 0...10,
                        step: 1,
                        label: { Text("Rating") },
                        minimumValueLabel: { Text("0") },
                        maximumValueLabel: { Text("10") }
                    )
                }
            } range: {
                if #available(iOS 26.0, macOS 26.0, *) {
                    RangeSlider(
                        range: $stepped,
                        in: 0...10,
                        step: 1,
                        minimumValueLabel: { Text("0") },
                        maximumValueLabel: { Text("10") },
                        tick: { SliderTick($0) }
                    )
                } else {
                    RangeSlider(
                        range: $stepped,
                        in: 0...10,
                        step: 1,
                        minimumValueLabel: { Text("0") },
                        maximumValueLabel: { Text("10") }
                    )
                }
            } readout: {
                Text(stepped.formatted)
            }

            if #available(iOS 26.0, macOS 26.0, *) {
                comparison("Listed ticks") {
                    Slider(value: $listedValue) {
                        Text("Position")
                    } ticks: {
                        SliderTick(0.25)
                        SliderTick(0.5)
                        SliderTick(0.75)
                    }
                } range: {
                    RangeSlider(range: $listed) {
                        SliderTick(0.25)
                        SliderTick(0.5)
                        SliderTick(0.75)
                    }
                } readout: {
                    Text(listed.formatted)
                }
            }

            comparison("Tinted, over 0…500 stepping by 10") {
                Slider(value: $tintedValue, in: 0...500, step: 10)
                    .tint(.orange)
            } range: {
                RangeSlider(range: $tinted, in: 0...500, step: 10)
                    .tint(.orange)
            } readout: {
                Text("\(Int(tinted.lowerBound))–\(Int(tinted.upperBound))")
            }
        }
    }

    // MARK: - Pieces

    private var steppedTitle: String {
        if #available(iOS 26.0, macOS 26.0, *) {
            "Step of 1 over 0…10, ticked on every step"
        } else {
            "Step of 1 over 0…10"
        }
    }

    private func comparison(
        _ title: String,
        @ViewBuilder system: () -> some View,
        @ViewBuilder range: () -> some View,
        @ViewBuilder readout: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                readout()
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            row("Slider", system())
            row("Range", range())
        }
    }

    private func row(_ name: String, _ control: some View) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            control
                .border(showsBounds ? Color.red.opacity(0.6) : .clear)
        }
    }
}

private extension ClosedRange<Double> {
    var formatted: String {
        String(format: "%.2f–%.2f", lowerBound, upperBound)
    }
}

#Preview {
    ComparisonRows()
        .padding(24)
        .frame(width: 520)
}
