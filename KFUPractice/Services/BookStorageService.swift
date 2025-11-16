//
//  BookStorageService.swift
//  KFUPractice
//
//  AI Reader App
//

import Foundation
import PDFKit

/// Сервис для сохранения и загрузки книг из UserDefaults и документов приложения
class BookStorageService {
    private let userDefaults = UserDefaults.standard
    private let booksKey = "KFUPractice_SavedBooks_v2" // Обновленный ключ для избежания конфликтов
    
    static let shared = BookStorageService()
    
    private init() {
        print("🏗️ [BookStorageService] Инициализация сервиса хранилища книг")
        print("🏗️ [BookStorageService] Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("🏗️ [BookStorageService] UserDefaults suite: \(userDefaults.description)")
        testStorage()
        setupBooksDirectory()
    }
    
    // MARK: - Public Methods
    
    /// Загрузить все сохраненные книги с fallback
    func loadBooks() -> [Book] {
        print("📖 [BookStorageService] Загружаем книги из UserDefaults...")
        print("📖 [BookStorageService] Используем ключ: \(booksKey)")
        
        // Сначала пытаемся загрузить из UserDefaults
        if let books = loadBooksFromUserDefaults() {
            print("📖 [BookStorageService] Загружено из UserDefaults: \(books.count) книг")
            return filterExistingBooks(books)
        }
        
        // Если не удалось, пытаемся загрузить из резервного файла
        if let books = loadBooksFromBackupFile() {
            print("📖 [BookStorageService] Загружено из резервного файла: \(books.count) книг")
            // Восстанавливаем в UserDefaults
            saveBooks(books)
            return filterExistingBooks(books)
        }
        
        print("📖 [BookStorageService] Книги не найдены, возвращаем пустой массив")
        return []
    }
    
    private func loadBooksFromUserDefaults() -> [Book]? {
        guard let data = userDefaults.data(forKey: booksKey) else {
            print("📖 [BookStorageService] Данные отсутствуют в UserDefaults")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let books = try decoder.decode([Book].self, from: data)
            print("📖 [BookStorageService] Успешно декодировано \(books.count) книг")
            return books
        } catch {
            print("❌ [BookStorageService] Ошибка декодирования из UserDefaults: \(error)")
            return nil
        }
    }
    
    private func filterExistingBooks(_ books: [Book]) -> [Book] {
        let validBooks = books.filter { book in
            bookFileExists(at: book.filePath)
        }
        
        if validBooks.count != books.count {
            print("⚠️ [BookStorageService] Отфильтровано \(books.count - validBooks.count) несуществующих файлов")
            // Обновляем хранилище без удаленных файлов
            saveBooks(validBooks)
        }
        
        return validBooks
    }
    
    /// Сохранить книги с дополнительными проверками
    func saveBooks(_ books: [Book]) {
        print("💾 [BookStorageService] Сохраняем \(books.count) книг в UserDefaults...")
        print("💾 [BookStorageService] Используем ключ: \(booksKey)")
        
        do {
            // Кодируем данные
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(books)
            print("💾 [BookStorageService] Закодировано \(data.count) байт данных")
            
            // Сохраняем в UserDefaults
            userDefaults.set(data, forKey: booksKey)
            
            // ВАЖНО: Принудительная синхронизация для симулятора
            let success = userDefaults.synchronize()
            print("💾 [BookStorageService] Синхронизация UserDefaults: \(success ? "✅ успешно" : "❌ ошибка")")
            
            // Дополнительная проверка записи в файл-дубликат
            saveBackupToFile(books)
            
            // Проверяем что данные действительно сохранились
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.verifyBooksSaved(originalBooks: books)
            }
        } catch {
            print("❌ [BookStorageService] Ошибка сохранения книг: \(error)")
        }
    }
    
    /// Добавить книгу
    func addBook(_ book: Book) {
        print("💾 [BookStorageService] Добавляем книгу: \(book.title)")
        
        var books = loadBooks()
        print("💾 [BookStorageService] Текущее количество книг: \(books.count)")
        
        // Проверяем, что книга еще не добавлена
        if !books.contains(where: { $0.filePath == book.filePath }) {
            books.append(book)
            print("💾 [BookStorageService] Книга добавлена в массив, новое количество: \(books.count)")
            saveBooks(books)
            print("💾 [BookStorageService] Книги сохранены в UserDefaults")
        } else {
            print("⚠️ [BookStorageService] Книга уже существует по пути: \(book.filePath)")
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
        print("🗑️ [BookStorageService] Очищаем все книги")
        userDefaults.removeObject(forKey: booksKey)
        userDefaults.synchronize()
    }
    
    /// Тестирование работы хранилища
    private func testStorage() {
        print("🧪 [BookStorageService] Тестируем работу хранилища...")
        
        // Проверяем доступность UserDefaults
        let testKey = "BookStorage_Test"
        let testValue = "test_\(Date().timeIntervalSince1970)"
        
        userDefaults.set(testValue, forKey: testKey)
        userDefaults.synchronize()
        
        if let retrievedValue = userDefaults.string(forKey: testKey), retrievedValue == testValue {
            print("🧪 [BookStorageService] ✅ UserDefaults работает корректно")
        } else {
            print("🧪 [BookStorageService] ❌ Проблема с UserDefaults!")
        }
        
        // Очищаем тестовый ключ
        userDefaults.removeObject(forKey: testKey)
        
        // Проверяем существующие книги
        let existingBooks = loadBooks()
        print("🧪 [BookStorageService] Найдено \(existingBooks.count) существующих книг")
    }
    
    /// Получить информацию о хранилище
    func getStorageInfo() {
        print("📊 [BookStorageService] Информация о хранилище:")
        print("📊 [BookStorageService] Ключ UserDefaults: \(booksKey)")
        
        let books = loadBooksFromUserDefaults() ?? []
        print("📊 - Всего книг в UserDefaults: \(books.count)")
        
        if let data = userDefaults.data(forKey: booksKey) {
            print("📊 - Размер данных UserDefaults: \(data.count) байт")
        } else {
            print("📊 - Данные UserDefaults отсутствуют")
        }
        
        // Проверяем резервный файл
        if let backupBooks = loadBooksFromBackupFile() {
            print("📊 - Книг в резервном файле: \(backupBooks.count)")
        } else {
            print("📊 - Резервный файл отсутствует")
        }
        
        let documentsURL = getDocumentsDirectory()
        let booksDirectory = documentsURL.appendingPathComponent("Books")
        print("📊 - Путь к папке Books: \(booksDirectory.path)")
        print("📊 - Папка Books существует: \(FileManager.default.fileExists(atPath: booksDirectory.path))")
        
        if FileManager.default.fileExists(atPath: booksDirectory.path) {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: booksDirectory.path)
                print("📊 - Файлов в папке Books: \(files.count)")
                for file in files {
                    print("📊   - \(file)")
                }
            } catch {
                print("📊 - Ошибка чтения папки Books: \(error)")
            }
        }
        
        for (index, book) in books.enumerated() {
            print("📊 - Книга \(index + 1): \(book.title) (\(book.format.displayName))")
            print("📊   Путь: \(book.filePath)")
            print("📊   Файл существует: \(bookFileExists(at: book.filePath))")
        }
    }
    
    // MARK: - Backup File Management
    
    private func saveBackupToFile(_ books: [Book]) {
        do {
            let documentsURL = getDocumentsDirectory()
            let backupURL = documentsURL.appendingPathComponent("books_backup.json")
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(books)
            
            try data.write(to: backupURL)
            print("💾 [BookStorageService] Резервная копия сохранена: \(backupURL.path)")
        } catch {
            print("❌ [BookStorageService] Ошибка сохранения резервной копии: \(error)")
        }
    }
    
    private func loadBooksFromBackupFile() -> [Book]? {
        do {
            let documentsURL = getDocumentsDirectory()
            let backupURL = documentsURL.appendingPathComponent("books_backup.json")
            
            guard FileManager.default.fileExists(atPath: backupURL.path) else {
                return nil
            }
            
            let data = try Data(contentsOf: backupURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let books = try decoder.decode([Book].self, from: data)
            
            print("📖 [BookStorageService] Загружено из резервного файла: \(books.count) книг")
            return books
        } catch {
            print("❌ [BookStorageService] Ошибка загрузки резервной копии: \(error)")
            return nil
        }
    }
    
    private func verifyBooksSaved(originalBooks: [Book]) {
        print("🔍 [BookStorageService] Проверяем сохранение...")
        
        if let savedData = userDefaults.data(forKey: booksKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decodedBooks = try decoder.decode([Book].self, from: savedData)
                print("🔍 [BookStorageService] Верификация: сохранено \(decodedBooks.count) книг")
                
                if decodedBooks.count == originalBooks.count {
                    print("✅ [BookStorageService] Количество книг совпадает")
                } else {
                    print("❌ [BookStorageService] Количество книг НЕ совпадает! Было: \(originalBooks.count), стало: \(decodedBooks.count)")
                }
            } catch {
                print("❌ [BookStorageService] Ошибка проверки сохраненных данных: \(error)")
            }
        } else {
            print("❌ [BookStorageService] Данные НЕ найдены в UserDefaults после сохранения!")
        }
    }
    
    private func setupBooksDirectory() {
        do {
            let documentsURL = getDocumentsDirectory()
            let booksDirectory = documentsURL.appendingPathComponent("Books")
            
            if !FileManager.default.fileExists(atPath: booksDirectory.path) {
                try FileManager.default.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
                print("📁 [BookStorageService] Создана папка Books: \(booksDirectory.path)")
            } else {
                print("📁 [BookStorageService] Папка Books уже существует: \(booksDirectory.path)")
            }
        } catch {
            print("❌ [BookStorageService] Ошибка создания папки Books: \(error)")
        }
    }
}

// MARK: - File Management Extensions

extension BookStorageService {
    /// Копировать файл книги в документы приложения с улучшенной обработкой
    func copyBookToDocuments(from sourceURL: URL) -> URL? {
        print("📁 [BookStorageService] Копируем файл: \(sourceURL.lastPathComponent)")
        
        guard sourceURL.startAccessingSecurityScopedResource() else {
            print("❌ [BookStorageService] Нет доступа к файлу: \(sourceURL)")
            return nil
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        
        do {
            // Создаем папку для книг если ее нет
            let documentsURL = getDocumentsDirectory()
            let booksDirectory = documentsURL.appendingPathComponent("Books")
            
            if !FileManager.default.fileExists(atPath: booksDirectory.path) {
                try FileManager.default.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
                print("📁 [BookStorageService] Создана папка Books")
            }
            
            // Создаем уникальное имя файла с timestamp для избежания конфликтов
            let originalFileName = sourceURL.lastPathComponent
            let nameWithoutExtension = sourceURL.deletingPathExtension().lastPathComponent
            let fileExtension = sourceURL.pathExtension
            let timestamp = Int(Date().timeIntervalSince1970)
            
            // Формат: OriginalName_timestamp.ext
            let uniqueFileName = "\(nameWithoutExtension)_\(timestamp).\(fileExtension)"
            let destinationURL = booksDirectory.appendingPathComponent(uniqueFileName)
            
            print("📁 [BookStorageService] Целевой путь: \(destinationURL.path)")
            
            // Проверяем что целевой файл не существует (маловероятно с timestamp, но на всякий случай)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
                print("📁 [BookStorageService] Удален существующий файл")
            }
            
            // Копируем файл
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("✅ [BookStorageService] Файл успешно скопирован: \(destinationURL.lastPathComponent)")
            
            // Проверяем что файл действительно скопировался
            let fileExists = FileManager.default.fileExists(atPath: destinationURL.path)
            print("📁 [BookStorageService] Проверка существования файла: \(fileExists)")
            
            if fileExists {
                let fileSize = getFileSize(at: destinationURL.path)
                print("📁 [BookStorageService] Размер скопированного файла: \(fileSize) байт")
                return destinationURL
            } else {
                print("❌ [BookStorageService] Файл не найден после копирования!")
                return nil
            }
            
        } catch {
            print("❌ [BookStorageService] Ошибка копирования файла: \(error)")
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

// MARK: - Drawing Management Extension

extension BookStorageService {
    private func drawingsKey(for bookId: UUID) -> String {
        return "PageDrawings_\(bookId.uuidString)"
    }
    
    /// Сохранить рисунки для книги
    func savePageDrawings(_ drawings: [Int: PageDrawing], for bookId: UUID) {
        let key = drawingsKey(for: bookId)
        
        do {
            let data = try JSONEncoder().encode(drawings)
            userDefaults.set(data, forKey: key)
            userDefaults.synchronize()
            print("💾 [BookStorage] Сохранено \(drawings.count) рисунков для книги \(bookId)")
        } catch {
            print("❌ [BookStorage] Ошибка сохранения рисунков: \(error)")
        }
    }
    
    /// Загрузить рисунки для книги
    func loadPageDrawings(for bookId: UUID) -> [Int: PageDrawing] {
        let key = drawingsKey(for: bookId)
        
        guard let data = userDefaults.data(forKey: key),
              let drawings = try? JSONDecoder().decode([Int: PageDrawing].self, from: data) else {
            print("📝 [BookStorage] Рисунки для книги \(bookId) не найдены")
            return [:]
        }
        
        print("📝 [BookStorage] Загружено \(drawings.count) рисунков для книги \(bookId)")
        return drawings
    }
    
    /// Удалить все рисунки для книги
    func removePageDrawings(for bookId: UUID) {
        let key = drawingsKey(for: bookId)
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()
        print("🗑️ [BookStorage] Удалены рисунки для книги \(bookId)")
    }
    
    /// Удалить рисунок для конкретной страницы
    func removeDrawing(for bookId: UUID, pageNumber: Int) {
        var drawings = loadPageDrawings(for: bookId)
        drawings.removeValue(forKey: pageNumber)
        savePageDrawings(drawings, for: bookId)
        print("🗑️ [BookStorage] Удален рисунок страницы \(pageNumber) для книги \(bookId)")
    }
    
    /// Проверить, есть ли рисунки для книги
    func hasDrawings(for bookId: UUID) -> Bool {
        let drawings = loadPageDrawings(for: bookId)
        return !drawings.isEmpty
    }
    
    /// Получить общее количество страниц с рисунками для книги
    func getDrawingPageCount(for bookId: UUID) -> Int {
        let drawings = loadPageDrawings(for: bookId)
        return drawings.count
    }
}