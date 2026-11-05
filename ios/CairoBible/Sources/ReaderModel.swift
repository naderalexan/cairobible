import Combine
import Foundation

enum ReaderState: Equatable {
    case idle
    case loading
    case loaded(NIVChapter, String)
    case failed(String)
}

@MainActor
final class ReaderModel: ObservableObject {
    @Published private(set) var selectedBook = BibleBook.all[0]
    @Published private(set) var selectedChapter = 1
    @Published private(set) var state: ReaderState = .idle

    private let client: any NIVReadingClient

    init(client: any NIVReadingClient) {
        self.client = client
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
            let chapter = try await client.fetchChapter(book: selectedBook, number: selectedChapter)
            guard !Task.isCancelled else { return }
            state = .loaded(chapter, chapter.plainText)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error.localizedDescription)
        }
    }
}
