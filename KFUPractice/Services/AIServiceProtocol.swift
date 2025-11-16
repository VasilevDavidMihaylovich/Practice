//
//  AIServiceProtocol.swift
//  KFUPractice
//
//  AI Reader App
//

import Foundation
import Combine

/// Протокол для интеграции с AI сервисами (Gemini API)
protocol AIServiceProtocol {
    /// Объяснить значение слова простым языком
    /// - Parameters:
    ///   - word: Слово для объяснения
    ///   - context: Контекст, в котором встретилось слово
    ///   - language: Язык объяснения
    /// - Returns: Publisher с результатом объяснения
    func explainWord(
        _ word: String,
        context: String?,
        language: String
    ) async throws -> Explanation
    
    /// Упростить сложное предложение или абзац
    /// - Parameters:
    ///   - text: Текст для упрощения
    ///   - difficultyLevel: Уровень сложности результата (1-5)
    ///   - language: Язык объяснения
    /// - Returns: Publisher с упрощенным текстом
    func simplifyText(
        _ text: String,
        difficultyLevel: Int,
        language: String
    ) async throws -> Explanation
    
    /// Объяснить математическую формулу
    /// - Parameters:
    ///   - formula: Формула для объяснения
    ///   - includeExamples: Включить примеры использования
    ///   - language: Язык объяснения
    /// - Returns: Publisher с объяснением формулы
    func explainFormula(
        _ formula: Formula,
        includeExamples: Bool,
        language: String
    ) async throws -> Explanation
    
    /// Создать краткий конспект текста
    /// - Parameters:
    ///   - text: Текст для конспекта
    ///   - maxLength: Максимальная длина конспекта
    ///   - language: Язык конспекта
    /// - Returns: Publisher с конспектом
    func summarizeText(
        _ text: String,
        maxLength: Int?,
        language: String
    ) async throws -> Explanation
    
    /// Получить связанные концепции для термина
    /// - Parameters:
    ///   - term: Термин для поиска связанных концепций
    ///   - subject: Предметная область (физика, математика, etc.)
    ///   - language: Язык ответа
    /// - Returns: Publisher со списком связанных концепций
    func getRelatedConcepts(
        for term: String,
        subject: String?,
        language: String
    ) async throws -> [String]
}

/// Конфигурация для AI запросов
struct AIRequestConfig {
    let maxTokens: Int                   // Максимальное количество токенов
    let temperature: Double              // Температура для генерации (0.0-1.0)
    let timeoutSeconds: TimeInterval     // Таймаут запроса
    let retryAttempts: Int              // Количество попыток повтора
    let cacheEnabled: Bool              // Включено ли кеширование
    let language: String                // Язык по умолчанию
    
    static let `default` = AIRequestConfig(
        maxTokens: 1000,
        temperature: 0.3,
        timeoutSeconds: 30.0,
        retryAttempts: 3,
        cacheEnabled: true,
        language: "ru"
    )
}

/// Ошибки AI сервиса
enum AIServiceError: LocalizedError, Hashable, Equatable {
    case networkError(Error)
    case invalidAPIKey
    case rateLimitExceeded
    case contentFiltered
    case invalidRequest(String)
    case responseParsingError
    case timeout
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .invalidAPIKey:
            return "Недействительный API ключ"
        case .rateLimitExceeded:
            return "Превышен лимит запросов"
        case .contentFiltered:
            return "Контент заблокирован фильтрами"
        case .invalidRequest(let message):
            return "Неправильный запрос: \(message)"
        case .responseParsingError:
            return "Ошибка обработки ответа"
        case .timeout:
            return "Превышено время ожидания"
        case .unknown(let message):
            return "Неизвестная ошибка: \(message)"
        }
    }
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .networkError(let error):
            hasher.combine("networkError")
            hasher.combine(error.localizedDescription)
        case .invalidAPIKey:
            hasher.combine("invalidAPIKey")
        case .rateLimitExceeded:
            hasher.combine("rateLimitExceeded")
        case .contentFiltered:
            hasher.combine("contentFiltered")
        case .invalidRequest(let message):
            hasher.combine("invalidRequest")
            hasher.combine(message)
        case .responseParsingError:
            hasher.combine("responseParsingError")
        case .timeout:
            hasher.combine("timeout")
        case .unknown(let message):
            hasher.combine("unknown")
            hasher.combine(message)
        }
    }
    
    static func == (lhs: AIServiceError, rhs: AIServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.invalidAPIKey, .invalidAPIKey),
             (.rateLimitExceeded, .rateLimitExceeded),
             (.contentFiltered, .contentFiltered),
             (.responseParsingError, .responseParsingError),
             (.timeout, .timeout):
            return true
        case (.invalidRequest(let lhsMessage), .invalidRequest(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.unknown(let lhsMessage), .unknown(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

/// Модель запроса к AI для объяснения текста
struct TextExplanationRequest {
    let text: String
    let requestType: AIRequestType
    let context: String?
    let difficultyLevel: Int             // 1-5
    let includeExamples: Bool
    let includeAnalogies: Bool
    let includeRelatedConcepts: Bool
    let maxLength: Int?
    let language: String
    
    init(
        text: String,
        requestType: AIRequestType,
        context: String? = nil,
        difficultyLevel: Int = 2,
        includeExamples: Bool = true,
        includeAnalogies: Bool = true,
        includeRelatedConcepts: Bool = true,
        maxLength: Int? = nil,
        language: String = "ru"
    ) {
        self.text = text
        self.requestType = requestType
        self.context = context
        self.difficultyLevel = difficultyLevel
        self.includeExamples = includeExamples
        self.includeAnalogies = includeAnalogies
        self.includeRelatedConcepts = includeRelatedConcepts
        self.maxLength = maxLength
        self.language = language
    }
}

/// Модель запроса к AI для объяснения формулы
struct FormulaExplanationRequest {
    let formula: Formula
    let requestType: AIRequestType
    let includeDerivation: Bool          // Включить вывод формулы
    let includeApplications: Bool        // Включить применения
    let includeExamples: Bool           // Включить примеры
    let difficultyLevel: Int            // 1-5
    let language: String
    
    init(
        formula: Formula,
        requestType: AIRequestType = .formulaExplanation,
        includeDerivation: Bool = false,
        includeApplications: Bool = true,
        includeExamples: Bool = true,
        difficultyLevel: Int = 2,
        language: String = "ru"
    ) {
        self.formula = formula
        self.requestType = requestType
        self.includeDerivation = includeDerivation
        self.includeApplications = includeApplications
        self.includeExamples = includeExamples
        self.difficultyLevel = difficultyLevel
        self.language = language
    }
}

// MARK: - Cache Protocol

/// Протокол для кеширования AI ответов
protocol AIResponseCacheProtocol {
    /// Получить кешированный ответ
    func getCachedResponse(for key: String) -> Explanation?
    
    /// Сохранить ответ в кеш
    func cacheResponse(_ explanation: Explanation, for key: String)
    
    /// Очистить весь кеш
    func clearCache()
    
    /// Очистить устаревшие записи
    func clearExpiredEntries()
    
    /// Размер кеша в байтах
    var cacheSize: Int64 { get }
}

// MARK: - Analytics Protocol

/// Протокол для аналитики использования AI
protocol AIAnalyticsProtocol {
    /// Записать успешный запрос
    func recordSuccessfulRequest(
        type: AIRequestType,
        processingTimeMs: Int,
        tokensUsed: Int
    )
    
    /// Записать неудачный запрос
    func recordFailedRequest(
        type: AIRequestType,
        error: AIServiceError
    )
    
    /// Получить статистику использования
    func getUsageStatistics() -> AIUsageStatistics
}

/// Статистика использования AI
struct AIUsageStatistics {
    let totalRequests: Int
    let successfulRequests: Int
    let failedRequests: Int
    let averageResponseTimeMs: Double
    let totalTokensUsed: Int
    let requestsByType: [AIRequestType: Int]
    let mostCommonErrors: [AIServiceError: Int]
}