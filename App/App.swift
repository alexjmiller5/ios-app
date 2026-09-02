import PostHog
import SwiftUI

// House-standard analytics (see AGENTS.md): one shared PostHog project
// across all of Alex's apps, segmented by the `app` super property.
// Publishable key, not a secret - fill from the shared 1P item at scaffold
// time; empty = analytics disabled.
private let posthogAPIKey = ""

@main
struct MainApp: App {
    init() {
        if !posthogAPIKey.isEmpty {
            let config = PostHogConfig(apiKey: posthogAPIKey, host: "https://us.i.posthog.com")
            PostHogSDK.shared.setup(config)
            PostHogSDK.shared.register(["app": Bundle.main.bundleIdentifier ?? "unknown"])
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
