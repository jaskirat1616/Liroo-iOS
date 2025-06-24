import SwiftUI

// MARK: - Markdown Renderer Tests
// This file contains test cases to verify the markdown renderer functionality

struct MarkdownRendererTests {
    
    // Test markdown content with various elements
    static let testMarkdownContent = """
    # Main Heading
    
    This is a **bold paragraph** with some *italic text* and `inline code`.
    
    ## Subheading
    
    Here's a list:
    - First item
    - Second item with **bold text**
    - Third item with *italic text*
    
    ### Another Subheading
    
    1. Numbered item one
    2. Numbered item two with `code`
    3. Numbered item three
    
    > This is a blockquote with some important information.
    
    Here's some code:
    ```
    func hello() {
        print("Hello, World!")
    }
    ```
    
    And some `inline code` in a sentence with **bold** and *italic* formatting mixed together.
    
    [This is a link](https://example.com)
    
    Regular paragraph with **bold**, *italic*, and `code` elements mixed together. This demonstrates how the rich text formatting works within a single paragraph.
    """
    
    // Test view to preview markdown rendering
    struct MarkdownTestView: View {
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Markdown Renderer Test")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                    
                    MarkdownRenderer.MarkdownTextView(
                        markdownText: testMarkdownContent,
                        baseFontSize: 16,
                        primaryTextColor: .primary,
                        secondaryTextColor: .secondary,
                        fontStyle: .systemDefault
                    )
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Markdown Test")
        }
    }
}

// MARK: - Preview
#if DEBUG
struct MarkdownRendererTests_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MarkdownRendererTests.MarkdownTestView()
        }
    }
}
#endif 