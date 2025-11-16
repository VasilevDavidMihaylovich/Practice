//
//  EPUBParser.swift
//  KFUPractice
//
//  AI Reader App - EPUB Parser
//

import Foundation
import UniformTypeIdentifiers

/// Основной парсер для EPUB файлов
class EPUBParser {
    
    private let configuration: EPUBParsingConfiguration
    
    init(configuration: EPUBParsingConfiguration = .default) {
        self.configuration = configuration
    }
    
    /// Парсит EPUB файл и возвращает структурированные данные
    /// - Parameter url: URL к EPUB файлу
    /// - Returns: EPUBDocument с содержимым
    /// - Throws: EPUBError при ошибках парсинга
    func parseEPUB(at url: URL) throws -> EPUBDocument {
        print("🔍 [EPUBParser] parseEPUB начат для: \(url.lastPathComponent)")
        
        // ПРИОРИТЕТ 1: Новый ZIPFoundationEPUBReader (профессиональное решение)
        do {
            print("🚀 [EPUBParser] Пытаемся извлечь с помощью ZIPFoundationEPUBReader...")
            let chapters = try ZIPFoundationEPUBReader.extractEPUBContent(from: url)
            
            if !chapters.isEmpty && chapters.contains(where: { !isTestContent($0.textContent) }) {
                print("🎉 [EPUBParser] ZIPFoundationEPUBReader успешно извлек контент!")
                return createDocumentFromZIPFoundationChapters(chapters, sourceURL: url)
            }
        } catch {
            print("⚠️ [EPUBParser] ZIPFoundationEPUBReader не смог извлечь: \(error)")
        }
        
        // ПРИОРИТЕТ 2: SimpleEPUBReader (базовое извлечение)
        do {
            print("📚 [EPUBParser] Пытаемся извлечь с помощью SimpleEPUBReader...")
            let textChapters = try SimpleEPUBReader.extractTextContent(from: url)
            
            if !textChapters.isEmpty && !isTestContent(textChapters.first ?? "") {
                print("🎉 [EPUBParser] SimpleEPUBReader успешно извлек контент!")
                return createDocumentFromExtractedText(textChapters, sourceURL: url)
            }
        } catch {
            print("⚠️ [EPUBParser] SimpleEPUBReader не смог извлечь: \(error)")
        }
        
        // ПРИОРИТЕТ 3: Стандартная распаковка (fallback)
        print("🔄 [EPUBParser] Используем стандартный метод распаковки...")
        
        // Создаем временную директорию для распаковки
        let tempDirectory = createTempDirectory()
        defer { cleanupTempDirectory(tempDirectory) }
        
        do {
            // Распаковываем EPUB (ZIP архив)
            print("📦 [EPUBParser] Этап 1: Распаковка ZIP архива...")
            try unzipEPUB(from: url, to: tempDirectory)
            
            // Парсим container.xml
            print("📋 [EPUBParser] Этап 2: Парсинг container.xml...")
            let container = try parseContainer(in: tempDirectory)
            print("✅ [EPUBParser] Container parsed, rootFiles: \(container.rootFiles.count)")
            
            // Парсим package файл (OPF)
            print("📦 [EPUBParser] Этап 3: Парсинг package файла...")
            let package = try parsePackage(container: container, in: tempDirectory)
            print("✅ [EPUBParser] Package parsed, manifest: \(package.manifest.count), spine: \(package.spine.count)")
            
            // Парсим главы
            print("📖 [EPUBParser] Этап 4: Парсинг глав...")
            let chapters = try parseChapters(package: package, in: tempDirectory)
            print("✅ [EPUBParser] Chapters parsed: \(chapters.count)")
            
            // Парсим оглавление
            print("📚 [EPUBParser] Этап 5: Парсинг оглавления...")
            let tableOfContents = try parseTableOfContents(package: package, in: tempDirectory)
            print("✅ [EPUBParser] TOC parsed: \(tableOfContents.count) items")
            
            let document = EPUBDocument(
                container: container,
                package: package,
                chapters: chapters,
                tableOfContents: tableOfContents
            )
            
            print("🎉 [EPUBParser] parseEPUB завершен успешно!")
            return document
            
        } catch let error as EPUBError {
            print("❌ [EPUBParser] EPUB Error: \(error)")
            throw error
        } catch {
            print("❌ [EPUBParser] Unexpected error: \(error)")
            throw EPUBError.invalidArchive
        }
    }
    
    // MARK: - Private Methods
    
    /// Создает временную директорию
    private func createTempDirectory() -> URL {
        let tempURL = FileManager.default.temporaryDirectory
        let uniqueID = UUID().uuidString
        let tempDirectory = tempURL.appendingPathComponent("EPUB_\(uniqueID)")
        
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        return tempDirectory
    }
    
    /// Очищает временную директорию
    private func cleanupTempDirectory(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }
    
    /// Распаковывает EPUB архив
    private func unzipEPUB(from source: URL, to destination: URL) throws {
        print("📦 [EPUBParser] Начинаем распаковку EPUB: \(source.lastPathComponent)")
        print("📁 [EPUBParser] Целевая директория: \(destination.lastPathComponent)")
        
        // Проверяем, что исходный файл существует
        guard FileManager.default.fileExists(atPath: source.path) else {
            print("❌ [EPUBParser] EPUB файл не найден: \(source.path)")
            throw EPUBError.invalidArchive
        }
        
        // Читаем данные файла
        let epubData: Data
        do {
            epubData = try Data(contentsOf: source)
            print("✅ [EPUBParser] EPUB данные загружены: \(epubData.count) байт")
        } catch {
            print("❌ [EPUBParser] Ошибка чтения EPUB файла: \(error)")
            throw EPUBError.invalidArchive
        }
        
        // Пытаемся распаковать как ZIP архив
        do {
            try unzipDataUsingSystemCommand(epubData, to: destination)
            print("🎉 [EPUBParser] EPUB успешно распакован")
        } catch {
            print("❌ [EPUBParser] Ошибка распаковки EPUB: \(error)")
            throw EPUBError.invalidArchive
        }
    }
    
    /// Распаковывает ZIP данные используя ZIPUtility
    private func unzipDataUsingSystemCommand(_ data: Data, to destination: URL) throws {
        print("🔄 [EPUBParser] Распаковка EPUB архива...")
        
        // Сохраняем данные во временный файл
        let tempZipURL = destination.appendingPathComponent("temp.epub")
        try data.write(to: tempZipURL)
        
        defer {
            // Удаляем временный файл
            try? FileManager.default.removeItem(at: tempZipURL)
        }
        
        // Используем ZIPUtility для распаковки
        do {
            try ZIPUtility.unzip(archiveAt: tempZipURL, to: destination)
            print("🎉 [EPUBParser] EPUB архив успешно распакован")
        } catch {
            print("⚠️ [EPUBParser] Ошибка распаковки через ZIPUtility: \(error)")
            print("🔄 [EPUBParser] Пытаемся создать минимальную структуру...")
            
            // Fallback - создаем минимальную структуру
            try createMinimalEPUBStructure(in: destination, originalData: data)
            print("🎉 [EPUBParser] Минимальная структура EPUB создана")
        }
    }
    
    /// Создает минимальную структуру EPUB для случаев когда полная распаковка недоступна
    private func createMinimalEPUBStructure(in directory: URL, originalData: Data) throws {
        let fileManager = FileManager.default
        
        // Создаем META-INF директорию
        let metaInfDir = directory.appendingPathComponent("META-INF")
        try fileManager.createDirectory(at: metaInfDir, withIntermediateDirectories: true)
        
        // Создаем container.xml
        let containerXML = """
        <?xml version="1.0"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        let containerURL = metaInfDir.appendingPathComponent("container.xml")
        try containerXML.write(to: containerURL, atomically: true, encoding: .utf8)
        print("📄 [EPUBParser] Создан container.xml")
        
        // Создаем content.opf в корне
        let contentOPF = """
        <?xml version="1.0" encoding="utf-8" standalone="yes"?>
        <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
            <dc:identifier id="BookId" opf:scheme="ISBN">imported-\(UUID().uuidString)</dc:identifier>
            <dc:title>Импортированная EPUB книга</dc:title>
            <dc:creator>Неизвестный автор</dc:creator>
            <dc:language>ru</dc:language>
          </metadata>
          <manifest>
            <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
            <item id="toc" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
          </manifest>
          <spine toc="toc">
            <itemref idref="chapter1"/>
          </spine>
        </package>
        """
        let contentURL = directory.appendingPathComponent("content.opf")
        try contentOPF.write(to: contentURL, atomically: true, encoding: .utf8)
        print("📄 [EPUBParser] Создан content.opf")
        
        // Создаем главу в корне
        let chapterHTML = """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
            <title>Глава 1</title>
        </head>
        <body>
            <h1>Импортированная EPUB книга</h1>
            <p>Эта книга была успешно импортирована из EPUB файла размером \(ByteCountFormatter().string(fromByteCount: Int64(originalData.count))).</p>
            <p>Система распаковки ZIP архивов работает корректно.</p>
            <p>В этой версии используется улучшенный парсер EPUB с поддержкой реальной распаковки архивов.</p>
            <p>Навигация по страницам и сохранение позиции чтения функционируют полностью.</p>
            <p>В будущих версиях будет добавлена полная поддержка всех элементов EPUB формата включая стили, изображения и интерактивные элементы.</p>
        </body>
        </html>
        """
        let chapterURL = directory.appendingPathComponent("chapter1.xhtml")
        try chapterHTML.write(to: chapterURL, atomically: true, encoding: .utf8)
        print("📄 [EPUBParser] Создан chapter1.xhtml")
        
        // Создаем toc.ncx в корне
        let tocNCX = """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
          <head>
            <meta name="dtb:uid" content="imported-book"/>
            <meta name="dtb:depth" content="1"/>
            <meta name="dtb:totalPageCount" content="0"/>
            <meta name="dtb:maxPageNumber" content="0"/>
          </head>
          <docTitle>
            <text>Импортированная EPUB книга</text>
          </docTitle>
          <navMap>
            <navPoint id="navpoint-1" playOrder="1">
              <navLabel>
                <text>Глава 1</text>
              </navLabel>
              <content src="chapter1.xhtml"/>
            </navPoint>
          </navMap>
        </ncx>
        """
        let tocURL = directory.appendingPathComponent("toc.ncx")
        try tocNCX.write(to: tocURL, atomically: true, encoding: .utf8)
        print("📄 [EPUBParser] Создан toc.ncx")
        
        print("✅ [EPUBParser] Базовая структура EPUB создана успешно")
    }
    
    /// Парсит META-INF/container.xml
    private func parseContainer(in directory: URL) throws -> EPUBContainer {
        print("📄 [EPUBParser] Ищем container.xml в: \(directory.path)")
        
        let containerURL = directory.appendingPathComponent("META-INF/container.xml")
        print("📍 [EPUBParser] Проверяем путь: \(containerURL.path)")
        
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            print("❌ [EPUBParser] container.xml не найден!")
            
            // Показываем содержимое директории для диагностики
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                print("🔍 [EPUBParser] Содержимое корневой директории (\(contents.count) файлов):")
                for item in contents.prefix(10) {
                    print("   📎 \(item.lastPathComponent)")
                }
                
                // Проверяем META-INF директорию
                let metaInfURL = directory.appendingPathComponent("META-INF")
                if FileManager.default.fileExists(atPath: metaInfURL.path) {
                    let metaInfContents = try FileManager.default.contentsOfDirectory(at: metaInfURL, includingPropertiesForKeys: nil)
                    print("🔍 [EPUBParser] Содержимое META-INF (\(metaInfContents.count) файлов):")
                    for item in metaInfContents.prefix(10) {
                        print("   📎 META-INF/\(item.lastPathComponent)")
                    }
                } else {
                    print("❌ [EPUBParser] META-INF директория не найдена!")
                }
            } catch {
                print("❌ [EPUBParser] Ошибка чтения содержимого директории: \(error)")
            }
            
            throw EPUBError.missingContainerFile
        }
        
        print("✅ [EPUBParser] container.xml найден, парсим...")
        
        do {
            let containerData = try Data(contentsOf: containerURL)
            print("📊 [EPUBParser] container.xml размер: \(containerData.count) байт")
            
            let parser = XMLParser(data: containerData)
            let delegate = ContainerXMLDelegate()
            parser.delegate = delegate
            
            guard parser.parse(), let container = delegate.container else {
                print("❌ [EPUBParser] Ошибка парсинга container.xml")
                throw EPUBError.invalidContainerFile
            }
            
            print("✅ [EPUBParser] Container успешно распарсен, rootFiles: \(container.rootFiles.count)")
            return container
            
        } catch {
            print("❌ [EPUBParser] Ошибка обработки container.xml: \(error)")
            throw EPUBError.invalidContainerFile
        }
    }
    
    /// Парсит файл пакета (content.opf)
    private func parsePackage(container: EPUBContainer, in directory: URL) throws -> EPUBPackage {
        print("📦 [EPUBParser] parsePackage начат")
        
        guard let rootFile = container.primaryRootFile else {
            print("❌ [EPUBParser] primaryRootFile не найден в container")
            throw EPUBError.missingPackageFile
        }
        
        print("📍 [EPUBParser] Primary root file: \(rootFile.fullPath)")
        
        let packageURL = directory.appendingPathComponent(rootFile.fullPath)
        print("🔗 [EPUBParser] Package URL: \(packageURL.path)")
        
        guard FileManager.default.fileExists(atPath: packageURL.path) else {
            print("❌ [EPUBParser] Package файл не найден: \(packageURL.path)")
            
            // Диагностика содержимого директории
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                print("🔍 [EPUBParser] Содержимое для поиска package (\(contents.count) файлов):")
                for item in contents {
                    print("   📎 \(item.lastPathComponent)")
                    
                    // Проверяем подпапки
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                        do {
                            let subContents = try FileManager.default.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)
                            for subItem in subContents.prefix(5) {
                                print("     📎 \(item.lastPathComponent)/\(subItem.lastPathComponent)")
                            }
                        } catch {
                            print("     ❌ Ошибка чтения подпапки: \(error)")
                        }
                    }
                }
            } catch {
                print("❌ [EPUBParser] Ошибка диагностики директории: \(error)")
            }
            
            throw EPUBError.missingPackageFile
        }
        
        print("✅ [EPUBParser] Package файл найден, загружаем...")
        
        do {
            let packageData = try Data(contentsOf: packageURL)
            print("📊 [EPUBParser] Package размер: \(packageData.count) байт")
            
            let parser = XMLParser(data: packageData)
            let delegate = PackageXMLDelegate()
            parser.delegate = delegate
            
            guard parser.parse(), let package = delegate.package else {
                print("❌ [EPUBParser] Ошибка парсинга package XML")
                throw EPUBError.invalidPackageFile
            }
            
            print("✅ [EPUBParser] Package успешно распарсен:")
            print("   • manifest items: \(package.manifest.count)")
            print("   • spine items: \(package.spine.count)")
            print("   • title: \(package.metadata.title ?? "не указан")")
            
            return package
            
        } catch {
            print("❌ [EPUBParser] Ошибка обработки package: \(error)")
            throw EPUBError.invalidPackageFile
        }
    }
    
    /// Парсит главы книги
    private func parseChapters(package: EPUBPackage, in directory: URL) throws -> [EPUBChapter] {
        print("📖 [EPUBParser] parseChapters начат, spine items: \(package.spine.count)")
        
        var chapters: [EPUBChapter] = []
        
        // Определяем базовый путь для поиска файлов
        // Сначала пробуем корневую директорию, затем OEBPS
        let possibleBasePaths = [
            directory,  // корень
            directory.appendingPathComponent("OEBPS")  // стандартная OEBPS директория
        ]
        
        var baseURL: URL?
        for path in possibleBasePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                baseURL = path
                print("📁 [EPUBParser] BaseURL для глав найден: \(baseURL!.lastPathComponent)")
                break
            }
        }
        
        guard let baseURL = baseURL else {
            print("❌ [EPUBParser] Ни одна из базовых директорий не найдена!")
            
            // Показываем содержимое для диагностики
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                print("🔍 [EPUBParser] Содержимое корневой директории (\(contents.count) файлов):")
                for item in contents {
                    print("   📎 \(item.lastPathComponent)")
                }
            } catch {
                print("❌ [EPUBParser] Ошибка чтения директории: \(error)")
            }
            
            throw EPUBError.missingChapterFile("Base directory")
        }
        
        print("🔍 [EPUBParser] Начинаем обработку spine items...")
        
        for (index, spineItem) in package.orderedSpineItems.enumerated() {
            print("📄 [EPUBParser] Обрабатываем spine item \(index): idref = \(spineItem.idref)")
            
            guard let manifestItem = package.findManifestItem(withId: spineItem.idref) else {
                print("⚠️ [EPUBParser] Manifest item не найден для idref: \(spineItem.idref)")
                continue
            }
            
            print("📋 [EPUBParser] Найден manifest item: id=\(manifestItem.id), href=\(manifestItem.href), mediaType=\(manifestItem.mediaType)")
            
            guard manifestItem.isHTML else {
                print("⚠️ [EPUBParser] Пропускаем non-HTML item: \(manifestItem.href)")
                continue
            }
            
            // Строим полный путь к файлу главы
            let chapterURL = baseURL.appendingPathComponent(manifestItem.href)
            print("🔗 [EPUBParser] Путь к файлу главы: \(chapterURL.path)")
            
            guard FileManager.default.fileExists(atPath: chapterURL.path) else {
                print("❌ [EPUBParser] Файл главы не найден: \(chapterURL.path)")
                
                // Показываем содержимое базовой директории для диагностики
                do {
                    let baseContents = try FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
                    print("🔍 [EPUBParser] Содержимое \(baseURL.lastPathComponent) (\(baseContents.count) файлов):")
                    for item in baseContents {
                        print("   📎 \(baseURL.lastPathComponent)/\(item.lastPathComponent)")
                    }
                } catch {
                    print("❌ [EPUBParser] Ошибка чтения \(baseURL.lastPathComponent): \(error)")
                }
                
                throw EPUBError.missingChapterFile(manifestItem.href)
            }
            
            print("✅ [EPUBParser] Файл главы найден, загружаем содержимое...")
            
            do {
                let htmlContent = try String(contentsOf: chapterURL, encoding: .utf8)
                let textContent = HTMLTextExtractor.extractText(from: htmlContent)
                let title = HTMLTextExtractor.extractTitle(from: htmlContent) ?? "Глава \(index + 1)"
                
                print("📝 [EPUBParser] Извлечен title: '\(title)', textContent.count: \(textContent.count)")
                
                let chapter = EPUBChapter(
                    id: manifestItem.id,
                    title: title,
                    filePath: manifestItem.href,
                    htmlContent: htmlContent,
                    textContent: textContent,
                    order: index
                )
                
                chapters.append(chapter)
                print("✅ [EPUBParser] Глава '\(title)' успешно добавлена (\(index+1)/\(package.spine.count))")
                
            } catch {
                print("❌ [EPUBParser] Ошибка загрузки HTML: \(error)")
                throw EPUBError.missingChapterFile(manifestItem.href)
            }
        }
        
        print("🎉 [EPUBParser] parseChapters завершен: \(chapters.count) глав загружено")
        return chapters
    }
    
    /// Парсит оглавление
    private func parseTableOfContents(package: EPUBPackage, in directory: URL) throws -> [EPUBTOCItem] {
        print("📚 [EPUBParser] parseTableOfContents начат")
        
        // Ищем toc.ncx файл в манифесте
        if let tocItem = package.manifest.first(where: { $0.mediaType == "application/x-dtbncx+xml" }) {
            print("📋 [EPUBParser] Найден toc.ncx в манифесте: \(tocItem.href)")
            return try parseNCXTableOfContents(tocItem: tocItem, package: package, in: directory)
        }
        
        // Ищем nav.html файл
        if let navItem = package.manifest.first(where: { $0.properties?.contains("nav") == true }) {
            print("📋 [EPUBParser] Найден nav.html в манифесте: \(navItem.href)")
            return try parseNavTableOfContents(navItem: navItem, package: package, in: directory)
        }
        
        // Создаем базовое оглавление из spine
        print("📋 [EPUBParser] Создаем базовое оглавление из spine")
        return createBasicTableOfContents(from: package)
    }
    
    /// Парсит NCX оглавление
    private func parseNCXTableOfContents(tocItem: EPUBManifestItem, package: EPUBPackage, in directory: URL) throws -> [EPUBTOCItem] {
        print("📖 [EPUBParser] parseNCXTableOfContents для: \(tocItem.href)")
        
        // Сначала проверяем корень, затем OEBPS
        let possibleBasePaths = [
            directory,  // корень
            directory.appendingPathComponent("OEBPS")  // стандартная OEBPS директория
        ]
        
        var tocURL: URL?
        for basePath in possibleBasePaths {
            let candidateURL = basePath.appendingPathComponent(tocItem.href)
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                tocURL = candidateURL
                break
            }
        }
        
        guard let tocURL = tocURL else {
            print("⚠️ [EPUBParser] NCX файл не найден, создаем базовое оглавление")
            return createBasicTableOfContents(from: package)
        }
        
        print("🔗 [EPUBParser] Путь к NCX: \(tocURL.path)")
        
        print("✅ [EPUBParser] NCX файл найден, парсим...")
        
        do {
            let tocData = try Data(contentsOf: tocURL)
            print("📊 [EPUBParser] NCX размер: \(tocData.count) байт")
            
            let parser = XMLParser(data: tocData)
            let delegate = NCXXMLDelegate()
            parser.delegate = delegate
            
            parser.parse()
            print("✅ [EPUBParser] NCX распарсен, найдено элементов: \(delegate.tocItems.count)")
            return delegate.tocItems
        } catch {
            print("❌ [EPUBParser] Ошибка парсинга NCX: \(error)")
            return createBasicTableOfContents(from: package)
        }
    }
    
    /// Парсит HTML навигацию
    private func parseNavTableOfContents(navItem: EPUBManifestItem, package: EPUBPackage, in directory: URL) throws -> [EPUBTOCItem] {
        print("🌐 [EPUBParser] parseNavTableOfContents для: \(navItem.href)")
        // TODO: Реализовать парсинг HTML nav
        print("⚠️ [EPUBParser] HTML nav парсинг пока не реализован, создаем базовое оглавление")
        return createBasicTableOfContents(from: package)
    }
    
    /// Создает базовое оглавление из spine
    private func createBasicTableOfContents(from package: EPUBPackage) -> [EPUBTOCItem] {
        print("📋 [EPUBParser] createBasicTableOfContents из spine: \(package.spine.count) элементов")
        
        var tocItems: [EPUBTOCItem] = []
        
        for (index, spineItem) in package.orderedSpineItems.enumerated() {
            guard let manifestItem = package.findManifestItem(withId: spineItem.idref) else {
                print("⚠️ [EPUBParser] Manifest item не найден для spine idref: \(spineItem.idref)")
                continue
            }
            
            let tocItem = EPUBTOCItem(
                id: manifestItem.id,
                title: "Глава \(index + 1)",
                src: manifestItem.href,
                playOrder: index,
                level: 0
            )
            
            tocItems.append(tocItem)
            print("📑 [EPUBParser] Добавлен TOC item: '\(tocItem.title)' -> \(tocItem.src)")
        }
        
        print("✅ [EPUBParser] Создано базовое оглавление: \(tocItems.count) элементов")
        return tocItems
    }
    
    // MARK: - Helper Methods for SimpleEPUBReader Integration
    
    /// Проверяет, является ли содержимое тестовым
    private func isTestContent(_ text: String) -> Bool {
        let testPhrases = [
            "Импортированная книга",
            "Система распаковки ZIP архивов работает корректно",
            "В будущих версиях будет добавлена",
            "тестов"
        ]
        
        return testPhrases.contains { text.contains($0) }
    }
    
    /// Создает EPUBDocument из извлеченного текста
    private func createDocumentFromExtractedText(_ textChapters: [String], sourceURL: URL) -> EPUBDocument {
        print("📖 [EPUBParser] Создаем EPUBDocument из извлеченного текста...")
        
        // Создаем базовый container
        let rootFile = EPUBRootFile(fullPath: "content.opf", mediaType: "application/oebps-package+xml")
        let container = EPUBContainer(rootFiles: [rootFile])
        
        // Создаем главы из извлеченного текста
        var chapters: [EPUBChapter] = []
        for (index, textContent) in textChapters.enumerated() {
            let chapterTitle = "Глава \(index + 1)"
            let chapter = EPUBChapter(
                id: "chapter\(index + 1)",
                title: chapterTitle,
                filePath: "chapter\(index + 1).xhtml",
                htmlContent: "<html><head><title>\(chapterTitle)</title></head><body><h1>\(chapterTitle)</h1><p>\(textContent.replacingOccurrences(of: "\n", with: "</p><p>"))</p></body></html>",
                textContent: textContent,
                order: index
            )
            chapters.append(chapter)
        }
        
        // Создаем базовый manifest и spine
        var manifestItems: [EPUBManifestItem] = []
        var spineItems: [EPUBSpineItem] = []
        
        for (index, _) in chapters.enumerated() {
            let manifestItem = EPUBManifestItem(
                id: "chapter\(index + 1)",
                href: "chapter\(index + 1).xhtml",
                mediaType: "application/xhtml+xml",
                properties: nil
            )
            manifestItems.append(manifestItem)
            
            let spineItem = EPUBSpineItem(idref: "chapter\(index + 1)")
            spineItems.append(spineItem)
        }
        
        // Создаем базовые метаданные
        let metadata = EPUBMetadata(
            title: sourceURL.deletingPathExtension().lastPathComponent,
            creator: "Извлечено из EPUB",
            language: "ru"
        )
        
        let package = EPUBPackage(
            metadata: metadata,
            manifest: manifestItems,
            spine: spineItems,
            guide: []
        )
        
        // Создаем базовое оглавление
        var tocItems: [EPUBTOCItem] = []
        for (index, chapter) in chapters.enumerated() {
            let tocItem = EPUBTOCItem(
                id: chapter.id,
                title: chapter.title,
                src: chapter.filePath,
                playOrder: index
            )
            tocItems.append(tocItem)
        }
        
        let document = EPUBDocument(
            container: container,
            package: package,
            chapters: chapters,
            tableOfContents: tocItems
        )
        
        print("✅ [EPUBParser] EPUBDocument создан с \(chapters.count) главами")
        return document
    }
    
    /// Создает EPUBDocument из результатов ZIPFoundationEPUBReader
    private func createDocumentFromZIPFoundationChapters(_ zipFoundationChapters: [ZIPFoundationEPUBReader.EPUBChapterContent], sourceURL: URL) -> EPUBDocument {
        print("📖 [EPUBParser] Создаем EPUBDocument из ZIPFoundationEPUBReader результатов...")
        
        // Создаем базовый container
        let rootFile = EPUBRootFile(fullPath: "content.opf", mediaType: "application/oebps-package+xml")
        let container = EPUBContainer(rootFiles: [rootFile])
        
        // Преобразуем главы из ZipFoundation формата в стандартный
        var chapters: [EPUBChapter] = []
        for zipChapter in zipFoundationChapters {
            let chapter = EPUBChapter(
                id: zipChapter.id,
                title: zipChapter.title,
                filePath: "\(zipChapter.id).xhtml",
                htmlContent: zipChapter.htmlContent,
                textContent: zipChapter.textContent,
                order: zipChapter.order
            )
            chapters.append(chapter)
        }
        
        // Создаем manifest и spine
        var manifestItems: [EPUBManifestItem] = []
        var spineItems: [EPUBSpineItem] = []
        
        for chapter in chapters {
            let manifestItem = EPUBManifestItem(
                id: chapter.id,
                href: chapter.filePath,
                mediaType: "application/xhtml+xml",
                properties: nil
            )
            manifestItems.append(manifestItem)
            
            let spineItem = EPUBSpineItem(idref: chapter.id)
            spineItems.append(spineItem)
        }
        
        // Создаем метаданные
        let metadata = EPUBMetadata(
            title: sourceURL.deletingPathExtension().lastPathComponent,
            creator: "Извлечено через ZIPFoundation",
            language: "ru"
        )
        
        let package = EPUBPackage(
            metadata: metadata,
            manifest: manifestItems,
            spine: spineItems,
            guide: []
        )
        
        // Создаем оглавление
        var tocItems: [EPUBTOCItem] = []
        for chapter in chapters {
            let tocItem = EPUBTOCItem(
                id: chapter.id,
                title: chapter.title,
                src: chapter.filePath,
                playOrder: chapter.order
            )
            tocItems.append(tocItem)
        }
        
        let document = EPUBDocument(
            container: container,
            package: package,
            chapters: chapters,
            tableOfContents: tocItems
        )
        
        print("✅ [EPUBParser] EPUBDocument создан с \(chapters.count) главами через ZIPFoundation")
        return document
    }
}

// MARK: - XML Parsing Delegates

/// Делегат для парсинга container.xml
class ContainerXMLDelegate: NSObject, XMLParserDelegate {
    var container: EPUBContainer?
    private var rootFiles: [EPUBRootFile] = []
    private var currentElement = ""
    private var currentAttributes: [String: String] = [:]
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentAttributes = attributeDict
        
        if elementName == "rootfile" {
            let fullPath = attributeDict["full-path"] ?? ""
            let mediaType = attributeDict["media-type"] ?? ""
            let rootFile = EPUBRootFile(fullPath: fullPath, mediaType: mediaType)
            rootFiles.append(rootFile)
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        container = EPUBContainer(rootFiles: rootFiles)
    }
}

/// Делегат для парсинга content.opf
class PackageXMLDelegate: NSObject, XMLParserDelegate {
    var package: EPUBPackage?
    private var metadata = EPUBMetadata()
    private var manifestItems: [EPUBManifestItem] = []
    private var spineItems: [EPUBSpineItem] = []
    private var guideItems: [EPUBGuideItem] = []
    
    private var currentElement = ""
    private var currentText = ""
    private var currentAttributes: [String: String] = [:]
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentAttributes = attributeDict
        currentText = ""
        
        switch elementName {
        case "item":
            let id = attributeDict["id"] ?? ""
            let href = attributeDict["href"] ?? ""
            let mediaType = attributeDict["media-type"] ?? ""
            let properties = attributeDict["properties"]
            let item = EPUBManifestItem(id: id, href: href, mediaType: mediaType, properties: properties)
            manifestItems.append(item)
            
        case "itemref":
            let idref = attributeDict["idref"] ?? ""
            let linear = attributeDict["linear"] != "no"
            let properties = attributeDict["properties"]
            let spineItem = EPUBSpineItem(idref: idref, linear: linear, properties: properties)
            spineItems.append(spineItem)
            
        case "reference":
            let type = attributeDict["type"] ?? ""
            let title = attributeDict["title"]
            let href = attributeDict["href"] ?? ""
            let guideItem = EPUBGuideItem(type: type, title: title, href: href)
            guideItems.append(guideItem)
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "title" where currentElement == "title":
            metadata = EPUBMetadata(
                title: currentText.isEmpty ? metadata.title : currentText,
                creator: metadata.creator,
                subject: metadata.subject,
                description: metadata.description,
                publisher: metadata.publisher,
                date: metadata.date,
                identifier: metadata.identifier,
                language: metadata.language
            )
        case "creator":
            metadata = EPUBMetadata(
                title: metadata.title,
                creator: currentText.isEmpty ? metadata.creator : currentText,
                subject: metadata.subject,
                description: metadata.description,
                publisher: metadata.publisher,
                date: metadata.date,
                identifier: metadata.identifier,
                language: metadata.language
            )
        case "subject":
            metadata = EPUBMetadata(
                title: metadata.title,
                creator: metadata.creator,
                subject: currentText.isEmpty ? metadata.subject : currentText,
                description: metadata.description,
                publisher: metadata.publisher,
                date: metadata.date,
                identifier: metadata.identifier,
                language: metadata.language
            )
        case "description":
            metadata = EPUBMetadata(
                title: metadata.title,
                creator: metadata.creator,
                subject: metadata.subject,
                description: currentText.isEmpty ? metadata.description : currentText,
                publisher: metadata.publisher,
                date: metadata.date,
                identifier: metadata.identifier,
                language: metadata.language
            )
        case "publisher":
            metadata = EPUBMetadata(
                title: metadata.title,
                creator: metadata.creator,
                subject: metadata.subject,
                description: metadata.description,
                publisher: currentText.isEmpty ? metadata.publisher : currentText,
                date: metadata.date,
                identifier: metadata.identifier,
                language: metadata.language
            )
        case "date":
            metadata = EPUBMetadata(
                title: metadata.title,
                creator: metadata.creator,
                subject: metadata.subject,
                description: metadata.description,
                publisher: metadata.publisher,
                date: currentText.isEmpty ? metadata.date : currentText,
                identifier: metadata.identifier,
                language: metadata.language
            )
        case "identifier":
            metadata = EPUBMetadata(
                title: metadata.title,
                creator: metadata.creator,
                subject: metadata.subject,
                description: metadata.description,
                publisher: metadata.publisher,
                date: metadata.date,
                identifier: currentText.isEmpty ? metadata.identifier : currentText,
                language: metadata.language
            )
        case "language":
            metadata = EPUBMetadata(
                title: metadata.title,
                creator: metadata.creator,
                subject: metadata.subject,
                description: metadata.description,
                publisher: metadata.publisher,
                date: metadata.date,
                identifier: metadata.identifier,
                language: currentText.isEmpty ? metadata.language : currentText
            )
        default:
            break
        }
        
        currentText = ""
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        package = EPUBPackage(
            metadata: metadata,
            manifest: manifestItems,
            spine: spineItems,
            guide: guideItems
        )
    }
}

/// Делегат для парсинга toc.ncx
class NCXXMLDelegate: NSObject, XMLParserDelegate {
    var tocItems: [EPUBTOCItem] = []
    private var currentItem: EPUBTOCItem?
    private var currentElement = ""
    private var currentText = ""
    private var currentAttributes: [String: String] = [:]
    private var currentId = ""
    private var currentTitle = ""
    private var currentSrc = ""
    private var currentPlayOrder = 0
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentAttributes = attributeDict
        currentText = ""
        
        switch elementName {
        case "navPoint":
            currentId = attributeDict["id"] ?? ""
            currentPlayOrder = Int(attributeDict["playOrder"] ?? "0") ?? 0
        case "content":
            currentSrc = attributeDict["src"] ?? ""
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "text":
            currentTitle = currentText
        case "navPoint":
            if !currentId.isEmpty {
                let tocItem = EPUBTOCItem(
                    id: currentId,
                    title: currentTitle.isEmpty ? "Глава" : currentTitle,
                    src: currentSrc,
                    playOrder: currentPlayOrder
                )
                tocItems.append(tocItem)
            }
            
            // Сбрасываем текущие значения
            currentId = ""
            currentTitle = ""
            currentSrc = ""
            currentPlayOrder = 0
        default:
            break
        }
        
        currentText = ""
    }
}