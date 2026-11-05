import SwiftUI

@main
struct CairoBibleApp: App {
    @StateObject private var preferences = ReadingPreferences()

    private let apiBaseURL = URL(
        string: Bundle.main.object(forInfoDictionaryKey: "BibleAPIBaseURL") as? String ?? ""
    ) ?? URL(string: "https://api.bible.cairolove.site")!

    var body: some Scene {
        WindowGroup {
            ReaderView(nivClient: NIVAPIClient(baseURL: apiBaseURL), preferences: preferences)
        }
    }
}
