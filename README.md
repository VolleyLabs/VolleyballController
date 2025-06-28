# VolleyballController

A watchOS-first SwiftUI volleyball scoring app with real-time cloud synchronization.

![image](https://github.com/user-attachments/assets/316dd1fe-60f7-4934-a66e-ec01bf33a8c3)

## Features

### Apple Watch App (Primary)
- **Split-screen scoring**: Tap left or right zones to score for each team
- **Advanced gesture controls**: 
  - Tap to increment score (+1)
  - Long-press to decrement score (-1)
  - Digital Crown support for precise adjustments
- **Visual & haptic feedback**: 
  - Color-coded flash animations (blue/red)
  - Distinct haptic patterns for each team
- **Match tracking**: Track wins across multiple sets with persistent storage
- **Cloud synchronization**: Real-time Supabase integration
  - Automatic score syncing across devices
  - Connection status indicator
  - Optimistic updates with error handling
- **Background persistence**: Stays active during extended gameplay
  - Uses HealthKit workout session to prevent app sleeping
  - Perfect for 2+ hour volleyball sessions
  - Automatically activates when app starts
- **Accessibility**: Full VoiceOver and AssistiveTouch support

### iOS App
- Companion app (placeholder - not actively developed)

## Requirements

- **watchOS 11.5+** (primary platform)
- iOS 18.5+ (companion)
- Xcode 16.4+
- Supabase account (for cloud sync)
- **HealthKit permissions** (for background persistence during gameplay)

## Getting Started

### Basic Setup
1. Open `VolleyballController.xcodeproj` in Xcode
2. Select Apple Watch target/simulator 
3. Build and run the app
4. Grant HealthKit permissions when prompted (required for background persistence)

### Cloud Sync Setup (Optional)
1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Copy `project.local.xcconfig` and update with your credentials:
   ```
   SUPABASE_URL = your_supabase_url
   SUPABASE_ANON_KEY = your_anon_key
   ```
3. Create these tables in your Supabase database:
   ```sql
   -- Daily set scores
   CREATE TABLE daily_sets (
     day DATE PRIMARY KEY,
     left_score INTEGER DEFAULT 0,
     right_score INTEGER DEFAULT 0
   );
   
   -- Daily match totals
   CREATE TABLE daily_totals (
     day DATE PRIMARY KEY,
     left_wins INTEGER DEFAULT 0,
     right_wins INTEGER DEFAULT 0
   );
   ```

## Controls

- **Tap zone**: Increment team score (+1)
- **Long press zone**: Decrement team score (-1) 
- **Digital Crown**: Fine-tune scores when zone is focused
- **Finish button**: Complete current set and update match totals
- **Reset button**: Reset all scores and match totals to zero

## Architecture

The app uses a clean SwiftUI architecture with:
- **ContentView.swift**: Main scoring interface with gesture handling
- **ScoreBoardModel.swift**: Observable state management with workout session integration
- **SupabaseService.swift**: Cloud synchronization service
- **WorkoutKeepAlive.swift**: HealthKit-based background persistence service
- **State management**: Local state with optimistic cloud updates
- **Background persistence**: HealthKit workout sessions prevent app sleeping
- **Error handling**: Graceful degradation when offline

## Development

### Build Commands
```bash
# Primary watchOS app
xcodebuild -project VolleyballController.xcodeproj -scheme "VolleyballController Watch App" build

# iOS companion
xcodebuild -project VolleyballController.xcodeproj -scheme "VolleyballController" build
```

### Testing
```bash
# watchOS tests
xcodebuild test -project VolleyballController.xcodeproj -scheme "VolleyballController Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'
```

## Dependencies

- [Supabase Swift SDK](https://github.com/supabase/supabase-swift): Real-time database
- SwiftUI: Native UI framework  
- WatchKit: Haptic feedback and device interaction
- HealthKit: Background app persistence during extended gameplay sessions

## Permissions & Privacy

The app requires the following permissions:
- **HealthKit Access**: Used to start a dummy workout session that keeps the app active during extended volleyball games (2+ hours). No health data is collected or stored - this is purely for background app persistence.
- **Network Access**: Required for real-time score synchronization with Supabase (optional feature)
