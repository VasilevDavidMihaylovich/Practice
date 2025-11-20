//
//  AIResult.swift
//  KFUPractice
//
//  AI Result Model
//

import Foundation

/// Результат обработки ИИ
struct AIResult: Equatable {
    let id: UUID
    let title: String
    let content: String
    let actionType: AIActionType
    let timestamp: Date
    let metadata: [String: String]
    let chartData: ChartData? // Данные для отображения графика
    
    init(
        id: UUID = UUID(),
        actionType: AIActionType,
        title: String,
        content: String,
        timestamp: Date = Date(),
        metadata: [String: String] = [:],
        chartData: ChartData? = nil
    ) {
        self.id = id
        self.actionType = actionType
        self.title = title
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
        self.chartData = chartData
    }
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