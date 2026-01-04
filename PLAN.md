# Chronicle - iOS 18+ Time Tracking App

## Overview
A personal time tracking and activity logging app with widgets, GPS tracking, diary entries, pomodoro timers, and goals.

## User Preferences (from brainstorming)
| Feature | Choice |
|---------|--------|
| UI Style | Minimal & Clean |
| Storage | iCloud Sync (CloudKit + SwiftData) |
| Widgets | Interactive Buttons + One-Tap Switch + Live Activity |
| Analytics | Timeline View (colored blocks) |
| Pomodoro | Task-Specific Settings |
| Location | Full GPS Trail + Auto-Detect Places + Geofence Triggers |
| Diary | Plain Text + Mood/Energy Tags |
| Organization | Flat Task List (no hierarchy) |
| Notifications | Full Suite (timers, summaries, geofence, idle) |
| Goals | Daily + Weekly Targets + Streaks |
| iOS Target | iOS 18+ |

---

## Project Structure

```
Chronicle/
├── Chronicle/                          # Main App Target
│   ├── App/
│   │   └── ChronicleApp.swift         # @main, ModelContainer + CloudKit
│   ├── Models/                         # SwiftData Models
│   │   ├── Task.swift                 # Core task (name, color, isFavorite)
│   │   ├── TimeEntry.swift            # Time blocks with start/end
│   │   ├── PomodoroSettings.swift     # Per-task work/break durations
│   │   ├── Place.swift                # Locations + geofence config
│   │   ├── GPSPoint.swift             # Trail coordinates
│   │   ├── DiaryEntry.swift           # Text + mood/energy
│   │   ├── Goal.swift                 # Daily/weekly targets
│   │   └── Streak.swift               # Consecutive day tracking
│   ├── ViewModels/                     # @Observable ViewModels
│   │   ├── TimeTrackingViewModel.swift
│   │   ├── PomodoroViewModel.swift
│   │   ├── LocationViewModel.swift
│   │   └── GoalsViewModel.swift
│   ├── Views/
│   │   ├── Main/                      # Timer home, active timer
│   │   ├── Tasks/                     # Task list, detail, color picker
│   │   ├── Timeline/                  # Day view with colored blocks
│   │   ├── Diary/                     # Entry list, editor, mood selector
│   │   ├── Goals/                     # Dashboard, streaks, progress
│   │   ├── Location/                  # Places, GPS trail map
│   │   └── Settings/
│   ├── Services/
│   │   ├── LocationService.swift      # CoreLocation actor
│   │   ├── GeofenceManager.swift      # Auto task triggers
│   │   ├── NotificationService.swift  # Local notifications
│   │   └── PomodoroService.swift      # Timer + alerts
│   └── Intents/                       # App Intents for widgets
│       ├── StartTaskIntent.swift
│       ├── StopTaskIntent.swift
│       └── ToggleTaskIntent.swift
│
├── ChronicleWidgets/                   # Widget Extension
│   ├── Widgets/
│   │   ├── ActiveTaskWidget.swift     # Current timer (lock screen)
│   │   └── FavoriteTasksWidget.swift  # Quick action buttons
│   ├── LiveActivity/
│   │   ├── TimerActivityAttributes.swift
│   │   └── TimerLiveActivity.swift    # Dynamic Island + Lock Screen
│   └── Controls/                      # iOS 18 Control Center
│       └── StartTaskControl.swift
│
└── Shared/                            # App Group shared data
    └── WidgetDataProvider.swift
```

---

## Implementation Phases

### Phase 1: Foundation
1. Create Xcode project using XcodeBuildMCP (iOS 18+, SwiftUI)
2. Configure App Groups and CloudKit container
3. Implement SwiftData models (Task, TimeEntry, PomodoroSettings)
4. Set up ModelContainer with CloudKit sync
5. Build TimeTrackingViewModel (start/stop/switch tasks)
6. Create basic UI: TabView, TimerHomeView, TaskListView

### Phase 2: Timeline & Pomodoro
1. Build DayTimelineView with horizontal colored blocks
2. Add date navigation and TimeEntryDetailSheet
3. Implement PomodoroService with work/break cycles
4. Add per-task pomodoro settings UI
5. Set up NotificationService for pomodoro alerts

### Phase 3: Widgets & Live Activities
1. Create Widget Extension with App Group data sharing
2. Build ActiveTaskWidget (systemSmall + accessory families)
3. Create FavoriteTasksWidget with interactive task buttons
4. Implement Live Activity for running timer (Dynamic Island)
5. Add App Intents (StartTask, StopTask, ToggleTask)
6. Build iOS 18 Control Center widget

### Phase 4: Location Features
1. Implement LocationService actor with CoreLocation
2. Add GPS trail recording (high-accuracy mode)
3. Create Place model and management UI
4. Build GeofenceManager for auto task triggers
5. Add place detection (reverse geocoding)
6. Implement battery-optimized tracking modes

### Phase 5: Diary & Goals
1. Implement DiaryEntry model and views
2. Add MoodSelector component (1-5 scale)
3. Build Goal and Streak models
4. Create GoalsDashboardView with progress
5. Add daily/weekly summary notifications

### Phase 6: Polish
1. Refine animations and haptic feedback
2. Test CloudKit sync on real devices
3. Optimize SwiftData queries
4. Add VoiceOver and Dynamic Type support

---

## Technical Constraints (SwiftData + CloudKit)

- No `@Attribute(.unique)` - CloudKit doesn't support it
- All properties need defaults or be optional
- All relationships must be optional
- Provide default empty arrays for relationships (iOS 17 bug)
- Test sync on real devices (simulator unreliable)

## Key Capabilities Required

- **App Groups**: Share data between app and widgets
- **Background Modes**: Location updates, background fetch
- **Push Notifications**: For local notifications
- **iCloud**: CloudKit container for sync
- **Location**: When In Use + Always (for geofencing)

---

## Project Setup Details

- **Location**: `/Users/kobejean/Developer/GitHub/Chronicle`
- **Signing**: Automatic with user's Apple Developer account
- **Bundle ID**: `com.[teamname].Chronicle` (will determine from account)

## First Steps (using XcodeBuildMCP)

1. ~~Create directory `/Users/kobejean/Developer/GitHub/Chronicle/`~~ (done)
2. ~~Create new iOS app project "Chronicle" with SwiftUI~~ (done)
3. Set deployment target to iOS 18.0
4. Configure automatic signing with developer account
5. Add App Group capability (`group.com.[teamname].Chronicle`)
6. Add iCloud capability with CloudKit container
7. Add Widget Extension target "ChronicleWidgets"
8. Add Background Modes (location updates)
9. Add Push Notifications capability
