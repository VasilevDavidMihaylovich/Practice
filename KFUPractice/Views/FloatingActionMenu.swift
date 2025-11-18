//
//  FloatingActionMenu.swift
//  KFUPractice
//
//  Floating Action Menu with Magic Wand
//

import SwiftUI
import PDFKit

/// Плавающее меню действий с магической палочкой
struct FloatingActionMenu: View {
    @Binding var isExpanded: Bool // Теперь управляется извне
    @Binding var showNavigationBar: Bool
    let pdfDocument: PDFDocument?
    let currentPageNumber: Int
    let onAreaSelected: (() -> Void)?
    let onDrawingSelected: (() -> Void)?
    let onTextScreenshotSelected: (() -> Void)?
    let onAINotesSelected: (() -> Void)?
    let onChartSelected: (() -> Void)?
    
    init(
        isExpanded: Binding<Bool>,
        showNavigationBar: Binding<Bool>,
        pdfDocument: PDFDocument? = nil,
        currentPageNumber: Int = 0,
        onAreaSelected: (() -> Void)? = nil,
        onDrawingSelected: (() -> Void)? = nil,
        onTextScreenshotSelected: (() -> Void)? = nil,
        onAINotesSelected: (() -> Void)? = nil,
        onChartSelected: (() -> Void)? = nil
    ) {
        self._isExpanded = isExpanded
        self._showNavigationBar = showNavigationBar
        self.pdfDocument = pdfDocument
        self.currentPageNumber = currentPageNumber
        self.onAreaSelected = onAreaSelected
        self.onDrawingSelected = onDrawingSelected
        self.onTextScreenshotSelected = onTextScreenshotSelected
        self.onAINotesSelected = onAINotesSelected
        self.onChartSelected = onChartSelected
    }
    
    var body: some View {
        ZStack {
            // Затемнение фона при раскрытии
            if isExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // Контейнер меню, закрепленный в правом нижнем углу
            VStack(spacing: 0) {
                Spacer()
                
                HStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 12) { // Уменьшили spacing с 16 до 12
                        if isExpanded {
                            // Кнопка "Маркер"
                            actionButton(
                                icon: "highlighter",
                                label: "Пометки",
                                color: .yellow,
                                delay: 0.25,
                                action: {
                                    isExpanded = false
                                    showNavigationBar = false
                                    onDrawingSelected?()
                                }
                            )
                            
                            // Кнопка "График"
                            actionButton(
                                icon: "chart.bar",
                                label: "График",
                                color: .green,
                                delay: 0.20,
                                action: {
                                    isExpanded = false
                                    showNavigationBar = false
                                    onChartSelected?()
                                }
                            )
                            
                            // Кнопка "AI заметка"
                            actionButton(
                                icon: "brain",
                                label: "AI заметка",
                                color: .purple,
                                delay: 0.15,
                                action: {
                                    isExpanded = false
                                    showNavigationBar = false
                                    onAINotesSelected?()
                                }
                            )
                            
                            // Кнопка "Текст" (скриншот для ИИ)
                            actionButton(
                                icon: "camera.viewfinder",
                                label: "Конспект",
                                color: .blue,
                                delay: 0.10,
                                action: {
                                    isExpanded = false
                                    showNavigationBar = false
                                    onTextScreenshotSelected?()
                                }
                            )
                            
                    // Кнопка "Ножницы"
//                    actionButton(
//                        icon: "scissors",
//                        label: "Вырезать",
//                        color: .red,
//                        delay: 0.05,
//                        action: {
//                            isExpanded = false
//                            onAreaSelected?()
//                        }
//                    )
                        }
                    }
                    .padding(.trailing, 10) // Уменьшили отступ справа с 20 до 10
                    .padding(.bottom, 130)
//                    .opacity(showNavigationBar ? 1 : 0)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private func actionButton(
        icon: String,
        label: String,
        color: Color,
        delay: Double,
        action: (() -> Void)? = nil
    ) -> some View {
        Button {
            if let action = action {
                // Закрываем меню
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = false
                }
                action()
            } else {
                // TODO: Добавить функционал
                print("Нажата кнопка: \(label)")
                
                // Закрываем меню после выбора
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Иконка с градиентом
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    color.opacity(0.3),
                                    color.opacity(0.15)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40) // Уменьшили с 44x44 до 40x40
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                
                // Текст
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10) // Уменьшили с 12 до 10
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.white))
//                    .shadow(
//                        color: Color.black.opacity(0.15),
//                        radius: 10,
//                        x: 0,
//                        y: 5
//                    )
            )
            .frame(width: 240) // Увеличили ширину с 200 до 240
        }
        .buttonStyle(ActionButtonStyle())
        .opacity(isExpanded ? 1 : 0)
        .offset(x: isExpanded ? 0 : 80, y: isExpanded ? 0 : -20)
        .scaleEffect(isExpanded ? 1 : 0.6)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.75)
            .delay(delay),
            value: isExpanded
        )
    }
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        FloatingActionMenu(
            isExpanded: .constant(false),
            showNavigationBar: .constant(false)
        )
    }
}

