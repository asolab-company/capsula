import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class SubscriptionStore {
    private(set) var monthlyProduct: Product?
    private(set) var hasActiveSubscription = false
    private(set) var isProcessing = false
    var errorMessage: String?

    func loadProducts() async {
        guard monthlyProduct == nil else { return }

        do {
            let products = try await Product.products(for: AppConstants.Subscriptions.productIDs)
            monthlyProduct = products.first { $0.id == AppConstants.Subscriptions.monthlyProductID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchaseMonthly() async -> Bool {
        errorMessage = nil
        await loadProducts()

        guard let monthlyProduct else {
            errorMessage = "Subscription is unavailable."
            return false
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await monthlyProduct.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return hasActiveSubscription
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async -> Bool {
        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return hasActiveSubscription
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshEntitlements() async {
        var isActive = false

        for await verification in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(verification) else { continue }
            guard AppConstants.Subscriptions.productIDs.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                continue
            }

            isActive = true
        }

        hasActiveSubscription = isActive
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
