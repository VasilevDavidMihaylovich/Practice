//
//  NoteDetailView.swift
//  KFUPractice
//
//  Детальный экран заметки для просмотра полной информации
//

import SwiftUI

struct NoteDetailView: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    
                    if let imageData = note.imageData,
                       let uiImage = UIImage(data: imageData) {
                        imageSection(uiImage: uiImage)
                    }
                    
                    contentSection
                    
                    metadataSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Заметка")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Назад") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NoteEditView(note: note)
        }
        .alert("Удалить заметку?", isPresented: $showDeleteAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                deleteNote()
            }
        } message: {
            Text("Это действие нельзя будет отменить.")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: note.type.systemImage)
                    .foregroundColor(note.type == .aiNote ? .purple : note.type == .chart ? .green : .blue)
                    .font(.title)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(note.type == .aiNote ? Color.purple.opacity(0.1) : 
                                  note.type == .chart ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.type.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Страница \(note.pageNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if note.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                }
            }
            
            if !note.tags.isEmpty {
                tagsView
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    private var tagsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(note.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray6))
                        )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Image Section
    
    private func imageSection(uiImage: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Изображение")
                .font(.headline)
                .foregroundColor(.primary)
            
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !note.selectedText.isEmpty {
                selectedTextSection
            }
            
            if let userText = note.userText, !userText.isEmpty {
                userTextSection(userText: userText)
            }
            
            if let aiExplanation = note.aiExplanation, !aiExplanation.isEmpty {
                aiExplanationSection(explanation: aiExplanation)
            }
        }
    }
    
    private var selectedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Выделенный текст")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(note.selectedText)
                .font(.body)
                .lineSpacing(2)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
        }
    }
    
    private func userTextSection(userText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Комментарий")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Если это AI результат, отображаем как Markdown
            if userText.contains("AI результат") || userText.contains("#") || userText.contains("**") {
                                NoteMarkdownView(text: userText)
            } else {
                Text(userText)
                    .font(.body)
                    .lineSpacing(2)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    )
            }
        }
    }
    
    private func aiExplanationSection(explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.purple)
                Text("AI Объяснение")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
                            NoteMarkdownView(text: explanation)
        }
    }
    
    // MARK: - Metadata Section
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Информация")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                metadataRow(title: "Дата создания", value: note.formattedDate)
                metadataRow(title: "Дата изменения", value: note.formattedModifiedDate)
                metadataRow(title: "Позиция", value: "\(Int(note.position.progressPercentage))%")
                
                if note.type == .formula {
                    metadataRow(title: "Тип", value: "Математическая формула")
                } else if note.type == .aiNote {
                    metadataRow(title: "Тип", value: "AI заметка")
                } else if note.type == .chart {
                    metadataRow(title: "Тип", value: "График/диаграмма")
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func metadataRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.callout)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Actions
    
    private func deleteNote() {
        NotesManager.shared.removeNote(with: note.id, for: note.bookId)
        dismiss()
    }
}

// MARK: - Markdown View

/// Компонент для отображения Markdown текста в заметках
struct NoteMarkdownView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseMarkdownLines(text), id: \.id) { line in
                renderLine(line)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private func renderLine(_ line: MarkdownLine) -> some View {
        switch line.type {
        case .header1:
            Text(line.text)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top, 8)
        case .header2:
            Text(line.text)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.top, 6)
        case .header3:
            Text(line.text)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.top, 4)
        case .bold:
            Text(line.text)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        case .listItem:
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body)
                    .foregroundColor(.secondary)
                Text(line.text)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
            }
        case .regular:
            Text(line.text)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(2)
        case .code:
            Text(line.text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(.systemGray5))
                .cornerRadius(6)
        }
    }
}

// MARK: - Markdown Parsing

struct MarkdownLine {
    let id = UUID()
    let text: String
    let type: MarkdownLineType
}

enum MarkdownLineType {
    case header1, header2, header3
    case bold
    case listItem
    case regular
    case code
}

private func parseMarkdownLines(_ text: String) -> [MarkdownLine] {
    let lines = text.components(separatedBy: .newlines)
    var result: [MarkdownLine] = []
    
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        if trimmedLine.isEmpty {
            continue
        }
        
        // Headers
        if trimmedLine.hasPrefix("### ") {
            let text = String(trimmedLine.dropFirst(4))
            result.append(MarkdownLine(text: text, type: .header3))
        } else if trimmedLine.hasPrefix("## ") {
            let text = String(trimmedLine.dropFirst(3))
            result.append(MarkdownLine(text: text, type: .header2))
        } else if trimmedLine.hasPrefix("# ") {
            let text = String(trimmedLine.dropFirst(2))
            result.append(MarkdownLine(text: text, type: .header1))
        }
        // Bold text
        else if trimmedLine.hasPrefix("**") && trimmedLine.hasSuffix("**") && trimmedLine.count > 4 {
            let text = String(trimmedLine.dropFirst(2).dropLast(2))
            result.append(MarkdownLine(text: text, type: .bold))
        }
        // List items
        else if trimmedLine.hasPrefix("- ") {
            let text = String(trimmedLine.dropFirst(2))
            result.append(MarkdownLine(text: text, type: .listItem))
        }
        // Code blocks
        else if trimmedLine.hasPrefix("```") && trimmedLine.hasSuffix("```") && trimmedLine.count > 6 {
            let text = String(trimmedLine.dropFirst(3).dropLast(3))
            result.append(MarkdownLine(text: text, type: .code))
        }
        // Regular text
        else {
            result.append(MarkdownLine(text: trimmedLine, type: .regular))
        }
    }
    
    return result
}

// MARK: - Edit View

struct NoteEditView: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @State private var editedText: String = ""
    @State private var isBookmarked: Bool = false
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Комментарий") {
                    TextEditor(text: $editedText)
                        .frame(minHeight: 100)
                }
                
                Section("Настройки") {
                    Toggle("Добавить в закладки", isOn: $isBookmarked)
                }
                
                Section("Теги") {
                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Spacer()
                            Button("Удалить") {
                                tags.removeAll { $0 == tag }
                            }
                            .foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        TextField("Новый тег", text: $newTag)
                        Button("Добавить") {
                            if !newTag.isEmpty && !tags.contains(newTag) {
                                tags.append(newTag)
                                newTag = ""
                            }
                        }
                        .disabled(newTag.isEmpty)
                    }
                }
            }
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            editedText = note.userText ?? ""
            isBookmarked = note.isBookmarked
            tags = note.tags
        }
    }
    
    private func saveChanges() {
        let updatedNote = Note(
            id: note.id,
            bookId: note.bookId,
            type: note.type,
            selectedText: note.selectedText,
            userText: editedText.isEmpty ? nil : editedText,
            aiExplanation: note.aiExplanation,
            imageData: note.imageData,
            position: note.position,
            pageNumber: note.pageNumber,
            dateCreated: note.dateCreated,
            dateModified: Date(),
            isBookmarked: isBookmarked,
            tags: tags
        )
        
        NotesManager.shared.updateNote(updatedNote)
        print("✅ [NoteDetailView] Заметка \(note.id) обновлена")
    }
}

// MARK: - Extensions

#Preview {
    NoteDetailView(
        note: Note(
            bookId: UUID(),
            type: .aiNote,
            selectedText: "Пример выделенного текста из книги",
            userText: """
            # AI Анализ
            
            ## Ключевые концепции:
            
            - **Основная идея**: Важный концепт для понимания
            - **Практическое применение**: Как использовать на практике
            
            ### Рекомендации:
            
            - Изучите дополнительные материалы
            - Попрактикуйтесь на примерах
            """,
            position: ReadingPosition(pageNumber: 42, progressPercentage: 65.0),
            pageNumber: 42,
            isBookmarked: true,
            tags: ["важное", "AI анализ"]
        )
    )
}