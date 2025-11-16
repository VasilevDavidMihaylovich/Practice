//
//  BookServiceProtocol.swift
//  KFUPractice
//
//  AI Reader App
//

import Foundation
import UIKit

/// Протокол для работы с книгами и файлами
protocol BookServiceProtocol {
    /// Импортировать книгу из файла
    /// - Parameter fileURL: URL файла книги
    /// - Returns: Импортированная книга
    func importBook(from fileURL: URL) async throws -> Book
    
    /// Получить список всех книг
    /// - Returns: Массив книг
    func getAllBooks() async throws -> [Book]
    
    /// Получить книгу по ID
    /// - Parameter id: Идентификатор книги
    /// - Returns: Книга или nil если не найдена
    func getBook(by id: UUID) async throws -> Book?
    
    /// Удалить книгу
    /// - Parameter book: Книга для удаления
    func deleteBook(_ book: Book) async throws
    
    /// Обновить метаданные книги
    /// - Parameter book: Книга с обновленными данными
    /// - Returns: Обновленная книга
    func updateBook(_ book: Book) async throws -> Book
    
    /// Получить содержимое страницы
    /// - Parameters:
    ///   - book: Книга
    ///   - pageNumber: Номер страницы
    /// - Returns: Содержимое страницы
    func getPageContent(book: Book, pageNumber: Int) async throws -> PageContent
    
    /// Поиск по содержимому книги
    /// - Parameters:
    ///   - book: Книга для поиска
    ///   - query: Поисковый запрос
    ///   - options: Опции поиска
    /// - Returns: Результаты поиска
    func searchInBook(
        book: Book,
        query: String,
        options: SearchOptions
    ) async throws -> [SearchResult]
    
    /// Обновить позицию чтения
    /// - Parameters:
    ///   - book: Книга
    ///   - position: Новая позиция
    /// - Returns: Обновленная книга
    func updateReadingPosition(
        book: Book,
        position: ReadingPosition
    ) async throws -> Book
    
    /// Получить превью обложки книги
    /// - Parameter book: Книга
    /// - Returns: Изображение обложки
    func getCoverImage(for book: Book) async throws -> UIImage?
    
    /// Экспортировать книгу
    /// - Parameters:
    ///   - book: Книга для экспорта
    ///   - format: Формат экспорта
    /// - Returns: URL экспортированного файла
    func exportBook(
        _ book: Book,
        to format: BookFormat
    ) async throws -> URL
}

/// Содержимое страницы книги
struct PageContent {
    let pageNumber: Int
    let text: String                  // Основной текст
    let images: [PageImage]          // Изображения на странице
    let formulas: [PageFormula]      // Формулы на странице
    let annotations: [PageAnnotation] // Аннотации
    let metadata: PageMetadata       // Метаданные страницы
    
    init(
        pageNumber: Int,
        text: String = "",
        images: [PageImage] = [],
        formulas: [PageFormula] = [],
        annotations: [PageAnnotation] = [],
        metadata: PageMetadata = PageMetadata()
    ) {
        self.pageNumber = pageNumber
        self.text = text
        self.images = images
        self.formulas = formulas
        self.annotations = annotations
        self.metadata = metadata
    }
}

/// Изображение на странице
struct PageImage {
    let id: UUID
    let boundingRect: CGRect         // Позиция на странице
    let imageData: Data?            // Данные изображения
    let caption: String?            // Подпись к изображению
    let altText: String?           // Альтернативный текст
}

/// Формула на странице
struct PageFormula {
    let id: UUID
    let boundingRect: CGRect         // Позиция на странице
    let text: String                // Текстовое представление
    let latexCode: String?          // LaTeX код
    let isInline: Bool              // Встроенная или отдельная
    let formula: Formula?           // Связанная модель формулы
}

/// Аннотация на странице
struct PageAnnotation {
    let id: UUID
    let boundingRect: CGRect         // Позиция на странице
    let text: String                // Текст аннотации
    let type: AnnotationType        // Тип аннотации
    let author: String?             // Автор аннотации
}

/// Типы аннотаций
enum AnnotationType: String, CaseIterable {
    case highlight = "highlight"     // Выделение
    case note = "note"              // Заметка
    case bookmark = "bookmark"      // Закладка
    case link = "link"             // Ссылка
    case comment = "comment"       // Комментарий
}

/// Метаданные страницы
struct PageMetadata {
    let characterCount: Int         // Количество символов
    let wordCount: Int             // Количество слов
    let readingTimeMinutes: Int    // Время чтения в минутах
    let difficulty: Double         // Сложность текста (0.0-1.0)
    let language: String           // Язык страницы
    let chapterTitle: String?      // Название главы
    let sectionTitle: String?      // Название раздела
    
    init(
        characterCount: Int = 0,
        wordCount: Int = 0,
        readingTimeMinutes: Int = 0,
        difficulty: Double = 0.5,
        language: String = "ru",
        chapterTitle: String? = nil,
        sectionTitle: String? = nil
    ) {
        self.characterCount = characterCount
        self.wordCount = wordCount
        self.readingTimeMinutes = readingTimeMinutes
        self.difficulty = difficulty
        self.language = language
        self.chapterTitle = chapterTitle
        self.sectionTitle = sectionTitle
    }
}

/// Опции поиска в книге
struct SearchOptions {
    let caseSensitive: Bool         // Учитывать регистр
    let wholeWords: Bool           // Только целые слова
    let regex: Bool                // Использовать регулярные выражения
    let includeImages: Bool        // Искать в подписях к изображениям
    let includeFormulas: Bool      // Искать в формулах
    let maxResults: Int           // Максимальное количество результатов
    
    static let `default` = SearchOptions(
        caseSensitive: false,
        wholeWords: false,
        regex: false,
        includeImages: true,
        includeFormulas: true,
        maxResults: 100
    )
}

/// Результат поиска
struct SearchResult {
    let pageNumber: Int
    let text: String               // Найденный текст
    let context: String           // Контекст вокруг найденного текста
    let boundingRect: CGRect?     // Позиция на странице
    let matchType: SearchMatchType // Тип совпадения
    let relevance: Double         // Релевантность (0.0-1.0)
}

/// Типы совпадений при поиске
enum SearchMatchType: String {
    case exact = "exact"           // Точное совпадение
    case partial = "partial"       // Частичное совпадение
    case fuzzy = "fuzzy"          // Нечеткое совпадение
    case formula = "formula"       // Совпадение в формуле
    case image = "image"          // Совпадение в подписи к изображению
}

/// Протокол для чтения конкретных форматов книг
protocol BookReaderProtocol {
    /// Поддерживаемые форматы
    var supportedFormats: [BookFormat] { get }
    
    /// Проверить, поддерживается ли формат
    func canRead(format: BookFormat) -> Bool
    
    /// Извлечь метаданные из файла
    func extractMetadata(from fileURL: URL) async throws -> BookMetadata
    
    /// Получить общее количество страниц
    func getPageCount(from fileURL: URL) async throws -> Int
    
    /// Прочитать содержимое страницы
    func readPage(
        from fileURL: URL,
        pageNumber: Int
    ) async throws -> PageContent
    
    /// Получить оглавление
    func getTableOfContents(from fileURL: URL) async throws -> [TableOfContentsItem]
    
    /// Получить изображение обложки
    func extractCoverImage(from fileURL: URL) async throws -> UIImage?
}

/// Метаданные книги
struct BookMetadata {
    let title: String?
    let author: String?
    let publisher: String?
    let publicationDate: Date?
    let isbn: String?
    let language: String?
    let description: String?
    let genre: String?
    let pageCount: Int?
    let fileSize: Int64
    let format: BookFormat
    let version: String?
}

/// Элемент оглавления
struct TableOfContentsItem {
    let id: UUID
    let title: String
    let pageNumber: Int
    let level: Int                // Уровень вложенности (0, 1, 2, ...)
    let children: [TableOfContentsItem] // Дочерние элементы
}

/// Ошибки работы с книгами
enum BookServiceError: LocalizedError {
    case fileNotFound
    case unsupportedFormat(BookFormat)
    case corrupted(String)
    case permissionDenied
    case insufficientSpace
    case networkError(Error)
    case parsingError(String)
    case encryptedFile
    case oversized(Int64)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Файл не найден"
        case .unsupportedFormat(let format):
            return "Неподдерживаемый формат: \(format.displayName)"
        case .corrupted(let details):
            return "Поврежденный файл: \(details)"
        case .permissionDenied:
            return "Отказано в доступе"
        case .insufficientSpace:
            return "Недостаточно места на диске"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .parsingError(let details):
            return "Ошибка разбора: \(details)"
        case .encryptedFile:
            return "Зашифрованный файл не поддерживается"
        case .oversized(let size):
            let formatter = ByteCountFormatter()
            let sizeString = formatter.string(fromByteCount: size)
            return "Файл слишком большой: \(sizeString)"
        case .unknown(let message):
            return "Неизвестная ошибка: \(message)"
        }
    }
}

/// Протокол для кеширования содержимого книг
protocol BookCacheProtocol {
    /// Кешировать страницу
    func cachePage(_ content: PageContent, for bookId: UUID)
    
    /// Получить страницу из кеша
    func getCachedPage(bookId: UUID, pageNumber: Int) -> PageContent?
    
    /// Очистить кеш для книги
    func clearCache(for bookId: UUID)
    
    /// Очистить весь кеш
    func clearAllCache()
    
    /// Размер кеша
    var cacheSize: Int64 { get }
}

/// Протокол для синхронизации книг
protocol BookSyncProtocol {
    /// Синхронизировать книги с облаком
    func syncBooks() async throws
    
    /// Загрузить книгу в облако
    func uploadBook(_ book: Book) async throws
    
    /// Скачать книгу из облака
    func downloadBook(id: UUID) async throws -> Book
    
    /// Проверить статус синхронизации
    func getSyncStatus() -> BookSyncStatus
}

/// Статус синхронизации
enum BookSyncStatus {
    case idle
    case syncing
    case success
    case failed(Error)
}