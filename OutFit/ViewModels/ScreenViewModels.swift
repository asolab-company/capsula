import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    let greeting = "Good day"
    let prompt = "What do you want to wear today?"

    let featureCards: [(title: String, subtitle: String, systemImage: String, isLocked: Bool)] = [
        ("Organize Your Wardrobe", "Keep all your clothes in one smart digital closet.", "app_ic_wardrobe", false),
/* SUBSCRIPTIONS_DISABLED_V1 — preserved for restoring subscriptions.
        ("Pack Smarter for Trips", "Generate packing lists and travel-ready outfits instantly.", "app_btn_category", true),
*/
        ("Pack Smarter for Trips", "Generate packing lists and travel-ready outfits instantly.", "app_btn_category", false),
/* SUBSCRIPTIONS_DISABLED_V1 — preserved for restoring subscriptions.
        ("Dress for the Weather", "Get outfit suggestions based on today’s forecast, temperature, and season.", "06_rainyday_light_2", true),
*/
        ("Dress for the Weather", "Get outfit suggestions based on today’s forecast, temperature, and season.", "06_rainyday_light_2", false),
/* SUBSCRIPTIONS_DISABLED_V1 — preserved for restoring subscriptions.
        ("Create Your AI Avatar", "See outfits on your personalized avatar before wearing them in real life.", "app_ic_ai", true)
*/
        ("Create Your AI Avatar", "See outfits on your personalized avatar before wearing them in real life.", "app_ic_ai", false)
    ]
}

@MainActor
@Observable
final class WardrobeViewModel {
    let categories = ClothingCategory.allCases

    func subtitle(for count: Int) -> String {
        "\(count) Items"
    }
}

@MainActor
@Observable
final class OutfitsViewModel {
    func subtitle(for count: Int) -> String {
        "\(count) Outfits"
    }
}

@MainActor
@Observable
final class AvatarViewModel {
    func subtitle(for count: Int) -> String {
        "\(count) Item"
    }
}

@MainActor
@Observable
final class ProfileViewModel {
    let settingsPrompt = "What do you want to wear today?"
    let generalRows = [
        (AppConstants.Profile.privacyTitle, "app_ic_set03"),
        (AppConstants.Profile.shareAppTitle, "app_ic_set02"),
/* SUBSCRIPTIONS_DISABLED_V1 — preserved for restoring subscriptions.
        (AppConstants.Profile.restoreTitle, "app_ic_change")
*/
    ]
    let legalRows = [
        (AppConstants.Legal.termsAndConditionsTitle, "app_ic_set01"),
        (AppConstants.Profile.rateUsTitle, "app_ic_heart"),
        (AppConstants.Profile.deleteDataTitle, "app_ic_delete")
    ]
}

@MainActor
@Observable
final class OnboardingViewModel {
    var page = 0
    var name = ""

    let legalText = "\(AppConstants.Legal.acceptanceLine)\n\(AppConstants.Legal.acceptancePrefix)\(AppConstants.Legal.termsOfUseTitle)\(AppConstants.Legal.acceptanceJoiner)\(AppConstants.Legal.privacyPolicyTitle)"
}
