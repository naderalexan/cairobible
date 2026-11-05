import Combine
import Foundation
import UserNotifications

enum ReaderAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

enum ReaderPalette: String, CaseIterable, Identifiable {
    case cairo
    case olive
    case nile
    case amethyst
    case sandstone

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

@MainActor
final class ReadingPreferences: ObservableObject {
    static let fontSizeRange = 14.0...32.0
    static let defaultFontSize = 17.0

    @Published private(set) var fontSize: Double
    @Published private(set) var appearance: ReaderAppearance
    @Published private(set) var palette: ReaderPalette

    private let defaults: UserDefaults
    private let fontSizeKey = "readingFontSize"
    private let appearanceKey = "readerAppearance"
    private let paletteKey = "readerPalette"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedFontSize = defaults.object(forKey: fontSizeKey) as? Double ?? Self.defaultFontSize
        fontSize = min(max(savedFontSize, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        appearance = ReaderAppearance(rawValue: defaults.string(forKey: appearanceKey) ?? "") ?? .system
        palette = ReaderPalette(rawValue: defaults.string(forKey: paletteKey) ?? "") ?? .cairo
    }

    func setFontSize(_ size: Double) {
        fontSize = min(max(size, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        defaults.set(fontSize, forKey: fontSizeKey)
    }

    func setAppearance(_ appearance: ReaderAppearance) {
        self.appearance = appearance
        defaults.set(appearance.rawValue, forKey: appearanceKey)
    }

    func setPalette(_ palette: ReaderPalette) {
        self.palette = palette
        defaults.set(palette.rawValue, forKey: paletteKey)
    }
}

@MainActor
protocol DailyReminderScheduling {
    func requestAuthorization() async throws -> Bool
    func scheduleDailyReminder(at time: DateComponents) async throws
    func cancelDailyReminder()
}

@MainActor
private struct LocalDailyReminderScheduler: DailyReminderScheduling {
    private var center: UNUserNotificationCenter { .current() }
    private let identifier = "daily-reading-reminder"

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func scheduleDailyReminder(at time: DateComponents) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Time to read the Bible"
        content.body = "Take a moment for your daily reading."
        content.sound = .default
        try await center.add(UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        ))
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

@MainActor
final class DailyReminderManager: ObservableObject {
    private static let defaultMinuteOfDay = 9 * 60

    @Published private(set) var isEnabled: Bool
    @Published private(set) var time: Date
    @Published private(set) var message: String?
    @Published private(set) var isRequestingAuthorization = false

    private let defaults: UserDefaults
    private let scheduler: any DailyReminderScheduling
    private let enabledKey = "dailyReadingReminderEnabled"
    private let minuteOfDayKey = "dailyReadingReminderMinuteOfDay"
    private var minuteOfDay: Int

    init(defaults: UserDefaults = .standard, scheduler: (any DailyReminderScheduling)? = nil) {
        self.defaults = defaults
        self.scheduler = scheduler ?? LocalDailyReminderScheduler()
        isEnabled = defaults.bool(forKey: enabledKey)
        minuteOfDay = min(max(defaults.object(forKey: minuteOfDayKey) as? Int ?? Self.defaultMinuteOfDay, 0), 1439)
        time = Self.date(for: minuteOfDay)
    }

    func setEnabled(_ enabled: Bool) async {
        guard !isRequestingAuthorization else { return }
        guard enabled != isEnabled else { return }

        message = nil
        guard enabled else {
            isEnabled = false
            defaults.set(false, forKey: enabledKey)
            scheduler.cancelDailyReminder()
            return
        }

        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }

        do {
            guard try await scheduler.requestAuthorization() else {
                message = "Notifications are disabled. Allow them in Settings to receive daily reminders."
                return
            }
            try await scheduleReminder()
            isEnabled = true
            defaults.set(true, forKey: enabledKey)
        } catch {
            message = "Couldn't schedule the reminder. Please try again."
        }
    }

    func setReminderTime(_ date: Date) async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        defaults.set(minuteOfDay, forKey: minuteOfDayKey)
        time = Self.date(for: minuteOfDay)
        message = nil
        if isEnabled {
            do {
                try await scheduleReminder()
            } catch {
                message = "Couldn't update the reminder. Please try again."
            }
        }
    }

    private func scheduleReminder() async throws {
        var components = DateComponents()
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        try await scheduler.scheduleDailyReminder(at: components)
    }

    private static func date(for minuteOfDay: Int) -> Date {
        let now = Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        components.second = 0
        return Calendar.current.date(from: components) ?? now
    }
}

enum ReaderState: Equatable {
    case idle
    case loading
    case loaded(ReaderChapter)
    case failed(String)
}

enum BibleTranslation: String, CaseIterable, Identifiable {
    case niv
    case svd

    var id: String { rawValue }

    var title: String {
        switch self {
        case .niv: "NIV"
        case .svd: "Arabic SVD"
        }
    }

    var sectionTitle: String {
        switch self {
        case .niv: "New International Version"
        case .svd: "Smith & Van Dyck (SVD)"
        }
    }

    var isRightToLeft: Bool { self == .svd }
}

struct ScriptureVerse: Equatable, Identifiable {
    let number: Int
    let text: String

    var id: Int { number }
}

struct ReaderChapter: Equatable {
    let bookName: String
    let chapter: Int
    let text: String
    let verses: [ScriptureVerse]
    let attribution: String
}

@MainActor
final class ReaderModel: ObservableObject {
    @Published private(set) var selectedTranslation = BibleTranslation.niv
    @Published private(set) var selectedBook = BibleBook.all[0]
    @Published private(set) var selectedChapter = 1
    @Published private(set) var state: ReaderState = .idle

    let preferences: ReadingPreferences
    private let nivClient: any NIVReadingClient
    private let svdClient: any SVDReadingClient

    init(
        nivClient: any NIVReadingClient,
        svdClient: any SVDReadingClient = BundledSVDReadingClient(),
        preferences: ReadingPreferences? = nil
    ) {
        self.nivClient = nivClient
        self.svdClient = svdClient
        self.preferences = preferences ?? ReadingPreferences()
    }

    func selectTranslation(_ translation: BibleTranslation) {
        selectedTranslation = translation
        state = .idle
    }

    func selectBook(_ book: BibleBook) {
        selectedBook = book
        selectedChapter = 1
        state = .idle
    }

    func selectChapter(_ chapter: Int) {
        selectedChapter = min(max(chapter, 1), selectedBook.chapterCount)
        state = .idle
    }

    func load() async {
        state = .loading
        do {
            let chapter: ReaderChapter
            switch selectedTranslation {
            case .niv:
                let nivChapter = try await nivClient.fetchChapter(book: selectedBook, number: selectedChapter)
                chapter = ReaderChapter(
                    bookName: nivChapter.bookName,
                    chapter: nivChapter.chapter,
                    text: nivChapter.plainText,
                    verses: [],
                    attribution: nivChapter.copyright
                )
            case .svd:
                let svdChapter = try await svdClient.fetchChapter(book: selectedBook, number: selectedChapter)
                chapter = ReaderChapter(
                    bookName: svdChapter.bookName,
                    chapter: svdChapter.chapter,
                    text: svdChapter.verses.map(\.text).joined(),
                    verses: svdChapter.verses,
                    attribution: svdChapter.attribution
                )
            }
            guard !Task.isCancelled else { return }
            state = .loaded(chapter)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error.localizedDescription)
        }
    }
}
