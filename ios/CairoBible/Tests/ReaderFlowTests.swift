import Foundation
import XCTest
@testable import CairoBible

@MainActor
final class ReaderFlowTests: XCTestCase {
    func testReaderLoadsSelectedNIVChapterFromBackend() async {
        StubURLProtocol.responder = { request in
            guard request.url?.path == "/api/niv/books/John/chapters/3" else {
                return (404, Data(#"{"detail":"Unexpected request"}"#.utf8))
            }
            return (200, Data(#"{"translation":"niv","bookId":"JHN","bookName":"John","chapter":3,"content":"<p>For God so loved the world.</p>","copyright":"NIV copyright"}"#.utf8))
        }
        defer { StubURLProtocol.responder = nil }

        let model = ReaderModel(client: makeClient())
        model.selectBook(BibleBook.all.first { $0.name == "John" }!)
        model.selectChapter(3)
        await model.load()

        guard case let .loaded(chapter) = model.state else {
            return XCTFail("Expected the selected chapter to load, got \(model.state)")
        }
        XCTAssertEqual(chapter.bookName, "John")
        XCTAssertEqual(chapter.chapter, 3)
        XCTAssertEqual(chapter.plainText, "For God so loved the world.")
        XCTAssertEqual(chapter.copyright, "NIV copyright")
    }

    func testReaderShowsBackendFailureMessage() async {
        StubURLProtocol.responder = { _ in
            (503, Data(#"{"detail":"NIV access is not enabled on the Bible server."}"#.utf8))
        }
        defer { StubURLProtocol.responder = nil }

        let model = ReaderModel(client: makeClient())
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

        let firstReader = ReaderModel(client: makeClient(cacheDirectory: cacheDirectory))
        firstReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        firstReader.selectChapter(3)
        await firstReader.load()

        StubURLProtocol.responder = { _ in
            requestCount += 1
            throw URLError(.notConnectedToInternet)
        }
        let reopenedReader = ReaderModel(client: makeClient(cacheDirectory: cacheDirectory))
        reopenedReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        reopenedReader.selectChapter(3)
        await reopenedReader.load()

        guard case let .loaded(chapter) = reopenedReader.state else {
            return XCTFail("Expected the fresh saved chapter to load, got \(reopenedReader.state)")
        }
        XCTAssertEqual(chapter.plainText, "Saved chapter")
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

        let firstReader = ReaderModel(client: makeClient(cacheDirectory: cacheDirectory, now: { now }))
        firstReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        firstReader.selectChapter(3)
        await firstReader.load()
        now.addTimeInterval(30 * 24 * 60 * 60)

        let reopenedReader = ReaderModel(client: makeClient(cacheDirectory: cacheDirectory, now: { now }))
        reopenedReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        reopenedReader.selectChapter(3)
        await reopenedReader.load()

        guard case let .loaded(chapter) = reopenedReader.state else {
            return XCTFail("Expected the refreshed chapter to load, got \(reopenedReader.state)")
        }
        XCTAssertEqual(chapter.plainText, "Refreshed chapter")
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

        let firstReader = ReaderModel(client: makeClient(cacheDirectory: cacheDirectory, now: { now }))
        firstReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        firstReader.selectChapter(3)
        await firstReader.load()
        now.addTimeInterval(30 * 24 * 60 * 60)
        StubURLProtocol.responder = { _ in
            requestCount += 1
            throw URLError(.notConnectedToInternet)
        }

        let offlineReader = ReaderModel(client: makeClient(cacheDirectory: cacheDirectory, now: { now }))
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

        let onlineReader = ReaderModel(client: makeClient(cacheDirectory: cacheDirectory))
        onlineReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        onlineReader.selectChapter(3)
        await onlineReader.load()
        StubURLProtocol.responder = { _ in throw URLError(.notConnectedToInternet) }

        let offlineReader = ReaderModel(client: makeClient(cacheDirectory: cacheDirectory))
        offlineReader.selectBook(BibleBook.all.first { $0.name == "John" }!)
        offlineReader.selectChapter(4)
        await offlineReader.load()

        guard case let .failed(message) = offlineReader.state else {
            return XCTFail("Expected an unavailable state for the uncached chapter, got \(offlineReader.state)")
        }
        XCTAssertTrue(message.contains("Connect to the internet"))
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
