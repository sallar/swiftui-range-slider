# RangeSlider

A SwiftUI range slider for iOS 26+ that looks and feels like the system `Slider` — same track metrics, tint behavior, and a Liquid Glass thumb that morphs into clear glass while dragging.

SwiftUI (and UIKit) only ship a single-thumb slider. `RangeSlider` fills that gap with two thumbs for selecting a closed range.

## Requirements

- iOS 26.0+
- Swift 6.2+ / Xcode 26+

## Installation

Add the package to your project with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/sallar/swiftui-range-slider.git", from: "1.0.0")
]
```

Then add `RangeSlider` as a dependency of your target.

## Usage

```swift
import SwiftUI
import RangeSlider

struct ContentView: View {
    @State private var range = 0.2...0.8

    var body: some View {
        RangeSlider(range: $range)
    }
}
```

With custom bounds, stepping, and an editing callback:

```swift
RangeSlider(range: $priceRange, in: 0...500, step: 10) { editing in
    print(editing ? "began editing" : "ended editing")
}
```

The slider follows the environment's tint:

```swift
RangeSlider(range: $range)
    .tint(.orange)
```

## Behavior

- Dragging anywhere on the track grabs the nearest thumb; when the thumbs overlap, the first direction of movement decides which one moves.
- Thumbs clamp against each other — the lower bound can never exceed the upper bound.
- Both thumbs are individually accessible with VoiceOver adjustable actions.

## License

[MIT](LICENSE)
