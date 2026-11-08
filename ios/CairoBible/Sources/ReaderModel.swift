import Combine
import Foundation
import UserNotifications

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case ar

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var title: String { self == .en ? "English" : "العربية" }

    static func initial(preferredLanguages: [String]) -> Self {
        let primaryLanguage = preferredLanguages.first?.split(separator: "-").first?.lowercased()
        return primaryLanguage == "ar" ? .ar : .en
    }

    func localized(_ key: String) -> String {
        let mainBundle = Bundle(for: AppLanguageBundle.self)
        let path = mainBundle.path(forResource: rawValue, ofType: "lproj")
        let bundle = path.flatMap(Bundle.init(path:)) ?? mainBundle
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: localized(key), locale: locale, arguments: arguments)
    }
}

private final class AppLanguageBundle {}

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

enum ReaderFontSizePreset: String, CaseIterable, Identifiable {
    case xs, s, m, l, xl

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    var size: Double {
        switch self {
        case .xs: 14
        case .s: 18.5
        case .m: 23
        case .l: 27.5
        case .xl: 32
        }
    }

    static func nearest(to size: Double) -> Self {
        allCases.min { abs($0.size - size) < abs($1.size - size) } ?? .m
    }
}

enum ReaderLineSpacing: String, CaseIterable, Identifiable {
    case xs, s, m, l, xl

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    var ratio: Double {
        switch self {
        case .xs: 1.2
        case .s: 1.35
        case .m: 1.5
        case .l: 1.85
        case .xl: 2.0
        }
    }

    var ratioText: String {
        switch self {
        case .xs: "1.2"
        case .s: "1.35"
        case .m: "1.5"
        case .l: "1.85"
        case .xl: "2.0"
        }
    }

    func extraSpacing(for fontSize: Double) -> Double {
        fontSize * (ratio - 1)
    }
}

@MainActor
final class ReadingPreferences: ObservableObject {
    static let fontSizeRange = 14.0...32.0
    static let defaultFontSize = 17.0

    @Published private(set) var fontSize: Double
    @Published private(set) var lineSpacing: ReaderLineSpacing
    @Published private(set) var appearance: ReaderAppearance
    @Published private(set) var palette: ReaderPalette
    @Published private(set) var translation: BibleTranslation
    @Published private(set) var appLanguage: AppLanguage

    private let defaults: UserDefaults
    private let fontSizeKey = "readingFontSize"
    private let lineSpacingKey = "readingLineSpacing"
    private let appearanceKey = "readerAppearance"
    private let paletteKey = "readerPalette"
    private let translationKey = "bibleTranslation"
    private let appLanguageKey = "appLanguage"
    private let lastReadBookKey = "lastReadBook"
    private let lastReadChapterKey = "lastReadChapter"
    private let lastReadVerseKey = "lastReadVerse"
    private let recentBookVisitsKey = "recentBookVisits"
    private let recentBookVisitWindow: TimeInterval = 30 * 24 * 60 * 60

    init(defaults: UserDefaults = .standard, preferredLanguages: [String] = Locale.preferredLanguages) {
        self.defaults = defaults
        let savedFontSize = defaults.object(forKey: fontSizeKey) as? Double ?? Self.defaultFontSize
        fontSize = min(max(savedFontSize, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        switch defaults.string(forKey: lineSpacingKey) {
        case "small": lineSpacing = .m
        case "medium": lineSpacing = .l
        case "large": lineSpacing = .xl
        case let savedValue: lineSpacing = ReaderLineSpacing(rawValue: savedValue ?? "") ?? .l
        }
        appearance = ReaderAppearance(rawValue: defaults.string(forKey: appearanceKey) ?? "") ?? .system
        palette = ReaderPalette(rawValue: defaults.string(forKey: paletteKey) ?? "") ?? .cairo
        translation = BibleTranslation(rawValue: defaults.string(forKey: translationKey) ?? "") ?? .niv
        appLanguage = AppLanguage(rawValue: defaults.string(forKey: appLanguageKey) ?? "")
            ?? AppLanguage.initial(preferredLanguages: preferredLanguages)
    }

    func setFontSize(_ size: Double) {
        fontSize = min(max(size, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        defaults.set(fontSize, forKey: fontSizeKey)
    }

    func setFontSize(_ preset: ReaderFontSizePreset) {
        setFontSize(preset.size)
    }

    func setLineSpacing(_ lineSpacing: ReaderLineSpacing) {
        self.lineSpacing = lineSpacing
        defaults.set(lineSpacing.rawValue, forKey: lineSpacingKey)
    }

    func setAppearance(_ appearance: ReaderAppearance) {
        self.appearance = appearance
        defaults.set(appearance.rawValue, forKey: appearanceKey)
    }

    func setPalette(_ palette: ReaderPalette) {
        self.palette = palette
        defaults.set(palette.rawValue, forKey: paletteKey)
    }

    func setTranslation(_ translation: BibleTranslation) {
        self.translation = translation
        defaults.set(translation.rawValue, forKey: translationKey)
    }

    var lastReadLocation: (book: BibleBook, chapter: Int, verse: Int)? {
        guard
            let bookName = defaults.string(forKey: lastReadBookKey),
            let book = BibleBook.all.first(where: { $0.name == bookName })
        else {
            return nil
        }
        let chapter = defaults.integer(forKey: lastReadChapterKey)
        let verse = defaults.integer(forKey: lastReadVerseKey)
        guard (1...book.chapterCount).contains(chapter), verse > 0 else { return nil }
        return (book, chapter, verse)
    }

    func lastReadLocation(for book: BibleBook) -> (chapter: Int, verse: Int)? {
        let chapterKey = "\(lastReadChapterKey).\(book.id)"
        let verseKey = "\(lastReadVerseKey).\(book.id)"
        guard defaults.object(forKey: chapterKey) != nil else {
            guard let location = lastReadLocation, location.book == book else { return nil }
            return (location.chapter, location.verse)
        }

        let chapter = defaults.integer(forKey: chapterKey)
        let verse = defaults.integer(forKey: verseKey)
        guard (1...book.chapterCount).contains(chapter), verse > 0 else { return nil }
        return (chapter, verse)
    }

    func saveLastReadLocation(book: BibleBook, chapter: Int, verse: Int) {
        defaults.set(book.name, forKey: lastReadBookKey)
        defaults.set(chapter, forKey: lastReadChapterKey)
        defaults.set(verse, forKey: lastReadVerseKey)
        defaults.set(chapter, forKey: "\(lastReadChapterKey).\(book.id)")
        defaults.set(verse, forKey: "\(lastReadVerseKey).\(book.id)")
    }

    var recentlyVisitedBooks: [BibleBook] {
        recentlyVisitedBooks(asOf: Date())
    }

    func recentlyVisitedBooks(asOf date: Date) -> [BibleBook] {
        let cutoff = date.addingTimeInterval(-recentBookVisitWindow)
        let visits = defaults.dictionary(forKey: recentBookVisitsKey)?.compactMapValues { $0 as? Date } ?? [:]
        return BibleBook.all.enumerated().compactMap { entry -> (index: Int, book: BibleBook, date: Date)? in
            guard let visitedAt = visits[entry.element.id], visitedAt >= cutoff else { return nil }
            return (entry.offset, entry.element, visitedAt)
        }
        .sorted { lhs, rhs in
            lhs.date == rhs.date ? lhs.index < rhs.index : lhs.date > rhs.date
        }
        .map(\.book)
    }

    func recordBookVisit(_ book: BibleBook, at date: Date = Date()) {
        let cutoff = date.addingTimeInterval(-recentBookVisitWindow)
        let validBookIDs = Set(BibleBook.all.map(\.id))
        var visits = defaults.dictionary(forKey: recentBookVisitsKey)?.compactMapValues { $0 as? Date } ?? [:]
        visits = visits.filter { validBookIDs.contains($0.key) && $0.value >= cutoff }
        visits[book.id] = date
        defaults.set(visits, forKey: recentBookVisitsKey)
    }

    func setAppLanguage(_ appLanguage: AppLanguage) {
        self.appLanguage = appLanguage
        defaults.set(appLanguage.rawValue, forKey: appLanguageKey)
    }
}

@MainActor
protocol DailyReminderScheduling {
    func requestAuthorization() async throws -> Bool
    func scheduleDailyReminder(at time: DateComponents, appLanguage: AppLanguage) async throws
    func cancelDailyReminder()
}

@MainActor
private struct LocalDailyReminderScheduler: DailyReminderScheduling {
    private var center: UNUserNotificationCenter { .current() }
    private let identifier = "daily-reading-reminder"

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func scheduleDailyReminder(at time: DateComponents, appLanguage: AppLanguage) async throws {
        let category = UNNotificationCategory(identifier: identifier, actions: [], intentIdentifiers: [])
        center.setNotificationCategories([category])

        let content = UNMutableNotificationContent()
        content.title = appLanguage.localized("Time to read the Bible")
        content.body = appLanguage.localized("Take a moment for your daily reading.")
        content.categoryIdentifier = identifier
        content.userInfo = ["appLanguage": appLanguage.rawValue]
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
    private var appLanguage: AppLanguage

    init(
        defaults: UserDefaults = .standard,
        scheduler: (any DailyReminderScheduling)? = nil,
        appLanguage: AppLanguage = .en
    ) {
        self.defaults = defaults
        self.scheduler = scheduler ?? LocalDailyReminderScheduler()
        self.appLanguage = appLanguage
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
                message = appLanguage.localized("Notifications are disabled. Allow them in Settings to receive daily reminders.")
                return
            }
            try await scheduleReminder()
            isEnabled = true
            defaults.set(true, forKey: enabledKey)
        } catch {
            message = appLanguage.localized("Couldn't schedule the reminder. Please try again.")
        }
    }

    func setAppLanguage(_ appLanguage: AppLanguage) async {
        self.appLanguage = appLanguage
        guard isEnabled else { return }
        do {
            try await scheduleReminder()
        } catch {
            message = appLanguage.localized("Couldn't update the reminder. Please try again.")
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
                message = appLanguage.localized("Couldn't update the reminder. Please try again.")
            }
        }
    }

    private func scheduleReminder() async throws {
        var components = DateComponents()
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        try await scheduler.scheduleDailyReminder(at: components, appLanguage: appLanguage)
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

    var readerControlTitle: String {
        switch self {
        case .niv: "EN - NIV"
        case .svd: "العربية"
        }
    }

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

    func localizedTitle(for appLanguage: AppLanguage) -> String {
        appLanguage.localized(title)
    }

    var isRightToLeft: Bool { self == .svd }

    func isForwardChapterSwipe(horizontalTranslation: CGFloat) -> Bool {
        isRightToLeft ? horizontalTranslation > 0 : horizontalTranslation < 0
    }
}

struct ScriptureVerse: Equatable, Identifiable {
    let number: Int
    let text: String

    var id: Int { number }

    func copyText(book: BibleBook, chapter: Int, appLanguage: AppLanguage) -> String {
        "\"\(text)\" -\(book.localizedName(for: appLanguage)) \(chapter):\(number)"
    }
}

struct ReaderChapter: Equatable {
    let bookName: String
    let chapter: Int
    let text: String
    let verses: [ScriptureVerse]
    let attribution: String
}

struct ReaderChapterLocation: Equatable {
    let book: BibleBook
    let chapter: Int
}

@MainActor
final class ReaderModel: ObservableObject {
    @Published private(set) var selectedTranslation: BibleTranslation
    @Published private(set) var selectedBook = BibleBook.all[0]
    @Published private(set) var selectedChapter = 1
    @Published private(set) var selectedVerse = 1
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
        let preferences = preferences ?? ReadingPreferences()
        self.preferences = preferences
        selectedTranslation = preferences.translation
        if let location = preferences.lastReadLocation {
            selectedBook = location.book
            selectedChapter = location.chapter
            selectedVerse = location.verse
        }
        preferences.recordBookVisit(selectedBook)
    }

    func selectTranslation(_ translation: BibleTranslation) {
        selectedTranslation = translation
        preferences.setTranslation(translation)
        state = .idle
    }

    func selectBook(_ book: BibleBook) {
        let location = preferences.lastReadLocation(for: book)
        selectedBook = book
        selectedChapter = location?.chapter ?? 1
        selectedVerse = location?.verse ?? 1
        saveLastReadLocation()
        preferences.recordBookVisit(book)
        state = .idle
    }

    func selectChapter(_ chapter: Int) {
        selectedChapter = min(max(chapter, 1), selectedBook.chapterCount)
        selectedVerse = 1
        saveLastReadLocation()
        state = .idle
    }

    func selectVerse(_ verse: Int) {
        guard verse > 0, verse != selectedVerse else { return }
        selectedVerse = verse
        saveLastReadLocation()
    }

    private func saveLastReadLocation() {
        preferences.saveLastReadLocation(book: selectedBook, chapter: selectedChapter, verse: selectedVerse)
    }

    var previousChapterLocation: ReaderChapterLocation? {
        if selectedChapter > 1 {
            return ReaderChapterLocation(book: selectedBook, chapter: selectedChapter - 1)
        }
        guard let index = BibleBook.all.firstIndex(of: selectedBook), index > 0 else { return nil }
        let book = BibleBook.all[index - 1]
        return ReaderChapterLocation(book: book, chapter: book.chapterCount)
    }

    var nextChapterLocation: ReaderChapterLocation? {
        if selectedChapter < selectedBook.chapterCount {
            return ReaderChapterLocation(book: selectedBook, chapter: selectedChapter + 1)
        }
        guard let index = BibleBook.all.firstIndex(of: selectedBook), index < BibleBook.all.count - 1 else { return nil }
        return ReaderChapterLocation(book: BibleBook.all[index + 1], chapter: 1)
    }

    var canSelectPreviousChapter: Bool { previousChapterLocation != nil }
    var canSelectNextChapter: Bool { nextChapterLocation != nil }

    var previousChapterAccessibilityLabel: String {
        if selectedChapter > 1 {
            return preferences.appLanguage.format("Previous chapter, %@ %d", selectedBook.localizedName(for: preferences.appLanguage), selectedChapter - 1)
        }
        guard let index = BibleBook.all.firstIndex(of: selectedBook), index > 0 else {
            return preferences.appLanguage.localized("Previous chapter")
        }
        let book = BibleBook.all[index - 1]
        return preferences.appLanguage.format("Previous chapter, %@ %d", book.localizedName(for: preferences.appLanguage), book.chapterCount)
    }

    var nextChapterAccessibilityLabel: String {
        if selectedChapter < selectedBook.chapterCount {
            return preferences.appLanguage.format("Next chapter, %@ %d", selectedBook.localizedName(for: preferences.appLanguage), selectedChapter + 1)
        }
        guard let index = BibleBook.all.firstIndex(of: selectedBook), index < BibleBook.all.count - 1 else {
            return preferences.appLanguage.localized("Next chapter")
        }
        return preferences.appLanguage.format("Next chapter, %@ 1", BibleBook.all[index + 1].localizedName(for: preferences.appLanguage))
    }

    func selectPreviousChapter() {
        if selectedChapter > 1 {
            selectChapter(selectedChapter - 1)
        } else if let index = BibleBook.all.firstIndex(of: selectedBook), index > 0 {
            selectedBook = BibleBook.all[index - 1]
            selectedChapter = selectedBook.chapterCount
            selectedVerse = 1
            saveLastReadLocation()
            preferences.recordBookVisit(selectedBook)
            state = .idle
        }
    }

    func selectNextChapter() {
        if selectedChapter < selectedBook.chapterCount {
            selectChapter(selectedChapter + 1)
        } else if let index = BibleBook.all.firstIndex(of: selectedBook), index < BibleBook.all.count - 1 {
            selectedBook = BibleBook.all[index + 1]
            selectedChapter = 1
            selectedVerse = 1
            saveLastReadLocation()
            preferences.recordBookVisit(selectedBook)
            state = .idle
        }
    }

    func previewChapter(at location: ReaderChapterLocation) async -> ReaderChapter? {
        do {
            let chapter = try await fetchChapter(book: location.book, number: location.chapter)
            return Task.isCancelled ? nil : chapter
        } catch {
            return nil
        }
    }

    func load() async {
        state = .loading
        do {
            let chapter = try await fetchChapter(book: selectedBook, number: selectedChapter)
            guard !Task.isCancelled else { return }
            if let firstVerse = chapter.verses.first?.number, !chapter.verses.contains(where: { $0.number == selectedVerse }) {
                selectedVerse = chapter.verses.last(where: { $0.number <= selectedVerse })?.number ?? firstVerse
                saveLastReadLocation()
            }
            state = .loaded(chapter)
        } catch {
            guard !Task.isCancelled else { return }
            let key: String
            switch error {
            case let NIVAPIError.backend(message):
                state = .failed(message)
                return
            case NIVAPIError.offlineUnavailable:
                key = "This chapter is not available offline. Connect to the internet and try again."
            case NIVAPIError.invalidURL:
                key = "The Bible server address is invalid."
            case NIVAPIError.invalidResponse:
                key = "The Bible server sent a chapter that could not be read."
            case SVDReadingError.resourcesUnavailable:
                key = "The Arabic SVD Bible data is unavailable on this device."
            case SVDReadingError.chapterUnavailable:
                key = "That Arabic SVD chapter is not available in the bundled Bible."
            default:
                key = "Couldn't load this chapter. Please try again."
            }
            state = .failed(preferences.appLanguage.localized(key))
        }
    }

    private func fetchChapter(book: BibleBook, number: Int) async throws -> ReaderChapter {
        switch selectedTranslation {
        case .niv:
            let chapter = try await nivClient.fetchChapter(book: book, number: number)
            return ReaderChapter(
                bookName: book.name,
                chapter: chapter.chapter,
                text: chapter.plainText,
                verses: chapter.verses,
                attribution: chapter.copyright
            )
        case .svd:
            let chapter = try await svdClient.fetchChapter(book: book, number: number)
            return ReaderChapter(
                bookName: chapter.bookName,
                chapter: chapter.chapter,
                text: chapter.verses.map(\.text).joined(),
                verses: chapter.verses,
                attribution: chapter.attribution
            )
        }
    }
}
