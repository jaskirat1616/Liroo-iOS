import Foundation
import UIKit
import PDFKit
import UniformTypeIdentifiers

/// Service for exporting content to various formats
@MainActor
class ExportService {
    static let shared = ExportService()
    
    private init() {}
    
    // MARK: - Export Models
    
    enum ExportFormat {
        case pdf
        case text
        case markdown
        case image
    }
    
    // MARK: - Story Export
    
    /// Export story to PDF
    func exportStoryToPDF(
        story: FirebaseStory,
        chapters: [FirebaseChapter],
        theme: ReadingTheme = .light
    ) async throws -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "Liroo",
            kCGPDFContextAuthor: story.userId ?? "Unknown",
            kCGPDFContextTitle: story.title
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(story.title)-\(UUID().uuidString).pdf")
        
        try renderer.writePDF(to: tempURL) { context in
            context.beginPage()
            
            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: theme.primaryUIColor
            ]
            story.title.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)
            
            // Overview
            if let overview = story.overview {
                let overviewAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14),
                    .foregroundColor: theme.secondaryUIColor
                ]
                let overviewRect = CGRect(x: 50, y: 100, width: 512, height: 200)
                overview.draw(in: overviewRect, withAttributes: overviewAttributes)
            }
            
            // Chapters
            var currentY: CGFloat = 350
            for chapter in chapters {
                if currentY > 700 {
                    context.beginPage()
                    currentY = 50
                }
                
                // Chapter title
                let chapterTitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 18),
                    .foregroundColor: theme.primaryUIColor
                ]
                chapter.title.draw(at: CGPoint(x: 50, y: currentY), withAttributes: chapterTitleAttributes)
                currentY += 30
                
                // Chapter content
                let contentAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: theme.primaryUIColor
                ]
                let contentRect = CGRect(x: 50, y: currentY, width: 512, height: 400)
                chapter.content.draw(in: contentRect, withAttributes: contentAttributes)
                currentY += 450
            }
        }
        
        return tempURL
    }
    
    /// Export story to markdown
    func exportStoryToMarkdown(story: FirebaseStory, chapters: [FirebaseChapter]) -> String {
        var markdown = "# \(story.title)\n\n"
        
        if let overview = story.overview {
            markdown += "## Overview\n\n\(overview)\n\n"
        }
        
        if let characters = story.mainCharacters {
            markdown += "## Main Characters\n\n"
            for character in characters {
                markdown += "- **\(character.name)**: \(character.description)\n"
            }
            markdown += "\n"
        }
        
        markdown += "## Chapters\n\n"
        for chapter in chapters.sorted(by: { ($0.order ?? 0) < ($1.order ?? 0) }) {
            markdown += "### Chapter \(chapter.order ?? 0): \(chapter.title)\n\n"
            markdown += "\(chapter.content)\n\n"
        }
        
        return markdown
    }
    
    /// Export story to text
    func exportStoryToText(story: FirebaseStory, chapters: [FirebaseChapter]) -> String {
        var text = "\(story.title)\n\n"
        
        if let overview = story.overview {
            text += "OVERVIEW\n\(overview)\n\n"
        }
        
        for chapter in chapters.sorted(by: { ($0.order ?? 0) < ($1.order ?? 0) }) {
            text += "Chapter \(chapter.order ?? 0): \(chapter.title)\n"
            text += "\(chapter.content)\n\n"
        }
        
        return text
    }
    
    // MARK: - Share Sheet
    
    /// Present share sheet for content
    func shareContent(
        items: [Any],
        sourceView: UIView? = nil,
        barButtonItem: UIBarButtonItem? = nil
    ) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityVC.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else if let barButtonItem = barButtonItem {
                popover.barButtonItem = barButtonItem
            }
        }
        
        return activityVC
    }
}

// MARK: - ReadingTheme Extension (defined in ReadingSettings.swift)

extension ReadingTheme {
    var primaryUIColor: UIColor {
        switch self {
        case .light:
            return .label
        case .dark:
            return .white
        case .sepia:
            return UIColor(red: 0.36, green: 0.25, blue: 0.18, alpha: 1.0)
        }
    }
    
    var secondaryUIColor: UIColor {
        switch self {
        case .light:
            return .secondaryLabel
        case .dark:
            return .lightGray
        case .sepia:
            return UIColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 1.0)
        }
    }
    
    var backgroundColorUIColor: UIColor {
        switch self {
        case .light:
            return .systemBackground
        case .dark:
            return .black
        case .sepia:
            return UIColor(red: 0.97, green: 0.94, blue: 0.89, alpha: 1.0)
        }
    }
}

