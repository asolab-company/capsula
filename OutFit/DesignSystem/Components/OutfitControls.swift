import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var width: CGFloat? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    AppIcon(name: systemImage, size: 18, color: .white)
                }

                Text(title)
                    .font(.outfitBody(16, weight: .medium))
            }
            .foregroundStyle(Color.white)
            .frame(width: width, height: 56)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .background(OutfitTheme.Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.outfitBody(16, weight: .medium))
            .foregroundStyle(OutfitTheme.Color.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .buttonStyle(.plain)
    }
}

struct CategoryChip: View {
    let title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.outfitBody(14))
                .foregroundStyle(isSelected ? Color.white : Color.black)
                .padding(.horizontal, 16)
                .frame(height: 30)
                .background(isSelected ? OutfitTheme.Color.secondaryText : OutfitTheme.Color.chip, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct AIPromptField: View {
    var text: String = "Outfit for..."
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AppIcon(name: "app_ic_ai", size: 18)

                Text(text)
                    .font(.outfitBody(14))
                    .foregroundStyle(OutfitTheme.Color.secondaryText)

                Spacer()

                IconCircleButton(systemName: "arrow.right", size: 32, action: action)
                    .allowsHitTesting(false)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(height: 50)
            .background(Color.white, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [OutfitTheme.Color.accentPink, .orange.opacity(0.55), OutfitTheme.Color.accentGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
