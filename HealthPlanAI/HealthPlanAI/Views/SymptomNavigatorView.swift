import SwiftUI

struct SymptomNavigatorView: View {
    @ObservedObject var viewModel: HealthPlanViewModel
    @StateObject private var navVM = SymptomNavigatorViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                inputCard
                if !navVM.isAnalyzing && navVM.result == nil {
                    suggestedSymptomsSection
                }
                if navVM.isAnalyzing {
                    analyzingView
                }
                if let error = navVM.errorMessage {
                    errorCard(error)
                }
                if let result = navVM.result {
                    resultSection(result)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Symptom Navigator")
        .onAppear {
            if let response = viewModel.planResponse {
                navVM.configure(with: response)
            }
        }
        .onChange(of: viewModel.planResponse != nil) { _, isReady in
            if isReady, let response = viewModel.planResponse {
                navVM.configure(with: response)
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "stethoscope.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 4) {
                Text("Symptom → Benefits")
                    .font(.headline)
                Text("Describe how you're feeling and we'll show which covered services apply — not medical advice, just your benefits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What's bothering you?", systemImage: "square.and.pencil")
                .font(.headline)

            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    "e.g. knee pain, anxiety, blurry vision…",
                    text: $navVM.symptomText,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .font(.subheadline)
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    Task { await navVM.analyze() }
                } label: {
                    Label("Find My Benefits", systemImage: "magnifyingglass")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            navVM.symptomText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.indigo.opacity(0.3)
                            : Color.indigo
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(navVM.symptomText.trimmingCharacters(in: .whitespaces).isEmpty || navVM.isAnalyzing)

                if navVM.result != nil {
                    Button {
                        withAnimation { navVM.clear() }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(width: 42, height: 38)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Suggested Symptoms

    private var suggestedSymptomsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Common Concerns")
                .font(.headline)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(navVM.suggestedSymptoms, id: \.self) { symptom in
                    Button {
                        navVM.symptomText = symptom
                        Task { await navVM.analyze() }
                    } label: {
                        Text(symptom)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.indigo.opacity(0.08))
                            .foregroundStyle(.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - Analyzing

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(.indigo)
            Text("Checking your benefits…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Error

    @ViewBuilder
    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Results

    @ViewBuilder
    private func resultSection(_ result: SymptomNavigatorResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            // Summary banner
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.indigo)
                    Text("Benefits for \(result.symptom)")
                        .font(.headline)
                }
                Text(result.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                disclaimerBadge
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Matched service cards
            Text("\(result.matchedServices.count) Relevant Service\(result.matchedServices.count == 1 ? "" : "s") Found")
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(result.matchedServices) { match in
                ServiceMatchCard(match: match)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var disclaimerBadge: some View {
        Label("Not medical advice — consult a healthcare professional for diagnosis and treatment.", systemImage: "info.circle")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Service Match Card

struct ServiceMatchCard: View {
    let match: SymptomNavigatorResult.ServiceMatch

    private var urgencyColor: Color {
        switch match.urgencyHint {
        case .routine:  return .green
        case .soonish:  return .orange
        case .urgent:   return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Top row
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.indigo.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: match.service.categoryIcon)
                        .font(.title3)
                        .foregroundStyle(.indigo)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(match.service.serviceName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(match.service.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Urgency badge
                HStack(spacing: 4) {
                    Image(systemName: match.urgencyHint.icon)
                        .font(.caption2)
                    Text(match.urgencyHint.label)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(urgencyColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(urgencyColor.opacity(0.12))
                .clipShape(Capsule())
            }

            // Relevance note
            Text(match.relevanceNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Cost row
            HStack(spacing: 16) {
                costPill(
                    label: "In-Network",
                    value: match.service.formattedInNetworkCopay,
                    color: .green
                )
                costPill(
                    label: "Out-of-Network",
                    value: match.service.formattedOutNetworkCopay,
                    color: .orange
                )
                if match.service.preAuthorizationRequired {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption2)
                        Text("Pre-Auth")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func costPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
