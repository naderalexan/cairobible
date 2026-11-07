import SwiftUI

struct ReaderView: View {
    @StateObject private var model: ReaderModel
    @StateObject private var reminderManager: DailyReminderManager
    @ObservedObject private var preferences: ReadingPreferences
    @Environment(\.colorScheme) private var systemColorScheme
    @ScaledMetric(relativeTo: .body) private var dynamicTypeScale = 1.0
    @State private var isShowingPreferences = false
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
        let reminderManager = reminderManager ?? DailyReminderManager(translation: preferences.translation)
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
            }
            .task {
                await reminderManager.setTranslation(model.selectedTranslation)
            }
            .onChange(of: model.selectedTranslation) { _, translation in
                Task { await reminderManager.setTranslation(translation) }
                showReaderControls()
            }
            .onChange(of: model.selectedBook) { _, _ in showReaderControls() }
            .onChange(of: model.selectedChapter) { _, _ in showReaderControls() }
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
            Menu {
                Picker("Book", selection: Binding(
                    get: { model.selectedBook },
                    set: { model.selectBook($0) }
                )) {
                    ForEach(BibleBook.all) { book in
                        Text(book.name).tag(book)
                    }
                }
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
            .accessibilityLabel("Choose book")
            .accessibilityValue(currentBookName)

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
                    Text("Chapter \(model.selectedChapter)")
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
            .accessibilityValue("Chapter \(model.selectedChapter)")
            .sheet(isPresented: $isShowingChapterPicker) {
                ChapterPickerSheet(
                    bookName: currentBookName,
                    chapterCount: model.selectedBook.chapterCount,
                    selectedChapter: model.selectedChapter,
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
        .environment(\.layoutDirection, .leftToRight)
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
            ProgressView("Loading \(model.selectedTranslation.title), \(model.selectedBook.name) \(model.selectedChapter)…")
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
                .accessibilityLabel("Translation attribution. \(chapter.attribution)")

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
        .accessibilityLabel(isRightToLeft ? "الآية \(verse.number). \(verse.text)" : "Verse \(verse.number). \(verse.text)")
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
                        .accessibilityLabel("Chapter \(chapter)")
                        .accessibilityValue(isSelected ? "Selected" : "")
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
                    .accessibilityLabel("\(preset.title) reading text size")
                    .accessibilityValue(isSelected ? "Selected" : "")
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
                            Label("\(spacing.title) (\(spacing.ratioText))", systemImage: "checkmark")
                        } else {
                            Text("\(spacing.title) (\(spacing.ratioText))")
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
            .accessibilityValue(preferences.lineSpacing.title)
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Color palette") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(ReaderPalette.allCases) { palette in
                            let colors = palette.colors(for: effectiveColorScheme)
                            let isSelected = preferences.palette == palette
                            Button {
                                preferences.setPalette(palette)
                            } label: {
                                VStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(colors.surface)
                                        .overlay(alignment: .leading) {
                                            Rectangle().fill(colors.accent).frame(width: 18)
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(colors.ink.opacity(0.2), lineWidth: 1)
                                        }
                                        .frame(height: 38)
                                        .overlay(alignment: .bottomTrailing) {
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(colors.accent)
                                                    .padding(3)
                                            }
                                        }

                                    Text(palette.title)
                                        .font(.subheadline)
                                        .foregroundStyle(colors.ink)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(colors.surfaceRaised)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? colors.accent : colors.ink.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(palette.title) palette")
                            .accessibilityValue(isSelected ? "Selected" : "")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
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
                    .pickerStyle(.segmented)
                }

                Section("Daily reminder") {
                    Toggle("Daily reading reminder", isOn: Binding(
                        get: { reminders.isEnabled },
                        set: { enabled in Task { await reminders.setEnabled(enabled) } }
                    ))
                    .disabled(reminders.isRequestingAuthorization)

                    DatePicker("Reminder time", selection: Binding(
                        get: { reminders.time },
                        set: { time in Task { await reminders.setReminderTime(time) } }
                    ), displayedComponents: .hourAndMinute)
                    .disabled(!reminders.isEnabled || reminders.isRequestingAuthorization)
                    .accessibilityHint(reminderTimeAccessibilityHint)

                    if let message = reminders.message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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

    private var reminderTimeAccessibilityHint: String {
        if reminders.isRequestingAuthorization {
            "Wait while notification permission is requested."
        } else if reminders.isEnabled {
            "Choose when your daily reading reminder is sent."
        } else {
            "Turn on the daily reading reminder to choose a time."
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
