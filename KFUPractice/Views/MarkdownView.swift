import SwiftUI

/// Современный компонент для отображения Markdown в SwiftUI
struct MarkdownView: View {
    let markdown: String
    
    var body: some View {
        Group {
            if #available(iOS 15.0, *) {
                // Используем встроенную поддержку Markdown в iOS 15+
                Text(try! AttributedString(markdown: markdown))
                    .textSelection(.enabled)
            } else {
                // Fallback для iOS 14
                Text(markdown)
                    .textSelection(.enabled)
            }
        }
        .font(.body)
        .lineSpacing(4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            MarkdownView(markdown: """
# Заголовок первого уровня

## Заголовок второго уровня

### Заголовок третьего уровня

Обычный текст с **жирным** и *курсивом*.

#### Список:
- Первый элемент
- **Важный** элемент
- *Выделенный* элемент

#### Нумерованный список:
1. Первый пункт
2. **Второй** пункт
3. *Третий* пункт

> Это цитата с **важной** информацией

Код: `let variable = "value"`

```swift
func example() {
    print("Hello World")
}
```

[Ссылка на Apple](https://apple.com)

---

**Формула**: E = mc²

~~Зачеркнутый текст~~
""")
        }
        .padding()
    }
}