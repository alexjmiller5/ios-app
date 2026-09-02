import PostHog
import SwiftUI

// House-standard analytics (see AGENTS.md): this app gets its OWN PostHog
// project, created at scaffold time. Publishable key, not a secret -
// empty = analytics disabled.
private let posthogAPIKey = ""

@main
struct MainApp: App {
    init() {
        if !posthogAPIKey.isEmpty {
            let config = PostHogConfig(apiKey: posthogAPIKey, host: "https://us.i.posthog.com")
            PostHogSDK.shared.setup(config)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
