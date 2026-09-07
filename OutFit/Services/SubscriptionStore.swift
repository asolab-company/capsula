/* SUBSCRIPTIONS_DISABLED_V1 — preserved for restoring subscriptions.
import Foundation
import Observation
import OSLog
import StoreKit

enum SubscriptionPurchaseOutcome {
    case purchased
    case pending
    case cancelled
    case failed
}

enum SubscriptionRestoreOutcome {
    case restored
    case noActiveSubscription
    case failed
}

@MainActor
@Observable
final class SubscriptionStore {
    private(set) var monthlyProduct: Product?
    private(set) var hasActiveSubscription = false
    private(set) var isLoadingProducts = false
    private(set) var isProcessing = false
    var errorMessage: String?

    @ObservationIgnored private var productLoadingTask: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "com.capsula.wardrobe", category: "Subscriptions")
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    @ObservationIgnored private let fetchProducts: ([String]) async throws -> [Product]
    @ObservationIgnored private let retryDelay: () async throws -> Void

    init(
        fetchProducts: @escaping ([String]) async throws -> [Product] = { try await Product.products(for: $0) },
        retryDelay: @escaping () async throws -> Void = { try await Task.sleep(for: .seconds(1)) }
    ) {
        self.fetchProducts = fetchProducts
        self.retryDelay = retryDelay
    }

    var monthlyPriceDescription: String? {
        monthlyProduct.map { "\($0.displayPrice) / month" }
    }

    func start() async {
        observeTransactionUpdates()
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts(forceReload: Bool = false) async {
        // App startup and the paywall share the same request, and both await its result.
        if let productLoadingTask {
            await productLoadingTask.value
            return
        }
        guard monthlyProduct == nil || forceReload else { return }

        isLoadingProducts = true
        errorMessage = nil
        let task = Task {
            defer {
                isLoadingProducts = false
                productLoadingTask = nil
            }
            await fetchProductsWithRetry()
        }
        productLoadingTask = task
        await task.value
    }

    private func fetchProductsWithRetry() async {
        let requestedIDs = AppConstants.Subscriptions.productIDs
        for attempt in 1...3 {
            do {
                let products = try await fetchProducts(requestedIDs)
                if let product = products.first(where: {
                    $0.id == AppConstants.Subscriptions.monthlyProductID &&
                    $0.type == .autoRenewable &&
                    $0.subscription?.subscriptionPeriod.unit == .month &&
                    $0.subscription?.subscriptionPeriod.value == 1
                }) {
                    monthlyProduct = product
                    errorMessage = nil
                    return
                }
                logger.error("Monthly product unavailable. Attempt \(attempt); bundle: \(Bundle.main.bundleIdentifier ?? "unknown", privacy: .public); requested: \(requestedIDs.joined(separator: ","), privacy: .public); returned: \(products.map(\.id).joined(separator: ","), privacy: .public)")
            } catch is CancellationError {
                return
            } catch {
                logger.error("StoreKit product request failed on attempt \(attempt): \(String(describing: error), privacy: .public)")
            }

            if attempt < 3 {
                do { try await retryDelay() }
                catch { return }
            }
        }
        errorMessage = "We couldn’t load the subscription price from the App Store. Please try again in a moment."
    }

    func purchaseMonthly() async -> SubscriptionPurchaseOutcome {
        guard !isProcessing else { return .failed }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        guard let monthlyProduct else {
            if errorMessage == nil {
                errorMessage = "This subscription is currently unavailable. Please try again later."
            }
            return .failed
        }

        do {
            let result = try await monthlyProduct.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                let transactionGrantsAccess = isActiveSubscription(transaction)
                await transaction.finish()
                await refreshEntitlements()

                guard transactionGrantsAccess else {
                    errorMessage = "Your purchase completed, but access could not be confirmed. Use Restore Purchases or try again."
                    return .failed
                }

                if !hasActiveSubscription {
                    hasActiveSubscription = true
                }
                return .purchased

            case .pending:
                return .pending

            case .userCancelled:
                return .cancelled

            @unknown default:
                errorMessage = "The App Store returned an unsupported purchase result."
                return .failed
            }
        } catch {
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    func restorePurchases() async -> SubscriptionRestoreOutcome {
        guard !isProcessing else { return .failed }

        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return hasActiveSubscription ? .restored : .noActiveSubscription
        } catch {
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    func refreshEntitlements() async {
        var isActive = false

        for await verification in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(verification) else { continue }
            if isActiveSubscription(transaction) {
                isActive = true
                break
            }
        }

        hasActiveSubscription = isActive
    }

    private func isActiveSubscription(_ transaction: Transaction) -> Bool {
        guard AppConstants.Subscriptions.productIDs.contains(transaction.productID) else {
            return false
        }
        guard transaction.revocationDate == nil else {
            return false
        }
        if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
            return false
        }
        return true
    }

    private func observeTransactionUpdates() {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await verification in Transaction.updates {
                guard let self else { return }

                if let transaction = try? self.checkVerified(verification) {
                    await transaction.finish()
                }

                await self.refreshEntitlements()
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionPurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

private enum SubscriptionPurchaseError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            "We could not verify this purchase."
        }
    }
}

*/
