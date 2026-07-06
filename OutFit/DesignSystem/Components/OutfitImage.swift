import SwiftUI
import UIKit

enum AssetResolver {
    static func image(named name: String) -> UIImage? {
        let candidates = candidateNames(for: name)
        for candidate in candidates {
            if let image = UIImage(named: candidate) {
                return image
            }
        }
        return nil
    }

    static func canonicalName(for name: String) -> String {
        switch name {
        case "app_ic_ailogo":
            "app_ic_ai"
        case "weather", "weather_rainy":
            "06_rainyday_light_2"
        default:
            name
        }
    }

    private static func candidateNames(for name: String) -> [String] {
        let canonical = canonicalName(for: name)
        let snake = canonical
            .lowercased()
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        var candidates: [String] = []
        for candidate in [name, canonical, snake] where !candidates.contains(candidate) {
            candidates.append(candidate)
        }
        return candidates
    }
}

struct OutfitImage: View {
    let name: String
    var contentMode: ContentMode = .fit

    var body: some View {
        if let image = AssetResolver.image(named: name) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            PlaceholderAsset(name: name)
        }
    }
}

private struct PlaceholderAsset: View {
    let name: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OutfitTheme.Radius.small)
                .fill(
                    LinearGradient(
                        colors: [Color.white, OutfitTheme.Color.border],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: fallbackIcon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
        }
    }

    private var fallbackIcon: String {
        if name.contains("avatar") { return "figure.stand" }
        if name.contains("weather") { return "cloud.sun.fill" }
        if name.contains("bag") { return "handbag.fill" }
        if name.contains("shoes") { return "shoeprints.fill" }
        return "tshirt.fill"
    }
}

#Preview {
    OutfitImage(name: AssetName.dress)
        .frame(width: 116, height: 140)
        .background(OutfitTheme.Color.appBackground)
}
