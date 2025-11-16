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
    @State private var isExpanded: Bool = false
    let pdfDocument: PDFDocument?
    let currentPageNumber: Int
    let onAreaSelected: (() -> Void)?
    let onDrawingSelected: (() -> Void)?
    let onTextScreenshotSelected: (() -> Void)?
    
    init(
        pdfDocument: PDFDocument? = nil,
        currentPageNumber: Int = 0,
        onAreaSelected: (() -> Void)? = nil,
        onDrawingSelected: (() -> Void)? = nil,
        onTextScreenshotSelected: (() -> Void)? = nil
    ) {
        self.pdfDocument = pdfDocument
        self.currentPageNumber = currentPageNumber
        self.onAreaSelected = onAreaSelected
        self.onDrawingSelected = onDrawingSelected
        self.onTextScreenshotSelected = onTextScreenshotSelected
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
                    
                    VStack(spacing: 16) {
                        if isExpanded {
                            // Кнопка "Маркер"
                            actionButton(
                                icon: "highlighter",
                                label: "Маркер",
                                color: .yellow,
                                delay: 0.15,
                                action: {
                                    isExpanded = false
                                    onDrawingSelected?()
                                }
                            )
                            
                            // Кнопка "Текст" (скриншот для ИИ)
                            actionButton(
                                icon: "camera.viewfinder",
                                label: "Скриншот",
                                color: .blue,
                                delay: 0.1,
                                action: {
                                    isExpanded = false
                                    onTextScreenshotSelected?()
                                }
                            )
                            
                    // Кнопка "Ножницы"
                    actionButton(
                        icon: "scissors",
                        label: "Вырезать",
                        color: .red,
                        delay: 0.05,
                        action: {
                            isExpanded = false
                            onAreaSelected?()
                        }
                    )
                        }
                        
                        // Главная кнопка с магической палочкой
                        mainButton
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    // MARK: - Main Button
    
    private var mainButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        } label: {
            ZStack {
                // Фон с градиентом
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.purple.opacity(0.9),
                                Color.pink.opacity(0.9)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(
                        color: Color.purple.opacity(0.4),
                        radius: isExpanded ? 20 : 10,
                        x: 0,
                        y: isExpanded ? 5 : 2
                    )
                
                // Иконка магической палочки с эффектом свечения
                Image(systemName: isExpanded ? "xmark" : "wand.and.stars")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .scaleEffect(isExpanded ? 0.85 : 1.0)
                    .shadow(color: Color.white.opacity(0.5), radius: 4)
            }
        }
        .buttonStyle(ScaleButtonStyle())
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
                        .frame(width: 44, height: 44)
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
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(0.15),
                        radius: 10,
                        x: 0,
                        y: 5
                    )
            )
            .frame(width: 190)
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
        
        FloatingActionMenu()
    }
}

