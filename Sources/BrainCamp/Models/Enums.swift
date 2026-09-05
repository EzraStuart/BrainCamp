import SwiftUI

enum Importance: Int, Codable, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

enum ReminderScope: String, Codable, CaseIterable, Identifiable {
    case global
    case local

    var id: String { rawValue }
    var label: String { self == .global ? "Global" : "Item-specific" }
}

enum TriggerType: String, Codable, CaseIterable, Identifiable {
    case recurring
    case location
    case oneTime
    case random

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recurring: return "Recurring time"
        case .location: return "Location"
        case .oneTime: return "One-time"
        case .random: return "Random check-ins"
        }
    }

    var systemImage: String {
        switch self {
        case .recurring: return "repeat"
        case .location: return "location.fill"
        case .oneTime: return "calendar"
        case .random: return "shuffle"
        }
    }
}

enum GeofenceEvent: String, Codable, CaseIterable, Identifiable {
    case enter
    case exit
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .enter: return "Arriving"
        case .exit: return "Leaving"
        case .both: return "Arriving or leaving"
        }
    }
}

enum NotificationStyle: String, Codable, CaseIterable, Identifiable {
    case plain
    case checkIn

    var id: String { rawValue }
    var label: String { self == .plain ? "Plain alert" : "Check-in (Yes/No)" }
}

enum LogSource: String, Codable, CaseIterable, Identifiable {
    case manual
    case checkInConfirmed
    case checkInMissing
    case locationArrival
    case locationDeparture

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: return "Logged manually"
        case .checkInConfirmed: return "Confirmed via check-in"
        case .checkInMissing: return "Reported missing via check-in"
        case .locationArrival: return "Detected on arrival"
        case .locationDeparture: return "Detected on departure"
        }
    }
}

/// Sunday = 1 ... Saturday = 7, matching `Calendar`/`DateComponents.weekday`.
enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}
