import SwiftUI
import Charts

/// SwiftUI компонент для отображения графика
struct ChartView: View {
    let chartData: ChartData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок графика
            Text(chartData.title)
                .font(.headline)
                .fontWeight(.semibold)
            
            // График
            chartContent
                .frame(height: 200)
                .padding(.vertical)
            
            // Описание
            if !chartData.description.isEmpty {
                Text(chartData.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    @ViewBuilder
    private var chartContent: some View {
        Chart {
            ForEach(Array(chartData.dataPoints.enumerated()), id: \.offset) { index, point in
                switch chartData.type {
                case .line:
                    LineMark(
                        x: .value("X", point.x),
                        y: .value("Y", point.y)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                case .bar:
                    BarMark(
                        x: .value("X", point.x),
                        y: .value("Y", point.y)
                    )
                    .foregroundStyle(.blue)
                    
                case .area:
                    AreaMark(
                        x: .value("X", point.x),
                        y: .value("Y", point.y)
                    )
                    .foregroundStyle(.blue.opacity(0.3))
                    
                case .scatter:
                    PointMark(
                        x: .value("X", point.x),
                        y: .value("Y", point.y)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(50)
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ChartView(chartData: ChartData(
            type: .line,
            title: "Квадратичная функция y = x²",
            description: "График показывает зависимость y от x для функции y = x²",
            dataPoints: [
                ChartData.DataPoint(x: -3, y: 9),
                ChartData.DataPoint(x: -2, y: 4),
                ChartData.DataPoint(x: -1, y: 1),
                ChartData.DataPoint(x: 0, y: 0),
                ChartData.DataPoint(x: 1, y: 1),
                ChartData.DataPoint(x: 2, y: 4),
                ChartData.DataPoint(x: 3, y: 9)
            ]
        ))
        
        ChartView(chartData: ChartData(
            type: .bar,
            title: "Пример столбчатой диаграммы",
            description: "Демонстрация различных значений",
            dataPoints: [
                ChartData.DataPoint(x: 1, y: 10),
                ChartData.DataPoint(x: 2, y: 15),
                ChartData.DataPoint(x: 3, y: 8),
                ChartData.DataPoint(x: 4, y: 20),
                ChartData.DataPoint(x: 5, y: 12)
            ]
        ))
    }
    .padding()
}