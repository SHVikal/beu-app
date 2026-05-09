import Foundation
import UIKit

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decoding(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The backend URL is invalid."
        case .invalidResponse:
            return "The backend returned an unexpected response."
        case .decoding(let message):
            return message
        case .server(let message):
            return message
        }
    }
}

final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURLString: String? = nil, session: URLSession = .shared) {
        let resolvedBaseURLString = baseURLString ?? APIConfig.baseURLString
        self.baseURL = URL(string: resolvedBaseURLString) ?? URL(fileURLWithPath: "/")
        self.session = session
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func fetchHealthStatus() async throws -> BackendHealthStatus {
        try await request(path: "/health", method: "GET", responseType: BackendHealthStatus.self)
    }

    func save(summary: HealthSummary) async throws -> HealthSummary {
        try await send(path: "/api/health-summary", method: "POST", body: summary, responseType: HealthSummary.self)
    }

    func save(goal: UserGoalPayload) async throws -> UserGoalResponse {
        try await send(path: "/api/user-goal", method: "POST", body: goal, responseType: UserGoalResponse.self)
    }

    func fetchWeeklySummaries(userId: String, days: Int = 7) async throws -> WeeklySummaryResponse {
        guard var components = URLComponents(url: baseURL.appending(path: "/api/health-summary/\(userId)"), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "days", value: String(days))]
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await execute(request, responseType: WeeklySummaryResponse.self)
    }

    func generateRecommendation(userId: String, date: String) async throws -> DietRecommendation {
        struct RequestBody: Codable {
            let userId: String
            let date: String
        }

        return try await send(
            path: "/api/diet-recommendation",
            method: "POST",
            body: RequestBody(userId: userId, date: date),
            responseType: DietRecommendation.self
        )
    }

    func saveNutritionProfile(_ profile: UserNutritionProfile) async throws -> UserNutritionProfile {
        try await send(path: "/api/nutrition-profile", method: "POST", body: profile, responseType: UserNutritionProfile.self)
    }

    func updateNutritionProfile(_ profile: UserNutritionProfile) async throws -> UserNutritionProfile {
        try await send(path: "/api/nutrition-profile/\(profile.userId)", method: "PUT", body: profile, responseType: UserNutritionProfile.self)
    }

    func fetchNutritionProfile(userId: String) async throws -> UserNutritionProfile {
        try await request(path: "/api/nutrition-profile/\(userId)", method: "GET", responseType: UserNutritionProfile.self)
    }

    func analyzeFoodImage(userId: String, image: UIImage) async throws -> FoodImageAnalysis {
        let imagePayload = try compressedJPEGPayload(for: image, maxBytes: 10 * 1024 * 1024)
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = baseURL.appending(path: "/api/food/analyze-image")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = makeMultipartBody(
            boundary: boundary,
            userId: userId,
            filename: imagePayload.filename,
            mimeType: imagePayload.mimeType,
            fileData: imagePayload.data
        )
        return try await execute(request, responseType: FoodImageAnalysis.self)
    }

    func analyzeFoodText(
        userId: String,
        description: String,
        mealType: String,
        dietPreference: String
    ) async throws -> FoodImageAnalysis {
        struct RequestBody: Codable {
            let userId: String
            let description: String
            let mealType: String
            let dietPreference: String
        }

        let requestBody = RequestBody(
            userId: userId,
            description: description,
            mealType: mealType,
            dietPreference: dietPreference
        )
        let url = baseURL.appending(path: "/api/food/analyze-text")
        print("[TextMeal] URL:", url.absoluteString)
        print("[TextMeal] Description:", description)
        if let encoded = try? encoder.encode(requestBody),
           let json = String(data: encoded, encoding: .utf8) {
            print("[TextMeal] Request body:", json)
        }

        let analysis = try await send(
            path: "/api/food/analyze-text",
            method: "POST",
            body: requestBody,
            responseType: FoodImageAnalysis.self
        )
        print("[TextMeal] Parsed detected items:", analysis.detectedItems.count)
        print("[TextMeal] Parsed total calories:", analysis.totalCalories)
        return analysis
    }

    func updateFoodAnalysis(analysisId: String, userId: String, imageLocalPath: String?, items: [DetectedFoodItem]) async throws -> FoodImageAnalysis {
        struct RequestBody: Codable {
            let userId: String
            let imageLocalPath: String?
            let items: [DetectedFoodItem]
        }

        return try await send(
            path: "/api/food/analysis/\(analysisId)/items",
            method: "PUT",
            body: RequestBody(userId: userId, imageLocalPath: imageLocalPath, items: items),
            responseType: FoodImageAnalysis.self
        )
    }

    func saveMealLog(_ mealLog: MealLog) async throws -> MealLog {
        try await send(path: "/api/meal-log", method: "POST", body: mealLog, responseType: MealLog.self)
    }

    func updateMealLog(_ mealLog: MealLog) async throws -> MealLog {
        try await send(path: "/api/meal-log/\(mealLog.id)", method: "PUT", body: mealLog, responseType: MealLog.self)
    }

    func fetchMealLogs(userId: String, date: String) async throws -> [MealLog] {
        struct MealLogListResponse: Codable {
            let userId: String
            let date: String
            let meals: [MealLog]
        }

        let response = try await request(path: "/api/meal-log/\(userId)/\(date)", method: "GET", responseType: MealLogListResponse.self)
        return response.meals
    }

    func deleteMealLog(id: String) async throws {
        let _: EmptyResponse = try await request(path: "/api/meal-log/\(id)", method: "DELETE", responseType: EmptyResponse.self, allowEmptyBody: true)
    }

    func fetchNutritionProgress(userId: String, date: String) async throws -> DailyNutritionProgress {
        try await request(path: "/api/nutrition-progress/\(userId)/\(date)", method: "GET", responseType: DailyNutritionProgress.self)
    }

    func fetchWeeklyNutritionSummary(userId: String) async throws -> WeeklyNutritionSummary {
        try await request(path: "/api/weekly-nutrition-summary/\(userId)", method: "GET", responseType: WeeklyNutritionSummary.self)
    }

    func fetchTodayPlan(userId: String) async throws -> DailyPersonalizedActionPlan {
        try await request(path: "/api/plan/\(userId)/today", method: "GET", responseType: DailyPersonalizedActionPlan.self)
    }

    func fetchWeeklyPlan(userId: String) async throws -> WeeklyPersonalizedActionPlan {
        try await request(path: "/api/plan/\(userId)/week", method: "GET", responseType: WeeklyPersonalizedActionPlan.self)
    }

    func fetchWeeklyInsights(userId: String) async throws -> WeeklyInsightsResponse {
        try await request(path: "/api/insights/\(userId)/week", method: "GET", responseType: WeeklyInsightsResponse.self)
    }

    func logWater(userId: String, litres: Double, date: String? = nil) async throws -> LogWaterResponse {
        struct RequestBody: Codable {
            let userId: String
            let litres: Double
            let date: String?
        }

        return try await send(
            path: "/api/plan/log-water",
            method: "POST",
            body: RequestBody(userId: userId, litres: litres, date: date),
            responseType: LogWaterResponse.self
        )
    }

    func logPlanMeal(_ requestBody: PlanMealLogRequest) async throws -> DailyPlanMealLogResponse {
        try await send(path: "/api/plan/log-meal", method: "POST", body: requestBody, responseType: DailyPlanMealLogResponse.self)
    }

    func fetchSupplements(userId: String) async throws -> [Supplement] {
        struct ResponseBody: Codable {
            let userId: String
            let supplements: [Supplement]
        }
        let response = try await request(path: "/api/supplements/\(userId)", method: "GET", responseType: ResponseBody.self)
        return response.supplements
    }

    func createSupplement(_ supplement: Supplement) async throws -> Supplement {
        try await send(path: "/api/supplements", method: "POST", body: supplement, responseType: Supplement.self)
    }

    func updateSupplement(_ supplement: Supplement) async throws -> Supplement {
        try await send(path: "/api/supplements/\(supplement.id)", method: "PUT", body: supplement, responseType: Supplement.self)
    }

    func deleteSupplement(id: String) async throws {
        let _: EmptyResponse = try await request(path: "/api/supplements/\(id)", method: "DELETE", responseType: EmptyResponse.self, allowEmptyBody: true)
    }

    func fetchHealthConditions(userId: String) async throws -> [HealthCondition] {
        struct ResponseBody: Codable {
            let userId: String
            let conditions: [HealthCondition]
        }
        let response = try await request(path: "/api/health-conditions/\(userId)", method: "GET", responseType: ResponseBody.self)
        return response.conditions
    }

    func createHealthCondition(_ condition: HealthCondition) async throws -> HealthCondition {
        try await send(path: "/api/health-conditions", method: "POST", body: condition, responseType: HealthCondition.self)
    }

    func updateHealthCondition(_ condition: HealthCondition) async throws -> HealthCondition {
        try await send(path: "/api/health-conditions/\(condition.id)", method: "PUT", body: condition, responseType: HealthCondition.self)
    }

    func deleteHealthCondition(id: String) async throws {
        let _: EmptyResponse = try await request(path: "/api/health-conditions/\(id)", method: "DELETE", responseType: EmptyResponse.self, allowEmptyBody: true)
    }

    private func send<Body: Codable, Response: Codable>(
        path: String,
        method: String,
        body: Body,
        responseType: Response.Type
    ) async throws -> Response {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await execute(request, responseType: responseType)
    }

    private func request<Response: Codable>(
        path: String,
        method: String,
        responseType: Response.Type,
        allowEmptyBody: Bool = false
    ) async throws -> Response {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        return try await execute(request, responseType: responseType, allowEmptyBody: allowEmptyBody)
    }

    private func execute<Response: Codable>(_ request: URLRequest, responseType: Response.Type, allowEmptyBody: Bool = false) async throws -> Response {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.server("Could not reach backend at \(baseURL.absoluteString). Check that the deployed backend URL is correct and the service is online.")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if request.url?.path == "/api/food/analyze-text" {
            print("[TextMeal] HTTP status:", httpResponse.statusCode)
            let rawResponse = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            print("[TextMeal] Raw response:", rawResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let message = payload["message"] as? String ?? payload["error"] as? String
                if let details = payload["details"] {
                    let detailsText = String(describing: details)
                    throw APIError.server([message, detailsText].compactMap { $0 }.joined(separator: ": "))
                }
                if let message {
                    throw APIError.server(message)
                }
                throw APIError.server("Backend error (\(httpResponse.statusCode)): \(payload)")
            }
            if let body = String(data: data, encoding: .utf8), !body.isEmpty {
                throw APIError.server("Backend error (\(httpResponse.statusCode)): \(body)")
            }
            throw APIError.invalidResponse
        }

        if allowEmptyBody, data.isEmpty, let empty = EmptyResponse() as? Response {
            return empty
        }

        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            if let body = String(data: data, encoding: .utf8), !body.isEmpty {
                throw APIError.decoding("Backend response could not be decoded for \(request.url?.path ?? "request"): \(body)")
            }
            throw APIError.decoding("Backend response could not be decoded for \(request.url?.path ?? "request").")
        }
    }

    private func makeMultipartBody(
        boundary: String,
        userId: String,
        filename: String,
        mimeType: String,
        fileData: Data
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"userId\"\(lineBreak)\(lineBreak)")
        body.append("\(userId)\(lineBreak)")

        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\(lineBreak)")
        body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
        body.append(fileData)
        body.append(lineBreak)
        body.append("--\(boundary)--\(lineBreak)")
        return body
    }

    private func compressedJPEGPayload(for image: UIImage, maxBytes: Int) throws -> (data: Data, filename: String, mimeType: String) {
        var quality: CGFloat = 0.9
        while quality >= 0.3 {
            if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return (data, "meal.jpg", "image/jpeg")
            }
            quality -= 0.1
        }

        if let data = image.jpegData(compressionQuality: 0.25), data.count <= maxBytes {
            return (data, "meal.jpg", "image/jpeg")
        }

        throw APIError.server("The selected photo is too large to upload. Please choose a smaller image.")
    }
}

struct BackendHealthStatus: Codable {
    let status: String
    let service: String
    let timestamp: String
}

private struct EmptyResponse: Codable {
    init?() {}
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
