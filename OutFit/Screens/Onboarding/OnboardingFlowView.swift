import SwiftUI
import SafariServices

struct OnboardingFlowView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var page = 0
    @State private var name = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var legalDocument: AppConstants.Legal.Document?

    private let pages = OnboardingFrameSpec.all
    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        page != 0 || normalizedName.count >= 2
    }

    private var currentSubtitle: String {
        pages[page].subtitle(normalizedName)
    }

    private var keyboardLift: CGFloat {
        page == 0 && keyboardHeight > 0 ? -min(160, keyboardHeight * 0.45) : 0
    }

    var body: some View {
        let layout = OnboardingLayout(device: smallDeviceAdaptation)

        AppCanvas {
            Group {
                OnboardingHeroAsset(name: pages[page].heroName, height: layout.heroHeight)
                    .appFrame(x: 0, y: 0, w: 393, h: layout.heroHeight)

                OnboardingPageIndicator(currentPage: page, pageCount: pages.count)
                    .appFrame(x: 139, y: layout.y(493), w: 116, h: 8)

                AppText(value: pages[page].title, role: .onboardingTitle, alignment: .center)
                    .frame(width: 356, alignment: .center)
                    .appFrame(x: 18, y: layout.y(531), w: 356, h: pages[page].titleHeight)

                AppText(value: currentSubtitle, role: .onboardingSubtitle, alignment: .center)
                    .frame(width: 356, alignment: .center)
                    .appFrame(x: 18, y: layout.y(pages[page].subtitleY), w: 356, h: 52)

                if page == 0 {
                    AppInputPill(placeholder: "What is your name?", text: $name)
                        .appFrame(x: 18, y: layout.y(621), w: 356, h: 50)
                } else {
                    OnboardingNoteChip(title: pages[page].note)
                        .appFrame(x: 18, y: layout.y(pages[page].noteY), w: 356, h: 30)
                }

                AppPrimaryButton(title: "Continue", isEnabled: canContinue) {
                    guard canContinue else { return }

                    if page < pages.count - 1 {
                        withAnimation(.smooth(duration: 0.25)) {
                            page += 1
                        }
                    } else {
                        store.profile.name = normalizedName
                        store.didCompleteOnboarding = true
                        router.presentPaywall(source: .onboarding)
                    }
                }
                .appFrame(x: 18, y: layout.y(703), w: 356, h: 56)

                if page == 0 {
                    OnboardingLegalText { document in
                        legalDocument = document
                    }
                    .appFrame(x: 31, y: layout.y(784), w: 330, h: 32)
                }
            }
            .offset(y: keyboardLift)
        }
        .animation(.smooth(duration: 0.25), value: keyboardLift)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            keyboardHeight = Self.keyboardHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .sheet(item: $legalDocument) { document in
            SafariLegalView(url: document.url)
                .ignoresSafeArea()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private static func keyboardHeight(from notification: Notification) -> CGFloat {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return 0 }
        return max(0, UIScreen.main.bounds.maxY - frame.minY)
    }
}

private struct SafariLegalView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct OnboardingPageIndicator: View {
    let currentPage: Int
    let pageCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.black : Color(hex: 0xE1E1E1))
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: 116, height: 8, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding page \(currentPage + 1) of \(pageCount)")
    }
}

private struct OnboardingNoteChip: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(OutfitTheme.Color.secondaryText.opacity(0.38))
                .frame(width: 22, height: 22)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black)
                }

            Text(title)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.black)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(height: 30)
        .fixedSize(horizontal: true, vertical: false)
        .background(OutfitTheme.Color.chip, in: Capsule())
    }
}

private struct OnboardingLegalText: View {
    let openDocument: (AppConstants.Legal.Document) -> Void

    var body: some View {
        VStack(spacing: 1) {
            Text(AppConstants.Legal.acceptanceLine)
                .foregroundStyle(OutfitTheme.Color.secondaryText)

            HStack(spacing: 0) {
                Text(AppConstants.Legal.acceptancePrefix)
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
                legalButton(.terms)
                Text(AppConstants.Legal.acceptanceJoiner)
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
                legalButton(.privacy)
            }
        }
        .font(.outfitMontserrat(12, weight: .medium))
        .multilineTextAlignment(.center)
        .frame(width: 330, height: 32)
    }

    private func legalButton(_ document: AppConstants.Legal.Document) -> some View {
        Button {
            openDocument(document)
        } label: {
            Text(document.title)
                .foregroundStyle(Color.black)
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingFrameSpec {
    let title: String
    let subtitle: (String) -> String
    let note: String
    let subtitleY: CGFloat
    let noteY: CGFloat
    let titleHeight: CGFloat
    let heroName: String

    init(
        title: String,
        subtitle: @escaping (String) -> String,
        note: String,
        subtitleY: CGFloat,
        noteY: CGFloat = 655,
        titleHeight: CGFloat,
        heroName: String
    ) {
        self.title = title
        self.subtitle = subtitle
        self.note = note
        self.subtitleY = subtitleY
        self.noteY = noteY
        self.titleHeight = titleHeight
        self.heroName = heroName
    }

    init(
        title: String,
        subtitle: String,
        note: String,
        subtitleY: CGFloat,
        noteY: CGFloat = 655,
        titleHeight: CGFloat,
        heroName: String
    ) {
        self.init(
            title: title,
            subtitle: { _ in subtitle },
            note: note,
            subtitleY: subtitleY,
            noteY: noteY,
            titleHeight: titleHeight,
            heroName: heroName
        )
    }

    static let all: [OnboardingFrameSpec] = [
        OnboardingFrameSpec(
            title: "Let’s Begin",
            subtitle: "The data will help you customize the application individually for you.",
            note: "",
            subtitleY: 568,
            noteY: 655,
            titleHeight: 32,
            heroName: "app_bg_onbording"
        ),
        OnboardingFrameSpec(
            title: "Your Digital Wardrobe",
            subtitle: { name in
                "Hey \(name), just upload your clothes — I detect colors, style and occasion automatically."
            },
            note: "Done in minutes with bulk upload.",
            subtitleY: 568,
            noteY: 645,
            titleHeight: 32,
            heroName: "app_bg_onbording_1"
        ),
        OnboardingFrameSpec(
            title: "Automatic Outfits At The Touch Of A Button",
            subtitle: "Just tell me your occasion —\nI’ll put together the perfect outfit for you!",
            note: "I find matching combos in seconds",
            subtitleY: 600,
            noteY: 666,
            titleHeight: 58,
            heroName: "app_bg_onbording_2"
        ),
        OnboardingFrameSpec(
            title: "Organize Like A Pro",
            subtitle: "Create collections for vacation, work, or occasions\n— I’ll help you pack!",
            note: "I keep track of your packing lists",
            subtitleY: 590,
            noteY: 656,
            titleHeight: 58,
            heroName: "app_bg_onbording_3"
        ),
        OnboardingFrameSpec(
            title: "Know What You Wear",
            subtitle: "I track what you wear, how often, and\nwhat’s been sitting untouched.",
            note: "I find your forgotten pieces",
            subtitleY: 590,
            noteY: 656,
            titleHeight: 58,
            heroName: "app_bg_onbording_4"
        ),
        OnboardingFrameSpec(
            title: "Try On Outfits Virtually",
            subtitle: "Mix & match your clothes on your avatar — see\nhow they look before wearing them!",
            note: "I show you how outfits look on you",
            subtitleY: 590,
            noteY: 656,
            titleHeight: 58,
            heroName: "app_bg_onbording_5"
        )
    ]
}

private struct OnboardingLayout {
    private static let regularHeroHeight: CGFloat = 480
    private static let smallHeroHeight: CGFloat = 360

    let device: SmallDeviceAdaptation

    var heroHeight: CGFloat {
        device.value(regular: Self.regularHeroHeight, small: Self.smallHeroHeight)
    }

    private var verticalReduction: CGFloat {
        Self.regularHeroHeight - heroHeight
    }

    func y(_ regularY: CGFloat) -> CGFloat {
        regularY - verticalReduction
    }
}

private struct OnboardingHeroAsset: View {
    let name: String
    let height: CGFloat

    var body: some View {
        OutfitImage(name: name, contentMode: .fit)
            .frame(width: 393, height: height)
    }
}

private struct OnboardingAvatarHero: View {
    var body: some View {
        ZStack {
            OutfitImage(name: AssetName.avatarLena, contentMode: .fit)
                .appFrame(x: -12, y: 92, w: 206, h: 374)
                .opacity(0.92)
            OutfitImage(name: AssetName.avatarMargo, contentMode: .fit)
                .appFrame(x: 122, y: 46, w: 236, h: 424)
        }
    }
}

private struct OnboardingWardrobeHero: View {
    private let images = [
        AssetName.dress, AssetName.jeans, AssetName.vest,
        AssetName.denimJacket, AssetName.stripedShirt, AssetName.hat,
        AssetName.pinkBag, AssetName.blackJacket, AssetName.beigeJacket
    ]

    var body: some View {
        ZStack {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                AppImageTile(imageName: image)
                    .appFrame(x: CGFloat(index % 3) * 120 + 18, y: CGFloat(index / 3) * 144 - 28, w: 116, h: 140)
            }
        }
    }
}

private struct OnboardingOutfitHero: View {
    var body: some View {
        ZStack {
            HStack {
                OutfitImage(name: AssetName.rainy)
                    .frame(width: 32, height: 32)
                AppText(value: "+20°C", role: .secondary)
                Spacer()
                AppIcon(name: "arrow.triangle.2.circlepath", size: 32)
            }
            .padding(.horizontal, 16)
            .frame(width: 356, height: 48)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .appFrame(x: 18, y: 72, w: 356, h: 48)

            HStack(spacing: 8) {
                AppChip(title: "Business Meeting", selected: true)
                AppChip(title: "Summer")
                AppChip(title: "Party")
                AppChip(title: "Date")
                AppChip(title: "Date")
            }
            .appFrame(x: 18, y: 136, w: 500, h: 30, alignment: .leading)

            AppInputPill(placeholder: "Outfit for...", isAI: true)
                .appFrame(x: 18, y: 190, w: 356, h: 50)

            AppImageTile(imageName: AssetName.dress, width: 175, height: 211)
                .appFrame(x: 18, y: 256, w: 175, h: 211)
            AppImageTile(imageName: AssetName.jeans, width: 175, height: 211)
                .appFrame(x: 199, y: 256, w: 175, h: 211)
        }
        .clipped()
    }
}

private struct OnboardingCollectionHero: View {
    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                AppChip(title: "Wardrobe")
                AppChip(title: "Holiday in Japan", selected: true)
            }
            .appFrame(x: 18, y: 72, w: 356, h: 30, alignment: .leading)

            AppImageTile(imageName: AssetName.dress, width: 175, height: 211)
                .appFrame(x: 18, y: 118, w: 175, h: 211)
            AppImageTile(imageName: AssetName.jeans, width: 175, height: 211)
                .appFrame(x: 199, y: 118, w: 175, h: 211)
            AppImageTile(imageName: AssetName.denimJacket, width: 175, height: 211)
                .appFrame(x: 18, y: 335, w: 175, h: 211)
            AppImageTile(imageName: AssetName.stripedShirt, width: 175, height: 211)
                .appFrame(x: 199, y: 335, w: 175, h: 211)
        }
        .clipped()
    }
}

private struct OnboardingStatsHero: View {
    var body: some View {
        ZStack {
            HStack(spacing: 4) {
                AppStatCard(label: "Total Items", value: "12")
                AppStatCard(label: "Worn this week", value: "12")
                AppStatCard(label: "Never worn", value: "3")
            }
            .appFrame(x: 18, y: 94, w: 356, h: 100)

            AppText(value: "Recently Worn", role: .section)
                .appFrame(x: 18, y: 226, w: 356, h: 22, alignment: .leading)
            HStack(spacing: 4) {
                AppImageTile(imageName: AssetName.dress)
                AppImageTile(imageName: AssetName.jeans)
                AppImageTile(imageName: AssetName.hat)
            }
            .appFrame(x: 18, y: 260, w: 356, h: 140, alignment: .leading)

            AppText(value: "Forgotten treasures", role: .section)
                .appFrame(x: 18, y: 416, w: 356, h: 22, alignment: .leading)
        }
    }
}

private struct OnboardingMixHero: View {
    var body: some View {
        ZStack {
            OutfitImage(name: AssetName.avatarMargo, contentMode: .fit)
                .appFrame(x: 78, y: 56, w: 238, h: 410)

            HStack(spacing: 8) {
                AppChip(title: "Tops", selected: true)
                AppChip(title: "Bikinis")
                AppChip(title: "Bags")
                AppChip(title: "Bottoms")
                AppChip(title: "Dresses")
            }
            .appFrame(x: 18, y: 396, w: 520, h: 30, alignment: .leading)
        }
        .clipped()
    }
}

#Preview {
    OnboardingFlowView()
        .environment(OutfitDataStore())
        .environment(AppRouter())
}
