import SwiftUI

struct ReaderView: View {
    @StateObject private var model: ReaderModel

    init(nivClient: any NIVReadingClient, svdClient: any SVDReadingClient = BundledSVDReadingClient()) {
        _model = StateObject(wrappedValue: ReaderModel(nivClient: nivClient, svdClient: svdClient))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Choose a passage") {
                    Picker("Translation", selection: Binding(
                        get: { model.selectedTranslation },
                        set: { model.selectTranslation($0) }
                    )) {
                        ForEach(BibleTranslation.allCases) { translation in
                            Text(translation.title).tag(translation)
                        }
                    }
                    .pickerStyle(.segmented)

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
            .task(id: "\(model.selectedTranslation.id)-\(model.selectedBook.id)-\(model.selectedChapter)") {
                await model.load()
            }
        }
    }

    @ViewBuilder
    private var readingSection: some View {
        Section(model.selectedTranslation.sectionTitle) {
            switch model.state {
            case .idle, .loading:
                ProgressView("Loading \(model.selectedTranslation.title), \(model.selectedBook.name) \(model.selectedChapter)…")
                    .frame(maxWidth: .infinity, alignment: .leading)

            case let .loaded(chapter):
                Text("\(chapter.bookName) \(chapter.chapter)")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .environment(\.layoutDirection, model.selectedTranslation.isRightToLeft ? .rightToLeft : .leftToRight)
                    .multilineTextAlignment(model.selectedTranslation.isRightToLeft ? .trailing : .leading)
                    .environment(\.locale, model.selectedTranslation.isRightToLeft ? Locale(identifier: "ar") : .current)

                if model.selectedTranslation == .svd {
                    ForEach(chapter.verses) { verse in
                        (Text(verbatim: "\u{2068}\(verse.number)\u{2069} ").font(.footnote.weight(.semibold))
                            + Text(verbatim: verse.text).font(.body))
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                            .environment(\.layoutDirection, .rightToLeft)
                            .environment(\.locale, Locale(identifier: "ar"))
                            .textSelection(.enabled)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("الآية \(verse.number). \(verse.text)")
                    }
                } else {
                    Text(verbatim: chapter.text)
                        .font(.body)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }

                Text(chapter.attribution)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .accessibilityLabel("Translation attribution. \(chapter.attribution)")

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
