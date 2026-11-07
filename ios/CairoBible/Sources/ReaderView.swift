import SwiftUI

struct ReaderView: View {
    @StateObject private var model: ReaderModel
    @StateObject private var reminderManager: DailyReminderManager
    @ObservedObject private var preferences: ReadingPreferences
    @Environment(\.colorScheme) private var systemColorScheme
    @ScaledMetric(relativeTo: .body) private var dynamicTypeScale = 1.0
    @State private var isShowingPreferences = false
    @State private var isShowingBookPicker = false
    @State private var isShowingChapterPicker = false
    @State private var areReaderControlsVisible = true
    @State private var lastScrollOffset: CGFloat?

    init(
        nivClient: any NIVReadingClient,
        svdClient: any SVDReadingClient = BundledSVDReadingClient(),
        preferences: ReadingPreferences? = nil,
        reminderManager: DailyReminderManager? = nil
    ) {
        let preferences = preferences ?? ReadingPreferences()
        let reminderManager = reminderManager ?? DailyReminderManager(appLanguage: preferences.appLanguage)
        _model = StateObject(wrappedValue: ReaderModel(
            nivClient: nivClient,
            svdClient: svdClient,
            preferences: preferences
        ))
        _preferences = ObservedObject(wrappedValue: preferences)
        _reminderManager = StateObject(wrappedValue: reminderManager)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chapterNavigation

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Color.clear
                            .frame(height: 0)
                            .background {
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: ReaderScrollOffsetKey.self,
                                        value: proxy.frame(in: .named("readerScroll")).minY
                                    )
                                }
                            }

                        readingContent
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .coordinateSpace(name: "readerScroll")
                .scrollIndicators(.hidden)
                .background(paletteColors.surface)
                .onPreferenceChange(ReaderScrollOffsetKey.self) { offset in
                    if let lastScrollOffset, abs(lastScrollOffset - offset) > 0.5 {
                        areReaderControlsVisible = false
                    }
                    lastScrollOffset = offset
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        areReaderControlsVisible = true
                    }
                }
            }
            .background(paletteColors.surface)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if areReaderControlsVisible {
                    ReaderControlsBar(model: model, preferences: preferences, colors: paletteColors)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Cairo Bible")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingPreferences = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Reading preferences")
                }
            }
            .sheet(isPresented: $isShowingPreferences) {
                ReadingPreferencesView(
                    preferences: preferences,
                    reminders: reminderManager
                )
                .presentationDetents([.fraction(0.76), .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(30)
                .presentationBackground(paletteColors.surfaceRaised)
            }
            .onChange(of: preferences.appLanguage) { _, appLanguage in
                Task { await reminderManager.setAppLanguage(appLanguage) }
            }
            .onChange(of: model.selectedTranslation) { _, _ in
                showReaderControls()
            }
            .onChange(of: model.selectedBook) { _, _ in showReaderControls() }
            .onChange(of: model.selectedChapter) { _, _ in showReaderControls() }
            .task(id: "\(model.selectedTranslation.id)-\(model.selectedBook.id)-\(model.selectedChapter)") {
                await model.load()
            }
        }
        .environment(\.colorScheme, effectiveColorScheme)
        .environment(\.locale, preferences.appLanguage.locale)
        .environment(\.layoutDirection, preferences.appLanguage == .ar ? .rightToLeft : .leftToRight)
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

    private var readingFontSize: Double {
        preferences.fontSize * dynamicTypeScale
    }

    private var readingFont: Font {
        .system(size: CGFloat(readingFontSize), design: .serif)
    }

    private var lineSpacing: CGFloat {
        CGFloat(preferences.lineSpacing.extraSpacing(for: readingFontSize))
    }

    private var paletteColors: ReaderPaletteColors {
        preferences.palette.colors(for: effectiveColorScheme)
    }

    private var chapterNavigation: some View {
        HStack(spacing: 10) {
            Button {
                isShowingBookPicker = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "book")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(paletteColors.accent)
                    Text(currentBookName)
                        .font(.system(size: 22, design: .serif))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .layoutPriority(1)
                        .foregroundStyle(paletteColors.ink)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose book")
            .accessibilityValue(currentBookName)
            .sheet(isPresented: $isShowingBookPicker) {
                let pickerColors = ReaderPalette.cairo.colors(for: effectiveColorScheme)
                BookPickerSheet(
                    selectedBook: model.selectedBook,
                    appLanguage: preferences.appLanguage,
                    colors: pickerColors
                ) { book in
                    model.selectBook(book)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(30)
                .presentationBackground(pickerColors.surfaceRaised)
            }

            Spacer(minLength: 0)

            Button(action: model.selectPreviousChapter) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 28, height: 40)
                    .contentShape(Rectangle())
            }
            .disabled(!model.canSelectPreviousChapter)
            .accessibilityLabel(model.previousChapterAccessibilityLabel)

            Button {
                isShowingChapterPicker = true
            } label: {
                HStack(spacing: 8) {
                    Text(preferences.appLanguage.format("Chapter %d", model.selectedChapter))
                        .font(.system(size: 18, design: .serif))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(paletteColors.ink)
                .padding(.horizontal, 13)
                .frame(height: 40)
                .background(paletteColors.surfaceRaised, in: Capsule())
                .overlay(Capsule().stroke(paletteColors.accent.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose chapter")
            .accessibilityValue(preferences.appLanguage.format("Chapter %d", model.selectedChapter))
            .sheet(isPresented: $isShowingChapterPicker) {
                ChapterPickerSheet(
                    bookName: currentBookName,
                    chapterCount: model.selectedBook.chapterCount,
                    selectedChapter: model.selectedChapter,
                    appLanguage: preferences.appLanguage,
                    colors: paletteColors
                ) { chapter in
                    model.selectChapter(chapter)
                    isShowingChapterPicker = false
                }
                .presentationDetents([.fraction(0.72), .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
                .presentationBackground(paletteColors.surfaceRaised)
            }

            Button(action: model.selectNextChapter) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 28, height: 40)
                    .contentShape(Rectangle())
            }
            .disabled(!model.canSelectNextChapter)
            .accessibilityLabel(model.nextChapterAccessibilityLabel)

        }
        .buttonStyle(.plain)
        .foregroundStyle(paletteColors.ink)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var currentBookName: String {
        if case let .loaded(chapter) = model.state { chapter.bookName }
        else { model.selectedBook.name }
    }

    @ViewBuilder
    private var readingContent: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView(preferences.appLanguage.format("Loading %@, %@ %d…", model.selectedTranslation.title, model.selectedBook.name, model.selectedChapter))
                .foregroundStyle(paletteColors.muted)
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)

        case let .loaded(chapter):
            if !chapter.verses.isEmpty {
                ForEach(chapter.verses) { verse in
                    verseRow(verse, isRightToLeft: model.selectedTranslation.isRightToLeft)
                }
            } else {
                Text(verbatim: chapter.text)
                    .font(readingFont)
                    .foregroundStyle(paletteColors.ink)
                    .lineSpacing(lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
            }

            Text(chapter.attribution)
                .font(.footnote)
                .foregroundStyle(paletteColors.muted)
                .textSelection(.enabled)
                .accessibilityLabel(preferences.appLanguage.format("Translation attribution. %@", chapter.attribution))

        case let .failed(message):
            ContentUnavailableView {
                Label("Chapter unavailable", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(paletteColors.ink)
            } description: {
                Text(message)
                    .foregroundStyle(paletteColors.muted)
            } actions: {
                Button("Try again") {
                    Task { await model.load() }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    private func verseRow(_ verse: ScriptureVerse, isRightToLeft: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(verbatim: "\u{2068}\(verse.number)\u{2069}")
                .font(.system(size: CGFloat(readingFontSize * 0.78), design: .serif))
                .foregroundStyle(paletteColors.muted)
                .frame(width: 24)
            Text(verbatim: verse.text)
                .font(readingFont)
                .foregroundStyle(paletteColors.ink)
                .lineSpacing(lineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
        .environment(\.locale, isRightToLeft ? Locale(identifier: "ar") : .current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preferences.appLanguage.format("Verse %d. %@", verse.number, verse.text))
    }

    private func showReaderControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            areReaderControlsVisible = true
        }
    }
}

private struct ChapterPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let bookName: String
    let chapterCount: Int
    let selectedChapter: Int
    let appLanguage: AppLanguage
    let colors: ReaderPaletteColors
    let onSelect: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(colors.muted.opacity(0.35))
                .frame(width: 64, height: 6)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(bookName)
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(colors.ink)
                    Text("Choose a chapter")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(colors.muted)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(colors.ink)
                        .frame(width: 36, height: 36)
                        .background(colors.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close chapter selector")
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(1...chapterCount, id: \.self) { chapter in
                        let isSelected = chapter == selectedChapter
                        Button {
                            onSelect(chapter)
                        } label: {
                            Text("\(chapter)")
                                .font(.system(size: 18, design: .serif))
                                .foregroundStyle(isSelected ? colors.surfaceRaised : colors.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(isSelected ? colors.accent : colors.surface, in: RoundedRectangle(cornerRadius: 16))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(colors.accent.opacity(isSelected ? 0 : 0.12), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(appLanguage.format("Chapter %d", chapter))
                        .accessibilityValue(isSelected ? appLanguage.localized("Selected") : "")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

private struct BookPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    let selectedBook: BibleBook
    let appLanguage: AppLanguage
    let colors: ReaderPaletteColors
    let onSelect: (BibleBook) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    private var filteredOldTestament: [BibleBook] {
        filteredBooks(BibleBook.oldTestament)
    }

    private var filteredNewTestament: [BibleBook] {
        filteredBooks(BibleBook.newTestament)
    }

    private var hasResults: Bool {
        !filteredOldTestament.isEmpty || !filteredNewTestament.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(colors.muted.opacity(0.4))
                .frame(width: 52, height: 4)
                .padding(.top, 8)
                .accessibilityHidden(true)

            HStack {
                Text(appLanguage.localized("Choose a book"))
                    .font(.custom("Georgia", size: 24, relativeTo: .title))
                    .foregroundStyle(colors.ink)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(colors.ink)
                        .frame(width: 40, height: 40)
                        .background(colors.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appLanguage.localized("Close book selector"))
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 16)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(colors.muted)
                TextField(appLanguage.localized("Search books..."), text: $searchText)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(colors.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(colors.surface, in: Capsule())
            .overlay(Capsule().stroke(colors.accent.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 22)
            .padding(.bottom, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if !filteredOldTestament.isEmpty {
                        testamentSection("Old Testament", books: filteredOldTestament)
                    }
                    if !filteredNewTestament.isEmpty {
                        testamentSection("New Testament", books: filteredNewTestament)
                    }
                    if !hasResults {
                        Text(appLanguage.localized("No books found"))
                            .font(.custom("Georgia", size: 17, relativeTo: .body))
                            .foregroundStyle(colors.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 36)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(colors.surfaceRaised.ignoresSafeArea())
    }

    private func testamentSection(_ title: String, books: [BibleBook]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(appLanguage.localized(title).uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(colors.ink)
                Rectangle()
                    .fill(colors.muted.opacity(0.28))
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(books) { book in
                    let isSelected = book == selectedBook
                    Button {
                        onSelect(book)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.name)
                                .font(.custom("Georgia", size: 15, relativeTo: .body))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(isSelected ? colors.surfaceRaised : colors.ink)
                            Text("\(book.svdID) · \(book.chapterCount)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .tracking(0.5)
                                .foregroundStyle(isSelected ? colors.surfaceRaised.opacity(0.82) : colors.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .padding(.horizontal, 14)
                        .background(isSelected ? colors.accent : colors.surface, in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(colors.accent.opacity(isSelected ? 0 : 0.12), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(isSelected ? appLanguage.localized("Selected") : "")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func filteredBooks(_ books: [BibleBook]) -> [BibleBook] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return books }
        return books.filter { $0.name.localizedStandardContains(query) }
    }
}

private struct ReaderScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ReaderControlsBar: View {
    @ObservedObject var model: ReaderModel
    @ObservedObject var preferences: ReadingPreferences
    let colors: ReaderPaletteColors

    private var selectedFontSize: ReaderFontSizePreset {
        ReaderFontSizePreset.nearest(to: preferences.fontSize)
    }

    private var controlDivider: some View {
        Rectangle()
            .fill(colors.muted.opacity(0.25))
            .frame(width: 1, height: 20)
    }

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(BibleTranslation.allCases) { translation in
                    Button {
                        model.selectTranslation(translation)
                    } label: {
                        if model.selectedTranslation == translation {
                            Label(translation.title, systemImage: "checkmark")
                        } else {
                            Text(translation.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(model.selectedTranslation.title)
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(colors.ink)
            }
            .accessibilityLabel("Translation")
            .accessibilityValue(model.selectedTranslation.title)

            controlDivider

            HStack(spacing: 2) {
                ForEach(ReaderFontSizePreset.allCases) { preset in
                    let isSelected = selectedFontSize == preset
                    Button {
                        preferences.setFontSize(preset)
                    } label: {
                        Text(preset.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isSelected ? colors.surfaceRaised : colors.ink)
                            .frame(width: 29, height: 29)
                            .background(isSelected ? colors.accent : .clear, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preferences.appLanguage.format("%@ reading text size", preset.title))
                    .accessibilityValue(isSelected ? preferences.appLanguage.localized("Selected") : "")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            controlDivider

            Menu {
                ForEach(ReaderLineSpacing.allCases) { spacing in
                    Button {
                        preferences.setLineSpacing(spacing)
                    } label: {
                        if preferences.lineSpacing == spacing {
                            Label(preferences.appLanguage.format("%@ (%@)", preferences.appLanguage.localized(spacing.rawValue), spacing.ratioText), systemImage: "checkmark")
                        } else {
                            Text(preferences.appLanguage.format("%@ (%@)", preferences.appLanguage.localized(spacing.rawValue), spacing.ratioText))
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(colors.ink)
                    .frame(width: 28, height: 34)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Line spacing")
            .accessibilityValue(preferences.appLanguage.localized(preferences.lineSpacing.rawValue))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(colors.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(colors.accent.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

private struct ReadingPreferencesView: View {
    @ObservedObject var preferences: ReadingPreferences
    @ObservedObject var reminders: DailyReminderManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var colors: ReaderPaletteColors {
        preferences.palette.colors(for: effectiveColorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(colors.muted.opacity(0.45))
                .frame(width: 56, height: 5)
                .padding(.top, 10)
                .accessibilityHidden(true)

            ZStack {
                Text(preferences.appLanguage.localized("Settings"))
                    .font(.custom("Georgia", size: 22, relativeTo: .title2))
                    .foregroundStyle(colors.ink)

                HStack {
                    Spacer()
                    Button(preferences.appLanguage.localized("Done")) { dismiss() }
                        .font(.custom("Georgia", size: 17, relativeTo: .body))
                        .foregroundStyle(colors.accent)
                }
            }
            .frame(height: 56)
            .padding(.horizontal, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    appearanceSection
                    languageSection
                    paletteSection
                    reminderSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .background(colors.surfaceRaised.ignoresSafeArea())
        .preferredColorScheme(preferredColorScheme)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Appearance")

            HStack(spacing: 4) {
                ForEach(ReaderAppearance.allCases) { appearance in
                    let isSelected = preferences.appearance == appearance
                    Button {
                        preferences.setAppearance(appearance)
                    } label: {
                        Text(preferences.appLanguage.localized(appearance.rawValue))
                            .font(.custom("Georgia", size: 17, relativeTo: .body))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundStyle(isSelected ? colors.surfaceRaised : colors.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 12).fill(colors.accent)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(isSelected ? preferences.appLanguage.localized("Selected") : "")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(4)
            .background(colors.surface, in: Capsule())
            .overlay(Capsule().stroke(colors.muted.opacity(0.22), lineWidth: 1))
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("App language")

            HStack(spacing: 4) {
                ForEach(AppLanguage.allCases) { language in
                    let isSelected = preferences.appLanguage == language
                    Button {
                        preferences.setAppLanguage(language)
                    } label: {
                        Text(language.title)
                            .font(.custom("Georgia", size: 17, relativeTo: .body))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundStyle(isSelected ? colors.surfaceRaised : colors.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 12).fill(colors.accent)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preferences.appLanguage.localized("App language"))
                    .accessibilityValue(isSelected ? language.title : "")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(4)
            .background(colors.surface, in: Capsule())
            .overlay(Capsule().stroke(colors.muted.opacity(0.22), lineWidth: 1))
        }
    }

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("App color palette")

            HStack(alignment: .top, spacing: 8) {
                ForEach(ReaderPalette.allCases) { palette in
                    let paletteColors = palette.colors(for: effectiveColorScheme)
                    let isSelected = preferences.palette == palette
                    Button {
                        preferences.setPalette(palette)
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(paletteColors.accent)
                                .frame(width: 32, height: 32)
                                .overlay(alignment: .topTrailing) {
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(paletteColors.accent)
                                            .background(paletteColors.surfaceRaised, in: Circle())
                                            .offset(x: 5, y: -5)
                                    }
                                }

                            Text(preferences.appLanguage.localized(palette.rawValue))
                                .font(.custom("Georgia", size: 12, relativeTo: .caption))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .foregroundStyle(paletteColors.ink)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 78)
                        .padding(.horizontal, 2)
                        .background(paletteColors.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isSelected ? paletteColors.accent : paletteColors.ink.opacity(0.16),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preferences.appLanguage.format("%@ palette", preferences.appLanguage.localized(palette.rawValue)))
                    .accessibilityValue(isSelected ? preferences.appLanguage.localized("Selected") : "")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var reminderSection: some View {
        VStack(spacing: 0) {
            HStack {
                sectionHeading("Reading reminders")
                Spacer()
                Toggle("Daily reading reminder", isOn: Binding(
                    get: { reminders.isEnabled },
                    set: { enabled in Task { await reminders.setEnabled(enabled) } }
                ))
                .labelsHidden()
                .tint(.green)
                .disabled(reminders.isRequestingAuthorization)
            }
            .frame(minHeight: 54)

            Divider().overlay(colors.muted.opacity(0.2))

            HStack {
                Text(preferences.appLanguage.localized("Time"))
                    .font(.custom("Georgia", size: 17, relativeTo: .body))
                    .foregroundStyle(reminders.isEnabled ? colors.ink : colors.muted)
                Spacer()
                DatePicker("Reminder time", selection: Binding(
                    get: { reminders.time },
                    set: { time in Task { await reminders.setReminderTime(time) } }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .font(.custom("Georgia", size: 17, relativeTo: .body))
                .disabled(!reminders.isEnabled || reminders.isRequestingAuthorization)
                .accessibilityLabel(preferences.appLanguage.localized("Reminder time"))
                .accessibilityHint(reminderTimeAccessibilityHint)
            }
            .frame(minHeight: 54)

            Divider().overlay(colors.muted.opacity(0.2))

            if let message = reminders.message {
                Text(message)
                    .font(.custom("Georgia", size: 13, relativeTo: .footnote))
                    .foregroundStyle(colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 16)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func sectionHeading(_ key: String) -> some View {
        Text(preferences.appLanguage.localized(key))
            .font(.custom("Georgia", size: 20, relativeTo: .title3))
            .foregroundStyle(colors.ink)
    }

    private var reminderTimeAccessibilityHint: String {
        if reminders.isRequestingAuthorization {
            preferences.appLanguage.localized("Wait while notification permission is requested.")
        } else if reminders.isEnabled {
            preferences.appLanguage.localized("Choose when your daily reading reminder is sent.")
        } else {
            preferences.appLanguage.localized("Turn on the daily reading reminder to choose a time.")
        }
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
        case .system: colorScheme
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct ReaderPaletteColors {
    let surface: Color
    let surfaceRaised: Color
    let ink: Color
    let muted: Color
    let accent: Color
}

private extension ReaderPalette {
    func colors(for colorScheme: ColorScheme) -> ReaderPaletteColors {
        let values: (surface: UInt, surfaceRaised: UInt, ink: UInt, muted: UInt, accent: UInt)
        switch (self, colorScheme) {
        case (.cairo, .dark): values = (0x211B18, 0x2B221E, 0xF3E8DC, 0xC1AFA2, 0xE69373)
        case (.olive, .dark): values = (0x1B211B, 0x242D24, 0xE5EEE2, 0xB2C2AF, 0xA7C9A6)
        case (.nile, .dark): values = (0x182129, 0x202C36, 0xE2EDF4, 0xAEC0CD, 0x8CC7E7)
        case (.amethyst, .dark): values = (0x211B25, 0x2C2432, 0xF0E7F4, 0xC4B3CC, 0xC7A4DA)
        case (.sandstone, .dark): values = (0x241F16, 0x302918, 0xF1E8D1, 0xC9BFA3, 0xE0C278)
        case (.cairo, _): values = (0xF3E8DC, 0xFBF6F0, 0x30251F, 0x706057, 0xB35A3D)
        case (.olive, _): values = (0xE9EEE4, 0xF8FAF5, 0x253127, 0x58665A, 0x47734E)
        case (.nile, _): values = (0xE7EFF5, 0xF8FBFD, 0x1D2D3A, 0x516678, 0x356D91)
        case (.amethyst, _): values = (0xF1EAF3, 0xFCF9FD, 0x33263A, 0x67586D, 0x79558A)
        case (.sandstone, _): values = (0xF4EFDD, 0xFCF9EF, 0x332D20, 0x70694F, 0x826622)
        }
        return ReaderPaletteColors(
            surface: Color(hex: values.surface),
            surfaceRaised: Color(hex: values.surfaceRaised),
            ink: Color(hex: values.ink),
            muted: Color(hex: values.muted),
            accent: Color(hex: values.accent)
        )
    }
}

private extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
