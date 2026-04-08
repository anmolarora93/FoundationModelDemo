import Foundation
import FoundationModels

// MARK: - Root Response

struct HealthPlanResponse: Codable {
    let memberProfile: MemberProfile
    let healthPlan: HealthPlan
    let financialSummary: FinancialSummary
    let coveredServices: [CoveredService]

    enum CodingKeys: String, CodingKey {
        case memberProfile = "member_profile"
        case healthPlan = "health_plan"
        case financialSummary = "financial_summary"
        case coveredServices = "covered_services"
    }
}

// MARK: - Member Profile

struct MemberProfile: Codable, Hashable {
    let memberId: String
    let fullName: String
    let dateOfBirth: String
    let relationship: String

    enum CodingKeys: String, CodingKey {
        case memberId = "member_id"
        case fullName = "full_name"
        case dateOfBirth = "date_of_birth"
        case relationship
    }
}

// MARK: - Health Plan

struct HealthPlan: Codable, Hashable {
    let planId: String
    let planLabel: String
    let planType: String
    let enrollmentStatus: String
    let effectiveFrom: String
    let effectiveThrough: String
    let renewalDate: String
    let groupNumber: String
    let groupName: String
    let networkTier: String
    let isSelfFundedPlan: Bool
    let includesDental: Bool
    let includesVision: Bool
    let enrollmentType: String

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case planLabel = "plan_label"
        case planType = "plan_type"
        case enrollmentStatus = "enrollment_status"
        case effectiveFrom = "effective_from"
        case effectiveThrough = "effective_through"
        case renewalDate = "renewal_date"
        case groupNumber = "group_number"
        case groupName = "group_name"
        case networkTier = "network_tier"
        case isSelfFundedPlan = "is_self_funded_plan"
        case includesDental = "includes_dental"
        case includesVision = "includes_vision"
        case enrollmentType = "enrollment_type"
    }

    var isActive: Bool {
        enrollmentStatus.lowercased() == "active"
    }

    var formattedEffectiveFrom: String {
        Self.formatDate(effectiveFrom)
    }

    var formattedEffectiveThrough: String {
        Self.formatDate(effectiveThrough)
    }

    var formattedRenewalDate: String {
        Self.formatDate(renewalDate)
    }

    private static func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Financial Summary

struct FinancialSummary: Codable, Hashable {
    let individualDeductible: FinancialBucket
    let familyDeductible: FinancialBucket
    let individualOutOfPocketMax: FinancialBucket
    let familyOutOfPocketMax: FinancialBucket

    enum CodingKeys: String, CodingKey {
        case individualDeductible = "individual_deductible"
        case familyDeductible = "family_deductible"
        case individualOutOfPocketMax = "individual_out_of_pocket_max"
        case familyOutOfPocketMax = "family_out_of_pocket_max"
    }
}

struct FinancialBucket: Codable, Hashable {
    let annualLimit: Double
    let amountUsed: Double
    let amountRemaining: Double

    enum CodingKeys: String, CodingKey {
        case annualLimit = "annual_limit"
        case amountUsed = "amount_used"
        case amountRemaining = "amount_remaining"
    }

    var usagePercentage: Double {
        guard annualLimit > 0 else { return 0 }
        return amountUsed / annualLimit
    }

    var formattedAnnualLimit: String {
        Self.currencyFormatter.string(from: NSNumber(value: annualLimit)) ?? "$0"
    }

    var formattedAmountUsed: String {
        Self.currencyFormatter.string(from: NSNumber(value: amountUsed)) ?? "$0"
    }

    var formattedAmountRemaining: String {
        Self.currencyFormatter.string(from: NSNumber(value: amountRemaining)) ?? "$0"
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
}

// MARK: - Covered Service
@Generable
struct CoveredService: Codable, Identifiable, Hashable {
    let serviceId: String
    let serviceName: String
    let category: String
    let inNetworkCopay: Double?
    let outNetworkCopay: Double?
    let coinsurancePercentage: Int
    let deductibleApplies: Bool
    let annualVisitLimit: Int?
    let preAuthorizationRequired: Bool
    let description: String

    var id: String { serviceId }

    enum CodingKeys: String, CodingKey {
        case serviceId = "service_id"
        case serviceName = "service_name"
        case category
        case inNetworkCopay = "in_network_copay"
        case outNetworkCopay = "out_network_copay"
        case coinsurancePercentage = "coinsurance_percentage"
        case deductibleApplies = "deductible_applies"
        case annualVisitLimit = "annual_visit_limit"
        case preAuthorizationRequired = "pre_authorization_required"
        case description
    }

    var formattedInNetworkCopay: String {
        guard let copay = inNetworkCopay else { return "N/A" }
        if copay == 0 { return "$0 (No Cost)" }
        return Self.currencyFormatter.string(from: NSNumber(value: copay)) ?? "N/A"
    }

    var formattedOutNetworkCopay: String {
        guard let copay = outNetworkCopay else { return "Not Covered" }
        return Self.currencyFormatter.string(from: NSNumber(value: copay)) ?? "N/A"
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    var categoryIcon: String {
        switch category.lowercased() {
        case "preventive": return "heart.text.clipboard"
        case "primary care": return "stethoscope"
        case "specialty care": return "person.badge.clock"
        case "urgent care": return "cross.case"
        case "emergency": return "staroflife"
        case "pharmacy": return "pills"
        case "behavioral health": return "brain.head.profile"
        case "diagnostics": return "testtube.2"
        case "rehabilitation": return "figure.walk"
        case "virtual care": return "video"
        case "vision": return "eye"
        default: return "cross.case"
        }
    }
}
