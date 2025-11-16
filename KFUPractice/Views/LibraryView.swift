//
//  LibraryView.swift
//  KFUPractice
//
//  AI Reader App
//

import SwiftUI

/// Временная библиотека для демонстрации архитектуры
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showingFileImporter = false
    
    var body: some View {
        NavigationView {
            content
                .navigationTitle("Библиотека")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $viewModel.searchText, prompt: "Поиск книг...")
                .onChange(of: viewModel.searchText) { newValue in
                    viewModel.searchBooks(query: newValue)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        // Кнопка создания демонстрационного PDF
                        Button {
                            Task {
                                await viewModel.createSamplePDFBook()
                            }
                        } label: {
                            Image(systemName: "doc.badge.plus")
                                .font(.title2)
                        }
                        
                        // Кнопка импорта файлов
                        Button {
                            showingFileImporter = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2)
                        }
                    }
                }
                .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                    Button("OK") {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    Text(viewModel.errorMessage ?? "")
                }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.pdf, .epub, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await viewModel.importBook(from: url)
                    }
                }
            case .failure(let error):
                print("Ошибка импорта: \(error)")
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.books.isEmpty && !viewModel.isLoading {
            emptyStateView
        } else {
            booksGridView
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Ваша библиотека пуста")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Добавьте первую книгу для начала чтения")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button {
                    showingFileImporter = true
                } label: {
                    Label("Добавить книгу", systemImage: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                
                Button {
                    createSampleTextFile()
                } label: {
                    Label("Создать образец TXT", systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Button {
                    createSampleEPUBFile()
                } label: {
                    Label("Создать образец EPUB", systemImage: "book.closed")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    private var booksGridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(viewModel.filteredBooks) { book in
                    NavigationLink(destination: ReadingView(book: book)) {
                        BookCardView(book: book)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button {
                            Task {
                                viewModel.deleteBook(book)
                            }
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Загрузка книг...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
            }
        }
    }
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }
    
    /// Создать образец текстового файла для тестирования
    private func createSampleTextFile() {
        let sampleContent = """
Квантовая физика - Введение

Глава 1: Основы квантовой механики

Квантовая механика представляет собой один из наиболее фундаментальных и удивительных разделов современной физики. Она описывает поведение материи и энергии на атомном и субатомном уровне, где законы классической физики перестают действовать.

История развития

Квантовая теория начала формироваться в начале XX века благодаря работам таких выдающихся ученых, как Макс Планк, Альберт Эйнштейн, Нильс Бор, Вернер Гейзенберг и Эрвин Шрёдингер. Каждый из них внес неоценимый вклад в понимание микромира.

Планк впервые предположил, что энергия излучается и поглощается дискретными порциями - квантами. Это революционное предположение положило начало квантовой эре в физике.

Эйнштейн, объясняя фотоэффект, развил идею квантов света - фотонов. За эту работу он получил Нобелевскую премию по физике в 1921 году.

Основные принципы

1. Принцип неопределенности Гейзенберга
Один из фундаментальных принципов квантовой механики гласит: невозможно одновременно точно измерить импульс и координату частицы. Чем точнее мы измеряем одну величину, тем менее точно можем определить другую.

Математически это выражается неравенством:
Δx × Δp ≥ ħ/2

где Δx - неопределенность координаты, Δp - неопределенность импульса, ħ - приведенная постоянная Планка.

2. Волновая функция
Состояние квантовой системы полностью описывается волновой функцией ψ(x,t). Квадрат модуля волновой функции |ψ(x,t)|² дает плотность вероятности обнаружить частицу в точке x в момент времени t.

3. Суперпозиция состояний
Квантовая система может находиться в суперпозиции нескольких состояний одновременно. Это означает, что до измерения частица может быть в нескольких состояниях сразу.

Знаменитый мысленный эксперимент Шрёдингера с котом иллюстрирует этот принцип: кот может быть одновременно и живым, и мертвым до тех пор, пока мы не откроем коробку.

Глава 2: Математический аппарат

Квантовая механика использует сложный математический аппарат, включающий:

- Линейную алгебру и теорию операторов
- Дифференциальные уравнения в частных производных
- Теорию вероятностей
- Комплексные числа

Уравнение Шрёдингера является основным уравнением квантовой механики:

iħ ∂ψ/∂t = Ĥψ

где Ĥ - гамильтониан системы, описывающий полную энергию.

Глава 3: Практические применения

Квантовая физика не является чисто теоретической дисциплиной. Она имеет множество практических применений:

1. Лазеры - основаны на принципе вынужденного излучения
2. Транзисторы - работают благодаря квантовым свойствам полупроводников
3. МРТ - использует ядерный магнитный резонанс
4. Квантовые компьютеры - обещают революцию в вычислительной технике

Квантовая криптография уже сегодня обеспечивает абсолютно защищенную передачу информации.

Заключение

Квантовая механика коренным образом изменила наше понимание природы реальности. Она показала, что мир на микроуровне принципиально отличается от привычного нам макромира.

Изучение квантовой физики продолжает приносить удивительные открытия и находить новые практические применения. Это одна из самых активно развивающихся областей современной науки.
"""
        
        // Создаем временный файл
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tempURL = documentsPath.appendingPathComponent("Квантовая физика - Образец.txt")
        
        do {
            try sampleContent.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Импортируем созданный файл
            Task {
                await viewModel.importBook(from: tempURL)
            }
        } catch {
            viewModel.errorMessage = "Ошибка создания файла: \(error.localizedDescription)"
        }
    }
    
    /// Создать образец EPUB файла для тестирования
    private func createSampleEPUBFile() {
        print("📚 Создаем образец EPUB файла...")
        
        // Создаем минимальную EPUB структуру
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tempEPUBDir = documentsPath.appendingPathComponent("temp_epub")
        let epubURL = documentsPath.appendingPathComponent("Программирование на Swift - Образец.epub")
        
        do {
            print("📁 Создаем временную директорию: \(tempEPUBDir.path)")
            
            // Создаем временную директорию
            try FileManager.default.createDirectory(at: tempEPUBDir, withIntermediateDirectories: true)
            
            print("🏗️ Создаем структуру EPUB...")
            
            // Создаем структуру EPUB
            try createEPUBStructure(in: tempEPUBDir)
            
            print("🗜️ Архивируем EPUB в ZIP...")
            
            // Архивируем в ZIP (EPUB)
            try zipEPUBDirectory(tempEPUBDir, to: epubURL)
            
            print("🗑️ Очищаем временную директорию...")
            
            // Очищаем временную директорию
            try FileManager.default.removeItem(at: tempEPUBDir)
            
            print("✅ EPUB файл создан: \(epubURL.lastPathComponent)")
            
            // Импортируем созданный файл
            Task {
                await viewModel.importBook(from: epubURL)
            }
            
        } catch {
            print("❌ Ошибка создания EPUB: \(error)")
            viewModel.errorMessage = "Ошибка создания EPUB: \(error.localizedDescription)"
        }
    }
    
    /// Создает структуру EPUB файла
    private func createEPUBStructure(in directory: URL) throws {
        let metaInfDir = directory.appendingPathComponent("META-INF")
        let oebpsDir = directory.appendingPathComponent("OEBPS")
        
        try FileManager.default.createDirectory(at: metaInfDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: oebpsDir, withIntermediateDirectories: true)
        
        // Создаем mimetype
        let mimetypeContent = "application/epub+zip"
        try mimetypeContent.write(to: directory.appendingPathComponent("mimetype"), atomically: true, encoding: .utf8)
        
        // Создаем container.xml
        let containerXML = """
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"""
        try containerXML.write(to: metaInfDir.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)
        
        // Создаем content.opf
        let contentOPF = """
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="BookId">sample-swift-book</dc:identifier>
    <dc:title>Программирование на Swift - Образец</dc:title>
    <dc:creator>AI Reader App</dc:creator>
    <dc:language>ru</dc:language>
    <dc:subject>Программирование</dc:subject>
    <dc:description>Образец EPUB книги для демонстрации возможностей AI Reader</dc:description>
  </metadata>
  <manifest>
    <item id="toc" properties="nav" href="nav.html" media-type="application/xhtml+xml"/>
    <item id="chapter1" href="chapter1.html" media-type="application/xhtml+xml"/>
    <item id="chapter2" href="chapter2.html" media-type="application/xhtml+xml"/>
    <item id="chapter3" href="chapter3.html" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="chapter1"/>
    <itemref idref="chapter2"/>
    <itemref idref="chapter3"/>
  </spine>
</package>
"""
        try contentOPF.write(to: oebpsDir.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)
        
        // Создаем nav.html
        let navHTML = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head>
    <title>Оглавление</title>
</head>
<body>
    <nav epub:type="toc">
        <h1>Оглавление</h1>
        <ol>
            <li><a href="chapter1.html">Глава 1: Введение в Swift</a></li>
            <li><a href="chapter2.html">Глава 2: Основы языка</a></li>
            <li><a href="chapter3.html">Глава 3: Функции и замыкания</a></li>
        </ol>
    </nav>
</body>
</html>
"""
        try navHTML.write(to: oebpsDir.appendingPathComponent("nav.html"), atomically: true, encoding: .utf8)
        
        // Создаем главы
        try createEPUBChapter(1, title: "Введение в Swift", in: oebpsDir)
        try createEPUBChapter(2, title: "Основы языка", in: oebpsDir)
        try createEPUBChapter(3, title: "Функции и замыкания", in: oebpsDir)
    }
    
    /// Создает главу EPUB
    private func createEPUBChapter(_ number: Int, title: String, in directory: URL) throws {
        let chapterContent = generateChapterContent(number: number, title: title)
        let fileName = "chapter\(number).html"
        try chapterContent.write(to: directory.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
    }
    
    /// Генерирует содержимое главы
    private func generateChapterContent(number: Int, title: String) -> String {
        switch number {
        case 1:
            return """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>Введение в Swift</title>
</head>
<body>
    <h1>Глава 1: Введение в Swift</h1>
    
    <p>Swift — это современный язык программирования, разработанный компанией Apple для создания приложений под iOS, macOS, watchOS и tvOS. Он сочетает в себе производительность компилируемых языков с простотой и выразительностью современных скриптовых языков.</p>
    
    <h2>История создания</h2>
    
    <p>Разработка Swift началась в 2010 году под руководством Криса Латтнера. Язык был официально представлен на конференции Apple WWDC в 2014 году. Основная цель создания Swift — заменить Objective-C как основной язык разработки для платформ Apple.</p>
    
    <h2>Ключевые особенности</h2>
    
    <p>Swift обладает рядом важных особенностей:</p>
    
    <ul>
        <li><strong>Безопасность типов</strong> — Swift помогает предотвращать ошибки типов во время компиляции</li>
        <li><strong>Управление памятью</strong> — автоматический подсчет ссылок (ARC) освобождает разработчика от ручного управления памятью</li>
        <li><strong>Производительность</strong> — Swift компилируется в машинный код и обеспечивает высокую производительность</li>
        <li><strong>Современный синтаксис</strong> — чистый и понятный код, минимум избыточности</li>
    </ul>
    
    <h2>Первая программа</h2>
    
    <p>Традиционная программа "Hello, World!" на Swift выглядит очень просто:</p>
    
    <pre><code>print("Hello, World!")</code></pre>
    
    <p>Это всё! Никаких дополнительных импортов или объявлений функций не требуется для такой простой программы.</p>
    
    <h2>Интерактивная разработка</h2>
    
    <p>Swift поставляется с интерактивной оболочкой REPL (Read-Eval-Print Loop), которая позволяет экспериментировать с кодом в реальном времени. Также доступны Swift Playgrounds — интерактивная среда для изучения программирования.</p>
    
</body>
</html>
"""
        case 2:
            return """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>Основы языка</title>
</head>
<body>
    <h1>Глава 2: Основы языка Swift</h1>
    
    <h2>Константы и переменные</h2>
    
    <p>В Swift используются два ключевых слова для объявления значений:</p>
    
    <ul>
        <li><code>let</code> — для констант (неизменяемых значений)</li>
        <li><code>var</code> — для переменных (изменяемых значений)</li>
    </ul>
    
    <p>Пример объявления констант и переменных:</p>
    <pre><code>let maximumNumberOfLoginAttempts = 10
var currentLoginAttempt = 0</code></pre>
    
    <h2>Типы данных</h2>
    
    <p>Swift предоставляет множество встроенных типов данных для работы с различными видами информации.</p>
    
</body>
</html>
"""
        case 3:
            return """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>Функции и замыкания</title>
</head>
<body>
    <h1>Глава 3: Функции и замыкания</h1>
    
    <h2>Объявление функций</h2>
    
    <p>Функции в Swift объявляются с помощью ключевого слова <code>func</code>:</p>
    
    <pre><code>func greet(name: String) -> String {
    return "Hello, \\(name)!"
}</code></pre>
    
    <h2>Замыкания</h2>
    
    <p>Замыкания — это самодостаточные блоки кода, которые могут передаваться и использоваться в коде. Функции — это особый случай замыканий.</p>
    
</body>
</html>
"""
        default:
            return ""
        }
    }
    
    /// Создает ZIP архив из директории (EPUB файл)
    private func zipEPUBDirectory(_ sourceDir: URL, to destination: URL) throws {
        // TODO: В реальной реализации здесь нужно использовать Compression framework или ZIPFoundation
        // Пока создаем простую заглушку - копируем первый файл как "архив"
        
        // Для демонстрации создадим простой файл
        let content = "EPUB архив (заглушка) - в реальной реализации здесь будет использован Compression framework"
        try content.write(to: destination, atomically: true, encoding: .utf8)
    }
}

/// Карточка книги в библиотеке
struct BookCardView: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Обложка книги
            bookCover
            
            // Информация о книге
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(book.displayAuthor)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(book.format.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    if book.readingProgress > 0 {
                        Text("\(book.progressPercentage)%")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 240)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private var bookCover: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: book.format == .epub ? [.purple.opacity(0.8), .purple] : [.accentColor.opacity(0.8), .accentColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 160)
            .overlay {
                VStack {
                    Image(systemName: book.format == .epub ? "book.closed" : "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(book.format.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
    }
}

#Preview {
    LibraryView()
}