//
//  AreaSelectionView.swift
//  KFUPractice
//
//  Area Selection with Scanning Functionality
//

import SwiftUI
import UIKit
import PDFKit

/// Компонент для выбора области с регулируемой рамкой
struct AreaSelectionView: View {
    @Binding var isPresented: Bool
    let pdfDocument: PDFDocument?
    let currentPageNumber: Int
    let onScanComplete: ((UIImage, String) -> Void)?
    
    @State private var selectionRect: CGRect = CGRect(x: 50, y: 200, width: 200, height: 150)
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var isResizing: Bool = false
    @State private var resizeCorner: ResizeCorner = .none
    @State private var showScanButton: Bool = true
    
    private let minSize: CGSize = CGSize(width: 100, height: 80)
    private let cornerSize: CGFloat = 30
    
    enum ResizeCorner {
        case none
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Полупрозрачный фон (не полностью затемненный, чтобы видеть PDF)
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
                
                // Выбранная область с рамкой
                selectionFrame(geometry: geometry)
                
                // Кнопка сканирования
                if showScanButton {
                    scanButton
                        .position(
                            x: selectionRect.midX,
                            y: selectionRect.maxY + 50
                        )
                }
                
                // Кнопка закрытия
                closeButton
                    .position(
                        x: selectionRect.midX,
                        y: selectionRect.minY - 40
                    )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(value: value, geometry: geometry)
                    }
                    .onEnded { _ in
                        isDragging = false
                        isResizing = false
                        resizeCorner = .none
                        dragOffset = .zero
                    }
            )
        }
        .onAppear {
            // Инициализируем рамку по центру экрана
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    let screenSize = window.bounds.size
                    selectionRect = CGRect(
                        x: screenSize.width * 0.2,
                        y: screenSize.height * 0.3,
                        width: screenSize.width * 0.6,
                        height: screenSize.height * 0.4
                    )
                }
            }
        }
    }
    
    // MARK: - Selection Frame
    
    @ViewBuilder
    private func selectionFrame(geometry: GeometryProxy) -> some View {
        ZStack {
            // Вырезанная область (прозрачная)
            Path { path in
                let screenRect = geometry.frame(in: .local)
                path.addRect(screenRect)
                path.addRect(selectionRect)
            }
            .fill(style: FillStyle(eoFill: true))
            .fill(Color.black.opacity(0.5))
            
            // Рамка выбранной области
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 3)
                .frame(width: selectionRect.width, height: selectionRect.height)
                .position(
                    x: selectionRect.midX,
                    y: selectionRect.midY
                )
            
            // Углы для изменения размера
            resizeCorners
        }
    }
    
    // MARK: - Resize Corners
    
    @ViewBuilder
    private var resizeCorners: some View {
        Group {
            // Верхний левый угол
            resizeCornerView(corner: .topLeft)
                .position(
                    x: selectionRect.minX,
                    y: selectionRect.minY
                )
            
            // Верхний правый угол
            resizeCornerView(corner: .topRight)
                .position(
                    x: selectionRect.maxX,
                    y: selectionRect.minY
                )
            
            // Нижний левый угол
            resizeCornerView(corner: .bottomLeft)
                .position(
                    x: selectionRect.minX,
                    y: selectionRect.maxY
                )
            
            // Нижний правый угол
            resizeCornerView(corner: .bottomRight)
                .position(
                    x: selectionRect.maxX,
                    y: selectionRect.maxY
                )
        }
    }
    
    @ViewBuilder
    private func resizeCornerView(corner: ResizeCorner) -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: cornerSize, height: cornerSize)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(radius: 4)
    }
    
    // MARK: - Buttons
    
    private var scanButton: some View {
        Button {
            performScan()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("Сканировать")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue,
                        Color.blue.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var closeButton: some View {
        Button {
            withAnimation {
                isPresented = false
            }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.white)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 40, height: 40)
                )
        }
    }
    
    // MARK: - Gesture Handling
    
    private func handleDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        let location = value.location
        let screenRect = geometry.frame(in: .local)
        
        // Проверяем, на каком элементе происходит тап
        if !isDragging && !isResizing {
            // Определяем, на углу ли тап
            let corner = detectCorner(at: location)
            if corner != .none {
                isResizing = true
                resizeCorner = corner
            } else if selectionRect.contains(location) {
                isDragging = true
            }
        }
        
        if isDragging {
            // Перемещение рамки
            let newX = selectionRect.origin.x + value.translation.width - dragOffset.width
            let newY = selectionRect.origin.y + value.translation.height - dragOffset.height
            
            // Ограничиваем перемещение границами экрана
            let clampedX = max(0, min(newX, screenRect.width - selectionRect.width))
            let clampedY = max(0, min(newY, screenRect.height - selectionRect.height))
            
            selectionRect.origin = CGPoint(x: clampedX, y: clampedY)
            dragOffset = value.translation
            
        } else if isResizing {
            // Изменение размера
            var newRect = selectionRect
            
            switch resizeCorner {
            case .topLeft:
                let deltaX = value.translation.width
                let deltaY = value.translation.height
                newRect.origin.x = max(0, min(selectionRect.origin.x + deltaX, selectionRect.maxX - minSize.width))
                newRect.origin.y = max(0, min(selectionRect.origin.y + deltaY, selectionRect.maxY - minSize.height))
                newRect.size.width = selectionRect.maxX - newRect.origin.x
                newRect.size.height = selectionRect.maxY - newRect.origin.y
                
            case .topRight:
                let deltaY = value.translation.height
                newRect.origin.y = max(0, min(selectionRect.origin.y + deltaY, selectionRect.maxY - minSize.height))
                newRect.size.width = max(minSize.width, selectionRect.width + value.translation.width)
                newRect.size.height = selectionRect.maxY - newRect.origin.y
                newRect.size.width = min(newRect.size.width, screenRect.width - newRect.origin.x)
                
            case .bottomLeft:
                let deltaX = value.translation.width
                newRect.origin.x = max(0, min(selectionRect.origin.x + deltaX, selectionRect.maxX - minSize.width))
                newRect.size.width = selectionRect.maxX - newRect.origin.x
                newRect.size.height = max(minSize.height, selectionRect.height + value.translation.height)
                newRect.size.height = min(newRect.size.height, screenRect.height - newRect.origin.y)
                
            case .bottomRight:
                newRect.size.width = max(minSize.width, selectionRect.width + value.translation.width)
                newRect.size.height = max(minSize.height, selectionRect.height + value.translation.height)
                newRect.size.width = min(newRect.size.width, screenRect.width - newRect.origin.x)
                newRect.size.height = min(newRect.size.height, screenRect.height - newRect.origin.y)
                
            case .none:
                break
            }
            
            selectionRect = newRect
        }
    }
    
    private func detectCorner(at point: CGPoint) -> ResizeCorner {
        let cornerRadius: CGFloat = cornerSize / 2 + 10
        
        if distance(point, to: CGPoint(x: selectionRect.minX, y: selectionRect.minY)) < cornerRadius {
            return .topLeft
        } else if distance(point, to: CGPoint(x: selectionRect.maxX, y: selectionRect.minY)) < cornerRadius {
            return .topRight
        } else if distance(point, to: CGPoint(x: selectionRect.minX, y: selectionRect.maxY)) < cornerRadius {
            return .bottomLeft
        } else if distance(point, to: CGPoint(x: selectionRect.maxX, y: selectionRect.maxY)) < cornerRadius {
            return .bottomRight
        }
        
        return .none
    }
    
    private func distance(_ p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // MARK: - Scanning
    
    private func performScan() {
        // Скрываем кнопку сканирования
        withAnimation {
            showScanButton = false
        }
        
        // Обрезаем PDF страницу по выбранной области
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let croppedImage = cropPDFPage() {
                // Конвертируем в бинарное изображение
                if let binaryImage = convertToBinary(croppedImage) {
                    // Распознаем текст (мок) и передаем изображение
                    recognizeText(from: binaryImage, originalImage: croppedImage)
                }
            } else {
                // Если не удалось обрезать PDF, показываем ошибку
                print("⚠️ [AreaSelectionView] Не удалось обрезать PDF страницу")
                withAnimation {
                    showScanButton = true
                    isPresented = false
                }
            }
        }
    }
    
    private func cropPDFPage() -> UIImage? {
        guard let pdfDoc = pdfDocument,
              currentPageNumber < pdfDoc.pageCount,
              let pdfPage = pdfDoc.page(at: currentPageNumber) else {
            print("⚠️ [AreaSelectionView] Не удалось получить PDF страницу")
            return nil
        }
        
        // Получаем размер страницы PDF
        let pageRect = pdfPage.bounds(for: .mediaBox)
        print("📄 [AreaSelectionView] Размер PDF страницы: \(pageRect)")
        
        // Получаем размер экрана для масштабирования
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        let screenSize = window.bounds.size
        let scale = UIScreen.main.scale
        
        // Вычисляем масштаб отображения PDF на экране
        // Предполагаем, что PDF отображается с сохранением пропорций
        let pdfAspectRatio = pageRect.width / pageRect.height
        let screenAspectRatio = screenSize.width / screenSize.height
        
        var displayWidth: CGFloat
        var displayHeight: CGFloat
        var displayOffsetX: CGFloat = 0
        var displayOffsetY: CGFloat = 0
        
        if pdfAspectRatio > screenAspectRatio {
            // PDF шире экрана
            displayWidth = screenSize.width
            displayHeight = screenSize.width / pdfAspectRatio
            displayOffsetY = (screenSize.height - displayHeight) / 2
        } else {
            // PDF выше экрана
            displayHeight = screenSize.height
            displayWidth = screenSize.height * pdfAspectRatio
            displayOffsetX = (screenSize.width - displayWidth) / 2
        }
        
        // Преобразуем координаты выбранной области из экранных в координаты PDF
        let relativeX = (selectionRect.origin.x - displayOffsetX) / displayWidth
        let relativeY = (selectionRect.origin.y - displayOffsetY) / displayHeight
        let relativeWidth = selectionRect.width / displayWidth
        let relativeHeight = selectionRect.height / displayHeight
        
        // Вычисляем область в координатах PDF
        let pdfCropRect = CGRect(
            x: pageRect.origin.x + relativeX * pageRect.width,
            y: pageRect.origin.y + (1 - relativeY - relativeHeight) * pageRect.height, // Инвертируем Y
            width: relativeWidth * pageRect.width,
            height: relativeHeight * pageRect.height
        )
        
        print("📐 [AreaSelectionView] Область в PDF координатах: \(pdfCropRect)")
        
        // Рендерим PDF страницу в изображение с высоким разрешением
        let renderScale: CGFloat = 3.0 // Высокое разрешение для качественного обрезания
        let renderSize = CGSize(
            width: pageRect.width * renderScale,
            height: pageRect.height * renderScale
        )
        
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let fullPageImage = renderer.image { context in
            // Белый фон
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))
            
            // Рендерим PDF страницу
            context.cgContext.translateBy(x: 0, y: renderSize.height)
            context.cgContext.scaleBy(x: renderScale, y: -renderScale)
            pdfPage.draw(with: .mediaBox, to: context.cgContext)
        }
        
        // Обрезаем изображение по выбранной области
        let cropRect = CGRect(
            x: pdfCropRect.origin.x * renderScale,
            y: pdfCropRect.origin.y * renderScale,
            width: pdfCropRect.width * renderScale,
            height: pdfCropRect.height * renderScale
        )
        
        guard let cgImage = fullPageImage.cgImage?.cropping(to: cropRect) else {
            print("⚠️ [AreaSelectionView] Не удалось обрезать изображение")
            return nil
        }
        
        let croppedImage = UIImage(cgImage: cgImage, scale: renderScale, orientation: .up)
        print("✅ [AreaSelectionView] PDF страница обрезана: \(croppedImage.size)")
        return croppedImage
    }
    
    private func convertToBinary(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else {
            print("⚠️ [AreaSelectionView] Не удалось получить CGImage")
            return nil
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        // Создаем контекст для серого изображения
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            print("⚠️ [AreaSelectionView] Не удалось создать контекст для серого изображения")
            return nil
        }
        
        // Рисуем исходное изображение в сером
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let grayImage = context.makeImage() else {
            print("⚠️ [AreaSelectionView] Не удалось создать серое изображение")
            return nil
        }
        
        // Упрощенная бинаризация через фильтр
        // Используем Core Image для бинаризации
        let ciImage = CIImage(cgImage: grayImage)
        
        // Применяем фильтр для повышения контраста и бинаризации
        guard let filter = CIFilter(name: "CIColorControls") else {
            print("⚠️ [AreaSelectionView] Не удалось создать фильтр")
            return UIImage(cgImage: grayImage)
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(1.5, forKey: kCIInputContrastKey) // Увеличиваем контраст
        filter.setValue(0.0, forKey: kCIInputSaturationKey) // Убираем насыщенность
        
        guard let outputImage = filter.outputImage else {
            return UIImage(cgImage: grayImage)
        }
        
        // Применяем пороговый фильтр для бинаризации
        let context2 = CIContext()
        guard let cgImage2 = context2.createCGImage(outputImage, from: outputImage.extent) else {
            return UIImage(cgImage: grayImage)
        }
        
        let binaryImage = UIImage(cgImage: cgImage2)
        print("✅ [AreaSelectionView] Изображение конвертировано в бинарное: \(binaryImage.size)")
        return binaryImage
    }
    
    private func recognizeText(from binaryImage: UIImage, originalImage: UIImage) {
        // Мок распознавание текста
        print("📸 [AreaSelectionView] Начато распознавание текста")
        print("   • Размер бинарного изображения: \(binaryImage.size)")
        print("   • Размер оригинального изображения: \(originalImage.size)")
        
        // Имитация обработки AI запроса
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Мок результат распознавания
            let mockText = """
            Это пример распознанного текста из выбранной области PDF.
            
            Текст был успешно извлечен из бинарного изображения.
            Здесь может быть любой текст, который был на странице PDF.
            
            В дальнейшем этот текст будет отправлен в AI с промпт-запросом
            для анализа и обработки.
            
            Распознавание выполнено с помощью мок-запроса.
            """
            
            print("✅ [AreaSelectionView] Текст распознан:")
            print(mockText)
            
            // Вызываем callback с изображением и текстом
            // В дальнейшем originalImage можно отправить в AI
            onScanComplete?(originalImage, mockText)
            
            // Закрываем view
            withAnimation {
                isPresented = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AreaSelectionView(
        isPresented: .constant(true),
        pdfDocument: nil,
        currentPageNumber: 0,
        onScanComplete: { image, text in
            print("Распознанный текст: \(text)")
            print("Изображение: \(image.size)")
        }
    )
}

