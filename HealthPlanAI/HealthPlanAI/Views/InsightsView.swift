import SwiftUI
import FoundationModels

// MARK: - Insight Model

struct HealthInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let message: String
    let actionLabel: String?
    let priority: Priority

    enum InsightType {
        case deductiblePace, unusedBenefit, visitLimit, freeService,
             renewalReminder, outOfPocketProgress, preAuthWarning

        var icon: String {
            switch self {
            case .deductiblePace:       return "chart.line.uptrend.xyaxis"
            case .unusedBenefit:        return "gift.fill"
            case .visitLimit:           return "calendar.badge.exclamationmark"
            case .freeService:          return "star.fill"
            case .renewalReminder:      return "arrow.clockwise.circle.fill"
            case .outOfPocketProgress:  return "shield.lefthalf.filled"
            case .preAuthWarning:       return "lock.shield.fill"
            }
        }

        var color: Color {
            switch self {
            case .deductiblePace:       return .blue
            case .unusedBenefit:        return .green
            case .visitLimit:           return .orange
            case .freeService:          return .teal
            case .renewalReminder:      return .purple
            case .outOfPocketProgress:  return .indigo
            case .preAuthWarning:       return .red
            }
        }
    }

    enum Priority: Int, Comparable {
        case high = 0, medium = 1, low = 2
        static func < (lhs: Priority, rhs: Priority) -> Bool { lhs.rawValue < rhs.rawValue }
    }
}

// MARK: - Insights Engine

struct InsightsEngine {
    static func generate(from response: HealthPlanResponse) -> [HealthInsight] {
        var insights: [HealthInsight] = []
        let plan = response.healthPlan
        let fin = response.financialSummary
        let services = response.coveredServices

        // 1. Deductible pace projection
        let yearFraction = yearProgressFraction(from: plan.effectiveFrom, through: plan.effectiveThrough)
        if yearFraction > 0 {
            let projectedUsage = yearFraction > 0
                ? fin.individualDeductible.amountUsed / yearFraction
                : 0
            let limit = fin.individualDeductible.annualLimit
            if projectedUsage < limit * 0.5 && yearFraction > 0.25 {
                insights.append(.init(
                    type: .deductiblePace,
                    title: "On Track to Stay Under Deductible",
                    message: "At your current pace, you're projected to use \(currency(projectedUsage)) of your \(currency(limit)) deductible this year. You likely won't hit it — consider using remaining preventive benefits.",
                    actionLabel: "See Free Services",
                    priority: .medium
                ))
            } else if projectedUsage >= limit {
                insights.append(.init(
                    type: .deductiblePace,
                    title: "You May Hit Your Deductible",
                    message: "Based on your usage so far, you're on track to meet your \(currency(limit)) individual deductible. After that, coinsurance kicks in and your costs drop.",
                    actionLabel: nil,
                    priority: .high
                ))
            }
        }

        // 2. Free / $0 services the user may not know about
        let freeServices = services.filter {
            ($0.inNetworkCopay ?? 1) == 0 && !$0.deductibleApplies
        }
        if !freeServices.isEmpty {
            let names = freeServices.prefix(3).map(\.serviceName).joined(separator: ", ")
            insights.append(.init(
                type: .freeService,
                title: "You Have \(freeServices.count) Free In-Network Services",
                message: "These cost you nothing when using in-network providers: \(names)\(freeServices.count > 3 ? ", and more" : "").",
                actionLabel: "View All",
                priority: .low
            ))
        }

        // 3. Vision exam unused check (annual limit = 1)
        if plan.includesVision,
           let vision = services.first(where: { $0.category.lowercased() == "vision" }),
           let limit = vision.annualVisitLimit, limit == 1 {
            insights.append(.init(
                type: .unusedBenefit,
                title: "Use Your Annual Vision Exam",
                message: "Your plan covers 1 vision exam per year at just \(vision.formattedInNetworkCopay) in-network. Make sure you schedule it before your plan renews.",
                actionLabel: nil,
                priority: .medium
            ))
        }

        // 4. Dental included reminder
        if plan.includesDental {
            insights.append(.init(
                type: .unusedBenefit,
                title: "Dental Coverage Included",
                message: "Your \(plan.planLabel) plan includes dental benefits. Check your dental provider network to make sure your dentist is in-network.",
                actionLabel: nil,
                priority: .low
            ))
        }

        // 5. Services requiring pre-authorization
        let preAuthServices = services.filter(\.preAuthorizationRequired)
        if !preAuthServices.isEmpty {
            let names = preAuthServices.map(\.serviceName).joined(separator: ", ")
            insights.append(.init(
                type: .preAuthWarning,
                title: "\(preAuthServices.count) Service\(preAuthServices.count > 1 ? "s" : "") Require Pre-Authorization",
                message: "Always get approval before scheduling: \(names). Skipping pre-auth can result in claim denial.",
                actionLabel: nil,
                priority: .high
            ))
        }

        // 6. Out-of-pocket max progress
        let oopPct = fin.individualOutOfPocketMax.usagePercentage
        if oopPct >= 0.7 {
            insights.append(.init(
                type: .outOfPocketProgress,
                title: "You're \(Int(oopPct * 100))% Toward Your Out-of-Pocket Max",
                message: "You've paid \(currency(fin.individualOutOfPocketMax.amountUsed)) of your \(currency(fin.individualOutOfPocketMax.annualLimit)) max. Once you hit it, your plan covers 100% for the rest of the year.",
                actionLabel: nil,
                priority: .high
            ))
        }

        // 7. Renewal reminder (within 60 days)
        if let renewDate = parseDate(plan.renewalDate) {
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: renewDate).day ?? 999
            if daysUntil <= 60 && daysUntil >= 0 {
                insights.append(.init(
                    type: .renewalReminder,
                    title: "Plan Renews in \(daysUntil) Days",
                    message: "Your \(plan.planLabel) coverage renews on \(plan.formattedRenewalDate). Use any remaining benefits — deductibles and out-of-pocket amounts reset at renewal.",
                    actionLabel: nil,
                    priority: .high
                ))
            }
        }

        // 8. Telehealth is free nudge
        if let telehealth = services.first(where: { $0.category.lowercased() == "virtual care" }),
           (telehealth.inNetworkCopay ?? 1) == 0 {
            insights.append(.init(
                type: .unusedBenefit,
                title: "Telehealth is Free on Your Plan",
                message: "Virtual care visits cost \(telehealth.formattedInNetworkCopay). Consider telehealth for non-emergency concerns before scheduling an in-person visit.",
                actionLabel: nil,
                priority: .low
            ))
        }

        return insights.sorted { $0.priority < $1.priority }
    }

    // MARK: - Helpers

    private static func yearProgressFraction(from start: String, through end: String) -> Double {
        guard let s = parseDate(start), let e = parseDate(end) else { return 0 }
        let total = e.timeIntervalSince(s)
        let elapsed = Date().timeIntervalSince(s)
        guard total > 0 else { return 0 }
        return min(max(elapsed / total, 0), 1)
    }

    private static func parseDate(_ str: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str)
    }

    private static func currency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Insights View

struct InsightsView: View {
    @ObservedObject var viewModel: HealthPlanViewModel
    @State private var insights: [HealthInsight] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView("Analyzing your plan...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if insights.isEmpty && viewModel.planResponse != nil {
                    ContentUnavailableView(
                        "No Insights Yet",
                        systemImage: "sparkles",
                        description: Text("Check back as you use your plan throughout the year.")
                    )
                } else {
                    headerBanner
                    ForEach(insights) { insight in
                        InsightCard(insight: insight)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Insights")
        .onAppear { regenerate() }
        .onChange(of: viewModel.planResponse != nil) { _, _ in regenerate() }
    }

    private var headerBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(insights.count) Personalized Insight\(insights.count == 1 ? "" : "s")")
                    .font(.headline)
                Text("Based on your current plan, usage, and coverage year.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(colors: [.purple.opacity(0.12), .blue.opacity(0.08)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func regenerate() {
        guard let response = viewModel.planResponse else { return }
        insights = InsightsEngine.generate(from: response)
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let insight: HealthInsight
    @State private var isExpanded = false

    @State private var aiIsWorking = false
    @State private var aiError: String? = nil
    @State private var aiExplanation: String? = nil
    @State private var aiNextSteps: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(insight.type.color.opacity(0.15))
                            .frame(width: 42, height: 42)
                        Image(systemName: insight.type.icon)
                            .font(.title3)
                            .foregroundStyle(insight.type.color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            if insight.priority == .high {
                                Text("IMPORTANT")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(insight.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text(insight.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let action = insight.actionLabel {
                        Button {
                            // Future: navigate to relevant tab
                        } label: {
                            Text(action)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(insight.type.color)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(insight.type.color.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    // AI helper buttons
                    HStack(spacing: 10) {
                        Button {
                            Task { await explainInsight() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("Explain in simple terms")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .disabled(aiIsWorking)

                        Button {
                            Task { await suggestNextSteps() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet")
                                Text("What should I do?")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .disabled(aiIsWorking)

                        if aiIsWorking {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.purple)
                        }
                    }

                    // AI result or error
                    if let error = aiError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let explanation = aiExplanation, !explanation.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("In plain language")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(explanation)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }

                    if let steps = aiNextSteps, !steps.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Suggested next steps")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(steps)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - AI Helpers
    private func availabilityErrorMessage(for availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available:
            return ""
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Please enable Apple Intelligence in Settings."
        case .unavailable(.deviceNotEligible):
            return "Apple Intelligence requires a supported device (iPhone 15 Pro or later) with iOS 26+."
        case .unavailable(.modelNotReady):
            return "The on-device model is downloading or not ready. Try again in a moment."
        default:
            return "Apple Intelligence is unavailable on this device."
        }
    }

    private func baseInstructions() -> String {
        return """
        You are a helpful Health Plan explainer. Stay within these rules:
        - Use only the information provided in the insight.
        - Do not provide medical advice. Focus on benefits/coverage context.
        - Be concise and clear. Avoid jargon.
        - When discussing actions, focus on benefits navigation (e.g., check in-network, pre-auth, limits).
        """
    }

    private func buildInsightContext() -> String {
        var priority = ""
        switch insight.priority {
        case .high: priority = "high"
        case .medium: priority = "medium"
        case .low: priority = "low"
        }
        return """
        Insight Context:
        - Type: \(String(describing: insight.type))
        - Priority: \(priority)
        - Title: \(insight.title)
        - Message: \(insight.message)
        """
    }

    private func resetAIState() {
        aiError = nil
        // Keep past results so users can compare; clear only when starting a new request
    }

    private func startWork() { aiIsWorking = true }
    private func endWork() { aiIsWorking = false }

    private func makeSession(with extraInstructions: String) -> LanguageModelSession? {
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            aiError = availabilityErrorMessage(for: availability)
            return nil
        }
        let instructions = baseInstructions() + "\n\n" + extraInstructions
        return LanguageModelSession(instructions: instructions)
    }

    private func explainPrompt() -> String {
        return """
        Explain the insight plainly for a non-technical audience in <= 100 words.
        Constraints:
        - Keep it simple and friendly.
        - No medical advice.
        - Focus on what the benefit means for the member.
        \n\(buildInsightContext())
        """
    }

    private func nextStepsPrompt() -> String {
        return """
        Provide 2-3 concise, actionable next steps as bullet points (using dashes), focused on benefits navigation only. No medical advice.
        \n\(buildInsightContext())
        """
    }

    private func explainInstructions() -> String { "Keep responses under 100 words. Use friendly, plain language." }
    private func nextStepsInstructions() -> String { "Return 2-3 bullet points only without markdown. Be specific and benefits-focused." }

    @MainActor
    private func explainInsight() async {
        resetAIState()
        startWork()
        defer { endWork() }
        guard let session = makeSession(with: explainInstructions()) else { return }
        do {
            let response = try await session.respond(to: explainPrompt())
            self.aiExplanation = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            self.aiError = "Could not generate an explanation. Please try again. (\(error.localizedDescription))"
        }
    }

    @MainActor
    private func suggestNextSteps() async {
        resetAIState()
        startWork()
        defer { endWork() }
        guard let session = makeSession(with: nextStepsInstructions()) else { return }
        do {
            let response = try await session.respond(to: nextStepsPrompt())
            self.aiNextSteps = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            self.aiError = "Could not generate next steps. Please try again. (\(error.localizedDescription))"
        }
    }
}
