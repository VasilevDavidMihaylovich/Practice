//
//  Drawing.swift
//  KFUPractice
//
//  AI Reader App - Drawing Models
//

import Foundation
import SwiftUI

/// Codable-совместимая версия CGPoint
struct CodablePoint: Codable, Equatable {
    let x: Double
    let y: Double
    
    init(_ point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }
    
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

/// Модель для одного штриха/линии рисунка
struct DrawingStroke: Codable, Identifiable, Equatable {
    let id: UUID
    let points: [CodablePoint] // Используем CodablePoint вместо CGPoint
    let color: String // Храним как hex string для Codable
    let lineWidth: Double
    let opacity: Double // Прозрачность от 0.0 до 1.0
    let timestamp: Date
    
    init(points: [CGPoint], color: Color = .black, lineWidth: Double = 3.0, opacity: Double = 1.0) {
        self.id = UUID()
        self.points = points.map { CodablePoint($0) }
        self.color = color.toHexString()
        self.lineWidth = lineWidth
        self.opacity = opacity
        self.timestamp = Date()
    }
    
    /// Получить точки как CGPoint массив
    var cgPoints: [CGPoint] {
        return points.map { $0.cgPoint }
    }
    
    /// Получить цвет как SwiftUI Color с примененной прозрачностью
    var swiftUIColor: Color {
        let baseColor = Color(hex: color) ?? .black
        return baseColor.opacity(opacity)
    }
}

/// Модель для рисунка на странице книги
struct PageDrawing: Codable, Identifiable, Equatable {
    let id: UUID
    let bookId: UUID
    let pageNumber: Int
    var strokes: [DrawingStroke]
    let dateCreated: Date
    var dateModified: Date
    
    init(bookId: UUID, pageNumber: Int) {
        self.id = UUID()
        self.bookId = bookId
        self.pageNumber = pageNumber
        self.strokes = []
        self.dateCreated = Date()
        self.dateModified = Date()
    }
    
    /// Добавить штрих к рисунку
    mutating func addStroke(_ stroke: DrawingStroke) {
        strokes.append(stroke)
        dateModified = Date()
    }
    
    /// Очистить все штрихи
    mutating func clearStrokes() {
        strokes.removeAll()
        dateModified = Date()
    }
    
    /// Проверить, есть ли рисунки на странице
    var isEmpty: Bool {
        return strokes.isEmpty
    }
}

/// Расширение Color для преобразования в hex string и обратно
extension Color {
    func toHexString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb = (Int)(red * 255) << 16 | (Int)(green * 255) << 8 | (Int)(blue * 255) << 0
        return String(format: "#%06x", rgb)
    }
    
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

/// Настройки кисти для рисования
struct DrawingBrushSettings {
    var color: Color = .black
    var lineWidth: Double = 3.0
    var opacity: Double = 1.0
    
    /// Доступные цвета для рисования
    static let availableColors: [Color] = [
        .black, .red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan, .brown
    ]
    
    /// Доступные размеры кисти
    static let availableSizes: [Double] = [1.0, 2.0, 3.0, 5.0, 8.0, 12.0]
    
    /// Доступные уровни прозрачности
    static let availableOpacities: [Double] = [0.2, 0.4, 0.6, 0.8, 1.0]
}