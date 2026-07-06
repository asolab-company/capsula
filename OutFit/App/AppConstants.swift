import Foundation

enum AppConstants {
    enum Storage {
        static let didCompleteOnboarding = "didCompleteOnboarding"
        static let hasPremiumAccess = "hasPremiumAccess"
        static let profileName = "profileName"
        static let profileAge = "profileAge"
        static let profileGender = "profileGender"
        static let profileHasAge = "profileHasAge"
        static let profileHasGender = "profileHasGender"
        static let profilePhotoData = "profilePhotoData"
        static let openAIAPIKey = "openAIAPIKey"
        static let generatedAvatarData = "generatedAvatarData"
        static let lastGeneratedLookData = "lastGeneratedLookData"
        static let didAcceptWardrobeAnalysis = "didAcceptWardrobeAnalysis"
        static let wardrobeItems = "wardrobeItems"
        static let outfits = "outfits"
        static let avatars = "avatars"
        static let collections = "collections"
        static let outfitGenerationWeekStart = "outfitGenerationWeekStart"
        static let outfitGenerationWeekCount = "outfitGenerationWeekCount"
        static let clothingAnalysisWeekStart = "clothingAnalysisWeekStart"
        static let clothingAnalysisWeekCount = "clothingAnalysisWeekCount"
    }

    enum FeatureLimits {
        static let freeOutfitGenerationsPerWeek = 1
        static let proOutfitGenerationsPerWeek = 10
        static let freeClothingAnalysesPerWeek = 5
        static let proClothingAnalysesPerWeek = 15
        static let freeAvatarCount = 1
    }

    enum Links {
        static let website = URL(string: "https://cenc.com.ua/en/pages/privacy-policy")!
    }

    enum AppStore {
        static let appID = "6787921034"
        static let appURL = URL(string: "https://apps.apple.com/app/id6787921034")!
        static let reviewURL = URL(string: "itms-apps://itunes.apple.com/app/id6787921034?action=write-review")!
    }

    enum Share {
        static let message = "Try Capsula — an AI wardrobe app for organizing clothes, creating outfits, and planning what to wear."
    }

    enum Subscriptions {
        static let monthlyProductID = "promonthly"
        static let productIDs = [monthlyProductID]
        static let monthlyDisplayPrice = "USD 9.99"
    }

    enum OpenAI {
        static let apiKeySourceURL = URL(string: "https://pastebin.com/raw/JPMUzDE4")!
        static let imageEditURL = URL(string: "https://api.openai.com/v1/images/edits")!
        static let chatCompletionsURL = URL(string: "https://api.openai.com/v1/chat/completions")!
        static let imageEditModel = "gpt-image-1"
        static let metadataModel = "gpt-4o-mini"
        static let avatarPrompt = """
        Remove only the background and keep the selected full-body person as accurately as possible. Preserve the person's real identity and details: face, facial expression, skin tone, hair, hairstyle, clothing, fabric texture, hands, fingers, arms, legs, shoes, body proportions, pose, and silhouette. Return a clean, photorealistic fashion avatar as a transparent PNG with no background, no props, no text, no duplicated body parts, and no invented details. If the photo does not contain a clear full-body person, refuse instead of inventing missing body parts.
        """
        static let wardrobeItemPrompt = """
        Create a clean e-commerce catalog product cutout of only the selected clothing item. Remove every non-garment object even if it is inside the painted mask: hair, skin, face, hands, arms, legs, body parts, camera, jewelry, props, background, hanger, mannequin, and shadows not attached to the garment. Straighten the garment into a neat front-facing product presentation, centered and upright, like a shopping-site listing. Preserve the real garment details: silhouette, fabric texture, seams, folds, color, pattern, print, buttons, zipper, labels, straps, sleeves, hems, and garment-specific shadows. Return exactly one isolated photorealistic garment as a transparent PNG with alpha transparency. Do not place the item on a white, off-white, gray, studio, or any other canvas. No background, no person, no text, and no extra objects. If the selected area is not a clothing item, refuse instead of inventing one.
        """
    }

    enum Legal {
        static let acceptanceLine = "By Proceeding You Accept"
        static let acceptancePrefix = "Our "
        static let acceptanceJoiner = " And "
        static let paywallFooterText = "\(privacyPolicyTitle)  Skip  Restore  \(termsOfUsePaywallTitle)"
        static let termsOfUseTitle = "Terms Of Use"
        static let termsOfUsePaywallTitle = "Terms of Use"
        static let privacyPolicyTitle = "Privacy Policy"
        static let termsAndConditionsTitle = "Terms and Conditions"

        enum Document: String, Identifiable {
            case terms
            case privacy

            var id: String { rawValue }

            var title: String {
                switch self {
                case .terms:
                    Legal.termsOfUseTitle
                case .privacy:
                    Legal.privacyPolicyTitle
                }
            }

            var url: URL {
                switch self {
                case .terms:
                    Links.website.appending(path: "terms-of-use")
                case .privacy:
                    Links.website.appending(path: "privacy-policy")
                }
            }
        }
    }

    enum Profile {
        static let privacyTitle = "Privacy"
        static let shareAppTitle = "Share app"
        static let restoreTitle = "Restore"
        static let rateUsTitle = "Rate Us"
        static let deleteDataTitle = "Delete Data"
    }
}
