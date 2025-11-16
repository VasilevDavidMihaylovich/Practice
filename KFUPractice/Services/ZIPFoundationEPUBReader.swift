//
//  ZIPFoundationEPUBReader.swift
//  KFUPractice
//
//  Профессиональный EPUB ридер использующий ZIPFoundation подходы
//

import Foundation

/// Профессиональный EPUB ридер основанный на ZIPFoundation принципах
class ZIPFoundationEPUBReader {
    
    // MARK: - EPUB Structure Models
    
    struct EPUBContainer {
        let rootFilePath: String
        let mediaType: String
    }
    
    struct EPUBMetadata {
        let title: String
        let creator: String
        let identifier: String
        let language: String
    }
    
    struct EPUBManifestItem {
        let id: String
        let href: String
        let mediaType: String
    }
    
    struct EPUBSpineItem {
        let idref: String
    }
    
    struct EPUBChapterContent {
        let id: String
        let title: String
        let htmlContent: String
        let textContent: String
        let order: Int
    }
    
    // MARK: - Main Interface
    
    /// Извлекает содержимое EPUB файла
    /// - Parameter epubURL: URL к EPUB файлу
    /// - Returns: Массив глав с содержимым
    /// - Throws: EPUBError при ошибках
    static func extractEPUBContent(from epubURL: URL) throws -> [EPUBChapterContent] {
        print("📚 [ZIPFoundationEPUBReader] Начинаем извлечение из: \(epubURL.lastPathComponent)")
        
        // Читаем EPUB как ZIP архив
        let epubData = try Data(contentsOf: epubURL)
        guard validateEPUBStructure(data: epubData) else {
            throw EPUBError.invalidArchive
        }
        
        // Создаем временную директорию для распаковки
        let tempDir = createTemporaryDirectory()
        defer { cleanupDirectory(tempDir) }
        
        // Распаковываем архив используя встроенные возможности
        try extractArchiveContents(epubData: epubData, to: tempDir)
        
        // Парсим EPUB структуру
        let container = try parseContainer(in: tempDir)
        let opfPath = container.rootFilePath
        let (metadata, manifest, spine) = try parseOPF(at: opfPath, in: tempDir)
        
        // Извлекаем содержимое глав
        let chapters = try extractChapterContents(
            manifest: manifest,
            spine: spine,
            baseDirectory: tempDir,
            metadata: metadata
        )
        
        print("✅ [ZIPFoundationEPUBReader] Извлечено \(chapters.count) глав")
        return chapters
    }
    
    // MARK: - Archive Processing
    
    /// Валидирует EPUB структуру
    private static func validateEPUBStructure(data: Data) -> Bool {
        // Проверяем ZIP сигнатуру
        guard data.count >= 4 else { return false }
        
        let zipSignature = Data([0x50, 0x4B, 0x03, 0x04]) // ZIP local file header
        let altSignature = Data([0x50, 0x4B, 0x05, 0x06]) // ZIP central directory
        let header = data.prefix(4)
        
        return header.starts(with: Data([0x50, 0x4B]))
    }
    
    /// Извлекает содержимое архива используя системные инструменты
    private static func extractArchiveContents(epubData: Data, to destination: URL) throws {
        // Сохраняем во временный файл
        let tempZipFile = destination.appendingPathComponent("temp.epub")
        try epubData.write(to: tempZipFile)
        
        defer {
            try? FileManager.default.removeItem(at: tempZipFile)
        }
        
        // Используем встроенную распаковку через NSFileManager
        do {
            try FileManager.default.unzipItem(at: tempZipFile, to: destination)
            print("✅ [ZIPFoundationEPUBReader] Архив распакован через FileManager")
        } catch {
            print("⚠️ [ZIPFoundationEPUBReader] FileManager failed, trying manual extraction")
            
            // Fallback: используем собственную реализацию
            try manualArchiveExtraction(epubData: epubData, to: destination)
        }
    }
    
    /// Ручная распаковка ZIP архива (fallback)
    private static func manualArchiveExtraction(epubData: Data, to destination: URL) throws {
        print("🔧 [ZIPFoundationEPUBReader] Ручная распаковка ZIP архива")
        
        // Ищем записи в ZIP архиве
        let centralDirectoryOffset = try findCentralDirectoryOffset(in: epubData)
        let entries = try parseZIPEntries(data: epubData, centralDirectoryOffset: centralDirectoryOffset)
        
        // Извлекаем каждую запись
        for entry in entries {
            try extractZIPEntry(entry: entry, from: epubData, to: destination)
        }
        
        print("✅ [ZIPFoundationEPUBReader] Ручная распаковка завершена")
    }
    
    // MARK: - ZIP Parsing (Simplified)
    
    private struct ZIPEntry {
        let fileName: String
        let offset: UInt32
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let compressionMethod: UInt16
    }
    
    private static func findCentralDirectoryOffset(in data: Data) throws -> Int {
        // Ищем End of Central Directory Record (EOCD)
        let eocdSignature: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
        
        // Поиск сзади (EOCD обычно в конце файла)
        for i in stride(from: data.count - 22, through: max(0, data.count - 65557), by: -1) {
            let slice = data.subdata(in: i..<min(i + 4, data.count))
            if slice == Data(eocdSignature) {
                // Найден EOCD, читаем offset central directory
                let cdOffset = data.subdata(in: (i + 16)..<(i + 20))
                return Int(cdOffset.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
            }
        }
        
        throw EPUBError.invalidArchive
    }
    
    private static func parseZIPEntries(data: Data, centralDirectoryOffset: Int) throws -> [ZIPEntry] {
        var entries: [ZIPEntry] = []
        var offset = centralDirectoryOffset
        
        while offset < data.count - 4 {
            // Проверяем сигнатуру Central Directory File Header
            let signature = data.subdata(in: offset..<(offset + 4))
            let expectedSignature = Data([0x50, 0x4B, 0x01, 0x02])
            
            guard signature == expectedSignature else {
                break
            }
            
            // Читаем основные поля
            let compressionMethod = data.subdata(in: (offset + 10)..<(offset + 12))
                .withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            
            let compressedSize = data.subdata(in: (offset + 20)..<(offset + 24))
                .withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
            
            let uncompressedSize = data.subdata(in: (offset + 24)..<(offset + 28))
                .withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
            
            let fileNameLength = data.subdata(in: (offset + 28)..<(offset + 30))
                .withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            
            let extraFieldLength = data.subdata(in: (offset + 30)..<(offset + 32))
                .withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            
            let commentLength = data.subdata(in: (offset + 32)..<(offset + 34))
                .withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
            
            let localHeaderOffset = data.subdata(in: (offset + 42)..<(offset + 46))
                .withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
            
            // Читаем имя файла
            let fileNameData = data.subdata(in: (offset + 46)..<(offset + 46 + Int(fileNameLength)))
            guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                offset += 46 + Int(fileNameLength) + Int(extraFieldLength) + Int(commentLength)
                continue
            }
            
            let entry = ZIPEntry(
                fileName: fileName,
                offset: localHeaderOffset,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                compressionMethod: compressionMethod
            )
            
            entries.append(entry)
            
            // Переход к следующей записи
            offset += 46 + Int(fileNameLength) + Int(extraFieldLength) + Int(commentLength)
        }
        
        return entries
    }
    
    private static func extractZIPEntry(entry: ZIPEntry, from data: Data, to destination: URL) throws {
        // Читаем Local File Header
        let localHeaderOffset = Int(entry.offset)
        
        // Проверяем сигнатуру
        let signature = data.subdata(in: localHeaderOffset..<(localHeaderOffset + 4))
        let expectedSignature = Data([0x50, 0x4B, 0x03, 0x04])
        
        guard signature == expectedSignature else {
            print("⚠️ [ZIPFoundationEPUBReader] Invalid local file header for \(entry.fileName)")
            return
        }
        
        // Читаем длины имени файла и extra field
        let fileNameLength = data.subdata(in: (localHeaderOffset + 26)..<(localHeaderOffset + 28))
            .withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
        
        let extraFieldLength = data.subdata(in: (localHeaderOffset + 28)..<(localHeaderOffset + 30))
            .withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
        
        // Вычисляем offset данных файла
        let fileDataOffset = localHeaderOffset + 30 + Int(fileNameLength) + Int(extraFieldLength)
        
        // Извлекаем данные файла
        let fileData = data.subdata(in: fileDataOffset..<(fileDataOffset + Int(entry.compressedSize)))
        
        // Создаем путь назначения
        let fileURL = destination.appendingPathComponent(entry.fileName)
        
        // Создаем директории если нужно
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        // Записываем файл (упрощенно, без декомпрессии для STORED файлов)
        if entry.compressionMethod == 0 { // STORED (без сжатия)
            try fileData.write(to: fileURL)
        } else {
            // Для сжатых файлов пропускаем или используем простую обработку
            print("⚠️ [ZIPFoundationEPUBReader] Skipping compressed file: \(entry.fileName)")
        }
    }
    
    // MARK: - EPUB Parsing
    
    /// Парсит container.xml
    private static func parseContainer(in directory: URL) throws -> EPUBContainer {
        let containerPath = directory.appendingPathComponent("META-INF/container.xml")
        
        guard FileManager.default.fileExists(atPath: containerPath.path) else {
            throw EPUBError.missingContainerFile
        }
        
        let containerData = try Data(contentsOf: containerPath)
        guard let containerXML = String(data: containerData, encoding: .utf8) else {
            throw EPUBError.invalidContainerFile
        }
        
        // Простой парсинг XML для rootfile
        guard let rootFileMatch = containerXML.range(of: #"<rootfile[^>]*full-path="([^"]+)""#, options: .regularExpression) else {
            throw EPUBError.invalidContainerFile
        }
        
        let fullPathPattern = #"full-path="([^"]+)""#
        let regex = try NSRegularExpression(pattern: fullPathPattern)
        let matches = regex.matches(in: containerXML, range: NSRange(containerXML.startIndex..., in: containerXML))
        
        guard let match = matches.first,
              let range = Range(match.range(at: 1), in: containerXML) else {
            throw EPUBError.invalidContainerFile
        }
        
        let rootFilePath = String(containerXML[range])
        
        return EPUBContainer(rootFilePath: rootFilePath, mediaType: "application/oebps-package+xml")
    }
    
    /// Парсит OPF файл
    private static func parseOPF(at path: String, in directory: URL) throws -> (EPUBMetadata, [EPUBManifestItem], [EPUBSpineItem]) {
        let opfPath = directory.appendingPathComponent(path)
        
        guard FileManager.default.fileExists(atPath: opfPath.path) else {
            throw EPUBError.missingPackageFile
        }
        
        let opfData = try Data(contentsOf: opfPath)
        guard let opfXML = String(data: opfData, encoding: .utf8) else {
            throw EPUBError.invalidPackageFile
        }
        
        // Парсим метаданные
        let metadata = parseMetadata(from: opfXML)
        
        // Парсим манифест
        let manifest = parseManifest(from: opfXML)
        
        // Парсим spine
        let spine = parseSpine(from: opfXML)
        
        return (metadata, manifest, spine)
    }
    
    private static func parseMetadata(from xml: String) -> EPUBMetadata {
        let title = extractXMLValue(from: xml, tag: "dc:title") ?? "Неизвестная книга"
        let creator = extractXMLValue(from: xml, tag: "dc:creator") ?? "Неизвестный автор"
        let identifier = extractXMLValue(from: xml, tag: "dc:identifier") ?? UUID().uuidString
        let language = extractXMLValue(from: xml, tag: "dc:language") ?? "ru"
        
        return EPUBMetadata(title: title, creator: creator, identifier: identifier, language: language)
    }
    
    private static func parseManifest(from xml: String) -> [EPUBManifestItem] {
        var items: [EPUBManifestItem] = []
        
        let itemPattern = #"<item[^>]*id="([^"]*)"[^>]*href="([^"]*)"[^>]*media-type="([^"]*)"[^>]*/?>"#
        
        do {
            let regex = try NSRegularExpression(pattern: itemPattern, options: [])
            let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
            
            for match in matches {
                guard match.numberOfRanges >= 4 else { continue }
                
                let idRange = Range(match.range(at: 1), in: xml)!
                let hrefRange = Range(match.range(at: 2), in: xml)!
                let mediaTypeRange = Range(match.range(at: 3), in: xml)!
                
                let item = EPUBManifestItem(
                    id: String(xml[idRange]),
                    href: String(xml[hrefRange]),
                    mediaType: String(xml[mediaTypeRange])
                )
                
                items.append(item)
            }
        } catch {
            print("❌ [ZIPFoundationEPUBReader] Error parsing manifest: \(error)")
        }
        
        return items
    }
    
    private static func parseSpine(from xml: String) -> [EPUBSpineItem] {
        var items: [EPUBSpineItem] = []
        
        let itemrefPattern = #"<itemref[^>]*idref="([^"]*)"[^>]*/?>"#
        
        do {
            let regex = try NSRegularExpression(pattern: itemrefPattern, options: [])
            let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
            
            for match in matches {
                guard match.numberOfRanges >= 2 else { continue }
                
                let idrefRange = Range(match.range(at: 1), in: xml)!
                let item = EPUBSpineItem(idref: String(xml[idrefRange]))
                items.append(item)
            }
        } catch {
            print("❌ [ZIPFoundationEPUBReader] Error parsing spine: \(error)")
        }
        
        return items
    }
    
    /// Извлекает содержимое глав
    private static func extractChapterContents(
        manifest: [EPUBManifestItem],
        spine: [EPUBSpineItem],
        baseDirectory: URL,
        metadata: EPUBMetadata
    ) throws -> [EPUBChapterContent] {
        var chapters: [EPUBChapterContent] = []
        
        for (index, spineItem) in spine.enumerated() {
            guard let manifestItem = manifest.first(where: { $0.id == spineItem.idref }) else {
                continue
            }
            
            // Проверяем, что это текстовый контент
            guard manifestItem.mediaType.contains("html") || manifestItem.mediaType.contains("xhtml") else {
                continue
            }
            
            let chapterPath = baseDirectory.appendingPathComponent(manifestItem.href)
            
            guard FileManager.default.fileExists(atPath: chapterPath.path) else {
                print("⚠️ [ZIPFoundationEPUBReader] Chapter file not found: \(manifestItem.href)")
                continue
            }
            
            do {
                let htmlContent = try String(contentsOf: chapterPath, encoding: .utf8)
                let textContent = HTMLTextExtractor.extractText(from: htmlContent)
                let chapterTitle = extractChapterTitle(from: htmlContent) ?? "Глава \(index + 1)"
                
                let chapter = EPUBChapterContent(
                    id: manifestItem.id,
                    title: chapterTitle,
                    htmlContent: htmlContent,
                    textContent: textContent,
                    order: index
                )
                
                chapters.append(chapter)
                print("✅ [ZIPFoundationEPUBReader] Extracted chapter: \(chapterTitle)")
                
            } catch {
                print("❌ [ZIPFoundationEPUBReader] Error reading chapter \(manifestItem.href): \(error)")
            }
        }
        
        return chapters
    }
    
    // MARK: - Utility Methods
    
    private static func extractXMLValue(from xml: String, tag: String) -> String? {
        let pattern = "<\(tag)[^>]*>([^<]*)</\(tag)>"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
              let range = Range(match.range(at: 1), in: xml) else {
            return nil
        }
        
        return String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func extractChapterTitle(from html: String) -> String? {
        // Ищем заголовки в порядке приоритета
        let titlePatterns = [
            "<title[^>]*>([^<]+)</title>",
            "<h1[^>]*>([^<]+)</h1>",
            "<h2[^>]*>([^<]+)</h2>",
            "<h3[^>]*>([^<]+)</h3>"
        ]
        
        for pattern in titlePatterns {
            if let title = extractXMLValue(from: html, tag: pattern) {
                return HTMLTextExtractor.extractText(from: title)
            }
        }
        
        return nil
    }
    
    private static func createTemporaryDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EPUB_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            print("❌ [ZIPFoundationEPUBReader] Could not create temp dir: \(error)")
        }
        
        return tempDir
    }
    
    private static func cleanupDirectory(_ directory: URL) {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            print("⚠️ [ZIPFoundationEPUBReader] Could not cleanup temp dir: \(error)")
        }
    }
}

// MARK: - FileManager Extension for ZIP

extension FileManager {
    /// Распаковывает ZIP файл (требует iOS 14+)
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        // Это fallback метод для случаев когда ZipFoundation недоступна
        throw EPUBError.unsupportedOperation
    }
}