import AVFoundation
import Combine
import Photos
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct AvatarView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        if store.hasPremiumAccess || !store.avatars.isEmpty {
            AvatarLibraryView()
        } else {
            AvatarFreeMixMatchView()
        }
    }
}

private struct AvatarLibraryView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation

    var body: some View {
        AppCanvas {
            Text("Avatars")
                .font(.outfitBody(24, weight: .bold))
                .foregroundStyle(Color.black)
                .appFrame(x: 30, y: 66, w: 160, h: 30, alignment: .leading)

            Text(itemCountText)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .appFrame(x: 30, y: smallDeviceAdaptation.underHeaderY(102), w: 120, h: 18, alignment: .leading)

            if store.avatars.isEmpty {
                AvatarEmptyState {
                    openAvatarCameraFlow()
                }
                .offset(y: smallDeviceAdaptation.value(regular: 0, small: -36))
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(116), spacing: 4), count: 3), spacing: 4) {
                        ForEach(store.avatars) { avatar in
                            AvatarImageTile(avatar: avatar) {
                                router.push(.avatarDetail(avatar))
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, smallDeviceAdaptation.scrollBottomPadding())
                }
                .frame(width: 393, height: smallDeviceAdaptation.underHeaderHeight(706), alignment: .top)
                .clipped()
                .appFrame(
                    x: 0,
                    y: smallDeviceAdaptation.underHeaderY(146),
                    w: 393,
                    h: smallDeviceAdaptation.underHeaderHeight(706),
                    alignment: .topLeading
                )
            }

            AvatarCreatePill(width: 148, height: 36, iconName: "app_ic_ai_1", iconContainer: 24, iconSize: 16) {
                openAvatarCameraFlow()
            }
            .appFrame(x: 225, y: 63, w: 148, h: 36)
        }
    }

    private var itemCountText: String {
        store.avatars.count == 1 ? "1 Item" : "\(store.avatars.count) Items"
    }

    private func openAvatarCameraFlow() {
        guard store.canCreateAvatar else {
            router.presentPaywall(source: .inApp)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            router.push(.avatarCapture)
        default:
            router.push(.cameraPermission(.avatar))
        }
    }
}

private struct AvatarEmptyState: View {
    let onCreate: () -> Void

    var body: some View {
        Group {
            AppIcon(name: "app_ic_avatar_empty", size: 136, color: Color(hex: 0x7E7E7E))
                .appFrame(x: 128.5, y: 322, w: 136, h: 136)

            Text("No Avatars Yet")
                .font(.outfitBody(24, weight: .bold))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .appFrame(x: 62, y: 487, w: 268, h: 30)

            Text("Generate a personalized\nAI model for outfit styling.")
                .font(.outfitBody(14, weight: .medium))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .appFrame(x: 82, y: 533, w: 228, h: 40)

            AvatarCreatePill(width: 180, height: 56, iconName: "system.plus", iconContainer: 24, action: onCreate)
                .appFrame(x: 106, y: 600, w: 180, h: 56)
        }
    }
}

private struct AvatarCreatePill: View {
    let width: CGFloat
    let height: CGFloat
    let iconName: String
    let iconContainer: CGFloat
    var iconSize: CGFloat? = nil
    var iconBackground = Color.white.opacity(0.19)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(iconBackground)
                    .frame(width: iconContainer, height: iconContainer)
                    .overlay {
                        icon
                    }

                Text("Create Avatar")
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }
            .frame(width: width, height: height)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var icon: some View {
        if iconName == "system.plus" {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: iconContainer, height: iconContainer)
        } else {
            AppIcon(name: iconName, size: iconSize ?? iconContainer, color: .white)
        }
    }
}

private struct AvatarImageTile: View {
    let avatar: AvatarProfile
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            AvatarProfileImage(avatar: avatar, contentMode: .fit)
                .padding(8)
                .frame(width: 116, height: 136)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: 0xECECEC), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct AvatarProfileImage: View {
    let avatar: AvatarProfile
    var contentMode: ContentMode = .fit

    var body: some View {
        Group {
            if let imageData = avatar.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if !avatar.imageName.isEmpty {
                OutfitImage(name: avatar.imageName, contentMode: contentMode)
            } else {
                Image(systemName: "figure.stand")
                    .font(.system(size: 70, weight: .semibold))
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
            }
        }
    }
}

private struct AvatarFreeMixMatchView: View {
    @Environment(AppRouter.self) private var router
    @Environment(OutfitDataStore.self) private var store
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var selectedStep = 0

    private let steps = AvatarFreeStep.all
    private let autoScrollTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        let layout = AvatarFreeLayout(device: smallDeviceAdaptation)

        AppCanvas {
            Text("Mix & Match")
                .font(.outfitBody(24, weight: .bold))
                .foregroundStyle(Color.black)
                .appFrame(x: 38, y: layout.titleY, w: 260, h: 30, alignment: .leading, adjustsTopInset: false)

            Text("Your virtual runway")
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .appFrame(x: 38, y: layout.subtitleY, w: 260, h: 18, alignment: .leading, adjustsTopInset: false)

            TabView(selection: $selectedStep) {
                ForEach(steps.indices, id: \.self) { index in
                    AvatarFreeStepImage(step: steps[index], height: layout.heroHeight)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .appFrame(x: 0, y: layout.heroY, w: 393, h: layout.heroHeight, adjustsTopInset: false)

            OnboardingDots(count: steps.count, index: selectedStep)
                .appFrame(x: 162, y: layout.dotsY, w: 70, h: 10, adjustsTopInset: false)

            Text("Step \(selectedStep + 1):")
                .font(.outfitBody(20, weight: .regular))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .appFrame(x: 18, y: layout.stepY, w: 356, h: 26, adjustsTopInset: false)

            Text(steps[selectedStep].title)
                .font(.outfitBody(24, weight: .bold))
                .foregroundStyle(OutfitTheme.Color.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .appFrame(x: 42, y: layout.stepTitleY, w: 308, h: 66, adjustsTopInset: false)

            AppPrimaryButton(title: store.canCreateAvatar ? "Create Avatar" : "Upgrade & Unlock") {
                if store.canCreateAvatar {
                    router.push(.avatarOnboarding)
                } else {
                    router.presentPaywall(source: .inApp)
                }
            }
            .appFrame(x: 18, y: layout.buttonY, w: 356, h: 56, adjustsTopInset: false)
        }
        .onReceive(autoScrollTimer) { _ in
            guard steps.count > 1 else { return }
            withAnimation(.smooth(duration: 0.35)) {
                selectedStep = (selectedStep + 1) % steps.count
            }
        }
    }
}

private struct AvatarFreeLayout {
    let device: SmallDeviceAdaptation

    var titleY: CGFloat { device.value(regular: 66, small: 40) }
    var subtitleY: CGFloat { device.value(regular: 98, small: 74) }
    var heroY: CGFloat { device.value(regular: 146, small: 108) }
    var heroHeight: CGFloat { device.value(regular: 340, small: 286) }
    var dotsY: CGFloat { device.value(regular: 530, small: 410) }
    var stepY: CGFloat { device.value(regular: 558, small: 430) }
    var stepTitleY: CGFloat { device.value(regular: 590, small: 462) }
    var buttonY: CGFloat { device.value(regular: 690, small: 552) }
}

private struct AvatarFreeStep: Identifiable {
    let id: Int
    let imageName: String
    let title: String

    static let all = [
        AvatarFreeStep(id: 0, imageName: "app_bg_onbording_6", title: "Upload A Full-Body\nPhoto"),
        AvatarFreeStep(id: 1, imageName: "app_bg_onbording_7", title: "Choose Clothes From Your\nWardrobe"),
        AvatarFreeStep(id: 2, imageName: "app_bg_onbording_8", title: "Try On Any Outfit\nCombination")
    ]
}

private struct AvatarFreeStepImage: View {
    let step: AvatarFreeStep
    let height: CGFloat

    var body: some View {
        OutfitImage(name: step.imageName, contentMode: .fit)
            .frame(width: 393, height: height)
    }
}

private struct OnboardingDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { dotIndex in
                Circle()
                    .fill(dotIndex == index ? Color.black : OutfitTheme.Color.chip)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: 70, height: 10)
    }
}

struct MixMatchOnboardingView: View {
    @Environment(AppRouter.self) private var router
    @Environment(OutfitDataStore.self) private var store
    @State private var step = 0

    private let steps = [
        "Step 1: Upload a full-body photo",
        "Step 2: Choose clothes from your wardrobe",
        "Step 3: Try on any outfit combination"
    ]

    var body: some View {
        AppCanvas {
            AppTopFade()
            DetailTopBar(title: "Mix & Match")
                .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)
            AppText(value: "Your virtual runway", role: .secondary)
                .appFrame(x: 68, y: 105, w: 260, h: 20, alignment: .leading)

            if step == 1 {
                HStack(spacing: 8) {
                    AppChip(title: "Tops", selected: true)
                    AppChip(title: "Bikinis")
                    AppChip(title: "Bags")
                    AppChip(title: "Bottoms")
                    AppChip(title: "Dresses")
                }
                .appFrame(x: 18, y: 136, w: 520, h: 30, alignment: .leading)
                .clipped()
            }

            OutfitImage(name: heroAsset, contentMode: .fit)
                .frame(width: 393, height: 408)
                .appFrame(x: 0, y: 150, w: 393, h: 408)

            AppText(value: steps[step], role: .appTitle, alignment: .center)
                .appFrame(x: 42, y: 536, w: 308, h: 58)

            AppPrimaryButton(title: step == 2 ? "Create Avatar" : "Upgrade & Unlock") {
                if step < 2 {
                    withAnimation(.smooth(duration: 0.2)) {
                        step += 1
                    }
                } else {
                    openAvatarCameraFlow()
                }
            }
            .appFrame(x: 18, y: 703, w: 356, h: 56)
        }
    }

    private func openAvatarCameraFlow() {
        guard store.canCreateAvatar else {
            router.presentPaywall(source: .inApp)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            router.push(.avatarCapture)
        default:
            router.push(.cameraPermission(.avatar))
        }
    }

    private var heroAsset: String {
        switch step {
        case 0: "app_bg_onbording_6"
        case 1: "app_bg_onbording_5"
        default: "app_bg_onbording_7"
        }
    }
}

struct AvatarEditorView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var brushSize: CGFloat = 24
    @State private var strokes: [AvatarBrushStroke] = []
    @State private var currentStroke: AvatarBrushStroke?
    @State private var phase: AvatarEditorPhase = .masking
    @State private var errorMessage: String?
    @State private var processingStartedAt = Date()
    @State private var processingFinishedAt: Date?

    private var hasSelection: Bool {
        !strokes.isEmpty || currentStroke != nil
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / OutfitTheme.Layout.referenceWidth
            let screenReferenceHeight = UIScreen.main.bounds.height / max(UIScreen.main.bounds.width, 1) * OutfitTheme.Layout.referenceWidth
            let referenceHeight = max(proxy.size.height / scale, screenReferenceHeight)
            let bottomSafeArea = UIApplication.shared.outfitBottomSafeAreaInset / max(UIScreen.main.bounds.width, 1) * OutfitTheme.Layout.referenceWidth
            let topY: CGFloat = 70
            let imageY: CGFloat = 136
            let bottomInset = max(22, bottomSafeArea + 14)
            let retakeY = referenceHeight - bottomInset - 56
            let createY = retakeY - 69
            let sliderY = createY - 52
            let brushY = sliderY - 30
            let hintY = brushY - 32
            let imageHeight = max(260, hintY - imageY - 20)

            ZStack(alignment: .topLeading) {
                OutfitTheme.Color.appBackground
                    .ignoresSafeArea()

                ZStack(alignment: .topLeading) {
                    OutfitTheme.Color.appBackground
                        .frame(width: 393, height: referenceHeight)

                    switch phase {
                    case .masking:
                        AvatarMaskTopBar {
                            undoLastStroke()
                        }
                        .appFrame(x: 18, y: topY, w: 356, h: 40, alignment: .topLeading)

                        AvatarMaskImageCanvas(
                            image: pendingImage,
                            height: imageHeight,
                            brushSize: brushSize,
                            strokes: strokes,
                            currentStroke: currentStroke,
                            onStrokeChanged: { points in
                                currentStroke = AvatarBrushStroke(points: points, width: brushSize)
                                errorMessage = nil
                            },
                            onStrokeEnded: { points in
                                guard points.count > 1 else { return }
                                strokes.append(AvatarBrushStroke(points: points, width: brushSize))
                                currentStroke = nil
                            }
                        )
                        .appFrame(x: 18, y: imageY, w: 356, h: imageHeight)

                        Text(errorMessage ?? "Paint over the object you want to select")
                            .font(.outfitBody(12, weight: .regular))
                            .foregroundStyle(errorMessage == nil ? OutfitTheme.Color.secondaryText : Color(hex: 0xFF4B4B))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .appFrame(x: 42, y: hintY - (errorMessage == nil ? 0 : 8), w: 308, h: errorMessage == nil ? 18 : 34)

                        HStack {
                            Text("Brush Size")
                                .font(.outfitBody(12, weight: .bold))
                            Spacer()
                            Text("\(Int(brushSize)) px")
                                .font(.outfitBody(12, weight: .bold))
                        }
                        .foregroundStyle(Color.black)
                        .appFrame(x: 18, y: brushY, w: 356, h: 20)

                        Slider(value: $brushSize, in: 8...48, step: 1)
                            .tint(Color.black)
                            .appFrame(x: 18, y: sliderY, w: 356, h: 32)

                        AvatarCreateNewButton(isEnabled: hasSelection) {
                            startAvatarGeneration(canvasHeight: imageHeight)
                        }
                        .appFrame(x: 18, y: createY, w: 356, h: 56)

                        AvatarRetakeButton {
                            retake()
                        }
                        .appFrame(x: 18, y: retakeY, w: 356, h: 56)
                    case .processing:
                        AvatarProcessingStateView(
                            image: pendingImage,
                            imageHeight: imageHeight,
                            referenceHeight: referenceHeight,
                            startDate: processingStartedAt,
                            finishDate: processingFinishedAt
                        )
                    case .result(let data):
                        let resultDeleteY = referenceHeight - bottomInset - 56
                        let resultSaveY = resultDeleteY - 68
                        let resultImageHeight = max(320, resultSaveY - 146 - 42)
                        AvatarResultStateView(
                            imageData: data,
                            imageHeight: resultImageHeight,
                            saveY: resultSaveY,
                            deleteY: resultDeleteY,
                            save: {
                                if store.canCreateAvatar {
                                    store.saveGeneratedAvatar(data: data)
                                    router.popToRoot()
                                } else {
                                    router.presentPaywall(source: .inApp)
                                }
                            },
                            delete: {
                                store.discardPendingGeneratedAvatar()
                                router.popToRoot()
                            }
                        )
                    }
                }
                .frame(width: 393, height: referenceHeight, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var pendingImage: UIImage? {
        guard let data = store.pendingAvatarPhotoData else { return nil }
        return UIImage(data: data)
    }

    private func undoLastStroke() {
        if currentStroke != nil {
            currentStroke = nil
        } else if !strokes.isEmpty {
            strokes.removeLast()
        }
    }

    private func retake() {
        store.pendingAvatarPhotoData = nil
        phase = .masking
        errorMessage = nil
        if router.path.last == .avatarEditor {
            router.pop()
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            router.push(.avatarCapture)
        default:
            router.push(.cameraPermission(.avatar))
        }
    }

    private func startAvatarGeneration(canvasHeight: CGFloat) {
        guard hasSelection else { return }
        guard store.canCreateAvatar else {
            router.presentPaywall(source: .inApp)
            return
        }
        guard let prepared = renderedAvatarRequest(canvasHeight: canvasHeight) else {
            errorMessage = "Please choose a clear full-body photo and paint over the person."
            return
        }

        phase = .processing
        processingStartedAt = Date()
        processingFinishedAt = nil
        errorMessage = nil
        Task {
            do {
                let avatarData = try await OpenAIAvatarService().createAvatar(
                    imageData: prepared.imageData,
                    maskData: prepared.maskData
                )
                await MainActor.run {
                    let finishDate = Date()
                    processingFinishedAt = finishDate
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        await MainActor.run {
                            guard case .processing = phase else { return }
                            guard processingFinishedAt == finishDate else { return }
                            phase = .result(avatarData)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    phase = .masking
                    processingFinishedAt = nil
                    errorMessage = "We couldn't create an avatar. Please choose another clear full-body photo."
                }
            }
        }
    }

    private func renderedAvatarRequest(canvasHeight: CGFloat) -> (imageData: Data, maskData: Data)? {
        guard let image = pendingImage else { return nil }
        let outputSize = CGSize(width: 1024, height: 1536)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let sourceRenderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        let sourceImage = sourceRenderer.image { _ in
            image.draw(in: image.aspectFitRect(in: CGRect(origin: .zero, size: outputSize)))
        }

        let maskRenderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        let maskImage = maskRenderer.image { context in
            context.cgContext.setFillColor(UIColor.clear.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: outputSize))
            context.cgContext.setStrokeColor(UIColor.white.cgColor)
            context.cgContext.setLineCap(.round)
            context.cgContext.setLineJoin(.round)

            let scaleX = outputSize.width / 356
            let scaleY = outputSize.height / max(canvasHeight, 1)
            for stroke in strokes {
                drawMaskStroke(stroke, context: context.cgContext, scaleX: scaleX, scaleY: scaleY)
            }
        }

        guard let imageData = sourceImage.pngData(), let maskData = maskImage.pngData() else {
            return nil
        }
        return (imageData, maskData)
    }

    private func drawMaskStroke(_ stroke: AvatarBrushStroke, context: CGContext, scaleX: CGFloat, scaleY: CGFloat) {
        guard let first = stroke.points.first else { return }
        context.beginPath()
        context.move(to: CGPoint(x: first.x * scaleX, y: first.y * scaleY))
        for point in stroke.points.dropFirst() {
            context.addLine(to: CGPoint(x: point.x * scaleX, y: point.y * scaleY))
        }
        context.setLineWidth(stroke.width * max(scaleX, scaleY))
        context.strokePath()
    }
}

private enum AvatarEditorPhase: Equatable {
    case masking
    case processing
    case result(Data)
}

private struct AvatarBrushStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var width: CGFloat
}

private struct AvatarMaskTopBar: View {
    @Environment(AppRouter.self) private var router
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppIconButton(name: "app_btn_back") {
                if router.path.isEmpty {
                    router.popToRoot()
                } else {
                    _ = router.path.popLast()
                }
            }

            Text("Create Your AI Avatar")
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)

            Spacer()

            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.black)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 356, height: 40)
    }
}

private struct AvatarMaskImageCanvas: View {
    let image: UIImage?
    let height: CGFloat
    let brushSize: CGFloat
    let strokes: [AvatarBrushStroke]
    let currentStroke: AvatarBrushStroke?
    let onStrokeChanged: ([CGPoint]) -> Void
    let onStrokeEnded: ([CGPoint]) -> Void

    @State private var activePoints: [CGPoint] = []

    var body: some View {
        ZStack {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    OutfitImage(name: "app_bg_onbording_6", contentMode: .fit)
                }
            }
            .frame(width: 356, height: height)
            .clipped()

            Canvas { context, _ in
                for stroke in strokes {
                    draw(stroke, in: &context)
                }
                if let currentStroke {
                    draw(currentStroke, in: &context)
                }
            }
            .frame(width: 356, height: height)
        }
        .frame(width: 356, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let point = clamped(value.location)
                    if activePoints.isEmpty {
                        activePoints = [point]
                    } else {
                        activePoints.append(point)
                    }
                    onStrokeChanged(activePoints)
                }
                .onEnded { _ in
                    onStrokeEnded(activePoints)
                    activePoints = []
                }
        )
    }

    private func draw(_ stroke: AvatarBrushStroke, in context: inout GraphicsContext) {
        guard let first = stroke.points.first else { return }
        var path = Path()
        path.move(to: first)
        for point in stroke.points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(
            path,
            with: .color(Color(hex: 0x1495FF).opacity(0.42)),
            style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
        )
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), 356),
            y: min(max(point.y, 0), height)
        )
    }
}

private struct AvatarProcessingStateView: View {
    let image: UIImage?
    let imageHeight: CGFloat
    let referenceHeight: CGFloat
    let startDate: Date
    let finishDate: Date?

    private var imageBottom: CGFloat { 136 + imageHeight }
    private var titleY: CGFloat { min(imageBottom + 34, referenceHeight - 204) }
    private var subtitleY: CGFloat { titleY + 52 }
    private var progressY: CGFloat { max(subtitleY + 68, referenceHeight - 106) }
    private var statusY: CGFloat { progressY + 30 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AvatarStaticTopBar()
                .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)

            ZStack {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        OutfitImage(name: "app_bg_onbording_6", contentMode: .fit)
                    }
                }
                .frame(width: 356, height: imageHeight)
                .opacity(0.38)
                .clipped()

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.black)
                    .scaleEffect(2.1)
            }
            .frame(width: 356, height: imageHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .appFrame(x: 18, y: 136, w: 356, h: imageHeight)

            Text("Create Your AI Avatar")
                .font(.outfitBody(24, weight: .bold))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .appFrame(x: 42, y: titleY, w: 308, h: 34)

            Text("Upload your photos to generate a\npersonalized fashion avatar.")
                .font(.outfitBody(14, weight: .medium))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .appFrame(x: 42, y: subtitleY, w: 308, h: 40)

            TimelineView(.animation) { timeline in
                let progress = progressValue(at: timeline.date)
                let dotText = processingDots(at: timeline.date)

                ZStack(alignment: .topLeading) {
                    Text("\(Int(progress * 100))%")
                        .font(.outfitBody(20, weight: .medium))
                        .foregroundStyle(Color.black)
                        .contentTransition(.numericText())
                        .multilineTextAlignment(.center)
                        .appFrame(x: 144, y: progressY, w: 104, h: 26)

                    Text("Processing")
                        .font(.outfitBody(12, weight: .regular))
                        .foregroundStyle(OutfitTheme.Color.secondaryText)
                        .multilineTextAlignment(.center)
                        .appFrame(x: 148, y: statusY, w: 96, h: 16)

                    Text(dotText)
                        .font(.outfitBody(12, weight: .regular))
                        .foregroundStyle(OutfitTheme.Color.secondaryText)
                        .multilineTextAlignment(.leading)
                        .appFrame(x: 226, y: statusY, w: 24, h: 16, alignment: .leading)
                }
                .frame(width: 393, height: referenceHeight, alignment: .topLeading)
            }
            .frame(width: 393, height: referenceHeight, alignment: .topLeading)
        }
        .frame(width: 393, height: referenceHeight, alignment: .topLeading)
    }

    private func progressValue(at date: Date) -> Double {
        if let finishDate {
            let baseProgress = baseProgressValue(at: finishDate)
            let finishElapsed = max(0, date.timeIntervalSince(finishDate))
            return min(1, baseProgress + (1 - baseProgress) * min(finishElapsed / 1.0, 1))
        }
        return baseProgressValue(at: date)
    }

    private func baseProgressValue(at date: Date) -> Double {
        let elapsed = max(0, date.timeIntervalSince(startDate))
        return min(0.92, 0.02 + (elapsed / 60.0) * 0.90)
    }

    private func processingDots(at date: Date) -> String {
        let elapsed = max(0, date.timeIntervalSince(startDate))
        let dotCount = Int(elapsed / 0.35) % 3 + 1
        return String(repeating: ".", count: dotCount)
    }
}

private struct AvatarResultStateView: View {
    let imageData: Data
    let imageHeight: CGFloat
    let saveY: CGFloat
    let deleteY: CGFloat
    let save: () -> Void
    let delete: () -> Void

    var body: some View {
        Group {
            AvatarStaticTopBar()
                .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)

            if let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 356, height: imageHeight)
                    .appFrame(x: 18, y: 146, w: 356, h: imageHeight)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 96, weight: .semibold))
                            .foregroundStyle(OutfitTheme.Color.secondaryText)
                    }
                    .appFrame(x: 18, y: 146, w: 356, h: imageHeight)
            }

            AvatarSaveButton(action: save)
            .appFrame(x: 18, y: saveY, w: 356, h: 56)

            AvatarDeleteButton(action: delete)
            .appFrame(x: 18, y: deleteY, w: 356, h: 56)
        }
    }
}

private struct AvatarStaticTopBar: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: 12) {
            AppIconButton(name: "app_btn_back") {
                if router.path.isEmpty {
                    router.popToRoot()
                } else {
                    _ = router.path.popLast()
                }
            }

            Text("Create Your AI Avatar")
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)

            Spacer()
        }
        .frame(width: 356, height: 40)
    }
}

private struct AvatarCreateNewButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.19))
                    .frame(width: 24, height: 24)
                    .overlay {
                        AppIcon(name: "app_ic_ai_1", size: 16, color: .white)
                    }
                Text("Create new Avatar")
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 356, height: 56)
            .background(isEnabled ? Color.black : Color.black.opacity(0.24), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct AvatarRetakeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Retake")
                .font(.outfitBody(16, weight: .medium))
                .foregroundStyle(Color.black)
                .frame(width: 356, height: 56)
                .overlay {
                    Capsule()
                        .stroke(Color.black, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct AvatarSaveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                Text("Save")
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 356, height: 56, alignment: .center)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct AvatarDeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AppIcon(name: "app_ic_delete", size: 24, color: .black)
                Text("Delete")
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.black)
            }
            .frame(width: 356, height: 56)
            .overlay {
                Capsule()
                    .stroke(Color.black, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private extension UIImage {
    func aspectFitRect(in bounds: CGRect) -> CGRect {
        let imageSize = size
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )
    }
}

private extension UIApplication {
    var outfitBottomSafeAreaInset: CGFloat {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets
            .bottom ?? 34
    }
}

struct AvatarDetailView: View {
    @Environment(AppRouter.self) private var router
    @Environment(OutfitDataStore.self) private var store
    @State private var isDeleteAlertPresented = false
    @State private var selectedAvatarID: UUID
    let avatar: AvatarProfile

    init(avatar: AvatarProfile) {
        self.avatar = avatar
        _selectedAvatarID = State(initialValue: avatar.id)
    }

    private var selectedAvatar: AvatarProfile {
        store.avatars.first { $0.id == selectedAvatarID } ?? avatar
    }

    private var hasMultipleAvatars: Bool {
        store.avatars.count > 1
    }

    private var detailReferenceHeight: CGFloat {
        max(
            OutfitTheme.Layout.referenceHeight,
            UIScreen.main.bounds.height / max(UIScreen.main.bounds.width, 1) * OutfitTheme.Layout.referenceWidth
        )
    }

    private var detailUsableReferenceHeight: CGFloat {
        let bottomSafeArea = UIApplication.shared.outfitBottomSafeAreaInset / max(UIScreen.main.bounds.width, 1) * OutfitTheme.Layout.referenceWidth
        return detailReferenceHeight - bottomSafeArea
    }

    private var detailImageHeight: CGFloat {
        guard hasMultipleAvatars else { return 590 }
        return min(456, max(380, detailUsableReferenceHeight - 368))
    }

    private var createLookY: CGFloat {
        hasMultipleAvatars ? 126 + detailImageHeight + 20 : 736
    }

    private var thumbnailsY: CGFloat {
        createLookY + 62
    }

    var body: some View {
        AppCanvas {
            AvatarDetailTopBar {
                isDeleteAlertPresented = true
            }
                .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)

            AvatarProfileImage(avatar: selectedAvatar, contentMode: .fit)
                .padding(12)
                .frame(width: 356, height: detailImageHeight)
                .appFrame(x: 18, y: 126, w: 356, h: detailImageHeight)

            AppPrimaryButton(title: "Create Look", iconName: "app_ic_ai") {
                store.selectedAvatarForLook = selectedAvatar
                router.push(.mixAndMatch)
            }
            .appFrame(x: 18, y: createLookY, w: 356, h: 56)

            if hasMultipleAvatars {
                AvatarThumbnailScroller(
                    avatars: store.avatars,
                    selectedID: selectedAvatarID
                ) { avatar in
                    selectedAvatarID = avatar.id
                }
                .appFrame(x: 0, y: thumbnailsY, w: 393, h: 150, alignment: .leading)
            }
        }
        .alert("Delete Avatar?", isPresented: $isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteGeneratedAvatar(id: selectedAvatar.id)
                router.popToRoot()
            }
        } message: {
            Text("Are you sure you want to delete this avatar?")
        }
    }
}

private struct AvatarDetailTopBar: View {
    @Environment(AppRouter.self) private var router
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppIconButton(name: "app_btn_back") {
                if router.path.isEmpty {
                    router.popToRoot()
                } else {
                    _ = router.path.popLast()
                }
            }

            Text("AI Avatar")
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)

            Spacer()

            Button(action: delete) {
                AppIcon(name: "app_ic_delete", size: 28, color: .black)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.001), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 356, height: 40)
    }
}

private struct AvatarThumbnailScroller: View {
    let avatars: [AvatarProfile]
    let selectedID: UUID
    let select: (AvatarProfile) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(avatars) { avatar in
                    Button {
                        select(avatar)
                    } label: {
                        AvatarProfileImage(avatar: avatar, contentMode: .fit)
                            .padding(6)
                            .frame(width: 104, height: 136)
                            .overlay {
                                if avatar.id == selectedID {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.black, lineWidth: 1.2)
                                }
                            }
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
        }
        .frame(width: 393, height: 150)
    }
}

struct MixAndMatchView: View {
    @Environment(AppRouter.self) private var router
    @Environment(OutfitDataStore.self) private var store
    @State private var selectedCategory = ClothingCategory.tops
    @State private var selectedItems: [WardrobeItem] = []
    @State private var generatedLookData = UserDefaults.standard.data(forKey: AppConstants.Storage.lastGeneratedLookData)
    @State private var isGeneratingLook = false
    @State private var isAvatarDropTargeted = false
    @State private var alertMessage: MixAndMatchAlert?

    private var mixMatchCategories: [ClothingCategory] {
        store.wardrobeCategories.filter { $0 != .all }
    }

    private var activeCategory: ClothingCategory {
        if mixMatchCategories.contains(selectedCategory) {
            return selectedCategory
        }
        return mixMatchCategories.first ?? .tops
    }

    private var filteredWardrobeItems: [WardrobeItem] {
        store.wardrobeItems.filter { $0.category == activeCategory }
    }

    private var selectedAvatar: AvatarProfile? {
        store.selectedAvatarForLook ?? store.avatars.first
    }

    var body: some View {
        AppCanvas {
            MixAndMatchTopBar(
                canGenerate: !selectedItems.isEmpty,
                isGenerating: isGeneratingLook,
                reset: resetLook,
                generate: generateLook
            )
            .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)

            ZStack(alignment: .top) {
                avatarCanvas
                    .frame(width: 276, height: 447)
                    .dropDestination(for: String.self) { itemIDs, _ in
                        handleDrop(itemIDs)
                    } isTargeted: { isTargeted in
                        isAvatarDropTargeted = isTargeted
                    }

                SelectedLookItemsOverlay(items: selectedItems) { item in
                    removeSelectedItem(item)
                }
                .padding(.top, 14)
                .padding(.horizontal, 2)
                .frame(width: 356, height: 447, alignment: .top)

                if let generatedLookData, UIImage(data: generatedLookData) != nil {
                    MixAndMatchSaveButton {
                        saveGeneratedLook()
                    }
                    .padding(.top, 390)
                    .padding(.trailing, 0)
                    .frame(width: 356, height: 447, alignment: .topTrailing)
                }
            }
            .appFrame(x: 18, y: 126, w: 356, h: 447, alignment: .topLeading)

            AppText(
                value: "Swipe to mix and match items\nDrag items onto your character to equip them",
                role: .small,
                alignment: .center
            )
            .appFrame(x: 42, y: 590, w: 308, h: 38)

            CategoryScroller(
                categories: mixMatchCategories,
                selected: activeCategory
            ) { category in
                selectedCategory = category
            }
            .appFrame(x: 18, y: 650, w: 356, h: 30, alignment: .leading)

            if filteredWardrobeItems.isEmpty {
                Text("No items in this category")
                    .font(.outfitBody(14, weight: .medium))
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .appFrame(x: 42, y: 736, w: 308, h: 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(filteredWardrobeItems) { item in
                            let isSelectable = canSelect(item)
                            Button {
                                addSelectedItem(item)
                            } label: {
                                MixAndMatchWardrobeItemTile(item: item, isDimmed: !isSelectable)
                            }
                            .buttonStyle(.plain)
                            .draggable(item.id.uuidString)
                            .allowsHitTesting(isSelectable)
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .appFrame(x: 0, y: 696, w: 393, h: 140, alignment: .leading)
            }

            if isGeneratingLook {
                MixAndMatchGeneratingOverlay()
                    .appFrame(x: 0, y: 0, w: 393, h: 852, alignment: .topLeading)
            }
        }
        .alert(item: $alertMessage) { message in
            Alert(title: Text(message.title), message: Text(message.body), dismissButton: .default(Text("OK")))
        }
    }

    @ViewBuilder
    private var avatarCanvas: some View {
        ZStack {
            if let generatedLookData, let image = UIImage(data: generatedLookData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
            } else if let avatar = selectedAvatar {
                AvatarProfileImage(avatar: avatar, contentMode: .fit)
                    .padding(10)
            } else {
                Image(systemName: "figure.stand")
                    .font(.system(size: 96, weight: .semibold))
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
            }
        }
        .frame(width: 276, height: 447)
        .overlay {
            if isAvatarDropTargeted {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.black.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
            }
        }
    }

    private func handleDrop(_ itemIDs: [String]) -> Bool {
        guard let itemID = itemIDs.first,
              let uuid = UUID(uuidString: itemID),
              let item = store.wardrobeItems.first(where: { $0.id == uuid }) else { return false }
        addSelectedItem(item)
        return true
    }

    private func addSelectedItem(_ item: WardrobeItem) {
        guard !isGeneratingLook else { return }
        guard !selectedItems.contains(where: { $0.id == item.id }) else { return }
        guard canSelectCategory(for: item) else {
            alertMessage = MixAndMatchAlert(
                title: "Already selected",
                body: conflictMessage(for: item)
            )
            return
        }
        guard selectedItems.count < 6 else {
            alertMessage = MixAndMatchAlert(title: "Limit reached", body: "You can add up to 6 items.")
            return
        }
        selectedItems.append(item)
        generatedLookData = nil
        UserDefaults.standard.removeObject(forKey: AppConstants.Storage.lastGeneratedLookData)
    }

    private func canSelect(_ item: WardrobeItem) -> Bool {
        !isGeneratingLook
            && selectedItems.count < 6
            && !selectedItems.contains { $0.id == item.id }
            && canSelectCategory(for: item)
    }

    private func canSelectCategory(for item: WardrobeItem) -> Bool {
        let newSlot = MixAndMatchItemSlot(item)
        return selectedItems.allSatisfy { selectedItem in
            !newSlot.conflicts(with: MixAndMatchItemSlot(selectedItem))
        }
    }

    private func conflictMessage(for item: WardrobeItem) -> String {
        let newSlot = MixAndMatchItemSlot(item)
        if newSlot == .fullBody {
            return "Remove your top or bottoms before adding a dress."
        }
        if selectedItems.contains(where: { MixAndMatchItemSlot($0) == .fullBody && newSlot.conflicts(with: .fullBody) }) {
            return "Remove the dress before adding this item."
        }
        return "Remove the current \(newSlot.displayName) before adding another one."
    }

    private func removeSelectedItem(_ item: WardrobeItem) {
        guard !isGeneratingLook else { return }
        selectedItems.removeAll { $0.id == item.id }
        generatedLookData = nil
        UserDefaults.standard.removeObject(forKey: AppConstants.Storage.lastGeneratedLookData)
    }

    private func resetLook() {
        guard !isGeneratingLook else { return }
        selectedItems = []
        generatedLookData = nil
        UserDefaults.standard.removeObject(forKey: AppConstants.Storage.lastGeneratedLookData)
        alertMessage = nil
    }

    private func generateLook() {
        guard !selectedItems.isEmpty, !isGeneratingLook else { return }
        guard let avatar = selectedAvatar,
              let avatarImageData = imageData(for: avatar) else {
            alertMessage = MixAndMatchAlert(title: "No avatar", body: "Create an avatar before generating a look.")
            return
        }

        let itemPayloads = selectedItems.compactMap { item -> (name: String, category: String, imageData: Data)? in
            guard let data = imageData(for: item) else { return nil }
            return (item.name, item.category.rawValue, data)
        }

        guard itemPayloads.count == selectedItems.count else {
            alertMessage = MixAndMatchAlert(title: "Missing image", body: "One of the selected wardrobe items has no image.")
            return
        }

        isGeneratingLook = true
        Task {
            do {
                let data = try await OpenAIAvatarService().createStyledAvatar(
                    avatarImageData: avatarImageData,
                    wardrobeItems: itemPayloads
                )
                await MainActor.run {
                    generatedLookData = data
                    UserDefaults.standard.set(data, forKey: AppConstants.Storage.lastGeneratedLookData)
                    isGeneratingLook = false
                }
            } catch {
                await MainActor.run {
                    isGeneratingLook = false
                    alertMessage = MixAndMatchAlert(
                        title: "Generation failed",
                        body: error.localizedDescription
                    )
                }
            }
        }
    }

    private func saveGeneratedLook() {
        guard let generatedLookData,
              let image = UIImage(data: generatedLookData) else { return }

        Task {
            do {
                try await saveToPhotoLibrary(image)
                await MainActor.run {
                    alertMessage = MixAndMatchAlert(title: "Saved", body: "Your look was saved to Photos.")
                }
            } catch {
                await MainActor.run {
                    alertMessage = MixAndMatchAlert(title: "Save failed", body: error.localizedDescription)
                }
            }
        }
    }

    private func imageData(for avatar: AvatarProfile) -> Data? {
        if let imageData = avatar.imageData {
            return imageData
        }
        return AssetResolver.image(named: avatar.imageName)?.pngData()
    }

    private func imageData(for item: WardrobeItem) -> Data? {
        if let imageData = item.imageData {
            return imageData
        }
        return AssetResolver.image(named: item.imageName)?.pngData()
    }

    private func saveToPhotoLibrary(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw OpenAIAvatarService.ServiceError.requestFailed("Photo library access was not granted.")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: OpenAIAvatarService.ServiceError.requestFailed("Could not save the image."))
                }
            }
        }
    }
}

private struct MixAndMatchTopBar: View {
    @Environment(AppRouter.self) private var router
    let canGenerate: Bool
    let isGenerating: Bool
    let reset: () -> Void
    let generate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            AppIconButton(name: "app_btn_back") {
                if router.path.isEmpty {
                    router.popToRoot()
                } else {
                    router.pop()
                }
            }
            .disabled(isGenerating)
            .opacity(isGenerating ? 0.35 : 1)

            Text("Mix & Match")
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            Button(action: reset) {
                AppIcon(name: "app_ic_restart", size: 28)
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(isGenerating)
            .opacity(isGenerating ? 0.35 : 1)

            Button(action: generate) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.white.opacity(0.19))
                        .frame(width: 24, height: 24)
                        .overlay {
                            AppIcon(name: "app_ic_ai_1", size: 16, color: .white)
                        }

                    Text(isGenerating ? "Generating" : "Generate")
                        .font(.outfitBody(16, weight: .medium))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(width: 118, height: 36)
                .background(Color.black, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canGenerate || isGenerating)
            .opacity(canGenerate && !isGenerating ? 1 : 0.35)
        }
        .frame(width: 356, height: 40)
    }
}

private struct MixAndMatchWardrobeItemTile: View {
    let item: WardrobeItem
    let isDimmed: Bool

    private var resolvedImage: UIImage? {
        item.imageData.flatMap(UIImage.init(data:))
    }

    var body: some View {
        Group {
            if let image = resolvedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                OutfitImage(name: item.imageName)
            }
        }
        .padding(8)
        .frame(width: 116, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(OutfitTheme.Color.border, lineWidth: 1)
        }
        .opacity(isDimmed ? 0.36 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum MixAndMatchItemSlot: Equatable {
    case upper
    case lower
    case fullBody
    case shoes
    case bag
    case hat
    case socks
    case swimwear
    case outerwear
    case accessory(String)
    case other(String)

    init(_ item: WardrobeItem) {
        if let specificSlot = Self.specificSlot(from: item.name) {
            self = specificSlot
            return
        }

        switch item.category {
        case .tops:
            self = .upper
        case .bottoms:
            self = .lower
        case .dresses:
            self = .fullBody
        case .bikinis:
            self = .swimwear
        case .socks:
            self = .socks
        case .bags:
            self = .bag
        case .all:
            self = .other("clothing")
        case .custom(let title):
            self = Self.slot(from: title)
        }
    }

    var displayName: String {
        switch self {
        case .upper:
            return "top"
        case .lower:
            return "bottom"
        case .fullBody:
            return "dress"
        case .shoes:
            return "shoes"
        case .bag:
            return "bag"
        case .hat:
            return "hat"
        case .socks:
            return "socks"
        case .swimwear:
            return "swimwear"
        case .outerwear:
            return "outerwear"
        case .accessory(let title), .other(let title):
            return title
        }
    }

    func conflicts(with other: MixAndMatchItemSlot) -> Bool {
        if self == other {
            return true
        }

        switch (self, other) {
        case (.fullBody, .upper), (.fullBody, .lower), (.fullBody, .swimwear),
             (.upper, .fullBody), (.lower, .fullBody), (.swimwear, .fullBody),
             (.swimwear, .upper), (.swimwear, .lower),
             (.upper, .swimwear), (.lower, .swimwear):
            return true
        default:
            return false
        }
    }

    private static func specificSlot(from title: String) -> MixAndMatchItemSlot? {
        let normalized = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if containsAny(normalized, ["shoe", "shoes", "sneaker", "sneakers", "boot", "boots", "loafer", "loafers", "heel", "heels", "sandal", "sandals"]) {
            return .shoes
        }
        if containsAny(normalized, ["hat", "hats", "cap", "caps", "beanie", "beanies"]) {
            return .hat
        }
        if containsAny(normalized, ["bag", "bags", "handbag", "handbags", "purse", "purses", "tote", "totes"]) {
            return .bag
        }
        if containsAny(normalized, ["outerwear", "jacket", "jackets", "coat", "coats", "blazer", "blazers", "vest", "vests", "cardigan", "cardigans"]) {
            return .outerwear
        }
        if containsAny(normalized, ["dress", "dresses", "gown", "gowns", "jumpsuit", "jumpsuits"]) {
            return .fullBody
        }
        if containsAny(normalized, ["skirt", "skirts", "jeans", "pants", "trousers", "shorts", "leggings"]) {
            return .lower
        }
        if containsAny(normalized, ["shirt", "shirts", "t-shirt", "tee", "top", "tops", "sweater", "sweaters", "hoodie", "hoodies", "blouse", "blouses"]) {
            return .upper
        }
        if containsAny(normalized, ["sock", "socks"]) {
            return .socks
        }
        if containsAny(normalized, ["bikini", "bikinis", "swimsuit", "swimsuits", "swimwear"]) {
            return .swimwear
        }
        if containsAny(normalized, ["accessory", "accessories", "jewelry", "jewellery", "scarf", "scarves", "belt", "belts", "glasses", "sunglasses"]) {
            return .accessory(normalized)
        }
        return nil
    }

    private static func slot(from title: String) -> MixAndMatchItemSlot {
        if let specificSlot = specificSlot(from: title) {
            return specificSlot
        }

        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return .other(normalized.isEmpty ? "item" : normalized)
    }

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.localizedStandardContains($0) }
    }
}

private struct SelectedLookItemsOverlay: View {
    let items: [WardrobeItem]
    let remove: (WardrobeItem) -> Void

    private var rightItems: ArraySlice<WardrobeItem> {
        items.prefix(3)
    }

    private var leftItems: ArraySlice<WardrobeItem> {
        items.dropFirst(3).prefix(3)
    }

    var body: some View {
        HStack(alignment: .top) {
            SelectedLookItemsColumn(items: Array(leftItems), remove: remove)
            Spacer(minLength: 0)
            SelectedLookItemsColumn(items: Array(rightItems), remove: remove)
        }
        .frame(width: 352, height: 433, alignment: .top)
    }
}

private struct SelectedLookItemsColumn: View {
    let items: [WardrobeItem]
    let remove: (WardrobeItem) -> Void

    var body: some View {
        VStack(spacing: 9) {
            ForEach(items) { item in
                Button {
                    remove(item)
                } label: {
                    SelectedLookItemTile(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 84, height: 252, alignment: .top)
    }
}

private struct MixAndMatchGeneratingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.black)
                    .scaleEffect(1.18)

                Text("Generating look...")
                    .font(.outfitBody(16, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)

                Text("This can take a moment")
                    .font(.outfitBody(14, weight: .medium))
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
                    .lineLimit(1)
            }
            .frame(width: 232, height: 128)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(width: 393, height: 852)
        .contentShape(Rectangle())
    }
}

private struct SelectedLookItemTile: View {
    let item: WardrobeItem

    private var resolvedImage: UIImage? {
        item.imageData.flatMap(UIImage.init(data:))
    }

    var body: some View {
        Group {
            if let image = resolvedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                OutfitImage(name: item.imageName, contentMode: .fit)
            }
        }
        .padding(5)
        .frame(width: 78, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: 0xECECEC), lineWidth: 1)
        }
    }
}

private struct MixAndMatchSaveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.19))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                Text("Save")
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 90, height: 36)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct MixAndMatchAlert: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

#Preview {
    AvatarView()
        .environment(OutfitDataStore())
        .environment(AppRouter())
}
