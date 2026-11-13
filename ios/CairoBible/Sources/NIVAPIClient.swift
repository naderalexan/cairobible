import Foundation

struct NIVChapter: Codable, Equatable {
    let bookName: String
    let chapter: Int
    let content: String
    let headings: [NIVHeading]
    let copyright: String

    private enum CodingKeys: String, CodingKey {
        case bookName, chapter, content, headings, copyright
    }

    init(bookName: String, chapter: Int, content: String, headings: [NIVHeading] = [], copyright: String) {
        self.bookName = bookName
        self.chapter = chapter
        self.content = content
        self.headings = headings.isEmpty ? Self.sourceHeadings(fromHTML: content) : headings
        self.copyright = copyright
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        bookName = try values.decode(String.self, forKey: .bookName)
        chapter = try values.decode(Int.self, forKey: .chapter)
        content = try values.decode(String.self, forKey: .content)
        let suppliedHeadings = try values.decodeIfPresent([NIVHeading].self, forKey: .headings) ?? []
        headings = suppliedHeadings.isEmpty ? Self.sourceHeadings(fromHTML: content) : suppliedHeadings
        copyright = try values.decode(String.self, forKey: .copyright)
    }

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
            let text = Self.text(fromHTML: Self.withoutHeadingParagraphs(String(content[bodyRange])))
            guard !text.isEmpty else { return nil }
            return ScriptureVerse(number: number, text: text)
        }
    }

    var contentItems: [ScriptureContentItem] {
        var items = Self.contentItems(fromHTML: content)
        for heading in headings where !items.contains(where: {
            if case let .heading(item) = $0 { return item == heading }
            return false
        }) {
            let insertionIndex = heading.afterVerse.flatMap { verse in
                items.lastIndex(where: { $0.verseNumber == verse }).map { $0 + 1 }
            } ?? 0
            items.insert(.heading(heading), at: insertionIndex)
        }
        return items
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

    private static func withoutHeadingParagraphs(_ html: String) -> String {
        guard let paragraphs = try? NSRegularExpression(pattern: #"(?is)<p\b([^>]*)>(.*?)</p>"#),
              let classAttribute = try? NSRegularExpression(pattern: #"(?i)\bclass\s*=\s*["']([^"']*)["']"#) else {
            return html
        }
        let source = html as NSString
        let result = NSMutableString(string: html)
        for paragraph in paragraphs.matches(in: html, range: NSRange(location: 0, length: source.length)).reversed() {
            let attributes = source.substring(with: paragraph.range(at: 1)) as NSString
            let attributeText = attributes as String
            guard let match = classAttribute.firstMatch(in: attributeText, range: NSRange(location: 0, length: attributes.length)),
                  let classRange = Range(match.range(at: 1), in: attributeText) else { continue }
            let classes = attributeText[classRange].split(whereSeparator: \.isWhitespace)
            guard classes.contains(where: { $0 == "sp" || $0 == "d" || $0.range(of: #"^s\d*$"#, options: .regularExpression) != nil }) else { continue }
            result.replaceCharacters(in: paragraph.range, with: " ")
        }
        return result as String
    }

    private static func sourceHeadings(fromHTML html: String) -> [NIVHeading] {
        guard let paragraphs = try? NSRegularExpression(pattern: #"(?is)<p\b([^>]*)>(.*?)</p>"#),
              let verseSpans = try? NSRegularExpression(pattern: #"(?is)<span\b[^>]*\bdata-number\s*=\s*["'](\d+)["'][^>]*>"#),
              let classAttribute = try? NSRegularExpression(pattern: #"(?i)\bclass\s*=\s*["']([^"']*)["']"#) else {
            return []
        }
        let source = html as NSString
        let verseMatches = verseSpans.matches(in: html, range: NSRange(location: 0, length: source.length))
        var verseIndex = 0
        var lastVerse: Int?
        var headings: [NIVHeading] = []
        for paragraph in paragraphs.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            while verseIndex < verseMatches.count && verseMatches[verseIndex].range.location < paragraph.range.location {
                let numberRange = verseMatches[verseIndex].range(at: 1)
                lastVerse = Int(source.substring(with: numberRange)) ?? lastVerse
                verseIndex += 1
            }
            let attributes = source.substring(with: paragraph.range(at: 1)) as NSString
            let attributeText = attributes as String
            guard let match = classAttribute.firstMatch(
                in: attributeText,
                range: NSRange(location: 0, length: attributes.length)
            ),
            let classRange = Range(match.range(at: 1), in: attributeText) else { continue }
            let classes = attributeText[classRange].split(whereSeparator: \.isWhitespace)
            let type: String?
            if classes.contains(where: { $0.range(of: #"^s\d*$"#, options: .regularExpression) != nil }) {
                type = "section"
            } else if classes.contains("sp") {
                type = "speaker"
            } else if classes.contains("d") {
                type = "descriptive"
            } else {
                type = nil
            }
            guard let type else { continue }
            let text = text(fromHTML: source.substring(with: paragraph.range(at: 2)))
            if !text.isEmpty {
                headings.append(NIVHeading(type: type, text: text, afterVerse: lastVerse))
            }
        }
        return headings
    }

    private static func contentItems(fromHTML html: String) -> [ScriptureContentItem] {
        guard let paragraphs = try? NSRegularExpression(pattern: #"(?is)<p\b([^>]*)>(.*?)</p>"#),
              let classAttribute = try? NSRegularExpression(pattern: #"(?i)\bclass\s*=\s*["']([^"']*)["']"#),
              let dataVerse = try? NSRegularExpression(pattern: #"(?i)\bdata-vid\s*=\s*["'][^"']*:(\d+)["']"#),
              let verseNumberSpan = try? NSRegularExpression(pattern: #"(?is)<span\b[^>]*\bdata-number\s*=\s*["'](\d+)["'][^>]*>.*?</span>"#) else {
            return []
        }
        let source = html as NSString
        var lastVerse: Int?
        var items: [ScriptureContentItem] = []
        for paragraph in paragraphs.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            let attributes = source.substring(with: paragraph.range(at: 1)) as NSString
            let attributeText = attributes as String
            let classes: [Substring]
            if let match = classAttribute.firstMatch(in: attributeText, range: NSRange(location: 0, length: attributes.length)),
               let classRange = Range(match.range(at: 1), in: attributeText) {
                classes = attributeText[classRange].split(whereSeparator: \.isWhitespace)
            } else {
                classes = []
            }

            let paragraphText = source.substring(with: paragraph.range(at: 2))
            let paragraphSource = paragraphText as NSString
            let spanMatch = verseNumberSpan.firstMatch(
                in: paragraphText,
                range: NSRange(location: 0, length: paragraphSource.length)
            )
            let spanVerse = spanMatch.flatMap { Int(paragraphSource.substring(with: $0.range(at: 1))) }
            let dataVerseMatch = dataVerse.firstMatch(in: attributeText, range: NSRange(location: 0, length: attributes.length))
            let dataVerseNumber = dataVerseMatch.flatMap { Int(attributes.substring(with: $0.range(at: 1))) }
            let verse = spanVerse ?? dataVerseNumber ?? lastVerse
            let type: String?
            if classes.contains(where: { $0.range(of: #"^s\d*$"#, options: .regularExpression) != nil }) {
                type = "section"
            } else if classes.contains("sp") {
                type = "speaker"
            } else if classes.contains("d") {
                type = "descriptive"
            } else {
                type = nil
            }
            let text = Self.text(fromHTML: spanVerse == nil
                ? paragraphText
                : verseNumberSpan.stringByReplacingMatches(
                    in: paragraphText,
                    range: NSRange(location: 0, length: paragraphSource.length),
                    withTemplate: " "
                ))
            if let type, !text.isEmpty {
                items.append(.heading(NIVHeading(type: type, text: text, afterVerse: verse)))
            } else if let verse, !text.isEmpty {
                items.append(.verse(number: verse, text: text, startsVerse: spanVerse != nil))
            }
            if let spanVerse { lastVerse = spanVerse }
            else if let dataVerseNumber { lastVerse = dataVerseNumber }
        }
        return items
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

struct NIVHeading: Codable, Equatable {
    let type: String
    let text: String
    let afterVerse: Int?
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

enum NIVAPIError: LocalizedError {
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
