import SwiftUI
import UIKit

struct AppCanvas<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / OutfitTheme.Layout.referenceWidth
            let smallDeviceAdaptation = SmallDeviceAdaptation(screenSize: proxy.size)

            ZStack(alignment: .topLeading) {
                OutfitTheme.Color.appBackground
                    .ignoresSafeArea()

                ZStack(alignment: .topLeading) {
                    OutfitTheme.Color.appBackground
                        .frame(width: 393, height: 852)
                    content
                }
                .frame(width: 393, height: 852, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: max(proxy.size.height, 852 * scale), alignment: .topLeading)
                .environment(\.smallDeviceAdaptation, smallDeviceAdaptation)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension View {
    func appFrame(
        x: CGFloat,
        y: CGFloat,
        w: CGFloat,
        h: CGFloat,
        alignment: Alignment = .center,
        adjustsTopInset: Bool = true
    ) -> some View {
        modifier(AppFrameModifier(x: x, y: y, w: w, h: h, alignment: alignment, adjustsTopInset: adjustsTopInset))
    }
}

private struct AppFrameModifier: ViewModifier {
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation

    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
    let alignment: Alignment
    let adjustsTopInset: Bool

    func body(content: Content) -> some View {
        let adjustedY = adjustsTopInset ? smallDeviceAdaptation.topAdjustedY(y) : y
        let adjustedHeight = adjustsTopInset ? smallDeviceAdaptation.topAdjustedHeight(y: y, height: h) : h

        content
            .frame(width: w, height: adjustedHeight, alignment: alignment)
            .position(x: x + w / 2, y: adjustedY + adjustedHeight / 2)
    }
}

struct AppTopFade: View {
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation

    var height: CGFloat = 134

    var body: some View {
        let adjustedHeight = smallDeviceAdaptation.topInsetHeight(height)

        LinearGradient(
            colors: [OutfitTheme.Color.appBackground, OutfitTheme.Color.appBackground.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 393, height: adjustedHeight)
        .allowsHitTesting(false)
    }
}

struct AppText: View {
    enum Role {
        case appTitle
        case section
        case body
        case secondary
        case small
        case tab
        case button
        case onboardingTitle
        case onboardingSubtitle
        case onboardingLegal
    }

    let value: String
    let role: Role
    var alignment: TextAlignment = .leading
    var color: Color?

    var body: some View {
        Text(value)
            .font(font)
            .foregroundStyle(color ?? defaultColor)
            .multilineTextAlignment(alignment)
            .lineSpacing(0)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var font: Font {
        switch role {
        case .appTitle:
            .outfitBody(24, weight: .bold)
        case .section:
            .outfitBody(16, weight: .semibold)
        case .body:
            .outfitBody(14, weight: .regular)
        case .secondary:
            .outfitBody(14, weight: .regular)
        case .small:
            .outfitBody(12, weight: .regular)
        case .tab:
            .outfitBody(10, weight: .medium)
        case .button:
            .outfitBody(16, weight: .medium)
        case .onboardingTitle:
            .outfitHero(24)
        case .onboardingSubtitle:
            .outfitMontserrat(14, weight: .medium)
        case .onboardingLegal:
            .outfitMontserrat(12, weight: .medium)
        }
    }

    private var defaultColor: Color {
        switch role {
        case .secondary, .small, .onboardingLegal:
            OutfitTheme.Color.secondaryText
        case .button:
            .white
        default:
            OutfitTheme.Color.primaryText
        }
    }
}

struct AppHeader: View {
    let title: String
    var subtitle: String?
    var trailing: AnyView?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                AppText(value: title, role: .appTitle)
                if let subtitle {
                    AppText(value: subtitle, role: .secondary)
                }
            }
            Spacer()
            trailing
        }
        .frame(width: 356, alignment: .topLeading)
    }
}

struct AppIcon: View {
    let name: String
    var size: CGFloat = 32
    var color: Color = .black

    var body: some View {
        Group {
            if let image = AssetResolver.image(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(color)
            } else {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.62, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
    }

    private var assetName: String {
        switch name {
        case "app_ic_ailogo":
            "app_ic_ai"
        case "weather":
            "06_rainyday_light_2"
        case "sparkles":
            "app_ic_ai"
        case "plus":
            "app_ic_add"
        case "hanger":
            "app_ic_wardrobe"
        case "chevron.left":
            "app_btn_back"
        case "chevron.right", "arrow.right", "arrow.triangle.2.circlepath":
            "app_ic_arrow"
        case "lock.fill":
            "app_ic_lock"
        case "trash", "trash.fill":
            "app_ic_delete"
        case "pencil":
            "app_ic_edit"
        case "camera.fill":
            "app_ic_camera"
        case "photo.fill":
            "app_btn_gallery"
        case "lightbulb.fill":
            "app_ic_tip"
        case "heart.fill":
            "app_ic_heart"
        case "suitcase.fill":
            "app_btn_category"
        case "tshirt.fill":
            "app_ic_shirt"
        case "checkmark", "checkmark.circle.fill":
            "app_ic_check"
        default:
            name
        }
    }

    private var systemName: String {
        switch name {
        case "app_ic_ai", "app_ic_ailogo": "sparkles"
        case "app_ic_add": "plus"
        case "app_btn_category": "suitcase.fill"
        case "app_btn_back": "chevron.left"
        case "app_ic_lock": "lock.fill"
        case "app_ic_check": "checkmark"
        case "app_ic_delete": "trash"
        case "app_ic_edit": "pencil"
        case "app_ic_camera": "camera.fill"
        case "app_ic_gallery": "photo.fill"
        case "app_ic_tip": "lightbulb.fill"
        case "app_ic_heart": "heart.fill"
        case "weather": "cloud.sun.fill"
        default: name.contains(".") ? name : "circle"
        }
    }
}

struct AppIconButton: View {
    let name: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            AppIcon(name: name, size: 32)
                .background(Color.white.opacity(0.001), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

struct AppPrimaryButton: View {
    let title: String
    var iconName: String?
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let iconName {
                    AppIcon(name: iconName, size: 18, color: .white)
                }
                AppText(value: title, role: .button)
            }
            .frame(width: 356, height: 56)
            .background(isEnabled ? Color.black : Color.black.opacity(0.22), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct AppSecondaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            AppText(value: title, role: .button, color: OutfitTheme.Color.secondaryText)
                .frame(width: 356, height: 50)
        }
        .buttonStyle(.plain)
    }
}

struct AppInputPill: View {
    var placeholder: String
    var text: Binding<String>? = nil
    var isAI = false
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let text {
                TextField(placeholder, text: text)
                    .font(.outfitBody(14))
                    .foregroundStyle(Color.black)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            } else {
                Button(action: { action?() }) {
                    HStack(spacing: 8) {
                        if isAI {
                            AppIcon(name: "app_ic_ai", size: 18)
                        }
                        AppText(value: placeholder, role: .secondary)
                        Spacer()
                        if isAI {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 32, height: 32)
                                .overlay(AppIcon(name: "app_ic_check", size: 14, color: .white))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, isAI ? 16 : 24)
        .padding(.trailing, 8)
        .frame(width: 356, height: 50)
        .background(Color.white, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(strokeStyle, lineWidth: 1)
        }
    }

    private var strokeStyle: some ShapeStyle {
        isAI
        ? AnyShapeStyle(LinearGradient(
            colors: [
                OutfitTheme.Color.accentPink,
                OutfitTheme.Color.accentRose,
                OutfitTheme.Color.accentOrange,
                OutfitTheme.Color.accentMint
            ],
            startPoint: .leading,
            endPoint: .trailing
        ))
        : AnyShapeStyle(OutfitTheme.Color.border)
    }
}

struct AppChip: View {
    let title: String
    var selected = false
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    label
                }
                .buttonStyle(.plain)
            } else {
                label
            }
        }
    }

    private var label: some View {
        AppText(value: title, role: .body, color: selected ? .white : .black)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(selected ? OutfitTheme.Color.secondaryText : OutfitTheme.Color.chip, in: Capsule())
    }
}

struct AppImageTile: View {
    let imageName: String
    var imageData: Data? = nil
    var width: CGFloat = 116
    var height: CGFloat = 140
    var showsBackground = true
    var action: (() -> Void)?

    private var resolvedImage: UIImage? {
        imageData.flatMap(UIImage.init(data:))
    }

    var body: some View {
        Button(action: { action?() }) {
            Group {
                if let image = resolvedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    OutfitImage(name: imageName)
                }
            }
                .padding(8)
                .frame(width: width, height: height)
                .background(showsBackground ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(OutfitTheme.Color.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(action != nil)
    }
}

struct AppAddTile: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color.black.opacity(0.32))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Color.black)
                    }
                AppText(value: title, role: .tab, color: .black)
            }
            .frame(width: 116, height: 140)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        OutfitTheme.Color.secondaryText,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

struct AppOutfitMosaic: View {
    let imageNames: [String]
    var width: CGFloat = 116
    var height: CGFloat = 140

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 2), spacing: 2) {
            ForEach(Array(imageNames.prefix(4).enumerated()), id: \.offset) { _, imageName in
                OutfitImage(name: imageName)
                    .padding(2)
                    .frame(height: (height - 2) / 2)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(OutfitTheme.Color.border, lineWidth: 1)
        }
    }
}

struct AppProgressCard: View {
    let count: Int

    private var progress: CGFloat {
        min(CGFloat(count) / 5, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 16) {
                OutfitImage(name: "app_ic_wardrobe", contentMode: .fit)
                    .frame(width: 56, height: 56)

                Text("Add at least 5 items to unlock automatic outfits")
                    .font(.outfitBody(14, weight: .medium))
                    .foregroundStyle(Color.black)
                    .frame(width: 205, alignment: .leading)

                Spacer(minLength: 0)
            }

            VStack(alignment: .trailing, spacing: 8) {
                Text("\(count)/5")
                    .font(.outfitBody(12, weight: .bold))
                    .foregroundStyle(Color.black)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: 0xA5A5A5))
                        Capsule()
                            .fill(Color.black)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(24)
        .frame(width: 356, height: 134)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AppStatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            AppText(value: label, role: .small, alignment: .center)
            AppText(value: value, role: .section, alignment: .center)
        }
        .frame(width: 116, height: 70)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct AppFeatureCard: View {
    let title: String
    let subtitle: String
    var iconName = "app_ic_home_feature_wardrobe"
    var locked = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            AppIcon(name: iconName, size: 24)
                .frame(width: 42, height: 42, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.outfitBody(14, weight: .bold))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .allowsTightening(true)
                Text(subtitle)
                    .font(.outfitBody(14, weight: .regular))
                    .foregroundStyle(Color.black)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if locked {
                AppIcon(name: "app_ic_lock", size: 16)
                    .frame(width: 24, height: 24)
            } else {
                Color.clear
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.leading, 24)
        .padding(.trailing, 32)
        .padding(.vertical, 22)
        .frame(width: 356)
        .frame(minHeight: 103)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct AppEmptyState: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 28)
                .fill(OutfitTheme.Color.border)
                .frame(width: 136, height: 136)
                .overlay(AppIcon(name: "app_ic_empty", size: 54, color: OutfitTheme.Color.secondaryText))
            AppText(value: title, role: .section, alignment: .center)
            AppText(value: subtitle, role: .secondary, alignment: .center)
                .frame(width: 280)
            AppPrimaryButton(title: buttonTitle, iconName: "app_ic_add", action: action)
                .padding(.top, 8)
        }
    }
}

struct AppBottomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.34))
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                .shadow(color: .white.opacity(0.75), radius: 1, y: -1)
                .appFrame(x: 19, y: 4, w: 356, h: 62)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 2) {
                            AppIcon(name: tab.appIconName, size: 32, color: selectedTab == tab ? .black : OutfitTheme.Color.secondaryText)
                            AppText(value: tab.title, role: .tab, alignment: .center, color: selectedTab == tab ? .black : OutfitTheme.Color.secondaryText)
                                .frame(height: 12)
                        }
                        .frame(width: 68, height: 54)
                    }
                    .buttonStyle(.plain)
                }
            }
            .appFrame(x: 27, y: 8, w: 340, h: 54)
        }
        .frame(width: 393, height: 70)
    }
}

extension AppTab {
    var appIconName: String {
        switch self {
        case .home: "app_ic_menu"
        case .wardrobe: "app_ic_menu_2"
        case .outfits: "app_ic_menu_4"
        case .avatar: "app_ic_menu_6"
        case .profile: "app_ic_menu_8"
        }
    }
}
