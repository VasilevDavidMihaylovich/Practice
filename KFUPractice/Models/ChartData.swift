import Foundation

/// Модель данных для отображения графиков
struct ChartData: Codable, Equatable {
    let id = UUID()
    let type: ChartType
    let title: String
    let description: String
    let dataPoints: [DataPoint]
    
    enum ChartType: String, Codable, CaseIterable {
        case line = "line"
        case bar = "bar"
        case area = "area"
        case scatter = "scatter"
        
        var displayName: String {
            switch self {
            case .line: return "Линейный график"
            case .bar: return "Столбчатая диаграмма"
            case .area: return "Площадной график"
            case .scatter: return "Точечная диаграмма"
            }
        }
    }
    
    struct DataPoint: Codable, Equatable {
        let x: Double
        let y: Double
        let label: String?
        
        init(x: Double, y: Double, label: String? = nil) {
            self.x = x
            self.y = y
            self.label = label
        }
    }
}