//
//  DrawingCanvasView.swift
//  KFUPractice
//
//  Drawing Canvas with Tools Panel
//

import SwiftUI

/// Компонент для рисования на странице книги
struct DrawingCanvasView: View {
    @Binding var isPresented: Bool
    @State private var currentStroke: [CGPoint] = []
    @State private var strokes: [DrawingStroke] = []
    @State private var brushSettings = DrawingBrushSettings()
    @State private var showBrushSettings: Bool = false
    
    let initialDrawing: PageDrawing?
    let onSave: (([DrawingStroke]) -> Void)
    let onCancel: (() -> Void)
    
    init(
        isPresented: Binding<Bool>,
        initialDrawing: PageDrawing? = nil,
        onSave: @escaping ([DrawingStroke]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.initialDrawing = initialDrawing
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            // Прозрачный фон для перехвата касаний
            Color.clear
                .ignoresSafeArea()
            
            // Холст для рисования (полный экран, прозрачный)
            Canvas { context, size in
                // Рисуем сохраненные штрихи
                for stroke in strokes {
                    drawStroke(stroke, in: context)
                }
                
                // Рисуем текущий штрих
                if !currentStroke.isEmpty {
                    let currentStrokeData = DrawingStroke(
                        points: currentStroke,
                        color: brushSettings.color,
                        lineWidth: brushSettings.lineWidth,
                        opacity: brushSettings.opacity
                    )
                    drawStroke(currentStrokeData, in: context)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        currentStroke.append(value.location)
                    }
                    .onEnded { _ in
                        // Завершаем штрих
                        if !currentStroke.isEmpty {
                            let stroke = DrawingStroke(
                                points: currentStroke,
                                color: brushSettings.color,
                                lineWidth: brushSettings.lineWidth,
                                opacity: brushSettings.opacity
                            )
                            strokes.append(stroke)
                            currentStroke.removeAll()
                        }
                    }
            )
            
            // Компактная панель инструментов (плавающая)
            VStack {
                HStack {
                    // Кнопка закрытия
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    
                    Spacer()
                    
                    // Кнопка настроек кисти
                    Button {
                        withAnimation(.spring()) {
                            showBrushSettings.toggle()
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.blue.opacity(0.8)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
                
                // Нижняя панель инструментов
                compactToolsPanel
                    .padding(.bottom, 30)
            }
            
            // Панель настроек кисти (сбоку)
            if showBrushSettings {
                HStack {
                    brushSettingsPanel
                        .transition(.move(edge: .leading))
                    Spacer()
                }
            }
        }
        .onAppear {
            // Загружаем существующие штрихи если есть
            if let drawing = initialDrawing {
                strokes = drawing.strokes
            }
        }
    }
    
    // MARK: - Compact Tools Panel
    
    private var compactToolsPanel: some View {
        HStack(spacing: 12) {
            // Очистить всё
            Button {
                withAnimation(.spring()) {
                    strokes.removeAll()
                    currentStroke.removeAll()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.red.opacity(0.8)))
            }
            
            // Отменить последний штрих
            Button {
                withAnimation(.spring()) {
                    if !strokes.isEmpty {
                        strokes.removeLast()
                    }
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.orange.opacity(0.8)))
            }
            .disabled(strokes.isEmpty)
            .opacity(strokes.isEmpty ? 0.5 : 1.0)
            
            Spacer()
            
            // Сохранить
            Button {
                onSave(strokes)
            } label: {
                Image(systemName: "checkmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 44)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
                .blur(radius: 10)
        )
    }
    
    // MARK: - Brush Settings Panel
    
    private var brushSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Настройки кисти")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Размер кисти
            VStack(alignment: .leading, spacing: 6) {
                Text("Размер: \(Int(brushSettings.lineWidth))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    ForEach(DrawingBrushSettings.availableSizes, id: \.self) { size in
                        Button {
                            brushSettings.lineWidth = size
                        } label: {
                            Circle()
                                .fill(brushSettings.lineWidth == size ? brushSettings.color : Color.gray)
                                .frame(width: size * 1.5 + 8, height: size * 1.5 + 8)
                        }
                    }
                }
            }
            
            // Прозрачность
            VStack(alignment: .leading, spacing: 6) {
                Text("Прозрачность: \(Int(brushSettings.opacity * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    ForEach(DrawingBrushSettings.availableOpacities, id: \.self) { opacity in
                        Button {
                            brushSettings.opacity = opacity
                        } label: {
                            Circle()
                                .fill(brushSettings.color.opacity(opacity))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            brushSettings.opacity == opacity ? Color.primary : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                    }
                }
            }
            
            // Цвета
            VStack(alignment: .leading, spacing: 6) {
                Text("Цвет")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(DrawingBrushSettings.availableColors, id: \.self) { color in
                        Button {
                            brushSettings.color = color
                        } label: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            brushSettings.color == color ? Color.primary : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 10)
        )
        .frame(width: 180)
        .padding(.leading, 20)
        .padding(.top, 100)
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
            with: .color(stroke.swiftUIColor),
            style: StrokeStyle(
                lineWidth: stroke.lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
}

// MARK: - Preview

#Preview {
    DrawingCanvasView(
        isPresented: Binding.constant(true),
        onSave: { strokes in
            print("Saved \(strokes.count) strokes")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}