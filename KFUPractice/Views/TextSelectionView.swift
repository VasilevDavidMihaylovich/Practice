//
//  TextSelectionView.swift
//  KFUPractice
//
//  Universal Text Selection Component with Copy and AI functionality
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation

/// Универсальный компонент для выделения текста с действиями
struct UniversalSelectableText: View {
    @Binding var text: String
    @Binding var fontSize: Double
    @Binding var fontName: String
    @Binding var textColor: Color
    @Binding var lineSpacing: Double
    
    let onTextSelected: (String) -> Void
    let onTextChanged: ((String) -> Void)?
    let onSettingsChanged: (() -> Void)?
    
    // Основной конструктор с Binding переменными
    init(
        text: Binding<String>,
        fontSize: Binding<Double>,
        fontName: Binding<String>,
        textColor: Binding<Color>,
        lineSpacing: Binding<Double>,
        onTextSelected: @escaping (String) -> Void,
        onTextChanged: ((String) -> Void)? = nil,
        onSettingsChanged: (() -> Void)? = nil
    ) {
        self._text = text
        self._fontSize = fontSize
        self._fontName = fontName
        self._textColor = textColor
        self._lineSpacing = lineSpacing
        self.onTextSelected = onTextSelected
        self.onTextChanged = onTextChanged
        self.onSettingsChanged = onSettingsChanged
    }
    
    // Конструктор с ReadingSettings
    init(
        text: Binding<String>,
        settings: Binding<ReadingSettings>,
        onTextSelected: @escaping (String) -> Void,
        onTextChanged: ((String) -> Void)? = nil,
        onSettingsChanged: (() -> Void)? = nil
    ) {
        self._text = text
        self._fontSize = Binding(
            get: { settings.wrappedValue.fontSize },
            set: { settings.wrappedValue.fontSize = $0 }
        )
        self._fontName = Binding(
            get: { settings.wrappedValue.fontName },
            set: { settings.wrappedValue.fontName = $0 }
        )
        self._textColor = Binding(
            get: { settings.wrappedValue.theme.textColor },
            set: { _ in }
        )
        self._lineSpacing = Binding(
            get: { settings.wrappedValue.lineSpacing },
            set: { settings.wrappedValue.lineSpacing = $0 }
        )
        self.onTextSelected = onTextSelected
        self.onTextChanged = onTextChanged
        self.onSettingsChanged = onSettingsChanged
    }
    
    // Конструктор для обратной совместимости с SwiftUI Font (создает локальные @State)
    init(
        text: String, 
        font: Font, 
        textColor: Color, 
        lineSpacing: CGFloat, 
        onTextSelected: @escaping (String) -> Void
    ) {
        // Создаем локальные State для совместимости
        self._text = .constant(text)
        self._textColor = .constant(textColor)
        self._lineSpacing = .constant(Double(lineSpacing))
        self.onTextSelected = onTextSelected
        self.onTextChanged = nil
        self.onSettingsChanged = nil
        
        // Извлечение параметров из SwiftUI Font
        let fontDescription = String(describing: font)
        
        // Поиск размера шрифта
        var extractedFontSize: Double = 17
        if let sizeRange = fontDescription.range(of: "size: ") {
            let afterSize = fontDescription[sizeRange.upperBound...]
            if let endRange = afterSize.range(of: ",") ?? afterSize.range(of: ")") {
                let sizeString = String(afterSize[..<endRange.lowerBound])
                if let size = Double(sizeString.trimmingCharacters(in: .whitespaces)) {
                    extractedFontSize = size
                }
            }
        }
        self._fontSize = .constant(extractedFontSize)
        
        // Определение типа шрифта
        var extractedFontName = "System"
        if fontDescription.contains("system") {
            extractedFontName = "System"
        } else if let nameRange = fontDescription.range(of: "name: \"") {
            let afterName = fontDescription[nameRange.upperBound...]
            if let endRange = afterName.range(of: "\"") {
                extractedFontName = String(afterName[..<endRange.lowerBound])
            }
        }
        self._fontName = .constant(extractedFontName)
    }
    
    var body: some View {
        GeometryReader { geometry in
            SelectableTextUIView(
                text: $text,
                fontSize: $fontSize,
                fontName: $fontName,
                textColor: $textColor,
                lineSpacing: $lineSpacing,
                availableWidth: geometry.size.width,
                onTextSelected: onTextSelected,
                onTextChanged: onTextChanged,
                onSettingsChanged: onSettingsChanged
            )
        }
    }
}

/// UIViewRepresentable с правильной шириной и поддержкой Binding
struct SelectableTextUIView: UIViewRepresentable {
    @Binding var text: String
    @Binding var fontSize: Double
    @Binding var fontName: String
    @Binding var textColor: Color
    @Binding var lineSpacing: Double
    
    let availableWidth: CGFloat
    let onTextSelected: (String) -> Void
    let onTextChanged: ((String) -> Void)?
    let onSettingsChanged: (() -> Void)?
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = UIColor.clear
        textView.delegate = context.coordinator
        
        setupTextContainer(textView: textView)
        setupTextAppearance(textView: textView)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Обновляем координатор с новыми колбеками
        context.coordinator.onTextSelected = onTextSelected
        context.coordinator.onTextChanged = onTextChanged
        context.coordinator.onSettingsChanged = onSettingsChanged
        
        setupTextContainer(textView: uiView)
        setupTextAppearance(textView: uiView)
    }
    
    private func setupTextContainer(textView: UITextView) {
        // Убираем отступы
        textView.textContainerInset = UIEdgeInsets.zero
        textView.textContainer.lineFragmentPadding = 0
        
        // ВАЖНО: Устанавливаем фиксированную ширину для правильного переноса
        textView.textContainer.size = CGSize(
            width: max(200, availableWidth), 
            height: .greatestFiniteMagnitude
        )
        
        // Настройки переноса
        textView.textContainer.widthTracksTextView = false // Отключаем автоматическое отслеживание
        textView.textContainer.heightTracksTextView = true
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0
        
        // Отключаем прокрутку
        textView.showsHorizontalScrollIndicator = false
        textView.showsVerticalScrollIndicator = false
        textView.bounces = false
        textView.isScrollEnabled = false
        
        // Дополнительные настройки
        textView.layoutManager.allowsNonContiguousLayout = false
        textView.layoutManager.usesFontLeading = true
    }
    
    private func setupTextAppearance(textView: UITextView) {
        // Создание UIFont с конверсией Double -> CGFloat
        let uiFont: UIFont
        if fontName == "System" {
            uiFont = UIFont.systemFont(ofSize: CGFloat(fontSize))
        } else {
            uiFont = UIFont(name: fontName, size: CGFloat(fontSize)) ?? UIFont.systemFont(ofSize: CGFloat(fontSize))
        }
        
        // Настройка параграфа
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(lineSpacing)
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .natural
        paragraphStyle.hyphenationFactor = 0.8
        
        // Создаем атрибутированный текст
        let attributes: [NSAttributedString.Key: Any] = [
            .font: uiFont,
            .foregroundColor: UIColor(textColor),
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        textView.attributedText = attributedString
        
        // Принудительно обновляем layout
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTextSelected: onTextSelected,
            onTextChanged: onTextChanged,
            onSettingsChanged: onSettingsChanged
        )
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var onTextSelected: (String) -> Void
        var onTextChanged: ((String) -> Void)?
        var onSettingsChanged: (() -> Void)?
        
        init(
            onTextSelected: @escaping (String) -> Void,
            onTextChanged: ((String) -> Void)? = nil,
            onSettingsChanged: (() -> Void)? = nil
        ) {
            self.onTextSelected = onTextSelected
            self.onTextChanged = onTextChanged
            self.onSettingsChanged = onSettingsChanged
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let selectedRange = textView.selectedTextRange,
                  !selectedRange.isEmpty else { return }
            
            let selectedText = textView.text(in: selectedRange) ?? ""
            if !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                onTextSelected(selectedText)
            }
        }
        
        // Добавляем поддержку изменения текста (если нужна)
        func textViewDidChange(_ textView: UITextView) {
            onTextChanged?(textView.text)
        }
        
        // Дополнительные методы для обработки взаимодействий
        func textViewDidBeginEditing(_ textView: UITextView) {
            onSettingsChanged?()
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            onSettingsChanged?()
        }
    }
}

/// Компонент с кнопками действий для выделенного текста
struct TextSelectionActionsView: View {
    let selectedText: String
    let onCopy: () -> Void
    let onAskAI: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Заголовок
            VStack(spacing: 12) {
                Text("Выделенный текст")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Предпросмотр выделенного текста
                ScrollView {
                    Text(selectedText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                }
                .frame(maxHeight: 100)
            }
            
            // Кнопки действий
            VStack(spacing: 12) {
                // Кнопка "Копировать"
                Button(action: {
                    onCopy()
                    onDismiss()
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Копировать")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Кнопка "Спросить ИИ"
                Button(action: {
                    onAskAI()
                    onDismiss()
                }) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text("Спросить ИИ")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Кнопка "Отменить"
                Button("Отменить", action: onDismiss)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 10)
        )
    }
}

/// Утилита для работы с буфером обмена
struct ClipboardManager {
    /// Копирует текст в буфер обмена
    static func copy(_ text: String) {
        UIPasteboard.general.setValue(text, forPasteboardType: UTType.plainText.identifier)
        
        // Можно добавить уведомление об успешном копировании
        print("📋 Текст скопирован в буфер обмена: \(text.prefix(50))...")
    }
    
    /// Получает текст из буфера обмена
    static func paste() -> String? {
        return UIPasteboard.general.string
    }
}

/// Пример использования с Binding переменными
struct BindingTextExample: View {
    @State private var text = "Интерактивный текст с Binding. Попробуйте выделить этот текст и посмотреть как работают новые возможности компонента."
    @State private var fontSize: Double = 18
    @State private var fontName = "System"
    @State private var textColor = Color.blue
    @State private var lineSpacing: Double = 6
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Пример с Binding")
                .font(.title2)
                .bold()
            
            // Основной текстовый компонент
            UniversalSelectableText(
                text: $text,
                fontSize: $fontSize,
                fontName: $fontName,
                textColor: $textColor,
                lineSpacing: $lineSpacing,
                onTextSelected: { selectedText in
                    print("📝 Выделен текст: \(selectedText)")
                },
                onTextChanged: { newText in
                    print("✏️ Текст изменен: \(newText)")
                },
                onSettingsChanged: {
                    print("⚙️ Настройки изменены")
                }
            )
            .frame(height: 200)
            .border(Color.gray, width: 1)
            
            // Элементы управления
            VStack(spacing: 12) {
                HStack {
                    Text("Размер шрифта: \(Int(fontSize))")
                    Slider(value: $fontSize, in: 12...24)
                }
                
                HStack {
                    Text("Интервал: \(Int(lineSpacing))")
                    Slider(value: $lineSpacing, in: 2...10)
                }
                
                HStack {
                    Button("Синий") { textColor = .blue }
                    Button("Красный") { textColor = .red }
                    Button("Зеленый") { textColor = .green }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
    }
}

#Preview {
    BindingTextExample()
}