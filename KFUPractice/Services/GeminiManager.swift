import Foundation
import UIKit

final class GeminiManager {
    static let shared = GeminiManager()

    private let apiKey = "AIzaSyDzJiCkVC1yyLok1vcQsFi_BAYe_e5jKDI"


    private let model = "gemini-2.0-flash" // или "gemini-1.5-flash"

    private init() {}

    func generateText(from image: UIImage, prompt: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw GeminiError.imageEncodingFailed
        }

        let base64Image = imageData.base64EncodedString()

        // https://generativelanguage.googleapis.com/v1/models/{model}:generateContent?key=API_KEY
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GeminiRequest(
            contents: [
                .init(parts: [
                    // сначала текстовый промпт
                    .init(text: prompt, inline_data: nil),
                    // потом сама картинка в base64
                    .init(
                        text: nil,
                        inline_data: .init(
                            mime_type: "image/jpeg",
                            data: base64Image
                        )
                    )
                ])
            ]
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase // чтобы inline_data → inline_data

        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            throw GeminiError.httpError(statusCode: httpResponse.statusCode, body: bodyString)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)

        guard
            let candidate = geminiResponse.candidates?.first,
            !candidate.content.parts.isEmpty
        else {
            throw GeminiError.emptyResponse
        }

        let text = candidate.content.parts
            .compactMap { $0.text }
            .joined(separator: " ")

        if text.isEmpty {
            throw GeminiError.emptyResponse
        }
        
        print(text)

        return text
    }
    
    // MARK: - Конспект функционал
    
    func generateSummary(from image: UIImage) async throws -> String {
        let prompt = createSummaryPrompt()
        return try await generateText(from: image, prompt: prompt)
    }
    
    private func createSummaryPrompt() -> String {
        return """
        Проанализируй содержимое изображения и составь краткий конспект на русском языке. Следуй этим требованиям:

        1. **Структура конспекта:**
           - Используй маркированные списки и подзаголовки
           - Выдели ключевые понятия **жирным шрифтом** (используй **текст**)
           - Используй *курсив* для акцентов (используй *текст*)
           - Организуй информацию логически

        2. **Содержание:**
           - Выдели **ГЛАВНЫЕ** идеи и концепции
           - Включи важные *определения* и термины
           - Добавь ключевые факты и данные
           - Если есть формулы - объясни их простыми словами
           - Если есть схемы/диаграммы - опиши их суть

        3. **Стиль:**
           - **Краткость** и ясность
           - Используй *академический* стиль
           - Избегай лишних деталей
           - Максимум 300-400 слов

        4. **Форматирование:**
           - Обязательно используй **жирный** для ключевых терминов
           - Используй *курсив* для пояснений
           - Применяй маркированные списки (- пункт)
           - Используй ### для подзаголовков

        5. **Если на изображении есть текст на других языках:**
           - Переведи основные идеи на русский
           - Сохрани оригинальные термины в скобках

        Начни конспект сразу, без вводных фраз типа "На изображении показано". Создай **полезный** конспект для студента с правильным markdown форматированием.
        """
    }
}

// MARK: - Модели запроса

private struct GeminiRequest: Encodable {
    let contents: [Content]

    struct Content: Encodable {
        let parts: [Part]
    }

    struct Part: Encodable {
        let text: String?
        let inline_data: InlineData?

        struct InlineData: Encodable {
            let mime_type: String
            let data: String
        }
    }
}

// MARK: - Модели ответа

private struct GeminiResponse: Decodable {
    let candidates: [Candidate]?

    struct Candidate: Decodable {
        let content: Content
    }

    struct Content: Decodable {
        let parts: [Part]
    }

    struct Part: Decodable {
        let text: String?
    }
}

// MARK: - Ошибки

enum GeminiError: Error {
    case invalidURL
    case imageEncodingFailed
    case httpError(statusCode: Int, body: String)
    case emptyResponse
}
