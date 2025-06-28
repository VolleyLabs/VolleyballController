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
- **Background Persistence**: HealthKit workout session prevents app from sleeping during gameplay
  - Uses `WorkoutKeepAlive` service with generic workout type
  - Automatically starts when app initializes data
  - Keeps app active even when display turns off during extended volleyball sessions
  - Requires HealthKit permissions (NSHealthShareUsageDescription, NSHealthUpdateUsageDescription)
- **Accessibility**: Full VoiceOver support and AssistiveTouch compatibility
- **Configuration**: Supabase credentials via `project.local.xcconfig`
- **Deployment Targets**: iOS 18.5+, watchOS 11.5+

## File Structure

```
VolleyballController Watch App/
├── VolleyballControllerApp.swift # App entry point
├── Models/
│   ├── ScoreBoardModel.swift     # Observable game state management
│   └── ScoreModels.swift         # Data structures for Supabase payloads
├── Services/
│   ├── HapticService.swift      # Haptic feedback management
│   ├── SupabaseService.swift    # Cloud sync service
│   └── WorkoutKeepAlive.swift   # Background persistence using HealthKit
├── Views/
│   ├── ContentView.swift        # Main UI composition
│   ├── ScoreDisplayView.swift   # Score display and reset UI
│   └── TapZoneView.swift        # Reusable tap zone component
└── Assets.xcassets/             # App icons and colors
```

## Dependencies

- **Supabase Swift SDK**: Real-time database synchronization
- **SwiftUI**: Native UI framework
- **WatchKit**: Haptic feedback and device interaction
- **HealthKit**: Background app persistence during extended gameplay sessions

## Required Capabilities & Permissions

- **HealthKit**: Required for workout session background persistence
  - `NSHealthShareUsageDescription`: "Needed to start a workout session."
  - `NSHealthUpdateUsageDescription`: "Needed to record a dummy workout."
- **Network**: Required for Supabase cloud synchronization
- **Background App Refresh**: Enabled through HealthKit workout sessions