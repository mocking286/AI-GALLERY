import Foundation

struct ImageGenerationRequest: Equatable {
    var prompt: String
    var negativePrompt: String
    var size: String
    var count: Int
    var seed: Int?
    var promptExtend: Bool
    var watermark: Bool
}

struct ImageGenerationTask: Equatable {
    let taskID: String
    let taskStatus: String
    let requestID: String?
    let seed: Int?
}

struct ImageGenerationResult: Equatable {
    let taskID: String
    let taskStatus: String
    let images: [GeneratedImage]
    let requestID: String?
    let message: String?

    var isFinished: Bool {
        taskStatus == "SUCCEEDED" || taskStatus == "FAILED" || taskStatus == "UNKNOWN"
    }
}

struct GeneratedImage: Identifiable, Equatable {
    let id: String
    let url: URL
    let originalPrompt: String
    let actualPrompt: String?
}

enum ImageGenerationServiceError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidPrompt
    case invalidResponse
    case requestFailed(String)
    case contentBlocked

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "请先在运行环境中配置 DASHSCOPE_API_KEY"
        case .invalidPrompt:
            "请输入适合公开展示的文生图提示词"
        case .invalidResponse:
            "阿里云文生图返回格式异常"
        case let .requestFailed(message):
            message
        case .contentBlocked:
            "提示词包含不适合公开生成的内容，请调整后再试"
        }
    }
}

struct DashScopeImageGenerationService {
    private let apiKeyProvider: () -> String?
    private let session: URLSession
    private let baseURL: URL

    init(
        apiKeyProvider: @escaping () -> String? = { AppConfig.dashScopeAPIKey },
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://dashscope.aliyuncs.com")!
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.session = session
        self.baseURL = baseURL
    }

    func createTask(_ request: ImageGenerationRequest) async throws -> ImageGenerationTask {
        let apiKey = try requireAPIKey()
        let createURL = baseURL.appending(path: "/api/v1/services/aigc/text2image/image-synthesis")
        var urlRequest = URLRequest(url: createURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 30
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("enable", forHTTPHeaderField: "X-DashScope-Async")
        urlRequest.httpBody = try JSONEncoder().encode(DashScopeCreateBody(request: request))

        let response: DashScopeCreateResponse = try await send(urlRequest)
        guard let taskID = response.output.taskID else {
            throw ImageGenerationServiceError.invalidResponse
        }

        return ImageGenerationTask(
            taskID: taskID,
            taskStatus: response.output.taskStatus ?? "PENDING",
            requestID: response.requestID,
            seed: request.seed
        )
    }

    func getResult(taskID: String) async throws -> ImageGenerationResult {
        let apiKey = try requireAPIKey()
        let resultURL = baseURL.appending(path: "/api/v1/tasks/\(taskID)")
        var urlRequest = URLRequest(url: resultURL)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 20
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let response: DashScopeResultResponse = try await send(urlRequest)
        let output = response.output
        guard let taskID = output.taskID, let status = output.taskStatus else {
            throw ImageGenerationServiceError.invalidResponse
        }

        let images = (output.results ?? []).compactMap { item -> GeneratedImage? in
            guard let url = item.url else { return nil }
            return GeneratedImage(
                id: "\(taskID)-\(url.absoluteString)",
                url: url,
                originalPrompt: item.originalPrompt ?? "",
                actualPrompt: item.actualPrompt
            )
        }

        return ImageGenerationResult(
            taskID: taskID,
            taskStatus: status,
            images: images,
            requestID: response.requestID,
            message: response.message
        )
    }

    private func requireAPIKey() throws -> String {
        guard let apiKey = apiKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            throw ImageGenerationServiceError.missingAPIKey
        }
        return apiKey
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationServiceError.invalidResponse
        }

        if (200..<300).contains(httpResponse.statusCode) {
            let decoded = try JSONDecoder.dashScope.decode(T.self, from: data)
            if let error = decoded as? DashScopeErrorCarrier, let code = error.code {
                throw ImageGenerationServiceError.requestFailed(error.message ?? code)
            }
            return decoded
        }

        if let apiError = try? JSONDecoder.dashScope.decode(DashScopeAPIError.self, from: data) {
            throw ImageGenerationServiceError.requestFailed(apiError.message ?? apiError.code ?? "DashScope 请求失败")
        }
        throw ImageGenerationServiceError.requestFailed("DashScope 请求失败：HTTP \(httpResponse.statusCode)")
    }
}

private struct DashScopeCreateBody: Encodable {
    let model = "wanx2.1-t2i-plus"
    let input: Input
    let parameters: Parameters

    init(request: ImageGenerationRequest) {
        input = Input(prompt: request.prompt, negativePrompt: request.negativePrompt)
        parameters = Parameters(
            size: request.size,
            n: request.count,
            seed: request.seed,
            promptExtend: request.promptExtend,
            watermark: request.watermark
        )
    }

    struct Input: Encodable {
        let prompt: String
        let negativePrompt: String

        enum CodingKeys: String, CodingKey {
            case prompt
            case negativePrompt = "negative_prompt"
        }
    }

    struct Parameters: Encodable {
        let size: String
        let n: Int
        let seed: Int?
        let promptExtend: Bool
        let watermark: Bool

        enum CodingKeys: String, CodingKey {
            case size
            case n
            case seed
            case promptExtend = "prompt_extend"
            case watermark
        }
    }
}

private struct DashScopeCreateResponse: Decodable, DashScopeErrorCarrier {
    let output: TaskOutput
    let requestID: String?
    let code: String?
    let message: String?

    struct TaskOutput: Decodable {
        let taskID: String?
        let taskStatus: String?

        enum CodingKeys: String, CodingKey {
            case taskID = "task_id"
            case taskStatus = "task_status"
        }
    }

    enum CodingKeys: String, CodingKey {
        case output
        case requestID = "request_id"
        case code
        case message
    }
}

private struct DashScopeResultResponse: Decodable, DashScopeErrorCarrier {
    let output: ResultOutput
    let usage: Usage?
    let requestID: String?
    let code: String?
    let message: String?

    struct ResultOutput: Decodable {
        let taskID: String?
        let taskStatus: String?
        let results: [ImageItem]?

        enum CodingKeys: String, CodingKey {
            case taskID = "task_id"
            case taskStatus = "task_status"
            case results
        }
    }

    struct ImageItem: Decodable {
        let originalPrompt: String?
        let actualPrompt: String?
        let url: URL?

        enum CodingKeys: String, CodingKey {
            case originalPrompt = "orig_prompt"
            case actualPrompt = "actual_prompt"
            case url
        }
    }

    struct Usage: Decodable {
        let imageCount: Int?

        enum CodingKeys: String, CodingKey {
            case imageCount = "image_count"
        }
    }

    enum CodingKeys: String, CodingKey {
        case output
        case usage
        case requestID = "request_id"
        case code
        case message
    }
}

private protocol DashScopeErrorCarrier {
    var code: String? { get }
    var message: String? { get }
}

private struct DashScopeAPIError: Decodable {
    let code: String?
    let message: String?
    let requestID: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case requestID = "request_id"
    }
}

private extension JSONDecoder {
    static var dashScope: JSONDecoder {
        JSONDecoder()
    }
}
