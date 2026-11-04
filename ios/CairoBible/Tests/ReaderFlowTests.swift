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

    private func makeClient() -> NIVAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return NIVAPIClient(
            baseURL: URL(string: "https://reader.test")!,
            session: URLSession(configuration: configuration)
        )
    }
}

private final class StubURLProtocol: URLProtocol {
    static var responder: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responder = Self.responder, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (statusCode, data) = responder(request)
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
