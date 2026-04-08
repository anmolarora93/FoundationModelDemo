import Combine
import Foundation
import FoundationModels

// MARK: - Symptom Result Model

@Generable
struct SymptomNavigatorResult {
    let symptom: String
    let matchedServices: [ServiceMatch]
    let summary: String

    @Generable
    struct ServiceMatch: Identifiable {
        let id = UUID()
        let service: CoveredService
        let relevanceNote: String  // Why this service was matched
        let urgencyHint: UrgencyHint

        @Generable
        enum UrgencyHint {
            case routine, soonish, urgent
            var label: String {
                switch self {
                case .routine:  return "Routine"
                case .soonish:  return "Within a few days"
                case .urgent:   return "Seek care soon"
                }
            }
            var color: String {  // Using string for SwiftUI Color mapping in View
                switch self {
                case .routine:  return "green"
                case .soonish:  return "orange"
                case .urgent:   return "red"
                }
            }
            var icon: String {
                switch self {
                case .routine:  return "clock"
                case .soonish:  return "exclamationmark.circle"
                case .urgent:   return "exclamationmark.triangle.fill"
                }
            }
        }
    }
}

// MARK: - Symptom Navigator ViewModel

@MainActor
final class SymptomNavigatorViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var symptomText = ""
    @Published var isAnalyzing = false
    @Published var result: SymptomNavigatorResult?
    @Published var errorMessage: String?
    @Published var isModelAvailable = false
    
    // MARK: - Private
    private var session: LanguageModelSession?
    private var planResponse: HealthPlanResponse?
    
    // MARK: - Suggested Symptoms
    let suggestedSymptoms = [
        "Knee pain", "Back pain", "Headache",
        "Anxiety or stress", "Blurry vision",
        "Chest tightness", "Sore throat",
        "Skin rash", "Trouble sleeping", "Ear pain"
    ]
    
    // MARK: - Setup
    
    func configure(with planResponse: HealthPlanResponse) {
        self.planResponse = planResponse
        checkAvailability()
        createSession()
    }
    
    private func checkAvailability() {
        switch SystemLanguageModel.default.availability {
        case .available:
            isModelAvailable = true
        case .unavailable:
            isModelAvailable = false
            errorMessage = "Apple Intelligence is not available on this device."
        }
    }
    
    private func createSession() {
        guard isModelAvailable, let planResponse else { return }
        session = LanguageModelSession(instructions: buildSystemPrompt(from: planResponse))
    }
    
    // MARK: - Analyze Symptom
    
    func analyze() async {
        let symptom = symptomText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !symptom.isEmpty, let session, let planResponse else { return }
        
        isAnalyzing = true
        errorMessage = nil
        result = nil
        
        let prompt = """
        The member describes this symptom or health concern: "\(symptom)"
        Only include services that are genuinely relevant. Order by most relevant first. Max 4 matches.
        Never provide medical diagnosis or medical advice. Focus purely on benefits navigation.
        """
        
        do {
            let response = try await session.respond(to: prompt,
                                                     generating: SymptomNavigatorResult.self)
            result = response.content
        } catch {
            errorMessage = "Could not analyze symptom. Please try rephrasing. (\(error.localizedDescription))"
        }
        
        isAnalyzing = false
    }
    
    func clear() {
        symptomText = ""
        result = nil
        errorMessage = nil
        // Fresh session so context doesn't bleed between queries
        createSession()
    }
    
    private enum ParseError: LocalizedError {
        case invalidFormat
        var errorDescription: String? { "Could not parse the response. Please try again." }
    }
    
    // MARK: - System Prompt
    
    private func buildSystemPrompt(from response: HealthPlanResponse) -> String {
        let services = response.coveredServices.map { svc in
            "- ID: \(svc.serviceId) | \(svc.serviceName) (Category: \(svc.category)) | In-network: \(svc.formattedInNetworkCopay) | Pre-auth: \(svc.preAuthorizationRequired ? "Yes" : "No")"
        }.joined(separator: "\n")
        
        return """
        You are a Health Benefits Navigator. Your ONLY job is to map symptoms or health concerns \
        to the most relevant covered services in the member's health plan.
        
        CRITICAL RULES:
        1. Never provide medical diagnosis, medical advice, or treatment recommendations.
        2. Always remind the user to consult a healthcare professional for medical decisions.
        3. Only reference services from the covered services list below.
        4. Respond ONLY in the exact JSON format requested. No prose, no markdown.
        5. Be conservative with urgency — only use "urgent" for clearly serious symptoms.
        6. Focus on benefits navigation, not clinical guidance.
        
        COVERED SERVICES:
        \(services)
        """
    }
}
