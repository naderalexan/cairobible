import Foundation
import XCTest
@testable import CairoBible

@MainActor
final class ReaderFlowTests: XCTestCase {
    func testReaderToolbarPresetsAndLineSpacingPersistWithoutNormalizingSavedFontSize() {
        let suiteName = "ReaderToolbarPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(20.0, forKey: "readingFontSize")

        let preferences = ReadingPreferences(defaults: defaults)
        XCTAssertEqual(ReaderFontSizePreset.allCases.map(\.size), [14, 18.5, 23, 27.5, 32])
        XCTAssertEqual(ReaderFontSizePreset.nearest(to: preferences.fontSize), .s)
        XCTAssertEqual(preferences.fontSize, 20)
        XCTAssertEqual(defaults.double(forKey: "readingFontSize"), 20)
        XCTAssertEqual(preferences.lineSpacing, .l)
        XCTAssertEqual(ReaderLineSpacing.allCases.map(\.ratio), [1.2, 1.35, 1.5, 1.85, 2.0])
        XCTAssertEqual(ReaderLineSpacing.allCases.map(\.title), ["XS", "S", "M", "L", "XL"])

        preferences.setFontSize(.xl)
        preferences.setLineSpacing(.xs)

        let relaunched = ReadingPreferences(defaults: defaults)
        XCTAssertEqual(relaunched.fontSize, 32)
        XCTAssertEqual(relaunched.lineSpacing, .xs)
        XCTAssertEqual(ReaderLineSpacing.l.extraSpacing(for: 20), 17)
    }

    func testReaderLineSpacingMigratesSavedPresets() {
        let suiteName = "ReaderLineSpacingMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        for (savedValue, expectedSpacing) in [("small", ReaderLineSpacing.m), ("medium", .l), ("large", .xl)] {
            defaults.set(savedValue, forKey: "readingLineSpacing")
            XCTAssertEqual(ReadingPreferences(defaults: defaults).lineSpacing, expectedSpacing)
        }
    }

    func testAppLanguageDefaultsFromDeviceAndPersistsManualSelection() {
        XCTAssertEqual(AppLanguage.initial(preferredLanguages: ["ar-EG", "en-US"]), .ar)
        XCTAssertEqual(AppLanguage.initial(preferredLanguages: ["en-US", "ar-EG"]), .en)
        XCTAssertEqual(AppLanguage.initial(preferredLanguages: ["fr-FR"]), .en)
        XCTAssertEqual(AppLanguage.initial(preferredLanguages: []), .en)
        XCTAssertEqual(AppLanguage.en.localized("App language"), "App language")
        XCTAssertEqual(AppLanguage.ar.localized("App language"), "لغة التطبيق")

        let suiteName = "AppLanguagePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = ReadingPreferences(defaults: defaults, preferredLanguages: ["ar-EG"])
        XCTAssertEqual(preferences.appLanguage, .ar)
        preferences.setAppLanguage(.en)

        let relaunched = ReadingPreferences(defaults: defaults, preferredLanguages: ["ar-EG"])
        XCTAssertEqual(relaunched.appLanguage, .en)
    }

    func testArabicBookAndTranslationNamesAreLocalized() {
        XCTAssertTrue(BibleBook.all.allSatisfy { $0.localizedName(for: .ar) != $0.name })
        XCTAssertEqual(BibleBook.all.first?.localizedName(for: .ar), "التكوين")
        XCTAssertEqual(BibleBook.all[39].localizedName(for: .ar), "متى")
        XCTAssertTrue(BibleBook.all.allSatisfy { $0.localizedAbbreviation(for: .ar) != $0.svdID })
        XCTAssertEqual(BibleBook.all.first?.localizedAbbreviation(for: .ar), "تك")
        XCTAssertEqual(BibleBook.all.first?.localizedAbbreviation(for: .en), "GEN")
        XCTAssertEqual(BibleTranslation.svd.localizedTitle(for: .ar), "فان دايك العربية")
        XCTAssertEqual(BibleTranslation.svd.localizedTitle(for: .en), "Arabic SVD")
    }

    func testBibleBooksAreGroupedIntoOldAndNewTestaments() {
        XCTAssertEqual(BibleBook.oldTestament.count, 39)
        XCTAssertEqual(BibleBook.newTestament.count, 27)
        XCTAssertEqual(BibleBook.oldTestament.first?.name, "Genesis")
        XCTAssertEqual(BibleBook.oldTestament.last?.name, "Malachi")
        XCTAssertEqual(BibleBook.newTestament.first?.name, "Matthew")
        XCTAssertEqual(BibleBook.newTestament.last?.name, "Revelation")
        XCTAssertEqual(BibleBook.oldTestament + BibleBook.newTestament, BibleBook.all)
    }

    func testReaderPreviousAndNextChapterNavigationCrossesBookBoundaries() {
        let model = ReaderModel(nivClient: StubNIVReadingClient(), preferences: makePreferences())
        XCTAssertFalse(model.canSelectPreviousChapter)
        XCTAssertTrue(model.canSelectNextChapter)
        XCTAssertEqual(model.previousChapterAccessibilityLabel, "Previous chapter")
        XCTAssertEqual(model.nextChapterAccessibilityLabel, "Next chapter, Genesis 2")

        model.selectTranslation(.svd)
        model.selectNextChapter()
        XCTAssertEqual(model.selectedChapter, 2)
        XCTAssertEqual(model.previousChapterAccessibilityLabel, "Previous chapter, Genesis 1")
        model.selectPreviousChapter()
        XCTAssertEqual(model.selectedChapter, 1)
        model.selectPreviousChapter()
        XCTAssertEqual(model.selectedBook, BibleBook.all[0])

        model.selectChapter(model.selectedBook.chapterCount)
        XCTAssertEqual(model.nextChapterAccessibilityLabel, "Next chapter, Exodus 1")
        model.selectNextChapter()
        XCTAssertEqual(model.selectedBook, BibleBook.all[1])
        XCTAssertEqual(model.selectedChapter, 1)
        XCTAssertEqual(model.previousChapterAccessibilityLabel, "Previous chapter, Genesis 50")
        model.selectPreviousChapter()
        XCTAssertEqual(model.selectedBook, BibleBook.all[0])
        XCTAssertEqual(model.selectedChapter, BibleBook.all[0].chapterCount)
        XCTAssertEqual(model.selectedTranslation, .svd)
        XCTAssertEqual(model.preferences.translation, .svd)
    }

    func testReaderNavigationStopsAtRevelationAndGenesis() {
        let model = ReaderModel(nivClient: StubNIVReadingClient(), preferences: makePreferences())
        let revelation = BibleBook.all.last!
        model.selectBook(revelation)
        model.selectChapter(revelation.chapterCount)

        XCTAssertFalse(model.canSelectNextChapter)
        XCTAssertEqual(model.nextChapterAccessibilityLabel, "Next chapter")
        XCTAssertEqual(model.previousChapterAccessibilityLabel, "Previous chapter, Revelation 21")
        model.selectNextChapter()
        XCTAssertEqual(model.selectedBook, revelation)
        XCTAssertEqual(model.selectedChapter, revelation.chapterCount)

        model.selectPreviousChapter()
        XCTAssertEqual(model.selectedChapter, revelation.chapterCount - 1)
        let genesis = BibleBook.all[0]
        model.selectBook(genesis)
        XCTAssertFalse(model.canSelectPreviousChapter)
        XCTAssertEqual(model.previousChapterAccessibilityLabel, "Previous chapter")
        model.selectPreviousChapter()
        XCTAssertEqual(model.selectedBook, genesis)
        XCTAssertEqual(model.selectedChapter, 1)
    }

    func testReaderLoadsSelectedNIVChapterFromBackend() async {
        let cacheDirectory = makeCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        StubURLProtocol.responder = { request in
            guard request.url?.path == "/api/niv/books/John/chapters/3" else {
                return (404, Data(#"{"detail":"Unexpected request"}"#.utf8))
            }
            return (200, Data(#"{"translation":"niv","bookId":"JHN","bookName":"Jn.","chapter":3,"content":"<p><span data-number=\"1\">1</span> For God so loved the world.</p>","copyright":"NIV copyright"}"#.utf8))
        }
        defer { StubURLProtocol.responder = nil }

        let model = ReaderModel(nivClient: makeClient(cacheDirectory: cacheDirectory), preferences: makePreferences())
        model.selectBook(BibleBook.all.first { $0.name == "John" }!)
        model.selectChapter(3)
        await model.load()

        guard case let .loaded(chapter) = model.state else {
            return XCTFail("Expected the selected chapter to load, got \(model.state)")
        }
        XCTAssertEqual(chapter.bookName, "John")
        XCTAssertEqual(chapter.chapter, 3)
        XCTAssertEqual(chapter.text, "For God so loved the world.")
        XCTAssertEqual(chapter.verses, [ScriptureVerse(number: 1, text: "For God so loved the world.")])
        XCTAssertEqual(chapter.attribution, "NIV copyright")
    }

    func testReaderLoadsBundledSVDChapterWithoutNetwork() async {
        var requestCount = 0
        StubURLProtocol.responder = { _ in
            requestCount += 1
            throw URLError(.notConnectedToInternet)
        }
        defer { StubURLProtocol.responder = nil }

        let model = ReaderModel(
            nivClient: makeClient(),
            svdClient: BundledSVDReadingClient(bundle: Bundle(for: ReaderFlowTests.self)),
            preferences: makePreferences()
        )
        model.selectTranslation(.svd)
        model.selectBook(BibleBook.all.first { $0.name == "Genesis" }!)
        model.selectChapter(1)
        await model.load()

        guard case let .loaded(chapter) = model.state else {
            return XCTFail("Expected the bundled SVD chapter to load, got \(model.state)")
        }
        XCTAssertEqual(chapter.bookName, "اَلتَّكْوِينُ.")
        XCTAssertEqual(chapter.chapter, 1)
        XCTAssertEqual(chapter.verses.count, 31)
        XCTAssertEqual(chapter.verses.first?.number, 1)
        XCTAssertTrue(chapter.verses.first?.text.hasPrefix("فِي ٱلْبَدْءِ خَلَقَ ٱللهُ") == true)
        XCTAssertTrue(chapter.attribution.contains("ebible.org"))
        XCTAssertEqual(requestCount, 0)
    }

    func testReadingPreferencesApplyAcrossTranslationsAndPersistAfterRelaunch() async {
        let suiteName = "ReadingPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = ReadingPreferences(defaults: defaults)
        preferences.setFontSize(26)
        preferences.setAppearance(.dark)
        preferences.setAppLanguage(.ar)

        let model = ReaderModel(
            nivClient: StubNIVReadingClient(),
            svdClient: StubSVDReadingClient(),
            preferences: preferences
        )
        preferences.setPalette(.nile)
        await model.load()
        guard case .loaded = model.state else {
            return XCTFail("Expected the NIV chapter to load, got \(model.state)")
        }
        XCTAssertEqual(model.preferences.fontSize, 26)
        XCTAssertEqual(model.preferences.appearance, .dark)
        XCTAssertEqual(model.preferences.palette, .nile)
        XCTAssertEqual(model.preferences.appLanguage, .ar)

        model.selectTranslation(.svd)
        await model.load()
        guard case let .loaded(chapter) = model.state else {
            return XCTFail("Expected the SVD chapter to load, got \(model.state)")
        }
        XCTAssertFalse(chapter.verses.isEmpty)
        XCTAssertEqual(model.preferences.fontSize, 26)
        XCTAssertEqual(model.preferences.appearance, .dark)
        XCTAssertEqual(model.preferences.palette, .nile)

        let relaunchedPreferences = ReadingPreferences(defaults: UserDefaults(suiteName: suiteName)!)
        XCTAssertEqual(relaunchedPreferences.fontSize, 26)
        XCTAssertEqual(relaunchedPreferences.appearance, .dark)
        XCTAssertEqual(relaunchedPreferences.palette, .nile)
        XCTAssertEqual(relaunchedPreferences.appLanguage, .ar)
        XCTAssertEqual(relaunchedPreferences.translation, .svd)
        let relaunchedModel = ReaderModel(
            nivClient: StubNIVReadingClient(),
            svdClient: StubSVDReadingClient(),
            preferences: relaunchedPreferences
        )
        XCTAssertEqual(relaunchedModel.selectedTranslation, .svd)
    }

    func testReaderShowsBackendFailureMessage() async {
        let cacheDirectory = makeCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        StubURLProtocol.responder = { _ in
            (503, Data(#"{"detail":"NIV access is not enabled on the Bible server."}"#.utf8))
        }
        defer { StubURLProtocol.responder = nil }

        let model = ReaderModel(nivClient: makeClient(cacheDirectory: cacheDirectory), preferences: makePreferences())
        await model.load()

        guard case let .failed(message) = model.state else {
            return XCTFail("Expected a visible failure, got \(model.state)")
        }
        XCTAssertEqual(message, "NIV access is not enabled on the Bible server.")
    }

    func testReaderReusesFreshChapterWithoutMakingAnotherRequest() async {
        let cacheDirectory = makeCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        var requestCount = 0
        StubURLProtocol.responder = { _ in
            requestCount += 1
            return (200, Data(#"{"translation":"niv","bookId":"JHN","bookName":"John","chapter":3,"content":"<p>Saved chapter</p>","copyright":"NIV copyright"}"#.utf8))
        }
        defer { StubURLProtocol.responder = nil }

        let firstReader = ReaderModel(nivClient: makeClient(cacheDirectory: cacheDirectory), preferences: makePreferences())
        firstReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        firstReader.selectChapter(3)
        await firstReader.load()

        StubURLProtocol.responder = { _ in
            requestCount += 1
            throw URLError(.notConnectedToInternet)
        }
        let reopenedReader = ReaderModel(nivClient: makeClient(cacheDirectory: cacheDirectory), preferences: makePreferences())
        reopenedReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        reopenedReader.selectChapter(3)
        await reopenedReader.load()

        guard case let .loaded(chapter) = reopenedReader.state else {
            return XCTFail("Expected the fresh saved chapter to load, got \(reopenedReader.state)")
        }
        XCTAssertEqual(chapter.text, "Saved chapter")
        XCTAssertEqual(requestCount, 1)
    }

    func testReaderRefreshesExpiredChapterWhenOnline() async {
        let cacheDirectory = makeCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        var now = Date(timeIntervalSince1970: 2_000_000_000)
        var requestCount = 0
        StubURLProtocol.responder = { _ in
            requestCount += 1
            let content = requestCount == 1 ? "Old chapter" : "Refreshed chapter"
            return (200, Data(#"{"translation":"niv","bookId":"JHN","bookName":"John","chapter":3,"content":"<p>\#(content)</p>","copyright":"NIV copyright"}"#.utf8))
        }
        defer { StubURLProtocol.responder = nil }

        let firstReader = ReaderModel(nivClient: makeClient(cacheDirectory: cacheDirectory, now: { now }), preferences: makePreferences())
        firstReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        firstReader.selectChapter(3)
        await firstReader.load()
        now.addTimeInterval(30 * 24 * 60 * 60)

        let reopenedReader = ReaderModel(nivClient: makeClient(cacheDirectory: cacheDirectory, now: { now }), preferences: makePreferences())
        reopenedReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        reopenedReader.selectChapter(3)
        await reopenedReader.load()

        guard case let .loaded(chapter) = reopenedReader.state else {
            return XCTFail("Expected the refreshed chapter to load, got \(reopenedReader.state)")
        }
        XCTAssertEqual(chapter.text, "Refreshed chapter")
        XCTAssertEqual(requestCount, 2)
    }

    func testReaderDoesNotShowExpiredChapterWhenOffline() async {
        let cacheDirectory = makeCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        var now = Date(timeIntervalSince1970: 2_000_000_000)
        var requestCount = 0
        StubURLProtocol.responder = { _ in
            requestCount += 1
            return (200, Data(#"{"translation":"niv","bookId":"JHN","bookName":"John","chapter":3,"content":"<p>Expired chapter</p>","copyright":"NIV copyright"}"#.utf8))
        }
        defer { StubURLProtocol.responder = nil }

        let firstReader = ReaderModel(nivClient: makeClient(cacheDirectory: cacheDirectory, now: { now }), preferences: makePreferences())
        firstReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        firstReader.selectChapter(3)
        await firstReader.load()
        now.addTimeInterval(30 * 24 * 60 * 60)
        StubURLProtocol.responder = { _ in
            requestCount += 1
            throw URLError(.notConnectedToInternet)
        }

        let offlineReader = ReaderModel(nivClient: makeClient(cacheDirectory: cacheDirectory, now: { now }), preferences: makePreferences())
        offlineReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        offlineReader.selectChapter(3)
        await offlineReader.load()

        guard case let .failed(message) = offlineReader.state else {
            return XCTFail("Expected an offline unavailable state, got \(offlineReader.state)")
        }
        XCTAssertTrue(message.contains("Connect to the internet"))
        XCTAssertEqual(requestCount, 2)
    }

    func testReaderExplainsWhenRequestedChapterWasNotSaved() async {
        let cacheDirectory = makeCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        StubURLProtocol.responder = { _ in
            (200, Data(#"{"translation":"niv","bookId":"JHN","bookName":"John","chapter":3,"content":"<p>John 3</p>","copyright":"NIV copyright"}"#.utf8))
        }
        defer { StubURLProtocol.responder = nil }

        let onlineReader = ReaderModel(nivClient: makeClient(cacheDirectory: cacheDirectory), preferences: makePreferences())
        onlineReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        onlineReader.selectChapter(3)
        await onlineReader.load()
        StubURLProtocol.responder = { _ in throw URLError(.notConnectedToInternet) }

        let offlineReader = ReaderModel(nivClient: makeClient(cacheDirectory: cacheDirectory), preferences: makePreferences())
        offlineReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        offlineReader.selectChapter(4)
        await offlineReader.load()

        guard case let .failed(message) = offlineReader.state else {
            return XCTFail("Expected an unavailable state for the uncached chapter, got \(offlineReader.state)")
        }
        XCTAssertTrue(message.contains("Connect to the internet"))
    }

    func testDailyReminderEnableRequestsPermissionSchedulesLocalTimeAndPersists() async {
        let suiteName = "DailyReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scheduler = StubDailyReminderScheduler()
        let reminders = DailyReminderManager(defaults: defaults, scheduler: scheduler)

        await reminders.setEnabled(true)

        XCTAssertTrue(reminders.isEnabled)
        XCTAssertEqual(scheduler.authorizationRequestCount, 1)
        XCTAssertEqual(scheduler.scheduledTimes.count, 1)
        XCTAssertEqual(scheduler.scheduledTimes[0].hour, 9)
        XCTAssertEqual(scheduler.scheduledTimes[0].minute, 0)
        XCTAssertEqual(scheduler.scheduledLanguages, [.en])
        XCTAssertNil(scheduler.scheduledTimes[0].timeZone)
        XCTAssertNil(scheduler.scheduledTimes[0].calendar)
        XCTAssertTrue(defaults.bool(forKey: "dailyReadingReminderEnabled"))
    }

    func testDailyReminderReschedulesWhenAppLanguageChangesWithoutChangingTranslation() async {
        let suiteName = "DailyReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scheduler = StubDailyReminderScheduler()
        let reminders = DailyReminderManager(defaults: defaults, scheduler: scheduler)
        await reminders.setEnabled(true)

        await reminders.setAppLanguage(.ar)

        XCTAssertEqual(scheduler.scheduledLanguages, [.en, .ar])
        XCTAssertTrue(reminders.isEnabled)
    }

    func testNotificationContentUsesRightAlignmentForArabicAndLeftForEnglish() {
        let viewController = NotificationViewController()
        viewController.loadViewIfNeeded()

        viewController.configure(title: "عنوان", body: "نص", isRightToLeft: true)
        XCTAssertEqual(viewController.titleLabel.textAlignment, .right)
        XCTAssertEqual(viewController.bodyLabel.textAlignment, .right)
        XCTAssertEqual(viewController.titleLabel.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(viewController.view.semanticContentAttribute, .forceRightToLeft)

        viewController.configure(title: "Title", body: "Body", isRightToLeft: false)
        XCTAssertEqual(viewController.titleLabel.textAlignment, .left)
        XCTAssertEqual(viewController.bodyLabel.textAlignment, .left)
        XCTAssertEqual(viewController.titleLabel.semanticContentAttribute, .forceLeftToRight)
    }

    func testDailyReminderTimeChangeReschedulesAndPersists() async {
        let suiteName = "DailyReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scheduler = StubDailyReminderScheduler()
        let reminders = DailyReminderManager(defaults: defaults, scheduler: scheduler)
        await reminders.setEnabled(true)
        let selectedTime = Calendar.current.date(bySettingHour: 20, minute: 15, second: 0, of: Date())!

        await reminders.setReminderTime(selectedTime)

        XCTAssertEqual(scheduler.scheduledTimes.count, 2)
        XCTAssertEqual(scheduler.scheduledTimes.last?.hour, 20)
        XCTAssertEqual(scheduler.scheduledTimes.last?.minute, 15)
        let relaunched = DailyReminderManager(defaults: defaults, scheduler: StubDailyReminderScheduler())
        XCTAssertTrue(relaunched.isEnabled)
        XCTAssertEqual(Calendar.current.component(.hour, from: relaunched.time), 20)
        XCTAssertEqual(Calendar.current.component(.minute, from: relaunched.time), 15)
    }

    func testDisablingDailyReminderCancelsAndPersists() async {
        let suiteName = "DailyReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scheduler = StubDailyReminderScheduler()
        let reminders = DailyReminderManager(defaults: defaults, scheduler: scheduler)
        await reminders.setEnabled(true)

        await reminders.setEnabled(false)

        XCTAssertFalse(reminders.isEnabled)
        XCTAssertEqual(scheduler.cancellationCount, 1)
        XCTAssertFalse(defaults.bool(forKey: "dailyReadingReminderEnabled"))
    }

    func testDeniedDailyReminderPermissionShowsGuidanceWithoutScheduling() async {
        let suiteName = "DailyReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scheduler = StubDailyReminderScheduler()
        scheduler.authorizationGranted = false
        let reminders = DailyReminderManager(defaults: defaults, scheduler: scheduler)

        await reminders.setEnabled(true)

        XCTAssertFalse(reminders.isEnabled)
        XCTAssertEqual(scheduler.authorizationRequestCount, 1)
        XCTAssertTrue(scheduler.scheduledTimes.isEmpty)
        XCTAssertFalse(defaults.bool(forKey: "dailyReadingReminderEnabled"))
        XCTAssertTrue(reminders.message?.contains("Allow them in Settings") == true)
    }

    private func makePreferences() -> ReadingPreferences {
        ReadingPreferences(defaults: UserDefaults(suiteName: "ReaderFlowTests.\(UUID().uuidString)")!)
    }

    private func makeClient(
        cacheDirectory: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) -> NIVAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return NIVAPIClient(
            baseURL: URL(string: "https://reader.test")!,
            session: URLSession(configuration: configuration),
            cacheDirectory: cacheDirectory,
            now: now
        )
    }

    private func makeCacheDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

@MainActor
private final class StubDailyReminderScheduler: DailyReminderScheduling {
    var authorizationGranted = true
    var authorizationRequestCount = 0
    var scheduledTimes: [DateComponents] = []
    var scheduledLanguages: [AppLanguage] = []
    var cancellationCount = 0

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        return authorizationGranted
    }

    func scheduleDailyReminder(at time: DateComponents, appLanguage: AppLanguage) async throws {
        scheduledTimes.append(time)
        scheduledLanguages.append(appLanguage)
    }

    func cancelDailyReminder() {
        cancellationCount += 1
    }
}

private struct StubNIVReadingClient: NIVReadingClient {
    func fetchChapter(book: BibleBook, number: Int) async throws -> NIVChapter {
        NIVChapter(bookName: book.name, chapter: number, content: "In the beginning.", copyright: "NIV copyright")
    }
}

private struct StubSVDReadingClient: SVDReadingClient {
    func fetchChapter(book: BibleBook, number: Int) async throws -> SVDChapter {
        SVDChapter(
            bookName: book.name,
            chapter: number,
            verses: [ScriptureVerse(number: 1, text: "فِي ٱلْبَدْءِ")],
            attribution: "SVD"
        )
    }
}

private final class StubURLProtocol: URLProtocol {
    static var responder: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responder = Self.responder, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let statusCode: Int
        let data: Data
        do {
            (statusCode, data) = try responder(request)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
