import Foundation

struct NIVChapter: Codable, Equatable {
    let bookName: String
    let chapter: Int
    let content: String
    let copyright: String

    var plainText: String {
        let parsedVerses = verses
        return parsedVerses.isEmpty
            ? Self.text(fromHTML: content)
            : parsedVerses.map(\.text).joined(separator: " ")
    }

    var verses: [ScriptureVerse] {
        let pattern = #"(?is)<span\b[^>]*\bdata-number\s*=\s*["'](\d+)["'][^>]*>.*?</span>(.*?)(?=<span\b[^>]*\bdata-number\s*=|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let source = content as NSString
        return regex.matches(in: content, range: NSRange(location: 0, length: source.length)).compactMap { match in
            guard let numberRange = Range(match.range(at: 1), in: content),
                  let bodyRange = Range(match.range(at: 2), in: content),
                  let number = Int(content[numberRange]) else { return nil }
            let text = Self.text(fromHTML: String(content[bodyRange]))
            guard !text.isEmpty else { return nil }
            return ScriptureVerse(number: number, text: text)
        }
    }

    private static func text(fromHTML html: String) -> String {
        let withBreaks = html.replacingOccurrences(
            of: #"(?i)<br\s*/?>|</(?:p|div|li|h[1-6])\s*>"#,
            with: " ",
            options: .regularExpression
        )
        let withoutTags = withBreaks.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
        return decodeHTMLEntities(withoutTags)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z][a-zA-Z0-9]+);"#) else {
            return text
        }
        let source = text as NSString
        let result = NSMutableString(string: text)
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)).reversed() {
            guard let valueRange = Range(match.range(at: 1), in: text) else { continue }
            let value = String(text[valueRange])
            let decoded: String?
            if value.hasPrefix("#x") {
                decoded = UInt32(value.dropFirst(2), radix: 16).flatMap(UnicodeScalar.init).map(String.init)
            } else if value.hasPrefix("#") {
                decoded = UInt32(value.dropFirst()).flatMap(UnicodeScalar.init).map(String.init)
            } else {
                decoded = [
                    "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
                    "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "ndash": "–", "mdash": "—", "hellip": "…"
                ][value]
            }
            if let decoded {
                result.replaceCharacters(in: match.range, with: decoded)
            }
        }
        return result as String
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
