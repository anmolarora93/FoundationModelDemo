import SwiftUI

struct BenefitsListView: View {
    @ObservedObject var viewModel: HealthPlanViewModel

    var body: some View {
        List {
            if viewModel.isLoading {
                Section {
                    ProgressView("Loading benefits...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
            } else if viewModel.coveredServices.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Benefits Found",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Benefits information is not available at this time.")
                    )
                }
            } else {
                ForEach(groupedServices, id: \.key) { category, services in
                    Section {
                        ForEach(services) { service in
                            NavigationLink(value: service) {
                                ServiceRowView(service: service)
                            }
                        }
                    } header: {
                        Label(category, systemImage: services.first?.categoryIcon ?? "cross.case")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Benefits & Coverage")
        .searchable(text: $viewModel.searchText, prompt: "Search services...")
        .navigationDestination(for: CoveredService.self) { service in
            ServiceDetailView(service: service)
        }
    }

    private var groupedServices: [(key: String, value: [CoveredService])] {
        Dictionary(grouping: viewModel.filteredServices, by: \.category)
            .sorted { $0.key < $1.key }
            .map { (key: $0.key, value: $0.value) }
    }
}

// MARK: - Service Row

struct ServiceRowView: View {
    let service: CoveredService

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: service.categoryIcon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(service.serviceName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Label(service.formattedInNetworkCopay, systemImage: "building.2")
                        .font(.caption)
                        .foregroundStyle(.green)

                    if service.preAuthorizationRequired {
                        Label("Auth Required", systemImage: "lock.shield")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            if service.deductibleApplies {
                Text("DED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Service Detail View

struct ServiceDetailView: View {
    let service: CoveredService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: service.categoryIcon)
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text(service.serviceName)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(service.category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Description
                Text(service.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Cost Details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cost Details")
                        .font(.headline)

                    Divider()

                    detailRow(label: "In-Network Copay", value: service.formattedInNetworkCopay, color: .green)
                    detailRow(label: "Out-of-Network Copay", value: service.formattedOutNetworkCopay, color: .orange)
                    detailRow(label: "Coinsurance", value: "\(service.coinsurancePercentage)%", color: .blue)
                    detailRow(label: "Deductible Applies", value: service.deductibleApplies ? "Yes" : "No",
                              color: service.deductibleApplies ? .orange : .green)
                    detailRow(label: "Pre-Auth Required", value: service.preAuthorizationRequired ? "Yes" : "No",
                              color: service.preAuthorizationRequired ? .orange : .green)

                    if let limit = service.annualVisitLimit {
                        detailRow(label: "Annual Visit Limit", value: "\(limit) visits", color: .purple)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Service Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func detailRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}
