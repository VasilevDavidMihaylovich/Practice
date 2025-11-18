//
//  HeaderActionMenu.swift
//  KFUPractice
//
//  Action Menu for Header
//

import SwiftUI
import PDFKit

/// Меню действий для header
struct HeaderActionMenu: View {
    @Binding var isExpanded: Bool
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
            
            // Меню, расположенное сверху справа
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    
                    if isExpanded {
                        VStack(spacing: 12) {
                            // Кнопка "Маркер"
                            actionButton(
                                icon: "highlighter",
                                label: "Маркер",
                                color: .yellow,
                                delay: 0.05,
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
                                delay: 0.10,
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
                            
                            // Кнопка "Скриншот"
                            actionButton(
                                icon: "camera.viewfinder",
                                label: "Конспект",
                                color: .blue,
                                delay: 0.20,
                                action: {
                                    isExpanded = false
                                    showNavigationBar = false
                                    onTextScreenshotSelected?()
                                }
                            )
                            
                            // Кнопка "Вырезать"
//                            actionButton(
//                                icon: "scissors",
//                                label: "Вырезать",
//                                color: .red,
//                                delay: 0.25,
//                                action: {
//                                    isExpanded = false
//                                    onAreaSelected?()
//                                }
//                            )
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 60)
                    }
                }
                
                Spacer()
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
                        .frame(width: 40, height: 40)
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
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.white))
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
            .frame(width: 240)
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

