//
//  HealthPlanAppIntents.swift
//  HealthPlanAI
//
//  Created by Arora, Anmol on 06/04/26.
//

import AppIntents
import Foundation

// MARK: - Shared Data Provider

/// A singleton that loads health plan data for use across App Intents.
/// In a real app this would share state with the main app via App Groups or SwiftData.
@MainActor
final class IntentDataProvider {
    static let shared = IntentDataProvider()
    private var cachedResponse: HealthPlanResponse?

    func getHealthPlanData() async throws -> HealthPlanResponse {
        if let cached = cachedResponse { return cached }

        guard let url = Bundle.main.url(forResource: "HealthPlanData", withExtension: "json") else {
            throw IntentError.dataUnavailable
        }
        let data = try Data(contentsOf: url)
        let response = try JSONDecoder().decode(HealthPlanResponse.self, from: data)
        cachedResponse = response
        return response
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case dataUnavailable
    case serviceNotFound(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .dataUnavailable:
            return "Health plan data is not available right now."
        case .serviceNotFound(let name):
            return "No service found matching '\(name)'."
        }
    }
}

// MARK: - 1. Get Plan Summary Intent

struct GetPlanSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get My Health Plan Summary"
    static var description: IntentDescription = "Returns an overview of your current health plan including plan name, type, and coverage period."
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = try await IntentDataProvider.shared.getHealthPlanData()
        let plan = data.healthPlan
        let member = data.memberProfile

        let summary = """
        \(member.fullName), you are enrolled in \(plan.planLabel) (\(plan.planType)). \
        Your coverage is \(plan.enrollmentStatus) from \(plan.formattedEffectiveFrom) \
        through \(plan.formattedEffectiveThrough) via \(plan.groupName). \
        Your plan \(plan.includesDental ? "includes" : "does not include") dental \
        and \(plan.includesVision ? "includes" : "does not include") vision coverage.
        """

        return .result(dialog: "\(summary)")
    }
}

// MARK: - 2. Get Coverage Dates Intent

struct GetCoverageDatesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get My Coverage Dates"
    static var description: IntentDescription = "Returns when your health coverage starts, ends, and renews."
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = try await IntentDataProvider.shared.getHealthPlanData()
        let plan = data.healthPlan

        let response = """
        Your coverage runs from \(plan.formattedEffectiveFrom) to \(plan.formattedEffectiveThrough). \
        Your plan renewal date is \(plan.formattedRenewalDate).
        """

        return .result(dialog: "\(response)")
    }
}

// MARK: - 3. Get Copay Info Intent

struct GetCopayIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Copay for a Service"
    static var description: IntentDescription = "Returns the copay amount for a specific healthcare service."
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Service Name",
        description: "The name of the healthcare service (e.g., Urgent Care, Emergency Room)",
        requestValueDialog: "Which healthcare service (e.g., Urgent Care, Emergency Room)"
    )
    var serviceName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = try await IntentDataProvider.shared.getHealthPlanData()

        guard let service = data.coveredServices.first(where: {
            $0.serviceName.localizedCaseInsensitiveContains(serviceName) ||
            $0.category.localizedCaseInsensitiveContains(serviceName)
        }) else {
            let available = data.coveredServices.map(\.serviceName).joined(separator: ", ")
            throw IntentError.serviceNotFound("\(serviceName). Available services: \(available)")
        }

        var response = "The copay for \(service.serviceName) is \(service.formattedInNetworkCopay) in-network"
        response += " and \(service.formattedOutNetworkCopay) out-of-network."

        if service.coinsurancePercentage > 0 {
            response += " Coinsurance is \(service.coinsurancePercentage)%."
        }
        if service.deductibleApplies {
            response += " Your deductible applies to this service."
        }
        if service.preAuthorizationRequired {
            response += " Pre-authorization is required."
        }

        return .result(dialog: "\(response)")
    }
}

// MARK: - 4. Get Deductible Status Intent

struct GetDeductibleStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get My Deductible Status"
    static var description: IntentDescription = "Returns how much of your deductible has been used and how much remains."
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = try await IntentDataProvider.shared.getHealthPlanData()
        let fin = data.financialSummary

        let response = """
        Individual Deductible: \(fin.individualDeductible.formattedAmountUsed) used of \
        \(fin.individualDeductible.formattedAnnualLimit) \
        (\(fin.individualDeductible.formattedAmountRemaining) remaining). \
        Family Deductible: \(fin.familyDeductible.formattedAmountUsed) used of \
        \(fin.familyDeductible.formattedAnnualLimit) \
        (\(fin.familyDeductible.formattedAmountRemaining) remaining).
        """

        return .result(dialog: "\(response)")
    }
}

// MARK: - 5. Get Out-of-Pocket Max Intent

struct GetOutOfPocketMaxIntent: AppIntent {
    static var title: LocalizedStringResource = "Get My Out-of-Pocket Maximum"
    static var description: IntentDescription = "Returns how much of your out-of-pocket maximum has been used."
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = try await IntentDataProvider.shared.getHealthPlanData()
        let fin = data.financialSummary

        let response = """
        Individual Out-of-Pocket Max: \(fin.individualOutOfPocketMax.formattedAmountUsed) used of \
        \(fin.individualOutOfPocketMax.formattedAnnualLimit) \
        (\(fin.individualOutOfPocketMax.formattedAmountRemaining) remaining). \
        Family Out-of-Pocket Max: \(fin.familyOutOfPocketMax.formattedAmountUsed) used of \
        \(fin.familyOutOfPocketMax.formattedAnnualLimit) \
        (\(fin.familyOutOfPocketMax.formattedAmountRemaining) remaining).
        """

        return .result(dialog: "\(response)")
    }
}

// MARK: - 6. List All Covered Benefits Intent

struct ListCoveredBenefitsIntent: AppIntent {
    static var title: LocalizedStringResource = "List My Covered Benefits"
    static var description: IntentDescription = "Lists all healthcare services covered by your health plan, grouped by category."
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = try await IntentDataProvider.shared.getHealthPlanData()
        let grouped = Dictionary(grouping: data.coveredServices, by: \.category)

        let response = grouped.sorted(by: { $0.key < $1.key }).map { category, services in
            let names = services.map(\.serviceName).joined(separator: ", ")
            return "\(category): \(names)"
        }.joined(separator: ". ")

        return .result(dialog: "Your plan covers: \(response).")
    }
}

// MARK: - 7. Coverage Check (AssistantSchema)

struct CheckCoverageIntent: AppIntent {
    static var title: LocalizedStringResource = "Check If Service Is Covered"
    static var description: IntentDescription = "Check if a specific healthcare service is covered by your plan and get coverage details."

    @Parameter(
        title: "Service to check coverage for",
        requestValueDialog: "Please enter the name of the service you want to check coverage for:"
    )
    var serviceName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = try await IntentDataProvider.shared.getHealthPlanData()

        let matching = data.coveredServices.filter {
            $0.serviceName.localizedCaseInsensitiveContains(serviceName) ||
            $0.category.localizedCaseInsensitiveContains(serviceName) ||
            $0.description.localizedCaseInsensitiveContains(serviceName)
        }

        if matching.isEmpty {
            let categories = Set(data.coveredServices.map(\.category)).sorted()
            return .result(dialog: """
            '\(serviceName)' was not found in your covered services. \
            Your plan covers services in these categories: \(categories.joined(separator: ", ")). \
            Try searching by category or a specific service name.
            """)
        }

        let results = matching.map { svc in
            "\(svc.serviceName): \(svc.formattedInNetworkCopay) copay" +
            (svc.preAuthorizationRequired ? " (pre-auth required)" : "") +
            (svc.deductibleApplies ? " (deductible applies)" : "")
        }.joined(separator: "\n")

        return .result(dialog: "Coverage results for '\(serviceName)':\n\n\(results)")
    }
}

// MARK: - 8. Plan Comparison Helper (AssistantSchema)

struct CompareCopaysIntent: AppIntent {
    static var title: LocalizedStringResource = "Compare Service Copays"
    static var description: IntentDescription = "Compare in-network vs out-of-network copays for services, helping you understand cost differences."

    @Parameter(
        title: "Services to compare",
        requestValueDialog: "Please enter the name of the service: "
    )
    var serviceName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = try await IntentDataProvider.shared.getHealthPlanData()
        let services: [CoveredService]

        if serviceName.isEmpty {
            services = Array(data.coveredServices)
        } else {
            services = data.coveredServices.filter {
                $0.serviceName.localizedCaseInsensitiveContains(serviceName) ||
                $0.category.localizedCaseInsensitiveContains(serviceName)
            }
        }

        guard !services.isEmpty else {
            return .result(dialog: "No services found matching '\(serviceName)'.")
        }

        let comparison = services.map { svc in
            "\(svc.serviceName): In-network \(svc.formattedInNetworkCopay) vs Out-of-network \(svc.formattedOutNetworkCopay)"
        }.joined(separator: "\n")

        return .result(dialog: "Copay Comparison:\n\(comparison)")
    }
}
