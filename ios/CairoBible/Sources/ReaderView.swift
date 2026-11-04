import SwiftUI

struct ReaderView: View {
    @StateObject private var model: ReaderModel

    init(client: any NIVReadingClient) {
        _model = StateObject(wrappedValue: ReaderModel(client: client))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Choose a passage") {
                    Picker("Book", selection: Binding(
                        get: { model.selectedBook },
                        set: { model.selectBook($0) }
                    )) {
                        ForEach(BibleBook.all) { book in
                            Text(book.name).tag(book)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("Chapter", selection: Binding(
                        get: { model.selectedChapter },
                        set: { model.selectChapter($0) }
                    )) {
                        ForEach(1...model.selectedBook.chapterCount, id: \.self) { number in
                            Text("Chapter \(number)").tag(number)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                readingSection
            }
            .navigationTitle("Cairo Bible")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: "\(model.selectedBook.id)-\(model.selectedChapter)") {
                await model.load()
            }
        }
    }

    @ViewBuilder
    private var readingSection: some View {
        Section("New International Version") {
            switch model.state {
            case .idle, .loading:
                ProgressView("Loading \(model.selectedBook.name) \(model.selectedChapter)…")
                    .frame(maxWidth: .infinity, alignment: .leading)

            case let .loaded(chapter):
                Text("\(chapter.bookName) \(chapter.chapter)")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                Text(chapter.plainText)
                    .font(.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)

                Text(chapter.copyright)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Translation attribution. \(chapter.copyright)")

            case let .failed(message):
                ContentUnavailableView {
                    Label("Chapter unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") {
                        Task { await model.load() }
                    }
                }
            }
        }
    }
}
