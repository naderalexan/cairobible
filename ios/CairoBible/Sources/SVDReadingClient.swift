import Foundation

struct SVDChapter: Equatable {
    let bookName: String
    let chapter: Int
    let verses: [ScriptureVerse]
    let attribution: String
}

protocol SVDReadingClient {
    func fetchChapter(book: BibleBook, number: Int) async throws -> SVDChapter
}

actor BundledSVDReadingClient: SVDReadingClient {
    private let bundle: Bundle
    private var corpus: SVDCorpus?
    private var verseMap: SVDVerseMap?

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func fetchChapter(book: BibleBook, number: Int) async throws -> SVDChapter {
        let corpus = try loadCorpus()
        let verseMap = try loadVerseMap()
        guard let svdBook = corpus.books[book.svdID] else {
            throw SVDReadingError.chapterUnavailable
        }

        let chapterKey = [
            String(number),
            String(format: "%02d", number),
            String(format: "%03d", number),
        ].first { svdBook.chapters[$0] != nil }
        guard let chapterKey, let text = svdBook.chapters[chapterKey], !text.isEmpty,
              let offsets = verseMap.books[book.svdID]?[chapterKey],
              offsets.first == 0,
              zip(offsets, offsets.dropFirst()).allSatisfy({ pair in pair.0 < pair.1 }) else {
            throw SVDReadingError.chapterUnavailable
        }

        let chapterText = text as NSString
        guard offsets.allSatisfy({ $0 >= 0 && $0 < chapterText.length }) else {
            throw SVDReadingError.chapterUnavailable
        }

        let verses = offsets.enumerated().map { index, start in
            let end = index + 1 < offsets.count ? offsets[index + 1] : chapterText.length
            return ScriptureVerse(
                number: index + 1,
                text: chapterText.substring(with: NSRange(location: start, length: end - start))
            )
        }
        return SVDChapter(
            bookName: svdBook.name,
            chapter: number,
            verses: verses,
            attribution: "\(corpus.translation). \(corpus.license). Source: \(corpus.source)"
        )
    }

    private func loadCorpus() throws -> SVDCorpus {
        if let corpus { return corpus }
        let data = try resourceData(named: "arb-vd")
        let decoded = try JSONDecoder().decode(SVDCorpus.self, from: data)
        corpus = decoded
        return decoded
    }

    private func loadVerseMap() throws -> SVDVerseMap {
        if let verseMap { return verseMap }
        let data = try resourceData(named: "arb-vd-verses")
        let decoded = try JSONDecoder().decode(SVDVerseMap.self, from: data)
        verseMap = decoded
        return decoded
    }

    private func resourceData(named name: String) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw SVDReadingError.resourcesUnavailable
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw SVDReadingError.resourcesUnavailable
        }
    }
}

private struct SVDCorpus: Decodable {
    let translation: String
    let source: String
    let license: String
    let books: [String: SVDBook]
}

private struct SVDBook: Decodable {
    let name: String
    let chapters: [String: String]
}

private struct SVDVerseMap: Decodable {
    let books: [String: [String: [Int]]]
}

enum SVDReadingError: LocalizedError {
    case resourcesUnavailable
    case chapterUnavailable

    var errorDescription: String? {
        switch self {
        case .resourcesUnavailable:
            "The Arabic SVD Bible data is unavailable on this device."
        case .chapterUnavailable:
            "That Arabic SVD chapter is not available in the bundled Bible."
        }
    }
}
