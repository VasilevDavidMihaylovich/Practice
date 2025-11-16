//
//  ReadingSettings.swift
//  KFUPractice
//
//  AI Reader App
//

import SwiftUI
import Foundation

/// Темы оформления для чтения
enum ReadingTheme: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case sepia = "sepia"
    
    var displayName: String {
        switch self {
        case .light: return "Светлая"
        case .dark: return "Темная"
        case .sepia: return "Сепия"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .light: return Color.white
        case .dark: return Color.black
        case .sepia: return Color(red: 0.95, green: 0.91, blue: 0.79)
        }
    }
    
    var textColor: Color {
        switch self {
        case .light: return Color.black
        case .dark: return Color.white
        case .sepia: return Color(red: 0.2, green: 0.15, blue: 0.1)
        }
    }
    
    var systemImage: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .sepia: return "leaf"
        }
    }
}

/// Настройки чтения пользователя
struct ReadingSettings: Codable, Equatable {
    /// Размер шрифта (12-32)
    var fontSize: Double
    
    /// Название шрифта
    var fontName: String
    
    /// Межстрочный интервал (0.8-2.0)
    var lineSpacing: Double
    
    /// Горизонтальные отступы
    var horizontalPadding: Double
    
    /// Тема оформления
    var theme: ReadingTheme
    
    /// Яркость экрана (0.1-1.0)
    var brightness: Double
    
    /// Автоматический поворот страниц при TTS
    var autoPageTurn: Bool
    
    /// Подсветка выбранного текста
    var highlightSelectedText: Bool
    
    /// Анимации при перелистывании
    var enableAnimations: Bool
    
    init(
        fontSize: Double = 16.0,
        fontName: String = "System",
        lineSpacing: Double = 1.2,
        horizontalPadding: Double = 20.0,
        theme: ReadingTheme = .light,
        brightness: Double = 1.0,
        autoPageTurn: Bool = false,
        highlightSelectedText: Bool = true,
        enableAnimations: Bool = true
    ) {
        self.fontSize = fontSize
        self.fontName = fontName
        self.lineSpacing = lineSpacing
        self.horizontalPadding = horizontalPadding
        self.theme = theme
        self.brightness = brightness
        self.autoPageTurn = autoPageTurn
        self.highlightSelectedText = highlightSelectedText
        self.enableAnimations = enableAnimations
    }
}

// MARK: - Helper Extensions

extension ReadingSettings {
    /// Доступные размеры шрифта
    static let fontSizeRange: ClosedRange<Double> = 12.0...32.0
    
    /// Доступные значения межстрочного интервала
    static let lineSpacingRange: ClosedRange<Double> = 0.8...2.0
    
    /// Доступные шрифты
    static let availableFonts: [String] = [
        "System",
        "Georgia",
        "Times New Roman",
        "Palatino",
        "Baskerville",
        "Charter",
        "New York"
    ]
    
    /// Настройки по умолчанию
    static let `default` = ReadingSettings()
    
    /// Создает шрифт SwiftUI на основе настроек
    var font: Font {
        if fontName == "System" {
            return .system(size: fontSize)
        } else {
            return .custom(fontName, size: fontSize)
        }
    }
    
    /// Проверка валидности настроек
    var isValid: Bool {
        return Self.fontSizeRange.contains(fontSize) &&
               Self.lineSpacingRange.contains(lineSpacing) &&
               horizontalPadding >= 0 &&
               brightness >= 0.1 && brightness <= 1.0
    }
    
    /// Обновление размера шрифта с ограничениями
    func withFontSize(_ newSize: Double) -> ReadingSettings {
        var updated = self
        updated.fontSize = max(Self.fontSizeRange.lowerBound, 
                             min(Self.fontSizeRange.upperBound, newSize))
        return updated
    }
    
    /// Обновление межстрочного интервала с ограничениями
    func withLineSpacing(_ newSpacing: Double) -> ReadingSettings {
        var updated = self
        updated.lineSpacing = max(Self.lineSpacingRange.lowerBound,
                                min(Self.lineSpacingRange.upperBound, newSpacing))
        return updated
    }
    
    /// Переключение темы
    func withTheme(_ newTheme: ReadingTheme) -> ReadingSettings {
        var updated = self
        updated.theme = newTheme
        return updated
    }
}

// MARK: - Preset Configurations

extension ReadingSettings {
    /// Предустановка для чтения научной литературы
    static let scientific = ReadingSettings(
        fontSize: 14.0,
        fontName: "Charter",
        lineSpacing: 1.4,
        theme: .sepia,
        highlightSelectedText: true
    )
    
    /// Предустановка для комфортного чтения
    static let comfortable = ReadingSettings(
        fontSize: 18.0,
        fontName: "Georgia",
        lineSpacing: 1.3,
        horizontalPadding: 24.0,
        theme: .light
    )
    
    /// Предустановка для ночного чтения
    static let night = ReadingSettings(
        fontSize: 16.0,
        fontName: "System",
        lineSpacing: 1.3,
        theme: .dark,
        brightness: 0.3
    )
}