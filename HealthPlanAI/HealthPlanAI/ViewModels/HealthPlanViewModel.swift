import Combine
import Foundation
import SwiftUI

final class HealthPlanViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var planResponse: HealthPlanResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    // MARK: - Dependencies

    private let service: HealthPlanServiceProtocol

    // MARK: - Init

    init(service: HealthPlanServiceProtocol = HealthPlanService()) {
        self.service = service
    }

    // MARK: - Computed Properties

    var memberProfile: MemberProfile? {
        planResponse?.memberProfile
    }

    var healthPlan: HealthPlan? {
        planResponse?.healthPlan
    }

    var financialSummary: FinancialSummary? {
        planResponse?.financialSummary
    }

    var coveredServices: [CoveredService] {
        planResponse?.coveredServices ?? []
    }

    var filteredServices: [CoveredService] {
        guard !searchText.isEmpty else { return coveredServices }
        return coveredServices.filter { service in
            service.serviceName.localizedCaseInsensitiveContains(searchText) ||
            service.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    var serviceCategories: [String] {
        Array(Set(coveredServices.map(\.category))).sorted()
    }

    // MARK: - Loading

    func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await service.fetchHealthPlanData()
            planResponse = response
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Apple Intelligence Helpers

    /// Returns a natural language summary of the member's health plan for Siri / App Intents.
    var planSummaryText: String {
        guard let plan = healthPlan, let member = memberProfile else {
            return "No health plan data is currently available."
        }
        return "\(member.fullName) is enrolled in the \(plan.planLabel) plan, a \(plan.planType) plan provided through \(plan.groupName). " +
               "Coverage is \(plan.enrollmentStatus) from \(plan.formattedEffectiveFrom) through \(plan.formattedEffectiveThrough). " +
               "The plan includes \(plan.includesDental ? "dental" : "no dental") and \(plan.includesVision ? "vision" : "no vision") coverage."
    }

    /// Returns formatted deductible information.
    var deductibleSummaryText: String {
        guard let fin = financialSummary else {
            return "No financial data is available."
        }
        return "Individual deductible: \(fin.individualDeductible.formattedAmountUsed) used of \(fin.individualDeductible.formattedAnnualLimit) (\(fin.individualDeductible.formattedAmountRemaining) remaining). " +
               "Family deductible: \(fin.familyDeductible.formattedAmountUsed) used of \(fin.familyDeductible.formattedAnnualLimit) (\(fin.familyDeductible.formattedAmountRemaining) remaining)."
    }

    /// Returns copay information for a specific service name.
    func copayInfo(for serviceName: String) -> String {
        guard let service = coveredServices.first(where: {
            $0.serviceName.localizedCaseInsensitiveContains(serviceName)
        }) else {
            return "No service found matching '\(serviceName)'. Available services include: \(coveredServices.prefix(5).map(\.serviceName).joined(separator: ", "))."
        }
        var result = "Copay for \(service.serviceName): In-network \(service.formattedInNetworkCopay), Out-of-network \(service.formattedOutNetworkCopay)."
        if service.deductibleApplies {
            result += " Deductible applies."
        }
        if service.preAuthorizationRequired {
            result += " Pre-authorization is required."
        }
        return result
    }

    /// Returns coverage date information.
    var coverageDateText: String {
        guard let plan = healthPlan else {
            return "No plan data available."
        }
        return "Your coverage is active from \(plan.formattedEffectiveFrom) through \(plan.formattedEffectiveThrough). Renewal date is \(plan.formattedRenewalDate)."
    }

    /// Lists all covered benefits by category.
    var benefitsListText: String {
        guard !coveredServices.isEmpty else {
            return "No covered services data available."
        }
        let grouped = Dictionary(grouping: coveredServices, by: \.category)
        return grouped.sorted(by: { $0.key < $1.key }).map { category, services in
            let serviceNames = services.map(\.serviceName).joined(separator: ", ")
            return "\(category): \(serviceNames)"
        }.joined(separator: ". ")
    }
}
