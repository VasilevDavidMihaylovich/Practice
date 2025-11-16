//
//  MathEngineProtocol.swift
//  KFUPractice
//
//  AI Reader App
//

import Foundation
import CoreGraphics

/// Протокол для математического движка
protocol MathEngineProtocol {
    /// Решить уравнение или выражение
    /// - Parameters:
    ///   - expression: Математическое выражение в строковом виде
    ///   - method: Предпочтительный метод решения
    /// - Returns: Результат решения с шагами
    func solve(
        expression: String,
        method: SolutionMethod?
    ) async throws -> MathSolutionResult
    
    /// Вычислить значение выражения для заданных переменных
    /// - Parameters:
    ///   - expression: Математическое выражение
    ///   - variables: Значения переменных
    /// - Returns: Численный результат
    func evaluate(
        expression: String,
        variables: [String: Double]
    ) throws -> Double
    
    /// Генерировать точки для построения графика функции
    /// - Parameters:
    ///   - expression: Математическое выражение
    ///   - variable: Основная переменная (обычно x)
    ///   - range: Диапазон значений переменной
    ///   - pointsCount: Количество точек для генерации
    /// - Returns: Массив точек для графика
    func generatePlotPoints(
        for expression: String,
        variable: String,
        range: ClosedRange<Double>,
        pointsCount: Int
    ) throws -> [CGPoint]
    
    /// Найти производную выражения
    /// - Parameters:
    ///   - expression: Исходное выражение
    ///   - variable: Переменная дифференцирования
    /// - Returns: Производная в строковом виде
    func differentiate(
        expression: String,
        withRespectTo variable: String
    ) throws -> String
    
    /// Найти интеграл выражения
    /// - Parameters:
    ///   - expression: Исходное выражение
    ///   - variable: Переменная интегрирования
    ///   - definite: Определенный или неопределенный интеграл
    ///   - bounds: Границы для определенного интеграла
    /// - Returns: Интеграл в строковом виде или численное значение
    func integrate(
        expression: String,
        withRespectTo variable: String,
        definite: Bool,
        bounds: ClosedRange<Double>?
    ) throws -> String
    
    /// Упростить математическое выражение
    /// - Parameter expression: Выражение для упрощения
    /// - Returns: Упрощенное выражение
    func simplify(expression: String) throws -> String
    
    /// Разложить выражение на множители
    /// - Parameter expression: Выражение для факторизации
    /// - Returns: Факторизованное выражение
    func factor(expression: String) throws -> String
    
    /// Найти корни уравнения
    /// - Parameters:
    ///   - equation: Уравнение
    ///   - variable: Переменная для решения
    ///   - method: Метод поиска корней
    /// - Returns: Массив корней
    func findRoots(
        of equation: String,
        for variable: String,
        method: RootFindingMethod?
    ) throws -> [Double]
}

/// Методы решения уравнений
enum SolutionMethod: String, CaseIterable {
    case analytical = "analytical"      // Аналитическое решение
    case numerical = "numerical"        // Численное решение
    case graphical = "graphical"        // Графическое решение
    case substitution = "substitution"  // Метод подстановки
    case elimination = "elimination"    // Метод исключения
    case newton = "newton"             // Метод Ньютона
    case bisection = "bisection"       // Метод деления пополам
    
    var displayName: String {
        switch self {
        case .analytical: return "Аналитический"
        case .numerical: return "Численный"
        case .graphical: return "Графический"
        case .substitution: return "Подстановка"
        case .elimination: return "Исключение"
        case .newton: return "Ньютона"
        case .bisection: return "Деление пополам"
        }
    }
}

/// Методы поиска корней
enum RootFindingMethod: String, CaseIterable {
    case newton = "newton"              // Метод Ньютона
    case bisection = "bisection"        // Метод деления пополам
    case secant = "secant"             // Метод секущих
    case falsePosition = "false_position" // Метод ложного положения
    case brent = "brent"               // Метод Брента
    
    var displayName: String {
        switch self {
        case .newton: return "Ньютона"
        case .bisection: return "Деления пополам"
        case .secant: return "Секущих"
        case .falsePosition: return "Ложного положения"
        case .brent: return "Брента"
        }
    }
}

/// Ошибки математического движка
enum MathEngineError: LocalizedError {
    case invalidExpression(String)
    case undefinedVariable(String)
    case divisionByZero
    case domainError
    case convergenceError
    case unsupportedOperation(String)
    case computationTimeout
    case memoryLimit
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidExpression(let expr):
            return "Неправильное выражение: \(expr)"
        case .undefinedVariable(let variable):
            return "Неопределенная переменная: \(variable)"
        case .divisionByZero:
            return "Деление на ноль"
        case .domainError:
            return "Ошибка области определения"
        case .convergenceError:
            return "Ошибка сходимости"
        case .unsupportedOperation(let operation):
            return "Неподдерживаемая операция: \(operation)"
        case .computationTimeout:
            return "Превышено время вычисления"
        case .memoryLimit:
            return "Превышен лимит памяти"
        case .unknown(let message):
            return "Неизвестная ошибка: \(message)"
        }
    }
}

/// Конфигурация математического движка
struct MathEngineConfig {
    let precision: Int                   // Точность вычислений
    let maxIterations: Int              // Максимальное количество итераций
    let tolerance: Double               // Допустимая погрешность
    let timeoutSeconds: TimeInterval    // Таймаут вычислений
    let enableSymbolic: Bool            // Включить символьные вычисления
    let enableNumerical: Bool           // Включить численные методы
    
    static let `default` = MathEngineConfig(
        precision: 15,
        maxIterations: 1000,
        tolerance: 1e-10,
        timeoutSeconds: 30.0,
        enableSymbolic: true,
        enableNumerical: true
    )
    
    static let highPrecision = MathEngineConfig(
        precision: 30,
        maxIterations: 10000,
        tolerance: 1e-15,
        timeoutSeconds: 60.0,
        enableSymbolic: true,
        enableNumerical: true
    )
}

/// Результат анализа выражения
struct ExpressionAnalysisResult {
    let variables: Set<String>          // Переменные в выражении
    let constants: Set<String>          // Константы
    let functions: Set<String>          // Функции
    let operators: Set<String>          // Операторы
    let complexity: Int                 // Сложность выражения
    let isLinear: Bool                  // Линейное ли выражение
    let isPolynomial: Bool              // Полином ли
    let degree: Int?                    // Степень (для полиномов)
    let domain: String?                 // Область определения
    let range: String?                  // Область значений
}

/// Протокол для анализа математических выражений
protocol MathExpressionAnalyzerProtocol {
    /// Анализировать структуру выражения
    func analyze(expression: String) throws -> ExpressionAnalysisResult
    
    /// Проверить корректность выражения
    func validate(expression: String) -> Bool
    
    /// Получить список переменных в выражении
    func extractVariables(from expression: String) throws -> Set<String>
    
    /// Получить список функций в выражении
    func extractFunctions(from expression: String) throws -> Set<String>
    
    /// Определить тип выражения
    func classifyExpression(_ expression: String) throws -> FormulaType
}

/// Протокол для преобразования математических выражений
protocol MathExpressionConverterProtocol {
    /// Преобразовать в LaTeX
    func convertToLaTeX(_ expression: String) throws -> String
    
    /// Преобразовать в MathML
    func convertToMathML(_ expression: String) throws -> String
    
    /// Преобразовать из LaTeX
    func convertFromLaTeX(_ latex: String) throws -> String
    
    /// Преобразовать из MathML
    func convertFromMathML(_ mathml: String) throws -> String
    
    /// Нормализовать выражение
    func normalize(_ expression: String) throws -> String
}