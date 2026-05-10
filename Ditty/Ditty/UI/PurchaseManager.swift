import Foundation
import StoreKit

/// Single non-consumable that unlocks every non-free system.
/// Matches the product ID in `Ditty.storekit` and (eventually) App Store Connect.
enum ProductIDs {
    static let pro = "studio.otherdays.ditty.pro"
}

/// Systems available without paying. Tuned for breadth: a handheld, a console,
/// a home computer, and a UK classic — covers the looks most people recognise.
enum FreeSystems {
    static let ids: Set<String> = [
        "gb",            // Game Boy classic green
        "nes",           // NES, 4-color
        "c64.multi",     // C-64 Multicolor
        "zx"             // ZX Spectrum (standard)
    ]
    static func isFree(_ systemId: String) -> Bool { ids.contains(systemId) }
}

@MainActor
final class PurchaseManager: ObservableObject {

    @Published private(set) var proProduct: Product?
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            // Listen for transactions made outside the buy flow (Ask to Buy approvals, family sharing, etc.)
            for await result in Transaction.updates {
                if case let .verified(t) = result {
                    await self?.refreshEntitlements()
                    await t.finish()
                }
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func bootstrap() async {
        await loadProduct()
        await refreshEntitlements()
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [ProductIDs.pro])
            proProduct = products.first
        } catch {
            lastError = "Could not load product: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case let .verified(t) = result, t.productID == ProductIDs.pro, t.revocationDate == nil {
                unlocked = true
            }
        }
        isPro = unlocked
    }

    func buy() async {
        guard let product = proProduct else {
            lastError = "Product not available."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case let .verified(t) = verification {
                    await t.finish()
                    await refreshEntitlements()
                } else {
                    lastError = "Purchase could not be verified."
                }
            case .userCancelled:
                break
            case .pending:
                lastError = "Purchase pending approval."
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    #if DEBUG
    /// Debug-only: clear locally-cached entitlement state so the paywall
    /// flow can be exercised without revoking the actual sandbox/StoreKit
    /// transaction. Re-launching the app (or calling `bootstrap()`) will
    /// re-read entitlements and flip back to Pro if a real transaction
    /// still exists. To delete the underlying transaction, use Xcode's
    /// Debug → StoreKit → Manage Transactions and delete it there.
    func debugClearProState() {
        isPro = false
    }
    #endif
}
