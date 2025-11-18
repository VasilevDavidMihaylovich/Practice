//
//  LibraryViewModel.swift
//  KFUPractice
//
//  AI Reader App
//

import Foundation
import SwiftUI
import PDFKit
import Combine

/// ViewModel для экрана библиотеки книг
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var sortBy: BookSortOption = .dateAdded
    @Published var filterBy: BookFilterOption = .all
    @Published var smartNotes: [Note] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    // Реальный сервис для хранения книг
    private let bookStorage = BookStorageService.shared
    
    init() {
        print("📱 [LibraryViewModel] Инициализация LibraryViewModel")
        // Загружаем сохраненные книги при инициализации
        loadBooks()
        // Загружаем умные заметки
        loadSmartNotes()
        // Показываем информацию о хранилище для диагностики
        bookStorage.getStorageInfo()
        
        // Подписываемся на изменения в NotesManager для автоматического обновления
        NotesManager.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.loadSmartNotes()
            }
        }.store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Загрузить все книги с подробным логированием
    func loadBooks() {
        print("📱 [LibraryViewModel] Загрузка книг...")
        isLoading = true
        errorMessage = nil
        
        // Загружаем книги из хранилища
        let loadedBooks = bookStorage.loadBooks()
        print("📱 [LibraryViewModel] Загружено книг из хранилища: \(loadedBooks.count)")
        
        // Фильтруем книги по существованию файлов (уже делается в BookStorageService, но для надежности)
        let validBooks = loadedBooks.filter { book in
            let exists = bookStorage.bookFileExists(at: book.filePath)
            if !exists {
                print("⚠️ [LibraryViewModel] Файл не найден: \(book.filePath)")
            }
            return exists
        }
        
        print("📱 [LibraryViewModel] Валидных книг: \(validBooks.count)")
        
        // Если некоторые файлы были удалены, обновляем хранилище
        if validBooks.count != loadedBooks.count {
            print("📱 [LibraryViewModel] Обновляем хранилище, удаляем \(loadedBooks.count - validBooks.count) недоступных книг")
            bookStorage.saveBooks(validBooks)
        }
        
        // Сортируем книги
        let sortedBooks = validBooks.sorted(by: sortBy.sortFunction)
        
        // Обновляем UI
        books = sortedBooks
        isLoading = false
        
        print("📱 [LibraryViewModel] Загрузка завершена, отображается \(books.count) книг")
    }
    
    /// Импортировать книгу из файла
    func importBook(from fileURL: URL) async {
        isLoading = true
        errorMessage = nil
        
        print("📚 Начинаем импорт книги: \(fileURL.lastPathComponent)")
        
        do {
            // Создаем книгу и добавляем в хранилище
            if let newBook = bookStorage.createBook(from: fileURL) {
                print("✅ Книга создана: \(newBook.title) (\(newBook.format.displayName))")
                
                // Добавляем книгу в хранилище (синхронно)
                bookStorage.addBook(newBook)
                print("✅ Книга добавлена в хранилище")
                
                // Обновляем UI на главном потоке
                await MainActor.run {
                    loadBooks() // Перезагружаем список
                    print("🔄 Список книг обновлен, всего книг: \(books.count)")
                }
            } else {
                print("❌ Не удалось создать книгу из файла")
                await MainActor.run {
                    errorMessage = "Не удалось импортировать книгу"
                }
            }
        } catch {
            print("❌ Ошибка импорта: \(error)")
            await MainActor.run {
                errorMessage = "Ошибка импорта: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    /// Удалить книгу
    func deleteBook(_ book: Book) {
        // Удаляем файл книги
        bookStorage.deleteBookFile(at: book.filePath)
        
        // Удаляем из хранилища
        bookStorage.removeBook(withId: book.id)
        
        // Обновляем UI
        loadBooks()
    }
    
    /// Обновить прогресс чтения
    func updateReadingProgress(for book: Book, progress: Double) {
        let newPosition = ReadingPosition(
            pageNumber: Int(Double(book.pageCount ?? 100) * progress),
            progressPercentage: progress
        )
        
        bookStorage.updateReadingPosition(for: book.id, position: newPosition)
        loadBooks() // Обновляем UI
    }
    
    /// Обновить позицию чтения
    func updateReadingPosition(for book: Book, position: ReadingPosition) {
        bookStorage.updateReadingPosition(for: book.id, position: position)
        loadBooks() // Обновляем UI
    }
    
    /// Поиск книг
    func searchBooks(query: String) {
        searchText = query
        // TODO: Реализовать поиск по названию и автору
        if query.isEmpty {
            loadBooks()
        } else {
            let allBooks = bookStorage.loadBooks()
            books = allBooks.filter { book in
                book.title.localizedCaseInsensitiveContains(query) ||
                book.displayAuthor.localizedCaseInsensitiveContains(query)
            }.sorted(by: sortBy.sortFunction)
        }
    }
    
    /// Поиск умных заметок
    func searchNotes(query: String) {
        if query.isEmpty {
            loadSmartNotes()
        } else {
            // Получаем все умные заметки из NotesManager
            let allSmartNotes = NotesManager.shared.getAllSmartNotes()
            
            // Фильтруем заметки по поисковому запросу
            smartNotes = allSmartNotes.filter { note in
                note.selectedText.localizedCaseInsensitiveContains(query) ||
                (note.userText?.localizedCaseInsensitiveContains(query) ?? false)
            }
            
            print("🔍 [LibraryViewModel] Поиск '\(query)': найдено \(smartNotes.count) заметок")
        }
    }
    
    /// Сортировка книг
    func sortBooks(by option: BookSortOption) {
        sortBy = option
        books = books.sorted(by: option.sortFunction)
    }
    
    /// Фильтрация книг
    func filterBooks(by option: BookFilterOption) {
        filterBy = option
        let allBooks = bookStorage.loadBooks()
        books = allBooks.filter { option.matches(book: $0) }.sorted(by: sortBy.sortFunction)
    }
    
    /// Получить отфильтрованные книги
    var filteredBooks: [Book] {
        var result = books
        
        // Применяем поиск
        if !searchText.isEmpty {
            result = result.filter { book in
                book.title.localizedCaseInsensitiveContains(searchText) ||
                book.displayAuthor.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Применяем фильтр
        result = result.filter { filterBy.matches(book: $0) }
        
        return result.sorted(by: sortBy.sortFunction)
    }
    
    /// Загрузить все умные заметки из всех книг
    func loadSmartNotes() {
        print("🧠 [LibraryViewModel] Загрузка умных заметок...")
        
        // Получаем все умные заметки из NotesManager
        smartNotes = NotesManager.shared.getAllSmartNotes()
        
        print("🧠 [LibraryViewModel] Загружено умных заметок: \(smartNotes.count)")
        
        // Выводим статистику для отладки
        NotesManager.shared.printStatistics()
    }
    
    /// Получить заметки для определенной книги
    private func getNotesForBook(_ bookId: UUID) -> [Note] {
        return NotesManager.shared.getNotesForBook(bookId)
    }
    
    // MARK: - Demo Content Creation
    
    /// Создает демонстрационный PDF файл для тестирования
    func createSamplePDFBook() async {
        print("📚 [LibraryViewModel] Создание демонстрационной PDF книги...")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let samplePDF = createSamplePDFDocument()
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let timestamp = Int(Date().timeIntervalSince1970)
            let pdfURL = documentsPath.appendingPathComponent("Books/Основы_Swift_\(timestamp).pdf")
            
            // Создаем директорию Books если её нет
            let booksDir = documentsPath.appendingPathComponent("Books")
            if !FileManager.default.fileExists(atPath: booksDir.path) {
                try FileManager.default.createDirectory(at: booksDir, withIntermediateDirectories: true)
            }
            
            // Сохраняем PDF файл
            let pdfData = samplePDF.dataRepresentation()
            try pdfData?.write(to: pdfURL)
            print("📚 [LibraryViewModel] PDF файл сохранен: \(pdfURL.path)")
            
            // Создаем объект книги
            let sampleBook = Book(
                id: UUID(),
                title: "Основы программирования на Swift",
                author: "Apple Developer Team",
                format: .pdf,
                filePath: pdfURL.path,
                fileSize: Int64(pdfData?.count ?? 0),
                pageCount: samplePDF.pageCount,
                dateAdded: Date(),
                isFinished: false,
                readingProgress: 0.0
            )
            
            print("📚 [LibraryViewModel] Создан объект книги: \(sampleBook.title)")
            
            // Добавляем книгу в библиотеку (синхронно)
            bookStorage.addBook(sampleBook)
            print("📚 [LibraryViewModel] Книга добавлена в хранилище")
            
            // Обновляем список книг на главном потоке
            await MainActor.run {
                loadBooks()
                print("📚 [LibraryViewModel] Список книг обновлен, всего: \(books.count)")
            }
            
        } catch {
            print("❌ [LibraryViewModel] Ошибка создания демонстрационной книги: \(error)")
            await MainActor.run {
                errorMessage = "Ошибка создания демонстрационного PDF: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    /// Создает PDFDocument с демонстрационным содержимым
    private func createSamplePDFDocument() -> PDFDocument {
        let pdfDocument = PDFDocument()
        
        // Создаем страницы с содержимым
        let pages = [
            createPDFPage(with: """
            Основы программирования на Swift
            
            Глава 1: Введение в Swift
            
            Swift — это мощный и интуитивно понятный язык программирования для iOS, macOS, watchOS и tvOS. Создание приложений никогда не было таким увлекательным.
            
            Swift включает современные возможности, которые разработчики любят. Синтаксис Swift краток, но выразителен, а код работает молниеносно. Swift готов к использованию, от телефона до сервера.
            
            Основные преимущества Swift:
            • Безопасность типов
            • Управление памятью
            • Высокая производительность
            • Современный синтаксис
            
            В этом руководстве мы рассмотрим основные концепции языка Swift и научимся создавать простые программы.
            """),
            
            createPDFPage(with: """
            Глава 2: Переменные и константы
            
            В Swift есть два способа хранения значений:
            
            let константа = "Неизменяемое значение"
            var переменная = "Изменяемое значение"
            
            Константы объявляются с помощью ключевого слова let, а переменные — с помощью var.
            
            Типы данных:
            • Int — целые числа
            • Double — числа с плавающей запятой
            • String — строки
            • Bool — логические значения
            
            Примеры:
            let name = "Alice"
            var age = 25
            let pi = 3.14159
            var isStudent = true
            
            Swift автоматически определяет тип переменной на основе присваиваемого значения.
            """),
            
            createPDFPage(with: """
            Глава 3: Функции
            
            Функции — это блоки кода, которые выполняют определенную задачу. Они принимают входные данные (параметры) и возвращают результат.
            
            Синтаксис функции:
            func имяФункции(параметр: Тип) -> ВозвращаемыйТип {
                // код функции
                return результат
            }
            
            Пример простой функции:
            func greet(name: String) -> String {
                return "Привет, \\(name)!"
            }
            
            let message = greet(name: "Мир")
            print(message) // Выводит: Привет, Мир!
            
            Функции могут иметь несколько параметров и могут не возвращать значение (тип Void).
            """)
        ]
        
        // Добавляем страницы в документ
        for (index, page) in pages.enumerated() {
            pdfDocument.insert(page, at: index)
        }
        
        return pdfDocument
    }
    
    /// Создает PDFPage с текстовым содержимым
    private func createPDFPage(with text: String) -> PDFPage {
        // Размер страницы A4
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        
        // Создаем контекст для рисования PDF
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        UIGraphicsBeginPDFPage()
        
        // Настройки для текста
        let textRect = CGRect(x: 50, y: 50, width: pageRect.width - 100, height: pageRect.height - 100)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.alignment = .left
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]
        
        // Рисуем текст
        text.draw(in: textRect, withAttributes: attributes)
        
        UIGraphicsEndPDFContext()
        
        // Создаем PDFPage из данных
        let pdfDocument = PDFDocument(data: pdfData as Data)!
        return pdfDocument.page(at: 0)!
    }
    
    // MARK: - Debug and Diagnostic Functions
    
    /// Очистить все книги (для отладки)
    func clearAllBooks() {
        print("🗑️ [LibraryViewModel] Очищаем все книги...")
        bookStorage.clearAllBooks()
        loadBooks()
        print("🗑️ [LibraryViewModel] Все книги удалены, текущее количество: \(books.count)")
    }
    
    /// Показать диагностическую информацию
    func showDiagnosticInfo() {
        print("🔍 [LibraryViewModel] Диагностическая информация:")
        print("🔍 [LibraryViewModel] Текущее количество книг в UI: \(books.count)")
        print("🔍 [LibraryViewModel] Состояние загрузки: \(isLoading)")
        print("🔍 [LibraryViewModel] Ошибки: \(errorMessage ?? "нет")")
        bookStorage.getStorageInfo()
    }
    
    /// Принудительно перезагрузить книги
    func forceReloadBooks() {
        print("🔄 [LibraryViewModel] Принудительная перезагрузка книг...")
        loadBooks()
    }
}

// MARK: - Supporting Types

/// Опции сортировки книг
enum BookSortOption: String, CaseIterable {
    case dateAdded = "date_added"
    case title = "title"
    case author = "author"
    case progress = "progress"
    case dateOpened = "date_opened"
    
    var displayName: String {
        switch self {
        case .dateAdded: return "Дате добавления"
        case .title: return "Названию"
        case .author: return "Автору"
        case .progress: return "Прогрессу"
        case .dateOpened: return "Последнему чтению"
        }
    }
    
    var sortFunction: (Book, Book) -> Bool {
        switch self {
        case .dateAdded:
            return { $0.dateAdded > $1.dateAdded }
        case .title:
            return { $0.title.lowercased() < $1.title.lowercased() }
        case .author:
            return { ($0.author ?? "").lowercased() < ($1.author ?? "").lowercased() }
        case .progress:
            return { $0.readingProgress > $1.readingProgress }
        case .dateOpened:
            return { ($0.dateLastOpened ?? Date.distantPast) > ($1.dateLastOpened ?? Date.distantPast) }
        }
    }
}

/// Опции фильтрации книг
enum BookFilterOption: String, CaseIterable {
    case all = "all"
    case reading = "reading"
    case finished = "finished"
    case notStarted = "not_started"
    
    var displayName: String {
        switch self {
        case .all: return "Все"
        case .reading: return "Читаю"
        case .finished: return "Прочитано"
        case .notStarted: return "Не начато"
        }
    }
    
    func matches(book: Book) -> Bool {
        switch self {
        case .all:
            return true
        case .reading:
            return book.readingProgress > 0 && !book.isFinished
        case .finished:
            return book.isFinished
        case .notStarted:
            return book.readingProgress == 0
        }
    }
}