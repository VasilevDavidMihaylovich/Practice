//
//  EPUBStructure.swift
//  KFUPractice
//
//  AI Reader App - EPUB Structure Models
//

import Foundation

/// Структура EPUB документа
struct EPUBDocument {
    let container: EPUBContainer
    let package: EPUBPackage
    let chapters: [EPUBChapter]
    let tableOfContents: [EPUBTOCItem]
    
    /// Получить общее количество страниц во всех главах
    var totalPages: Int {
        return chapters.reduce(0) { $0 + $1.pages.count }
    }
    
    /// Получить все страницы в правильном порядке
    var allPages: [EPUBPage] {
        var pages: [EPUBPage] = []
        for chapter in chapters {
            pages.append(contentsOf: chapter.pages)
        }
        return pages
    }
}

/// Контейнер EPUB (META-INF/container.xml)
struct EPUBContainer {
    let rootFiles: [EPUBRootFile]
    
    var primaryRootFile: EPUBRootFile? {
        return rootFiles.first { $0.mediaType == "application/oebps-package+xml" }
    }
}

/// Корневой файл EPUB
struct EPUBRootFile {
    let fullPath: String
    let mediaType: String
}

/// Пакет EPUB (content.opf)
struct EPUBPackage {
    let metadata: EPUBMetadata
    let manifest: [EPUBManifestItem]
    let spine: [EPUBSpineItem]
    let guide: [EPUBGuideItem]
    
    /// Получить элементы spine в правильном порядке
    var orderedSpineItems: [EPUBSpineItem] {
        return spine
    }
    
    /// Найти manifest item по ID
    func findManifestItem(withId id: String) -> EPUBManifestItem? {
        return manifest.first { $0.id == id }
    }
}

/// Метаданные EPUB
struct EPUBMetadata {
    let title: String?
    let creator: String?
    let subject: String?
    let description: String?
    let publisher: String?
    let date: String?
    let identifier: String?
    let language: String?
    let rights: String?
    let source: String?
    let coverage: String?
    let relation: String?
    
    init(
        title: String? = nil,
        creator: String? = nil,
        subject: String? = nil,
        description: String? = nil,
        publisher: String? = nil,
        date: String? = nil,
        identifier: String? = nil,
        language: String? = nil,
        rights: String? = nil,
        source: String? = nil,
        coverage: String? = nil,
        relation: String? = nil
    ) {
        self.title = title
        self.creator = creator
        self.subject = subject
        self.description = description
        self.publisher = publisher
        self.date = date
        self.identifier = identifier
        self.language = language
        self.rights = rights
        self.source = source
        self.coverage = coverage
        self.relation = relation
    }
}

/// Элемент манифеста EPUB
struct EPUBManifestItem {
    let id: String
    let href: String
    let mediaType: String
    let properties: String?
    
    var isHTML: Bool {
        return mediaType.contains("html") || mediaType.contains("xhtml")
    }
    
    var isImage: Bool {
        return mediaType.hasPrefix("image/")
    }
    
    var isCSS: Bool {
        return mediaType == "text/css"
    }
}

/// Элемент spine EPUB
struct EPUBSpineItem {
    let idref: String
    let linear: Bool
    let properties: String?
    
    init(idref: String, linear: Bool = true, properties: String? = nil) {
        self.idref = idref
        self.linear = linear
        self.properties = properties
    }
}

/// Элемент guide EPUB
struct EPUBGuideItem {
    let type: String
    let title: String?
    let href: String
}

/// Глава EPUB
struct EPUBChapter {
    let id: String
    let title: String
    let filePath: String
    let htmlContent: String
    let textContent: String
    let pages: [EPUBPage]
    let order: Int
    
    init(
        id: String,
        title: String,
        filePath: String,
        htmlContent: String,
        textContent: String,
        order: Int
    ) {
        self.id = id
        self.title = title
        self.filePath = filePath
        self.htmlContent = htmlContent
        self.textContent = textContent
        self.order = order
        
        // Разбиваем текст на страницы
        self.pages = EPUBChapter.createPages(from: textContent, chapterId: id, chapterOrder: order)
    }
    
    /// Разбивает текст главы на страницы
    private static func createPages(from text: String, chapterId: String, chapterOrder: Int) -> [EPUBPage] {
        let lines = text.components(separatedBy: .newlines)
        var pages: [EPUBPage] = []
        var currentPageText = ""
        let targetCharsPerPage = 1000
        let maxCharsPerPage = 1200
        var pageNumber = 0
        
        for line in lines {
            let lineWithNewline = line + "\n"
            
            if currentPageText.count + lineWithNewline.count > maxCharsPerPage && !currentPageText.isEmpty {
                let page = EPUBPage(
                    id: "\(chapterId)_page_\(pageNumber)",
                    chapterId: chapterId,
                    chapterOrder: chapterOrder,
                    pageNumber: pageNumber,
                    content: currentPageText.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                pages.append(page)
                currentPageText = lineWithNewline
                pageNumber += 1
            }
            else if currentPageText.count + lineWithNewline.count >= targetCharsPerPage &&
                    line.trimmingCharacters(in: .whitespaces).isEmpty &&
                    !currentPageText.isEmpty {
                let page = EPUBPage(
                    id: "\(chapterId)_page_\(pageNumber)",
                    chapterId: chapterId,
                    chapterOrder: chapterOrder,
                    pageNumber: pageNumber,
                    content: currentPageText.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                pages.append(page)
                currentPageText = ""
                pageNumber += 1
            }
            else {
                currentPageText += lineWithNewline
            }
        }
        
        // Добавляем последнюю страницу если есть контент
        if !currentPageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let page = EPUBPage(
                id: "\(chapterId)_page_\(pageNumber)",
                chapterId: chapterId,
                chapterOrder: chapterOrder,
                pageNumber: pageNumber,
                content: currentPageText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            pages.append(page)
        }
        
        return pages.isEmpty ? [EPUBPage(id: "\(chapterId)_page_0", chapterId: chapterId, chapterOrder: chapterOrder, pageNumber: 0, content: "Глава пуста")] : pages
    }
}

/// Страница EPUB
struct EPUBPage: Equatable {
    let id: String
    let chapterId: String
    let chapterOrder: Int
    let pageNumber: Int
    let content: String
    let globalPageNumber: Int
    
    init(id: String, chapterId: String, chapterOrder: Int, pageNumber: Int, content: String, globalPageNumber: Int = 0) {
        self.id = id
        self.chapterId = chapterId
        self.chapterOrder = chapterOrder
        self.pageNumber = pageNumber
        self.content = content
        self.globalPageNumber = globalPageNumber
    }
    
    static func == (lhs: EPUBPage, rhs: EPUBPage) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Элемент оглавления EPUB (toc.ncx или nav.html)
struct EPUBTOCItem {
    let id: String
    let title: String
    let src: String
    let playOrder: Int
    let level: Int
    let children: [EPUBTOCItem]
    
    init(
        id: String,
        title: String,
        src: String,
        playOrder: Int,
        level: Int = 0,
        children: [EPUBTOCItem] = []
    ) {
        self.id = id
        self.title = title
        self.src = src
        self.playOrder = playOrder
        self.level = level
        self.children = children
    }
}

/// Конфигурация для парсинга EPUB
struct EPUBParsingConfiguration {
    let maxPageSize: Int
    let targetPageSize: Int
    let preserveFormatting: Bool
    let extractImages: Bool
    let extractCSS: Bool
    
    static let `default` = EPUBParsingConfiguration(
        maxPageSize: 1200,
        targetPageSize: 1000,
        preserveFormatting: true,
        extractImages: false,
        extractCSS: false
    )
}

/// Ошибки парсинга EPUB
enum EPUBError: LocalizedError {
    case invalidArchive
    case missingContainerFile
    case invalidContainerFile
    case missingPackageFile
    case invalidPackageFile
    case missingChapterFile(String)
    case invalidTableOfContents
    case unsupportedOperation
    
    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "Файл не является корректным EPUB архивом"
        case .missingContainerFile:
            return "Файл container.xml не найден в META-INF"
        case .invalidContainerFile:
            return "Файл container.xml имеет неверный формат"
        case .missingPackageFile:
            return "Файл package.opf не найден"
        case .invalidPackageFile:
            return "Файл package.opf имеет неверный формат"
        case .missingChapterFile(let fileName):
            return "Файл главы не найден: \(fileName)"
        case .invalidTableOfContents:
            return "Оглавление имеет неверный формат"
        case .unsupportedOperation:
            return "Операция не поддерживается"
        }
    }
}