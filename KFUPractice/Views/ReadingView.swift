//
//  ReadingView.swift
//  KFUPractice
//
//  AI Reader App
//

import SwiftUI

/// Экран для чтения книги
struct ReadingView: View {
    @StateObject private var viewModel: ReadingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showNavigationBar = true
    @State private var lastTapTime = Date()
    
    init(book: Book) {
        self._viewModel = StateObject(wrappedValue: ReadingViewModel(book: book))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Фон с учетом темы
                viewModel.readingSettings.theme.backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Заголовок (скрывается при чтении)
                    if showNavigationBar {
                        headerView
                            .transition(.move(edge: .top))
                    }
                    
                    // Основной контент
                    contentView
                    
                    // Панель навигации (скрывается при чтении)
                    if showNavigationBar {
                        navigationView
                            .transition(.move(edge: .bottom))
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onTapGesture {
            handleTap()
        }
        .sheet(isPresented: $viewModel.showSettingsPanel) {
            ReadingSettingsView(settings: $viewModel.readingSettings)
        }
        .overlay(
            // AI объяснение
            Group {
                if viewModel.showExplanation {
                    ExplanationPopoverView(
                        selectedText: viewModel.selectedText,
                        onDismiss: viewModel.clearSelection
                    )
                }
            }
        )
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Библиотека")
                }
                .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.book.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let author = viewModel.book.author {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                viewModel.showSettingsPanel = true
            } label: {
                Image(systemName: "textformat.size")
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else {
                    textContentView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, viewModel.readingSettings.horizontalPadding)
    }
    
    private var textContentView: some View {
        SelectableText(
            text: viewModel.currentPageContent,
            font: viewModel.readingSettings.font,
            textColor: viewModel.readingSettings.theme.textColor,
            lineSpacing: viewModel.readingSettings.lineSpacing,
            onTextSelected: { selectedText in
                viewModel.selectText(selectedText)
            }
        )
        .padding(.vertical, 20)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            
            Text("Загрузка страницы...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        VStack(spacing: 8) {
            // Прогресс-бар
            progressBarView
            
            // Кнопки навигации
            HStack {
                Button {
                    viewModel.previousPage()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                .disabled(viewModel.currentPageNumber == 0)
                
                Spacer()
                
                // Индикатор страниц
                Text("\(viewModel.currentPageNumber + 1) из \(viewModel.totalPages)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    viewModel.nextPage()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
                .disabled(viewModel.currentPageNumber >= viewModel.totalPages - 1)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
    
    private var progressBarView: some View {
        VStack(spacing: 4) {
            ProgressView(value: viewModel.readingProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 4)
            
            HStack {
//                Text("\(Int(viewModel.readingProgress * 100))%")
//                    .font(.caption2)
//                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let pageCount = viewModel.book.pageCount {
                    Text("\(pageCount) стр.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
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

// MARK: - Selectable Text View

/// Компонент для отображения текста с возможностью выделения
struct SelectableText: View {
    let text: String
    let font: Font
    let textColor: Color
    let lineSpacing: CGFloat
    let onTextSelected: (String) -> Void
    
    @State private var selectedRange: NSRange?
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(textColor)
            .lineSpacing(lineSpacing)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onReceive(NotificationCenter.default.publisher(for: UIMenuController.didShowMenuNotification)) { _ in
                // Когда появляется контекстное меню, можем обработать выделенный текст
                handleTextSelection()
            }
    }
    
    private func handleTextSelection() {
        // TODO: Получить выделенный текст
        // Пока используем заглушку
        let selectedText = "выделенный текст" // Заглушка
        if !selectedText.isEmpty {
            onTextSelected(selectedText)
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

// MARK: - Explanation Popover

/// Всплывающее окно с AI объяснением
struct ExplanationPopoverView: View {
    let selectedText: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Объяснение")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Выделенный текст:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(selectedText)
                .font(.body)
                .padding(.vertical, 4)
            
            Divider()
            
            // TODO: Здесь будет реальное объяснение от AI
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                        .scaleEffect(0.8)
                    
                    Text("Получаем объяснение от AI...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // TODO: Заменить на реальный контент от Gemini API
                Text("Здесь будет объяснение от AI после интеграции с Gemini API")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
        .frame(maxWidth: 300)
        .padding()
    }
}

#Preview {
    ReadingView(book: Book.sampleBooks[0])
}
