//
//  BookStorageService.swift
//  KFUPractice
//
//  AI Reader App
//

import Foundation
import PDFKit

/// Сервис для сохранения и загрузки книг из UserDefaults
class BookStorageService {
    private let userDefaults = UserDefaults.standard
    private let booksKey = "SavedBooks"
    
    static let shared = BookStorageService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Загрузить все сохраненные книги
    func loadBooks() -> [Book] {
        guard let data = userDefaults.data(forKey: booksKey),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            return []
        }
        return books
    }
    
    /// Сохранить книги
    func saveBooks(_ books: [Book]) {
        do {
            let data = try JSONEncoder().encode(books)
            userDefaults.set(data, forKey: booksKey)
            userDefaults.synchronize()
        } catch {
            print("Ошибка сохранения книг: \(error)")
        }
    }
    
    /// Добавить книгу
    func addBook(_ book: Book) {
        var books = loadBooks()
        
        // Проверяем, что книга еще не добавлена
        if !books.contains(where: { $0.filePath == book.filePath }) {
            books.append(book)
            saveBooks(books)
        }
    }
    
    /// Удалить книгу
    func removeBook(withId id: UUID) {
        var books = loadBooks()
        books.removeAll { $0.id == id }
        saveBooks(books)
    }
    
    /// Обновить книгу
    func updateBook(_ updatedBook: Book) {
        var books = loadBooks()
        
        if let index = books.firstIndex(where: { $0.id == updatedBook.id }) {
            books[index] = updatedBook
            saveBooks(books)
        }
    }
    
    /// Обновить позицию чтения для книги
    func updateReadingPosition(for bookId: UUID, position: ReadingPosition) {
        var books = loadBooks()
        
        if let index = books.firstIndex(where: { $0.id == bookId }) {
            var book = books[index]
            book.currentPosition = position
            book.readingProgress = position.progressPercentage
            books[index] = book
            saveBooks(books)
        }
    }
    
    /// Получить книгу по ID
    func getBook(by id: UUID) -> Book? {
        let books = loadBooks()
        return books.first { $0.id == id }
    }
    
    /// Очистить все книги (для отладки)
    func clearAllBooks() {
        userDefaults.removeObject(forKey: booksKey)
        userDefaults.synchronize()
    }
}

// MARK: - File Management Extensions

extension BookStorageService {
    /// Копировать файл книги в документы приложения
    func copyBookToDocuments(from sourceURL: URL) -> URL? {
        guard sourceURL.startAccessingSecurityScopedResource() else {
            print("Нет доступа к файлу: \(sourceURL)")
            return nil
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        
        do {
            // Создаем папку для книг если ее нет
            let documentsURL = getDocumentsDirectory()
            let booksDirectory = documentsURL.appendingPathComponent("Books")
            
            if !FileManager.default.fileExists(atPath: booksDirectory.path) {
                try FileManager.default.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
            }
            
            // Создаем уникальное имя файла
            let fileName = sourceURL.lastPathComponent
            let destinationURL = booksDirectory.appendingPathComponent(fileName)
            
            // Если файл уже существует, добавляем номер
            var finalDestination = destinationURL
            var counter = 1
            while FileManager.default.fileExists(atPath: finalDestination.path) {
                let nameWithoutExtension = sourceURL.deletingPathExtension().lastPathComponent
                let fileExtension = sourceURL.pathExtension
                let newFileName = "\(nameWithoutExtension)_\(counter).\(fileExtension)"
                finalDestination = booksDirectory.appendingPathComponent(newFileName)
                counter += 1
            }
            
            // Копируем файл
            try FileManager.default.copyItem(at: sourceURL, to: finalDestination)
            return finalDestination
            
        } catch {
            print("Ошибка копирования файла: \(error)")
            return nil
        }
    }
    
    /// Удалить файл книги из документов
    func deleteBookFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Ошибка удаления файла: \(error)")
        }
    }
    
    /// Проверить, существует ли файл книги
    func bookFileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// Получить размер файла
    func getFileSize(at path: String) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - Book Creation Helpers

extension BookStorageService {
    /// Создать модель книги из файла
    func createBook(from fileURL: URL) -> Book? {
        print("🔧 Создаем книгу из файла: \(fileURL.lastPathComponent)")
        
        // Копируем файл в документы приложения
        guard let localFileURL = copyBookToDocuments(from: fileURL) else {
            print("❌ Не удалось скопировать файл в Documents")
            return nil
        }
        
        print("📁 Файл скопирован в: \(localFileURL.path)")
        
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        let fileSize = getFileSize(at: localFileURL.path)
        
        print("📊 Размер файла: \(fileSize) байт, расширение: \(fileExtension)")
        
        // Определяем формат книги
        let format: BookFormat
        switch fileExtension {
        case "pdf": format = .pdf
        case "epub": format = .epub
        case "docx": format = .docx
        case "txt": format = .txt
        default: format = .txt
        }
        
        print("📖 Определен формат: \(format.displayName)")
        
        // Извлекаем метаданные (теперь с реальным подсчетом страниц)
        let metadata = extractBasicMetadata(from: localFileURL, format: format)
        
        print("📝 Метаданные: title=\(metadata.title ?? "nil"), author=\(metadata.author ?? "nil"), pages=\(metadata.pageCount ?? 0)")
        
        let book = Book(
            title: metadata.title ?? fileName,
            author: metadata.author,
            format: format,
            filePath: localFileURL.path,
            fileSize: fileSize,
            pageCount: metadata.pageCount
        )
        
        print("✅ Книга создана успешно: \(book.title)")
        
        return book
    }
    
    /// Извлечь базовые метаданные из файла
    private func extractBasicMetadata(from fileURL: URL, format: BookFormat) -> (title: String?, author: String?, pageCount: Int?) {
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        
        // Простая эвристика для извлечения автора из имени файла
        var author: String? = nil
        var title: String? = nil
        
        // Для EPUB пытаемся извлечь метаданные из самого файла
        if format == .epub {
            if let epubMetadata = extractEPUBMetadata(from: fileURL) {
                title = epubMetadata.title ?? fileName
                author = epubMetadata.creator
            }
        }
        
        // Если не EPUB или не удалось извлечь, используем имя файла
        if title == nil {
            // Если в имени файла есть " - ", предполагаем формат "Автор - Название"
            if fileName.contains(" - ") {
                let parts = fileName.components(separatedBy: " - ")
                if parts.count >= 2 {
                    author = parts[0].trimmingCharacters(in: .whitespaces)
                    title = parts[1].trimmingCharacters(in: .whitespaces)
                }
            } else {
                title = fileName
            }
        }
        
        // Подсчитываем реальное количество страниц в зависимости от формата
        var pageCount: Int? = nil
        switch format {
        case .pdf:
            pageCount = getPDFPageCount(from: fileURL)
        case .txt:
            pageCount = getTextPageCount(from: fileURL)
        case .epub:
            pageCount = getEPUBPageCount(from: fileURL)
        case .docx:
            pageCount = 1 // Пока заглушка для DOCX
        }
        
        return (title: title, author: author, pageCount: pageCount)
    }
    
    /// Получить количество страниц PDF
    private func getPDFPageCount(from fileURL: URL) -> Int? {
        guard let pdfDocument = PDFDocument(url: fileURL) else {
            return nil
        }
        return pdfDocument.pageCount
    }
    
    /// Получить количество страниц для текстового файла
    private func getTextPageCount(from fileURL: URL) -> Int? {
        do {
            // Пробуем разные кодировки
            let content = try loadTextContentWithEncoding(from: fileURL)
            
            // Используем ту же логику разбивки что и в ReadingViewModel
            let pages = splitTextIntoPages(content)
            return pages.count
            
        } catch {
            print("Ошибка подсчета страниц TXT: \(error)")
            return nil
        }
    }
    
    /// Получить количество страниц для EPUB файла
    private func getEPUBPageCount(from fileURL: URL) -> Int? {
        print("📊 Подсчитываем страницы EPUB файла: \(fileURL.lastPathComponent)")
        do {
            let parser = EPUBParser()
            let epubDocument = try parser.parseEPUB(at: fileURL)
            let pageCount = epubDocument.totalPages
            print("📄 EPUB содержит \(pageCount) страниц")
            return pageCount
        } catch {
            print("❌ Ошибка подсчета страниц EPUB: \(error)")
            return nil
        }
    }
    
    /// Извлекает метаданные из EPUB файла
    private func extractEPUBMetadata(from fileURL: URL) -> EPUBMetadata? {
        print("📋 Извлекаем метаданные из EPUB: \(fileURL.lastPathComponent)")
        do {
            let parser = EPUBParser()
            let epubDocument = try parser.parseEPUB(at: fileURL)
            let metadata = epubDocument.package.metadata
            print("📝 EPUB метаданные: title=\(metadata.title ?? "nil"), creator=\(metadata.creator ?? "nil")")
            return metadata
        } catch {
            print("❌ Ошибка извлечения метаданных EPUB: \(error)")
            return nil
        }
    }
    
    /// Загружает текстовый файл пробуя разные кодировки
    private func loadTextContentWithEncoding(from url: URL) throws -> String {
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .windowsCP1251, // Для русского текста
            .ascii,
            .isoLatin1
        ]
        
        for encoding in encodings {
            if let content = try? String(contentsOf: url, encoding: encoding) {
                return content
            }
        }
        
        throw NSError(domain: "TextLoading", code: 1, 
                      userInfo: [NSLocalizedDescriptionKey: "Не удалось определить кодировку файла"])
    }
    
    /// Разбивает текст на страницы (та же логика что в ReadingViewModel)
    private func splitTextIntoPages(_ content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var pages: [String] = []
        var currentPage = ""
        let targetCharsPerPage = 1000
        let maxCharsPerPage = 1200
        
        for line in lines {
            let lineWithNewline = line + "\n"
            
            if currentPage.count + lineWithNewline.count > maxCharsPerPage && !currentPage.isEmpty {
                pages.append(currentPage.trimmingCharacters(in: .whitespacesAndNewlines))
                currentPage = lineWithNewline
            }
            else if currentPage.count + lineWithNewline.count >= targetCharsPerPage && 
                    line.trimmingCharacters(in: .whitespaces).isEmpty && 
                    !currentPage.isEmpty {
                pages.append(currentPage.trimmingCharacters(in: .whitespacesAndNewlines))
                currentPage = ""
            }
            else {
                currentPage += lineWithNewline
            }
        }
        
        if !currentPage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pages.append(currentPage.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return pages.isEmpty ? [""] : pages
    }
}