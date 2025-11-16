//
//  KFUPracticeApp.swift
//  KFUPractice
//
//  AI Reader App - Интеллектуальная читалка для обучения
//  Created by Давид Васильев on 09.11.2025.
//

import SwiftUI

@main
struct KFUPracticeApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
                .preferredColorScheme(nil) // Поддержка светлой/темной темы
        }
    }
}
