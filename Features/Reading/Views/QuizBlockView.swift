import SwiftUI

struct QuizBlockView: View {
    let block: FirebaseContentBlock
    let baseFontSize: Double
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let fontStyle: ReadingFontStyle

    @State private var selectedOptionID: String? = nil
    @State private var isAnswerSubmitted: Bool = false
    @State private var showExplanation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let question = block.content, !question.isEmpty {
                MarkdownRenderer.MarkdownTextView(
                    markdownText: question,
                    baseFontSize: baseFontSize,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    fontStyle: fontStyle
                )
                .padding(.bottom, 8)
            }

            if let options = block.options {
                ForEach(options.filter { $0.id != nil && $0.text != nil }) { option in
                    Button(action: {
                        if !isAnswerSubmitted, let optionId = option.id {
                            selectedOptionID = optionId
                        }
                    }) {
                        HStack {
                            Image(systemName: iconNameForOption(option: option))
                                .foregroundColor(iconColorForOption(option: option))
                            Text(option.text ?? "Unnamed Option")
                                .font(fontStyle.getFont(size: CGFloat(baseFontSize * 0.9)))
                                .foregroundColor(primaryTextColor)
                            Spacer()
                        }
                        .padding()
                        .background(backgroundColorForOption(option: option))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(borderColorForOption(option: option), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isAnswerSubmitted)
                }
            }

            if !isAnswerSubmitted && selectedOptionID != nil {
                Button(action: {
                    withAnimation {
                        isAnswerSubmitted = true
                        if block.explanation != nil && !block.explanation!.isEmpty {
                            showExplanation = true
                        }
                    }
                }) {
                    Text("Submit Answer")
                        .font(fontStyle.getFont(size: CGFloat(baseFontSize * 0.9), weight: .semibold))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }

            if isAnswerSubmitted && showExplanation {
                if let explanationText = block.explanation, !explanationText.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Explanation:")
                            .font(fontStyle.getFont(size: CGFloat(baseFontSize * 0.85), weight: .bold))
                            .foregroundColor(primaryTextColor)
                        
                        MarkdownRenderer.MarkdownTextView(
                            markdownText: explanationText,
                            baseFontSize: baseFontSize * 0.85,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            fontStyle: fontStyle
                        )
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(primaryTextColor.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .slide))
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func iconNameForOption(option: FirebaseQuizOption) -> String {
        guard let optionId = option.id else { return "circle" }
        if isAnswerSubmitted {
            if optionId == block.correctAnswerID {
                return "checkmark.circle.fill"
            } else if optionId == selectedOptionID {
                return "xmark.circle.fill"
            }
        } else if optionId == selectedOptionID {
            return "largecircle.fill.circle" // Or "record.circle" / "circle.inset.filled"
        }
        return "circle"
    }

    private func iconColorForOption(option: FirebaseQuizOption) -> Color {
         guard let optionId = option.id else { return .gray }
        if isAnswerSubmitted {
            if optionId == block.correctAnswerID {
                return .green
            } else if optionId == selectedOptionID {
                return .red
            }
        } else if optionId == selectedOptionID {
            return .blue
        }
        return .gray
    }

    private func backgroundColorForOption(option: FirebaseQuizOption) -> Color {
        guard let optionId = option.id else { return Color(.systemGray6) }

        if isAnswerSubmitted {
            if optionId == block.correctAnswerID {
                return .green.opacity(0.15)
            } else if optionId == selectedOptionID {
                return .red.opacity(0.15)
            }
        } else if optionId == selectedOptionID {
            return .blue.opacity(0.1)
        }
        return Color(.systemGray6)
    }

    private func borderColorForOption(option: FirebaseQuizOption) -> Color {
        guard let optionId = option.id else { return Color(.systemGray4) }

        if isAnswerSubmitted {
            if optionId == block.correctAnswerID {
                return .green
            } else if optionId == selectedOptionID {
                return .red
            } else {
                return Color(.systemGray4) // Non-selected, non-correct after submission
            }
        } else if optionId == selectedOptionID {
            return .blue
        }
        return Color(.systemGray4)
    }
}
