//
//  PDFPageView.swift
//  KFUPractice
//
//  PDF Page Rendering Component with Image Support
//

import SwiftUI
import PDFKit

/// Компонент для отображения одной страницы PDF с поддержкой изображений
struct PDFPageView: UIViewRepresentable {
    let page: PDFPage
    let scale: CGFloat
    
    init(page: PDFPage, scale: CGFloat = 1.0) {
        self.page = page
        self.scale = scale
    }
    
    func makeUIView(context: Context) -> PDFPageViewContainer {
        let container = PDFPageViewContainer()
        container.setup(page: page, scale: scale)
        return container
    }
    
    func updateUIView(_ uiView: PDFPageViewContainer, context: Context) {
        uiView.update(page: page, scale: scale)
    }
}

/// UIView контейнер для PDF страницы
class PDFPageViewContainer: UIView {
    private var pdfPage: PDFPage?
    private var currentScale: CGFloat = 1.0
    private var imageView: UIImageView?
    
    func setup(page: PDFPage, scale: CGFloat) {
        self.pdfPage = page
        self.currentScale = scale
        renderPage()
    }
    
    func update(page: PDFPage, scale: CGFloat) {
        if self.pdfPage != page || self.currentScale != scale {
            self.pdfPage = page
            self.currentScale = scale
            renderPage()
        }
    }
    
    private func renderPage() {
        guard let page = pdfPage else { return }
        
        // Удаляем старое изображение
        imageView?.removeFromSuperview()
        
        // Вычисляем размер страницы с учетом scale
        let pageRect = page.bounds(for: .mediaBox)
        let scaledSize = CGSize(
            width: pageRect.width * currentScale,
            height: pageRect.height * currentScale
        )
        
        // Создаем изображение страницы
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { context in
            // Белый фон
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            // Рендерим PDF страницу
            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            context.cgContext.scaleBy(x: currentScale, y: -currentScale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        // Создаем UIImageView для отображения
        let newImageView = UIImageView(image: image)
        newImageView.contentMode = .scaleAspectFit
        newImageView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(newImageView)
        
        NSLayoutConstraint.activate([
            newImageView.topAnchor.constraint(equalTo: topAnchor),
            newImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            newImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            newImageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        self.imageView = newImageView
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Обновляем layout при изменении размера
        if let page = pdfPage {
            renderPage()
        }
    }
}


