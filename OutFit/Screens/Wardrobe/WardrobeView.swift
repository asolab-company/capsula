import AVFoundation
import SafariServices
import SwiftUI
import UIKit

struct WardrobeView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation

    var body: some View {
        @Bindable var store = store

        AppCanvas {
            AppTopFade()
            AppHeader(
                title: "Wardrobe",
                subtitle: "\(store.wardrobeItems.count) Items",
                trailing: AnyView(headerActions)
            )
            .appFrame(x: 18, y: 70, w: 356, h: 52, alignment: .topLeading)

            CategoryScroller(
                categories: store.wardrobeCategories,
                selected: store.selectedCategory
            ) { category in
                store.selectedCategory = category
            }
            .appFrame(x: 18, y: smallDeviceAdaptation.underHeaderY(136), w: 356, h: 30, alignment: .leading)

            if store.wardrobeItems.isEmpty {
                WardrobeEmptyState {
                    openAddItemFlow()
                }
                .appFrame(x: 18, y: smallDeviceAdaptation.underHeaderY(258), w: 356, h: 300)
            } else if store.filteredItems.isEmpty {
                WardrobeEmptyState(
                    title: "No items in this category",
                    subtitle: "Add an item to fill \(store.selectedCategory.rawValue).",
                    buttonTitle: "Add item"
                ) {
                    openAddItemFlow()
                }
                .appFrame(x: 18, y: smallDeviceAdaptation.underHeaderY(258), w: 356, h: 300)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(116), spacing: 4), count: 3), spacing: 4) {
                        ForEach(store.filteredItems) { item in
                            AppImageTile(imageName: item.imageName, imageData: item.imageData, showsBackground: false) {
                                router.push(.itemDetail(item))
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, smallDeviceAdaptation.scrollBottomPadding())
                }
                .frame(width: 393, height: smallDeviceAdaptation.underHeaderHeight(670), alignment: .top)
                .clipped()
                .appFrame(
                    x: 0,
                    y: smallDeviceAdaptation.underHeaderY(182),
                    w: 393,
                    h: smallDeviceAdaptation.underHeaderHeight(670),
                    alignment: .topLeading
                )
            }
        }
    }

    private var headerActions: some View {
        HStack(spacing: 16) {
            WardrobeHeaderAssetButton(name: "app_ic_add_3") { openAddItemFlow() }
            AppIconButton(name: "app_btn_category") { openCollections() }
        }
    }

    private func openAddItemFlow() {
        guard store.canAnalyzeClothingThisWeek else {
            router.presentPaywall(source: .inApp)
            return
        }
        if store.didAcceptWardrobeAnalysis {
            openClothingCameraOrPermission()
        } else {
            router.presentAccess(kind: .clothing)
        }
    }

    private func openCollections() {
        guard store.canCreateCollection else {
            router.presentPaywall(source: .inApp)
            return
        }
        router.push(.wardrobeCollections)
    }

    private func openClothingCameraOrPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            router.push(.cameraCapture(.clothing))
        default:
            router.push(.cameraPermission(.clothing))
        }
    }
}

private struct WardrobeHeaderAssetButton: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            OutfitImage(name: name, contentMode: .fit)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.001), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct WardrobeEmptyState: View {
    var title = "Your wardrobe is empty"
    var subtitle = "Add your first item and let AI create outfits for you."
    var buttonTitle = "Add item"
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            OutfitImage(name: "app_ic_empty", contentMode: .fit)
                .frame(width: 136, height: 136)

            Text(title)
                .font(.outfitBody(24, weight: .bold))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.outfitBody(14, weight: .medium))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .frame(width: 280)

            Button(action: action) {
                HStack(spacing: 8) {
                    AppIcon(name: "app_ic_add", size: 18, color: .white)
                    Text(buttonTitle)
                        .font(.outfitBody(16, weight: .medium))
                        .foregroundStyle(Color.white)
                }
                .frame(width: 180, height: 56)
                .background(Color.black, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(width: 356, height: 300)
    }
}

struct WardrobeItemDetailView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var isDeleteAlertPresented = false
    @State private var isCollectionSheetPresented = false
    let item: WardrobeItem

    private var currentItem: WardrobeItem {
        store.wardrobeItems.first { $0.id == item.id } ?? item
    }

    var body: some View {
        let item = currentItem

        AppCanvas {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    WardrobeDetailImageCard(item: item)

                    WardrobeWoreButton {
                        store.markWardrobeItemWornToday(id: item.id)
                    }
                    .padding(.top, 26)

                    WardrobeDetailStatsBlock(
                        stats: [
                            WardrobeDetailStat(systemImage: "arrow.counterclockwise", value: "\(item.wornCount)x", label: "Worn"),
                            WardrobeDetailStat(systemImage: "calendar", value: item.lastWorn, label: "Last worn"),
                            WardrobeDetailStat(systemImage: "clock.arrow.circlepath", value: item.addedDate.isEmpty ? "—" : item.addedDate, label: "Added")
                        ]
                    )
                    .padding(.top, 18)

                    WardrobeReadOnlyTagSection(title: "Brand", values: item.brand.isEmpty ? [] : [item.brand])
                        .padding(.top, 18)
                    WardrobeReadOnlyTagSection(title: "Colors", values: item.colors, showsColorDot: true)
                        .padding(.top, 18)
                    WardrobeReadOnlyTagSection(title: "Style", values: item.styles)
                        .padding(.top, 18)
                    WardrobeReadOnlyTagSection(title: "Material", values: item.materials)
                        .padding(.top, 18)
                    WardrobeReadOnlyTagSection(title: "Season", values: item.seasons)
                        .padding(.top, 18)
                    WardrobeReadOnlyTagSection(title: "Category", values: [item.category.rawValue])
                        .padding(.top, 18)
                        .padding(.bottom, 50)
                }
                .frame(width: 356, alignment: .topLeading)
                .padding(.horizontal, 18)
            }
            .appFrame(
                x: 0,
                y: smallDeviceAdaptation.underHeaderY(126),
                w: 393,
                h: smallDeviceAdaptation.underHeaderHeight(726),
                alignment: .topLeading
            )

            WardrobeDetailTopBar(
                title: item.name,
                edit: {
                    router.push(.itemEditor(item))
                },
                addToCollection: {
                    if store.canCreateCollection {
                        isCollectionSheetPresented = true
                    } else {
                        router.presentPaywall(source: .inApp)
                    }
                },
                delete: {
                    isDeleteAlertPresented = true
                }
            )
            .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)
        }
        .alert("Delete Item?", isPresented: $isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteWardrobeItem(id: item.id)
                router.pop()
            }
        } message: {
            Text("Are you sure you want to delete this item?")
        }
        .sheet(isPresented: $isCollectionSheetPresented) {
            WardrobeItemCollectionSheetView(item: item)
                .presentationDetents([.height(660)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(hex: 0xF3F3F3))
        }
    }
}

private struct WardrobeDetailTopBar: View {
    @Environment(AppRouter.self) private var router
    let title: String
    let edit: () -> Void
    let addToCollection: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppIconButton(name: "app_btn_back") {
                if router.path.isEmpty {
                    router.popToRoot()
                } else {
                    router.pop()
                }
            }

            Text(title)
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            HStack(spacing: 12) {
                AppIconButton(name: "app_ic_edit", action: edit)
                    .frame(width: 32, height: 32)
                AppIconButton(name: "app_btn_category", action: addToCollection)
                    .frame(width: 32, height: 32)
                AppIconButton(name: "app_ic_delete", action: delete)
                    .frame(width: 32, height: 32)
            }
        }
        .frame(width: 356, height: 40)
    }
}

private struct WardrobeDetailImageCard: View {
    let item: WardrobeItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: 0xECECEC), lineWidth: 1)

            Group {
                if let imageData = item.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    OutfitImage(name: item.imageName, contentMode: .fit)
                }
            }
            .padding(18)
        }
        .frame(width: 356, height: 480)
    }
}

private struct WardrobeWoreButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                Text("I wore this today")
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 356, height: 56)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct WardrobeDetailStat: Identifiable {
    let id = UUID()
    let systemImage: String
    let value: String
    let label: String
}

private struct WardrobeDetailStatsBlock: View {
    let stats: [WardrobeDetailStat]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(stats) { stat in
                WardrobeDetailStatColumn(stat: stat)
            }
        }
        .frame(width: 356, height: 100)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct WardrobeDetailStatColumn: View {
    let stat: WardrobeDetailStat

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: stat.systemImage)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .frame(width: 18, height: 18)
                .padding(.bottom, 8)
            Text(stat.value)
                .font(.outfitBody(14, weight: .semibold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.bottom, 6)
            Text(stat.label)
                .font(.outfitBody(12, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
        }
        .frame(width: 356 / 3, height: 100)
    }
}

private struct WardrobeReadOnlyTagSection: View {
    let title: String
    let values: [String]
    var showsColorDot = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.outfitBody(16, weight: .semibold))
                .foregroundStyle(Color.black)

            if values.isEmpty {
                Text("None")
                    .font(.outfitBody(14, weight: .regular))
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
                    .frame(height: 30)
            } else {
                FlexibleTagRow(spacing: 8, lineSpacing: 8) {
                    ForEach(values, id: \.self) { value in
                        WardrobeDetailTagChip(title: value, showsColorDot: showsColorDot)
                    }
                }
            }
        }
        .frame(width: 356, alignment: .topLeading)
    }
}

private struct WardrobeDetailTagChip: View {
    let title: String
    let showsColorDot: Bool

    var body: some View {
        HStack(spacing: 7) {
            if showsColorDot {
                Circle()
                    .fill(EditableTagChip.chipColor(for: title))
                    .frame(width: 10, height: 10)
            }

            Text(title)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.black)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(Color(hex: 0xE7E7E7), in: Capsule())
    }
}

struct ItemEditorView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    let item: WardrobeItem
    @State private var draft: WardrobeItemDraft
    @State private var isDeleteAlertPresented = false

    init(item: WardrobeItem) {
        self.item = item
        _draft = State(initialValue: WardrobeItemDraft(item: item))
    }

    private var isSaveEnabled: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var topBarTitle: String {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Edit Item" : trimmedName
    }

    var body: some View {
        AppCanvas {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    WardrobeEditImageCard(item: item)

                    EditableNameSection(title: "Name", text: $draft.name)
                        .padding(.top, 18)

                    Text("Double tap to remove tag")
                        .font(.outfitBody(12, weight: .regular))
                        .foregroundStyle(OutfitTheme.Color.secondaryText)
                        .frame(width: 356, height: 18)
                        .padding(.top, 16)

                    EditableTagSection(title: "Brand", values: $draft.brand, allowsColorDot: false)
                        .padding(.top, 14)
                    EditableTagSection(title: "Colors", values: $draft.colors, allowsColorDot: true)
                        .padding(.top, 16)
                    EditableTagSection(title: "Style", values: $draft.styles, allowsColorDot: false)
                        .padding(.top, 16)
                    EditableTagSection(title: "Material", values: $draft.materials, allowsColorDot: false)
                        .padding(.top, 16)
                    EditableTagSection(title: "Season", values: $draft.seasons, allowsColorDot: false)
                        .padding(.top, 16)
                    EditableTagSection(title: "Category", values: $draft.categoryTags, allowsColorDot: false, maximumValues: 1)
                        .padding(.top, 16)

                    ClothingSaveButton(isEnabled: isSaveEnabled) {
                        store.updateWardrobeItem(id: item.id, draft: draft)
                        router.pop()
                    }
                    .padding(.top, 24)

                    ClothingDeleteButton {
                        isDeleteAlertPresented = true
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 48)
                }
                .frame(width: 356, alignment: .topLeading)
                .padding(.horizontal, 18)
            }
            .appFrame(
                x: 0,
                y: smallDeviceAdaptation.underHeaderY(126),
                w: 393,
                h: smallDeviceAdaptation.underHeaderHeight(726),
                alignment: .topLeading
            )

            ClothingStaticTopBar(title: topBarTitle)
                .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)
        }
        .alert("Delete Item?", isPresented: $isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteWardrobeItem(id: item.id)
                router.popToRoot()
            }
        } message: {
            Text("Are you sure you want to delete this item?")
        }
    }
}

private struct WardrobeEditImageCard: View {
    let item: WardrobeItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: 0xECECEC), lineWidth: 1)

            Group {
                if let imageData = item.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    OutfitImage(name: item.imageName, contentMode: .fit)
                }
            }
            .padding(16)
        }
        .frame(width: 356, height: 448)
    }
}

private struct EditableNameSection: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.outfitBody(14, weight: .bold))
                .foregroundStyle(Color.black)

            TextField("Item name", text: $text)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.black)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .padding(.horizontal, 14)
                .frame(width: 356, height: 44)
                .background(Color(hex: 0xE7E7E7), in: Capsule())
        }
        .frame(width: 356, alignment: .topLeading)
    }
}

struct ItemAnalyzeView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var brushSize: CGFloat = 24
    @State private var strokes: [ClothingBrushStroke] = []
    @State private var currentStroke: ClothingBrushStroke?
    @State private var phase: ClothingAnalyzePhase = .masking
    @State private var processingStartedAt = Date()
    @State private var processingFinishedAt: Date?
    @State private var errorMessage: String?

    private var hasSelection: Bool {
        !strokes.isEmpty || currentStroke != nil
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / OutfitTheme.Layout.referenceWidth
            let screenReferenceHeight = UIScreen.main.bounds.height / max(UIScreen.main.bounds.width, 1) * OutfitTheme.Layout.referenceWidth
            let referenceHeight = max(proxy.size.height / scale, screenReferenceHeight)
            let bottomSafeArea = UIApplication.shared.wardrobeBottomSafeAreaInset / max(UIScreen.main.bounds.width, 1) * OutfitTheme.Layout.referenceWidth
            let imageY: CGFloat = 136
            let bottomInset = max(22, bottomSafeArea + 14)
            let retakeY = referenceHeight - bottomInset - 56
            let analyzeY = retakeY - 69
            let sliderY = analyzeY - 52
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
                        ClothingAnalyzeTopBar {
                            undoLastStroke()
                        }
                        .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)

                        ClothingMaskImageCanvas(
                            image: pendingImage,
                            height: imageHeight,
                            brushSize: brushSize,
                            strokes: strokes,
                            currentStroke: currentStroke,
                            onStrokeChanged: { points in
                                currentStroke = ClothingBrushStroke(points: points, width: brushSize)
                                errorMessage = nil
                            },
                            onStrokeEnded: { points in
                                guard points.count > 1 else { return }
                                strokes.append(ClothingBrushStroke(points: points, width: brushSize))
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

                        ClothingAnalyzeButton(isEnabled: hasSelection) {
                            startClothingAnalysis(canvasHeight: imageHeight)
                        }
                        .appFrame(x: 18, y: analyzeY, w: 356, h: 56)

                        ClothingRetakeButton {
                            retake()
                        }
                        .appFrame(x: 18, y: retakeY, w: 356, h: 56)
                    case .processing:
                        ClothingProcessingStateView(
                            image: pendingImage,
                            imageHeight: imageHeight,
                            referenceHeight: referenceHeight,
                            startDate: processingStartedAt,
                            finishDate: processingFinishedAt
                        )
                    case .result(let result):
                        ClothingResultEditorView(
                            result: result,
                            referenceHeight: referenceHeight,
                            bottomInset: bottomInset,
                            save: { draft in
                                store.saveGeneratedWardrobeItem(data: result.imageData, draft: draft)
                                router.popToRoot()
                            },
                            delete: {
                                store.pendingClothingPhotoData = nil
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
        guard let data = store.pendingClothingPhotoData else { return nil }
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
        store.pendingClothingPhotoData = nil
        phase = .masking
        errorMessage = nil
        if router.path.last == .itemAnalyze {
            router.pop()
        }
        router.push(.cameraCapture(.clothing))
    }

    private func startClothingAnalysis(canvasHeight: CGFloat) {
        guard hasSelection else { return }
        guard store.canAnalyzeClothingThisWeek else {
            router.presentPaywall(source: .inApp)
            return
        }
        guard let prepared = renderedClothingRequest(canvasHeight: canvasHeight) else {
            errorMessage = "Please choose a clear clothing photo and paint over the item."
            return
        }

        phase = .processing
        processingStartedAt = Date()
        processingFinishedAt = nil
        errorMessage = nil
        Task {
            do {
                let service = OpenAIAvatarService()
                let itemData = try await service.createWardrobeItem(
                    imageData: prepared.imageData,
                    maskData: prepared.maskData
                )
                let metadata = (try? await service.analyzeWardrobeItemMetadata(imageData: itemData)) ?? .fallback
                await MainActor.run {
                    let finishDate = Date()
                    processingFinishedAt = finishDate
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        await MainActor.run {
                            guard case .processing = phase else { return }
                            guard processingFinishedAt == finishDate else { return }
                            phase = .result(GeneratedWardrobeResult(imageData: itemData, metadata: metadata))
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    phase = .masking
                    processingFinishedAt = nil
                    errorMessage = "We couldn't analyze this item. Please choose another clothing photo."
                }
            }
        }
    }

    private func renderedClothingRequest(canvasHeight: CGFloat) -> (imageData: Data, maskData: Data)? {
        guard let image = pendingImage else { return nil }
        let outputSize = CGSize(width: 1024, height: 1536)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let sourceRenderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        let sourceImage = sourceRenderer.image { _ in
            image.draw(in: image.clothingAspectFitRect(in: CGRect(origin: .zero, size: outputSize)))
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

    private func drawMaskStroke(_ stroke: ClothingBrushStroke, context: CGContext, scaleX: CGFloat, scaleY: CGFloat) {
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

private enum ClothingAnalyzePhase: Equatable {
    case masking
    case processing
    case result(GeneratedWardrobeResult)
}

private struct GeneratedWardrobeResult: Equatable {
    let imageData: Data
    let metadata: WardrobeItemMetadata
}

private struct ClothingBrushStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var width: CGFloat
}

private struct ClothingAnalyzeTopBar: View {
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

            Text("Photo")
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

private struct ClothingMaskImageCanvas: View {
    let image: UIImage?
    let height: CGFloat
    let brushSize: CGFloat
    let strokes: [ClothingBrushStroke]
    let currentStroke: ClothingBrushStroke?
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
                    OutfitImage(name: AssetName.dress, contentMode: .fit)
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

    private func draw(_ stroke: ClothingBrushStroke, in context: inout GraphicsContext) {
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

private struct ClothingProcessingStateView: View {
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
            ClothingStaticTopBar()
                .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)

            ZStack {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        OutfitImage(name: AssetName.dress, contentMode: .fit)
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

            Text("Analyze Clothing Item")
                .font(.outfitBody(24, weight: .bold))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .appFrame(x: 42, y: titleY, w: 308, h: 34)

            Text("Our AI identifies the garment and removes\nthe background for your wardrobe.")
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

private struct ClothingResultEditorView: View {
    let result: GeneratedWardrobeResult
    let referenceHeight: CGFloat
    let bottomInset: CGFloat
    let save: (WardrobeItemDraft) -> Void
    let delete: () -> Void
    @State private var draft: WardrobeItemDraft

    init(
        result: GeneratedWardrobeResult,
        referenceHeight: CGFloat,
        bottomInset: CGFloat,
        save: @escaping (WardrobeItemDraft) -> Void,
        delete: @escaping () -> Void
    ) {
        self.result = result
        self.referenceHeight = referenceHeight
        self.bottomInset = bottomInset
        self.save = save
        self.delete = delete
        _draft = State(initialValue: WardrobeItemDraft(metadata: result.metadata))
    }

    private var imageHeight: CGFloat {
        min(448, max(330, referenceHeight * 0.48))
    }

    private var isSaveEnabled: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var topBarTitle: String {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Photo" : trimmedName
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    resultImage

                    Text("Double tap to remove tag")
                        .font(.outfitBody(12, weight: .regular))
                        .foregroundStyle(OutfitTheme.Color.secondaryText)
                        .frame(width: 356, height: 18)
                        .padding(.top, 18)

                    EditableTagSection(title: "Brand", values: $draft.brand, allowsColorDot: false)
                        .padding(.top, 14)
                    EditableTagSection(title: "Colors", values: $draft.colors, allowsColorDot: true)
                        .padding(.top, 16)
                    EditableTagSection(title: "Style", values: $draft.styles, allowsColorDot: false)
                        .padding(.top, 16)
                    EditableTagSection(title: "Material", values: $draft.materials, allowsColorDot: false)
                        .padding(.top, 16)
                    EditableTagSection(title: "Season", values: $draft.seasons, allowsColorDot: false)
                        .padding(.top, 16)
                    EditableTagSection(title: "Category", values: $draft.categoryTags, allowsColorDot: false, maximumValues: 1)
                        .padding(.top, 16)

                    ClothingSaveButton(isEnabled: isSaveEnabled) {
                        save(draft)
                    }
                    .padding(.top, 24)

                    ClothingDeleteButton(action: delete)
                        .padding(.top, 10)
                        .padding(.bottom, bottomInset + 14)
                }
                .frame(width: 356, alignment: .topLeading)
                .padding(.horizontal, 18)
            }
            .frame(width: 393, height: max(1, referenceHeight - 126), alignment: .topLeading)
            .clipped()
            .appFrame(x: 0, y: 126, w: 393, h: max(1, referenceHeight - 126), alignment: .topLeading)

            ClothingStaticTopBar(title: topBarTitle)
                .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)
        }
        .frame(width: 393, height: referenceHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private var resultImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: 0xECECEC), lineWidth: 1)

            if let image = UIImage(data: result.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
            }
        }
        .frame(width: 356, height: imageHeight)
    }
}

private struct EditableTagSection: View {
    let title: String
    @Binding var values: [String]
    let allowsColorDot: Bool
    var maximumValues: Int? = nil
    @State private var editingIndex: Int?
    @FocusState private var focusedIndex: Int?

    private var canAddMoreValues: Bool {
        guard let maximumValues else { return true }
        return values.count < maximumValues
    }

    private var hasEmptyDraftValue: Bool {
        values.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.outfitBody(14, weight: .bold))
                .foregroundStyle(Color.black)

            FlexibleTagRow(spacing: 8, lineSpacing: 8) {
                ForEach(Array(values.indices), id: \.self) { index in
                    let value = value(at: index)
                    if editingIndex == index || value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        editableInputChip(at: index)
                    } else {
                        EditableTagChip(title: value, showsColorDot: allowsColorDot)
                            .onTapGesture(count: 2) {
                                removeValue(at: index)
                            }
                        }
                }

                if canAddMoreValues && !hasEmptyDraftValue {
                    AddTagChip(action: addValue)
                }
            }
        }
        .frame(width: 356, alignment: .topLeading)
    }

    private func editableInputChip(at index: Int) -> some View {
        HStack(spacing: 7) {
            if allowsColorDot {
                Circle()
                    .fill(chipColor(for: value(at: index)))
                    .frame(width: 10, height: 10)
            }

            TextField("", text: binding(for: index))
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .submitLabel(.done)
                .focused($focusedIndex, equals: index)
                .frame(width: inputWidth(for: value(at: index)), height: 30)
                .onSubmit {
                    finalizeValue(at: index)
                }
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(Color(hex: 0xE7E7E7), in: Capsule())
    }

    private func addValue() {
        if let maximumValues, values.count >= maximumValues {
            values.removeAll()
        }
        values.append("")
        let newIndex = values.count - 1
        editingIndex = newIndex
        DispatchQueue.main.async {
            focusedIndex = newIndex
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: {
                value(at: index)
            },
            set: { newValue in
                guard values.indices.contains(index) else { return }
                values[index] = newValue
            }
        )
    }

    private func value(at index: Int) -> String {
        values.indices.contains(index) ? values[index] : ""
    }

    private func removeValue(at index: Int) {
        guard values.indices.contains(index) else { return }
        values.remove(at: index)
        editingIndex = nil
        focusedIndex = nil
    }

    private func finalizeValue(at index: Int) {
        guard values.indices.contains(index) else { return }
        let trimmedValue = values[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            removeValue(at: index)
            return
        }
        values[index] = trimmedValue
        removeDuplicateValues(keeping: index)
        editingIndex = nil
        focusedIndex = nil
    }

    private func removeDuplicateValues(keeping keptIndex: Int) {
        guard values.indices.contains(keptIndex) else { return }
        var seenValues: Set<String> = []
        var cleanedValues: [String] = []

        for (index, value) in values.enumerated() {
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedValue.isEmpty else { continue }
            let key = trimmedValue.lowercased()
            if index == keptIndex || !seenValues.contains(key) {
                cleanedValues.append(trimmedValue)
                seenValues.insert(key)
            }
        }
        if let maximumValues, cleanedValues.count > maximumValues {
            values = Array(cleanedValues.prefix(maximumValues))
        } else {
            values = cleanedValues
        }
    }

    private func inputWidth(for value: String) -> CGFloat {
        min(220, max(42, CGFloat(max(value.count, 1)) * 8.5 + 8))
    }

    private func chipColor(for value: String) -> Color {
        EditableTagChip.chipColor(for: value)
    }
}

private struct FlexibleTagRow<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        FlowTagLayout(spacing: spacing, lineSpacing: lineSpacing) {
            content()
        }
        .frame(width: 356, alignment: .leading)
    }
}

private struct FlowTagLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 356
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextX = x == 0 ? size.width : x + spacing + size.width
            if nextX > maxWidth, x > 0 {
                y += lineHeight + lineSpacing
                x = size.width
                lineHeight = size.height
            } else {
                x = nextX
                lineHeight = max(lineHeight, size.height)
            }
        }

        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextX = x == 0 ? size.width : x + spacing + size.width
            if nextX > maxWidth, x > 0 {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct EditableTagChip: View {
    let title: String
    let showsColorDot: Bool

    var body: some View {
        HStack(spacing: 7) {
            if showsColorDot {
                Circle()
                    .fill(Self.chipColor(for: title))
                    .frame(width: 10, height: 10)
            }

            Text(title)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.black)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(Color(hex: 0xE7E7E7), in: Capsule())
    }

    static func chipColor(for value: String) -> Color {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")

        if let hexColor = hexChipColor(from: normalized) {
            return hexColor
        }

        switch normalized {
        case "black", "черный", "чёрный":
            return Color(hex: 0x000000)
        case "white", "белый":
            return Color(hex: 0xFFFFFF)
        case "offwhite", "ivory", "cream", "ecru", "молочный", "айвори", "кремовый":
            return Color(hex: 0xF4EBDD)
        case "gray", "grey", "серый":
            return Color(hex: 0xA5A5A5)
        case "charcoal", "darkgray", "darkgrey", "графит":
            return Color(hex: 0x3A3A3A)
        case "silver", "серебро", "серебристый":
            return Color(hex: 0xC0C0C0)
        case "gold", "золото", "золотой":
            return Color(hex: 0xDDBD73)
        case "rose gold", "rosegold":
            return Color(hex: 0xB76E79)
        case "red", "красный":
            return Color(hex: 0xE53935)
        case "burgundy", "wine", "maroon", "бордовый", "винный":
            return Color(hex: 0x7B1E3A)
        case "orange", "оранжевый":
            return Color(hex: 0xF57C00)
        case "coral", "коралловый":
            return Color(hex: 0xFF6F61)
        case "yellow", "желтый", "жёлтый":
            return Color(hex: 0xF9D64A)
        case "mustard", "горчичный":
            return Color(hex: 0xD4A017)
        case "green", "зеленый", "зелёный":
            return Color(hex: 0x2E7D32)
        case "lime", "лайм":
            return Color(hex: 0x9CCC65)
        case "mint", "мятный":
            return Color(hex: 0x98D8C8)
        case "olive", "khaki", "хаки", "оливковый":
            return Color(hex: 0x708238)
        case "teal", "бирюзовый":
            return Color(hex: 0x00897B)
        case "turquoise", "cyan", "циан":
            return Color(hex: 0x26C6DA)
        case "blue", "синий":
            return Color(hex: 0x2F80ED)
        case "navy", "darkblue", "темносиний", "тёмносиний":
            return Color(hex: 0x0B1F4D)
        case "skyblue", "lightblue", "голубой":
            return Color(hex: 0x74B9FF)
        case "purple", "violet", "фиолетовый":
            return Color(hex: 0x7B2CBF)
        case "lavender", "lilac", "сиреневый", "лавандовый":
            return Color(hex: 0xBFA2DB)
        case "pink", "розовый":
            return Color(hex: 0xF48FB1)
        case "hotpink", "fuchsia", "magenta", "фуксия":
            return Color(hex: 0xD81B60)
        case "brown", "коричневый":
            return Color(hex: 0x795548)
        case "tan", "camel", "caramel", "карамельный":
            return Color(hex: 0xC19A6B)
        case "beige", "бежевый":
            return Color(hex: 0xD8C3A5)
        case "nude", "skin", "телесный":
            return Color(hex: 0xE8C1A0)
        default:
            return Color.black.opacity(0.28)
        }
    }

    private static func hexChipColor(from value: String) -> Color? {
        let cleaned = value.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let rawValue = UInt(cleaned, radix: 16) else { return nil }
        return Color(hex: rawValue)
    }
}

private struct AddTagChip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: 0xBEBEBE))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.black)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct ClothingStaticTopBar: View {
    @Environment(AppRouter.self) private var router
    let title: String

    init(title: String = "Photo") {
        self.title = title
    }

    var body: some View {
        HStack(spacing: 12) {
            AppIconButton(name: "app_btn_back") {
                if router.path.isEmpty {
                    router.popToRoot()
                } else {
                    _ = router.path.popLast()
                }
            }

            Text(title)
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()
        }
        .frame(width: 356, height: 40)
    }
}

private struct ClothingAnalyzeButton: View {
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
                Text("Analyze")
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

private struct ClothingRetakeButton: View {
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

private struct ClothingSaveButton: View {
    var isEnabled = true
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
            .frame(width: 356, height: 56)
            .background(isEnabled ? Color.black : Color.black.opacity(0.24), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct ClothingDeleteButton: View {
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
    func clothingAspectFitRect(in bounds: CGRect) -> CGRect {
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
    var wardrobeBottomSafeAreaInset: CGFloat {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets
            .bottom ?? 34
    }
}

struct AccessExplainerView: View {
    @Environment(AppRouter.self) private var router
    @Environment(OutfitDataStore.self) private var store
    @State private var dragOffset: CGFloat = 0
    @State private var legalDocument: AppConstants.Legal.Document?
    let kind: CaptureKind

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / OutfitTheme.Layout.referenceWidth
            let referenceHeight = proxy.size.height / scale
            let deviceAdaptation = SmallDeviceAdaptation(screenSize: proxy.size)
            let layout = AccessExplainerLayout(isSmallDevice: deviceAdaptation.isSmallHeightDevice)
            let sheetHeight = min(referenceHeight - layout.topGap, layout.maxSheetHeight)
            let sheetY = max(0, referenceHeight - sheetHeight)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissSheet()
                    }

                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(OutfitTheme.Color.appBackground)
                        .appFrame(x: 0, y: sheetY, w: 393, h: sheetHeight, adjustsTopInset: false)

                    Capsule()
                        .fill(Color(hex: 0xA5A5A5))
                        .appFrame(x: 178.5, y: sheetY + layout.handleY, w: 36, h: 4, adjustsTopInset: false)

                    OutfitImage(name: "app_ic_ai_4", contentMode: .fit)
                        .appFrame(
                            x: layout.iconX,
                            y: sheetY + layout.iconY,
                            w: layout.iconSize,
                            h: layout.iconSize,
                            adjustsTopInset: false
                        )

                    Text("AI Wardrobe Analysis")
                        .font(.outfitBody(layout.titleSize, weight: .bold))
                        .foregroundStyle(Color.black)
                        .multilineTextAlignment(.center)
                        .appFrame(x: 42, y: sheetY + layout.titleY, w: 308, h: layout.titleHeight, adjustsTopInset: false)

                    Text("To organize your wardrobe automatically, we send your\nphotos to a third-party AI service.")
                        .font(.outfitBody(14, weight: .medium))
                        .foregroundStyle(Color.black)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .appFrame(x: 24, y: sheetY + layout.subtitleY, w: 345, h: layout.subtitleHeight, adjustsTopInset: false)

                    WardrobeAnalysisInfoCard(
                        title: "WHAT WE SEND",
                        value: "Photos of your clothing items",
                        height: layout.cardHeight
                    )
                    .appFrame(x: 24, y: sheetY + layout.firstCardY, w: 345, h: layout.cardHeight, alignment: .topLeading, adjustsTopInset: false)

                    WardrobeAnalysisInfoCard(
                        title: "WHERE IT GOES",
                        value: "OpenAI API",
                        height: layout.cardHeight
                    )
                    .appFrame(x: 24, y: sheetY + layout.secondCardY, w: 345, h: layout.cardHeight, alignment: .topLeading, adjustsTopInset: false)

                    WardrobeAnalysisInfoCard(
                        title: "WHAT IT’S USED FOR",
                        value: "Categorizing items by type and color",
                        height: layout.cardHeight
                    )
                    .appFrame(x: 24, y: sheetY + layout.thirdCardY, w: 345, h: layout.cardHeight, alignment: .topLeading, adjustsTopInset: false)

                    WardrobeAnalysisPrivacyNote {
                        legalDocument = .privacy
                    }
                    .appFrame(x: 24, y: sheetY + layout.privacyY, w: 345, h: 40, adjustsTopInset: false)

                    Button {
                        store.didAcceptWardrobeAnalysis = true
                        openCameraOrPermission()
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white)
                                }
                            Text("I agree, continue")
                                .font(.outfitBody(16, weight: .medium))
                                .foregroundStyle(Color.white)
                        }
                        .frame(width: 345, height: 56)
                        .background(Color.black, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .appFrame(x: 24, y: sheetY + layout.primaryButtonY, w: 345, h: 56, adjustsTopInset: false)

                    Button {
                        dismissSheet()
                    } label: {
                        Text("Not now")
                            .font(.outfitBody(16, weight: .medium))
                            .foregroundStyle(Color.black)
                            .frame(width: 345, height: 56)
                            .overlay {
                                Capsule()
                                    .stroke(Color.black, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .appFrame(x: 24, y: sheetY + layout.secondaryButtonY, w: 345, h: 56, adjustsTopInset: false)
                }
                .frame(width: 393, height: referenceHeight, alignment: .topLeading)
                .offset(y: max(0, dragOffset))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = max(0, value.translation.height)
                        }
                        .onEnded { value in
                            if value.translation.height > 84 || value.predictedEndTranslation.height > 150 {
                                dismissSheet()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
        }
        .ignoresSafeArea()
        .sheet(item: $legalDocument) { document in
            WardrobeAnalysisSafariLegalView(url: document.url)
                .ignoresSafeArea()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func openCameraOrPermission() {
        router.dismissAccess()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            router.push(nextRoute)
        default:
            router.push(.cameraPermission(kind))
        }
    }

    private var nextRoute: AppRoute {
        switch kind {
        case .clothing: .cameraCapture(.clothing)
        case .avatar: .avatarCapture
        case .profile: .cameraCapture(.profile)
        }
    }

    private func dismissSheet() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            dragOffset = 0
            router.dismissAccess()
        }
    }
}

private struct WardrobeAnalysisSafariLegalView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct AccessExplainerLayout {
    let isSmallDevice: Bool

    var topGap: CGFloat {
        isSmallDevice ? 44 : 64
    }

    var maxSheetHeight: CGFloat {
        isSmallDevice ? 744 : 744
    }

    var handleY: CGFloat {
        isSmallDevice ? 18 : 20
    }

    var iconSize: CGFloat {
        isSmallDevice ? 62 : 78
    }

    var iconX: CGFloat {
        (OutfitTheme.Layout.referenceWidth - iconSize) / 2
    }

    var iconY: CGFloat {
        isSmallDevice ? 48 : 58
    }

    var titleY: CGFloat {
        isSmallDevice ? 118 : 150
    }

    var titleSize: CGFloat {
        isSmallDevice ? 22 : 24
    }

    var titleHeight: CGFloat {
        isSmallDevice ? 30 : 32
    }

    var subtitleY: CGFloat {
        isSmallDevice ? 155 : 194
    }

    var subtitleHeight: CGFloat {
        isSmallDevice ? 48 : 44
    }

    var cardHeight: CGFloat {
        isSmallDevice ? 72 : 86
    }

    var firstCardY: CGFloat {
        isSmallDevice ? 218 : 260
    }

    var secondCardY: CGFloat {
        isSmallDevice ? 298 : 354
    }

    var thirdCardY: CGFloat {
        isSmallDevice ? 378 : 448
    }

    var privacyY: CGFloat {
        isSmallDevice ? 462 : 546
    }

    var primaryButtonY: CGFloat {
        isSmallDevice ? 516 : 604
    }

    var secondaryButtonY: CGFloat {
        isSmallDevice ? 584 : 672
    }
}

private struct WardrobeAnalysisInfoCard: View {
    let title: String
    let value: String
    var height: CGFloat = 86

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.outfitBody(14, weight: .bold))
                .foregroundStyle(Color.black)
            Text(value)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.black)
        }
        .padding(.horizontal, 24)
        .frame(width: 345, height: height, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct WardrobeAnalysisPrivacyNote: View {
    let openPrivacy: () -> Void

    var body: some View {
        Button(action: openPrivacy) {
            VStack(spacing: 0) {
                Text("Your photos are not used to train any models and are not retained beyond")
                    .font(.outfitBody(12, weight: .regular))
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
                    .multilineTextAlignment(.center)
                (
                    Text("processing. ")
                        .font(.outfitBody(12, weight: .regular))
                    + Text("Privacy Policy")
                        .font(.outfitBody(12, weight: .regular))
                        .underline()
                )
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .multilineTextAlignment(.center)
            }
            .frame(width: 345, height: 40)
        }
        .buttonStyle(.plain)
    }
}

struct CameraPermissionView: View {
    @Environment(AppRouter.self) private var router
    @State private var isCameraDenied = false
    let kind: CaptureKind

    var body: some View {
        AppCanvas {
            ProvideAccessTopBar()
                .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)

            AppIcon(name: "app_ic_camera", size: 142, color: Color(hex: 0x858585))
                .appFrame(x: 124, y: 300, w: 145, h: 120)

            Text("Camera Access Needed")
                .font(.outfitBody(24, weight: .bold))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .appFrame(x: 18, y: 442, w: 356, h: 32)

            Text(subtitle)
                .font(.outfitBody(14, weight: .medium))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .appFrame(x: 78, y: 493, w: 236, h: 44)

            if isCameraDenied {
                Text("Camera access is disabled in Settings.")
                    .font(.outfitBody(12, weight: .regular))
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .appFrame(x: 58, y: 540, w: 276, h: 18)
            }

            CameraAccessButton(title: "Allow Access") {
                Task {
                    await requestCameraAccess()
                }
            }
            .appFrame(x: 108, y: 565, w: 177, h: 56)
        }
    }

    private func requestCameraAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            router.replaceLast(with: nextRoute)
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                router.replaceLast(with: nextRoute)
            } else {
                isCameraDenied = true
            }
        default:
            isCameraDenied = true
        }
    }

    private var subtitle: String {
        switch kind {
        case .clothing:
            "Take photos of your clothes to build your wardrobe."
        case .avatar:
            "Enable camera access to capture your avatar photo."
        case .profile:
            "Enable camera access to capture your profile picture."
        }
    }

    private var nextRoute: AppRoute {
        switch kind {
        case .clothing: .cameraCapture(.clothing)
        case .avatar: .avatarCapture
        case .profile: .cameraCapture(.profile)
        }
    }
}

private struct ProvideAccessTopBar: View {
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
            Text("Provide Access")
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
            Spacer()
        }
        .frame(width: 356, height: 40)
    }
}

private struct CameraAccessButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.outfitBody(16, weight: .medium))
                .foregroundStyle(Color.white)
                .frame(width: 177, height: 56)
                .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CameraCaptureView: View {
    @Environment(AppRouter.self) private var router
    @Environment(OutfitDataStore.self) private var store
    @State private var isShowingCamera = false
    @State private var isShowingGalleryPicker = false
    @State private var isCameraDenied = false
    let kind: CaptureKind

    var body: some View {
        if usesRealCamera {
            realCameraBody
        } else {
            placeholderCameraBody
        }
    }

    private var usesRealCamera: Bool {
        kind == .profile || kind == .avatar || kind == .clothing
    }

    private var realCameraBody: some View {
        AppCanvas {
            Color.black
                .appFrame(x: 0, y: 0, w: 393, h: 852)

            if isCameraDenied {
                AppText(value: "Camera access is disabled in Settings.", role: .body, alignment: .center, color: .white)
                    .appFrame(x: 42, y: 384, w: 308, h: 44)
            }
        }
        .task {
            await requestCameraAccess()
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            ZStack(alignment: .bottomTrailing) {
                ProfileCameraPicker(source: .camera, onImage: { image in
                    isShowingCamera = false
                    handlePickedImage(image)
                }, onCancel: {
                    isShowingCamera = false
                    router.pop()
                })
                .ignoresSafeArea()

                CameraGalleryOverlayButton {
                    openGalleryPicker()
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isShowingGalleryPicker) {
            ProfileCameraPicker(source: .gallery, onImage: { image in
                isShowingGalleryPicker = false
                handlePickedImage(image)
            }, onCancel: {
                isShowingGalleryPicker = false
                router.pop()
            })
            .ignoresSafeArea()
        }
    }

    private var placeholderCameraBody: some View {
        AppCanvas {
            Color.black
                .appFrame(x: 0, y: 0, w: 393, h: 852)
            AppText(
                value: kind == .avatar ? "Position the model in the frame" : "Position the clothing item in the frame",
                role: .body,
                alignment: .center,
                color: .white
            )
            .appFrame(x: 18, y: 76, w: 356, h: 24)

            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                .appFrame(x: 42, y: 158, w: 308, h: 430)

            Button {
                switch kind {
                case .clothing: router.push(.itemAnalyze)
                case .avatar: router.push(.avatarProcessing)
                case .profile: break
                }
            } label: {
                OutfitImage(name: "app_btn_makephoto", contentMode: .fit)
                    .frame(width: 74, height: 74)
            }
            .appFrame(x: 159, y: 720, w: 74, h: 74)
        }
    }

    private func requestCameraAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isShowingCamera = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            isCameraDenied = !granted
            isShowingCamera = granted
        default:
            isCameraDenied = true
        }
    }

    private func openGalleryPicker() {
        isShowingCamera = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isShowingGalleryPicker = true
        }
    }

    private func handlePickedImage(_ image: UIImage) {
        switch kind {
        case .profile:
            store.pendingProfilePhotoData = image.jpegData(compressionQuality: 0.92)
            closeCaptureRoute()
            router.push(.profileCrop)
        case .avatar:
            store.pendingAvatarPhotoData = image.jpegData(compressionQuality: 0.92)
            closeCaptureRoute()
            router.push(.avatarEditor)
        case .clothing:
            store.pendingClothingPhotoData = image.jpegData(compressionQuality: 0.92)
            closeCaptureRoute()
            router.push(.itemAnalyze)
        }
    }

    private func closeCaptureRoute() {
        switch kind {
        case .profile:
            if router.path.last == .cameraCapture(.profile) {
                router.pop()
            }
        case .avatar:
            if router.path.last == .avatarCapture {
                router.pop()
            }
        case .clothing:
            if router.path.last == .cameraCapture(.clothing) {
                router.pop()
            }
        }
    }
}

private struct CameraGalleryOverlayButton: View {
    let action: () -> Void

    var body: some View {
        GeometryReader { proxy in
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.44))
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                .frame(width: 50, height: 50)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .position(
                x: proxy.size.width / 2 + 124,
                y: proxy.size.height - 136
            )
        }
        .allowsHitTesting(true)
    }
}

struct ProcessingView: View {
    var topBarTitle: String? = nil
    let title: String
    let subtitle: String
    let progress: Double

    var body: some View {
        AppCanvas {
            if let topBarTitle {
                DetailTopBar(title: topBarTitle)
                    .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)
            }

            RoundedRectangle(cornerRadius: 28)
                .fill(OutfitTheme.Color.border)
                .overlay(AppIcon(name: "app_ic_ai", size: 60, color: OutfitTheme.Color.secondaryText))
                .appFrame(x: 96, y: 212, w: 200, h: 200)

            AppText(value: subtitle, role: .secondary, alignment: .center)
                .appFrame(x: 42, y: 450, w: 308, h: 48)
            AppText(value: "\(Int(progress * 100))%", role: .appTitle, alignment: .center)
                .appFrame(x: 18, y: 524, w: 356, h: 32)
            AppText(value: title, role: .section, alignment: .center)
                .appFrame(x: 18, y: 572, w: 356, h: 22)
            AppText(value: "Processing...", role: .secondary, alignment: .center)
                .appFrame(x: 18, y: 604, w: 356, h: 20)
        }
    }
}

struct CollectionPickerView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var isCreateCollectionPresented = false
    @State private var collectionPendingDeletion: CollectionGroup?
    let kind: CollectionKind
    let mode: CollectionMode

    var body: some View {
        AppCanvas {
            let headerHeight = smallDeviceAdaptation.value(regular: CGFloat(40), small: CGFloat(32))
            let contentY = smallDeviceAdaptation.value(regular: CGFloat(136), small: CGFloat(104))
            let browseContentHeight = smallDeviceAdaptation.value(regular: CGFloat(548), small: CGFloat(470))
            let createButtonY = smallDeviceAdaptation.value(regular: CGFloat(746), small: CGFloat(626))
            let selectSubtitleY = smallDeviceAdaptation.value(regular: CGFloat(170), small: CGFloat(136))
            let selectRowsY = smallDeviceAdaptation.value(regular: CGFloat(220), small: CGFloat(178))
            let saveButtonY = smallDeviceAdaptation.value(regular: CGFloat(703), small: CGFloat(626))

            CollectionTopBar(title: mode == .browse ? "Collections" : "Select collections")
                .appFrame(x: 18, y: 70, w: 356, h: headerHeight, alignment: .topLeading)

            if mode == .browse {
                CollectionBrowseContent(
                    collections: store.collections,
                    height: browseContentHeight,
                    onDelete: { collectionPendingDeletion = $0 },
                    onTogglePin: { store.toggleCollectionPinned(id: $0.id) }
                )
                    .appFrame(x: 18, y: contentY, w: 356, h: browseContentHeight, alignment: .topLeading)

                CreateCollectionButton {
                    if store.canCreateCollection {
                        isCreateCollectionPresented = true
                    } else {
                        router.presentPaywall(source: .inApp)
                    }
                }
                .appFrame(x: 18, y: createButtonY, w: 356, h: 56)
            } else {
                AppText(value: kind == .wardrobe ? "Wardrobe" : "All Outfits", role: .appTitle)
                    .appFrame(x: 18, y: contentY, w: 356, h: 32, alignment: .leading)
                AppText(value: kind == .wardrobe ? "Complete overview" : "No collection created yet", role: .secondary)
                    .appFrame(x: 18, y: selectSubtitleY, w: 356, h: 20, alignment: .leading)

                VStack(spacing: 8) {
                    ForEach(store.collections) { collection in
                        CollectionRow(collection: collection)
                    }
                }
                .appFrame(x: 18, y: selectRowsY, w: 356, h: 210, alignment: .topLeading)

                AppPrimaryButton(title: "Save") {
                    router.pop()
                }
                .appFrame(x: 18, y: saveButtonY, w: 356, h: 56)
            }
        }
        .sheet(isPresented: $isCreateCollectionPresented) {
            CollectionEditorSheetView()
                .presentationDetents([.height(406)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(hex: 0xF3F3F3))
        }
        .alert("Вы действительно хотите удалить коллекцию?", isPresented: isCollectionDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {
                collectionPendingDeletion = nil
            }
            Button("Delete", role: .destructive) {
                if let collectionPendingDeletion {
                    store.deleteCollection(id: collectionPendingDeletion.id)
                }
                collectionPendingDeletion = nil
            }
        }
    }

    private var isCollectionDeleteAlertPresented: Binding<Bool> {
        Binding(
            get: { collectionPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    collectionPendingDeletion = nil
                }
            }
        )
    }
}

private struct CollectionTopBar<Trailing: View>: View {
    @Environment(AppRouter.self) private var router
    let title: String
    @ViewBuilder var trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            AppIconButton(name: "app_btn_back") {
                if router.path.isEmpty {
                    router.popToRoot()
                } else {
                    _ = router.path.popLast()
                }
            }

            Text(title)
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)

            Spacer()
            trailing
        }
        .frame(width: 356, height: 40)
    }
}

private struct CollectionBrowseContent: View {
    @Environment(AppRouter.self) private var router
    let collections: [CollectionGroup]
    let height: CGFloat
    let onDelete: (CollectionGroup) -> Void
    let onTogglePin: (CollectionGroup) -> Void

    private var sortedCollections: [CollectionGroup] {
        collections.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    var body: some View {
        if collections.isEmpty {
            CollectionEmptyState(height: height)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(sortedCollections) { collection in
                        CollectionSwipeRow(
                            collection: collection,
                            onOpen: { router.push(.collectionDetail(collection)) },
                            onDelete: { onDelete(collection) },
                            onTogglePin: { onTogglePin(collection) }
                        )
                    }
                }
                .padding(.bottom, 16)
            }
            .frame(width: 356, height: height, alignment: .top)
            .clipped()
        }
    }
}

private struct CollectionSwipeRow: View {
    private let rowWidth: CGFloat = 356
    private let rowHeight: CGFloat = 76
    private let actionWidth: CGFloat = 112
    private let swipeThreshold: CGFloat = 78

    let collection: CollectionGroup
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            swipeActions

            CollectionRow(collection: collection)
                .offset(x: dragOffset)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard abs(dragOffset) < 1 else { return }
                    onOpen()
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            dragOffset = clampedOffset(value.translation.width)
                        }
                        .onEnded { value in
                            finishSwipe(translation: value.translation.width)
                        }
                )
                .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: dragOffset)
        }
        .frame(width: rowWidth, height: rowHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var swipeActions: some View {
        if dragOffset > 0 {
            HStack(spacing: 0) {
                HStack {
                    Image(systemName: collection.isPinned ? "pin.slash.fill" : "pin.fill")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color.white)
                    Spacer()
                }
                .padding(.leading, 28)
                .frame(width: max(actionWidth, dragOffset), height: rowHeight)
                .background(Color.black)

                Spacer(minLength: 0)
            }
            .frame(width: rowWidth, height: rowHeight)
        } else if dragOffset < 0 {
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color.white)
                }
                .padding(.trailing, 28)
                .frame(width: max(actionWidth, -dragOffset), height: rowHeight)
                .background(Color.red)
            }
            .frame(width: rowWidth, height: rowHeight)
        }
    }

    private func clampedOffset(_ offset: CGFloat) -> CGFloat {
        max(-actionWidth, min(actionWidth, offset))
    }

    private func finishSwipe(translation: CGFloat) {
        if translation <= -swipeThreshold {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                dragOffset = -actionWidth
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                onDelete()
                resetOffset()
            }
        } else if translation >= swipeThreshold {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                dragOffset = actionWidth
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                onTogglePin()
                resetOffset()
            }
        } else {
            resetOffset()
        }
    }

    private func resetOffset() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            dragOffset = 0
        }
    }
}

private struct CollectionEmptyState: View {
    let height: CGFloat

    var body: some View {
        VStack(spacing: 12) {
            OutfitImage(name: "app_ic_wardrobe", contentMode: .fit)
                .frame(width: 96, height: 96)

            Text("No collections yet")
                .font(.outfitBody(16, weight: .semibold))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)

            Text("Create your first collection to organize your wardrobe.")
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .multilineTextAlignment(.center)
                .frame(width: 280)
        }
        .frame(width: 356, height: height)
    }
}

private struct CreateCollectionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                Text("Create collection")
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 356, height: 56)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

enum CollectionKind {
    case wardrobe
    case outfit
}

enum CollectionMode {
    case browse
    case select
}

private struct WardrobeItemCollectionSheetView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isCreateCollectionPresented = false
    let item: WardrobeItem

    private var sortedCollections: [CollectionGroup] {
        store.collections.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private var selectedCollectionIDs: Set<UUID> {
        Set(store.collections.filter { $0.itemIDs.contains(item.id) }.map(\.id))
    }

    private var hasSelectedCollections: Bool {
        !selectedCollectionIDs.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(hex: 0xA3A3A3))
                .frame(width: 36, height: 4)
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 0) {
                Text("Select View")
                    .font(.outfitBody(24, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.top, 28)

                if sortedCollections.isEmpty {
                    CollectionMembershipEmptyState()
                        .frame(width: 356, height: 430)
                        .padding(.top, 20)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(sortedCollections) { collection in
                                CollectionSelectionRow(
                                    title: collection.title,
                                    subtitle: collection.subtitle,
                                    isSelected: selectedCollectionIDs.contains(collection.id),
                                    isPrimary: false
                                ) {
                                    toggle(collection)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(width: 356, height: 304, alignment: .top)
                    .padding(.top, 18)
                }
            }
            .frame(width: 356, alignment: .topLeading)

            Spacer(minLength: 0)

            CollectionSheetActionButton(
                title: hasSelectedCollections ? "Add to collections" : "Create collection",
                systemImage: hasSelectedCollections ? "checkmark" : "plus"
            ) {
                if hasSelectedCollections {
                    dismiss()
                } else {
                    isCreateCollectionPresented = true
                }
            }
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: 0xF3F3F3))
        .sheet(isPresented: $isCreateCollectionPresented) {
            CollectionEditorSheetView()
            .presentationDetents([.height(406)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color(hex: 0xF3F3F3))
        }
    }

    private func toggle(_ collection: CollectionGroup) {
        let isSelected = selectedCollectionIDs.contains(collection.id)
        store.setWardrobeItem(item.id, included: !isSelected, in: collection.id)
    }
}

private struct CollectionSelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isPrimary: Bool
    var action: (() -> Void)?

    var body: some View {
        rowContent
            .contentShape(Rectangle())
            .onTapGesture {
                action?()
            }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.outfitBody(14, weight: .bold))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.outfitBody(14, weight: .regular))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: isSelected ? 0xD9D9D9 : 0xEBEBEB))
                    .frame(width: 24, height: 24)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black)
                }
            }
        }
        .padding(.horizontal, 28)
        .frame(width: 356, height: 84)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if isPrimary {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black, lineWidth: 1)
            }
        }
    }
}

struct CollectionMembershipEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            OutfitImage(name: "app_ic_wardrobe", contentMode: .fit)
                .frame(width: 56, height: 56)

            Text("No collection created yet")
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)

            Text("Create collection to organize clothing for trips")
                .font(.outfitBody(14, weight: .medium))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct CollectionSheetActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                Text(title)
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 356, height: 56)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CollectionEditorSheetView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    let onCreate: (CollectionGroup) -> Void

    init(onCreate: @escaping (CollectionGroup) -> Void = { _ in }) {
        self.onCreate = onCreate
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        trimmedName.count >= 2 && trimmedDescription.count >= 4
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(hex: 0xA3A3A3))
                .frame(width: 36, height: 4)
                .padding(.top, 22)

            VStack(alignment: .leading, spacing: 0) {
                Text("Create New Collection")
                    .font(.outfitBody(24, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.top, 30)

                CollectionSheetTextField(placeholder: "Enter the name*", text: $name)
                    .padding(.top, 18)

                CollectionSheetTextField(placeholder: "Enter a description*", text: $description)
                    .padding(.top, 14)

                Button {
                    saveCollection()
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.white.opacity(0.22))
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
                    .frame(width: 356, height: 56)
                    .background(canSave ? Color.black : Color(hex: 0x858585), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .padding(.top, 34)

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.outfitBody(16, weight: .medium))
                        .foregroundStyle(Color.black)
                        .frame(width: 356, height: 56)
                        .overlay {
                            Capsule()
                                .stroke(Color.black, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
            .frame(width: 356, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: 0xF3F3F3))
    }

    private func saveCollection() {
        guard let collection = store.createCollection(title: trimmedName, subtitle: trimmedDescription) else { return }
        onCreate(collection)
        dismiss()
    }
}

private struct CollectionSheetTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.outfitBody(16, weight: .regular))
            .foregroundStyle(Color.black)
            .tint(Color.black)
            .padding(.horizontal, 24)
            .frame(width: 356, height: 50)
            .background(Color.white, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            }
    }
}

struct CollectionEditorView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var name = ""
    @State private var description = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        AppCanvas {
            DetailTopBar(title: "Create new collection")
                .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)
            AppInputPill(placeholder: "Enter the name*", text: $name)
                .appFrame(x: 18, y: 150, w: 356, h: 50)
            AppInputPill(placeholder: "Enter a description*", text: $description)
                .appFrame(x: 18, y: 216, w: 356, h: 50)
            AppPrimaryButton(title: "Save", isEnabled: !trimmedName.isEmpty) {
                saveCollection()
            }
                .appFrame(x: 18, y: smallDeviceAdaptation.bottomPinnedY(703, height: 56 + 66), w: 356, h: 56)
            AppSecondaryButton(title: "Cancel") { router.pop() }
                .appFrame(x: 18, y: smallDeviceAdaptation.bottomPinnedY(772, height: 50), w: 356, h: 50)
        }
    }

    private func saveCollection() {
        let subtitle = trimmedDescription.isEmpty ? "No description" : trimmedDescription
        if store.createCollection(title: trimmedName, subtitle: subtitle) != nil {
            router.pop()
        } else {
            router.presentPaywall(source: .inApp)
        }
    }
}

struct CollectionDetailView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var isDeleteAlertPresented = false
    let collection: CollectionGroup

    private var currentCollection: CollectionGroup {
        store.collections.first { $0.id == collection.id } ?? collection
    }

    private var collectionItems: [WardrobeItem] {
        store.items(in: currentCollection)
    }

    private var collectionOutfits: [OutfitSuggestion] {
        currentCollection.outfitIDs.compactMap { outfitID in
            store.outfits.first { $0.id == outfitID }
        }
    }

    var body: some View {
        AppCanvas {
            CollectionTopBar(title: currentCollection.title) {
                AppIconButton(name: "app_ic_delete") {
                    isDeleteAlertPresented = true
                }
                .frame(width: 32, height: 32)
            }
                .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)

            if collectionItems.isEmpty && collectionOutfits.isEmpty {
                CollectionItemsEmptyState()
                    .appFrame(
                        x: 18,
                        y: smallDeviceAdaptation.underHeaderY(136),
                        w: 356,
                        h: smallDeviceAdaptation.underHeaderHeight(548)
                    )
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(116), spacing: 4), count: 3), spacing: 4) {
                        ForEach(collectionOutfits) { outfit in
                            Button {
                                router.push(.outfitDetail(outfit))
                            } label: {
                                OutfitThumbnail(outfit: outfit)
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(collectionItems) { item in
                            AppImageTile(imageName: item.imageName, imageData: item.imageData, showsBackground: false) {
                                router.push(.itemDetail(item))
                            }
                        }
                    }
                    .padding(.bottom, smallDeviceAdaptation.scrollBottomPadding(50))
                }
                .frame(width: 356, height: smallDeviceAdaptation.underHeaderHeight(666), alignment: .top)
                .clipped()
                .appFrame(
                    x: 18,
                    y: smallDeviceAdaptation.underHeaderY(136),
                    w: 356,
                    h: smallDeviceAdaptation.underHeaderHeight(666),
                    alignment: .topLeading
                )
            }
        }
        .alert("Вы действительно хотите удалить коллекцию?", isPresented: $isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteCollection(id: currentCollection.id)
                router.pop()
            }
        }
    }
}

private struct CollectionItemsEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            OutfitImage(name: "app_ic_empty", contentMode: .fit)
                .frame(width: 136, height: 136)

            Text("No items yet")
                .font(.outfitBody(16, weight: .semibold))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)

            Text("Items you add to this collection will appear here.")
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .multilineTextAlignment(.center)
                .frame(width: 280)
        }
        .frame(width: 356, height: 548)
    }
}

struct DetailTopBar<Trailing: View>: View {
    @Environment(AppRouter.self) private var router
    let title: String
    @ViewBuilder var trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            AppIconButton(name: "app_btn_back") {
                if router.path.isEmpty {
                    router.popToRoot()
                } else {
                    _ = router.path.popLast()
                }
            }
            AppText(value: title, role: .appTitle)
                .lineLimit(1)
            Spacer()
            trailing
        }
        .frame(width: 356, height: 40)
    }
}

struct TagSection: View {
    let title: String
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppText(value: title, role: .section)
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    AppChip(title: value)
                }
            }
        }
    }
}

struct PrivacyRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            AppText(value: title, role: .small)
            AppText(value: value, role: .body, color: .black)
        }
    }
}

struct CollectionRow: View {
    let collection: CollectionGroup

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(collection.title)
                    .font(.outfitBody(14, weight: .bold))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                Text(collection.subtitle)
                    .font(.outfitBody(14, weight: .regular))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
            }

            Spacer()

            if collection.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.black)
        }
        .padding(.horizontal, 24)
        .frame(width: 356, height: 76)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct CategoryScroller: View {
    let categories: [ClothingCategory]
    let selected: ClothingCategory
    let action: (ClothingCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    AppChip(title: category.rawValue, selected: selected == category) {
                        action(category)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: 30, alignment: .leading)
        }
        .frame(width: 356, height: 30, alignment: .leading)
        .clipped()
    }
}

#Preview {
    WardrobeView()
        .environment(OutfitDataStore())
        .environment(AppRouter())
}
