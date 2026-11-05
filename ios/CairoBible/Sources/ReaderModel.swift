import Combine
import Foundation

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
