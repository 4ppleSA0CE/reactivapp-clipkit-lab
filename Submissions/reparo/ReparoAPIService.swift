import Foundation

// MARK: - Models

struct RepairResult: Codable {
    let repairability: String?
    let difficulty: String?
    let estimated_time: String?
    let estimated_cost_usd: Double?
    let brief_description: String?
    let repair_steps: [String]?
    let parts_needed: [String]?
    let tools_needed: [String]?
    let products: ProductLinks?
}

struct ProductLinks: Codable {
    let parts: [ProductLink]?
    let tools: [ProductLink]?
    let source: String?
}

struct ProductLink: Codable, Identifiable {
    let title: String?``
    let url: String?

    var id: String { url ?? UUID().uuidString }
}

// MARK: - API Service

enum ReparoAPIService {

    // TODO: Replace with your Mac's LAN IP for simulator testing.
    // iOS Simulator cannot reach localhost — use `ipconfig getifaddr en0`.
    static let baseURL = "http://10.200.14.212:8000"

    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func analyze(imageData: Data, mimeType: String = "image/jpeg") async throws -> RepairResult {
        guard let url = URL(string: "\(baseURL)/analyze") else {
            throw APIError(message: "Invalid API URL")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let ext = mimeType.contains("png") ? "png" : mimeType.contains("webp") ? "webp" : "jpg"
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.\(ext)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid server response")
        }

        if http.statusCode == 503 {
            throw APIError(message: "AI rate limit reached. Please wait a minute and try again.")
        }

        guard (200...299).contains(http.statusCode) else {
            if let detail = try? JSONDecoder().decode([String: String].self, from: data),
               let msg = detail["detail"] ?? detail["message"] {
                throw APIError(message: msg)
            }
            throw APIError(message: "Analysis failed (HTTP \(http.statusCode))")
        }

        return try JSONDecoder().decode(RepairResult.self, from: data)
    }
}

// MARK: - Data helpers

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { self.append(d) }
    }
}
