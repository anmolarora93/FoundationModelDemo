import AppIntents
import Foundation

// MARK: - Shared Data Provider
// Loads plan data synchronously for use inside App Intents (which run outside the main app session).

private struct IntentDataProvider {
    static func loadResponse() throws -> HealthPlanResponse {
        guard let url = Bundle.main.url(forResource: "HealthPlanData", withExtension: "json") else {
            throw IntentError.dataUnavailable
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(HealthPlanResponse.self, from: data)
    }
}

private enum IntentError: LocalizedError {
    case dataUnavailable
    case serviceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .dataUnavailable:
            return "Health plan data is not available right now."
        case .serviceNotFound(let name):
            return "No covered service found matching '\(name)'."
        }
    }
}

// MARK: - 1. Plan Summary Intent
// "Hey Siri, summarize my health plan"

struct PlanSummaryIntent: AppIntent {

    static var title: LocalizedStringResource = "Get Health Plan Summary"
    static var description = IntentDescription("Get a summary of your current health plan and coverage status.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let response = try IntentDataProvider.loadResponse()
        let vm = await MainActor.run { HealthPlanViewModel() }
        await MainActor.run { vm.planResponse = response }
        let summary = await MainActor.run { vm.planSummaryText }
        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
}

// MARK: - Covered Service Enum (required by AppIntents — must be AppEnum)

enum CoveredServiceOption: String, AppEnum {
    case preventiveCare       = "Preventive Care Visit"
    case primaryCare          = "Primary Care Office Visit"
    case specialistConsult    = "Specialist Consultation"
    case urgentCare           = "Urgent Care"
    case emergencyRoom        = "Emergency Room"
    case genericDrugs         = "Generic Prescription Drugs"
    case brandNameDrugs       = "Brand-Name Prescription Drugs"
    case mentalHealth         = "Mental Health - Outpatient"
    case labWork              = "Lab Work & Diagnostics"
    case physicalTherapy      = "Physical Therapy"
    case telehealth           = "Telehealth Visit"
    case visionExam           = "Vision Exam"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Health Service"

    static var caseDisplayRepresentations: [CoveredServiceOption: DisplayRepresentation] = [
        .preventiveCare:    "Preventive Care Visit",
        .primaryCare:       "Primary Care Office Visit",
        .specialistConsult: "Specialist Consultation",
        .urgentCare:        "Urgent Care",
        .emergencyRoom:     "Emergency Room",
        .genericDrugs:      "Generic Prescription Drugs",
        .brandNameDrugs:    "Brand-Name Prescription Drugs",
        .mentalHealth:      "Mental Health - Outpatient",
        .labWork:           "Lab Work & Diagnostics",
        .physicalTherapy:   "Physical Therapy",
        .telehealth:        "Telehealth Visit",
        .visionExam:        "Vision Exam",
    ]
}

// MARK: - 2. Copay Lookup Intent
// "Hey Siri, what's my copay for urgent care?"

struct CopayLookupIntent: AppIntent {

    static var title: LocalizedStringResource = "Look Up Service Copay"
    static var description = IntentDescription("Find out what you'll pay for a specific covered service.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Service", description: "The health service to look up")
    var service: CoveredServiceOption

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let response = try IntentDataProvider.loadResponse()
        let vm = await MainActor.run { HealthPlanViewModel() }
        await MainActor.run { vm.planResponse = response }

        let result = await MainActor.run { vm.copayInfo(for: service.rawValue) }

        if result.hasPrefix("No service found") {
            throw IntentError.serviceNotFound(service.rawValue)
        }

        return .result(value: result, dialog: IntentDialog(stringLiteral: result))
    }
}

// MARK: - 3. Deductible Status Intent
// "Hey Siri, how much deductible do I have left?"

struct DeductibleStatusIntent: AppIntent {

    static var title: LocalizedStringResource = "Check Deductible Status"
    static var description = IntentDescription("Check how much of your deductible you've used and what remains.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let response = try IntentDataProvider.loadResponse()
        let vm = await MainActor.run { HealthPlanViewModel() }
        await MainActor.run { vm.planResponse = response }
        let summary = await MainActor.run { vm.deductibleSummaryText }
        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
}

// MARK: - 4. Coverage Dates Intent
// "Hey Siri, when does my health coverage end?"

struct CoverageDatesIntent: AppIntent {

    static var title: LocalizedStringResource = "Check Coverage Dates"
    static var description = IntentDescription("Find out when your current health plan coverage starts and ends.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let response = try IntentDataProvider.loadResponse()
        let vm = await MainActor.run { HealthPlanViewModel() }
        await MainActor.run { vm.planResponse = response }
        let dates = await MainActor.run { vm.coverageDateText }
        return .result(value: dates, dialog: IntentDialog(stringLiteral: dates))
    }
}

// MARK: - 5. Benefits List Intent
// "Hey Siri, what benefits are covered on my health plan?"

struct BenefitsListIntent: AppIntent {

    static var title: LocalizedStringResource = "List Covered Benefits"
    static var description = IntentDescription("Get a list of all your covered health benefits by category.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let response = try IntentDataProvider.loadResponse()
        let vm = await MainActor.run { HealthPlanViewModel() }
        await MainActor.run { vm.planResponse = response }
        let list = await MainActor.run { vm.benefitsListText }
        return .result(value: list, dialog: IntentDialog(stringLiteral: list))
    }
}

// MARK: - App Shortcuts (Siri Phrases)
// These are the phrases users can say to trigger each intent without setup.

struct HealthPlanShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlanSummaryIntent(),
            phrases: [
                "Summarize my health plan with \(.applicationName)",
                "What's my health plan with \(.applicationName)"
            ],
            shortTitle: "Health Plan Summary",
            systemImageName: "heart.text.clipboard"
        )
        AppShortcut(
            intent: CopayLookupIntent(),
            phrases: [
                "What's my copay for \(\.$service) with \(.applicationName)",
                "How much is \(\.$service) with \(.applicationName)"
            ],
            shortTitle: "Copay Lookup",
            systemImageName: "dollarsign.circle"
        )
        AppShortcut(
            intent: DeductibleStatusIntent(),
            phrases: [
                "How much deductible do I have left with \(.applicationName)",
                "Check my deductible with \(.applicationName)"
            ],
            shortTitle: "Deductible Status",
            systemImageName: "chart.bar.fill"
        )
        AppShortcut(
            intent: CoverageDatesIntent(),
            phrases: [
                "When does my health coverage end with \(.applicationName)",
                "Check my coverage dates with \(.applicationName)"
            ],
            shortTitle: "Coverage Dates",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: BenefitsListIntent(),
            phrases: [
                "What benefits do I have with \(.applicationName)",
                "List my health benefits with \(.applicationName)"
            ],
            shortTitle: "Benefits List",
            systemImageName: "list.bullet.clipboard"
        )
    }
}
