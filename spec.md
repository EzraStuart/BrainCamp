# BrainCamp Spec

## Items

Items are their own objects.
Properties:
    - Name
    - Notes (optional)
    - Importance: low / medium / high / critical
    - Icon (optional, system icon name)
    - Designated Place (a Place, see below)
    - Local Reminders (Reminders attached to this item)
    - Last Seen Entries (log of where the item was actually seen/logged)

## Places

A Place is its own reusable object (so multiple items can share one, e.g. "Home", "Desk").
Properties:
    - Name
    - Latitude / Longitude
    - Radius (meters) — defines the geofence for location reminders
    - Items (the items whose designated place this is)

## Reminders

Reminders are their own objects too, each with a unique id.
Local reminders are attached to their item; globals are attached to the global state (item = none).

Properties:
    - Title
    - Scope: global (not tied to one item; can reference other items or none) / local (tied to a specific item)
    - Trigger type: recurring time / location / one-time / random
        - Recurring: weekdays + hour/minute
        - Location: a Place + event (enter / exit / both)
        - One-time: a specific date/time
        - Random: N times per day within a time window (e.g. 3 times between 9am–9pm)
    - Notification style: plain (just an alert) / check-in (asks "Do you have it? Is it in its designated place?" with Yes/No actions)
    - Enabled (on/off)
        - Should also have some transcience so that you can set a recurring reminder for your earrings when you are out one time

## Last Seen Entries

Records where/when an item was actually confirmed to be, either logged manually or from a check-in notification response.
Properties:
    - Timestamp
    - Item
    - Place (may differ from the item's designated place)
    - Source: manual / check-in confirmed / check-in missing / location arrival / location departure
    - Note (optional)
    - Related reminder (optional, if triggered by one)