import SwiftUI

struct AppView: View {
    @State private var store = OutfitDataStore()
    @State private var router = AppRouter()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            Group {
                if store.didCompleteOnboarding {
                    MainTabShell()
                } else {
                    OnboardingFlowView()
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                routeDestination(route)
            }
        }
        .fullScreenCover(item: $router.paywallPresentation) { presentation in
            PaywallView(plan: .monthly, source: presentation.source)
                .environment(store)
                .environment(router)
                .ignoresSafeArea()
        }
        .environment(store)
        .environment(router)
        .preferredColorScheme(.light)
        .task {
            _ = try? await OpenAIAvatarService().cachedAPIKey()
        }
    }

    @ViewBuilder
    private func routeDestination(_ route: AppRoute) -> some View {
        switch route {
        case .paywall:
            PaywallView(plan: .monthly, source: .onboarding)
        case .premiumPaywall:
            PaywallView(plan: .monthly, source: .inApp)
        case .monthlyPaywall:
            PaywallView(plan: .monthly, source: .onboarding)
        case .addItemAccess:
            AccessExplainerView(kind: .clothing)
        case .cameraPermission(let kind):
            CameraPermissionView(kind: kind)
        case .cameraCapture(let kind):
            CameraCaptureView(kind: kind)
        case .itemAnalyze:
            ItemAnalyzeView()
        case .itemProcessing:
            ProcessingView(topBarTitle: "Photo", title: "Analyze Clothing Item", subtitle: "Our AI identifies the garment and removes the background for your wardrobe.", progress: 0.5)
        case .itemEditor(let item):
            ItemEditorView(item: item)
        case .itemDetail(let item):
            WardrobeItemDetailView(item: item)
        case .wardrobeCollections:
            CollectionPickerView(kind: .wardrobe, mode: .browse)
        case .collectionDetail(let collection):
            CollectionDetailView(collection: collection)
        case .createCollection:
            CollectionEditorView()
        case .addToCollection:
            CollectionPickerView(kind: .wardrobe, mode: .select)
        case .createOutfit:
            CreateOutfitView()
        case .useWeather:
            UseWeatherView()
        case .outfitProcessing(let request):
            OutfitProcessingView(request: request)
        case .outfitReview(let outfits):
            OutfitReviewView(outfits: outfits)
        case .outfitDetail(let outfit):
            OutfitDetailView(outfit: outfit)
        case .outfitCollections:
            CollectionPickerView(kind: .outfit, mode: .browse)
        case .avatarOnboarding:
            MixMatchOnboardingView()
        case .avatarCapture:
            CameraCaptureView(kind: .avatar)
        case .avatarProcessing:
            ProcessingView(topBarTitle: "Create Your AI Avatar", title: "Create Your AI Avatar", subtitle: "Upload your photos to generate a personalized fashion avatar.", progress: 0.5)
        case .avatarEditor:
            AvatarEditorView()
        case .avatarDetail(let avatar):
            AvatarDetailView(avatar: avatar)
        case .mixAndMatch:
            MixAndMatchView()
        case .editProfile:
            EditProfileView()
        case .profileAccess:
            CameraPermissionView(kind: .profile)
        case .profileCrop:
            ProfileCropView()
        }
    }
}

struct MainTabShell: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var didPresentStartupPaywall = false

    var body: some View {
        @Bindable var router = router

        GeometryReader { proxy in
            let scale = proxy.size.width / OutfitTheme.Layout.referenceWidth
            let tabBarHeight = OutfitTheme.Layout.tabBarHeight * scale
            let regularTabBarY = 795 * scale
            let compactTabBarY = proxy.size.height - tabBarHeight / 2 - 8
            let tabBarY = smallDeviceAdaptation.value(regular: regularTabBarY, small: compactTabBarY)

            ZStack(alignment: .topLeading) {
                Group {
                    switch router.selectedTab {
                    case .home:
                        HomeView()
                    case .wardrobe:
                        WardrobeView()
                    case .outfits:
                        OutfitsView()
                    case .avatar:
                        AvatarView()
                    case .profile:
                        ProfileView()
                    }
                }

                BottomTabBar(selectedTab: $router.selectedTab)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: 393 * scale, height: 70 * scale, alignment: .topLeading)
                    .position(x: proxy.size.width / 2, y: tabBarY)

                if let accessPresentation = router.accessPresentation {
                    AccessExplainerView(kind: accessPresentation.kind)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .ignoresSafeArea()
            .animation(.spring(response: 0.36, dampingFraction: 0.9), value: router.accessPresentation?.id)
        }
        .ignoresSafeArea()
        .task {
            guard store.didCompleteOnboarding else { return }
            guard !store.hasPremiumAccess else { return }
            guard !didPresentStartupPaywall else { return }
            guard router.path.isEmpty else { return }

            didPresentStartupPaywall = true
            router.presentPaywall(source: .inApp)
        }
    }
}
