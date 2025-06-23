# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

This is a dual-platform SwiftUI volleyball scoring app with separate iOS and watchOS targets:

- **VolleyballController**: iOS companion app (minimal implementation)  
- **VolleyballController Watch App**: Primary watchOS app with full scoring functionality

The watchOS app implements a split-screen volleyball scoreboard with tap zones for each team, visual feedback, and match tracking across multiple sets.

## Development Commands

### Build
```bash
# Build iOS app
xcodebuild -project VolleyballController.xcodeproj -scheme "VolleyballController" build

# Build watchOS app  
xcodebuild -project VolleyballController.xcodeproj -scheme "VolleyballController Watch App" build
```

### Test
```bash
# Test iOS app
xcodebuild test -project VolleyballController.xcodeproj -scheme "VolleyballController" -destination 'platform=iOS Simulator,name=iPhone 15'

# Test watchOS app
xcodebuild test -project VolleyballController.xcodeproj -scheme "VolleyballController Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'
```

## Key Implementation Notes

- Watch app uses sophisticated gesture handling (tap to increment, long-press to decrement)
- State management tracks both per-set scores and overall match wins
- Visual feedback system with color-coded flash animations
- iOS app currently serves as placeholder companion to watchOS implementation
- Deployment targets: iOS 18.5+, watchOS 11.5+