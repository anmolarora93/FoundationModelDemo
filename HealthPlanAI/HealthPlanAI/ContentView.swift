import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HealthPlanViewModel()

    var body: some View {
        TabView {
            // ── Existing Tab 1 ──────────────────────────────────────────
            NavigationStack {
                DashboardView(viewModel: viewModel)
            }
            .tabItem {
                Label("Dashboard", systemImage: "heart.text.clipboard")
            }

            // ── Existing Tab 2 ──────────────────────────────────────────
            NavigationStack {
                BenefitsListView(viewModel: viewModel)
            }
            .tabItem {
                Label("Benefits", systemImage: "list.bullet.clipboard")
            }

            // ── NEW: Proactive Insights ─────────────────────────────────
            NavigationStack {
                InsightsView(viewModel: viewModel)
            }
            .tabItem {
                Label("Insights", systemImage: "sparkles")
            }

            // ── NEW: Symptom Navigator ──────────────────────────────────
            NavigationStack {
                SymptomNavigatorView(viewModel: viewModel)
            }
            .tabItem {
                Label("Symptom", systemImage: "stethoscope")
            }

            // ── Existing Tab 3 ──────────────────────────────────────────
            NavigationStack {
                HealthPlanAdvisorView(viewModel: viewModel)
            }
            .tabItem {
                Label("Advisor", systemImage: "apple.intelligence")
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}
