import SwiftUI

struct ImageGenerationView: View {
    @StateObject private var viewModel = ImageGenerationViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case prompt
        case negative
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    promptEditor
                    sizePicker
                    actionRow
                    statusPanel
                    resultSection
                }
                .padding(18)
                .padding(.bottom, 110)
            }
            .background(Color.galleryBackground.ignoresSafeArea())
            .navigationTitle("文生图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("通义万相 wanx2.1-t2i-plus", systemImage: "wand.and.stars")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text("用文字生成 AI 图片")
                .font(.system(size: 28, weight: .bold))

            Text("创建任务后自动轮询结果，也可以手动查看结果或用同一提示词重新生成。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var promptEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("提示词")
                .font(.headline)

            TextField("描述你想生成的图片", text: $viewModel.prompt, axis: .vertical)
                .lineLimit(4...7)
                .focused($focusedField, equals: .prompt)
                .padding(13)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.galleryWarmGray, lineWidth: 1)
                }
                .accessibilityIdentifier("image-prompt-field")

            DisclosureGroup {
                TextField("不希望出现的内容", text: $viewModel.negativePrompt, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .negative)
                    .padding(13)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.galleryWarmGray, lineWidth: 1)
                    }
            } label: {
                Text("反向提示词")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(.primary)
        }
    }

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("画幅")
                .font(.headline)

            Picker("画幅", selection: $viewModel.selectedSize) {
                Text("方图").tag("1024*1024")
                Text("竖图").tag("1024*1440")
                Text("横图").tag("1440*1024")
            }
            .pickerStyle(.segmented)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                focusedField = nil
                Task {
                    await viewModel.create()
                }
            } label: {
                Label("生成", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.state.isWorking || !viewModel.isConfigured)
            .accessibilityIdentifier("image-create-button")

            Button {
                Task {
                    await viewModel.refreshResult()
                }
            } label: {
                Label("查看", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.galleryWarmGray, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentTask == nil || viewModel.state.isWorking)
            .accessibilityIdentifier("image-result-button")
        }
    }

    private var statusPanel: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: viewModel.state.isWorking ? "clock.arrow.circlepath" : "checkmark.seal")
                .font(.headline)
                .foregroundStyle(viewModel.state.isWorking ? .secondary : .primary)
                .frame(width: 34, height: 34)
                .background(.white, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.state.statusText)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("image-generation-status")

                if let task = viewModel.currentTask {
                    Text("Task ID \(task.taskID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if viewModel.isConfigured {
                    Text("已配置文生图密钥，输入提示词即可创建阿里云任务。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("未配置文生图密钥（按量计费）。在 Info.plist 添加 DashScopeAPIKey 或设置 DASHSCOPE_API_KEY 后即可生成。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.galleryWarmGray.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("生成结果")
                    .font(.headline)
                Spacer()
                Button {
                    focusedField = nil
                    Task {
                        await viewModel.regenerate()
                    }
                } label: {
                    Label("重新生成", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.state.isWorking || !viewModel.isConfigured || viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("image-regenerate-button")
            }

            if viewModel.images.isEmpty {
                emptyResult
            } else {
                ForEach(viewModel.images) { image in
                    generatedImageCard(image)
                }
            }
        }
    }

    private var emptyResult: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.secondary)
            Text("还没有生成结果")
                .font(.headline)
            Text("创建任务后等待阿里云返回图片，结果 URL 仅临时有效，请及时保存。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 18)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func generatedImageCard(_ image: GeneratedImage) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            AdaptiveGalleryImage(url: image.url, title: image.originalPrompt, fallbackAspectRatio: 1)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if let actualPrompt = image.actualPrompt, !actualPrompt.isEmpty {
                Text(actualPrompt)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("generated-image-card")
    }
}
