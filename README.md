# BrainCamp

An iPhone/iPad app for people who lose things: track your belongings, give
each one a designated place, and get nudged by location-based, time-based,
and random check-in notifications.

See `spec.md` for the data model this app is built from.

## Building (on a Mac, in Xcode)

This repo was authored on Linux, so there's no `.xcodeproj` checked in —
[XcodeGen](https://github.com/yonaskolb/XcodeGen) generates it from
`project.yml` + the `Sources/` tree.

```sh
brew install xcodegen
cd BrainCamp
xcodegen generate
open BrainCamp.xcodeproj
```

Then in Xcode: select the `BrainCamp` scheme, pick an iOS 17+ simulator (or a
device), and Run (⌘R).

If you're pulling this onto a different machine (e.g. over a git remote),
just `git clone`/`git pull` and re-run `xcodegen generate` — the generated
`.xcodeproj` isn't checked in and is safe to regenerate any time the source
tree changes. Re-run it whenever `project.yml` or the file list changes
(new/removed/renamed Swift files).

Requires:
- Xcode 15+ (for SwiftData, which needs an iOS 17+ deployment target)
- A Mac, since SwiftUI/SwiftData/CoreLocation/MapKit/UserNotifications don't
  exist outside Apple's toolchain

## What to test once it's running

- **Onboarding**: complete it, granting When-In-Use location and
  notifications (the "Always" location upgrade is prompted later, the first
  time you create a location-trigger reminder — this is intentional, not a
  bug, to avoid stacking two location prompts back to back).
- **Add an item**: give it a name, importance, and a designated place (drop a
  pin or search, then size the geofence radius).
- **Add reminders**: try a recurring reminder (pick weekdays + a time), a
  random check-in (N times/day in a window — check-in notifications carry
  Yes/No actions), and a location reminder (arrives/leaves a place). Mark one
  "One-time use" and confirm it disables itself after firing once.
- **Location testing in the simulator**: Xcode's simulator can simulate
  location and simulate entering/leaving a custom coordinate
  (Debug ▸ Location ▸ Custom Location, or use a GPX file) — use this to
  trigger geofence notifications without physically moving.
- **Settings tab**: confirm it shows real permission status and a sensible
  "X of Y places monitored" / "pending notifications" count.

## Known rough edges to watch for

- SwiftData's `#Predicate` macro comparing a stored enum property to a
  specific case (used throughout `LocationManager`/`NotificationManager`/
  `RandomReminderScheduler` to filter reminders by `triggerType`) has had bugs
  on early iOS 17.0 in some Xcode versions. If a `context.fetch(descriptor)`
  call throws or silently returns nothing where you'd expect results, try a
  newer iOS 17.x simulator runtime first before assuming the model/query
  logic itself is wrong.
- Region monitoring is capped by iOS at 20 places per app; if you have more
  than 20 location-triggered reminders' worth of places, BrainCamp only
  actively monitors the top 20 (ranked by item importance, then proximity) —
  Settings shows how many are actually active.
- Random and one-time reminders are (re)scheduled when the app is foregrounded
  or launched, not via a background task — if the app isn't opened for
  several days, some random check-ins in that gap will be missed. This is a
  deliberate MVP simplification (see `RandomReminderScheduler.swift`).
