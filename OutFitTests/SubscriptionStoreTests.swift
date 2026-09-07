/* SUBSCRIPTIONS_DISABLED_V1 — preserved for restoring subscriptions.
import XCTest
import SwiftUI
import StoreKit
import StoreKitTest
@testable import OutFit

@MainActor
final class SubscriptionStoreTests: XCTestCase {
    func testUnavailableProductStopsAfterBoundedRetries() async {
        var attempts = 0
        let store = SubscriptionStore(fetchProducts: { _ in
            attempts += 1
            return []
        }, retryDelay: {})
        await store.loadProducts()
        XCTAssertEqual(attempts, 3)
        XCTAssertNil(store.monthlyPriceDescription)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertFalse(store.isLoadingProducts)
    }

    func testPurchaseWithoutDisplayedProductDoesNotFetchOrPurchase() async {
        var attempts = 0
        let store = SubscriptionStore(fetchProducts: { _ in
            attempts += 1
            return []
        }, retryDelay: {})
        _ = await store.purchaseMonthly()
        XCTAssertEqual(attempts, 0, "Loading the price must be separate from purchasing")
        XCTAssertFalse(store.hasActiveSubscription)
    }

    func testCaptureUnavailablePaywall() async throws {
        let subscription = SubscriptionStore(fetchProducts: { _ in [] }, retryDelay: {})
        await subscription.loadProducts()
        try await capture("Paywall-unavailable", view: PaywallView()
            .environment(OutfitDataStore()).environment(AppRouter()).environment(subscription))
    }

    func testCaptureHomeAttributionFallback() async throws {
        try await capture("Home-weather-attribution", view: HomeView()
            .environment(OutfitDataStore()).environment(AppRouter()))
    }

    func testCaptureOutfitAttributionFallback() async throws {
        try await capture("Outfit-weather-attribution", view: CreateOutfitView()
            .environment(OutfitDataStore()).environment(AppRouter()))
    }

    func testConcurrentCallersWaitForOneRequest() async {
        var attempts = 0
        let store = SubscriptionStore(fetchProducts: { _ in
            attempts += 1
            try await Task.sleep(for: .milliseconds(50))
            return []
        }, retryDelay: {})
        let first = Task { await store.loadProducts() }
        while !store.isLoadingProducts { await Task.yield() }
        await store.loadProducts()
        XCTAssertFalse(store.isLoadingProducts, "Every caller must wait until the shared request finishes")
        XCTAssertNotNil(store.errorMessage)
        await first.value
        XCTAssertEqual(attempts, 3, "Concurrent callers must share one retry sequence")
    }

    func testNetworkFailureStopsAfterBoundedRetries() async {
        var attempts = 0
        let store = SubscriptionStore(fetchProducts: { _ in
            attempts += 1
            throw URLError(.notConnectedToInternet)
        }, retryDelay: {})
        await store.loadProducts()
        XCTAssertEqual(attempts, 3)
        XCTAssertFalse(store.isLoadingProducts)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertNil(store.monthlyPriceDescription)
    }
}

// Requires a working StoreKit Test session. On affected iOS 26.5 simulators,
// launch OutFit-Tests from Xcode to initialize the local StoreKit configuration.
@MainActor
final class StoreKitIntegrationTests: XCTestCase {
    private func product() async throws -> (SKTestSession, Product) {
        let session = try SKTestSession(configurationFileNamed: "TestSub")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        let products = try await Product.products(for: AppConstants.Subscriptions.productIDs)
        return (session, try XCTUnwrap(products.first))
    }

    func testLoadsLocalizedMonthlyPrice() async throws {
        let (session, product) = try await product()
        defer { session.clearTransactions() }
        let store = SubscriptionStore(fetchProducts: { _ in [product] }, retryDelay: {})
        await store.loadProducts()
        XCTAssertEqual(store.monthlyPriceDescription, "\(product.displayPrice) / month")
        XCTAssertFalse(store.isLoadingProducts)
        XCTAssertNil(store.errorMessage)
    }

    func testRetriesEmptyResponseAndRecoversPrice() async throws {
        let (session, product) = try await product()
        defer { session.clearTransactions() }
        var attempts = 0
        let store = SubscriptionStore(fetchProducts: { _ in
            attempts += 1
            return attempts == 1 ? [] : [product]
        }, retryDelay: {})
        await store.loadProducts()
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(store.monthlyProduct?.id, product.id)
        XCTAssertNil(store.errorMessage)
    }

    func testRetriesNetworkFailureAndRecoversPrice() async throws {
        let (session, product) = try await product()
        defer { session.clearTransactions() }
        var attempts = 0
        let store = SubscriptionStore(fetchProducts: { _ in
            attempts += 1
            if attempts < 3 { throw URLError(.notConnectedToInternet) }
            return [product]
        }, retryDelay: {})
        await store.loadProducts()
        XCTAssertEqual(attempts, 3)
        XCTAssertNotNil(store.monthlyPriceDescription)
        XCTAssertNil(store.errorMessage)
    }

    func testCapturePaywallWithLocalizedPrice() async throws {
        let (session, product) = try await product()
        defer { session.clearTransactions() }
        let subscription = SubscriptionStore(fetchProducts: { _ in [product] }, retryDelay: {})
        await subscription.loadProducts()
        try await capture("Paywall-local-price", view: PaywallView()
            .environment(OutfitDataStore()).environment(AppRouter()).environment(subscription))
    }
}

@MainActor
extension XCTestCase {
    fileprivate func capture<V: View>(_ name: String, view: V) async throws {
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first?.windows.first)
        let original = window.rootViewController
        defer { window.rootViewController = original }
        let host = UIHostingController(rootView: view.ignoresSafeArea().preferredColorScheme(.light))
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(500))
        host.view.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertGreaterThan(image.size.width, 0)
    }
}

*/

import XCTest
import SwiftUI
@testable import OutFit

@MainActor
final class FreeVersionTests: XCTestCase {
    func testAllFeaturesAvailableWithoutPurchase() {
        UserDefaults.standard.set(false, forKey: AppConstants.Storage.hasPremiumAccess)
        let store = OutfitDataStore()
        XCTAssertTrue(store.hasPremiumAccess)
        XCTAssertTrue(store.canCreateCollection)
        XCTAssertTrue(store.canCreateAvatar)
        XCTAssertTrue(store.canGenerateOutfitThisWeek)
        XCTAssertTrue(store.canAnalyzeClothingThisWeek)
        store.avatars = (0..<3).map { AvatarProfile(id: UUID(), name: "Test \($0)", imageName: "", imageData: nil) }
        XCTAssertTrue(store.canCreateAvatar)
    }

    func testPreviousUsageDoesNotLimitFreeRelease() {
        let defaults = UserDefaults.standard
        defaults.set(500, forKey: AppConstants.Storage.outfitGenerationWeekCount)
        defaults.set(500, forKey: AppConstants.Storage.clothingAnalysisWeekCount)
        let store = OutfitDataStore()
        for _ in 0..<50 {
            XCTAssertTrue(store.recordOutfitGenerationIfAllowed())
            XCTAssertTrue(store.recordClothingAnalysisIfAllowed())
        }
        XCTAssertTrue(store.canGenerateOutfitThisWeek)
        XCTAssertTrue(store.canAnalyzeClothingThisWeek)
    }

    func testResetAndRelaunchKeepFeaturesFree() {
        let store = OutfitDataStore()
        store.resetAllUserData()
        XCTAssertTrue(store.hasPremiumAccess)
        XCTAssertTrue(OutfitDataStore().hasPremiumAccess)
        XCTAssertTrue(OutfitDataStore().canCreateAvatar)
    }

    func testPaywallRoutesCannotOpen() {
        let router = AppRouter()
        router.presentPaywall(source: .onboarding)
        XCTAssertNil(router.paywallPresentation)
        router.presentPaywall(source: .inApp)
        XCTAssertNil(router.paywallPresentation)
        for route in [AppRoute.paywall, .premiumPaywall, .monthlyPaywall] {
            router.push(route)
            XCTAssertTrue(router.path.isEmpty)
            router.replaceLast(with: route)
            XCTAssertTrue(router.path.isEmpty)
        }
        router.push(.createOutfit)
        XCTAssertEqual(router.path, [.createOutfit])
    }

    func testHomeHasWeatherAttribution() async throws {
        let store = OutfitDataStore()
        store.resetAllUserData()
        try await capture("Free-Home", view: HomeView().environment(store).environment(AppRouter()))
    }

    func testProfileHasNoPurchaseControls() async throws {
        try await capture("Free-Profile", view: ProfileView().environment(OutfitDataStore()).environment(AppRouter()))
    }

    func testOutfitOptionsAreUnlocked() async throws {
        try await capture("Free-Outfit", view: CreateOutfitView().environment(OutfitDataStore()).environment(AppRouter()))
    }

    func testAvatarScreenIsAvailable() async throws {
        try await capture("Free-Avatar", view: AvatarView().environment(OutfitDataStore()).environment(AppRouter()))
    }

    func testMainScreenDoesNotPresentPaywall() async throws {
        let store = OutfitDataStore()
        store.didCompleteOnboarding = true
        let router = AppRouter()
        try await capture("Free-Main", view: MainTabShell().environment(store).environment(router))
        XCTAssertNil(router.paywallPresentation)
    }

    private func capture<V: View>(_ name: String, view: V) async throws {
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first?.windows.first)
        let original = window.rootViewController
        defer { window.rootViewController = original }
        let host = UIHostingController(rootView: view.ignoresSafeArea().preferredColorScheme(.light))
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(500))
        host.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
