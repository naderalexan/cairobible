import SwiftUI

struct ReaderView: View {
    @StateObject private var model: ReaderModel
    @ObservedObject private var preferences: ReadingPreferences
    @Environment(\.colorScheme) private var systemColorScheme
    @ScaledMetric(relativeTo: .body) private var dynamicTypeScale = 1.0
    @State private var isShowingPreferences = false

    init(
        nivClient: any NIVReadingClient,
        svdClient: any SVDReadingClient = BundledSVDReadingClient(),
        preferences: ReadingPreferences? = nil
    ) {
        let preferences = preferences ?? ReadingPreferences()
        _model = StateObject(wrappedValue: ReaderModel(
            nivClient: nivClient,
            svdClient: svdClient,
            preferences: preferences
        ))
        _preferences = ObservedObject(wrappedValue: preferences)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingPreferences = true
                    } label: {
                        Image(systemName: "textformat.size")
                    }
                    .accessibilityLabel("Reading preferences")
                }
            }
            .sheet(isPresented: $isShowingPreferences) {
                ReadingPreferencesView(preferences: preferences, translation: model.selectedTranslation)
            }
            .task(id: "\(model.selectedTranslation.id)-\(model.selectedBook.id)-\(model.selectedChapter)") {
                await model.load()
            }
        }
        .environment(\.colorScheme, effectiveColorScheme)
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        switch preferences.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var effectiveColorScheme: ColorScheme {
        switch preferences.appearance {
        case .system: systemColorScheme
        case .light: .light
        case .dark: .dark
        }
    }

    private var readingFont: Font {
        .system(size: CGFloat(preferences.fontSize * dynamicTypeScale))
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
                    .font(readingFont.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .environment(\.layoutDirection, model.selectedTranslation.isRightToLeft ? .rightToLeft : .leftToRight)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.locale, model.selectedTranslation.isRightToLeft ? Locale(identifier: "ar") : .current)

                if model.selectedTranslation == .svd {
                    ForEach(chapter.verses) { verse in
                        (Text(verbatim: "\u{2068}\(verse.number)\u{2069} ").font(.footnote.weight(.semibold))
                            + Text(verbatim: verse.text).font(readingFont))
                            .lineSpacing(6)
                            .listRowSeparator(.hidden)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .environment(\.layoutDirection, .rightToLeft)
                            .environment(\.locale, Locale(identifier: "ar"))
                            .textSelection(.enabled)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("الآية \(verse.number). \(verse.text)")
                    }
                } else {
                    Text(verbatim: chapter.text)
                        .font(readingFont)
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

private struct ReadingPreferencesView: View {
    @ObservedObject var preferences: ReadingPreferences
    let translation: BibleTranslation
    @ScaledMetric(relativeTo: .body) private var dynamicTypeScale = 1.0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Text size") {
                    Slider(
                        value: Binding(
                            get: { preferences.fontSize },
                            set: { preferences.setFontSize($0) }
                        ),
                        in: ReadingPreferences.fontSizeRange,
                        step: 1
                    )
                    .accessibilityLabel("Reading text size")
                    .accessibilityValue("\(Int(preferences.fontSize)) points")

                    Text(sampleText)
                        .font(.system(size: CGFloat(preferences.fontSize * dynamicTypeScale)))
                        .environment(\.layoutDirection, translation.isRightToLeft ? .rightToLeft : .leftToRight)
                        .multilineTextAlignment(.leading)
                        .environment(\.locale, translation.isRightToLeft ? Locale(identifier: "ar") : .current)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section("Appearance") {
                    Picker("Appearance", selection: Binding(
                        get: { preferences.appearance },
                        set: { preferences.setAppearance($0) }
                    )) {
                        ForEach(ReaderAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                }
            }
            .navigationTitle("Reading preferences")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(preferredColorScheme)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var sampleText: String {
        switch translation {
        case .niv: "The Lord is my shepherd"
        case .svd: "ٱلرَّبُّ رَاعِيَّ فَلَا يُعْوِزُنِي شَيْءٌ."
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch preferences.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
