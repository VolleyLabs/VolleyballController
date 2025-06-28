# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

This is a watchOS-first SwiftUI volleyball scoring app with cloud sync capabilities:

- **VolleyballController Watch App**: Primary watchOS app with full scoring functionality and Supabase integration
- **VolleyballController**: iOS companion app (placeholder, not actively developed)

The watchOS app implements a split-screen volleyball scoreboard with tap zones for each team, visual feedback, match tracking across multiple sets, and real-time cloud synchronization.

## Development Commands

### Build
```bash
# Build watchOS app (primary target)
xcodebuild -project VolleyballController.xcodeproj -scheme "VolleyballController Watch App" build

# Build iOS app (minimal companion)
xcodebuild -project VolleyballController.xcodeproj -scheme "VolleyballController" build
```

### Test
```bash
# Test watchOS app
xcodebuild test -project VolleyballController.xcodeproj -scheme "VolleyballController Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'

# Test iOS app
xcodebuild test -project VolleyballController.xcodeproj -scheme "VolleyballController" -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Key Implementation Notes

- **Primary Focus**: watchOS app is the main implementation with full feature set
- **Gesture Handling**: Tap to increment (+1), long-press to decrement (-1), Digital Crown support
- **State Management**: Tracks per-set scores and overall match wins with real-time sync
- **Visual Feedback**: Color-coded flash animations (blue/red) with haptic feedback
- **Cloud Sync**: Supabase integration for real-time score synchronization
  - `daily_sets` table: Current set scores
  - `daily_totals` table: Match win totals
  - Connection status indicator with visual feedback
- **Accessibility**: Full VoiceOver support and AssistiveTouch compatibility
- **Configuration**: Supabase credentials via `project.local.xcconfig`
- **Deployment Targets**: iOS 18.5+, watchOS 11.5+

## File Structure

```
VolleyballController Watch App/
├── ContentView.swift          # Main UI with scoring logic
├── SupabaseService.swift      # Cloud sync service
├── VolleyballControllerApp.swift # App entry point
└── Assets.xcassets/          # App icons and colors
```

## Dependencies

- **Supabase Swift SDK**: Real-time database synchronization
- **SwiftUI**: Native UI framework
- **WatchKit**: Haptic feedback and device interaction