import SwiftUI
import Foundation

// MARK: - Markdown Renderer
struct MarkdownRenderer {
    
    // MARK: - Markdown Text View
    struct MarkdownTextView: View {
        let markdownText: String
        let baseFontSize: Double
        let primaryTextColor: Color
        let secondaryTextColor: Color
        let fontStyle: ReadingFontStyle
        let onTapGesture: (() -> Void)?
        
        init(markdownText: String, 
             baseFontSize: Double, 
             primaryTextColor: Color, 
             secondaryTextColor: Color, 
             fontStyle: ReadingFontStyle,
             onTapGesture: (() -> Void)? = nil) {
            self.markdownText = markdownText
            self.baseFontSize = baseFontSize
            self.primaryTextColor = primaryTextColor
            self.secondaryTextColor = secondaryTextColor
            self.fontStyle = fontStyle
            self.onTapGesture = onTapGesture
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(parseMarkdown(markdownText), id: \.id) { element in
                    renderMarkdownElement(element)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTapGesture?()
            }
        }
        
        private func renderMarkdownElement(_ element: MarkdownElement) -> some View {
            switch element.type {
            case .heading1:
                return AnyView(
                    Text(element.content)
                        .font(fontStyle.getFont(size: CGFloat(baseFontSize + 8), weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .padding(.top, 8)
                )
            case .heading2:
                return AnyView(
                    Text(element.content)
                        .font(fontStyle.getFont(size: CGFloat(baseFontSize + 6), weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .padding(.top, 6)
                )
            case .heading3:
                return AnyView(
                    Text(element.content)
                        .font(fontStyle.getFont(size: CGFloat(baseFontSize + 4), weight: .semibold))
                        .foregroundColor(primaryTextColor)
                        .padding(.top, 4)
                )
            case .bold:
                return AnyView(
                    Text(element.content)
                        .font(fontStyle.getFont(size: CGFloat(baseFontSize), weight: .bold))
                        .foregroundColor(primaryTextColor)
                )
            case .italic:
                return AnyView(
                    Text(element.content)
                        .font(fontStyle.getFont(size: CGFloat(baseFontSize), weight: .medium))
                        .italic()
                        .foregroundColor(primaryTextColor)
                )
            case .code:
                return AnyView(
                    Text(element.content)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(secondaryTextColor.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(primaryTextColor)
                )
            case .codeBlock:
                return AnyView(
                    Text(element.content)
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .background(secondaryTextColor.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(primaryTextColor)
                )
            case .blockquote:
                return AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle()
                            .fill(primaryTextColor.opacity(0.3))
                            .frame(width: 4)
                        Text(element.content)
                            .font(fontStyle.getFont(size: CGFloat(baseFontSize)))
                            .foregroundColor(primaryTextColor.opacity(0.8))
                            .italic()
                    }
                    .padding(.vertical, 4)
                )
            case .listItem:
                return AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(fontStyle.getFont(size: CGFloat(baseFontSize)))
                            .foregroundColor(primaryTextColor)
                        Text(element.content)
                            .font(fontStyle.getFont(size: CGFloat(baseFontSize)))
                            .foregroundColor(primaryTextColor)
                    }
                )
            case .numberedListItem:
                return AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(element.number).")
                            .font(fontStyle.getFont(size: CGFloat(baseFontSize)))
                            .foregroundColor(primaryTextColor)
                        Text(element.content)
                            .font(fontStyle.getFont(size: CGFloat(baseFontSize)))
                            .foregroundColor(primaryTextColor)
                    }
                )
            case .link:
                return AnyView(
                    Text(element.content)
                        .font(fontStyle.getFont(size: CGFloat(baseFontSize)))
                        .foregroundColor(.blue)
                        .underline()
                )
            case .paragraph:
                return AnyView(
                    Text(element.content)
                        .font(fontStyle.getFont(size: CGFloat(baseFontSize)))
                        .foregroundColor(primaryTextColor)
                        .lineSpacing(CGFloat(baseFontSize * 0.3))
                )
            }
        }
    }
    
    // MARK: - Markdown Element Types
    enum MarkdownElementType {
        case heading1, heading2, heading3
        case bold, italic
        case code, codeBlock
        case blockquote
        case listItem, numberedListItem
        case link
        case paragraph
    }
    
    struct MarkdownElement: Identifiable {
        let id = UUID()
        let type: MarkdownElementType
        let content: String
        let number: Int?
        
        init(type: MarkdownElementType, content: String, number: Int? = nil) {
            self.type = type
            self.content = content
            self.number = number
        }
    }
    
    // MARK: - Markdown Parsing
    static func parseMarkdown(_ text: String) -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = text.components(separatedBy: .newlines)
        var currentParagraph = ""
        var inCodeBlock = false
        var codeBlockContent = ""
        var listItemNumber = 1
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Handle code blocks
            if trimmedLine.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    if !codeBlockContent.isEmpty {
                        elements.append(MarkdownElement(type: .codeBlock, content: codeBlockContent))
                    }
                    codeBlockContent = ""
                    inCodeBlock = false
                } else {
                    // Start code block
                    if !currentParagraph.isEmpty {
                        elements.append(MarkdownElement(type: .paragraph, content: currentParagraph))
                        currentParagraph = ""
                    }
                    inCodeBlock = true
                }
                continue
            }
            
            if inCodeBlock {
                codeBlockContent += line + "\n"
                continue
            }
            
            // Handle headings
            if trimmedLine.hasPrefix("# ") {
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                let content = String(trimmedLine.dropFirst(2))
                elements.append(MarkdownElement(type: .heading1, content: content))
                continue
            }
            
            if trimmedLine.hasPrefix("## ") {
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                let content = String(trimmedLine.dropFirst(3))
                elements.append(MarkdownElement(type: .heading2, content: content))
                continue
            }
            
            if trimmedLine.hasPrefix("### ") {
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                let content = String(trimmedLine.dropFirst(4))
                elements.append(MarkdownElement(type: .heading3, content: content))
                continue
            }
            
            // Handle blockquotes
            if trimmedLine.hasPrefix("> ") {
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                let content = String(trimmedLine.dropFirst(2))
                elements.append(MarkdownElement(type: .blockquote, content: content))
                continue
            }
            
            // Handle list items
            if trimmedLine.hasPrefix("- ") {
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                let content = String(trimmedLine.dropFirst(2))
                elements.append(MarkdownElement(type: .listItem, content: content))
                continue
            }
            
            // Handle numbered list items
            if let match = trimmedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                let numberString = String(trimmedLine[..<match.upperBound]).replacingOccurrences(of: ". ", with: "")
                let number = Int(numberString) ?? listItemNumber
                let content = String(trimmedLine[match.upperBound...])
                elements.append(MarkdownElement(type: .numberedListItem, content: content, number: number))
                listItemNumber = number + 1
                continue
            }
            
            // Handle empty lines (paragraph breaks)
            if trimmedLine.isEmpty {
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph))
                    currentParagraph = ""
                }
                continue
            }
            
            // Add to current paragraph
            if !currentParagraph.isEmpty {
                currentParagraph += "\n"
            }
            currentParagraph += line
        }
        
        // Add final paragraph if exists
        if !currentParagraph.isEmpty {
            elements.append(MarkdownElement(type: .paragraph, content: currentParagraph))
        }
        
        // Return elements directly without additional processing
        return elements
    }
    
    // MARK: - Inline Formatting (Simplified)
    private static func processInlineFormatting(_ elements: [MarkdownElement]) -> [MarkdownElement] {
        return elements.map { element in
            if case .paragraph = element.type {
                return processInlineMarkdown(element.content)
            }
            return element
        }
    }
    
    private static func processInlineMarkdown(_ text: String) -> MarkdownElement {
        // Simply clean the text and return as regular paragraph
        var cleanedText = text
        
        // Remove markdown syntax
        cleanedText = cleanedText.replacingOccurrences(of: #"\*\*(.*?)\*\*"#, with: "$1", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: #"\*(.*?)\*"#, with: "$1", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: #"`(.*?)`"#, with: "$1", options: .regularExpression)
        
        return MarkdownElement(type: .paragraph, content: cleanedText)
    }
}

// MARK: - Convenience Extensions
extension View {
    func markdownText(_ text: String, 
                     baseFontSize: Double, 
                     primaryTextColor: Color, 
                     secondaryTextColor: Color, 
                     fontStyle: ReadingFontStyle,
                     onTapGesture: (() -> Void)? = nil) -> some View {
        MarkdownRenderer.MarkdownTextView(
            markdownText: text,
            baseFontSize: baseFontSize,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            fontStyle: fontStyle,
            onTapGesture: onTapGesture
        )
    }
} 