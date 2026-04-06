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

// MARK: - Cost Estimator Logic
// Add this extension to the bottom of HealthPlanViewModel.swift
// Nothing else in the file changes.

extension HealthPlanViewModel {

    /// Calculates a detailed out-of-pocket cost estimate for a given service and visit count,
    /// accounting for the member's current deductible balance and coinsurance.
    func estimateCost(
        for service: CoveredService,
        visits: Int,
        financial: FinancialSummary
    ) -> CostEstimate {

        let copay = service.inNetworkCopay ?? 0
        let coinsurancePct = Double(service.coinsurancePercentage) / 100.0
        let deductibleApplies = service.deductibleApplies
        var deductibleRemaining = financial.individualDeductible.amountRemaining

        // Estimate a typical visit's base cost for coinsurance calculation.
        // We use a reasonable baseline per category since actual billed amounts aren't in the data.
        let estimatedBilledAmount = billedAmount(for: service)

        var breakdownItems: [EstimateLineItem] = []
        var totalCopays = 0.0
        var totalDeductible = 0.0
        var totalCoinsurance = 0.0

        // If service has an annual visit limit and user exceeds it, mark those visits as full cost
        let coveredVisits = service.annualVisitLimit.map { min(visits, $0) } ?? visits
        let uncoveredVisits = visits - coveredVisits

        for i in 1...max(1, visits) {
            var youPay = 0.0
            var deductApplied = 0.0
            var coinsuranceApplied = 0.0
            var copayApplied = 0.0

            if i > coveredVisits {
                // Beyond visit limit — full billed amount
                youPay = estimatedBilledAmount
            } else if deductibleApplies && deductibleRemaining > 0 {
                // Deductible phase: member pays full cost until deductible met
                let toPay = min(estimatedBilledAmount, deductibleRemaining)
                deductApplied = toPay
                deductibleRemaining -= toPay
                youPay = toPay

                // If deductible is now met mid-visit, apply coinsurance to remainder
                let remainder = estimatedBilledAmount - toPay
                if remainder > 0 && coinsurancePct > 0 {
                    coinsuranceApplied = remainder * coinsurancePct
                    youPay += coinsuranceApplied
                }
            } else if deductibleApplies && deductibleRemaining <= 0 {
                // Post-deductible: pay coinsurance on billed amount
                copayApplied = copay
                coinsuranceApplied = estimatedBilledAmount * coinsurancePct
                youPay = copayApplied + coinsuranceApplied
            } else {
                // Deductible doesn't apply — just copay (+ coinsurance if any)
                copayApplied = copay
                coinsuranceApplied = (coinsurancePct > 0 && estimatedBilledAmount > 0)
                    ? estimatedBilledAmount * coinsurancePct : 0
                youPay = copayApplied + coinsuranceApplied
            }

            totalCopays += copayApplied
            totalDeductible += deductApplied
            totalCoinsurance += coinsuranceApplied

            breakdownItems.append(EstimateLineItem(
                visitNumber: i,
                copay: copayApplied,
                deductibleApplied: deductApplied,
                coinsuranceApplied: coinsuranceApplied,
                youPay: youPay,
                deductibleRemainingAfter: max(deductibleRemaining, 0)
            ))
        }

        let total = totalCopays + totalDeductible + totalCoinsurance +
                    (Double(uncoveredVisits) * estimatedBilledAmount)
        let perVisit = visits > 0 ? total / Double(visits) : 0

        var note: String?
        if uncoveredVisits > 0 {
            note = "\(uncoveredVisits) visit(s) exceed your \(service.annualVisitLimit ?? 0)-visit annual limit and are estimated at full cost."
        } else if service.preAuthorizationRequired {
            note = "⚠️ This service requires pre-authorization. Without it, your claim may be denied."
        }

        return CostEstimate(
            service: service,
            plannedVisits: visits,
            perVisitCost: perVisit,
            totalOutOfPocket: total,
            deductibleApplied: totalDeductible,
            coinsuranceApplied: totalCoinsurance,
            copayTotal: totalCopays,
            breakdown: breakdownItems,
            note: note
        )
    }

    /// Rough billed-amount baseline per service category for coinsurance math.
    private func billedAmount(for service: CoveredService) -> Double {
        switch service.category.lowercased() {
        case "emergency":           return 1500.0
        case "specialty care":      return 300.0
        case "diagnostics":         return 200.0
        case "rehabilitation":      return 150.0
        case "primary care":        return 150.0
        case "behavioral health":   return 150.0
        case "urgent care":         return 200.0
        case "pharmacy":            return (service.inNetworkCopay ?? 0) * 3
        default:                    return 100.0
        }
    }
}
