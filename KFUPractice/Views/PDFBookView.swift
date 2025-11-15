//
//  PDFBookView.swift
//  KFUPractice
//
//  PDF Book View with Page Flip Animation
//

import SwiftUI
import PDFKit

/// Компонент для отображения PDF с анимацией перелистывания страниц
struct PDFBookView: View {
    let pdfDocument: PDFDocument
    @Binding var currentPageNumber: Int
    let onPageChanged: ((Int) -> Void)?
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var nextPageNumber: Int?
    @State private var previousPageNumber: Int?
    @State private var pageFlipProgress: CGFloat = 0
    
    private let pageSpacing: CGFloat = 20
    private let minDragDistance: CGFloat = 50
    
    init(
        pdfDocument: PDFDocument,
        currentPageNumber: Binding<Int>,
        onPageChanged: ((Int) -> Void)? = nil
    ) {
        self.pdfDocument = pdfDocument
        self._currentPageNumber = currentPageNumber
        self.onPageChanged = onPageChanged
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Фон
                Color(white: 0.95)
                    .ignoresSafeArea()
                
                // Контейнер страниц
                ZStack {
                    // Предыдущая страница (сзади)
                    if let prevPageNum = previousPageNumber, prevPageNum >= 0 {
                        pageView(for: prevPageNum)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(isDragging && dragOffset > 0 ? 0.95 : 1.0)
                            .opacity(isDragging && dragOffset > 0 ? 0.5 : 0)
                            .zIndex(0)
                    }
                    
                    // Текущая страница
                    if currentPageNumber < pdfDocument.pageCount {
                        pageView(for: currentPageNumber)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: dragOffset)
                            .scaleEffect(isDragging ? 0.98 : 1.0)
                            .zIndex(2)
                            .shadow(
                                color: Color.black.opacity(isDragging ? 0.3 : 0.2),
                                radius: isDragging ? 20 : 10,
                                x: isDragging ? dragOffset * 0.1 : 0,
                                y: 5
                            )
                    }
                    
                    // Следующая страница (справа)
                    if let nextPageNum = nextPageNumber, nextPageNum < pdfDocument.pageCount {
                        pageView(for: nextPageNum)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: dragOffset + geometry.size.width)
                            .scaleEffect(isDragging && dragOffset < 0 ? 0.95 : 1.0)
                            .opacity(isDragging && dragOffset < 0 ? 0.5 : 0)
                            .zIndex(1)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        handleDragChanged(value: value, geometry: geometry)
                    }
                    .onEnded { value in
                        handleDragEnded(value: value, geometry: geometry)
                    }
            )
            .onAppear {
                updateAdjacentPages()
            }
            .onChange(of: currentPageNumber) { newValue in
                // Анимация при изменении страницы через кнопки
                if !isDragging {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        updateAdjacentPages()
                    }
                } else {
                    updateAdjacentPages()
                }
            }
        }
    }
    
    // MARK: - Page View
    
    @ViewBuilder
    private func pageView(for pageNumber: Int) -> some View {
        if let page = pdfDocument.page(at: pageNumber) {
            GeometryReader { pageGeometry in
                PDFPageView(page: page, scale: calculateScale(for: pageGeometry.size))
                    .background(Color.white)
                    .cornerRadius(4)
                    .shadow(
                        color: Color.black.opacity(0.15),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            }
        } else {
            Color.white
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Страница \(pageNumber + 1)")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                )
                .cornerRadius(4)
        }
    }
    
    private func calculateScale(for size: CGSize) -> CGFloat {
        // Вычисляем оптимальный масштаб для страницы
        guard let page = pdfDocument.page(at: currentPageNumber) else { return 2.0 }
        let pageRect = page.bounds(for: .mediaBox)
        let scaleX = size.width / pageRect.width
        let scaleY = size.height / pageRect.height
        return min(scaleX, scaleY, 3.0) // Ограничиваем максимальный масштаб
    }
    
    // MARK: - Gesture Handling
    
    private func handleDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        if !isDragging {
            isDragging = true
            updateAdjacentPages()
        }
        
        dragOffset = value.translation.width
        
        // Ограничиваем движение с более плавным эффектом
        let maxOffset = geometry.size.width * 0.8
        if dragOffset > maxOffset {
            dragOffset = maxOffset + (value.translation.width - maxOffset) * 0.3
        } else if dragOffset < -maxOffset {
            dragOffset = -maxOffset + (value.translation.width + maxOffset) * 0.3
        }
        
        // Вычисляем прогресс перелистывания для эффекта
        pageFlipProgress = abs(dragOffset) / geometry.size.width
    }
    
    private func handleDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        let threshold = geometry.size.width * 0.25
        let velocity = value.predictedEndTranslation.width - value.translation.width
        
        // Используем более плавную анимацию с эффектом перелистывания
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0.3)) {
            if dragOffset > threshold || velocity > 400 {
                // Переход на предыдущую страницу
                goToPreviousPage()
            } else if dragOffset < -threshold || velocity < -400 {
                // Переход на следующую страницу
                goToNextPage()
            } else {
                // Возврат на текущую страницу с эффектом отскока
                dragOffset = 0
                pageFlipProgress = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isDragging = false
            dragOffset = 0
            pageFlipProgress = 0
            updateAdjacentPages()
        }
    }
    
    // MARK: - Navigation
    
    private func goToNextPage() {
        guard currentPageNumber < pdfDocument.pageCount - 1 else {
            dragOffset = 0
            return
        }
        
        // Анимация перехода на следующую страницу
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dragOffset = -1000 // Анимация сдвига влево
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            currentPageNumber += 1
            onPageChanged?(currentPageNumber)
            dragOffset = 0
        }
    }
    
    private func goToPreviousPage() {
        guard currentPageNumber > 0 else {
            dragOffset = 0
            return
        }
        
        // Анимация перехода на предыдущую страницу
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dragOffset = 1000 // Анимация сдвига вправо
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            currentPageNumber -= 1
            onPageChanged?(currentPageNumber)
            dragOffset = 0
        }
    }
    
    private func updateAdjacentPages() {
        previousPageNumber = currentPageNumber > 0 ? currentPageNumber - 1 : nil
        nextPageNumber = currentPageNumber < pdfDocument.pageCount - 1 ? currentPageNumber + 1 : nil
    }
}

// MARK: - Page Flip Animation Extension

extension PDFBookView {
    /// Анимация перелистывания страницы (page curl effect)
    static func pageFlipTransition() -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

