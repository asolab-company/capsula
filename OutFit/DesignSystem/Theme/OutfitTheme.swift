import SwiftUI

enum OutfitTheme {
    enum Color {
        static let appBackground = SwiftUI.Color(hex: 0xF3F3F3)
        static let darkBackup = SwiftUI.Color(hex: 0x262425)
        static let primaryText = SwiftUI.Color(hex: 0x222222)
        static let secondaryText = SwiftUI.Color(hex: 0xA5A5A5)
        static let border = SwiftUI.Color(hex: 0xECECEC)
        static let chip = SwiftUI.Color(hex: 0xDDDDDD)
        static let field = SwiftUI.Color.white
        static let black = SwiftUI.Color.black
        static let accentPink = SwiftUI.Color(hex: 0xFCA2FF)
        static let accentRose = SwiftUI.Color(hex: 0xFF5B8C)
        static let accentOrange = SwiftUI.Color(hex: 0xFF9500)
        static let accentMint = SwiftUI.Color(hex: 0x01FF8D)
        static let accentGreen = SwiftUI.Color(hex: 0x79F2A2)
    }

    enum Spacing {
        static let screen: CGFloat = 18
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let section: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let pill: CGFloat = 32
        static let menu: CGFloat = 40
    }

    enum Layout {
        static let referenceWidth: CGFloat = 393
        static let referenceHeight: CGFloat = 852
        static let contentX: CGFloat = 18
        static let contentWidth: CGFloat = 356
        static let topGradientHeight: CGFloat = 134
        static let tabBarHeight: CGFloat = 70
        static let tabBarInnerHeight: CGFloat = 62
        static let cardWidth: CGFloat = 116
        static let cardHeight: CGFloat = 140
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension Font {
    static func outfitHero(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .heavy)
    }

    static func outfitBody(_ size: CGFloat = 14, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func outfitMontserrat(_ size: CGFloat, weight: Weight = .medium) -> Font {
        .system(size: size, weight: weight)
    }
}
