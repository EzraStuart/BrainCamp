import SwiftUI

/// Requests When-In-Use location and notification permission up front, with
/// plain-language rationale first. The "Always" location upgrade is
/// deliberately deferred to the moment the user creates their first
/// location-trigger reminder (see `ReminderEditView`), matching Apple's
/// guidance against chaining permission prompts back-to-back.
struct OnboardingView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var step = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: iconName)
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(description)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: advance) {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)

            if step > 0 {
                Button("Skip for now") {
                    hasCompletedOnboarding = true
                }
                .font(.footnote)
            }
        }
        .padding(.bottom, 32)
    }

    private var iconName: String {
        switch step {
        case 0: return "brain.head.profile"
        case 1: return "location.fill"
        default: return "bell.badge.fill"
        }
    }

    private var title: String {
        switch step {
        case 0: return "Welcome to BrainCamp"
        case 1: return "Find Your Things"
        default: return "Stay Notified"
        }
    }

    private var description: String {
        switch step {
        case 0:
            return "BrainCamp reminds you about the things you tend to forget — where they belong, on a schedule, or with random check-ins."
        case 1:
            return "BrainCamp uses your location to remind you about items when you arrive at or leave a place you've designated for them, like home or the office."
        default:
            return "BrainCamp needs permission to send notifications so it can actually alert you when a reminder fires."
        }
    }

    private var buttonTitle: String {
        switch step {
        case 0: return "Get Started"
        case 1: return "Allow Location Access"
        default: return "Allow Notifications"
        }
    }

    private func advance() {
        switch step {
        case 0:
            step = 1
        case 1:
            locationManager.requestWhenInUseThenAlways()
            step = 2
        default:
            Task {
                _ = await notificationManager.requestAuthorization()
                hasCompletedOnboarding = true
            }
        }
    }
}
