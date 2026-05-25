import SwiftUI

struct QAPair: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

@available(iOS 26.0, macOS 26.0, *)
struct PatternQAView: View {
    @ObservedObject var service: PatternAIService
    let patternID: UUID
    let patternText: String

    @State private var question: String = ""
    @State private var isAsking: Bool = false
    @State private var errorMessage: String? = nil

    private var history: [QAPair] { service.qaHistory[patternID] ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !history.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(history) { pair in
                            qaThread(pair)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: 240)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            askInput
        }
        .padding(.bottom, 4)
    }

    // MARK: - Q&A chat bubbles

    @ViewBuilder
    private func qaThread(_ pair: QAPair) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // User question — accent bubble, right-aligned.
            HStack {
                Spacer(minLength: 44)
                Text(pair.question)
                    .font(Typo.bodyText)
                    .foregroundColor(.white)
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(Color.appAccent)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 18, bottomLeadingRadius: 18,
                        bottomTrailingRadius: 4, topTrailingRadius: 18))
            }
            // AI answer — avatar + bordered bubble, left-aligned.
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    Circle().fill(Color.appAccent.opacity(0.12))
                        .overlay(Circle().strokeBorder(Color.appAccent.opacity(0.25), lineWidth: 1))
                        .frame(width: 26, height: 26)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(Color.appAccent)
                }
                Text(pair.answer)
                    .font(Typo.bodyText)
                    .foregroundColor(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 11).padding(.horizontal, 14)
                    .background(Color.surface)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 18, bottomLeadingRadius: 4,
                        bottomTrailingRadius: 18, topTrailingRadius: 18))
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 18, bottomLeadingRadius: 4,
                            bottomTrailingRadius: 18, topTrailingRadius: 18)
                            .strokeBorder(Color.dividerToken, lineWidth: 0.5))
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Ask input

    private var askInput: some View {
        HStack(spacing: 10) {
            TextField(history.isEmpty ? "Ask anything about this pattern…" : "Ask a follow-up…", text: $question)
                .textFieldStyle(.plain)
                .font(Typo.bodyText)
                .onSubmit { askQuestion() }
                .disabled(isAsking)

            if isAsking {
                ProgressView().scaleEffect(0.6).frame(width: 28, height: 28)
            } else {
                Button { askQuestion() } label: {
                    ZStack {
                        Circle()
                            .fill(question.isEmpty ? Color.appAccent.opacity(0.25) : Color.appAccent)
                            .frame(width: 28, height: 28)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(question.isEmpty ? Color.appAccent.opacity(0.6) : .white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(question.isEmpty)
                .accessibilityLabel("Send question")
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(0.25), lineWidth: 1))
    }

    private func askQuestion() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isAsking = true
        errorMessage = nil
        let asked = trimmed
        question = ""
        Task {
            do {
                let answer = try await service.answerQuestion(asked, patternText: patternText)
                service.qaHistory[patternID, default: []].append(QAPair(question: asked, answer: answer))
            } catch {
                errorMessage = "Error: \(error.localizedDescription)"
            }
            isAsking = false
        }
    }
}
