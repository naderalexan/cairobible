import SwiftUI

struct ReaderView: View {
    @StateObject private var model: ReaderModel
    @StateObject private var reminderManager: DailyReminderManager
    @ObservedObject private var preferences: ReadingPreferences
    @Environment(\.colorScheme) private var systemColorScheme
    @ScaledMetric(relativeTo: .body) private var dynamicTypeScale = 1.0
    @State private var isShowingPreferences = false

    init(
        nivClient: any NIVReadingClient,
        svdClient: any SVDReadingClient = BundledSVDReadingClient(),
        preferences: ReadingPreferences? = nil,
        reminderManager: DailyReminderManager? = nil
    ) {
        let preferences = preferences ?? ReadingPreferences()
        let reminderManager = reminderManager ?? DailyReminderManager()
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
            .scrollContentBackground(.hidden)
            .background(paletteColors.surface)
            .tint(paletteColors.accent)
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
                ReadingPreferencesView(
                    preferences: preferences,
                    reminders: reminderManager,
                    translation: model.selectedTranslation
                )
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

    private var paletteColors: ReaderPaletteColors {
        preferences.palette.colors(for: effectiveColorScheme)
    }

    @ViewBuilder
    private var readingSection: some View {
        Section {
            switch model.state {
            case .idle, .loading:
                ProgressView("Loading \(model.selectedTranslation.title), \(model.selectedBook.name) \(model.selectedChapter)…")
                    .foregroundStyle(paletteColors.muted)
                    .listRowBackground(paletteColors.surfaceRaised)
                    .frame(maxWidth: .infinity, alignment: .leading)

            case let .loaded(chapter):
                Text("\(chapter.bookName) \(chapter.chapter)")
                    .font(readingFont.weight(.semibold))
                    .foregroundStyle(paletteColors.ink)
                    .listRowBackground(paletteColors.surfaceRaised)
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
                            .foregroundStyle(paletteColors.ink)
                            .listRowBackground(paletteColors.surfaceRaised)
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
                        .foregroundStyle(paletteColors.ink)
                        .lineSpacing(6)
                        .listRowBackground(paletteColors.surfaceRaised)
                        .textSelection(.enabled)
                }

                Text(chapter.attribution)
                    .font(.footnote)
                    .foregroundStyle(paletteColors.muted)
                    .listRowBackground(paletteColors.surfaceRaised)
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
                .listRowBackground(paletteColors.surfaceRaised)
            }
        } header: {
            Text(model.selectedTranslation.sectionTitle)
                .foregroundStyle(paletteColors.accent)
        }
    }
}

private struct ReadingPreferencesView: View {
    @ObservedObject var preferences: ReadingPreferences
    @ObservedObject var reminders: DailyReminderManager
    let translation: BibleTranslation
    @ScaledMetric(relativeTo: .body) private var dynamicTypeScale = 1.0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

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

                    if let message = reminders.message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
