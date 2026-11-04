import Foundation

struct NIVChapter: Codable, Equatable {
    let bookName: String
    let chapter: Int
    let content: String
    let copyright: String

    var plainText: String {
        guard let data = content.data(using: .utf8),
              let text = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ],
                documentAttributes: nil
              ) else {
            return content
        }
        return text.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

protocol NIVReadingClient {
    func fetchChapter(book: BibleBook, number: Int) async throws -> NIVChapter
}

struct NIVAPIClient: NIVReadingClient {
    private static let cacheLifetime: TimeInterval = 29 * 24 * 60 * 60

    let baseURL: URL
    let session: URLSession
    private let cacheDirectory: URL
    private let now: () -> Date

    init(
        baseURL: URL,
        session: URLSession = .shared,
        cacheDirectory: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.baseURL = baseURL
        self.session = session
        self.cacheDirectory = cacheDirectory
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("NIVChapters", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("NIVChapters", isDirectory: true)
        self.now = now
    }

    func fetchChapter(book: BibleBook, number: Int) async throws -> NIVChapter {
        if let cachedChapter = cachedChapter(book: book, number: number) {
            return cachedChapter
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/api/niv/books/\(book.name)/chapters/\(number)"
        components?.query = nil
        components?.fragment = nil
        guard let url = components?.url else {
            throw NIVAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NIVAPIError.offlineUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NIVAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let detail = (try? JSONDecoder().decode(BackendError.self, from: data).detail)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NIVAPIError.backend(
                detail.flatMap { $0.isEmpty ? nil : $0 }
                    ?? "The Bible server returned an error (\(httpResponse.statusCode))."
            )
        }

        do {
            let chapter = try JSONDecoder().decode(NIVChapter.self, from: data)
            cache(chapter, book: book, number: number)
            return chapter
        } catch {
            throw NIVAPIError.invalidResponse
        }
    }

    private func cachedChapter(book: BibleBook, number: Int) -> NIVChapter? {
        let url = cacheURL(book: book, number: number)
        guard let data = try? Data(contentsOf: url),
              let cached = try? JSONDecoder().decode(CachedNIVChapter.self, from: data) else {
            return nil
        }
        let age = now().timeIntervalSince(cached.fetchedAt)
        return age >= 0 && age < Self.cacheLifetime ? cached.chapter : nil
    }

    private func cache(_ chapter: NIVChapter, book: BibleBook, number: Int) {
        guard let data = try? JSONEncoder().encode(CachedNIVChapter(fetchedAt: now(), chapter: chapter)) else {
            return
        }
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try data.write(to: cacheURL(book: book, number: number), options: .atomic)
        } catch {
            // Keep a successfully fetched chapter readable if the device cannot write its cache.
        }
    }

    private func cacheURL(book: BibleBook, number: Int) -> URL {
        cacheDirectory.appendingPathComponent("niv-\(book.id)-\(number).json")
    }
}

private struct CachedNIVChapter: Codable {
    let fetchedAt: Date
    let chapter: NIVChapter
}

private struct BackendError: Decodable {
    let detail: String
}

private enum NIVAPIError: LocalizedError {
    case offlineUnavailable
    case invalidURL
    case invalidResponse
    case backend(String)

    var errorDescription: String? {
        switch self {
        case .offlineUnavailable:
            "This chapter is not available offline. Connect to the internet and try again."
        case .invalidURL:
            "The Bible server address is invalid."
        case .invalidResponse:
            "The Bible server sent a chapter that could not be read."
        case let .backend(message):
            message
        }
    }
}
