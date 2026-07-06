import AVFoundation
import SafariServices
import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var subscriptionStore = SubscriptionStore()
    @State private var legalDocument: AppConstants.Legal.Document?
    @State private var isSharePresented = false
    @State private var alert: ProfileAlert?

    var body: some View {
        AppCanvas {
            AppTopFade()

            Text("Settings & Profile")
                .font(.outfitBody(24, weight: .bold))
                .foregroundStyle(OutfitTheme.Color.primaryText)
                .appFrame(x: 18, y: 66, w: 357, h: 30, alignment: .leading)

            let compactDeleteBottomPadding = smallDeviceAdaptation.value(regular: CGFloat(0), small: CGFloat(36))

            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    let isPremium = store.hasPremiumAccess
                    let premiumOffset: CGFloat = isPremium ? -80 : 0
                    let restoreOffset: CGFloat = isPremium ? -80 : 0
                    let compactPremiumGap = smallDeviceAdaptation.value(regular: CGFloat(0), small: isPremium ? 0 : 28)

                    if !isPremium {
                        ProfilePremiumButton {
                            router.presentPaywall(source: .inApp)
                        }
                        .appFrame(x: 18, y: 0, w: 357, h: 58)
                    }

                    ProfileSectionHeader(title: "Profile", actionTitle: "Edit", iconName: "app_ic_edit") {
                        router.push(.editProfile)
                    }
                    .appFrame(x: 18, y: 80 + premiumOffset + compactPremiumGap, w: 357, h: 22, alignment: .leading)

                    ProfileSummaryCard(
                        profile: store.profile,
                        hasAge: store.profileHasAge,
                        hasGender: store.profileHasGender,
                        profilePhotoData: store.profilePhotoData,
                        avatar: store.avatars.first
                    ) {
                        openProfileCameraFlow()
                    }
                    .appFrame(x: 18, y: 115 + premiumOffset + compactPremiumGap, w: 357, h: 90)

                    HStack(spacing: 6) {
                        ProfileStatTile(iconName: "app_ic_category", value: "\(store.wardrobeItems.count)", label: "Clothing")
                        ProfileStatTile(
                            iconName: "app_ic_category_2",
                            value: "\(store.outfits.count)",
                            label: "Outfits",
                            isLocked: !store.hasPremiumAccess
                        ) {
                            router.presentPaywall(source: .inApp)
                        }
                        ProfileStatTile(
                            iconName: "app_ic_heart",
                            value: "\(store.outfits.filter(\.isFavorite).count)",
                            label: "Favorites",
                            isLocked: !store.hasPremiumAccess
                        ) {
                            router.presentPaywall(source: .inApp)
                        }
                    }
                    .appFrame(x: 18, y: 214 + premiumOffset + compactPremiumGap, w: 357, h: 100, alignment: .leading)

                    ProfileSectionHeader(title: "Support & Legal")
                        .appFrame(x: 18, y: 342 + premiumOffset + compactPremiumGap, w: 357, h: 22, alignment: .leading)

                    ProfileSettingsRow(title: AppConstants.Profile.privacyTitle, iconName: "app_ic_set06") {
                        legalDocument = .privacy
                    }
                    .appFrame(x: 18, y: 377 + premiumOffset + compactPremiumGap, w: 357, h: 70)

                    ProfileSettingsRow(title: AppConstants.Legal.termsAndConditionsTitle, iconName: "app_ic_set03") {
                        legalDocument = .terms
                    }
                    .appFrame(x: 18, y: 457 + premiumOffset + compactPremiumGap, w: 357, h: 70)

                    ProfileSectionHeader(title: "General")
                        .appFrame(x: 18, y: 558 + premiumOffset + compactPremiumGap, w: 357, h: 22, alignment: .leading)

                    ProfileSettingsRow(title: AppConstants.Profile.shareAppTitle, iconName: "app_ic_set05") {
                        isSharePresented = true
                    }
                        .appFrame(x: 18, y: 591 + premiumOffset + compactPremiumGap, w: 357, h: 70)

                    ProfileSettingsRow(title: AppConstants.Profile.rateUsTitle, iconName: "app_ic_set02") {
                        openURL(AppConstants.AppStore.reviewURL)
                    }
                        .appFrame(x: 18, y: 671 + premiumOffset + compactPremiumGap, w: 357, h: 70)

                    if !isPremium {
                        ProfileSettingsRow(title: AppConstants.Profile.restoreTitle, iconName: "app_ic_set04") {
                            Task {
                                await restorePurchases()
                            }
                        }
                            .appFrame(x: 18, y: 751 + premiumOffset + compactPremiumGap, w: 357, h: 70)
                    }

                    ProfileSettingsRow(title: AppConstants.Profile.deleteDataTitle, iconName: "app_ic_set01", iconColor: Color(hex: 0xFF4B4B)) {
                        deleteAllData()
                    }
                        .appFrame(x: 18, y: 831 + premiumOffset + restoreOffset + compactPremiumGap, w: 357, h: 70)
                }
                .frame(width: 393, height: (store.hasPremiumAccess ? 764 : 924) + compactDeleteBottomPadding)
                .padding(.bottom, smallDeviceAdaptation.scrollBottomPadding() + compactDeleteBottomPadding)
            }
            .appFrame(
                x: 0,
                y: smallDeviceAdaptation.underHeaderY(121),
                w: 393,
                h: smallDeviceAdaptation.underHeaderHeight(731),
                alignment: .topLeading
            )
        }
        .sheet(item: $legalDocument) { document in
            ProfileSafariLegalView(url: document.url)
                .ignoresSafeArea()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isSharePresented) {
            ProfileShareSheet(activityItems: [AppConstants.Share.message, AppConstants.AppStore.appURL])
                .ignoresSafeArea()
        }
        .alert(item: $alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func restorePurchases() async {
        if await subscriptionStore.restorePurchases() {
            store.hasPremiumAccess = true
            alert = ProfileAlert(title: "Restored", message: "Your subscription has been restored.")
        } else if let errorMessage = subscriptionStore.errorMessage {
            alert = ProfileAlert(title: "Restore Failed", message: errorMessage)
        } else {
            alert = ProfileAlert(title: "No Subscription Found", message: "We could not find an active subscription to restore.")
        }
    }

    private func deleteAllData() {
        router.selectedTab = .home
        router.popToRoot()
        store.resetAllUserData()
    }

    private func openProfileCameraFlow() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            router.push(.cameraCapture(.profile))
        default:
            router.push(.profileAccess)
        }
    }
}

private struct ProfilePremiumButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AppIcon(name: "app_ic_pro", size: 22, color: .white)
                Text("Go to Premium")
                    .font(.outfitBody(16, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 357, height: 58)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var iconName: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.outfitBody(16, weight: .semibold))
                .foregroundStyle(OutfitTheme.Color.primaryText)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 7) {
                        if let iconName {
                            AppIcon(name: iconName, size: 18, color: OutfitTheme.Color.secondaryText)
                        }
                        Text(actionTitle)
                            .font(.outfitBody(12, weight: .medium))
                            .foregroundStyle(OutfitTheme.Color.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ProfileSummaryCard: View {
    let profile: ProfileSummary
    let hasAge: Bool
    let hasGender: Bool
    let profilePhotoData: Data?
    let avatar: AvatarProfile?
    var imageAction: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: imageAction) {
                ProfileAvatarBadge(profilePhotoData: profilePhotoData, avatar: avatar)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name.isEmpty ? "Profile" : profile.name)
                    .font(.outfitBody(20, weight: .semibold))
                    .foregroundStyle(OutfitTheme.Color.primaryText)
                    .lineLimit(1)
                if let detailsText {
                    Text(detailsText)
                        .font(.outfitBody(14, weight: .regular))
                        .foregroundStyle(OutfitTheme.Color.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(width: 357, height: 90)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 15))
    }

    private var detailsText: String? {
        var details: [String] = []
        if hasAge {
            details.append("\(profile.age) years old")
        }
        if hasGender {
            details.append(profile.gender)
        }
        return details.isEmpty ? nil : details.joined(separator: " ")
    }
}

private struct ProfileAvatarBadge: View {
    let profilePhotoData: Data?
    let avatar: AvatarProfile?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let profilePhotoData, let image = UIImage(data: profilePhotoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let imageData = avatar?.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let avatarImageName = avatar?.imageName, !avatarImageName.isEmpty {
                    OutfitImage(name: avatarImageName, contentMode: .fill)
                } else {
                    Circle()
                        .fill(OutfitTheme.Color.border)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(OutfitTheme.Color.secondaryText)
                        }
                }
            }
            .frame(width: 62, height: 62)
            .clipShape(Circle())

            OutfitImage(name: "app_btn_change", contentMode: .fit)
                .frame(width: 24, height: 24)
                .offset(x: 2, y: -1)
        }
    }
}

private struct ProfileStatTile: View {
    let iconName: String
    let value: String
    let label: String
    var isLocked = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 6) {
                AppIcon(name: iconName, size: 22, color: OutfitTheme.Color.secondaryText)
                    .frame(height: 28)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black)
                } else {
                    Text(value)
                        .font(.outfitBody(14, weight: .semibold))
                        .foregroundStyle(Color.black)
                }
                Text(label)
                    .font(.outfitBody(12, weight: .regular))
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
            }
            .frame(width: 115, height: 100)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!isLocked)
    }
}

private struct ProfileSettingsRow: View {
    let title: String
    let iconName: String
    var iconColor: Color = .black
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                AppIcon(name: iconName, size: 32, color: iconColor)
                    .frame(width: 34, height: 34)
                Text(title)
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.black)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(OutfitTheme.Color.secondaryText)
            }
            .padding(.leading, 20)
            .padding(.trailing, 24)
            .frame(width: 357, height: 70)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileSafariLegalView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct ProfileShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ProfileAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct EditProfileView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var name = ""
    @State private var age: Int?
    @State private var gender: String?
    @State private var activePicker: EditProfilePicker?
    @FocusState private var isNameFocused: Bool

    private let genders = ["Male", "Female", "Another"]
    private let ages = Array(12...80)

    var body: some View {
        AppCanvas {
            EditProfileTopBar()
                .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)

            EditProfileAvatar(profilePhotoData: store.profilePhotoData, avatar: store.avatars.first) {
                isNameFocused = false
                activePicker = nil
                openProfileCameraFlow()
            }
                .appFrame(
                    x: 168,
                    y: smallDeviceAdaptation.value(regular: CGFloat(150), small: CGFloat(126)),
                    w: 58,
                    h: 58
                )

            EditProfileTextField(text: $name, isFocused: $isNameFocused)
                .appFrame(x: 18, y: 248, w: 357, h: 50)

            Text("Gender")
                .font(.outfitBody(16, weight: .semibold))
                .foregroundStyle(OutfitTheme.Color.primaryText)
                .appFrame(x: 18, y: 340, w: 150, h: 22, alignment: .leading)

            EditProfileSelectionPill(title: gender ?? "None") {
                isNameFocused = false
                togglePicker(.gender)
            }
                .appFrame(x: 300, y: 336, w: 75, h: 30)

            if activePicker == .gender {
                EditProfileWheelPicker(selection: genderBinding, values: genders) { value in
                    value
                }
                    .appFrame(x: 18, y: 378, w: 357, h: 112)
            }

            Text("Age")
                .font(.outfitBody(16, weight: .semibold))
                .foregroundStyle(OutfitTheme.Color.primaryText)
                .appFrame(x: 18, y: ageRowY, w: 100, h: 22, alignment: .leading)

            EditProfileSelectionPill(title: age.map { "\($0) Years" } ?? "None") {
                isNameFocused = false
                togglePicker(.age)
            }
                .appFrame(x: 291, y: ageRowY - 4, w: 84, h: 30)

            if activePicker == .age {
                EditProfileAgeWheelPicker(selection: ageBinding, values: ages)
                    .appFrame(x: 112, y: ageRowY + 38, w: 170, h: 112)
            }

            EditProfileSaveButton(isEnabled: canSave) {
                saveProfile()
            }
                .appFrame(x: 18, y: buttonsY, w: 356, h: 56)

            EditProfileDeleteButton {
                deleteProfile()
            }
                .appFrame(x: 18, y: buttonsY + 72, w: 356, h: 56)
        }
        .onAppear {
            name = store.profile.name
            age = store.profileHasAge ? store.profile.age : nil
            gender = store.profileHasGender ? store.profile.gender : nil
        }
        .onChange(of: isNameFocused) { _, isFocused in
            if isFocused {
                activePicker = nil
            }
        }
    }

    private var ageRowY: CGFloat {
        activePicker == .gender ? 518 : 400
    }

    private var buttonsY: CGFloat {
        activePicker == .gender || activePicker == .age ? 648 : 506
    }

    private var canSave: Bool {
        age != nil && gender != nil
    }

    private var genderBinding: Binding<String> {
        Binding {
            gender ?? "Female"
        } set: { newValue in
            gender = newValue
        }
    }

    private var ageBinding: Binding<Int> {
        Binding {
            age ?? 25
        } set: { newValue in
            age = newValue
        }
    }

    private func saveProfile() {
        guard let age, let gender else { return }
        store.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.profile.age = age
        store.profile.gender = gender
        store.profileHasAge = true
        store.profileHasGender = true
        router.popToRoot()
    }

    private func deleteProfile() {
        store.profile.name = ""
        store.profile.age = 25
        store.profile.gender = "Female"
        store.profileHasAge = false
        store.profileHasGender = false
        store.profilePhotoData = nil
        router.popToRoot()
    }

    private func openProfileCameraFlow() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            router.push(.cameraCapture(.profile))
        default:
            router.push(.profileAccess)
        }
    }

    private func togglePicker(_ picker: EditProfilePicker) {
        switch picker {
        case .gender:
            gender = gender ?? "Female"
        case .age:
            age = age ?? 25
        }
        activePicker = activePicker == picker ? nil : picker
    }
}

private struct EditProfileTopBar: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: 12) {
            AppIconButton(name: "app_btn_back") {
                if router.path.isEmpty {
                    router.popToRoot()
                } else {
                    _ = router.path.popLast()
                }
            }
            Text("Profile")
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
            Spacer()
        }
        .frame(width: 356, height: 40)
    }
}

private struct EditProfileAvatar: View {
    let profilePhotoData: Data?
    let avatar: AvatarProfile?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let profilePhotoData, let image = UIImage(data: profilePhotoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else if let imageData = avatar?.imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else if let avatarImageName = avatar?.imageName, !avatarImageName.isEmpty {
                        OutfitImage(name: avatarImageName, contentMode: .fill)
                    } else {
                        Circle()
                            .fill(OutfitTheme.Color.border)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundStyle(OutfitTheme.Color.secondaryText)
                            }
                    }
                }
                .frame(width: 58, height: 58)
                .clipShape(Circle())

                OutfitImage(name: "app_btn_change", contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .offset(x: 3, y: 1)
            }
            .frame(width: 58, height: 58)
        }
        .buttonStyle(.plain)
    }
}

private struct EditProfileTextField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text("Enter the name*")
                    .font(.outfitBody(14, weight: .regular))
                    .foregroundStyle(Color(hex: 0xA5A5A5))
                    .padding(.horizontal, 28)
            }
            TextField("", text: $text)
                .font(.outfitBody(16, weight: .medium))
                .foregroundStyle(Color.black)
                .tint(Color.black)
                .padding(.horizontal, 28)
                .focused(isFocused)
        }
            .font(.outfitBody(16, weight: .medium))
            .frame(width: 357, height: 50)
            .background(Color.white, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(OutfitTheme.Color.border.opacity(0.8), lineWidth: 1)
            }
    }
}

private struct EditProfileSelectionPill: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: 0xA8A8A8), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct EditProfileWheelPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let title: (Value) -> String

    var body: some View {
        ZStack {
            Picker("", selection: $selection) {
                ForEach(values, id: \.self) { value in
                    Text(title(value))
                        .font(.outfitBody(23, weight: .regular))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: 357, height: 112)
            .clipped()

            VStack(spacing: 48) {
                Rectangle().fill(Color(hex: 0xA5A5A5)).frame(height: 1)
                Rectangle().fill(Color(hex: 0xA5A5A5)).frame(height: 1)
            }
            .allowsHitTesting(false)
        }
    }
}

private struct EditProfileAgeWheelPicker: View {
    @Binding var selection: Int
    let values: [Int]

    var body: some View {
        ZStack {
            Picker("", selection: $selection) {
                ForEach(values, id: \.self) { value in
                    Text("\(value)")
                        .font(.outfitBody(23, weight: .regular))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: 170, height: 112)
            .clipped()

            VStack(spacing: 48) {
                Rectangle().fill(Color(hex: 0xA5A5A5)).frame(height: 1)
                Rectangle().fill(Color(hex: 0xA5A5A5)).frame(height: 1)
            }
            .allowsHitTesting(false)
        }
    }
}

private enum EditProfilePicker {
    case gender
    case age
}

private struct EditProfileSaveButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                Text("Save")
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 356, height: 56, alignment: .center)
            .background(isEnabled ? Color.black : Color.black.opacity(0.24), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct EditProfileDeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                AppIcon(name: "app_ic_delete", size: 24, color: .black)
                Text("Delete")
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.black)
            }
            .frame(width: 356, height: 56, alignment: .center)
            .overlay {
                Capsule()
                    .stroke(Color.black, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ProfileCropView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var scale = 1.0
    @State private var lastScale = 1.0

    private let cropDiameter: CGFloat = 320

    private var cropAreaSize: CGSize {
        CGSize(
            width: 357,
            height: smallDeviceAdaptation.value(regular: CGFloat(440), small: CGFloat(342))
        )
    }

    private var cropAreaY: CGFloat {
        smallDeviceAdaptation.value(regular: CGFloat(150), small: CGFloat(126))
    }

    private var instructionY: CGFloat {
        cropAreaY + cropAreaSize.height + smallDeviceAdaptation.value(regular: CGFloat(28), small: CGFloat(18))
    }

    private var saveButtonY: CGFloat {
        smallDeviceAdaptation.bottomPinnedY(703, height: 56 + 69)
    }

    private var retakeButtonY: CGFloat {
        smallDeviceAdaptation.bottomPinnedY(772, height: 56)
    }

    var body: some View {
        AppCanvas {
            ProfileCropTopBar()
                .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)

            if let image {
                ProfileCropPhotoView(image: image, offset: offset, scale: scale, cropDiameter: cropDiameter)
                    .gesture(dragGesture(for: image).simultaneously(with: magnificationGesture(for: image)))
                    .appFrame(x: 18, y: cropAreaY, w: cropAreaSize.width, h: cropAreaSize.height)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(OutfitTheme.Color.border)
                    .overlay {
                        AppIcon(name: "app_ic_camera", size: 96, color: OutfitTheme.Color.secondaryText)
                    }
                    .appFrame(x: 18, y: cropAreaY, w: cropAreaSize.width, h: cropAreaSize.height)
            }

            Text("Move and scale your image to fit perfectly.")
                .font(.outfitBody(12, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .multilineTextAlignment(.center)
                .appFrame(x: 42, y: instructionY, w: 308, h: 20)

            CropSaveButton {
                if let image, let cropped = crop(image: image) {
                    store.profilePhotoData = cropped.pngData()
                    store.pendingProfilePhotoData = nil
                }
                closeAfterSaving()
            }
                .appFrame(x: 18, y: saveButtonY, w: 356, h: 56)

            CropRetakeButton {
                if router.path.last == .profileCrop {
                    router.pop()
                }
                router.push(.cameraCapture(.profile))
            }
                .appFrame(x: 18, y: retakeButtonY, w: 356, h: 56)
        }
    }

    private var image: UIImage? {
        guard let data = store.pendingProfilePhotoData ?? store.profilePhotoData else { return nil }
        return UIImage(data: data)
    }

    private func dragGesture(for image: UIImage) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposedOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(proposedOffset, scale: scale, image: image)
            }
            .onEnded { _ in
                offset = clampedOffset(offset, scale: scale, image: image)
                lastOffset = offset
            }
    }

    private func magnificationGesture(for image: UIImage) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposedScale = max(1, min(4, lastScale * value))
                scale = proposedScale
                offset = clampedOffset(offset, scale: proposedScale, image: image)
            }
            .onEnded { _ in
                offset = clampedOffset(offset, scale: scale, image: image)
                lastOffset = offset
                lastScale = scale
            }
    }

    private func clampedOffset(_ proposedOffset: CGSize, scale: Double, image: UIImage) -> CGSize {
        let displaySize = displayedImageSize(for: image, scale: scale)
        let maxX = max(0, (displaySize.width - cropDiameter) / 2)
        let maxY = max(0, (displaySize.height - cropDiameter) / 2)

        return CGSize(
            width: min(max(proposedOffset.width, -maxX), maxX),
            height: min(max(proposedOffset.height, -maxY), maxY)
        )
    }

    private func displayedImageSize(for image: UIImage, scale: Double) -> CGSize {
        let baseScale = max(cropAreaSize.width / image.size.width, cropAreaSize.height / image.size.height)
        return CGSize(
            width: image.size.width * baseScale * scale,
            height: image.size.height * baseScale * scale
        )
    }

    private func crop(image: UIImage) -> UIImage? {
        let imageSize = image.size
        let areaWidth = cropAreaSize.width
        let areaHeight = cropAreaSize.height
        let baseScale = max(areaWidth / imageSize.width, areaHeight / imageSize.height)
        let effectiveScale = baseScale * scale
        let displaySize = CGSize(width: imageSize.width * effectiveScale, height: imageSize.height * effectiveScale)
        let imageOrigin = CGPoint(
            x: areaWidth / 2 + offset.width - displaySize.width / 2,
            y: areaHeight / 2 + offset.height - displaySize.height / 2
        )
        let cropRect = CGRect(
            x: (areaWidth - cropDiameter) / 2,
            y: (areaHeight - cropDiameter) / 2,
            width: cropDiameter,
            height: cropDiameter
        )

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropDiameter, height: cropDiameter))
        return renderer.image { context in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: cropDiameter, height: cropDiameter))).addClip()
            image.draw(in: CGRect(
                x: imageOrigin.x - cropRect.minX,
                y: imageOrigin.y - cropRect.minY,
                width: displaySize.width,
                height: displaySize.height
            ))
            context.cgContext.setStrokeColor(UIColor.white.cgColor)
            context.cgContext.setLineWidth(0)
        }
    }

    private func closeAfterSaving() {
        if let editIndex = router.path.lastIndex(of: .editProfile) {
            router.path = Array(router.path.prefix(through: editIndex))
        } else {
            router.popToRoot()
        }
    }
}

private struct ProfileCropTopBar: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: 12) {
            AppIconButton(name: "app_btn_back") {
                if router.path.isEmpty {
                    router.popToRoot()
                } else {
                    _ = router.path.popLast()
                }
            }
            Text("Crop")
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
            Spacer()
        }
        .frame(width: 356, height: 40)
    }
}

private struct ProfileCropPhotoView: View {
    let image: UIImage
    let offset: CGSize
    let scale: Double
    let cropDiameter: CGFloat

    var body: some View {
        ZStack {
            movingImage

            CropOutsideOverlay(diameter: cropDiameter)
                .fill(Color.white.opacity(0.52), style: FillStyle(eoFill: true))

            movingImage
                .mask {
                    Circle()
                        .frame(width: cropDiameter, height: cropDiameter)
                }
        }
        .frame(width: 357, height: 440)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
    }

    private var movingImage: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: 357, height: 440)
    }
}

private struct CropOutsideOverlay: Shape {
    let diameter: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addEllipse(in: CGRect(
            x: rect.midX - diameter / 2,
            y: rect.midY - diameter / 2,
            width: diameter,
            height: diameter
        ))
        return path
    }
}

private struct CropSaveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                }
                Text("Save")
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 356, height: 56)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct CropRetakeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Retake")
                .font(.outfitBody(16, weight: .medium))
                .foregroundStyle(Color.black)
                .frame(width: 356, height: 56)
                .overlay {
                    Capsule()
                        .stroke(Color.black, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileView()
        .environment(OutfitDataStore())
        .environment(AppRouter())
}
