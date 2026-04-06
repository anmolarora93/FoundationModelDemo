import Combine
import Foundation
import FoundationModels

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date

    enum Role {
        case user
        case assistant
        case system
    }

    init(role: Role, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Health Plan Advisor Service

/// Uses Apple's on-device Foundation Models (iOS 26+) to answer free-form
/// health plan questions. All processing happens on-device — no data leaves the phone.
@MainActor
final class HealthPlanAdvisor: ObservableObject {

    // MARK: - Published State

    @Published var messages: [ChatMessage] = []
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var isModelAvailable = false

    // MARK: - Private

    private var session: LanguageModelSession?
    private var planResponse: HealthPlanResponse?

    // MARK: - Setup

    /// Call this after health plan data is loaded to configure the advisor.
    func configure(with planResponse: HealthPlanResponse) {
        self.planResponse = planResponse
        checkAvailability()
        createSession()
        addWelcomeMessage()
    }

    private func checkAvailability() {
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            isModelAvailable = true
        case .unavailable:
            isModelAvailable = false
            errorMessage = "Apple Intelligence is not available on this device. Requires iPhone 15 Pro or later with iOS 26+."
        }
    }

    private func createSession() {
        guard isModelAvailable, let planResponse else { return }

        let systemPrompt = buildSystemPrompt(from: planResponse)

        session = LanguageModelSession(
            instructions: systemPrompt
        )
    }

    private func addWelcomeMessage() {
        guard let plan = planResponse?.healthPlan,
              let member = planResponse?.memberProfile else { return }

        let welcome = """
        Hello \(member.fullName)! I'm your Health Plan Advisor, powered by Apple Intelligence running entirely on your device. 🔒

        I can help you understand your **\(plan.planLabel)** plan. Try asking me things like:

        • "What's my copay for urgent care?"
        • "Do I need a referral to see a specialist?"
        • "How much deductible do I have left?"
        • "Is mental health covered?"
        • "What happens if I go out-of-network?"
        • "Explain my out-of-pocket maximum"

        All conversations are processed on-device — nothing leaves your phone.
        """

        messages.append(ChatMessage(role: .assistant, content: welcome))
    }

    // MARK: - Send Message

    func sendMessage(_ text: String) async {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        guard let session else {
            messages.append(ChatMessage(
                role: .assistant,
                content: "I'm sorry, the on-device AI model is not available. Please make sure you're running iOS 26+ on a supported device with Apple Intelligence enabled."
            ))
            return
        }

        isGenerating = true
        errorMessage = nil

        do {
            let response = try await session.respond(to: text)
            let assistantMessage = ChatMessage(role: .assistant, content: response.content)
            messages.append(assistantMessage)
        } catch {
            let errorResponse = ChatMessage(
                role: .assistant,
                content: "I encountered an issue processing your question. Please try rephrasing it. (Error: \(error.localizedDescription))"
            )
            messages.append(errorResponse)
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    // MARK: - Streaming Response

    func sendMessageStreaming(_ text: String) async {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        guard let session else {
            messages.append(ChatMessage(
                role: .assistant,
                content: "I'm sorry, the on-device AI model is not available. Please make sure you're running iOS 26+ on a supported device with Apple Intelligence enabled."
            ))
            return
        }

        isGenerating = true
        errorMessage = nil

        // Add a placeholder assistant message that we'll update with streaming content
        let placeholderMessage = ChatMessage(role: .assistant, content: "")
        messages.append(placeholderMessage)
        let messageIndex = messages.count - 1

        do {
            var accumulated = ""
            let stream = session.streamResponse(to: text)

            for try await partial in stream {
                accumulated = partial.content
                messages[messageIndex] = ChatMessage(
                    role: .assistant,
                    content: accumulated,
                    timestamp: placeholderMessage.timestamp
                )
            }

            // If somehow empty, provide a fallback
            if accumulated.isEmpty {
                messages[messageIndex] = ChatMessage(
                    role: .assistant,
                    content: "I wasn't able to generate a response. Please try rephrasing your question.",
                    timestamp: placeholderMessage.timestamp
                )
            }
        } catch let error as LanguageModelSession.GenerationError {
            print(">>>> Generation Error: \(error)")
            switch error {
            case .exceededContextWindowSize(let context):
                errorMessage = "Exceeded Window Size for \(context)"
            case .assetsUnavailable(let context):
                errorMessage = "Assets Unavailable for \(context)"
            case .guardrailViolation(let context):
                errorMessage = "Guardrail Violation for \(context)"
            case .unsupportedGuide(let context):
                errorMessage = "Unsupported Guide for \(context)"
            case .unsupportedLanguageOrLocale(let context):
                errorMessage = "Unsupported Language or Locale for \(context)"
            case .decodingFailure(let context):
                errorMessage = "Decoding Failure for \(context)"
            case .rateLimited(let context):
                errorMessage = "Rate Limited for \(context)"
            case .concurrentRequests(let context):
                errorMessage = "Concurrent Requests for \(context)"
            case .refusal(let refusal, let context):
                errorMessage = "Refusal \(refusal) for \(context)"
            @unknown default:
                errorMessage = "\(error.localizedDescription)"
            }
        } catch {
            messages[messageIndex] = ChatMessage(
                role: .assistant,
                content: "I encountered an issue: \(error.localizedDescription). Please try again.",
                timestamp: placeholderMessage.timestamp
            )
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    // MARK: - Reset Conversation

    func resetConversation() {
        messages.removeAll()
        createSession()
        addWelcomeMessage()
    }

    // MARK: - Suggested Questions

    var suggestedQuestions: [String] {
        var suggestions = [
            "What's my copay for an urgent care visit?",
            "How much deductible do I have remaining?",
            "Is physical therapy covered under my plan?",
            "Do I need pre-authorization for anything?",
            "What's the difference between my in-network and out-of-network costs?",
            "When does my coverage end?",
            "Explain what coinsurance means for my plan",
            "What zero-cost services are available to me?",
        ]

        if let plan = planResponse?.healthPlan {
            if plan.includesDental {
                suggestions.append("What dental benefits do I have?")
            }
            if plan.includesVision {
                suggestions.append("What vision benefits do I have?")
            }
        }

        return suggestions
    }

    // MARK: - System Prompt Builder

    private func buildSystemPrompt(from response: HealthPlanResponse) -> String {
      //  return "Create a 3 day trip plan for Paris"
        let member = response.memberProfile
        let plan = response.healthPlan
        let fin = response.financialSummary
        let services = response.coveredServices

        let servicesDetail = services.map { svc in
            var detail = "- \(svc.serviceName) (Category: \(svc.category)): "
            detail += "In-network copay: \(svc.formattedInNetworkCopay), "
            detail += "Out-of-network copay: \(svc.formattedOutNetworkCopay), "
            detail += "Coinsurance: \(svc.coinsurancePercentage)%, "
            detail += "Deductible applies: \(svc.deductibleApplies ? "Yes" : "No"), "
            detail += "Pre-authorization required: \(svc.preAuthorizationRequired ? "Yes" : "No")"
            if let limit = svc.annualVisitLimit {
                detail += ", Annual visit limit: \(limit)"
            }
            detail += "\n  Description: \(svc.description)"
            return detail
        }.joined(separator: "\n")

        return """
        You are a friendly and knowledgeable Health Plan Advisor for a healthcare benefits app. \
        Your role is to help the member understand their health insurance plan, coverage details, \
        costs, and benefits. You answer questions clearly and accurately based ONLY on the plan \
        data provided below. If asked about something not covered in the data, say so honestly \
        and suggest they contact their benefits administrator.

        IMPORTANT RULES:
        1. Only use the data provided below. Never fabricate coverage details or costs.
        2. Be conversational, warm, and empathetic — health insurance can be confusing.
        3. Use simple language. Avoid jargon unless explaining it.
        4. When discussing costs, always specify whether it's in-network or out-of-network.
        5. If a service requires pre-authorization, always mention it.
        6. If a deductible applies, explain that the member pays the full cost until the deductible is met.
        7. Format dollar amounts clearly (e.g., "$25.00").
        8. Keep responses concise but thorough. Use bullet points for lists.
        9. Never provide medical advice — only insurance/benefits information.
        10. If the member asks about a service not listed, let them know it may still be covered \
            and recommend checking with member services.

        MEMBER INFORMATION:
        - Name: \(member.fullName)
        - Member ID: \(member.memberId)
        - Date of Birth: \(member.dateOfBirth)
        - Relationship: \(member.relationship)

        HEALTH PLAN DETAILS:
        - Plan Name: \(plan.planLabel)
        - Plan Type: \(plan.planType)
        - Plan ID: \(plan.planId)
        - Status: \(plan.enrollmentStatus)
        - Effective From: \(plan.formattedEffectiveFrom)
        - Effective Through: \(plan.formattedEffectiveThrough)
        - Renewal Date: \(plan.formattedRenewalDate)
        - Group: \(plan.groupName) (\(plan.groupNumber))
        - Network Tier: \(plan.networkTier)
        - Self-Funded: \(plan.isSelfFundedPlan ? "Yes" : "No")
        - Includes Dental: \(plan.includesDental ? "Yes" : "No")
        - Includes Vision: \(plan.includesVision ? "Yes" : "No")
        - Enrollment Type: \(plan.enrollmentType)

        FINANCIAL SUMMARY:
        - Individual Deductible: \(fin.individualDeductible.formattedAmountUsed) used of \
        \(fin.individualDeductible.formattedAnnualLimit) (\(fin.individualDeductible.formattedAmountRemaining) remaining)
        - Family Deductible: \(fin.familyDeductible.formattedAmountUsed) used of \
        \(fin.familyDeductible.formattedAnnualLimit) (\(fin.familyDeductible.formattedAmountRemaining) remaining)
        - Individual Out-of-Pocket Max: \(fin.individualOutOfPocketMax.formattedAmountUsed) used of \
        \(fin.individualOutOfPocketMax.formattedAnnualLimit) (\(fin.individualOutOfPocketMax.formattedAmountRemaining) remaining)
        - Family Out-of-Pocket Max: \(fin.familyOutOfPocketMax.formattedAmountUsed) used of \
        \(fin.familyOutOfPocketMax.formattedAnnualLimit) (\(fin.familyOutOfPocketMax.formattedAmountRemaining) remaining)

        COVERED SERVICES:
        \(servicesDetail)

        GENERAL PLAN KNOWLEDGE (for \(plan.planType) plans):
        - PPO plans allow members to see any provider without a referral, but costs are lower with in-network providers.
        - HMO plans typically require a primary care physician referral to see specialists.
        - The deductible is the amount you pay out-of-pocket before insurance starts covering costs.
        - Coinsurance is the percentage you pay after meeting your deductible.
        - The out-of-pocket maximum is the most you'll pay in a year; after reaching it, the plan covers 100%.
        - Copays are fixed amounts you pay for specific services, often regardless of deductible status.
        - Preventive care services are typically covered at no cost under the Affordable Care Act.
        - Emergency room visits are covered at the same copay whether in-network or out-of-network.
        """
    }
}
