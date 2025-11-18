//
//  NotesManager.swift
//  KFUPractice
//
//  Менеджер для централизованного управления заметками
//

import Foundation
import Combine

/// Централизованный менеджер заметок для всего приложения
class NotesManager: ObservableObject {
    static let shared = NotesManager()
    
    @Published private var allNotes: [UUID: [Note]] = [:] // [BookID: [Note]]
    
    private init() {
        print("📝 [NotesManager] Инициализация менеджера заметок")
    }
    
    // MARK: - Public Methods
    
    /// Добавить заметку для книги
    func addNote(_ note: Note, for bookId: UUID) {
        DispatchQueue.main.async {
            if self.allNotes[bookId] == nil {
                self.allNotes[bookId] = []
            }
            self.allNotes[bookId]?.append(note)
            print("📝 [NotesManager] Добавлена заметка для книги \(bookId). Всего заметок: \(self.allNotes[bookId]?.count ?? 0)")
        }
    }
    
    /// Получить все заметки для конкретной книги
    func getNotesForBook(_ bookId: UUID) -> [Note] {
        return allNotes[bookId] ?? []
    }
    
    /// Получить все умные заметки (AI и графики) для всех книг
    func getAllSmartNotes() -> [Note] {
        var smartNotes: [Note] = []
        
        for (_, notes) in allNotes {
            let filteredNotes = notes.filter { note in
                note.type == .aiNote || note.type == .chart || 
                (note.type == .custom && (note.userText?.contains("AI результат") ?? false))
            }
            smartNotes.append(contentsOf: filteredNotes)
        }
        
        // Сортируем по дате создания (новые сначала)
        return smartNotes.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    /// Удалить заметку
    func removeNote(with id: UUID, for bookId: UUID) {
        DispatchQueue.main.async {
            self.allNotes[bookId]?.removeAll { $0.id == id }
            print("📝 [NotesManager] Удалена заметка \(id) для книги \(bookId)")
        }
    }
    
    /// Обновить заметку
    func updateNote(_ updatedNote: Note) {
        DispatchQueue.main.async {
            if let bookNotes = self.allNotes[updatedNote.bookId],
               let index = bookNotes.firstIndex(where: { $0.id == updatedNote.id }) {
                self.allNotes[updatedNote.bookId]?[index] = updatedNote
                print("📝 [NotesManager] Обновлена заметка \(updatedNote.id)")
            }
        }
    }
    
    /// Получить общее количество заметок
    func getTotalNotesCount() -> Int {
        return allNotes.values.reduce(0) { $0 + $1.count }
    }
    
    // MARK: - Debug Methods
    
    /// Вывести статистику заметок в консоль (для отладки)
    func printStatistics() {
        let totalCount = getTotalNotesCount()
        let smartCount = getAllSmartNotes().count
        
        print("📝 [NotesManager] === Статистика заметок ===")
        print("📝 [NotesManager] Всего заметок: \(totalCount)")
        print("📝 [NotesManager] Умных заметок: \(smartCount)")
        print("📝 [NotesManager] Книг с заметками: \(allNotes.count)")
        
        for (bookId, notes) in allNotes {
            let aiNotes = notes.filter { $0.type == .aiNote }.count
            let charts = notes.filter { $0.type == .chart }.count
            let custom = notes.filter { $0.type == .custom }.count
            print("📝 [NotesManager] Книга \(bookId): AI(\(aiNotes)), Графики(\(charts)), Обычные(\(custom))")
        }
        print("📝 [NotesManager] ========================")
    }
}