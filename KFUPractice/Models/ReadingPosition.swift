//
//  ReadingPosition.swift
//  KFUPractice
//
//  AI Reader App
//

import Foundation

/// Позиция в книге для отслеживания прогресса чтения
struct ReadingPosition: Codable, Equatable {
    /// Номер текущей страницы (начинается с 0)
    let pageNumber: Int
    
    /// Смещение в пикселях или процент от начала страницы
    let offset: Double
    
    /// Номер главы (если доступен)
    let chapterNumber: Int?
    
    /// Название главы (если доступно)
    let chapterTitle: String?
    
    /// Процент прочитанной книги (0.0 - 1.0)
    let progressPercentage: Double
    
    /// Время последнего обновления позиции
    let timestamp: Date
    
    init(
        pageNumber: Int,
        offset: Double = 0.0,
        chapterNumber: Int? = nil,
        chapterTitle: String? = nil,
        progressPercentage: Double,
        timestamp: Date = Date()
    ) {
        self.pageNumber = pageNumber
        self.offset = offset
        self.chapterNumber = chapterNumber
        self.chapterTitle = chapterTitle
        self.progressPercentage = progressPercentage
        self.timestamp = timestamp
    }
}

// MARK: - Helper Extensions

extension ReadingPosition {
    /// Отображаемая информация о позиции
    var displayInfo: String {
        var info = "Страница \(pageNumber + 1)"
        
        if let chapterTitle = chapterTitle {
            info += " • \(chapterTitle)"
        } else if let chapterNumber = chapterNumber {
            info += " • Глава \(chapterNumber + 1)"
        }
        
        return info
    }
    
    /// Процент прогресса в виде строки
    var progressText: String {
        let percentage = Int(progressPercentage * 100)
        return "\(percentage)%"
    }
    
    /// Создание начальной позиции для новой книги
    static func initial() -> ReadingPosition {
        ReadingPosition(
            pageNumber: 0,
            offset: 0.0,
            progressPercentage: 0.0
        )
    }
    
    /// Обновление позиции с новыми данными
    func updated(
        pageNumber: Int? = nil,
        offset: Double? = nil,
        chapterNumber: Int? = nil,
        chapterTitle: String? = nil,
        progressPercentage: Double? = nil
    ) -> ReadingPosition {
        ReadingPosition(
            pageNumber: pageNumber ?? self.pageNumber,
            offset: offset ?? self.offset,
            chapterNumber: chapterNumber ?? self.chapterNumber,
            chapterTitle: chapterTitle ?? self.chapterTitle,
            progressPercentage: progressPercentage ?? self.progressPercentage,
            timestamp: Date()
        )
    }
}