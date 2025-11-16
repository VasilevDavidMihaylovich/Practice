//
//  FormulaRecognizerProtocol.swift
//  KFUPractice
//
//  AI Reader App
//

import Foundation
import CoreML
import Vision
import UIKit
import CoreGraphics

/// Протокол для распознавания математических формул с помощью ML
protocol FormulaRecognizerProtocol {
    /// Распознать формулу из изображения
    /// - Parameters:
    ///   - image: Изображение с формулой
    ///   - options: Опции распознавания
    /// - Returns: Результат распознавания
    func recognizeFormula(
        from image: UIImage,
        options: FormulaRecognitionOptions
    ) async throws -> FormulaRecognitionResult
    
    /// Распознать формулы из текста
    /// - Parameters:
    ///   - text: Текст, содержащий формулы
    ///   - options: Опции распознавания
    /// - Returns: Массив найденных формул
    func extractFormulas(
        from text: String,
        options: FormulaRecognitionOptions
    ) async throws -> [FormulaRecognitionResult]
    
    /// Распознать рукописную формулу
    /// - Parameters:
    ///   - strokes: Штрихи рукописного ввода
    ///   - options: Опции распознавания
    /// - Returns: Результат распознавания
    func recognizeHandwrittenFormula(
        from strokes: [DrawingStroke],
        options: FormulaRecognitionOptions
    ) async throws -> FormulaRecognitionResult
    
    /// Проверить, содержит ли изображение формулу
    /// - Parameter image: Изображение для проверки
    /// - Returns: Вероятность наличия формулы (0.0-1.0)
    func detectFormulaPresence(in image: UIImage) async throws -> Double
    
    /// Получить границы формулы на изображении
    /// - Parameter image: Изображение с формулой
    /// - Returns: Массив прямоугольников с формулами
    func locateFormulas(in image: UIImage) async throws -> [CGRect]
}

/// Опции для распознавания формул
struct FormulaRecognitionOptions {
    let outputFormat: FormulaOutputFormat  // Формат вывода
    let confidenceThreshold: Double       // Минимальный порог уверенности
    let enablePostprocessing: Bool        // Включить постобработку
    let language: String                  // Язык для распознавания текста
    let enableContextAnalysis: Bool       // Анализ контекста
    let maxProcessingTimeMs: Int         // Максимальное время обработки
    
    static let `default` = FormulaRecognitionOptions(
        outputFormat: .latex,
        confidenceThreshold: 0.7,
        enablePostprocessing: true,
        language: "en",
        enableContextAnalysis: true,
        maxProcessingTimeMs: 10000
    )
    
    static let highAccuracy = FormulaRecognitionOptions(
        outputFormat: .latex,
        confidenceThreshold: 0.9,
        enablePostprocessing: true,
        language: "en",
        enableContextAnalysis: true,
        maxProcessingTimeMs: 30000
    )
}

/// Форматы вывода распознанных формул
enum FormulaOutputFormat: String, CaseIterable {
    case latex = "latex"           // LaTeX
    case mathml = "mathml"         // MathML
    case plaintext = "plaintext"   // Обычный текст
    case asciimath = "asciimath"   // ASCII Math
    case wolfram = "wolfram"       // Wolfram Language
    
    var displayName: String {
        switch self {
        case .latex: return "LaTeX"
        case .mathml: return "MathML"
        case .plaintext: return "Текст"
        case .asciimath: return "ASCII Math"
        case .wolfram: return "Wolfram"
        }
    }
}

/// Результат распознавания формулы
struct FormulaRecognitionResult {
    let isSuccess: Bool
    let confidence: Double              // Уверенность модели (0.0-1.0)
    let recognizedText: String?         // Распознанный текст
    let boundingBox: CGRect?           // Границы формулы на изображении
    let outputFormat: FormulaOutputFormat // Формат вывода
    let processingTimeMs: Int          // Время обработки
    let errorMessage: String?          // Сообщение об ошибке
    
    // Альтернативные варианты распознавания
    let alternatives: [AlternativeRecognition] // Альтернативные результаты
    
    // Метаданные
    let detectedElements: [FormulaElement]  // Обнаруженные элементы
    let structuralAnalysis: StructuralAnalysis? // Структурный анализ
    
    init(
        isSuccess: Bool,
        confidence: Double = 0.0,
        recognizedText: String? = nil,
        boundingBox: CGRect? = nil,
        outputFormat: FormulaOutputFormat = .latex,
        processingTimeMs: Int = 0,
        errorMessage: String? = nil,
        alternatives: [AlternativeRecognition] = [],
        detectedElements: [FormulaElement] = [],
        structuralAnalysis: StructuralAnalysis? = nil
    ) {
        self.isSuccess = isSuccess
        self.confidence = confidence
        self.recognizedText = recognizedText
        self.boundingBox = boundingBox
        self.outputFormat = outputFormat
        self.processingTimeMs = processingTimeMs
        self.errorMessage = errorMessage
        self.alternatives = alternatives
        self.detectedElements = detectedElements
        self.structuralAnalysis = structuralAnalysis
    }
}

/// Альтернативный вариант распознавания
struct AlternativeRecognition {
    let text: String                   // Альтернативный текст
    let confidence: Double             // Уверенность
    let format: FormulaOutputFormat    // Формат
}

/// Элемент формулы
struct FormulaElement {
    let type: FormulaElementType       // Тип элемента
    let text: String                   // Текст элемента
    let boundingBox: CGRect           // Границы на изображении
    let confidence: Double            // Уверенность распознавания
}

/// Типы элементов формулы
enum FormulaElementType: String, CaseIterable {
    case variable = "variable"         // Переменная
    case number = "number"            // Число
    case mathOperator = "operator"    // Оператор
    case function = "function"        // Функция
    case fraction = "fraction"        // Дробь
    case superscript = "superscript"  // Надстрочный индекс
    case subscriptIndex = "subscript" // Подстрочный индекс
    case radical = "radical"          // Корень
    case integral = "integral"        // Интеграл
    case sum = "sum"                 // Сумма
    case matrix = "matrix"           // Матрица
    case bracket = "bracket"         // Скобка
    case delimiter = "delimiter"     // Разделитель
    case symbol = "symbol"           // Символ
    
    var displayName: String {
        switch self {
        case .variable: return "Переменная"
        case .number: return "Число"
        case .mathOperator: return "Оператор"
        case .function: return "Функция"
        case .fraction: return "Дробь"
        case .superscript: return "Верхний индекс"
        case .subscriptIndex: return "Нижний индекс"
        case .radical: return "Корень"
        case .integral: return "Интеграл"
        case .sum: return "Сумма"
        case .matrix: return "Матрица"
        case .bracket: return "Скобка"
        case .delimiter: return "Разделитель"
        case .symbol: return "Символ"
        }
    }
}

/// Структурный анализ формулы
struct StructuralAnalysis {
    let hasNestedStructures: Bool      // Есть ли вложенные структуры
    let complexity: Int               // Сложность (1-10)
    let mainComponents: [String]      // Основные компоненты
    let relationships: [String]       // Связи между компонентами
    let suggestedType: FormulaType?   // Предполагаемый тип формулы
}

/// Штрих для рукописного ввода
struct DrawingStroke {
    let points: [CGPoint]             // Точки штриха
    let pressure: [Float]             // Давление (если поддерживается)
    let timestamp: Date               // Время создания штриха
    let strokeWidth: CGFloat          // Толщина линии
}

/// Ошибки распознавания формул
enum FormulaRecognitionError: LocalizedError {
    case modelNotLoaded
    case invalidImage
    case noFormulasFound
    case recognitionFailed(String)
    case processingTimeout
    case insufficientMemory
    case unsupportedFormat
    case lowConfidence(Double)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "ML модель не загружена"
        case .invalidImage:
            return "Неправильное изображение"
        case .noFormulasFound:
            return "Формулы не найдены"
        case .recognitionFailed(let reason):
            return "Ошибка распознавания: \(reason)"
        case .processingTimeout:
            return "Превышено время обработки"
        case .insufficientMemory:
            return "Недостаточно памяти"
        case .unsupportedFormat:
            return "Неподдерживаемый формат"
        case .lowConfidence(let confidence):
            return "Низкая уверенность: \(Int(confidence * 100))%"
        }
    }
}

/// Протокол для постобработки результатов распознавания
protocol FormulaPostprocessorProtocol {
    /// Улучшить результат распознавания
    func enhanceRecognition(
        _ result: FormulaRecognitionResult,
        context: String?
    ) -> FormulaRecognitionResult
    
    /// Исправить типичные ошибки
    func correctCommonErrors(in text: String) -> String
    
    /// Валидировать синтаксис формулы
    func validateSyntax(of formula: String, format: FormulaOutputFormat) -> Bool
    
    /// Нормализовать формулу
    func normalize(formula: String, format: FormulaOutputFormat) -> String
}

/// Протокол для управления ML моделями
protocol FormulaMLModelManagerProtocol {
    /// Загрузить модель
    func loadModel(named modelName: String) async throws
    
    /// Выгрузить модель
    func unloadModel(named modelName: String)
    
    /// Проверить, загружена ли модель
    func isModelLoaded(named modelName: String) -> Bool
    
    /// Получить информацию о модели
    func getModelInfo(named modelName: String) -> MLModelInfo?
    
    /// Обновить модель
    func updateModel(named modelName: String) async throws
}

/// Информация о ML модели
struct MLModelInfo {
    let name: String
    let version: String
    let size: Int64                   // Размер в байтах
    let accuracy: Double             // Точность модели
    let supportedFormats: [FormulaOutputFormat]
    let lastUpdated: Date
    let isDownloaded: Bool
}