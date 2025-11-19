import SwiftUI

struct AttributedMarkdownView: View {
    let markdown: String
    
    @State private var attributedString: AttributedString?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                progressView
            } else if let attributedText = attributedString {
                Text(attributedText)
                    .textSelection(.enabled)
                    .font(.body)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                errorView
            }
        }
        .onAppear {
            parseMarkdown()
        }
        .onChange(of: markdown) { _, _ in
            parseMarkdown()
        }
    }
    
    // MARK: - UI
    
    private var progressView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Обработка Markdown...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var errorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text("Ошибка обработки Markdown")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(markdown)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Markdown Parsing
    
    private func parseMarkdown() {
        isLoading = true
        
        Task {
            // 1. Предобработка Markdown под нужный нам рендеринг
            let processedMarkdown = preprocessMarkdown(markdown)
            
            do {
                // 2. Основной парсер — только инлайновый Markdown, переносы сохраняем
                let parsed = try AttributedString(
                    markdown: processedMarkdown,
                    options: AttributedString.MarkdownParsingOptions(
                        allowsExtendedAttributes: true,
                        interpretedSyntax: .inlineOnlyPreservingWhitespace
                    )
                )
                
                await MainActor.run {
                    self.attributedString = applyCustomStyles(to: parsed)
                    self.isLoading = false
                }
            } catch {
                // 3. Фаллбэк — показываем как обычный текст без Markdown
                await MainActor.run {
                    var result = AttributedString(processedMarkdown)
                    result.foregroundColor = .primary
                    self.attributedString = result
                    self.isLoading = false
                }
            }
        }
    }
    
    private func applyCustomStyles(to attributedString: AttributedString) -> AttributedString {
        var result = attributedString
        result.foregroundColor = .primary
        return result
    }
    
    // MARK: - Предобработка Markdown
    
    private func preprocessMarkdown(_ markdown: String) -> String {
        var processed = markdown
        
        // Заголовки: "### ..." -> "\n\n**...**\n\n"
        processed = processed.replacingOccurrences(
            of: #"(?m)^(#{1,6})\s+(.+)$"#,
            with: "\n\n**$2**\n\n",
            options: [.regularExpression]
        )
        
        // Маркированные списки: "- пункт" -> "• пункт"
        processed = processed.replacingOccurrences(
            of: #"(?m)^[\s]*[-*+]\s+(.+)$"#,
            with: "• $1",
            options: [.regularExpression]
        )
        
        // Нумерованные списки: "1. пункт" -> "1) пункт"
        processed = processed.replacingOccurrences(
            of: #"(?m)^[\s]*(\d+)\.\s+(.+)$"#,
            with: "$1) $2",
            options: [.regularExpression]
        )

        // Цитаты: "> текст" -> «текст»
        processed = processed.replacingOccurrences(
            of: #"(?m)^>\s*(.+)$"#,
            with: "«$1»",
            options: [.regularExpression]
        )
        
        // Удаляем лишние повторяющиеся переносы >2
        processed = processed.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: [.regularExpression]
        )
        
        return processed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            AttributedMarkdownView(markdown: """
# Заголовок первого уровня

## Заголовок второго уровня

### Заголовок третьего уровня

Обычный текст с **жирным форматированием** и *курсивом*.

### Списки:

- Первый элемент списка
- Второй элемент списка
  - Вложенный элемент
  - Еще один вложенный элемент

### Нумерованные списки:

1. Первый пункт
2. Второй пункт
3. Третий пункт

### Код:

Встроенный `код` выглядит так.

```
Блок кода:
let example = "Пример кода"
print(example)
```

### Цитата:

> Это важная цитата, которую стоит запомнить.
> Она может быть многострочной.

### Ссылки:

[Ссылка на Apple](https://apple.com)

**Заключение**: AttributedMarkdownView поддерживает основные элементы Markdown.
""")
            
            Divider()
            
            AttributedMarkdownView(markdown: """
## Простой пример

Этот текст содержит **жирное** форматирование и *курсив*.

- Элемент списка 1
- Элемент списка 2

`Код встроенный` и обычный текст.
""")
        }
        .padding()
    }
}
