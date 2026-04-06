import SwiftUI

// MARK: - Cost Estimate Result Model

struct CostEstimate {
    let service: CoveredService
    let plannedVisits: Int
    let perVisitCost: Double
    let totalOutOfPocket: Double
    let deductibleApplied: Double
    let coinsuranceApplied: Double
    let copayTotal: Double
    let breakdown: [EstimateLineItem]
    let note: String?
}

struct EstimateLineItem: Identifiable {
    let id = UUID()
    let visitNumber: Int
    let copay: Double
    let deductibleApplied: Double
    let coinsuranceApplied: Double
    let youPay: Double
    let deductibleRemainingAfter: Double
}

// MARK: - Cost Estimator View

struct CostEstimatorView: View {
    @ObservedObject var viewModel: HealthPlanViewModel

    @State private var selectedService: CoveredService?
    @State private var visitCount: Double = 1
    @State private var showEstimate = false
    @State private var estimate: CostEstimate?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                servicePickerCard
                visitSliderCard
                if showEstimate, let estimate {
                    estimateResultCard(estimate)
                    visitBreakdownCard(estimate)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Cost Estimator")
        .onChange(of: selectedService) { _, _ in recalculate() }
        .onChange(of: visitCount) { _, _ in recalculate() }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title)
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 4) {
                Text("Estimate Your Costs")
                    .font(.headline)
                Text("See what you'll actually pay based on your current deductible and plan details.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Service Picker

    private var servicePickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Select a Service", systemImage: "cross.case")
                .font(.headline)

            Divider()

            if viewModel.coveredServices.isEmpty {
                Text("Loading services...")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.coveredServices) { svc in
                            serviceChip(svc)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func serviceChip(_ svc: CoveredService) -> some View {
        let isSelected = selectedService?.id == svc.id
        Button {
            selectedService = svc
        } label: {
            VStack(spacing: 6) {
                Image(systemName: svc.categoryIcon)
                    .font(.title3)
                Text(svc.serviceName)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 80)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.teal : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.teal : Color.clear, lineWidth: 2)
            )
        }
    }

    // MARK: - Visit Slider

    private var visitSliderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Planned Visits", systemImage: "calendar.badge.clock")
                .font(.headline)

            Divider()

            HStack {
                Text("Visits per year")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(visitCount))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.teal)
            }

            Slider(value: $visitCount, in: 1...30, step: 1)
                .tint(.teal)

            HStack {
                Text("1")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("30")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let svc = selectedService, let limit = svc.annualVisitLimit, Int(visitCount) > limit {
                Label("Your plan only covers \(limit) visits/year. Costs beyond that are fully out-of-pocket.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Estimate Result

    @ViewBuilder
    private func estimateResultCard(_ estimate: CostEstimate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Estimate", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.teal)

            Divider()

            HStack(alignment: .top, spacing: 0) {
                estimateStat(
                    title: "Total You Pay",
                    value: formatted(estimate.totalOutOfPocket),
                    color: .teal,
                    large: true
                )
                Divider().frame(height: 60)
                estimateStat(
                    title: "Per Visit",
                    value: formatted(estimate.perVisitCost),
                    color: .blue
                )
                Divider().frame(height: 60)
                estimateStat(
                    title: "Visits",
                    value: "\(estimate.plannedVisits)",
                    color: .purple
                )
            }
            .padding(.vertical, 8)

            if estimate.copayTotal > 0 {
                costBar(label: "Copays", amount: estimate.copayTotal, total: estimate.totalOutOfPocket, color: .blue)
            }
            if estimate.deductibleApplied > 0 {
                costBar(label: "Toward Deductible", amount: estimate.deductibleApplied, total: estimate.totalOutOfPocket, color: .orange)
            }
            if estimate.coinsuranceApplied > 0 {
                costBar(label: "Coinsurance", amount: estimate.coinsuranceApplied, total: estimate.totalOutOfPocket, color: .purple)
            }

            if let note = estimate.note {
                Label(note, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private func estimateStat(title: String, value: String, color: Color, large: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(large ? .title2 : .title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func costBar(label: String, amount: Double, total: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(formatted(amount)).font(.caption).fontWeight(.semibold).foregroundStyle(color)
            }
            ProgressView(value: total > 0 ? amount / total : 0).tint(color)
        }
    }

    // MARK: - Visit Breakdown

    @ViewBuilder
    private func visitBreakdownCard(_ estimate: CostEstimate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Visit-by-Visit Breakdown", systemImage: "list.number")
                .font(.headline)

            Divider()

            ForEach(estimate.breakdown.prefix(10)) { item in
                HStack(spacing: 12) {
                    Text("Visit \(item.visitNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        if item.deductibleApplied > 0 {
                            Text("Deductible: \(formatted(item.deductibleApplied))")
                                .font(.caption2).foregroundStyle(.orange)
                        }
                        if item.copay > 0 {
                            Text("Copay: \(formatted(item.copay))")
                                .font(.caption2).foregroundStyle(.blue)
                        }
                        if item.coinsuranceApplied > 0 {
                            Text("Coinsurance: \(formatted(item.coinsuranceApplied))")
                                .font(.caption2).foregroundStyle(.purple)
                        }
                    }

                    Spacer()

                    Text(formatted(item.youPay))
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("Ded left: \(formatted(item.deductibleRemainingAfter))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                if item.visitNumber < min(estimate.breakdown.count, 10) {
                    Divider()
                }
            }

            if estimate.breakdown.count > 10 {
                Text("+ \(estimate.breakdown.count - 10) more visits…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Calculation

    private func recalculate() {
        guard let svc = selectedService,
              let financial = viewModel.financialSummary else {
            showEstimate = false
            return
        }

        estimate = viewModel.estimateCost(
            for: svc,
            visits: Int(visitCount),
            financial: financial
        )
        withAnimation(.spring(duration: 0.4)) { showEstimate = true }
    }

    private func formatted(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}
