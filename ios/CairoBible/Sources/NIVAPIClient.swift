import Foundation

struct NIVChapter: Decodable, Equatable {
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
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchChapter(book: BibleBook, number: Int) async throws -> NIVChapter {
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NIVAPIError.connection
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
            return try JSONDecoder().decode(NIVChapter.self, from: data)
        } catch {
            throw NIVAPIError.invalidResponse
        }
    }
}

private struct BackendError: Decodable {
    let detail: String
}

private enum NIVAPIError: LocalizedError {
    case connection
    case invalidURL
    case invalidResponse
    case backend(String)

    var errorDescription: String? {
        switch self {
        case .connection:
            "Could not connect to the Bible server. Check your connection and try again."
        case .invalidURL:
            "The Bible server address is invalid."
        case .invalidResponse:
            "The Bible server sent a chapter that could not be read."
        case let .backend(message):
            message
        }
    }
}
