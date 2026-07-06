import SwiftUI

struct AppScaffold<Content: View>: View {
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation

    var topInset: CGFloat = 134
    var showsTabBarSpace = true
    @ViewBuilder var content: Content

    var body: some View {
        let adjustedTopInset = smallDeviceAdaptation.topInsetHeight(topInset)

        ZStack(alignment: .top) {
            OutfitTheme.Color.appBackground
                .ignoresSafeArea()

            content

            LinearGradient(
                colors: [OutfitTheme.Color.appBackground, OutfitTheme.Color.appBackground.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: adjustedTopInset)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ScreenHeader: View {
    let title: String
    let subtitle: String?
    var trailing: AnyView?

    init(title: String, subtitle: String? = nil, trailing: AnyView? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.outfitBody(24, weight: .bold))
                    .foregroundStyle(OutfitTheme.Color.primaryText)
                    .textCase(.none)

                if let subtitle {
                    Text(subtitle)
                        .font(.outfitBody(14))
                        .foregroundStyle(OutfitTheme.Color.secondaryText)
                }
            }

            Spacer()

            if let trailing {
                trailing
            }
        }
        .padding(.horizontal, OutfitTheme.Spacing.screen)
        .padding(.top, 17)
    }
}

struct WeatherBadge: View {
    var body: some View {
        VStack(spacing: 1) {
            OutfitImage(name: AssetName.rainy)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("+20°C")
                .font(.outfitBody(14))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
        }
    }
}

struct IconCircleButton: View {
    let systemName: String
    var size: CGFloat = 32
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(OutfitTheme.Color.black)
                AppIcon(name: systemName, size: size * 0.48, color: .white)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}
