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
    @Binding var showNavigationBar: Bool
    let pdfDocument: PDFDocument?
    let currentPageNumber: Int
    let onScanComplete: ((UIImage, String) -> Void)?
    
    @State private var selectionRect: CGRect = CGRect(x: 100, y: 200, width: 200, height: 150)
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var isResizing: Bool = false
    @State private var resizeCorner: ResizeCorner = .none
    @State private var showScanButton: Bool = true
    @State private var initialRect: CGRect = .zero
    
    // MARK: - Screenshot Animation States
    @State private var isCapturingScreenshot = false
    @State private var showFlashEffect = false
    @State private var showLoadingIndicator = false
    @State private var hideInterface = false
    
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
        ZStack {
            // Фон на весь экран (включая safe area)
            Color.black.opacity(0.1)
                .ignoresSafeArea(.all)
            
            GeometryReader { geometry in
                ZStack {
                    // Выбранная область с рамкой
                    if !hideInterface {
                        selectionFrame(geometry: geometry)
                    }
                    
                    // Кнопка сканирования
                    if showScanButton && !hideInterface {
                        scanButton
                            .position(
                                x: selectionRect.midX,
                                y: selectionRect.maxY + 30
                            )
                    }
                    
                    // Кнопка закрытия
                    if !hideInterface {
                        closeButton
                            .position(
                                x: selectionRect.midX,
                                y: selectionRect.minY - 60
                            )
                    }
                    
                    // Эффект вспышки для скриншота
                    if showFlashEffect {
                        Rectangle()
                            .fill(Color.white)
                            .ignoresSafeArea()
                            .zIndex(400)
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showFlashEffect = false
                                }
                            }
                    }
                    
                    // Лоадер после скриншота
                    if showLoadingIndicator {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                
                                Text("Обработка области...")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.regularMaterial)
                            )
                        }
                        .zIndex(500)
                    }
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
                            initialRect = .zero
                        }
                )
            }
        }
        .onAppear {
            // Инициализируем рамку по центру экрана
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    let screenSize = window.bounds.size
                    let frameWidth = min(screenSize.width * 0.6, 300)
                    let frameHeight = min(screenSize.height * 0.4, 200)
                    selectionRect = CGRect(
                        x: (screenSize.width - frameWidth) / 2,
                        y: (screenSize.height - frameHeight) / 2,
                        width: frameWidth,
                        height: frameHeight
                    )
                }
            }
        }
        .ignoresSafeArea(.all)
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
            .fill(
                Color.black.opacity(0.4),
                style: FillStyle(eoFill: true)
            )
            
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
                    .stroke(Color.white, lineWidth: 3)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Buttons
    
    private var scanButton: some View {
        Button {
            performScan()
            showNavigationBar = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("Выделить")
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
//            .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var closeButton: some View {
        Button {
            withAnimation {
                isPresented = false
                showNavigationBar = true
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
        let screenRect = geometry.frame(in: .local)
        
        // Проверяем начало жеста
        if !isDragging && !isResizing {
            let corner = detectCorner(at: value.startLocation)
            
            if corner != .none {
                // Начинаем изменение размера
                isResizing = true
                resizeCorner = corner
                initialRect = selectionRect
            } else if selectionRect.contains(value.startLocation) {
                // Начинаем перемещение
                isDragging = true
                initialRect = selectionRect
            }
        }
        
        if isDragging {
            // Перемещение рамки
            let deltaX = value.translation.width
            let deltaY = value.translation.height
            
            let newX = initialRect.origin.x + deltaX
            let newY = initialRect.origin.y + deltaY
            
            // Ограничиваем перемещение границами экрана
            let clampedX = max(0, min(newX, screenRect.width - selectionRect.width))
            let clampedY = max(0, min(newY, screenRect.height - selectionRect.height))
            
            selectionRect.origin = CGPoint(x: clampedX, y: clampedY)
            
        } else if isResizing {
            // Изменение размера
            let deltaX = value.translation.width
            let deltaY = value.translation.height
            
            var newRect = initialRect
            
            switch resizeCorner {
            case .topLeft:
                newRect.origin.x = max(0, min(initialRect.maxX - minSize.width, initialRect.origin.x + deltaX))
                newRect.origin.y = max(0, min(initialRect.maxY - minSize.height, initialRect.origin.y + deltaY))
                newRect.size.width = max(minSize.width, initialRect.maxX - newRect.origin.x)
                newRect.size.height = max(minSize.height, initialRect.maxY - newRect.origin.y)
                
            case .topRight:
                newRect.origin.y = max(0, min(initialRect.maxY - minSize.height, initialRect.origin.y + deltaY))
                newRect.size.width = max(minSize.width, min(screenRect.width - initialRect.origin.x, initialRect.width + deltaX))
                newRect.size.height = max(minSize.height, initialRect.maxY - newRect.origin.y)
                
            case .bottomLeft:
                newRect.origin.x = max(0, min(initialRect.maxX - minSize.width, initialRect.origin.x + deltaX))
                newRect.size.width = max(minSize.width, initialRect.maxX - newRect.origin.x)
                newRect.size.height = max(minSize.height, min(screenRect.height - initialRect.origin.y, initialRect.height + deltaY))
                
            case .bottomRight:
                newRect.size.width = max(minSize.width, min(screenRect.width - initialRect.origin.x, initialRect.width + deltaX))
                newRect.size.height = max(minSize.height, min(screenRect.height - initialRect.origin.y, initialRect.height + deltaY))
                
            case .none:
                break
            }
            
            // Ограничиваем размер границами экрана
            newRect.origin.x = max(0, min(newRect.origin.x, screenRect.width - newRect.size.width))
            newRect.origin.y = max(0, min(newRect.origin.y, screenRect.height - newRect.size.height))
            
            selectionRect = newRect
        }
    }
    
    private func detectCorner(at point: CGPoint) -> ResizeCorner {
        let cornerRadius: CGFloat = 30  // Увеличиваем радиус для лучшего обнаружения
        
        let topLeft = CGPoint(x: selectionRect.minX, y: selectionRect.minY)
        let topRight = CGPoint(x: selectionRect.maxX, y: selectionRect.minY)
        let bottomLeft = CGPoint(x: selectionRect.minX, y: selectionRect.maxY)
        let bottomRight = CGPoint(x: selectionRect.maxX, y: selectionRect.maxY)
        
        // Проверяем углы в порядке приоритета
        if distance(point, to: topLeft) < cornerRadius {
            return .topLeft
        } else if distance(point, to: topRight) < cornerRadius {
            return .topRight
        } else if distance(point, to: bottomLeft) < cornerRadius {
            return .bottomLeft
        } else if distance(point, to: bottomRight) < cornerRadius {
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
        guard !isCapturingScreenshot else { return }
        
        isCapturingScreenshot = true
        print("📸 [AreaSelectionView] Начинаем анимированный скриншот области...")
        
        // Сохраняем координаты выбранной области для передачи в ИИ
        let selectedArea = selectionRect
        print("📐 [AreaSelectionView] Координаты выбранной области: \(selectedArea)")
        
        // 1. СНАЧАЛА делаем скриншот С ВИДИМОЙ РАМКОЙ
        let screenshotWithFrame = captureScreenshotWithFrame()
        
        // 2. Скрываем интерфейс выбора области для анимации
        withAnimation(.easeOut(duration: 0.3)) {
            hideInterface = true
            showScanButton = false
        }
        
        // 3. Ждем завершения анимации скрытия и показываем эффекты
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.showAnimationEffects(screenshot: screenshotWithFrame, selectedArea: selectedArea)
        }
    }
    
    private func captureScreenshotWithFrame() -> UIImage? {
        print("📸 [AreaSelectionView] Создание скриншота С ВИДИМОЙ РАМКОЙ...")
        
        // Получаем окно для создания скриншота
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("❌ [AreaSelectionView] Не удалось получить окно для скриншота")
            return nil
        }
        
        // Создаем скриншот с видимой рамкой выбора
        let bounds = window.bounds
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let screenshotWithFrame = renderer.image { context in
            window.layer.render(in: context.cgContext)
        }
        
        print("📸 [AreaSelectionView] Скриншот с рамкой создан: \(screenshotWithFrame.size)")
        print("🔲 [AreaSelectionView] Рамка видна на скриншоте для ИИ анализа")
        
        return screenshotWithFrame
    }
    
    private func showAnimationEffects(screenshot: UIImage?, selectedArea: CGRect) {
        guard let screenshot = screenshot else {
            print("❌ [AreaSelectionView] Скриншот не получен, прерываем процесс")
            resetScanState()
            return
        }
        
        // 1. Показываем эффект вспышки
        withAnimation(.easeOut(duration: 0.1)) {
            showFlashEffect = true
        }
        
        // 2. После вспышки показываем лоадер
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.showLoadingIndicator = true
            }
            
            // 3. Обрабатываем скриншот с рамкой
            self.processScreenshotWithFrame(screenshot, selectedArea: selectedArea)
            
            // 4. Через 2 секунды закрываем
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.finishScanWithFrame(screenshot, selectedArea: selectedArea)
            }
        }
    }
    
    private func processScreenshotWithFrame(_ screenshot: UIImage, selectedArea: CGRect) {
        // Мок обработки - имитация распознавания текста с видимой рамкой
        print("🔍 [AreaSelectionView] Обработка скриншота с видимой рамкой...")
        print("📐 [AreaSelectionView] Область интереса: \(selectedArea)")
        print("🖼️ [AreaSelectionView] Размер скриншота: \(screenshot.size)")
        print("🔲 [AreaSelectionView] ИИ может видеть рамку на изображении")
        
        // В дальнейшем здесь будет:
        // - Отправка скриншота С РАМКОЙ в ИИ
        // - Промпт: "Проанализируй содержимое внутри синей рамки на этом скриншоте"
        // - ИИ сам определит что находится внутри видимой рамки
    }
    
    private func finishScanWithFrame(_ screenshot: UIImage, selectedArea: CGRect) {
        // Создаем мок результат распознавания с указанием на видимую рамку
        let mockText = """
        📸 Анализ содержимого внутри ВИДИМОЙ РАМКИ на скриншоте.
        
        🔲 На изображении видна синяя рамка выбора области.
        📐 Координаты рамки: x=\(Int(selectedArea.origin.x)), y=\(Int(selectedArea.origin.y)), width=\(Int(selectedArea.width)), height=\(Int(selectedArea.height))
        
        🤖 ИИ анализирует содержимое ВНУТРИ ВИДИМОЙ РАМКИ:
        • Может видеть точные границы выбранной области
        • Определяет текст, изображения, элементы UI внутри рамки
        • Игнорирует содержимое за пределами рамки
        
        💡 Промпт для ИИ: "Проанализируй содержимое внутри синей рамки на этом скриншоте"
        
        ✅ Распознавание выполнено с помощью мок-запроса.
        """
        
        print("✅ [AreaSelectionView] Скриншот с рамкой обработан:")
        print(mockText)
        
        // Вызываем callback со СКРИНШОТОМ С РАМКОЙ и текстом
        onScanComplete?(screenshot, mockText)
        
        // Закрываем view
        withAnimation {
            isPresented = false
        }
    }
    
    private func resetScanState() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showLoadingIndicator = false
            hideInterface = false
            showScanButton = true
        }
        isCapturingScreenshot = false
        print("❌ [AreaSelectionView] Сканирование прервано, интерфейс восстановлен")
    }
    
    // MARK: - Legacy Cropping Functions (Deprecated)
    // Эти функции больше не используются, так как теперь делается полный скриншот
    /*
    private func cropScreenArea() -> UIImage? {
        print("📱 [AreaSelectionView] Создаем скриншот экрана для обрезки области...")
        
        // Получаем окно для создания скриншота
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("❌ [AreaSelectionView] Не удалось получить окно для скриншота")
            return nil
        }
        
        // Создаем скриншот всего экрана
        let bounds = window.bounds
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let fullScreenshot = renderer.image { context in
            window.layer.render(in: context.cgContext)
        }
        
        print("📸 [AreaSelectionView] Полный скриншот создан: \(fullScreenshot.size)")
        print("✂️ [AreaSelectionView] Область обрезки: \(selectionRect)")
        
        // Обрезаем изображение по выбранной области
        let scale = UIScreen.main.scale
        let cropRect = CGRect(
            x: selectionRect.origin.x * scale,
            y: selectionRect.origin.y * scale,
            width: selectionRect.width * scale,
            height: selectionRect.height * scale
        )
        
        guard let cgImage = fullScreenshot.cgImage,
              let croppedCGImage = cgImage.cropping(to: cropRect) else {
            print("❌ [AreaSelectionView] Не удалось обрезать изображение")
            return nil
        }
        
        let croppedImage = UIImage(cgImage: croppedCGImage)
        print("✅ [AreaSelectionView] Область успешно обрезана: \(croppedImage.size)")
        
        return croppedImage
    }
    */
    
    /*
    /*
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
        let _ = UIScreen.main.scale
        
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
    */
    
    // MARK: - Legacy Binary Conversion and Text Recognition (Deprecated)
    // Эти функции больше не используются с новой логикой полного скриншота
    /*
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
            print("⚠️ [AreaSelectionView] Не удалось создать контекст")
            return nil
        }
        
        // Рендерим оригинальное изображение в серый контекст
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Получаем серое изображение
        guard let grayImage = context.makeImage() else {
            print("⚠️ [AreaSelectionView] Не удалось создать серое изображение")
            return nil
        }
        
        // Преобразуем в бинарное (черно-белое) изображение
        guard let binaryContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        
        // Применяем пороговое значение для бинаризации
        binaryContext.interpolationQuality = .none
        binaryContext.draw(grayImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let cgImage2 = binaryContext.makeImage() else {
            return nil
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
    */
        
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
    */
}

// MARK: - Preview

