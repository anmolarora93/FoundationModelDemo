import SwiftUI

struct HealthPlanAdvisorView: View {
    @ObservedObject var viewModel: HealthPlanViewModel
    @StateObject private var advisor = HealthPlanAdvisor()
    @State private var inputText = ""
    @State private var showSuggestions = true
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !advisor.isModelAvailable && advisor.errorMessage != nil {
                modelUnavailableBanner
            }

            chatMessagesView

            if showSuggestions && advisor.messages.count <= 1 {
                suggestedQuestionsView
            }

            inputBar
        }
        .navigationTitle("Plan Advisor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    advisor.resetConversation()
                }, label: {
                    Text("Reset")
                })
            }
//                Menu {
//                    Button(role: .destructive) {
//                        advisor.resetConversation()
//                        showSuggestions = true
//                    } label: {
//                        Label("New Conversation", systemImage: "arrow.counterclockwise")
//                    }
//                } label: {
//                    Image(systemName: "ellipsis.circle")
//                }
//            }
        }
        .onAppear {
            if let response = viewModel.planResponse {
                advisor.configure(with: response)
            }
        }
        .onChange(of: viewModel.planResponse != nil) { _, becameNonNil in
            if becameNonNil, let response = viewModel.planResponse, advisor.messages.isEmpty {
                advisor.configure(with: response)
            }
        }
    }

    // MARK: - Model Unavailable Banner

    private var modelUnavailableBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Intelligence Unavailable")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(advisor.errorMessage ?? "Model not available")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Chat Messages

    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    privacyHeader

                    ForEach(advisor.messages) { message in
                        ChatBubbleView(message: message)
                            .id(message.id)
                    }

                    if advisor.isGenerating {
                        typingIndicator
                    }
                }
                .padding()
            }
            .onChange(of: advisor.messages.count) { _, _ in
                if let last = advisor.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: advisor.messages.last?.content) { _, _ in
                if let last = advisor.messages.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var privacyHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "apple.intelligence")
                .font(.title3)
                .foregroundStyle(.purple)

            VStack(alignment: .leading, spacing: 2) {
                Text("Powered by Apple Intelligence")
                    .font(.caption)
                    .fontWeight(.semibold)

                Text("Runs entirely on your device · Your data never leaves your phone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
        .padding(12)
        .background(Color.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.purple.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(advisor.isGenerating ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: advisor.isGenerating
                        )
                }
                Text("Thinking...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer()
        }
    }

    // MARK: - Suggested Questions

    private var suggestedQuestionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(advisor.suggestedQuestions.prefix(6)), id: \.self) { question in
                    Button {
                        inputText = question
                        sendMessage()
                    } label: {
                        Text(question)
                            .font(.caption)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                TextField("Ask about your health plan...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || advisor.isGenerating
                            ? .gray : .purple
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || advisor.isGenerating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        showSuggestions = false

        Task {
            await advisor.sendMessageStreaming(text)
        }
    }
}

// MARK: - Chat Bubble View

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            if message.role == .assistant {
                Image(systemName: "apple.intelligence")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                formattedContent
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(timeString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role == .assistant {
                Spacer(minLength: 40)
            }

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
        }
    }

    private var formattedContent: Text {
        // Simple markdown-like bold handling
        let content = message.content
        return Text(LocalizedStringKey(content))
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
            LinearGradient(
                colors: [.blue, .blue.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(.systemGray6)
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}

