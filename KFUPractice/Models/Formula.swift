//
//  Formula.swift
//  KFUPractice
//
//  AI Reader App
//

import Foundation
import CoreGraphics

/// Тип математической формулы
enum FormulaType: String, CaseIterable, Codable {
    case algebraic = "algebraic"         // Алгебраическое выражение
    case differential = "differential"    // Дифференциальное уравнение
    case integral = "integral"           // Интегральное выражение
    case function = "function"           // Функция
    case equation = "equation"           // Уравнение
    case inequality = "inequality"       // Неравенство
    case matrix = "matrix"              // Матричное выражение
    case vector = "vector"              // Векторное выражение
    case trigonometric = "trigonometric" // Тригонометрическое выражение
    case logarithmic = "logarithmic"     // Логарифмическое выражение
    case other = "other"                // Другое
    
    var displayName: String {
        switch self {
        case .algebraic: return "Алгебра"
        case .differential: return "Диф. уравнение"
        case .integral: return "Интеграл"
        case .function: return "Функция"
        case .equation: return "Уравнение"
        case .inequality: return "Неравенство"
        case .matrix: return "Матрица"
        case .vector: return "Вектор"
        case .trigonometric: return "Тригонометрия"
        case .logarithmic: return "Логарифм"
        case .other: return "Другое"
        }
    }
    
    var systemImage: String {
        switch self {
        case .algebraic: return "x.squareroot"
        case .differential: return "function"
        case .integral: return "integral"
        case .function: return "f.cursive"
        case .equation: return "equal.circle"
        case .inequality: return "greaterthan.circle"
        case .matrix: return "grid.circle"
        case .vector: return "arrow.up.right"
        case .trigonometric: return "triangle"
        case .logarithmic: return "log"
        case .other: return "questionmark.circle"
        }
    }
}

/// Результат анализа формулы
struct FormulaAnalysisResult: Codable, Equatable {
    let variables: [String]              // Переменные в формуле
    let constants: [String]              // Константы
    let functions: [String]              // Функции (sin, cos, log, etc.)
    let operators: [String]              // Операторы (+, -, *, /, ^, etc.)
    let domain: String?                  // Область определения
    let range: String?                   // Область значений
    let complexity: Int                  // Сложность (1-5)
    
    init(
        variables: [String] = [],
        constants: [String] = [],
        functions: [String] = [],
        operators: [String] = [],
        domain: String? = nil,
        range: String? = nil,
        complexity: Int = 1
    ) {
        self.variables = variables
        self.constants = constants
        self.functions = functions
        self.operators = operators
        self.domain = domain
        self.range = range
        self.complexity = complexity
    }
}

/// Результат решения математического выражения
struct MathSolutionResult: Codable, Equatable {
    let isSuccess: Bool
    let solution: String?                // Аналитическое решение
    let numericValue: Double?            // Численное значение
    let steps: [String]                  // Шаги решения
    let plotPoints: [CGPoint]           // Точки для построения графика
    let errorMessage: String?            // Сообщение об ошибке
    let solutionMethod: String?          // Метод решения
    
    init(
        isSuccess: Bool,
        solution: String? = nil,
        numericValue: Double? = nil,
        steps: [String] = [],
        plotPoints: [CGPoint] = [],
        errorMessage: String? = nil,
        solutionMethod: String? = nil
    ) {
        self.isSuccess = isSuccess
        self.solution = solution
        self.numericValue = numericValue
        self.steps = steps
        self.plotPoints = plotPoints
        self.errorMessage = errorMessage
        self.solutionMethod = solutionMethod
    }
}

/// Модель математической формулы
struct Formula: Codable, Identifiable, Equatable {
    let id: UUID
    let originalText: String             // Исходный текст формулы
    let latexRepresentation: String?     // LaTeX представление
    let mathMLRepresentation: String?    // MathML представление
    let type: FormulaType               // Тип формулы
    let analysisResult: FormulaAnalysisResult? // Результат анализа
    let solutionResult: MathSolutionResult?    // Результат решения
    
    // Метаданные
    let dateCreated: Date
    let sourceBookId: UUID?              // Книга, откуда взята формула
    let sourcePosition: ReadingPosition? // Позиция в книге
    
    // AI объяснение
    let aiExplanation: String?           // Объяснение формулы от AI
    let userNotes: String?               // Заметки пользователя
    let tags: [String]                   // Теги для категоризации
    
    init(
        id: UUID = UUID(),
        originalText: String,
        latexRepresentation: String? = nil,
        mathMLRepresentation: String? = nil,
        type: FormulaType = .other,
        analysisResult: FormulaAnalysisResult? = nil,
        solutionResult: MathSolutionResult? = nil,
        dateCreated: Date = Date(),
        sourceBookId: UUID? = nil,
        sourcePosition: ReadingPosition? = nil,
        aiExplanation: String? = nil,
        userNotes: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.originalText = originalText
        self.latexRepresentation = latexRepresentation
        self.mathMLRepresentation = mathMLRepresentation
        self.type = type
        self.analysisResult = analysisResult
        self.solutionResult = solutionResult
        self.dateCreated = dateCreated
        self.sourceBookId = sourceBookId
        self.sourcePosition = sourcePosition
        self.aiExplanation = aiExplanation
        self.userNotes = userNotes
        self.tags = tags
    }
}

// MARK: - Helper Extensions

extension Formula {
    /// Есть ли результат анализа
    var isAnalyzed: Bool {
        return analysisResult != nil
    }
    
    /// Есть ли решение
    var isSolved: Bool {
        return solutionResult?.isSuccess == true
    }
    
    /// Есть ли точки для графика
    var hasPlotData: Bool {
        return !(solutionResult?.plotPoints.isEmpty ?? true)
    }
    
    /// Есть ли AI объяснение
    var hasAIExplanation: Bool {
        return aiExplanation != nil && !aiExplanation!.isEmpty
    }
    
    /// Лучшее представление формулы для отображения
    var bestRepresentation: String {
        return latexRepresentation ?? mathMLRepresentation ?? originalText
    }
    
    /// Краткая информация о формуле
    var summary: String {
        var parts: [String] = []
        
        if let analysis = analysisResult {
            if !analysis.variables.isEmpty {
                parts.append("Переменные: \(analysis.variables.joined(separator: ", "))")
            }
            if !analysis.functions.isEmpty {
                parts.append("Функции: \(analysis.functions.joined(separator: ", "))")
            }
        }
        
        return parts.isEmpty ? type.displayName : parts.joined(separator: " • ")
    }
    
    /// Обновление с результатом анализа
    func withAnalysis(_ analysis: FormulaAnalysisResult) -> Formula {
        Formula(
            id: self.id,
            originalText: self.originalText,
            latexRepresentation: self.latexRepresentation,
            mathMLRepresentation: self.mathMLRepresentation,
            type: self.type,
            analysisResult: analysis,
            solutionResult: self.solutionResult,
            dateCreated: self.dateCreated,
            sourceBookId: self.sourceBookId,
            sourcePosition: self.sourcePosition,
            aiExplanation: self.aiExplanation,
            userNotes: self.userNotes,
            tags: self.tags
        )
    }
    
    /// Обновление с результатом решения
    func withSolution(_ solution: MathSolutionResult) -> Formula {
        Formula(
            id: self.id,
            originalText: self.originalText,
            latexRepresentation: self.latexRepresentation,
            mathMLRepresentation: self.mathMLRepresentation,
            type: self.type,
            analysisResult: self.analysisResult,
            solutionResult: solution,
            dateCreated: self.dateCreated,
            sourceBookId: self.sourceBookId,
            sourcePosition: self.sourcePosition,
            aiExplanation: self.aiExplanation,
            userNotes: self.userNotes,
            tags: self.tags
        )
    }
    
    /// Обновление с AI объяснением
    func withAIExplanation(_ explanation: String) -> Formula {
        Formula(
            id: self.id,
            originalText: self.originalText,
            latexRepresentation: self.latexRepresentation,
            mathMLRepresentation: self.mathMLRepresentation,
            type: self.type,
            analysisResult: self.analysisResult,
            solutionResult: self.solutionResult,
            dateCreated: self.dateCreated,
            sourceBookId: self.sourceBookId,
            sourcePosition: self.sourcePosition,
            aiExplanation: explanation,
            userNotes: self.userNotes,
            tags: self.tags
        )
    }
}

// MARK: - Sample Data for Development

extension Formula {
    static let sampleFormulas: [Formula] = [
        Formula(
            originalText: "E = mc²",
            latexRepresentation: "E = mc^2",
            type: .equation,
            analysisResult: FormulaAnalysisResult(
                variables: ["E", "m", "c"],
                constants: ["c"],
                operators: ["=", "^"],
                complexity: 2
            ),
            aiExplanation: "Формула эквивалентности массы и энергии Эйнштейна",
            tags: ["физика", "эйнштейн", "энергия"]
        ),
        Formula(
            originalText: "∫x²dx = x³/3 + C",
            latexRepresentation: "\\int x^2 dx = \\frac{x^3}{3} + C",
            type: .integral,
            analysisResult: FormulaAnalysisResult(
                variables: ["x", "C"],
                constants: ["3"],
                functions: ["∫"],
                operators: ["=", "/", "+"],
                complexity: 3
            ),
            aiExplanation: "Интеграл от квадратичной функции",
            tags: ["математика", "интеграл", "производная"]
        ),
        Formula(
            originalText: "sin²x + cos²x = 1",
            latexRepresentation: "\\sin^2 x + \\cos^2 x = 1",
            type: .trigonometric,
            analysisResult: FormulaAnalysisResult(
                variables: ["x"],
                constants: ["1"],
                functions: ["sin", "cos"],
                operators: ["=", "+", "^"],
                complexity: 2
            ),
            aiExplanation: "Основное тригонометрическое тождество",
            tags: ["тригонометрия", "тождество", "математика"]
        )
    ]
}