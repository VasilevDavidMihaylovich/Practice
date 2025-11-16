//
//  DrawingOverlayView.swift
//  KFUPractice
//
//  Overlay for displaying saved drawings
//

import SwiftUI

/// Компонент для отображения сохраненных рисунков поверх содержимого страницы
struct DrawingOverlayView: View {
    let drawing: PageDrawing
    
    var body: some View {
        Canvas { context, size in
            // Рисуем все сохраненные штрихи
            for stroke in drawing.strokes {
                drawStroke(stroke, in: context)
            }
        }
        .allowsHitTesting(false) // Позволяет проходить касаниям через рисунок
    }
    
    // MARK: - Helper Methods
    
    private func drawStroke(_ stroke: DrawingStroke, in context: GraphicsContext) {
        let points = stroke.cgPoints
        guard points.count > 1 else { return }
        
        var path = Path()
        path.move(to: points[0])
        
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        context.stroke(
            path,
            with: .color(stroke.swiftUIColor), // Убираем прозрачность, чтобы рисунки были видны поверх содержимого
            style: StrokeStyle(
                lineWidth: stroke.lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
}

#Preview {
    // Создаем тестовые данные для превью
    let testDrawing = PageDrawing(bookId: UUID(), pageNumber: 1)
    
    DrawingOverlayView(drawing: testDrawing)
        .frame(width: 300, height: 400)
        .background(Color.white)
}