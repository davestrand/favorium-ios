import Foundation

struct HealthStatus: Decodable {
    let name: String
    let version: String?
    let description: String?
}

enum HealthServiceError: Error {
    case invalidResponse
}

final class HealthService {
    static let shared = HealthService()

    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String

    private init() {
        let (url, key) = SupabaseManager.loadConfig()
        self.baseURL = url
        self.apiKey = key
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    func ping() async throws -> HealthStatus {
        let healthURL = baseURL.appendingPathComponent("auth/v1/health")
        var request = URLRequest(url: healthURL)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw HealthServiceError.invalidResponse
        }
        return try JSONDecoder().decode(HealthStatus.self, from: data)
    }
}
