import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case wardrobe
    case outfits
    case avatar
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .wardrobe: "Wardrobe"
        case .outfits: "Outfits"
        case .avatar: "Avatar"
        case .profile: "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .wardrobe: "rectangle.split.2x1.fill"
        case .outfits: "hanger"
        case .avatar: "figure.stand"
        case .profile: "person.fill"
        }
    }
}

enum AppRoute: Hashable {
    case paywall
    case premiumPaywall
    case monthlyPaywall
    case addItemAccess
    case cameraPermission(CaptureKind)
    case cameraCapture(CaptureKind)
    case itemAnalyze
    case itemProcessing
    case itemEditor(WardrobeItem)
    case itemDetail(WardrobeItem)
    case wardrobeCollections
    case collectionDetail(CollectionGroup)
    case createCollection
    case addToCollection
    case createOutfit
    case useWeather
    case outfitProcessing(OutfitGenerationRequest)
    case outfitReview([OutfitSuggestion])
    case outfitDetail(OutfitSuggestion)
    case outfitCollections
    case avatarOnboarding
    case avatarCapture
    case avatarProcessing
    case avatarEditor
    case avatarDetail(AvatarProfile)
    case mixAndMatch
    case editProfile
    case profileAccess
    case profileCrop
}

enum CaptureKind: String, Hashable {
    case clothing
    case avatar
    case profile
}

struct PaywallPresentation: Identifiable {
    let id = UUID()
    let source: PaywallSource
}

struct AccessPresentation: Identifiable {
    let id = UUID()
    let kind: CaptureKind
}

@MainActor
@Observable
final class AppRouter {
    var path: [AppRoute] = []
    var selectedTab: AppTab = .home
    var paywallPresentation: PaywallPresentation?
    var accessPresentation: AccessPresentation?

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func replaceLast(with route: AppRoute) {
        if path.isEmpty {
            path.append(route)
        } else {
            path[path.count - 1] = route
        }
    }

    func presentPaywall(source: PaywallSource) {
        paywallPresentation = PaywallPresentation(source: source)
    }

    func dismissPaywall() {
        paywallPresentation = nil
    }

    func presentAccess(kind: CaptureKind) {
        accessPresentation = AccessPresentation(kind: kind)
    }

    func dismissAccess() {
        accessPresentation = nil
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
