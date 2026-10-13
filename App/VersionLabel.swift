import SwiftUI

/// The public version, e.g. "Version 1.2.0 (42)": CFBundleShortVersionString and
/// CFBundleVersion read from the bundle at run time, so it always names the
/// running build (MARKETING_VERSION / CURRENT_PROJECT_VERSION in project.yml).
func versionText(_ info: [String: Any]? = Bundle.main.infoDictionary) -> String {
    let version = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return "Version \(version) (\(build))"
}

/// Small muted version line for the settings screen or the main view's footer.
struct VersionLabel: View {
    var body: some View {
        Text(versionText())
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
