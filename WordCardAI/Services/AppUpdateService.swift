import Foundation
import SwiftUI
import Combine

struct AppUpdateInfo: Identifiable {
    let version: String
    let trackViewURL: URL?
    let releaseNotes: String?

    var id: String { version }
}

@MainActor
class AppUpdateService: ObservableObject {
    @Published var availableUpdate: AppUpdateInfo?

    private let settingsService: SettingsService
    private var hasCheckedThisLaunch = false

    init(settingsService: SettingsService) {
        self.settingsService = settingsService
    }

    func checkForUpdatesIfNeeded() async {
        guard !hasCheckedThisLaunch else { return }
        hasCheckedThisLaunch = true
        await checkForUpdates()
    }

    func checkForUpdates() async {
        guard
            let bundleId = Bundle.main.bundleIdentifier,
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        else {
            return
        }

        let country = Locale.current.region?.identifier ?? "JP"
        guard let response = await fetchLookup(bundleId: bundleId, country: country) else { return }
        guard let app = response.results.first else { return }
        guard isVersion(app.version, newerThan: currentVersion) else { return }
        guard settingsService.settings.lastNotifiedAppVersion != app.version else { return }

        availableUpdate = AppUpdateInfo(
            version: app.version,
            trackViewURL: app.trackViewUrl.flatMap(URL.init(string:)),
            releaseNotes: app.releaseNotes
        )
    }

    func markCurrentUpdateAsNotified() {
        guard let version = availableUpdate?.version else { return }
        settingsService.updateLastNotifiedAppVersion(version)
        availableUpdate = nil
    }

    private func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        lhs.compare(rhs, options: .numeric) == .orderedDescending
    }

    private func fetchLookup(bundleId: String, country: String) async -> LookupResponse? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleId),
            URLQueryItem(name: "country", value: country),
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(LookupResponse.self, from: data)
        } catch {
            return nil
        }
    }
}

private struct LookupResponse: Decodable {
    let resultCount: Int
    let results: [LookupApp]
}

private struct LookupApp: Decodable {
    let version: String
    let trackViewUrl: String?
    let releaseNotes: String?
}
