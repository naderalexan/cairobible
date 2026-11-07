import Foundation

struct BibleBook: Hashable, Identifiable {
    let name: String
    let svdID: String
    let chapterCount: Int

    var id: String { name }

    func localizedName(for appLanguage: AppLanguage) -> String {
        appLanguage.localized(name)
    }

    static let all: [BibleBook] = [
        .init(name: "Genesis", svdID: "GEN", chapterCount: 50),
        .init(name: "Exodus", svdID: "EXO", chapterCount: 40),
        .init(name: "Leviticus", svdID: "LEV", chapterCount: 27),
        .init(name: "Numbers", svdID: "NUM", chapterCount: 36),
        .init(name: "Deuteronomy", svdID: "DEU", chapterCount: 34),
        .init(name: "Joshua", svdID: "JOS", chapterCount: 24),
        .init(name: "Judges", svdID: "JDG", chapterCount: 21),
        .init(name: "Ruth", svdID: "RUT", chapterCount: 4),
        .init(name: "1 Samuel", svdID: "1SA", chapterCount: 31),
        .init(name: "2 Samuel", svdID: "2SA", chapterCount: 24),
        .init(name: "1 Kings", svdID: "1KI", chapterCount: 22),
        .init(name: "2 Kings", svdID: "2KI", chapterCount: 25),
        .init(name: "1 Chronicles", svdID: "1CH", chapterCount: 29),
        .init(name: "2 Chronicles", svdID: "2CH", chapterCount: 36),
        .init(name: "Ezra", svdID: "EZR", chapterCount: 10),
        .init(name: "Nehemiah", svdID: "NEH", chapterCount: 13),
        .init(name: "Esther", svdID: "EST", chapterCount: 10),
        .init(name: "Job", svdID: "JOB", chapterCount: 42),
        .init(name: "Psalms", svdID: "PSA", chapterCount: 150),
        .init(name: "Proverbs", svdID: "PRO", chapterCount: 31),
        .init(name: "Ecclesiastes", svdID: "ECC", chapterCount: 12),
        .init(name: "Song of Songs", svdID: "SNG", chapterCount: 8),
        .init(name: "Isaiah", svdID: "ISA", chapterCount: 66),
        .init(name: "Jeremiah", svdID: "JER", chapterCount: 52),
        .init(name: "Lamentations", svdID: "LAM", chapterCount: 5),
        .init(name: "Ezekiel", svdID: "EZK", chapterCount: 48),
        .init(name: "Daniel", svdID: "DAN", chapterCount: 12),
        .init(name: "Hosea", svdID: "HOS", chapterCount: 14),
        .init(name: "Joel", svdID: "JOL", chapterCount: 3),
        .init(name: "Amos", svdID: "AMO", chapterCount: 9),
        .init(name: "Obadiah", svdID: "OBA", chapterCount: 1),
        .init(name: "Jonah", svdID: "JON", chapterCount: 4),
        .init(name: "Micah", svdID: "MIC", chapterCount: 7),
        .init(name: "Nahum", svdID: "NAM", chapterCount: 3),
        .init(name: "Habakkuk", svdID: "HAB", chapterCount: 3),
        .init(name: "Zephaniah", svdID: "ZEP", chapterCount: 3),
        .init(name: "Haggai", svdID: "HAG", chapterCount: 2),
        .init(name: "Zechariah", svdID: "ZEC", chapterCount: 14),
        .init(name: "Malachi", svdID: "MAL", chapterCount: 4),
        .init(name: "Matthew", svdID: "MAT", chapterCount: 28),
        .init(name: "Mark", svdID: "MRK", chapterCount: 16),
        .init(name: "Luke", svdID: "LUK", chapterCount: 24),
        .init(name: "John", svdID: "JHN", chapterCount: 21),
        .init(name: "Acts", svdID: "ACT", chapterCount: 28),
        .init(name: "Romans", svdID: "ROM", chapterCount: 16),
        .init(name: "1 Corinthians", svdID: "1CO", chapterCount: 16),
        .init(name: "2 Corinthians", svdID: "2CO", chapterCount: 13),
        .init(name: "Galatians", svdID: "GAL", chapterCount: 6),
        .init(name: "Ephesians", svdID: "EPH", chapterCount: 6),
        .init(name: "Philippians", svdID: "PHP", chapterCount: 4),
        .init(name: "Colossians", svdID: "COL", chapterCount: 4),
        .init(name: "1 Thessalonians", svdID: "1TH", chapterCount: 5),
        .init(name: "2 Thessalonians", svdID: "2TH", chapterCount: 3),
        .init(name: "1 Timothy", svdID: "1TI", chapterCount: 6),
        .init(name: "2 Timothy", svdID: "2TI", chapterCount: 4),
        .init(name: "Titus", svdID: "TIT", chapterCount: 3),
        .init(name: "Philemon", svdID: "PHM", chapterCount: 1),
        .init(name: "Hebrews", svdID: "HEB", chapterCount: 13),
        .init(name: "James", svdID: "JAS", chapterCount: 5),
        .init(name: "1 Peter", svdID: "1PE", chapterCount: 5),
        .init(name: "2 Peter", svdID: "2PE", chapterCount: 3),
        .init(name: "1 John", svdID: "1JN", chapterCount: 5),
        .init(name: "2 John", svdID: "2JN", chapterCount: 1),
        .init(name: "3 John", svdID: "3JN", chapterCount: 1),
        .init(name: "Jude", svdID: "JUD", chapterCount: 1),
        .init(name: "Revelation", svdID: "REV", chapterCount: 22),
    ]

    static let oldTestament = Array(all.prefix(39))
    static let newTestament = Array(all.dropFirst(39))
}
