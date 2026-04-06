import Foundation

// MARK: - Network Error

enum NetworkError: LocalizedError {
    case fileNotFound
    case decodingFailed(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The health plan data file could not be found."
        case .decodingFailed(let error):
            return "Failed to decode health plan data: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred while fetching health plan data."
        }
    }
}

// MARK: - Health Plan Service Protocol

protocol HealthPlanServiceProtocol {
    func fetchHealthPlanData() async throws -> HealthPlanResponse
}

// MARK: - Mock Health Plan Service
/// Simulates a network call by loading data from the local app bundle.
/// In a production app, this would be replaced with a real URLSession-based service.

final class HealthPlanService: HealthPlanServiceProtocol {

    func fetchHealthPlanData() async throws -> HealthPlanResponse {
        // Simulate network latency
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds

        guard let url = Bundle.main.url(forResource: "HealthPlanData", withExtension: "json") else {
            throw NetworkError.fileNotFound
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(HealthPlanResponse.self, from: data)
            return response
        } catch let decodingError as DecodingError {
            throw NetworkError.decodingFailed(decodingError)
        } catch {
            throw NetworkError.unknown
        }
    }
}
