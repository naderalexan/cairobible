import Combine
import Foundation

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

    private let nivClient: any NIVReadingClient
    private let svdClient: any SVDReadingClient

    init(nivClient: any NIVReadingClient, svdClient: any SVDReadingClient = BundledSVDReadingClient()) {
        self.nivClient = nivClient
        self.svdClient = svdClient
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
