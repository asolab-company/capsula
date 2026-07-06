import SwiftUI
import SafariServices

struct PaywallView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var subscriptionStore = SubscriptionStore()
    @State private var legalDocument: AppConstants.Legal.Document?
    @State private var alert: PaywallAlert?
    var plan: PaywallPlan = .monthly
    var source: PaywallSource = .onboarding

    private let features = PaywallFeature.appRows

    var body: some View {
        let layout = PaywallLayout(device: smallDeviceAdaptation)

        AppCanvas {
            if source == .inApp {
                PaywallCloseButton {
                    closePaywall()
                }
                .appFrame(x: 18, y: layout.closeButtonY, w: 28, h: 28)
            }

            PaywallHeroIcon(size: layout.heroIconSize)
                .appFrame(x: layout.heroIconX, y: layout.heroIconY, w: layout.heroIconSize, h: layout.heroIconSize)

            Text("Boost Your Outfits\nWith Pro Features")
                .font(.outfitHero(layout.titleSize))
                .foregroundStyle(OutfitTheme.Color.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 356, alignment: .center)
                .appFrame(x: 18, y: layout.titleY, w: 356, h: layout.titleHeight)

            PaywallPlanLabels()
                .appFrame(x: 253, y: layout.planLabelsY, w: 121, h: 30)

            VStack(spacing: layout.featureSpacing) {
                ForEach(features) { feature in
                    PaywallFeatureRow(feature: feature)
                }
            }
            .appFrame(x: 18, y: layout.featuresY, w: 356, h: layout.featuresHeight, alignment: .topLeading)

            PaywallPlanCard(plan: plan)
                .appFrame(x: 18, y: layout.planCardY, w: 356, h: 70)

            AppPrimaryButton(title: subscriptionStore.isProcessing ? "Please Wait" : "Unlock Pro Features", isEnabled: !subscriptionStore.isProcessing) {
                Task {
                    await unlockProFeatures()
                }
            }
            .appFrame(x: 18, y: layout.buttonY, w: 356, h: 56)

            PaywallCancelAnytime()
                .appFrame(x: 137, y: layout.cancelAnytimeY, w: 120, h: 21)

            PaywallFooterLinks(
                onPrivacy: { legalDocument = .privacy },
                onSkip: source == .onboarding ? { skipPaywall() } : nil,
                onRestore: {
                    Task {
                        await restorePurchases()
                    }
                },
                onTerms: { legalDocument = .terms }
            )
            .appFrame(x: 42, y: layout.footerY, w: 311, h: 14)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await subscriptionStore.loadProducts()
            await subscriptionStore.refreshEntitlements()
            if subscriptionStore.hasActiveSubscription {
                store.hasPremiumAccess = true
            }
        }
        .sheet(item: $legalDocument) { document in
            PaywallSafariLegalView(url: document.url)
                .ignoresSafeArea()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert(item: $alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func unlockProFeatures() async {
        if await subscriptionStore.purchaseMonthly() {
            finishPremiumFlow()
        } else if let errorMessage = subscriptionStore.errorMessage {
            alert = PaywallAlert(title: "Purchase Failed", message: errorMessage)
        }
    }

    private func restorePurchases() async {
        if await subscriptionStore.restorePurchases() {
            finishPremiumFlow()
        } else if let errorMessage = subscriptionStore.errorMessage {
            alert = PaywallAlert(title: "Restore Failed", message: errorMessage)
        } else {
            alert = PaywallAlert(title: "No Subscription Found", message: "We could not find an active subscription to restore.")
        }
    }

    private func skipPaywall() {
        store.didCompleteOnboarding = true
        closePaywall()
    }

    private func finishPremiumFlow() {
        store.hasPremiumAccess = true
        if source == .onboarding {
            store.didCompleteOnboarding = true
        }
        closePaywall()
    }

    private func closePaywall() {
        if router.paywallPresentation != nil {
            router.dismissPaywall()
        } else {
            router.pop()
        }
    }
}

enum PaywallSource {
    case onboarding
    case inApp
}

private struct PaywallSafariLegalView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct PaywallAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum PaywallPlan {
    case yearly
    case monthly

    var title: String {
        switch self {
        case .yearly: "Yearly"
        case .monthly: "Monthly"
        }
    }

    var price: String {
        switch self {
        case .yearly: "USD 49.99"
        case .monthly: AppConstants.Subscriptions.monthlyDisplayPrice
        }
    }

    var originalPrice: String {
        switch self {
        case .yearly: "USD 109.99"
        case .monthly: "USD 12.99"
        }
    }

    var badge: String {
        switch self {
        case .yearly: "-58%"
        case .monthly: "-23%"
        }
    }
}

private struct PaywallFeature: Identifiable {
    let id = UUID()
    let icon: PaywallFeatureIcon
    let title: String
    let subtitle: String
    let free: String
    let pro: PaywallFeatureValue

    static let appRows: [PaywallFeature] = [
        PaywallFeature(icon: .sparkles, title: "AI Outfit Generations", subtitle: "Outfit suggestions per week", free: "1", pro: .text("10")),
        PaywallFeature(icon: .hanger, title: "Clothing analysis", subtitle: "Add items per week", free: "5", pro: .text("15")),
        PaywallFeature(icon: .suitcase, title: "Suitcases & Collections", subtitle: "Organize your clothes & outfits", free: "-", pro: .text("Unlimited")),
        PaywallFeature(icon: .person, title: "Avatar Try-on", subtitle: "Try on outfits on your avatar", free: "1", pro: .check),
        PaywallFeature(icon: .chart, title: "Statistics & Analysis", subtitle: "Insights & wardrobe tracking", free: "1", pro: .check)
    ]
}

private enum PaywallFeatureIcon {
    case sparkles
    case hanger
    case suitcase
    case person
    case chart

    var assetName: String {
        switch self {
        case .sparkles:
            "app_ic_mainiconsmenu_2"
        case .hanger:
            "app_ic_mainiconsmenu_4"
        case .suitcase:
            "app_ic_mainiconsmenu_6"
        case .person:
            "app_ic_mainiconsmenu_3"
        case .chart:
            "app_ic_mainiconsmenu_5"
        }
    }
}

private enum PaywallFeatureValue {
    case text(String)
    case check
}

private struct PaywallLayout {
    let device: SmallDeviceAdaptation

    var closeButtonY: CGFloat {
        device.value(regular: 70, small: 34)
    }

    var heroIconSize: CGFloat {
        device.value(regular: 78, small: 64)
    }

    var heroIconX: CGFloat {
        (OutfitTheme.Layout.referenceWidth - heroIconSize) / 2
    }

    var heroIconY: CGFloat {
        device.value(regular: 97, small: 42)
    }

    var titleSize: CGFloat {
        device.value(regular: 24, small: 21)
    }

    var titleHeight: CGFloat {
        device.value(regular: 58, small: 50)
    }

    var titleY: CGFloat {
        device.value(regular: 199, small: 119)
    }

    var planLabelsY: CGFloat {
        device.value(regular: 273, small: 188)
    }

    var featureSpacing: CGFloat {
        device.value(regular: 16, small: 9)
    }

    var featuresY: CGFloat {
        device.value(regular: 315, small: 225)
    }

    var featuresHeight: CGFloat {
        device.value(regular: 254, small: 226)
    }

    var planCardY: CGFloat {
        device.value(regular: 601, small: 468)
    }

    var buttonY: CGFloat {
        device.value(regular: 703, small: 552)
    }

    var cancelAnytimeY: CGFloat {
        device.value(regular: 773, small: 622)
    }

    var footerY: CGFloat {
        device.value(regular: 806, small: 650)
    }
}

private struct PaywallHeroIcon: View {
    var size: CGFloat = 78

    var body: some View {
        OutfitImage(name: "app_ic_ailogo", contentMode: .fit)
            .frame(width: size, height: size)
    }
}

private struct PaywallCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct PaywallPlanLabels: View {
    var body: some View {
        HStack(spacing: 14) {
            Text("Free")
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .frame(width: 26, alignment: .center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(spacing: 4) {
                AppIcon(name: "app_ic_pro", size: 16, color: .black)
                Text("PRO")
                    .font(.outfitBody(14, weight: .bold))
            }
            .foregroundStyle(Color.black)
            .frame(width: 81, height: 30)
            .background(OutfitTheme.Color.chip, in: Capsule())
        }
    }
}

private struct PaywallFeatureRow: View {
    let feature: PaywallFeature

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaywallFeatureIconView(icon: feature.icon)
                .frame(width: 24, height: 24)
                .position(x: 12, y: 19)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.outfitBody(14, weight: .bold))
                    .foregroundStyle(Color.black)
                Text(feature.subtitle)
                    .font(.outfitBody(14, weight: .regular))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(width: 200, alignment: .leading)
            .position(x: 140, y: 19)

            Text(feature.free)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .frame(width: 40, height: 38, alignment: .center)
                .position(x: 248, y: 19)

            proValue
                .frame(width: 80, height: 38, alignment: .center)
                .position(x: 315, y: 19)
        }
        .frame(width: 356, height: 38, alignment: .leading)
    }

    @ViewBuilder
    private var proValue: some View {
        switch feature.pro {
        case .text(let value):
            Text(value)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.black)
                .lineLimit(1)
        case .check:
            PaywallCheckCircle(size: 16, iconSize: 9)
        }
    }
}

private struct PaywallFeatureIconView: View {
    let icon: PaywallFeatureIcon

    var body: some View {
        Group {
            if let image = AssetResolver.image(named: icon.assetName) {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
            }
        }
        .foregroundStyle(Color.black)
        .frame(width: 24, height: 24)
    }
}

private struct PaywallPlanCard: View {
    let plan: PaywallPlan

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(plan.title)
                    .font(.outfitBody(14, weight: .bold))
                    .foregroundStyle(Color.black)

                HStack(spacing: 4) {
                    Text(plan.originalPrice)
                        .strikethrough(true, color: OutfitTheme.Color.secondaryText)
                    Text("→")
                    Text(plan.price)
                }
                .font(.outfitBody(12, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
            }
            .frame(width: 180, alignment: .leading)

            Spacer()

            Text(plan.badge)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.white)
                .frame(width: 65, height: 30)
                .background(OutfitTheme.Color.secondaryText, in: Capsule())

            PaywallCheckCircle(size: 24, iconSize: 12)
        }
        .padding(.horizontal, 24)
        .frame(width: 356, height: 70)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.black, lineWidth: 1)
        }
    }
}

private struct PaywallCheckCircle: View {
    let size: CGFloat
    let iconSize: CGFloat

    var body: some View {
        Circle()
            .fill(OutfitTheme.Color.chip)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(Color.black)
            }
    }
}

private struct PaywallCancelAnytime: View {
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 16, weight: .semibold))
            Text("Cancel Anytime")
                .font(.outfitBody(12, weight: .semibold))
        }
        .foregroundStyle(Color.black)
    }
}

private struct PaywallFooterLinks: View {
    let onPrivacy: () -> Void
    let onSkip: (() -> Void)?
    let onRestore: () -> Void
    let onTerms: () -> Void

    var body: some View {
        HStack {
            footerButton(AppConstants.Legal.privacyPolicyTitle, action: onPrivacy)
            Spacer()
            if let onSkip {
                footerButton("Skip", action: onSkip)
                Spacer()
            }
            footerButton(AppConstants.Profile.restoreTitle, action: onRestore)
            Spacer()
            footerButton(AppConstants.Legal.termsOfUsePaywallTitle, action: onTerms)
        }
        .font(.outfitBody(12, weight: .medium))
        .foregroundStyle(OutfitTheme.Color.secondaryText)
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .foregroundStyle(OutfitTheme.Color.secondaryText)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
        .environment(OutfitDataStore())
        .environment(AppRouter())
}
