//
//  ReadingView.swift
//  KFUPractice
//
//  AI Reader App
//

import SwiftUI
import PDFKit
import Photos

/// Экран для чтения книги
struct ReadingView: View {
    @StateObject private var viewModel: ReadingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showNavigationBar = true
    @State private var lastTapTime = Date()
    @State private var showAreaSelection: Bool = false
    @State private var capturedContentView: UIView?
    
    // MARK: - Screenshot Animation States
    @State private var isCapturingScreenshot = false
    @State private var showFlashEffect = false
    @State private var showLoadingIndicator = false
    @State private var hideFloatingMenu = false

    init(book: Book) {
        self._viewModel = StateObject(wrappedValue: ReadingViewModel(book: book))
    }
    
    var body: some View {
        GeometryReader { geometry in
            mainContent
                .overlay(overlayContent(geometry: geometry))
        }
        .navigationBarHidden(true)
        .onAppear {
            setupView()
        }
        .onTapGesture {
            handleTap()
        }
        .sheet(isPresented: $viewModel.showSettingsPanel) {
            ReadingSettingsView(settings: $viewModel.readingSettings)
        }
        .refreshable {
            viewModel.id = .init()
        }
        .id(viewModel.id)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Заголовок (скрывается при чтении)
            if showNavigationBar {
                headerView
                    .transition(.move(edge: .top))
            }
            
            // Основной контент
            contentView()
            
            // Панель навигации (скрывается при чтении)  
            if showNavigationBar {
                navigationView
                    .transition(.move(edge: .bottom))
            }
        }
        .background {
            viewModel.readingSettings.theme.backgroundColor
                .ignoresSafeArea(.all, edges: .all)
        }
    }
    
    // MARK: - Overlay Content
    
    @ViewBuilder
    private func overlayContent(geometry: GeometryProxy) -> some View {
        ZStack {
            // Отображение сохраненных рисунков (поверх содержимого)
            if let currentDrawing = viewModel.getDrawing(for: viewModel.currentPageNumber),
               !currentDrawing.isEmpty {
                DrawingOverlayView(drawing: currentDrawing)
                    .allowsHitTesting(false)
                    .zIndex(10)
            }
            
            // Действия с выделенным текстом
            if viewModel.showExplanation {
                textSelectionOverlay(geometry: geometry)
                    .zIndex(50)
            }
            
            // Плавающее меню действий
            if !hideFloatingMenu {
                FloatingActionMenu(
                    pdfDocument: viewModel.pdfDocument,
                    currentPageNumber: viewModel.currentPageNumber,
                    onAreaSelected: {
                        showAreaSelection = true
                    },
                    onDrawingSelected: {
                        viewModel.startDrawing()
                    },
                    onTextScreenshotSelected: {
                        captureScreenshotWithAnimation()
                    }
                )
                .zIndex(100)
            }
            
            // Рамка выбора области для всех типов документов
            if showAreaSelection {
                AreaSelectionView(
                    isPresented: $showAreaSelection,
                    pdfDocument: viewModel.pdfDocument,
                    currentPageNumber: viewModel.currentPageNumber,
                    onScanComplete: { image, text in
                        print("📝 [ReadingView] Распознанный текст: \(text)")
                        print("🖼️ [ReadingView] Скриншот с рамкой: \(image.size)")
                        // Сохраняем скриншот с видимой рамкой в галерею
                        saveImageToGallery(image)
                        print("💾 [ReadingView] Скриншот с рамкой сохранен в галерею")
                        print("🔲 [ReadingView] ИИ сможет видеть выбранную область на изображении")
                        // TODO: Отправить скриншот с рамкой в AI - ИИ увидит границы области
                    }
                )
                .zIndex(200)
            }
            
            // Холст для рисования (полностью прозрачный, поверх всего)
            if viewModel.showDrawingCanvas {
                DrawingCanvasView(
                    isPresented: $viewModel.showDrawingCanvas,
                    initialDrawing: viewModel.currentPageDrawing,
                    onSave: { strokes in
                        viewModel.saveDrawing(strokes: strokes)
                    },
                    onCancel: {
                        viewModel.stopDrawing()
                    }
                )
                .zIndex(300)
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
                        
                        Text("Обработка скриншота...")
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
    }
    
    // MARK: - Text Selection Overlay
    
    @ViewBuilder
    private func textSelectionOverlay(geometry: GeometryProxy) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea(.all)
                .onTapGesture {
                    viewModel.clearSelection()
                }
            
            TextSelectionActionsView(
                selectedText: viewModel.selectedText,
                onCopy: {
                    ClipboardManager.copy(viewModel.selectedText)
                },
                onAskAI: {
                    viewModel.askAIAboutSelectedText()
                },
                onDismiss: {
                    viewModel.clearSelection()
                }
            )
            .frame(maxWidth: min(geometry.size.width - 32, 400))
            .padding(.horizontal, 16)
            .padding(.top, geometry.safeAreaInsets.top + 60)
            .padding(.bottom, geometry.safeAreaInsets.bottom + 60)
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupView() {
        // Принудительно обновляем UI при появлении для корректного отображения настроек
        Task { @MainActor in
            // Если данные уже загружены, убеждаемся что currentPageContent актуальный
            if !viewModel.pages.isEmpty && viewModel.currentPageContent.isEmpty {
                viewModel.refreshCurrentPageContent() // Синхронный вызов для обновления контента
            }
            viewModel.objectWillChange.send()
        }
    }
    
    // MARK: - Screenshot Functionality
    
    private func captureScreenshotWithAnimation() {
        guard !isCapturingScreenshot else { return }
        
        isCapturingScreenshot = true
        print("📸 [ReadingView] Начинаем анимированный скриншот...")
        
        // 1. Скрываем плавающее меню
        withAnimation(.easeOut(duration: 0.3)) {
            hideFloatingMenu = true
        }
        
        // 2. Ждем завершения анимации скрытия и делаем скриншот
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.captureScreenshot()
        }
    }
    
    private func captureScreenshot() {
        print("📸 [ReadingView] Создание скриншота содержимого...")
        
        // Получаем root view для скриншота
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("❌ [ReadingView] Не удалось получить окно для скриншота")
            resetScreenshotState()
            return
        }
        
        // Создаем скриншот области с содержимым
        let bounds = window.bounds
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let screenshot = renderer.image { context in
            window.layer.render(in: context.cgContext)
        }
        
        // 3. Показываем эффект вспышки
        withAnimation(.easeOut(duration: 0.1)) {
            showFlashEffect = true
        }
        
        // 4. После вспышки показываем лоадер
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.showLoadingIndicator = true
            }
            
            // 5. Обрабатываем скриншот
            let finalScreenshot = self.cropToContentArea(screenshot)
            self.saveImageToGallery(finalScreenshot)
            self.viewModel.captureScreenshot(screenshot: finalScreenshot)
            
            // 6. Через 2 секунды скрываем лоадер и восстанавливаем интерфейс
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.resetScreenshotState()
            }
        }
    }
    
    private func resetScreenshotState() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showLoadingIndicator = false
            hideFloatingMenu = false
        }
        isCapturingScreenshot = false
        print("✅ [ReadingView] Скриншот завершен, интерфейс восстановлен")
    }
    
    private func saveImageToGallery(_ image: UIImage) {
        // Проверяем статус разрешений
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            performSave(image)
        case .denied, .restricted:
            print("❌ [ReadingView] Нет разрешения на запись в галерею")
        case .notDetermined:
            // Запрашиваем разрешение
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self.performSave(image)
                    } else {
                        print("❌ [ReadingView] Разрешение на запись в галерею отклонено")
                    }
                }
            }
        @unknown default:
            print("⚠️ [ReadingView] Неизвестный статус разрешений")
        }
    }
    
    private func performSave(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ReadingView] Ошибка сохранения в галерею: \(error.localizedDescription)")
                } else if success {
                    print("✅ [ReadingView] Изображение сохранено в галерею")
                } else {
                    print("⚠️ [ReadingView] Не удалось сохранить изображение")
                }
            }
        }
    }
    
    private func cropToContentArea(_ screenshot: UIImage) -> UIImage {
        // В будущем здесь можно добавить логику обрезки до конкретной области содержимого
        // Пока возвращаем полный скриншот
        return screenshot
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Библиотека")
                        .font(.system(size: 17))
                }
                .foregroundColor(.primary)
            }
            
            Spacer(minLength: 8)
            
            VStack(alignment: .center, spacing: 2) {
                Text(viewModel.book.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if let author = viewModel.book.author {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            
            Spacer(minLength: 8)
            
            Button {
                viewModel.showSettingsPanel = true
            } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
        .safeAreaInset(edge: .top) {
            Rectangle()
                .fill(Color(.systemBackground))
                .frame(height: 0)
        }
    }
    
    // MARK: - Content View
    @ViewBuilder
    private func contentView() -> some View {
        GeometryReader { geometry in
            if viewModel.isLoading {
                loadingView
            } else if viewModel.isChangingPage {
                pageChangingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                // Для PDF используем специальный компонент с анимацией
                if viewModel.book.format == .pdf, let pdfDocument = viewModel.pdfDocument {
                    pdfContentView(pdfDocument: pdfDocument)
                } else {
                    // Для EPUB и TXT используем текстовый контент
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            textContentView()
                        }
                        .frame(minHeight: geometry.size.height)
                    }
                    .padding(.horizontal, max(16, viewModel.readingSettings.horizontalPadding))
                    .clipped()
                }
            }
        }
    }
    
    @ViewBuilder
    private func pdfContentView(pdfDocument: PDFDocument) -> some View {
        PDFBookView(
            pdfDocument: pdfDocument,
            currentPageNumber: $viewModel.currentPageNumber,
            onPageChanged: { pageNumber in
                // Обновляем контент при смене страницы
                viewModel.currentPageNumber = pageNumber
            }
        )
    }
    
    @ViewBuilder
    private func textContentView() -> some View {
        UniversalSelectableText(
            text: $viewModel.currentPageContent,
            settings: $viewModel.readingSettings,
            onTextSelected: { selectedText in
                viewModel.selectText(selectedText)
            },
            onSettingsChanged: {
                // Принудительно обновляем UI при изменении настроек
                Task { @MainActor in
                    viewModel.objectWillChange.send()
                }
            }
        )
        .padding(.top, 20)
        .padding(.bottom, 40) // Extra bottom padding for comfortable reading
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            
            Text("Загрузка страницы...")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var pageChangingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.8)
            
            Text("Переход на страницу \(viewModel.currentPageNumber + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Ошибка загрузки")
                .font(.headline)
            
            Text(error)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Попробовать снова") {
                Task {
                    await viewModel.loadCurrentPage()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Navigation View
    
    private var navigationView: some View {
        VStack(spacing: 12) {
            // Прогресс-бар
            progressBarView
                .padding(.horizontal, 16)
            
            // Кнопки навигации
            HStack(spacing: 20) {
                Button {
                    viewModel.previousPage()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(viewModel.currentPageNumber == 0 ? .secondary : .primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(viewModel.currentPageNumber == 0)
                
                Spacer()
                
                // Индикатор страниц
                VStack(spacing: 4) {
                    Text("\(viewModel.currentPageNumber + 1) из \(viewModel.totalPages)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if let pageCount = viewModel.book.pageCount {
                        Text("Всего \(pageCount) стр.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    viewModel.nextPage()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(viewModel.currentPageNumber >= viewModel.totalPages - 1 ? .secondary : .primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(viewModel.currentPageNumber >= viewModel.totalPages - 1)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            Color(.systemBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: -1)
        )
        .safeAreaInset(edge: .bottom) {
            Rectangle()
                .fill(Color(.systemBackground))
                .frame(height: 0)
        }
    }
    
    private var progressBarView: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.readingProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                .frame(height: 3)
                .background(Color(.systemGray5))
                .cornerRadius(1.5)
            
            HStack {
                Text("\(Int(viewModel.readingProgress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Прогресс чтения")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Interaction Handling
    
    private func handleTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        lastTapTime = now
        
        // Двойной тап - переключаем UI
        if timeSinceLastTap < 0.3 {
            withAnimation(.easeInOut(duration: 0.3)) {
                showNavigationBar.toggle()
            }
        }
    }
}

// MARK: - Reading Settings View

/// Панель настроек чтения
struct ReadingSettingsView: View {
    @Binding var settings: ReadingSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            settingsForm
                .navigationTitle("Настройки чтения")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Готово") {
                            dismiss()
                        }
                    }
                }
        }
    }
    
    private var settingsForm: some View {
        Form {
            fontSection
            themeSection
            previewSection
        }
    }
    
    private var fontSection: some View {
        Section("Шрифт") {
            fontSizeSlider
            lineSpacingSlider
        }
    }
    
    private var fontSizeSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Размер")
                Spacer()
                Text("\(Int(settings.fontSize))")
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: Binding(
                    get: { settings.fontSize },
                    set: { settings = settings.withFontSize($0) }
                ),
                in: ReadingSettings.fontSizeRange,
                step: 1
            )
        }
    }
    
    private var lineSpacingSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Межстрочный интервал")
                Spacer()
                Text(String(format: "%.1f", settings.lineSpacing))
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: Binding(
                    get: { settings.lineSpacing },
                    set: { settings = settings.withLineSpacing($0) }
                ),
                in: ReadingSettings.lineSpacingRange,
                step: 0.1
            )
        }
    }
    
    private var themeSection: some View {
        Section("Тема") {
            ForEach(ReadingTheme.allCases, id: \.rawValue) { theme in
                themeRow(theme)
            }
        }
    }
    
    private func themeRow(_ theme: ReadingTheme) -> some View {
        HStack {
            Image(systemName: theme.systemImage)
                .foregroundColor(theme == .dark ? .white : .primary)
                .frame(width: 24)
            
            Text(theme.displayName)
            
            Spacer()
            
            if settings.theme == theme {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            settings = settings.withTheme(theme)
        }
    }
    
    private var previewSection: some View {
        Section("Предпросмотр") {
            previewText
        }
    }
    
    private var previewText: some View {
        Text("Пример текста для демонстрации выбранных настроек. Квантовая механика описывает поведение материи на атомном уровне.")
            .font(settings.font)
            .lineSpacing(settings.lineSpacing * 4)
            .padding()
            .background(settings.theme.backgroundColor)
            .foregroundColor(settings.theme.textColor)
            .cornerRadius(8)
    }
}

#Preview {
    ReadingView(book: Book.sampleBooks[0])
}
