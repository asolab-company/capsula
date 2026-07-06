import AVFoundation
import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @StateObject private var weather = WeatherKitManager()
    @State private var outfitPrompt = ""
    @FocusState private var isOutfitPromptFocused: Bool

    private let promptLimit = 50

    private var trimmedOutfitPrompt: String {
        outfitPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreateOutfit: Bool {
        !trimmedOutfitPrompt.isEmpty
    }

    private var scrollBottomPadding: CGFloat {
        smallDeviceAdaptation.scrollBottomPadding()
    }

    private var activeFeatureCards: [HomeFeatureCardModel] {
        var cards: [HomeFeatureCardModel] = []

        if store.wardrobeItems.isEmpty {
            cards.append(.init(
                title: "Organize Your Wardrobe",
                subtitle: "Keep all your clothes in one smart digital closet.",
                iconName: "app_ic_home_feature_wardrobe",
                locked: false
            ))
        }

        if store.collections.isEmpty {
            cards.append(.init(
                title: "Pack Smarter for Trips",
                subtitle: "Generate packing lists and travel-ready outfits instantly.",
                iconName: "app_ic_home_feature_trips",
                locked: true
            ))
        }

        if store.outfits.isEmpty {
            cards.append(.init(
                title: "Dress for the Weather",
                subtitle: "Get outfit suggestions based on today's forecast, temperature, and season.",
                iconName: "app_ic_home_feature_weather",
                locked: true
            ))
        }

        if store.avatars.isEmpty {
            cards.append(.init(
                title: "Create Your AI Avatar",
                subtitle: "See outfits on your personalized avatar before wearing them in real life.",
                iconName: "app_ic_home_feature_avatar",
                locked: true
            ))
        }

        return cards
    }

    var body: some View {
        AppCanvas {
            if store.wardrobeItems.count < 5 {
                lockedContent
            } else {
                unlockedContent
            }

            AppTopFade()

            HomeGreetingHeader(name: store.profile.name, weather: weather.snapshot)
            .appFrame(x: 18, y: 71, w: 356, h: 48, alignment: .topLeading)

            if store.wardrobeItems.count >= 5 {
                HomeOutfitPromptPill(
                    text: $outfitPrompt,
                    isFocused: $isOutfitPromptFocused,
                    limit: promptLimit,
                    canSubmit: canCreateOutfit
                ) {
                    submitOutfitPrompt()
                }
                .appFrame(x: 18, y: smallDeviceAdaptation.underHeaderY(150), w: 356, h: 50)
            }
        }
        .task {
            weather.start()
        }
    }

    @ViewBuilder
    private var lockedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                AppProgressCard(count: store.wardrobeItems.count)

                AppPrimaryButton(title: "Add Item to your Wardrobe", iconName: "app_ic_add") {
                    openAddItemFlow()
                }

                VStack(spacing: 8) {
                    ForEach(activeFeatureCards) { card in
                        AppFeatureCard(
                            title: card.title,
                            subtitle: card.subtitle,
                            iconName: card.iconName,
                            locked: card.locked
                        )
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, scrollBottomPadding)
        }
        .appFrame(
            x: 0,
            y: smallDeviceAdaptation.underHeaderY(138),
            w: 393,
            h: smallDeviceAdaptation.underHeaderHeight(648),
            alignment: .topLeading
        )
    }

    private var unlockedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 25) {
                if !store.wardrobeItems.isEmpty {
                    HomeRecentStrip(title: "Your Wardrobe", showAll: { showTab(.wardrobe) }) {
                        AppAddTile(title: "Add") { openAddItemFlow() }
                        ForEach(Array(store.wardrobeItems.prefix(2).enumerated()), id: \.element.id) { _, item in
                            AppImageTile(imageName: item.imageName, imageData: item.imageData, showsBackground: false) {
                                router.push(.itemDetail(item))
                            }
                        }
                    }
                }

                if !store.outfits.isEmpty {
                    HomeRecentStrip(title: "Your Outfits", showAll: { showTab(.outfits) }) {
                        ForEach(Array(store.outfits.prefix(3).enumerated()), id: \.element.id) { _, outfit in
                            Button {
                                router.push(.outfitDetail(outfit))
                            } label: {
                                OutfitThumbnail(outfit: outfit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !store.avatars.isEmpty {
                    HomeRecentStrip(title: "Your Avatars", showAll: { showTab(.avatar) }) {
                        ForEach(Array(store.avatars.prefix(3).enumerated()), id: \.element.id) { _, avatar in
                            HomeAvatarTile(avatar: avatar) {
                                router.push(.avatarDetail(avatar))
                            }
                        }
                    }
                }

                ForEach(activeFeatureCards) { card in
                    AppFeatureCard(
                        title: card.title,
                        subtitle: card.subtitle,
                        iconName: card.iconName,
                        locked: card.locked
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, scrollBottomPadding)
        }
        .appFrame(
            x: 0,
            y: smallDeviceAdaptation.underHeaderY(214),
            w: 393,
            h: smallDeviceAdaptation.underHeaderHeight(572),
            alignment: .topLeading
        )
    }

    private func openAddItemFlow() {
        guard store.canAnalyzeClothingThisWeek else {
            router.presentPaywall(source: .inApp)
            return
        }
        if store.didAcceptWardrobeAnalysis {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                router.push(.cameraCapture(.clothing))
            default:
                router.push(.cameraPermission(.clothing))
            }
        } else {
            router.presentAccess(kind: .clothing)
        }
    }

    private func submitOutfitPrompt() {
        guard canCreateOutfit else { return }
        guard store.recordOutfitGenerationIfAllowed() else {
            router.presentPaywall(source: .inApp)
            return
        }
        let request = OutfitGenerationRequest(
            suggestionCount: 1,
            sourceID: "wardrobe",
            weather: "Not specified",
            occasion: trimmedOutfitPrompt
        )
        isOutfitPromptFocused = false
        router.push(.outfitProcessing(request))
    }

    private func showTab(_ tab: AppTab) {
        router.popToRoot()
        router.selectedTab = tab
    }
}

private struct HomeAvatarTile: View {
    let avatar: AvatarProfile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let imageData = avatar.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    OutfitImage(name: avatar.imageName, contentMode: .fit)
                }
            }
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

private struct HomeFeatureCardModel: Identifiable {
    let title: String
    let subtitle: String
    let iconName: String
    let locked: Bool

    var id: String { title }
}

private struct HomeOutfitPromptPill: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let limit: Int
    let canSubmit: Bool
    let submit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(width: 24, height: 24)

            TextField("Outfit for...", text: $text)
                .focused(isFocused)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.black)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit {
                    guard canSubmit else { return }
                    submit()
                }
                .onChange(of: text) { _, newValue in
                    if newValue.count > limit {
                        text = String(newValue.prefix(limit))
                    }
                }

            Button(action: submit) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
                    .background(canSubmit ? Color.black : Color(hex: 0xA5A5A5), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .padding(.leading, 20)
        .padding(.trailing, 9)
        .frame(width: 356, height: 50)
        .background(Color.white, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: 0xFF8FE8), Color(hex: 0xFFC36A), Color(hex: 0x6FF5B8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

private struct HomeRecentStrip<Content: View>: View {
    let title: String
    let showAll: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppText(value: title, role: .section)
                Spacer()
                Button("Show all", action: showAll)
                    .font(.outfitBody(12, weight: .semibold))
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
            }
            .frame(width: 356, height: 22)

            HStack(spacing: 4) {
                content
                Spacer(minLength: 0)
            }
            .frame(width: 356, height: 140, alignment: .leading)
        }
        .frame(width: 356, alignment: .leading)
    }
}

private struct HomeGreetingHeader: View {
    let name: String
    let weather: LocalWeatherSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.outfitHero(24))
                    .foregroundStyle(OutfitTheme.Color.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                AppText(value: "What do you want to wear today?", role: .secondary)
            }
            Spacer()
            WeatherBadgeApp(snapshot: weather)
        }
        .frame(width: 356, alignment: .topLeading)
    }

    private var greeting: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = "\(dayPartGreeting)\(trimmedName.isEmpty ? "" : ", \(trimmedName)")"
        return text
    }

    private var dayPartGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good day"
        case 17..<22:
            return "Good evening"
        default:
            return "Good night"
        }
    }
}

private struct WeatherBadgeApp: View {
    let snapshot: LocalWeatherSnapshot

    var body: some View {
        VStack(spacing: 1) {
            OutfitImage(name: snapshot.iconName)
                .frame(width: 32, height: 32)
            AppText(value: snapshot.temperatureText, role: .secondary, alignment: .center)
                .frame(width: 48, height: 17)
        }
    }
}

private struct HomeStrip<Content: View>: View {
    let title: String
    let y: CGFloat
    var showAll: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppText(value: title, role: .section)
                .appFrame(x: 18, y: y, w: 240, h: 22, alignment: .leading)
            Button("Show all", action: showAll)
                .font(.outfitBody(12, weight: .semibold))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .appFrame(x: 316, y: y + 2, w: 58, h: 16)
            HStack(spacing: 4) {
                content
            }
            .appFrame(x: 18, y: y + 34, w: 356, h: 140, alignment: .leading)
        }
    }
}

struct WardrobeProgressCard: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppProgressCard(count: count)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environment(OutfitDataStore())
        .environment(AppRouter())
}
