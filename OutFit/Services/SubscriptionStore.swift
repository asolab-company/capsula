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

    @ObservationIgnored private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.capsula.wardrobe",
        category: "StoreKit"
    )
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    var monthlyPriceDescription: String? {
        monthlyProduct.map { "\($0.displayPrice) / month" }
    }

    func start() async {
        observeTransactionUpdates()
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts(forceReload: Bool = false) async {
        guard !isLoadingProducts else { return }
        if monthlyProduct != nil, !forceReload {
            return
        }

        isLoadingProducts = true
        errorMessage = nil
        defer { isLoadingProducts = false }

        do {
            let requestedIDs = AppConstants.Subscriptions.productIDs
            let products = try await Product.products(for: requestedIDs)
            monthlyProduct = products.first { $0.id == AppConstants.Subscriptions.monthlyProductID }

            guard monthlyProduct != nil else {
                logger.error(
                    "App Store returned no matching subscription. Requested: \(requestedIDs.joined(separator: ","), privacy: .public); returned: \(products.map(\.id).joined(separator: ","), privacy: .public)"
                )
                errorMessage = "We couldn’t load subscription options from the App Store. Please check your connection and try again."
                return
            }

            logger.info(
                "Loaded subscription \(AppConstants.Subscriptions.monthlyProductID, privacy: .public)."
            )
        } catch {
            monthlyProduct = nil
            logger.error("Product loading failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "We couldn’t connect to the App Store. Please check your connection and try again."
        }
    }

    func purchaseMonthly() async -> SubscriptionPurchaseOutcome {
        guard !isProcessing else { return .failed }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        if monthlyProduct == nil {
            await loadProducts(forceReload: true)
        }

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

                // A verified transaction is authoritative. currentEntitlements can briefly
                // lag immediately after the purchase finishes.
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
            logger.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
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
            logger.error("Restore failed: \(error.localizedDescription, privacy: .public)")
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
        logger.info("Premium entitlement active: \(isActive, privacy: .public)")
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

                do {
                    let transaction = try self.checkVerified(verification)
                    await transaction.finish()
                } catch {
                    self.logger.error("Transaction verification failed: \(error.localizedDescription, privacy: .public)")
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
