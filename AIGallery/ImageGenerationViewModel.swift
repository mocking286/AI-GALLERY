import Combine
import Foundation

@MainActor
final class ImageGenerationViewModel: ObservableObject {
    @Published var prompt = "未来城市中的玻璃花园，晨光穿过透明穹顶，细腻建筑空间，电影感构图"
    @Published var negativePrompt = "低质量、低分辨率、畸形、文字、水印、血腥、暴力、色情、未成年人、名人肖像"
    @Published var selectedSize = "1024*1024"
    @Published private(set) var state: ImageGenerationState = .idle
    @Published private(set) var currentTask: ImageGenerationTask?
    @Published private(set) var images: [GeneratedImage] = []
    @Published private(set) var lastSeed: Int?

    private let service: DashScopeImageGenerationService
    private var pollingTask: Task<Void, Never>?

    init(service: DashScopeImageGenerationService = DashScopeImageGenerationService()) {
        self.service = service
    }

    var isConfigured: Bool {
        AppConfig.hasDashScopeKey
    }

    deinit {
        pollingTask?.cancel()
    }

    func create() async {
        let seed = Int.random(in: 1...2_147_000_000)
        await submit(seed: seed)
    }

    func regenerate() async {
        let seed = ((lastSeed ?? Int.random(in: 1...2_147_000_000)) + 9_973) % 2_147_483_647
        await submit(seed: seed)
    }

    func refreshResult() async {
        guard let currentTask else { return }
        await query(taskID: currentTask.taskID)
    }

    private func submit(seed: Int) async {
        pollingTask?.cancel()
        let review = ContentSafety.reviewPrompt(prompt)
        guard !review.isBlocked, !review.sanitizedQuery.isEmpty else {
            state = .failed(ImageGenerationServiceError.contentBlocked.localizedDescription)
            return
        }

        state = .creating
        images = []
        lastSeed = seed

        let request = ImageGenerationRequest(
            prompt: review.sanitizedQuery,
            negativePrompt: negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            size: selectedSize,
            count: 1,
            seed: seed,
            promptExtend: true,
            watermark: false
        )

        do {
            let task = try await service.createTask(request)
            currentTask = task
            state = .running(task.taskStatus)
            startPolling(taskID: task.taskID)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func startPolling(taskID: String) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            for _ in 0..<24 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                await self?.query(taskID: taskID)
                if await self?.state.isFinished == true {
                    return
                }
            }

            if !Task.isCancelled {
                await MainActor.run {
                    self?.state = .running("任务仍在处理中，请稍后点查看结果")
                }
            }
        }
    }

    private func query(taskID: String) async {
        do {
            let result = try await service.getResult(taskID: taskID)
            if !result.images.isEmpty {
                images = result.images
            }

            switch result.taskStatus {
            case "SUCCEEDED":
                state = .succeeded(result.taskStatus)
            case "FAILED", "UNKNOWN":
                state = .failed(result.message ?? "文生图任务失败：\(result.taskStatus)")
            default:
                state = .running(result.taskStatus)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

enum ImageGenerationState: Equatable {
    case idle
    case creating
    case running(String)
    case succeeded(String)
    case failed(String)

    var isWorking: Bool {
        switch self {
        case .creating, .running:
            true
        case .idle, .succeeded, .failed:
            false
        }
    }

    var isFinished: Bool {
        switch self {
        case .succeeded, .failed:
            true
        case .idle, .creating, .running:
            false
        }
    }

    var statusText: String {
        switch self {
        case .idle:
            "输入提示词后创建任务"
        case .creating:
            "正在创建阿里云文生图任务"
        case let .running(status):
            "任务处理中：\(status)"
        case .succeeded:
            "生成完成"
        case let .failed(message):
            message
        }
    }
}
