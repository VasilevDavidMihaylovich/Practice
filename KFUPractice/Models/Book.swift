//
//  Book.swift
//  KFUPractice
//
//  AI Reader App
//

import Foundation

/// Поддерживаемые форматы книг
enum BookFormat: String, CaseIterable, Codable {
    case pdf = "pdf"
    case epub = "epub"
    case docx = "docx"
    case txt = "txt"
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .epub: return "EPUB"
        case .docx: return "DOCX"
        case .txt: return "TXT"
        }
    }
    
    var fileExtensions: [String] {
        switch self {
        case .pdf: return ["pdf"]
        case .epub: return ["epub"]
        case .docx: return ["docx"]
        case .txt: return ["txt"]
        }
    }
}

/// Модель книги с метаданными
struct Book: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let author: String?
    let format: BookFormat
    let filePath: String
    let coverImagePath: String?
    let fileSize: Int64
    let pageCount: Int?
    let dateAdded: Date
    let dateLastOpened: Date?
    
    // Прогресс чтения
    var currentPosition: ReadingPosition?
    var isFinished: Bool
    var readingProgress: Double // 0.0 - 1.0
    
    init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        format: BookFormat,
        filePath: String,
        coverImagePath: String? = nil,
        fileSize: Int64,
        pageCount: Int? = nil,
        dateAdded: Date = Date(),
        dateLastOpened: Date? = nil,
        currentPosition: ReadingPosition? = nil,
        isFinished: Bool = false,
        readingProgress: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.format = format
        self.filePath = filePath
        self.coverImagePath = coverImagePath
        self.fileSize = fileSize
        self.pageCount = pageCount
        self.dateAdded = dateAdded
        self.dateLastOpened = dateLastOpened
        self.currentPosition = currentPosition
        self.isFinished = isFinished
        self.readingProgress = readingProgress
    }
}

// MARK: - Helper Extensions

extension Book {
    /// Форматированный размер файла
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    /// Отображаемое имя автора
    var displayAuthor: String {
        author ?? "Неизвестный автор"
    }
    
    /// Процент прогресса чтения
    var progressPercentage: Int {
        Int(readingProgress * 100)
    }
    
    /// URL файла книги
    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }
    
    /// URL обложки (если есть)
    var coverImageURL: URL? {
        guard let coverImagePath = coverImagePath else { return nil }
        return URL(fileURLWithPath: coverImagePath)
    }
}

// MARK: - Sample Data for Development

extension Book {
    static let sampleBooks: [Book] = [
        Book(
            title: "Введение в квантовую физику",
            author: "А.И. Иванов",
            format: .pdf,
            filePath: "/sample/quantum_physics.pdf",
            fileSize: 5_242_880,
            pageCount: 324,
            readingProgress: 0.35
        ),
        Book(
            title: "Математический анализ",
            author: "Б.В. Петров",
            format: .epub,
            filePath: "/sample/math_analysis.epub",
            fileSize: 2_621_440,
            pageCount: 256,
            readingProgress: 0.75
        ),
        Book(
            title: "Теория алгоритмов",
            author: "С.Н. Сидоров",
            format: .docx,
            filePath: "/sample/algorithms.docx",
            fileSize: 1_048_576,
            pageCount: 128,
            readingProgress: 0.0
        )
    ]
}