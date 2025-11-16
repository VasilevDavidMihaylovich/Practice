//
//  SimpleEPUBReader.swift
//  KFUPractice
//
//  Простой EPUB ридер для извлечения текста из EPUB файлов
//

import Foundation

/// Простой EPUB ридер для извлечения текстового содержимого
class SimpleEPUBReader {
    
    /// Извлекает текстовое содержимое из EPUB файла
    /// - Parameter epubURL: URL к EPUB файлу
    /// - Returns: Массив строк с содержимым глав
    /// - Throws: EPUBError при ошибках чтения
    static func extractTextContent(from epubURL: URL) throws -> [String] {
        print("📚 [SimpleEPUBReader] Начинаем извлечение текста из: \(epubURL.lastPathComponent)")
        
        // Читаем EPUB как данные
        let epubData = try Data(contentsOf: epubURL)
        print("📊 [SimpleEPUBReader] Размер EPUB файла: \(epubData.count) байт")
        
        // Проверяем сигнатуру ZIP
        guard epubData.count >= 4 else {
            throw EPUBError.invalidArchive
        }
        
        let zipSignature = Data([0x50, 0x4B]) // "PK"
        let fileHeader = epubData.prefix(2)
        
        guard fileHeader == zipSignature else {
            print("❌ [SimpleEPUBReader] Не является ZIP архивом")
            throw EPUBError.invalidArchive
        }
        
        print("✅ [SimpleEPUBReader] ZIP сигнатура найдена, ищем HTML/XHTML файлы...")
        
        // Ищем HTML/XHTML контент в ZIP данных
        let textChapters = try extractHTMLContent(from: epubData)
        
        if textChapters.isEmpty {
            print("⚠️ [SimpleEPUBReader] Не найдено HTML содержимого, создаем базовую главу")
            return ["Извлеченное содержимое из EPUB файла размером \(ByteCountFormatter().string(fromByteCount: Int64(epubData.count))).\n\nК сожалению, не удалось извлечь текстовое содержимое автоматически. В будущих версиях будет добавлена более продвинутая обработка EPUB файлов."]
        }
        
        print("🎉 [SimpleEPUBReader] Извлечено \(textChapters.count) глав")
        return textChapters
    }
    
    /// Извлекает HTML контент из ZIP данных
    private static func extractHTMLContent(from zipData: Data) throws -> [String] {
        var chapters: [String] = []
        
        // Поиск HTML/XHTML файлов в ZIP архиве
        // Простой метод: ищем паттерны HTML тегов в данных
        
        let htmlPatterns = [
            "<html",
            "<body>",
            "<p>", 
            "<h1>",
            "<h2>",
            "<div>",
            "<!DOCTYPE html"
        ]
        
        // Конвертируем данные в строку для поиска
        if let zipString = String(data: zipData, encoding: .utf8) {
            print("🔍 [SimpleEPUBReader] Конвертировали ZIP в UTF-8 строку")
            
            // Ищем HTML контент
            if htmlPatterns.contains(where: { zipString.contains($0) }) {
                print("✅ [SimpleEPUBReader] Найдены HTML теги в архиве")
                
                // Пытаемся извлечь текст между <body> тегами
                let bodyContent = extractBodyContent(from: zipString)
                if !bodyContent.isEmpty {
                    chapters.append(contentsOf: bodyContent)
                }
            }
        } else {
            print("⚠️ [SimpleEPUBReader] Не удалось конвертировать в UTF-8, пробуем другие кодировки")
            
            // Пробуем другие кодировки
            for encoding in [String.Encoding.ascii, .windowsCP1252, .isoLatin1] {
                if let zipString = String(data: zipData, encoding: encoding) {
                    print("✅ [SimpleEPUBReader] Успешно конвертировали с кодировкой: \(encoding)")
                    
                    let bodyContent = extractBodyContent(from: zipString)
                    if !bodyContent.isEmpty {
                        chapters.append(contentsOf: bodyContent)
                        break
                    }
                }
            }
        }
        
        // Если ничего не найдено, пытаемся найти любой читаемый текст
        if chapters.isEmpty {
            chapters = extractAnyReadableText(from: zipData)
        }
        
        return chapters
    }
    
    /// Извлекает содержимое между <body> тегами
    private static func extractBodyContent(from htmlString: String) -> [String] {
        var chapters: [String] = []
        
        // Ищем все <body>...</body> блоки
        let bodyPattern = #"<body[^>]*>(.*?)</body>"#
        
        do {
            let regex = try NSRegularExpression(pattern: bodyPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            
            print("🔍 [SimpleEPUBReader] Найдено \(matches.count) <body> блоков")
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: htmlString) {
                    let bodyContent = String(htmlString[range])
                    let cleanText = HTMLTextExtractor.extractText(from: bodyContent)
                    
                    if !cleanText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        chapters.append(cleanText)
                        print("✅ [SimpleEPUBReader] Извлечена глава длиной \(cleanText.count) символов")
                    }
                }
            }
        } catch {
            print("❌ [SimpleEPUBReader] Ошибка regex: \(error)")
        }
        
        // Если не найдены <body> теги, ищем <p> теги
        if chapters.isEmpty {
            chapters = extractParagraphs(from: htmlString)
        }
        
        return chapters
    }
    
    /// Извлекает параграфы из HTML
    private static func extractParagraphs(from htmlString: String) -> [String] {
        var chapters: [String] = []
        
        // Ищем все <p>...</p> блоки
        let pPattern = #"<p[^>]*>(.*?)</p>"#
        
        do {
            let regex = try NSRegularExpression(pattern: pPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            
            print("🔍 [SimpleEPUBReader] Найдено \(matches.count) <p> блоков")
            
            var allParagraphs = ""
            for match in matches {
                if let range = Range(match.range(at: 1), in: htmlString) {
                    let pContent = String(htmlString[range])
                    let cleanText = HTMLTextExtractor.extractText(from: pContent)
                    
                    if !cleanText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        allParagraphs += cleanText + "\n\n"
                    }
                }
            }
            
            if !allParagraphs.isEmpty {
                chapters.append(allParagraphs)
                print("✅ [SimpleEPUBReader] Объединено \(matches.count) параграфов")
            }
        } catch {
            print("❌ [SimpleEPUBReader] Ошибка regex для параграфов: \(error)")
        }
        
        return chapters
    }
    
    /// Извлекает любой читаемый текст из данных
    private static func extractAnyReadableText(from zipData: Data) -> [String] {
        print("🔍 [SimpleEPUBReader] Поиск любого читаемого текста...")
        
        // Ищем текстовые файлы в ZIP
        let textPatterns = [
            "chapter",
            "content",
            ".html",
            ".xhtml",
            ".txt"
        ]
        
        if let dataString = String(data: zipData, encoding: .utf8) ?? String(data: zipData, encoding: .ascii) {
            
            // Ищем участки с большим количеством читаемого текста
            let lines = dataString.components(separatedBy: .newlines)
            var textChunks: [String] = []
            var currentChunk = ""
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Пропускаем очень короткие строки и строки с много специальных символов
                if trimmedLine.count > 20 && isReadableText(trimmedLine) {
                    currentChunk += trimmedLine + "\n"
                } else if !currentChunk.isEmpty {
                    // Завершаем текущий чанк
                    if currentChunk.count > 100 {
                        textChunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    currentChunk = ""
                }
            }
            
            // Добавляем последний чанк
            if !currentChunk.isEmpty && currentChunk.count > 100 {
                textChunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            
            if !textChunks.isEmpty {
                print("✅ [SimpleEPUBReader] Найдено \(textChunks.count) фрагментов читаемого текста")
                return textChunks
            }
        }
        
        return []
    }
    
    /// Проверяет, является ли строка читаемым текстом
    private static func isReadableText(_ text: String) -> Bool {
        let russianPattern = #"[а-яё]"#
        let englishPattern = #"[a-z]"#
        let numberPattern = #"\d"#
        
        do {
            let russianRegex = try NSRegularExpression(pattern: russianPattern, options: .caseInsensitive)
            let englishRegex = try NSRegularExpression(pattern: englishPattern, options: .caseInsensitive)
            let numberRegex = try NSRegularExpression(pattern: numberPattern, options: [])
            
            let range = NSRange(text.startIndex..., in: text)
            
            let russianMatches = russianRegex.numberOfMatches(in: text, range: range)
            let englishMatches = englishRegex.numberOfMatches(in: text, range: range)
            let numberMatches = numberRegex.numberOfMatches(in: text, range: range)
            
            let totalTextMatches = russianMatches + englishMatches + numberMatches
            let textRatio = Double(totalTextMatches) / Double(text.count)
            
            // Считаем текст читаемым, если больше 40% символов - буквы/цифры
            return textRatio > 0.4 && !text.contains("PK") // исключаем ZIP заголовки
            
        } catch {
            return false
        }
    }
}