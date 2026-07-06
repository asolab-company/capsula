import SwiftUI

struct ImageTile: View {
    let imageName: String
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            OutfitImage(name: imageName)
                .padding(8)
                .frame(width: OutfitTheme.Layout.cardWidth, height: OutfitTheme.Layout.cardHeight)
                .background(Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: OutfitTheme.Radius.small)
                        .stroke(OutfitTheme.Color.border, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: OutfitTheme.Radius.small))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

struct AddTile: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(OutfitTheme.Color.secondaryText.opacity(0.55))
                    AppIcon(name: "app_ic_add", size: 22)
                }
                .frame(width: 30, height: 30)

                Text(title)
                    .font(.outfitBody(10, weight: .medium))
                    .foregroundStyle(Color.black)
            }
            .frame(width: OutfitTheme.Layout.cardWidth, height: OutfitTheme.Layout.cardHeight)
            .overlay {
                RoundedRectangle(cornerRadius: OutfitTheme.Radius.small)
                    .stroke(OutfitTheme.Color.secondaryText, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .buttonStyle(.plain)
    }
}

struct SectionStrip<Content: View>: View {
    let title: String
    var showAllAction: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.outfitBody(16, weight: .semibold))
                    .foregroundStyle(OutfitTheme.Color.primaryText)
                Spacer()
                if let showAllAction {
                    Button("Show all", action: showAllAction)
                        .font(.outfitBody(12, weight: .semibold))
                        .foregroundStyle(OutfitTheme.Color.secondaryText)
                        .buttonStyle(.plain)
                }
            }

            content
        }
    }
}

struct OutfitMosaic: View {
    let imageNames: [String]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 2), spacing: 2) {
            ForEach(Array(imageNames.prefix(4).enumerated()), id: \.offset) { _, imageName in
                OutfitImage(name: imageName)
                    .padding(2)
                    .frame(height: 69)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: OutfitTheme.Radius.small))
            }
        }
        .frame(width: OutfitTheme.Layout.cardWidth, height: OutfitTheme.Layout.cardHeight)
        .overlay {
            RoundedRectangle(cornerRadius: OutfitTheme.Radius.small)
                .stroke(OutfitTheme.Color.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: OutfitTheme.Radius.small))
    }
}

struct FeatureCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var isLocked = false

    var body: some View {
        HStack(spacing: 16) {
            AppIcon(name: systemImage, size: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.outfitBody(14, weight: .semibold))
                    .foregroundStyle(OutfitTheme.Color.primaryText)
                Text(subtitle)
                    .font(.outfitBody(14))
                    .foregroundStyle(OutfitTheme.Color.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isLocked {
                AppIcon(name: "app_ic_lock", size: 16)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 103)
        .background(Color.white, in: RoundedRectangle(cornerRadius: OutfitTheme.Radius.medium))
    }
}

struct EmptyStateCard: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    var systemImage = "hanger"
    var action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(OutfitTheme.Color.border)
                AppIcon(name: systemImage, size: 54, color: OutfitTheme.Color.secondaryText)
            }
            .frame(width: 136, height: 136)

            Text(title)
                .font(.outfitBody(18, weight: .bold))
                .foregroundStyle(OutfitTheme.Color.primaryText)

            Text(subtitle)
                .font(.outfitBody(14))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            PrimaryButton(title: buttonTitle, systemImage: "app_ic_add", action: action)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, OutfitTheme.Spacing.screen)
    }
}

struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.outfitBody(14, weight: .semibold))
                .foregroundStyle(OutfitTheme.Color.primaryText)
            Text(label)
                .font(.outfitBody(12))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(Color.white, in: RoundedRectangle(cornerRadius: OutfitTheme.Radius.medium))
    }
}
