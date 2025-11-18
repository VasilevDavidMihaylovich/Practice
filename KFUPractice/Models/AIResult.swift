//
//  AIResult.swift
//  KFUPractice
//
//  AI Result Model
//

import Foundation

/// Результат обработки ИИ
struct AIResult {
    let id: UUID = UUID()
    let title: String
    let content: String
    let actionType: AIActionType
    let createdAt: Date = Date()
}

/// Типы действий ИИ
enum AIActionType: String, CaseIterable {
    case screenshot = "screenshot"
    case aiNote = "aiNote" 
    case chart = "chart"
    case areaSelection = "areaSelection"
    
    var displayName: String {
        switch self {
        case .screenshot:
            return "Скриншот"
        case .aiNote:
            return "AI заметка"
        case .chart:
            return "График"
        case .areaSelection:
            return "Вырезка"
        }
    }
    
    var icon: String {
        switch self {
        case .screenshot:
            return "camera.viewfinder"
        case .aiNote:
            return "brain"
        case .chart:
            return "chart.bar"
        case .areaSelection:
            return "scissors"
        }
    }
}