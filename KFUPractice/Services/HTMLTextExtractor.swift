//
//  HTMLTextExtractor.swift
//  KFUPractice
//
//  AI Reader App - HTML Text Extraction Utilities
//

import Foundation

/// Утилита для извлечения чистого текста из HTML
struct HTMLTextExtractor {
    
    /// Извлекает чистый текст из HTML строки
    /// - Parameter html: HTML строка
    /// - Returns: Чистый текст без HTML тегов
    static func extractText(from html: String) -> String {
        var text = html
        
        // Удаляем скрипты и стили полностью
        text = removeElementsWithContent(from: text, elements: ["script", "style"])
        
        // Заменяем блочные элементы на переносы строк
        text = replaceBlockElements(in: text)
        
        // Заменяем br на переносы строк
        text = text.replacingOccurrences(
            of: "<br\\s*/??>",
            with: "\n",
            options: .regularExpression,
            range: nil
        )
        
        // Удаляем все HTML теги
        text = removeAllHTMLTags(from: text)
        
        // Декодируем HTML entities
        text = decodeHTMLEntities(in: text)
        
        // Нормализуем пробелы и переносы
        text = normalizeWhitespace(in: text)
        
        return text
    }
    
    /// Извлекает заголовок из HTML
    /// - Parameter html: HTML строка
    /// - Returns: Заголовок главы или nil
    static func extractTitle(from html: String) -> String? {
        // Ищем title в head
        if let titleMatch = html.range(of: "<title[^>]*>([^<]+)</title>", options: .regularExpression) {
            let titleHTML = String(html[titleMatch])
            let title = extractText(from: titleHTML)
            if !title.isEmpty {
                return title.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Ищем первый h1-h6 заголовок
        let headerPattern = "<h[1-6][^>]*>([^<]+)</h[1-6]>"
        if let headerMatch = html.range(of: headerPattern, options: .regularExpression) {
            let headerHTML = String(html[headerMatch])
            let title = extractText(from: headerHTML)
            if !title.isEmpty {
                return title.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    /// Извлекает метаданные из HTML
    /// - Parameter html: HTML строка
    /// - Returns: Словарь с метаданными
    static func extractMetadata(from html: String) -> [String: String] {
        var metadata: [String: String] = [:]
        
        let metaPattern = "<meta\\s+([^>]*)>"
        let regex = try? NSRegularExpression(pattern: metaPattern, options: .caseInsensitive)
        let nsString = html as NSString
        let results = regex?.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        results?.forEach { match in
            let metaTag = nsString.substring(with: match.range)
            
            // Извлекаем name и content
            if let nameMatch = metaTag.range(of: "name\\s*=\\s*[\"']([^\"']*)[\"']", options: .regularExpression),
               let contentMatch = metaTag.range(of: "content\\s*=\\s*[\"']([^\"']*)[\"']", options: .regularExpression) {
                let name = String(metaTag[nameMatch]).replacingOccurrences(of: "name=", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
                let content = String(metaTag[contentMatch]).replacingOccurrences(of: "content=", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
                metadata[name] = content
            }
        }
        
        return metadata
    }
    
    // MARK: - Private Methods
    
    /// Удаляет элементы вместе с их содержимым
    private static func removeElementsWithContent(from html: String, elements: [String]) -> String {
        var result = html
        
        for element in elements {
            let pattern = "<\(element)[^>]*>.*?</\(element)>"
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return result
    }
    
    /// Заменяет блочные элементы на переносы строк
    private static func replaceBlockElements(in html: String) -> String {
        let blockElements = [
            "p", "div", "section", "article", "header", "footer", "main",
            "h1", "h2", "h3", "h4", "h5", "h6",
            "ul", "ol", "li", "dl", "dt", "dd",
            "blockquote", "pre", "address",
            "table", "tr", "td", "th", "thead", "tbody", "tfoot"
        ]
        
        var result = html
        
        for element in blockElements {
            // Заменяем открывающие теги
            result = result.replacingOccurrences(
                of: "<\(element)[^>]*>",
                with: "\n",
                options: [.regularExpression, .caseInsensitive]
            )
            
            // Заменяем закрывающие теги
            result = result.replacingOccurrences(
                of: "</\(element)>",
                with: "\n",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return result
    }
    
    /// Удаляет все HTML теги
    private static func removeAllHTMLTags(from html: String) -> String {
        return html.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
    }
    
    /// Декодирует HTML entities
    private static func decodeHTMLEntities(in text: String) -> String {
        var result = text
        
        let entities = [
            "&lt;": "<",
            "&gt;": ">",
            "&amp;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™",
            "&hellip;": "…",
            "&mdash;": "—",
            "&ndash;": "–",
            "&lsquo;": "'",
            "&rsquo;": "'",
            "&ldquo;": "\"",
            "&rdquo;": "\"",
            "&times;": "×",
            "&divide;": "÷"
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // Декодируем численные entities
        let numericPattern = "&#(\\d+);"
        let regex = try? NSRegularExpression(pattern: numericPattern, options: [])
        let nsString = result as NSString
        let matches = regex?.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches.reversed() {
            if match.numberOfRanges > 1 {
                let numberRange = match.range(at: 1)
                let numberString = nsString.substring(with: numberRange)
                if let number = Int(numberString),
                   let unicodeScalar = UnicodeScalar(number) {
                    let character = String(Character(unicodeScalar))
                    result = nsString.replacingCharacters(in: match.range, with: character)
                }
            }
        }
        
        return result
    }
    
    /// Нормализует пробелы и переносы строк
    private static func normalizeWhitespace(in text: String) -> String {
        var result = text
        
        // Убираем множественные пробелы
        result = result.replacingOccurrences(
            of: " +",
            with: " ",
            options: .regularExpression
        )
        
        // Убираем пробелы в начале и конце строк
        let lines = result.components(separatedBy: .newlines)
        let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        result = trimmedLines.joined(separator: "\n")
        
        // Убираем множественные переносы строк
        result = result.replacingOccurrences(
            of: "\n\n\n+",
            with: "\n\n",
            options: .regularExpression
        )
        
        // Убираем переносы в начале и конце
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }
}

/// Конфигурация для извлечения текста
struct HTMLExtractionOptions {
    let preserveLineBreaks: Bool
    let preserveParagraphs: Bool
    let extractLinks: Bool
    let extractImages: Bool
    let maxTextLength: Int?
    
    static let `default` = HTMLExtractionOptions(
        preserveLineBreaks: true,
        preserveParagraphs: true,
        extractLinks: false,
        extractImages: false,
        maxTextLength: nil
    )
    
    static let minimal = HTMLExtractionOptions(
        preserveLineBreaks: false,
        preserveParagraphs: false,
        extractLinks: false,
        extractImages: false,
        maxTextLength: nil
    )
}