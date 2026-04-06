import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: HealthPlanViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Loading your health plan...")
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else if let plan = viewModel.healthPlan,
                          let member = viewModel.memberProfile,
                          let financial = viewModel.financialSummary {
                    welcomeHeader(member: member, plan: plan)
                    planStatusCard(plan: plan)
                    financialOverview(financial: financial)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("My Health Plan")
    }

    // MARK: - Welcome Header

    @ViewBuilder
    private func welcomeHeader(member: MemberProfile, plan: HealthPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome, \(member.fullName)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Member ID: \(member.memberId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: plan.isActive ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(plan.isActive ? .green : .red)
            }
            HStack(spacing: 4) {
                Circle()
                    .fill(plan.isActive ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(plan.isActive ? "Active Coverage" : "Inactive Coverage")
                    .font(.subheadline)
                    .foregroundStyle(plan.isActive ? .green : .red)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Plan Status Card

    @ViewBuilder
    private func planStatusCard(plan: HealthPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Plan Details", systemImage: "shield.checkered")
                .font(.headline)
                .foregroundStyle(.black)

            Divider()

            planInfoRow(label: "Plan Name", value: plan.planLabel)
            planInfoRow(label: "Plan Type", value: plan.planType)
            planInfoRow(label: "Group", value: plan.groupName)
            planInfoRow(label: "Network", value: plan.networkTier.capitalized)
            planInfoRow(label: "Enrollment", value: plan.enrollmentType.capitalized)
            planInfoRow(label: "Coverage Period",
                        value: "\(plan.formattedEffectiveFrom) – \(plan.formattedEffectiveThrough)")
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func planInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // MARK: - Financial Overview

    @ViewBuilder
    private func financialOverview(financial: FinancialSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Financial Summary", systemImage: "dollarsign.circle")
                .font(.headline)
                .foregroundStyle(.black)

            Divider()

            deductibleCard(
                title: "Individual Deductible",
                bucket: financial.individualDeductible,
                color: .blue
            )
            deductibleCard(
                title: "Family Deductible",
                bucket: financial.familyDeductible,
                color: .purple
            )
            deductibleCard(
                title: "Individual Out-of-Pocket Max",
                bucket: financial.individualOutOfPocketMax,
                color: .orange
            )
            deductibleCard(
                title: "Family Out-of-Pocket Max",
                bucket: financial.familyOutOfPocketMax,
                color: .green
            )
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func deductibleCard(title: String, bucket: FinancialBucket, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            ProgressView(value: bucket.usagePercentage)
                .tint(color)

            HStack {
                Text("\(bucket.formattedAmountUsed) used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(bucket.formattedAmountRemaining) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("of \(bucket.formattedAnnualLimit)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Something went wrong")
                .font(.title3)
                .fontWeight(.semibold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await viewModel.loadData() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}
