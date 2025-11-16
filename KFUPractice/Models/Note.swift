//
//  Note.swift
//  KFUPractice
//
//  AI Reader App
//

import Foundation

/// Тип заметки
enum NoteType: String, CaseIterable, Codable {
    case word = "word"                    // Отдельное слово
    case phrase = "phrase"                // Фраза или предложение
    case formula = "formula"              // Математическая формула
    case paragraph = "paragraph"          // Абзац или больший фрагмент
    case custom = "custom"                // Произвольная пользовательская заметка
    
    var displayName: String {
        switch self {
        case .word: return "Слово"
        case .phrase: return "Фраза"
        case .formula: return "Формула"
        case .paragraph: return "Абзац"
        case .custom: return "Заметка"
        }
    }
    
    var systemImage: String {
        switch self {
        case .word: return "a.circle"
        case .phrase: return "text.quote"
        case .formula: return "function"
        case .paragraph: return "doc.text"
        case .custom: return "pencil.circle"
        }
    }
}

/// Модель заметки пользователя
struct Note: Codable, Identifiable, Equatable {
    let id: UUID
    let bookId: UUID
    let type: NoteType
    
    // Содержимое
    let selectedText: String              // Выделенный текст из книги
    let userText: String?                 // Пользовательский комментарий
    let aiExplanation: String?            // Объяснение от AI (если есть)
    
    // Позиция в книге
    let position: ReadingPosition         // Позиция в книге
    let pageNumber: Int                   // Номер страницы для быстрого доступа
    
    // Метаданные
    let dateCreated: Date
    let dateModified: Date
    let isBookmarked: Bool                // Закладка для важных заметок
    let tags: [String]                    // Теги для категоризации
    
    init(
        id: UUID = UUID(),
        bookId: UUID,
        type: NoteType,
        selectedText: String,
        userText: String? = nil,
        aiExplanation: String? = nil,
        position: ReadingPosition,
        pageNumber: Int,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        isBookmarked: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.bookId = bookId
        self.type = type
        self.selectedText = selectedText
        self.userText = userText
        self.aiExplanation = aiExplanation
        self.position = position
        self.pageNumber = pageNumber
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.isBookmarked = isBookmarked
        self.tags = tags
    }
}

// MARK: - Helper Extensions

extension Note {
    /// Есть ли AI объяснение
    var hasAIExplanation: Bool {
        aiExplanation != nil && !aiExplanation!.isEmpty
    }
    
    /// Есть ли пользовательский текст
    var hasUserText: Bool {
        userText != nil && !userText!.isEmpty
    }
    
    /// Основной контент для отображения
    var primaryContent: String {
        if hasUserText {
            return userText!
        } else if hasAIExplanation {
            return aiExplanation!
        } else {
            return selectedText
        }
    }
    
    /// Краткий превью контента (первые 100 символов)
    var previewText: String {
        let content = primaryContent
        return content.count <= 100 ? content : String(content.prefix(100)) + "..."
    }
    
    /// Формат даты для отображения
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: dateCreated)
    }
    
    /// Обновление заметки с новыми данными
    func updated(
        userText: String? = nil,
        aiExplanation: String? = nil,
        isBookmarked: Bool? = nil,
        tags: [String]? = nil
    ) -> Note {
        Note(
            id: self.id,
            bookId: self.bookId,
            type: self.type,
            selectedText: self.selectedText,
            userText: userText ?? self.userText,
            aiExplanation: aiExplanation ?? self.aiExplanation,
            position: self.position,
            pageNumber: self.pageNumber,
            dateCreated: self.dateCreated,
            dateModified: Date(),
            isBookmarked: isBookmarked ?? self.isBookmarked,
            tags: tags ?? self.tags
        )
    }
}

// MARK: - Search and Filtering

extension Note {
    /// Поиск по тексту заметки
    func matches(searchQuery: String) -> Bool {
        guard !searchQuery.isEmpty else { return true }
        
        let query = searchQuery.lowercased()
        
        return selectedText.lowercased().contains(query) ||
               (userText?.lowercased().contains(query) ?? false) ||
               (aiExplanation?.lowercased().contains(query) ?? false) ||
               tags.contains { $0.lowercased().contains(query) }
    }
    
    /// Фильтрация по типу заметки
    func matches(type: NoteType) -> Bool {
        return self.type == type
    }
    
    /// Фильтрация по тегу
    func hasTag(_ tag: String) -> Bool {
        return tags.contains(tag.lowercased())
    }
}

// MARK: - Sample Data for Development

extension Note {
    static func sampleNotes(for bookId: UUID) -> [Note] {
        let samplePosition = ReadingPosition(
            pageNumber: 15,
            progressPercentage: 0.25
        )
        
        return [
            Note(
                bookId: bookId,
                type: .word,
                selectedText: "квантовая",
                aiExplanation: "Относящийся к квантовой механике - разделу физики, изучающему поведение материи и энергии на атомном и субатомном уровне.",
                position: samplePosition,
                pageNumber: 15,
                tags: ["физика", "термин"]
            ),
            Note(
                bookId: bookId,
                type: .formula,
                selectedText: "E = mc²",
                userText: "Знаменитая формула Эйнштейна для эквивалентности массы и энергии",
                aiExplanation: "Формула показывает, что масса и энергия взаимозаменяемы. E - энергия, m - масса, c - скорость света.",
                position: samplePosition,
                pageNumber: 16,
                isBookmarked: true,
                tags: ["физика", "эйнштейн", "формула"]
            ),
            Note(
                bookId: bookId,
                type: .phrase,
                selectedText: "принцип неопределенности Гейзенберга",
                aiExplanation: "Фундаментальное ограничение квантовой механики: невозможно одновременно точно знать импульс и положение частицы.",
                position: samplePosition,
                pageNumber: 18,
                tags: ["квантовая механика", "принцип"]
            )
        ]
    }
}