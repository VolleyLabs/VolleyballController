# VolleyballController

A SwiftUI volleyball scoring app for iOS and Apple Watch.

## Features

### Apple Watch App
- **Split-screen scoring**: Tap left or right zones to score for each team
- **Visual feedback**: Color-coded flash animations on scoring
- **Gesture controls**: Tap to increment score, long-press to decrement
- **Match tracking**: Track wins across multiple sets
- **Set management**: Finish sets and reset global scores

### iOS App
- Companion app (minimal implementation)

## Requirements

- iOS 18.5+
- watchOS 11.5+
- Xcode 16.4+

## Getting Started

1. Open `VolleyballController.xcodeproj` in Xcode
2. Select your target device/simulator
3. Build and run the app

The Apple Watch app is the primary interface - use the left and right tap zones to score points for each team.

## Controls

- **Tap**: Increment team score
- **Long press**: Decrement team score (if score > 0)
- **Finish**: Complete current set and update match totals
- **Reset**: Reset all scores to zero

## Development

Build commands:
```bash
# iOS app
xcodebuild -project VolleyballController.xcodeproj -scheme "VolleyballController" build

# watchOS app
xcodebuild -project VolleyballController.xcodeproj -scheme "VolleyballController Watch App" build
```