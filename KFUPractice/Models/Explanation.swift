//
//  Explanation.swift
//  KFUPractice
//
//  AI Reader App
//

import Foundation

/// Тип запроса к AI
enum AIRequestType: String, CaseIterable, Codable {
    case wordDefinition = "word_definition"      // Объяснение слова
    case textSimplification = "text_simplification" // Упрощение текста
    case formulaExplanation = "formula_explanation"  // Объяснение формулы
    case conceptExplanation = "concept_explanation"  // Объяснение концепции
    case summary = "summary"                     // Краткое резюме
    
    var displayName: String {
        switch self {
        case .wordDefinition: return "Определение слова"
        case .textSimplification: return "Упрощение текста"
        case .formulaExplanation: return "Объяснение формулы"
        case .conceptExplanation: return "Объяснение концепции"
        case .summary: return "Краткое резюме"
        }
    }
}

/// Статус обработки AI запроса
enum AIRequestStatus: String, Codable {
    case pending = "pending"        // В ожидании
    case processing = "processing"  // Обрабатывается
    case completed = "completed"    // Завершено успешно
    case failed = "failed"         // Ошибка
    case cached = "cached"         // Результат из кеша
    
    var displayName: String {
        switch self {
        case .pending: return "Ожидание"
        case .processing: return "Обработка..."
        case .completed: return "Готово"
        case .failed: return "Ошибка"
        case .cached: return "Из кеша"
        }
    }
}

/// Модель объяснения от AI
struct Explanation: Codable, Identifiable, Equatable {
    let id: UUID
    let requestType: AIRequestType
    let originalText: String           // Исходный текст для объяснения
    let explanation: String?           // Объяснение от AI
    let examples: [String]            // Примеры использования (если есть)
    let analogies: [String]           // Аналогии для лучшего понимания
    let relatedConcepts: [String]     // Связанные концепции
    let simplifiedText: String?        // Упрощенная версия текста
    
    // Метаданные запроса
    let status: AIRequestStatus
    let errorMessage: String?          // Сообщение об ошибке (если есть)
    let requestDate: Date
    let responseDate: Date?
    let processingTimeMs: Int?         // Время обработки в миллисекундах
    
    // Настройки запроса
    let language: String              // Язык ответа
    let difficultyLevel: Int          // Уровень сложности объяснения (1-5)
    let includeExamples: Bool         // Включать примеры
    let includeAnalogies: Bool        // Включать аналогии
    
    init(
        id: UUID = UUID(),
        requestType: AIRequestType,
        originalText: String,
        explanation: String? = nil,
        examples: [String] = [],
        analogies: [String] = [],
        relatedConcepts: [String] = [],
        simplifiedText: String? = nil,
        status: AIRequestStatus = .pending,
        errorMessage: String? = nil,
        requestDate: Date = Date(),
        responseDate: Date? = nil,
        processingTimeMs: Int? = nil,
        language: String = "ru",
        difficultyLevel: Int = 2,
        includeExamples: Bool = true,
        includeAnalogies: Bool = true
    ) {
        self.id = id
        self.requestType = requestType
        self.originalText = originalText
        self.explanation = explanation
        self.examples = examples
        self.analogies = analogies
        self.relatedConcepts = relatedConcepts
        self.simplifiedText = simplifiedText
        self.status = status
        self.errorMessage = errorMessage
        self.requestDate = requestDate
        self.responseDate = responseDate
        self.processingTimeMs = processingTimeMs
        self.language = language
        self.difficultyLevel = difficultyLevel
        self.includeExamples = includeExamples
        self.includeAnalogies = includeAnalogies
    }
}

// MARK: - Helper Extensions

extension Explanation {
    /// Успешно ли завершен запрос
    var isSuccessful: Bool {
        return status == .completed && explanation != nil
    }
    
    /// В процессе ли обработка
    var isProcessing: Bool {
        return status == .pending || status == .processing
    }
    
    /// Есть ли ошибка
    var hasError: Bool {
        return status == .failed
    }
    
    /// Основной контент для отображения
    var primaryContent: String {
        if let explanation = explanation {
            return explanation
        } else if let simplified = simplifiedText {
            return simplified
        } else {
            return originalText
        }
    }
    
    /// Есть ли дополнительная информация
    var hasAdditionalInfo: Bool {
        return !examples.isEmpty || !analogies.isEmpty || !relatedConcepts.isEmpty
    }
    
    /// Время обработки в удобном формате
    var formattedProcessingTime: String? {
        guard let timeMs = processingTimeMs else { return nil }
        
        if timeMs < 1000 {
            return "\(timeMs) мс"
        } else {
            let seconds = Double(timeMs) / 1000.0
            return String(format: "%.1f с", seconds)
        }
    }
    
    /// Обновление статуса с результатом
    func withResult(
        explanation: String?,
        examples: [String] = [],
        analogies: [String] = [],
        relatedConcepts: [String] = [],
        simplifiedText: String? = nil,
        processingTimeMs: Int? = nil
    ) -> Explanation {
        Explanation(
            id: self.id,
            requestType: self.requestType,
            originalText: self.originalText,
            explanation: explanation,
            examples: examples,
            analogies: analogies,
            relatedConcepts: relatedConcepts,
            simplifiedText: simplifiedText,
            status: .completed,
            errorMessage: nil,
            requestDate: self.requestDate,
            responseDate: Date(),
            processingTimeMs: processingTimeMs,
            language: self.language,
            difficultyLevel: self.difficultyLevel,
            includeExamples: self.includeExamples,
            includeAnalogies: self.includeAnalogies
        )
    }
    
    /// Обновление с ошибкой
    func withError(_ message: String) -> Explanation {
        Explanation(
            id: self.id,
            requestType: self.requestType,
            originalText: self.originalText,
            status: .failed,
            errorMessage: message,
            requestDate: self.requestDate,
            responseDate: Date(),
            language: self.language,
            difficultyLevel: self.difficultyLevel,
            includeExamples: self.includeExamples,
            includeAnalogies: self.includeAnalogies
        )
    }
}

// MARK: - Sample Data for Development

extension Explanation {
    static let sampleExplanations: [Explanation] = [
        Explanation(
            requestType: .wordDefinition,
            originalText: "квантовая",
            explanation: "Квантовая - относящийся к квантам, минимальным порциям энергии или другой физической величины, которые могут быть переданы или поглощены системой.",
            examples: [
                "квантовая физика",
                "квантовая механика",
                "квантовые эффекты"
            ],
            analogies: [
                "Как монеты - нельзя иметь половину копейки, так и энергия передается только целыми 'порциями'"
            ],
            relatedConcepts: ["фотон", "энергия", "планк"],
            status: .completed,
            responseDate: Date(),
            processingTimeMs: 1200
        ),
        Explanation(
            requestType: .formulaExplanation,
            originalText: "E = mc²",
            explanation: "Формула эквивалентности массы и энергии. Показывает, что масса может превращаться в энергию и наоборот.",
            examples: [
                "В ядерных реакциях",
                "В процессе аннигиляции"
            ],
            analogies: [
                "Как деньги в разных валютах - масса и энергия это разные 'валюты' одной сущности"
            ],
            relatedConcepts: ["относительность", "ядерная энергия", "c - скорость света"],
            status: .completed,
            responseDate: Date(),
            processingTimeMs: 1800
        )
    ]
}