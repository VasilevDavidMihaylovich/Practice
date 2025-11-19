//
//  ReadingViewModel.swift
//  KFUPractice
//
//  AI Reader App - Reading functionality with AI integration
//

import Foundation
import SwiftUI
import UIKit
import PDFKit

/// ViewModel для экрана чтения книги
@MainActor
class ReadingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var id: UUID = .init()
    @Published var currentPageNumber: Int = 0 {
        didSet {
            updateCurrentPageContent()
        }
    }
    @Published var pages: [String] = [] {
        didSet {
            updateCurrentPageContent()
        }
    }
    @Published var currentPageContent: String = ""
    @Published var fullContent: String = ""
    @Published var isLoading: Bool = false
    @Published var isChangingPage: Bool = false  // Новое состояние для смены страниц
    @Published var errorMessage: String?
    
    // MARK: - AI и математические функции
    
    @Published var selectedFormula: Formula?
    @Published var formulaExplanation: Explanation?
    @Published var isAnalyzingFormula: Bool = false
    
    @Published var selectedText: String = ""
    @Published var textExplanation: Explanation?
    @Published var isAnalyzingText: Bool = false
    
    @Published var latestAIResult: AIResult?
    
    @Published var notes: [Note] = []
    @Published var readingSettings = ReadingSettings()
    
    // MARK: - UI State
    @Published var showSettingsPanel = false
    @Published var showExplanation = false
    
    // MARK: - Drawing Support
    @Published var showDrawingCanvas = false
    @Published var pageDrawings: [Int: PageDrawing] = [:]
    @Published var currentPageDrawing: PageDrawing?
    
    // MARK: - EPUB Support
    
    @Published var epubDocument: EPUBDocument?
    @Published var epubPages: [EPUBPage] = []
    @Published var currentChapterInfo: (title: String, chapterNumber: Int)?
    
    // MARK: - PDF Support
    
    @Published var pdfDocument: PDFDocument?
    
    // MARK: - Book Properties
    
    let book: Book
    
    // MARK: - Dependencies (протоколы для тестируемости)
    
    private let aiService: AIServiceProtocol
    private let mathEngine: MathEngineProtocol
    private let formulaRecognizer: FormulaRecognizerProtocol
    
    // MARK: - Initialization
    
    init(book: Book, 
         aiService: AIServiceProtocol = DefaultAIService(),
         mathEngine: MathEngineProtocol = DefaultMathEngine(),
         formulaRecognizer: FormulaRecognizerProtocol = DefaultFormulaRecognizer()) {
        
        self.book = book
        self.aiService = aiService
        self.mathEngine = mathEngine
        self.formulaRecognizer = formulaRecognizer
        
        print("📚 [ReadingViewModel] init")
        print("   • book.id: \(book.id)")
        print("   • book.title: \(book.title)")
        print("   • book.format: \(book.format)")
        print("   • book.filePath: \(book.filePath)")
        
        // Принудительно уведомляем об изменении настроек для корректного первичного отображения
        Task { @MainActor in
            self.objectWillChange.send()
            // НЕ вызываем updateCurrentPageContent() здесь, так как pages еще пустой
        }
        
        // Запускаем загрузку контента
        loadBookContent()
    }
    
    // MARK: - Content Loading
    
    func loadBookContent() {
        print("📖 [ReadingViewModel] loadBookContent() called for book: \(book.title) [format: \(book.format)]")
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fileExists = FileManager.default.fileExists(atPath: book.filePath)
                print("📁 [ReadingViewModel] fileExists at path '\(book.filePath)': \(fileExists)")
                
                if !fileExists {
                    print("⚠️ [ReadingViewModel] Файл по пути не найден ещё до выбора формата")
                }
                
                print("🔀 [ReadingViewModel] format switch: \(book.format)")
                
                switch book.format {
                case .txt:
                    print("📝 [ReadingViewModel] selected loader: loadTextContent()")
                    await loadTextContent()
                case .epub:
                    print("📚 [ReadingViewModel] selected loader: loadEPUBContent()")
                    await loadEPUBContent()
                case .pdf:
                    print("📄 [ReadingViewModel] selected loader: loadPDFContent()")
                    await loadPDFContent()
                case .docx:
                    print("📂 [ReadingViewModel] selected loader: loadDOCXContent()")
                    await loadDOCXContent()
                }
                
                await MainActor.run {
                    self.isLoading = false
                    print("✅ [ReadingViewModel] loadBookContent finished. pages.count = \(self.pages.count)")
                    
                    // ВАЖНО: Обновляем текущую страницу ПОСЛЕ загрузки данных
                    self.updateCurrentPageContent()
                    
                    // Принудительно обновляем настройки для корректного отображения
                    self.objectWillChange.send()
                    
                    // Загружаем сохраненные рисунки для книги
                    self.loadPageDrawings()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка загрузки книги: \(error.localizedDescription)"
                    self.isLoading = false
                    print("❌ [ReadingViewModel] loadBookContent error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadTextContent() async {
        do {
            let url = URL(fileURLWithPath: book.filePath)
            let content = try String(contentsOf: url)
            
            await MainActor.run {
                // Разбиваем на страницы (примерно 1000 символов на страницу)
                let chunkSize = 1000
                var chunks: [String] = []
                
                let lines = content.components(separatedBy: .newlines)
                var currentChunk = ""
                
                for line in lines {
                    if currentChunk.count + line.count > chunkSize && !currentChunk.isEmpty {
                        chunks.append(currentChunk)
                        currentChunk = line
                    } else {
                        currentChunk += currentChunk.isEmpty ? line : "\n" + line
                    }
                }
                
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                
                self.pages = chunks.isEmpty ? ["Книга пуста"] : chunks
                self.fullContent = content
                self.currentPageNumber = 0
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка чтения файла: \(error.localizedDescription)"
                self.pages = ["Ошибка загрузки содержимого"]
                self.fullContent = ""
            }
        }
    }
    
    private func loadEPUBContent() async {
        print("📚 [ReadingViewModel] loadEPUBContent() start")
        
        do {
            let url = URL(fileURLWithPath: book.filePath)
            print("🔗 [ReadingViewModel] EPUB URL: \(url)")
            
            // Проверяем, что файл существует
            let fileExists = FileManager.default.fileExists(atPath: book.filePath)
            print("📁 [ReadingViewModel] EPUB file exists at '\(book.filePath)': \(fileExists)")
            
            guard fileExists else {
                await MainActor.run {
                    self.errorMessage = "EPUB файл не найден по пути: \(book.filePath)"
                    self.pages = ["Файл EPUB не найден"]
                    self.fullContent = ""
                }
                print("❌ [ReadingViewModel] EPUB file NOT FOUND, aborting loadEPUBContent")
                return
            }
            
            print("🔍 [ReadingViewModel] Начинаем парсинг EPUB файла: \(url.lastPathComponent)")
            
            let parser = EPUBParser()
            let epubDoc = try parser.parseEPUB(at: url)
            
            print("✅ [ReadingViewModel] EPUB успешно распарсен")
            print("   • chapters.count = \(epubDoc.chapters.count)")
            print("   • toc.count = \(epubDoc.tableOfContents.count)")
            
            if epubDoc.chapters.isEmpty {
                print("⚠️ [ReadingViewModel] epubDoc.chapters is EMPTY")
            } else {
                print("📖 [ReadingViewModel] first chapter title: \(epubDoc.chapters.first?.title ?? "nil")")
            }
            
            epubDocument = epubDoc
            
            // Проверяем, что есть главы для чтения
            guard !epubDoc.chapters.isEmpty else {
                await MainActor.run {
                    self.pages = ["EPUB файл не содержит читаемых глав"]
                    self.fullContent = ""
                }
                print("⚠️ [ReadingViewModel] EPUB has no readable chapters, stopping")
                return
            }
            
            // Преобразуем главы в страницы
            var allPages: [EPUBPage] = []
            var globalPageNumber = 0
            
            for chapter in epubDoc.chapters {
                let chapterContent = chapter.textContent
                print("📖 [ReadingViewModel] Обрабатываем главу: '\(chapter.title)'")
                print("   • chapter.id: \(chapter.id)")
                print("   • chapter.order: \(chapter.order)")
                print("   • textContent.count: \(chapterContent.count)")
                
                // Если глава пустая, пропускаем
                if chapterContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("⚠️ [ReadingViewModel] Глава '\(chapter.title)' пустая, пропускаем")
                    continue
                }
                
                let chunkSize = 1000
                var chunks: [String] = []
                var currentChunk = ""
                
                for line in chapterContent.components(separatedBy: CharacterSet.newlines) {
                    if currentChunk.count + line.count > chunkSize && !currentChunk.isEmpty {
                        chunks.append(currentChunk)
                        currentChunk = line
                    } else {
                        currentChunk += currentChunk.isEmpty ? line : "\n" + line
                    }
                }
                
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                
                print("📄 [ReadingViewModel] Глава '\(chapter.title)' разбита на \(chunks.count) страниц (чанков)")
                
                for (pageIndex, chunk) in chunks.enumerated() {
                    let page = EPUBPage(
                        id: "\(chapter.id)_page_\(pageIndex)",
                        chapterId: chapter.id,
                        chapterOrder: chapter.order,
                        pageNumber: pageIndex,
                        content: chunk,
                        globalPageNumber: globalPageNumber
                    )
                    allPages.append(page)
                    globalPageNumber += 1
                }
            }
            
            print("📊 [ReadingViewModel] Всего сформировано EPUB страниц: \(allPages.count)")
            
            await MainActor.run {
                self.epubPages = allPages
                self.pages = allPages.map { $0.content }
                self.fullContent = epubDoc.chapters.map { $0.textContent }.joined(separator: "\n\n")
                self.currentPageNumber = 0
                
                if allPages.isEmpty {
                    print("⚠️ [ReadingViewModel] allPages is EMPTY — нет текстового контента для отображения")
                    self.pages = ["EPUB файл обработан, но не содержит текстового контента для отображения."]
                    self.fullContent = ""
                } else {
                    print("🎉 [ReadingViewModel] EPUB загружен успешно, pages.count = \(self.pages.count)")
                    print("   • currentPageNumber = \(self.currentPageNumber)")
                    print("   • первая страница (обрезано): \(self.pages.first?.prefix(120) ?? "nil")")
                }
            }
            
        } catch {
            print("❌ [ReadingViewModel] Ошибка загрузки EPUB: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Ошибка загрузки EPUB файла: \(error.localizedDescription)"
                self.pages = ["Ошибка загрузки EPUB файла: \(error.localizedDescription)"]
                self.fullContent = ""
            }
        }
    }
    
    private func loadPDFContent() async {
        do {
            let url = URL(fileURLWithPath: book.filePath)
            
            // Создаем PDF документ из файла
            guard let pdfDocument = PDFDocument(url: url) else {
                await MainActor.run {
                    self.errorMessage = "Ошибка открытия PDF файла"
                    self.pages = ["Не удалось открыть PDF файл"]
                    self.fullContent = ""
                }
                return
            }
            
            await MainActor.run {
                // Сохраняем PDF документ для отображения с изображениями
                self.pdfDocument = pdfDocument
                
                // Создаем страницы на основе реальных страниц PDF
                var pdfPages: [String] = []
                var fullText = ""
                
                // Извлекаем текст для поиска и других функций
                for pageIndex in 0..<pdfDocument.pageCount {
                    if let page = pdfDocument.page(at: pageIndex) {
                        let pageText = page.string ?? ""
                        fullText += pageText + "\n\n"
                        
                        // Создаем страницу (даже если нет текста, страница будет отображаться как изображение)
                        if !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            pdfPages.append("PDF_PAGE_\(pageIndex)")
                        } else {
                            // Страница с изображениями без текста
                            pdfPages.append("PDF_PAGE_\(pageIndex)")
                        }
                    }
                }
                
                // Если нет страниц, создаем хотя бы одну
                if pdfPages.isEmpty {
                    pdfPages = ["PDF_PAGE_0"]
                }
                
                self.pages = pdfPages
                self.fullContent = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                self.currentPageNumber = 0
                
                print("✅ [ReadingViewModel] PDF загружен: \(pdfDocument.pageCount) страниц")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка чтения PDF: \(error.localizedDescription)"
                self.pages = ["Ошибка загрузки PDF файла"]
                self.fullContent = ""
            }
        }
    }
    
    /// Разбивает большую страницу PDF на удобные для чтения части
    private func splitPageIntoChunks(_ text: String, maxChunkSize: Int) -> [String] {
        // Если текст короткий, возвращаем как есть
        if text.count <= maxChunkSize {
            return [text]
        }
        
        var chunks: [String] = []
        let paragraphs = text.components(separatedBy: "\n\n")
        var currentChunk = ""
        
        for paragraph in paragraphs {
            let proposedChunk = currentChunk.isEmpty ? paragraph : currentChunk + "\n\n" + paragraph
            
            if proposedChunk.count <= maxChunkSize {
                currentChunk = proposedChunk
            } else {
                // Если текущий чанк не пуст, сохраняем его
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                
                // Если параграф слишком длинный, разбиваем его по предложениям
                if paragraph.count > maxChunkSize {
                    let sentences = paragraph.components(separatedBy: ". ")
                    var sentenceChunk = ""
                    
                    for sentence in sentences {
                        let proposedSentenceChunk = sentenceChunk.isEmpty ? sentence : sentenceChunk + ". " + sentence
                        
                        if proposedSentenceChunk.count <= maxChunkSize {
                            sentenceChunk = proposedSentenceChunk
                        } else {
                            if !sentenceChunk.isEmpty {
                                chunks.append(sentenceChunk)
                            }
                            sentenceChunk = sentence
                        }
                    }
                    
                    currentChunk = sentenceChunk
                } else {
                    currentChunk = paragraph
                }
            }
        }
        
        // Добавляем последний чанк, если он не пустой
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks.isEmpty ? [text] : chunks
    }
    
    private func loadDOCXContent() async {
        // TODO: Реальный парсер DOCX 
        // DOCX это ZIP архив с XML файлами
        await MainActor.run {
            self.pages = ["DOCX формат пока не поддерживается.\n\nВ будущих версиях будет добавлена поддержка DOCX с извлечением текста из XML структуры."]
            self.fullContent = self.pages[0]
        }
    }
    
    // MARK: - Navigation
    
    func nextPage() {
        print("➡️ [ReadingViewModel] nextPage() tapped. currentPageNumber = \(currentPageNumber)")
        
        // Для PDF используем реальное количество страниц
        let maxPage = book.format == .pdf && pdfDocument != nil 
            ? (pdfDocument?.pageCount ?? 0) - 1 
            : pages.count - 1
        
        if currentPageNumber < maxPage {
            isChangingPage = true  // Начинаем смену страницы
            currentPageNumber += 1
            print("   • new currentPageNumber = \(currentPageNumber)")
            if book.format == .epub {
                updateCurrentChapterInfo()
            }
        } else {
            print("⚠️ [ReadingViewModel] nextPage(): already at last page")
        }
    }
    
    func previousPage() {
        print("⬅️ [ReadingViewModel] previousPage() tapped. currentPageNumber = \(currentPageNumber)")
        if currentPageNumber > 0 {
            isChangingPage = true  // Начинаем смену страницы
            currentPageNumber -= 1
            id = .init()
            print("   • new currentPageNumber = \(currentPageNumber)")
            if book.format == .epub {
                updateCurrentChapterInfo()
            }
        } else {
            print("⚠️ [ReadingViewModel] previousPage(): already at first page")
        }
    }
    
    func goToPage(_ pageNumber: Int) {
        print("🔢 [ReadingViewModel] goToPage(\(pageNumber)) called. pages.count = \(pages.count)")
        
        // Для PDF используем реальное количество страниц
        let maxPage = book.format == .pdf && pdfDocument != nil 
            ? (pdfDocument?.pageCount ?? 0) 
            : pages.count
        
        if pageNumber >= 0 && pageNumber < maxPage {
            isChangingPage = true  // Начинаем смену страницы
            currentPageNumber = pageNumber
            print("   • currentPageNumber set to \(currentPageNumber)")
            if book.format == .epub {
                updateCurrentChapterInfo()
            }
        } else {
            print("⚠️ [ReadingViewModel] goToPage: pageNumber out of range")
        }
    }
    
    // MARK: - Reading Progress
    
    var readingProgress: Double {
        // Для PDF используем реальное количество страниц
        let total = book.format == .pdf && pdfDocument != nil 
            ? (pdfDocument?.pageCount ?? 1) 
            : max(pages.count, 1)
        
        guard total > 1 else { return 0 }
        return Double(currentPageNumber) / Double(total - 1)
    }
    
    var progressText: String {
        let total = book.format == .pdf && pdfDocument != nil 
            ? (pdfDocument?.pageCount ?? pages.count) 
            : pages.count
        return "\(currentPageNumber + 1) / \(total)"
    }
    
    // MARK: - Current Page Content
    
    private func updateCurrentPageContent() {
        print("🔄 [ReadingViewModel] updateCurrentPageContent() called. currentPageNumber: \(currentPageNumber)")
        
        isChangingPage = true  // Начинаем смену страницы
        
        // Закрываем холст рисования при смене страницы
        if showDrawingCanvas {
            showDrawingCanvas = false
        }
        
        // Загружаем рисунок для новой страницы
        loadCurrentPageDrawing()
        
        // Для PDF не обновляем текстовый контент, так как страницы отображаются как изображения
        if book.format == .pdf {
            isChangingPage = false
            return
        }
        
        guard currentPageNumber < pages.count && currentPageNumber >= 0 else { 
            currentPageContent = ""
            isChangingPage = false  // Завершаем смену страницы даже при ошибке
            return 
        }
        
        // Имитируем небольшую задержку для правильного отображения ProgressView
        Task { @MainActor in
            // Небольшая задержка для обеспечения видимости ProgressView
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            
            self.currentPageContent = self.pages[self.currentPageNumber]
            self.isChangingPage = false  // Завершаем смену страницы
            
            // Принудительно уведомляем об изменении для правильного layout текста
            self.objectWillChange.send()
            
            print("✅ [ReadingViewModel] updateCurrentPageContent() completed. page \(self.currentPageNumber) content length: \(self.currentPageContent.count)")
        }
    }
    
    var totalPages: Int {
        // Для PDF используем реальное количество страниц
        if book.format == .pdf, let pdfDoc = pdfDocument {
            return pdfDoc.pageCount
        }
        return pages.count
    }
    
    // MARK: - Search Functionality
    
    /// Поиск по содержимому книги
    func searchInBook(_ query: String) -> [(pageNumber: Int, context: String)] {
        guard !query.isEmpty else { return [] }
        
        var results: [(pageNumber: Int, context: String)] = []
        
        for (pageIndex, pageContent) in pages.enumerated() {
            let lowercasedContent = pageContent.lowercased()
            let lowercasedQuery = query.lowercased()
            
            if lowercasedContent.contains(lowercasedQuery) {
                // Найдем контекст вокруг найденного текста
                let lines = pageContent.components(separatedBy: .newlines)
                for line in lines {
                    if line.lowercased().contains(lowercasedQuery) {
                        let context = String(line.prefix(100)) + (line.count > 100 ? "..." : "")
                        results.append((pageNumber: pageIndex, context: context))
                        break // Один результат на страницу
                    }
                }
            }
        }
        
        return results
    }
    
    // MARK: - EPUB Chapter Navigation
    
    private func updateCurrentChapterInfo() {
        print("📌 [ReadingViewModel] updateCurrentChapterInfo() for page \(currentPageNumber)")
        
        guard let epubDoc = epubDocument,
              currentPageNumber < epubPages.count else {
            print("⚠️ [ReadingViewModel] updateCurrentChapterInfo: epubDocument = nil или индекс вне диапазона")
            currentChapterInfo = nil
            return
        }
        
        let currentPage = epubPages[currentPageNumber]
        print("   • currentPage.chapterId = \(currentPage.chapterId)")
        
        if let chapter = epubDoc.chapters.first(where: { $0.id == currentPage.chapterId }) {
            currentChapterInfo = (title: chapter.title, chapterNumber: chapter.order + 1)
            print("   ✅ currentChapter = '\(chapter.title)' (№\(chapter.order + 1))")
        } else {
            print("   ⚠️ Глава для currentPage.chapterId не найдена")
            currentChapterInfo = nil
        }
    }
    
    /// Перейти к определенной главе (EPUB)
    func goToChapter(_ chapterIndex: Int) {
        print("📂 [ReadingViewModel] goToChapter(\(chapterIndex))")
        
        guard let epubDoc = epubDocument else {
            print("⚠️ [ReadingViewModel] goToChapter: epubDocument is nil")
            return
        }
        
        guard chapterIndex < epubDoc.chapters.count else {
            print("⚠️ [ReadingViewModel] goToChapter: chapterIndex out of range. chapters.count = \(epubDoc.chapters.count)")
            return
        }
        
        let chapter = epubDoc.chapters[chapterIndex]
        print("   • target chapter id: \(chapter.id), title: \(chapter.title)")
        
        guard let chapterPage = epubPages.first(where: { $0.chapterId == chapter.id }) else {
            print("⚠️ [ReadingViewModel] goToChapter: no page found for chapter.id = \(chapter.id)")
            return
        }
        
        if let pageIndex = epubPages.firstIndex(of: chapterPage) {
            print("   ✅ found first page for chapter at index \(pageIndex)")
            goToPage(pageIndex)
        } else {
            print("⚠️ [ReadingViewModel] goToChapter: page index not found in epubPages")
        }
    }
    
    /// Получить оглавление EPUB
    func getTableOfContents() -> [EPUBTOCItem] {
        let count = epubDocument?.tableOfContents.count ?? 0
        print("📚 [ReadingViewModel] getTableOfContents() -> \(count) items")
        return epubDocument?.tableOfContents ?? []
    }
    
    /// Перейти к главе по индексу оглавления
    func goToTOCItem(_ tocIndex: Int) {
        print("🧭 [ReadingViewModel] goToTOCItem(\(tocIndex))")
        
        guard let epubDoc = epubDocument else {
            print("⚠️ [ReadingViewModel] goToTOCItem: epubDocument is nil")
            return
        }
        
        guard tocIndex < epubDoc.tableOfContents.count else {
            print("⚠️ [ReadingViewModel] goToTOCItem: tocIndex out of range. toc.count = \(epubDoc.tableOfContents.count)")
            return
        }
        
        let tocItem = epubDoc.tableOfContents[tocIndex]
        print("   • TOC item src: \(tocItem.src), title: \(tocItem.title)")
        
        // Найдем первую страницу соответствующей главы
        if let chapterPage = epubPages.first(where: { page in
            epubDoc.chapters.contains { chapter in
                chapter.id == page.chapterId && chapter.filePath.contains(tocItem.src)
            }
        }) {
            if let pageIndex = epubPages.firstIndex(of: chapterPage) {
                print("   ✅ found page for TOC item at index \(pageIndex)")
                goToPage(pageIndex)
            } else {
                print("⚠️ [ReadingViewModel] goToTOCItem: page index not found for TOC item")
            }
        } else {
            print("⚠️ [ReadingViewModel] goToTOCItem: no page matched TOC src")
        }
    }
    
    // MARK: - AI Features (заглушки для будущей реализации)
    
    func analyzeFormula(_ formula: Formula) {
        // TODO: Интеграция с AI сервисом для объяснения формул
        isAnalyzingFormula = true
        selectedFormula = formula
        
        // Симуляция работы AI
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
            await MainActor.run {
                self.isAnalyzingFormula = false
                // TODO: Создать правильный объект Explanation когда AI будет реализован
                self.formulaExplanation = nil
            }
        }
    }
    
    func analyzeText(_ text: String) {
        // TODO: Интеграция с AI сервисом для объяснения текста
        isAnalyzingText = true
        selectedText = text
        
        // Симуляция работы AI
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
            await MainActor.run {
                self.isAnalyzingText = false
                // TODO: Создать правильный объект Explanation когда AI будет реализован
                self.textExplanation = nil
            }
        }
    }
    
    func addNote(_ content: String, at pageNumber: Int) {
        let note = Note(
            id: UUID(),
            bookId: book.id,
            type: .custom,
            selectedText: "",
            userText: content,
            position: ReadingPosition(pageNumber: pageNumber, progressPercentage: readingProgress),
            pageNumber: pageNumber
        )
        notes.append(note)
    }
    
    func addNote(_ note: Note) {
        notes.append(note)
        // Сохраняем также в глобальный менеджер заметок
        NotesManager.shared.addNote(note, for: book.id)
    }
    
    // MARK: - UI Actions
    
    func selectText(_ text: String) {
        selectedText = text
        showExplanation = true
    }
    
    func loadCurrentPage() async {
        // Обновляем контент текущей страницы если данные уже загружены
        await MainActor.run {
            self.updateCurrentPageContent()
            self.objectWillChange.send()
        }
    }
    
    /// Публичный метод для принудительного обновления контента текущей страницы
    func refreshCurrentPageContent() {
        isChangingPage = true
        updateCurrentPageContent()
        objectWillChange.send()
    }
    
    func clearSelection() {
        selectedText = ""
        showExplanation = false
    }
    
    func askAIAboutSelectedText() {
        // TODO: В будущем здесь будет интеграция с AI API
        // Пока просто логгируем выбранный текст
        print("📖 Пользователь хочет спросить ИИ о тексте: '\(selectedText)'")
        
        // Можно добавить аналитику или подготовку для будущего API
        // например, сохранить запрос в базу данных для последующей обработки
        
        // Закрываем панель выделения
        clearSelection()
    }
    
    // MARK: - Drawing Management
    
    /// Показать холст для рисования
    func startDrawing() {
        showDrawingCanvas = true
        loadCurrentPageDrawing()
    }
    
    /// Скрыть холст рисования
    func stopDrawing() {
        showDrawingCanvas = false
    }
    
    /// Загрузить рисунок для текущей страницы
    private func loadCurrentPageDrawing() {
        if let existingDrawing = pageDrawings[currentPageNumber] {
            currentPageDrawing = existingDrawing
        } else {
            // Создаем новый рисунок для страницы
            currentPageDrawing = PageDrawing(bookId: book.id, pageNumber: currentPageNumber)
        }
    }
    
    /// Сохранить рисунок для текущей страницы
    func saveDrawing(strokes: [DrawingStroke]) {
        guard var drawing = currentPageDrawing else { return }
        
        // Обновляем штрихи в рисунке
        drawing.strokes = strokes
        
        // Сохраняем в словарь
        if strokes.isEmpty {
            pageDrawings.removeValue(forKey: currentPageNumber)
        } else {
            pageDrawings[currentPageNumber] = drawing
        }
        
        // Обновляем текущий рисунок
        currentPageDrawing = strokes.isEmpty ? nil : drawing
        
        // Сохраняем в BookStorage
        BookStorageService.shared.savePageDrawings(pageDrawings, for: book.id)
        
        // Скрываем холст
        stopDrawing()
        
        print("💾 [ReadingViewModel] Сохранен рисунок для страницы \(currentPageNumber) с \(strokes.count) штрихами")
    }
    
    /// Очистить рисунок для текущей страницы
    func clearCurrentPageDrawing() {
        pageDrawings.removeValue(forKey: currentPageNumber)
        currentPageDrawing = nil
        
        // Сохраняем изменения
        BookStorageService.shared.savePageDrawings(pageDrawings, for: book.id)
        
        // Скрываем холст
        stopDrawing()
        
        print("🗑️ [ReadingViewModel] Очищен рисунок для страницы \(currentPageNumber)")
    }
    
    /// Загрузить все рисунки для книги
    func loadPageDrawings() {
        pageDrawings = BookStorageService.shared.loadPageDrawings(for: book.id)
        loadCurrentPageDrawing()
        
        print("📝 [ReadingViewModel] Загружено \(pageDrawings.count) рисунков для книги")
    }
    
    /// Получить рисунок для конкретной страницы
    func getDrawing(for pageNumber: Int) -> PageDrawing? {
        return pageDrawings[pageNumber]
    }
    
    // MARK: - Screenshot Functionality
    
    /// Создать скриншот содержимого и подготовить для отправки ИИ
    func captureScreenshot(screenshot: UIImage) {
        Task {
            await processScreenshot(screenshot)
        }
    }
    
    @MainActor
    private func processScreenshot(_ screenshot: UIImage) async {
        print("📸 [ReadingViewModel] Обработка скриншота...")
        print("🖼️ [ReadingViewModel] Размер: \(screenshot.size)")
        print("📄 [ReadingViewModel] Текущая страница: \(currentPageNumber + 1)")
        print("📖 [ReadingViewModel] Книга: \(book.title)")
        print("📱 [ReadingViewModel] Формат: \(book.format)")
        
        do {
            // Создаем конспект с помощью GeminiManager
            print("🤖 [ReadingViewModel] Создание конспекта через GeminiManager...")
            let summary = try await GeminiManager.shared.generateSummary(from: screenshot)
            
            // Создаем заметку с конспектом
            let note = Note(
                bookId: book.id,
                type: .aiNote,
                selectedText: "Конспект страницы \(currentPageNumber + 1)",
                aiExplanation: summary,
                imageData: screenshot.jpegData(compressionQuality: 0.8),
                position: ReadingPosition(pageNumber: currentPageNumber + 1, progressPercentage: readingProgress),
                pageNumber: currentPageNumber + 1,
                tags: ["конспект", "ai", "скриншот"]
            )
            
            // Добавляем заметку
            addNote(note)
            
            // Создаем AI результат для отображения
            let aiResult = AIResult(
                actionType: .screenshot,
                title: "Конспект страницы \(currentPageNumber + 1)",
                content: summary,
                metadata: [
                    "pageNumber": "\(currentPageNumber + 1)",
                    "bookTitle": book.title,
                    "noteId": note.id.uuidString
                ]
            )
            
            // Устанавливаем результат для отображения в UI
            latestAIResult = aiResult
            
            print("✅ [ReadingViewModel] Конспект создан и сохранен как заметка")
            
        } catch {
            print("❌ [ReadingViewModel] Ошибка создания конспекта: \(error)")
            
            // Создаем AI результат с ошибкой для отображения
            let errorResult = AIResult(
                actionType: .screenshot,
                title: "Ошибка создания конспекта",
                content: "Произошла ошибка при создании конспекта: \(error.localizedDescription)\n\nПопробуйте еще раз или обратитесь в поддержку.",
                metadata: [
                    "pageNumber": "\(currentPageNumber + 1)",
                    "bookTitle": book.title,
                    "error": error.localizedDescription
                ]
            )
            
            latestAIResult = errorResult
            
            // Также вызываем legacy метод для логирования
            await sendScreenshotToAI_Legacy(screenshot)
        }
    }
    
    /// Legacy метод отправки скриншота (для резерва)
    private func sendScreenshotToAI_Legacy(_ screenshot: UIImage) async {
        let aiRequest = ScreenshotAIRequest(
            image: screenshot,
            pageNumber: currentPageNumber + 1,
            bookTitle: book.title,
            bookFormat: book.format.rawValue,
            textContent: currentPageContent.isEmpty ? "Содержимое недоступно" : String(currentPageContent.prefix(500)) + "..."
        )
        
        await sendScreenshotToAI(aiRequest)
    }
    
    /// Мок отправки скриншота ИИ
    private func sendScreenshotToAI(_ request: ScreenshotAIRequest) async {
        print("\n🤖 [AI REQUEST] Отправка скриншота ИИ:")
        print("📚 Книга: \(request.bookTitle)")
        print("📄 Страница: \(request.pageNumber)")
        print("📱 Формат: \(request.bookFormat)")
        print("🖼️ Размер изображения: \(request.image.size)")
        print("📝 Фрагмент текста: \(request.textContent)")
        print("\n💭 Примерный промпт для ИИ:")
        print("\"Проанализируй содержимое этой страницы из книги '\(request.bookTitle)' (страница \(request.pageNumber), формат \(request.bookFormat)). На изображении показан контент: '\(request.textContent)'. Пожалуйста, объясни основные концепции, выдели ключевые моменты и предложи вопросы для понимания материала.\"")
        print("\n✅ [AI REQUEST] Скриншот готов для отправки ИИ")
        print("💾 [GALLERY] Изображение также сохранено в галерею устройства\n")
        
        // TODO: Здесь будет реальная отправка ИИ
        // let response = try await aiService.analyzeScreenshot(request)
    }
}

// MARK: - Screenshot AI Request Model

/// Модель запроса для отправки скриншота ИИ
struct ScreenshotAIRequest {
    let image: UIImage
    let pageNumber: Int
    let bookTitle: String
    let bookFormat: String
    let textContent: String
}

// MARK: - Mock Services for Development

private struct DefaultAIService: AIServiceProtocol {
    func explainConcept(_ text: String) async throws -> Explanation {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI сервис будет реализован в следующих версиях"])
    }
    
    func generateSummary(_ content: String) async throws -> String {
        // Для текстового контента создаем простое изображение с текстом
        // или используем существующий текстовый промпт
        
        // Временно возвращаем заглушку, так как GeminiManager работает с изображениями
        return "Конспект будет доступен при создании скриншота страницы. Используйте кнопку 'Конспект' в меню действий."
    }
    
    func explainWord(_ word: String, context: String?, language: String) async throws -> Explanation {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI сервис будет реализован в следующих версиях"])
    }
    
    func simplifyText(_ text: String, difficultyLevel: Int, language: String) async throws -> Explanation {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI сервис будет реализован в следующих версиях"])
    }
    
    func explainFormula(_ formula: Formula, includeExamples: Bool, language: String) async throws -> Explanation {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI сервис будет реализован в следующих версиях"])
    }
    
    func summarizeText(_ text: String, maxLength: Int?, language: String) async throws -> Explanation {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI сервис будет реализован в следующих версиях"])
    }
    
    func getRelatedConcepts(for term: String, subject: String?, language: String) async throws -> [String] {
        return []
    }
}

private struct DefaultMathEngine: MathEngineProtocol {
    func solve(expression: String, method: SolutionMethod?) async throws -> MathSolutionResult {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "Математический движок будет реализован в следующих версиях"])
    }
    
    func evaluate(expression: String, variables: [String : Double]) throws -> Double {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "Математический движок будет реализован в следующих версиях"])
    }
    
    func generatePlotPoints(for expression: String, variable: String, range: ClosedRange<Double>, pointsCount: Int) throws -> [CGPoint] {
        return []
    }
    
    func differentiate(expression: String, withRespectTo variable: String) throws -> String {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "Математический движок будет реализован в следующих версиях"])
    }
    
    func integrate(expression: String, withRespectTo variable: String, definite: Bool, bounds: ClosedRange<Double>?) throws -> String {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "Математический движок будет реализован в следующих версиях"])
    }
    
    func simplify(expression: String) throws -> String {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "Математический движок будет реализован в следующих версиях"])
    }
    
    func factor(expression: String) throws -> String {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "Математический движок будет реализован в следующих версиях"])
    }
    
    func findRoots(of expression: String, for variable: String, method: RootFindingMethod?) throws -> [Double] {
        return []
    }
}

private struct DefaultFormulaRecognizer: FormulaRecognizerProtocol {
    func recognizeFormula(from image: UIImage, options: FormulaRecognitionOptions) async throws -> FormulaRecognitionResult {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "Распознавание формул будет реализовано в следующих версиях"])
    }
    
    func extractFormulas(from text: String, options: FormulaRecognitionOptions) async throws -> [FormulaRecognitionResult] {
        return []
    }
    
    func recognizeHandwrittenFormula(from strokes: [FormulaStroke], options: FormulaRecognitionOptions) async throws -> FormulaRecognitionResult {
        throw NSError(domain: "NotImplemented", code: 1, userInfo: [NSLocalizedDescriptionKey: "Распознавание рукописных формул будет реализовано в следующих версиях"])
    }
    
    func detectFormulaPresence(in image: UIImage) async throws -> Double {
        return 0.0
    }
    
    func locateFormulas(in image: UIImage) async throws -> [CGRect] {
        return []
    }
    
    // Оставляем методы для обратной совместимости
    func recognizeFormulas(in text: String) async throws -> [Formula] {
        return []
    }
    
    func validateFormula(_ formula: String) -> Bool {
        let mathCharacters = CharacterSet(charactersIn: "+-*/=()[]{}^∑∫√πα")
        return formula.rangeOfCharacter(from: mathCharacters) != nil
    }
}
