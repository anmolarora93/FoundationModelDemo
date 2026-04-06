//
//  HealthPlanShortcuts.swift
//  HealthPlanAI
//
//  Created by Arora, Anmol on 06/04/26.
//

import AppIntents

struct HealthPlanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetPlanSummaryIntent(),
            phrases: [
                "What's my health plan in \(.applicationName)?",
                "Show my health plan summary in \(.applicationName)",
                "Tell me about my health plan in \(.applicationName)",
                "Get my plan details from \(.applicationName)"
            ],
            shortTitle: "Plan Summary",
            systemImageName: "shield.checkered"
        )

        AppShortcut(
            intent: GetCoverageDatesIntent(),
            phrases: [
                "When does my coverage end in \(.applicationName)?",
                "What are my coverage dates in \(.applicationName)?",
                "When does my plan renew in \(.applicationName)?"
            ],
            shortTitle: "Coverage Dates",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: GetCopayIntent(),
            phrases: [
                "What's my copay for service in \(.applicationName)?",
                "How much does service cost in \(.applicationName)?",
                "Get copay for service from \(.applicationName)"
            ],
            shortTitle: "Service Copay",
            systemImageName: "dollarsign.circle"
        )

        AppShortcut(
            intent: GetDeductibleStatusIntent(),
            phrases: [
                "How much deductible have I used in \(.applicationName)?",
                "Show my deductible status in \(.applicationName)",
                "What's my deductible in \(.applicationName)?"
            ],
            shortTitle: "Deductible Status",
            systemImageName: "chart.bar"
        )

        AppShortcut(
            intent: GetOutOfPocketMaxIntent(),
            phrases: [
                "What's my out of pocket max in \(.applicationName)?",
                "Show my out of pocket maximum in \(.applicationName)",
                "How much out of pocket have I spent in \(.applicationName)?"
            ],
            shortTitle: "Out-of-Pocket Max",
            systemImageName: "creditcard"
        )

        AppShortcut(
            intent: ListCoveredBenefitsIntent(),
            phrases: [
                "What benefits are covered in \(.applicationName)?",
                "List my covered services in \(.applicationName)",
                "Show my benefits in \(.applicationName)"
            ],
            shortTitle: "Covered Benefits",
            systemImageName: "list.clipboard"
        )

        AppShortcut(
            intent: CheckCoverageIntent(),
            phrases: [
                "Is service covered in \(.applicationName)?",
                "Check if service is covered by \(.applicationName)",
                "Does my plan cover service in \(.applicationName)?"
            ],
            shortTitle: "Check Coverage",
            systemImageName: "checkmark.shield"
        )

        AppShortcut(
            intent: CompareCopaysIntent(),
            phrases: [
                "Compare copays for service in \(.applicationName)",
                "Show in-network vs out-of-network for service in \(.applicationName)"
            ],
            shortTitle: "Compare Copays",
            systemImageName: "arrow.left.arrow.right"
        )
    }
}
