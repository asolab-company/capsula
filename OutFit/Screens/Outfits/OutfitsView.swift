import SwiftUI
import UIKit

struct OutfitsView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var selectedFilter: OutfitsFilter = .all
    @State private var isCreateOutfitPresented = false

    private var displayedOutfits: [OutfitSuggestion] {
        switch selectedFilter {
        case .all:
            store.outfits
        case .favorites:
            store.outfits.filter(\.isFavorite)
        }
    }

    private var favoriteOutfitsCount: Int {
        store.outfits.filter(\.isFavorite).count
    }

    var body: some View {
        AppCanvas {
            screenContent

            AppTopFade()
            AppHeader(
                title: "Outfits",
                subtitle: "\(store.outfits.count) Items",
                trailing: AnyView(headerActions)
            )
            .appFrame(x: 18, y: 70, w: 356, h: 52, alignment: .topLeading)

            HStack(spacing: 8) {
                AppChip(title: "All Outfits (\(store.outfits.count))", selected: selectedFilter == .all) {
                    selectedFilter = .all
                }
                AppChip(title: "Favorites (\(favoriteOutfitsCount))", selected: selectedFilter == .favorites) {
                    selectedFilter = .favorites
                }
            }
            .appFrame(x: 18, y: smallDeviceAdaptation.underHeaderY(136), w: 356, h: 30, alignment: .leading)
        }
        .sheet(isPresented: $isCreateOutfitPresented) {
            CreateOutfitSheetView { request in
                isCreateOutfitPresented = false
                router.push(.outfitProcessing(request))
            }
            .presentationDetents([.height(456)])
            .presentationDragIndicator(.hidden)
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        if displayedOutfits.isEmpty {
            if store.wardrobeItems.count < 5 {
                OutfitsUnlockCard(count: min(store.wardrobeItems.count, 5))
                    .appFrame(x: 18, y: smallDeviceAdaptation.underHeaderY(190), w: 356, h: 134)
                OutfitsEmptyState(isUnlocked: false) {
                    isCreateOutfitPresented = true
                }
                    .appFrame(x: 18, y: smallDeviceAdaptation.underHeaderY(378), w: 356, h: 250)
            } else {
                OutfitsEmptyState(isUnlocked: true) {
                    isCreateOutfitPresented = true
                }
                    .appFrame(x: 18, y: smallDeviceAdaptation.underHeaderY(258), w: 356, h: 300)
            }
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(116), spacing: 4), count: 3), spacing: 4) {
                    ForEach(displayedOutfits) { outfit in
                        Button {
                            router.push(.outfitDetail(outfit))
                        } label: {
                            OutfitThumbnail(outfit: outfit)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, smallDeviceAdaptation.underHeaderY(190))
                .padding(.bottom, smallDeviceAdaptation.scrollBottomPadding())
            }
            .frame(width: 393, height: 852)
        }
    }

    private var headerActions: some View {
        HStack(spacing: 16) {
            if store.wardrobeItems.count >= 5 {
                OutfitCreateIconButton { isCreateOutfitPresented = true }
            }
            AppIconButton(name: "app_btn_category") {
                if store.canCreateCollection {
                    router.push(.outfitCollections)
                } else {
                    router.presentPaywall(source: .inApp)
                }
            }
        }
    }
}

private enum OutfitsFilter {
    case all
    case favorites
}

private struct OutfitsUnlockCard: View {
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

private struct OutfitCreateIconButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let image = AssetResolver.image(named: "app_ic_add_6") {
                    Image(uiImage: image)
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.black)
                }
            }
            .frame(width: 32, height: 32)
            .background(Color.white.opacity(0.001), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct OutfitsEmptyState: View {
    let isUnlocked: Bool
    let createOutfit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            OutfitImage(name: "app_ic_empty", contentMode: .fit)
                .frame(width: 136, height: 136)

            Text("No outfits yet")
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)

            Text(isUnlocked ? "You have enough items to start creating outfits." : "Add clothes to your wardrobe to start creating outfits.")
                .font(.outfitBody(14, weight: .medium))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .frame(width: 284)

            if isUnlocked {
                OutfitCreateCTAButton(action: createOutfit)
                    .padding(.top, 8)
            }
        }
        .frame(width: 356, alignment: .center)
    }
}

private struct OutfitCreateCTAButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                Text("Create outfit")
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 180, height: 56)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CreateOutfitView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        CreateOutfitSheetView { request in
            router.push(.outfitProcessing(request))
        }
    }
}

private struct CreateOutfitSheetView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weather = WeatherKitManager()
    @State private var prompt = ""
    @State private var selectedSuggestionCount = 1
    @State private var selectedSourceID = "wardrobe"
    @State private var selectedPreset: String?
    @State private var selectedWeather = OutfitWeatherSelection()
    @State private var isWeatherManuallySelected = false
    @State private var isWeatherSheetPresented = false
    @FocusState private var isPromptFocused: Bool
    let startProcessing: (OutfitGenerationRequest) -> Void

    private let presets = ["Business Meeting", "Summer", "Party", "Date"]
    private let promptLimit = 50

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedPrompt.isEmpty
    }

    private var sortedSources: [OutfitSourceOption] {
        guard store.hasPremiumAccess else {
            return [OutfitSourceOption(id: "wardrobe", title: "Wardrobe", isPinned: true, isEnabled: true)]
        }
        let collectionOptions = store.collections.map { collection in
            OutfitSourceOption(
                id: collection.id.uuidString,
                title: collection.title,
                isPinned: collection.isPinned,
                isEnabled: collection.itemIDs.count >= 2
            )
        }
        let enabledCollections = collectionOptions
            .filter(\.isEnabled)
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        let disabledCollections = collectionOptions
            .filter { !$0.isEnabled }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return [OutfitSourceOption(id: "wardrobe", title: "Wardrobe", isPinned: true, isEnabled: true)] + enabledCollections + disabledCollections
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(hex: 0xA3A3A3))
                .frame(width: 36, height: 4)
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 18) {
                Text("Create Outfit")
                    .font(.outfitBody(24, weight: .bold))
                    .foregroundStyle(Color.black)

                VStack(alignment: .leading, spacing: 9) {
                    OutfitSheetSectionTitle("How many suggestions?")
                    HStack(spacing: 8) {
                        ForEach(1...3, id: \.self) { value in
                            OutfitSheetChip(
                                title: "\(value) Outfit\(value > 1 ? "s" : "")",
                                isSelected: selectedSuggestionCount == value,
                                isEnabled: store.hasPremiumAccess || value == 1,
                                isLocked: !store.hasPremiumAccess && value > 1,
                                fixedWidth: 116
                            ) {
                                selectedSuggestionCount = value
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    OutfitSheetSectionTitle("Create outfit from:")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sortedSources) { source in
                                OutfitSheetChip(
                                    title: source.title,
                                    isSelected: selectedSourceID == source.id,
                                    isEnabled: source.isEnabled,
                                    isLocked: false
                                ) {
                                    selectedSourceID = source.id
                                }
                                .opacity(source.isEnabled ? 1 : 0.38)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    OutfitSheetSectionTitle("Use Weather")
                    Button {
                        guard store.hasPremiumAccess else { return }
                        isWeatherSheetPresented = true
                    } label: {
                        HStack(spacing: 10) {
                            OutfitImage(name: selectedWeather.iconName, contentMode: .fit)
                                .frame(width: 38, height: 38)
                                .background(Color(hex: 0xEEF8FA), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Text(selectedWeather.temperatureText)
                                .font(.outfitBody(14, weight: .regular))
                                .foregroundStyle(OutfitTheme.Color.secondaryText)
                            Spacer()
                            if store.hasPremiumAccess {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .frame(width: 26, height: 26)
                                    .background(Color.black, in: Circle())
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.black)
                                    .frame(width: 26, height: 26)
                            }
                        }
                        .padding(.horizontal, 10)
                        .frame(width: 356, height: 48)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.hasPremiumAccess)
                    .opacity(store.hasPremiumAccess ? 1 : 0.72)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { preset in
                            OutfitSheetChip(title: preset, isSelected: selectedPreset == preset) {
                                selectedPreset = preset
                                prompt = preset
                            }
                        }
                    }
                }

                OutfitPromptPill(text: $prompt, isFocused: $isPromptFocused, limit: promptLimit, canSubmit: canSubmit) {
                    submit()
                }
                .onChange(of: prompt) { _, newValue in
                    if selectedPreset != newValue {
                        selectedPreset = nil
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 26)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: 0xF3F3F3))
        .task {
            weather.start()
        }
        .onChange(of: weather.snapshot) { _, snapshot in
            guard !isWeatherManuallySelected else { return }
            selectedWeather = OutfitWeatherSelection(snapshot: snapshot)
        }
        .sheet(isPresented: $isWeatherSheetPresented) {
            UseWeatherSheetView(selection: $selectedWeather) {
                isWeatherManuallySelected = true
            }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func submit() {
        guard canSubmit else { return }
        guard store.recordOutfitGenerationIfAllowed() else {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                router.presentPaywall(source: .inApp)
            }
            return
        }
        let request = OutfitGenerationRequest(
            suggestionCount: selectedSuggestionCount,
            sourceID: selectedSourceID,
            weather: selectedWeather.temperatureText,
            occasion: trimmedPrompt
        )
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            startProcessing(request)
        }
    }
}

private struct OutfitSourceOption: Identifiable {
    let id: String
    let title: String
    let isPinned: Bool
    let isEnabled: Bool
}

private struct OutfitSheetSectionTitle: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(.outfitBody(14, weight: .regular))
            .foregroundStyle(Color.black)
    }
}

private struct OutfitSheetChip: View {
    let title: String
    var isSelected: Bool
    var isEnabled = true
    var isLocked = false
    var fixedWidth: CGFloat?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.outfitBody(14, weight: .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(OutfitTheme.Color.secondaryText)
                }
            }
            .padding(.horizontal, fixedWidth == nil ? 18 : 0)
            .frame(width: fixedWidth, height: 30)
            .background(isSelected ? Color(hex: 0xA5A5A5) : Color(hex: 0xE3E3E3), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct OutfitPromptPill: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let limit: Int
    let canSubmit: Bool
    let submit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(width: 24, height: 24)

            TextField("Outfit for...", text: $text)
                .focused(isFocused)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.black)
                .submitLabel(.go)
                .onSubmit {
                    guard canSubmit else { return }
                    submit()
                }
                .onChange(of: text) { _, newValue in
                    if newValue.count > limit {
                        text = String(newValue.prefix(limit))
                    }
                }

            Button(action: submit) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
                    .background(canSubmit ? Color.black : Color(hex: 0xA5A5A5), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .padding(.leading, 20)
        .padding(.trailing, 9)
        .frame(width: 356, height: 50)
        .background(Color.white, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: 0xFF8FE8), Color(hex: 0xFFC36A), Color(hex: 0x6FF5B8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

private struct OutfitWeatherSelection: Equatable {
    var iconName = "06_rainyday_light_2"
    var temperature = 20

    init(iconName: String = "06_rainyday_light_2", temperature: Int = 20) {
        self.iconName = iconName
        self.temperature = temperature
    }

    init(snapshot: LocalWeatherSnapshot) {
        iconName = snapshot.iconName
        let numberText = snapshot.temperatureText
            .replacingOccurrences(of: "°C", with: "")
            .replacingOccurrences(of: "+", with: "")
        temperature = Int(numberText) ?? 20
    }

    var temperatureText: String {
        "\(temperature >= 0 ? "+" : "")\(temperature)°C"
    }
}

struct UseWeatherView: View {
    @State private var selection = OutfitWeatherSelection()

    var body: some View {
        UseWeatherSheetView(selection: $selection)
    }
}

private struct UseWeatherSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: OutfitWeatherSelection
    @State private var draft: OutfitWeatherSelection
    let onSave: () -> Void

    private let icons = [
        "11_mostly_cloudy_light_1", "12_thunder_light_1", "13_thunderstorm_light_1", "14_heavy_snowfall_light_1", "15_cloud_light_1",
        "16_cloudy_night_light_1", "17_cloudy_night_stars_light_1", "18_heavy_rain_light_1", "19_moon_set_light_1", "20_rain_light_1",
        "21_heavy_wind_light_1", "22_snow_light_1", "23_hailstrom_light_1", "24_drop_light_1", "01_sun_light_1",
        "02_sunset_light_1", "03_sunrise_light_1", "04_eclipse_light_1", "05_partial_cloudy_light_1", "06_rainyday_light_2",
        "07_mostly_cloud_light_1", "08_full_moon_light_1", "09_half_moon_light_1", "10_cloudy_night_light_1"
    ]

    init(selection: Binding<OutfitWeatherSelection>, onSave: @escaping () -> Void = {}) {
        _selection = selection
        _draft = State(initialValue: selection.wrappedValue)
        self.onSave = onSave
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 26
            let iconSpacing: CGFloat = 12
            let contentWidth = max(0, proxy.size.width - horizontalPadding * 2)
            let iconSize = min(50, max(40, (contentWidth - iconSpacing * 4) / 5))

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Use Weather")
                            .font(.outfitBody(24, weight: .bold))
                            .foregroundStyle(Color.black)

                        VStack(alignment: .leading, spacing: 10) {
                            OutfitSheetSectionTitle("Select Weather")
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(iconSize), spacing: iconSpacing), count: 5), spacing: 12) {
                                ForEach(icons, id: \.self) { icon in
                                    Button {
                                        draft.iconName = icon
                                    } label: {
                                        OutfitImage(name: icon, contentMode: .fit)
                                            .frame(width: iconSize, height: iconSize)
                                            .background(Color(hex: 0xE9F6F8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(icon == draft.iconName ? Color.black : Color.clear, lineWidth: 1.4)
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            OutfitSheetSectionTitle("Set the temperature")
                            TemperatureWheelPicker(temperature: $draft.temperature)
                                .frame(maxWidth: .infinity)
                                .frame(height: 118)
                                .clipped()
                                .overlay {
                                    VStack(spacing: 0) {
                                        Divider()
                                        Spacer()
                                        Divider()
                                    }
                                    .frame(height: 44)
                                    .allowsHitTesting(false)
                                }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 28)
                    .padding(.bottom, 14)
                }
                .scrollBounceBehavior(.basedOnSize)

                VStack(spacing: 12) {
                    OutfitSheetPrimaryButton(title: "Save", systemImage: "checkmark") {
                        selection = draft
                        onSave()
                        dismiss()
                    }
                    OutfitSheetSecondaryButton(title: "Cancel") {
                        dismiss()
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 28)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .background(Color(hex: 0xF3F3F3))
    }
}

private struct TemperatureWheelPicker: UIViewRepresentable {
    @Binding var temperature: Int
    private let values = Array(-20...40)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.backgroundColor = .clear
        clearSelectionBackground(in: picker)
        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        context.coordinator.parent = self
        if let row = values.firstIndex(of: temperature), picker.selectedRow(inComponent: 0) != row {
            picker.selectRow(row, inComponent: 0, animated: false)
        }
        clearSelectionBackground(in: picker)
        DispatchQueue.main.async {
            clearSelectionBackground(in: picker)
        }
    }

    private func clearSelectionBackground(in view: UIView) {
        view.subviews.forEach { subview in
            subview.backgroundColor = .clear
            clearSelectionBackground(in: subview)
        }
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: TemperatureWheelPicker

        init(_ parent: TemperatureWheelPicker) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            1
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            parent.values.count
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            44
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            pickerView.bounds.width
        }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 23, weight: .regular)
            label.textColor = .black
            label.backgroundColor = .clear
            label.text = Self.temperatureText(for: parent.values[row])
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            parent.temperature = parent.values[row]
            pickerView.subviews.forEach { $0.backgroundColor = .clear }
        }

        private static func temperatureText(for temperature: Int) -> String {
            "\(temperature >= 0 ? "+" : "")\(temperature)°C"
        }
    }
}

private struct OutfitSheetPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                Text(title)
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 356, height: 56)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct OutfitSheetSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.outfitBody(16, weight: .medium))
                .foregroundStyle(Color.black)
                .frame(width: 356, height: 50)
                .overlay {
                    Capsule().stroke(Color.black, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct OutfitProcessingView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var progress: Double = 0

    let request: OutfitGenerationRequest
    private let duration: TimeInterval = 60

    private var processingItems: [WardrobeItem] {
        Array(sourceItems.prefix(9))
    }

    private var sourceItems: [WardrobeItem] {
        guard request.sourceID != "wardrobe",
              let collectionID = UUID(uuidString: request.sourceID),
              let collection = store.collections.first(where: { $0.id == collectionID }) else {
            return store.wardrobeItems
        }
        return store.items(in: collection)
    }

    var body: some View {
        AppCanvas {
            OutfitImage(name: "app_bg_onbording_1", contentMode: .fit)
                .opacity(0.72)
                .appFrame(x: 18, y: 74, w: 356, h: 548)

            LinearGradient(
                colors: [
                    OutfitTheme.Color.appBackground.opacity(0),
                    OutfitTheme.Color.appBackground.opacity(0.92),
                    OutfitTheme.Color.appBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .appFrame(x: 0, y: 390, w: 393, h: 462, alignment: .topLeading)

            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.black)
                .scaleEffect(1.7)
                .appFrame(x: 169, y: 320, w: 56, h: 56)

            Text("Generating Outfit Ideas")
                .font(.outfitBody(24, weight: .bold))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .appFrame(x: 32, y: 612, w: 329, h: 32)

            Text("Our AI is selecting matching items\nand colors.")
                .font(.outfitBody(14, weight: .medium))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .appFrame(x: 56, y: 672, w: 282, h: 40)

            Text("\(Int(progress * 100))%")
                .font(.outfitBody(20, weight: .medium))
                .foregroundStyle(Color.black)
                .appFrame(x: 144, y: 764, w: 104, h: 26)

            Text("Processing...")
                .font(.outfitBody(12, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .appFrame(x: 122, y: 794, w: 148, h: 18)
        }
        .task {
            await runProcessing()
        }
    }

    private func runProcessing() async {
        progress = 0
        async let generatedOutfits = try? OpenAIAvatarService().generateOutfitSuggestions(
            request: request,
            sourceItems: sourceItems
        )
        let steps = 100
        let delay = UInt64(duration / Double(steps) * 1_000_000_000)
        for step in 1...steps {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: delay)
            progress = Double(step) / Double(steps)
        }
        guard !Task.isCancelled else { return }
        let openAIOutfits = await generatedOutfits
        showReview(outfits: completedSuggestions(openAIOutfits ?? []))
    }

    private func showReview(outfits: [OutfitSuggestion]) {
        if !router.path.isEmpty {
            router.path[router.path.count - 1] = .outfitReview(outfits)
        } else {
            router.push(.outfitReview(outfits))
        }
    }

    private func generatedSuggestions() -> [OutfitSuggestion] {
        let count = max(1, min(request.suggestionCount, 3))
        let rankedItems = rankedSourceItems()
        return (0..<count).map { index in
            generatedSuggestion(index: index, rankedItems: rankedItems)
        }
    }

    private func completedSuggestions(_ suggestions: [OutfitSuggestion]) -> [OutfitSuggestion] {
        let count = max(1, min(request.suggestionCount, 3))
        var result = Array(suggestions.prefix(count))
        if result.count < count {
            result.append(contentsOf: generatedSuggestions().dropFirst(result.count).prefix(count - result.count))
        }
        return result
    }

    private func generatedSuggestion(index: Int, rankedItems: [WardrobeItem]) -> OutfitSuggestion {
        let selectedItems = selectedItems(from: rankedItems, offset: index)
        let imageNames = selectedItems.map(\.imageName).filter { !$0.isEmpty }
        let occasionText = stylingIntentText(request.occasion)
        let weatherText = request.weather.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldUseWeather = !weatherText.isEmpty && weatherText != "Not specified" && weatherText != "--°C"
        let summary = shouldUseWeather
            ? "This outfit is selected from your wardrobe for \(occasionText). It balances the weather \(request.weather) with compatible colors, practical layers, and a clean body-slot structure so the pieces read as one complete look rather than separate items."
            : "This outfit is selected from your full wardrobe for \(occasionText). It focuses on the occasion, color harmony, practical layers, and a clean body-slot structure so the pieces read as one complete look rather than separate items."
        let match = max(68, min(96, 88 - index * 4 + min(selectedItems.count, 5)))
        return OutfitSuggestion(
            id: UUID(),
            title: generatedTitle(for: selectedItems, index: index),
            date: Self.formattedDate(),
            match: match,
            summary: summary,
            tips: [
                "Use the strongest piece as the visual anchor and keep the rest simpler.",
                "Avoid adding another item from the same visible category unless it is outerwear.",
                "Match shoes and accessories to one of the outfit colors for a cleaner finish."
            ],
            itemIDs: selectedItems.map(\.id),
            itemImageNames: imageNames,
            isFavorite: false
        )
    }

    private func stylingIntentText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "a versatile everyday outfit" }

        let value = trimmed.lowercased()
        let usefulTokens = [
            "outfit", "look", "wear", "dress", "style", "clothes", "wardrobe",
            "date", "party", "meeting", "office", "work", "business", "travel", "trip",
            "dinner", "lunch", "school", "university", "gym", "walk", "wedding",
            "свид", "вечерин", "встреч", "работ", "офис", "делов", "ужин", "обед",
            "прогул", "школ", "универ", "свад", "одеж", "гардероб", "наряд",
            "надеть", "одеть", "лук", "образ", "плать", "стиль"
        ]
        let unrelatedTokens = [
            "привет", "зовут", "hello", "hi ", "weather", "погода", "как дела",
            "what is", "кто ты", "расскажи", "мария"
        ]

        if usefulTokens.contains(where: { value.contains($0) }) {
            return trimmed
        }
        if unrelatedTokens.contains(where: { value.contains($0) }) {
            return "a versatile everyday outfit"
        }
        return trimmed
    }

    private func generatedTitle(for items: [WardrobeItem], index: Int) -> String {
        let occasion = request.occasion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !occasion.isEmpty {
            return "\(occasion) Look"
        }

        let anchor = items.first { $0.category == .dresses }
            ?? items.first { $0.category == .tops }
            ?? items.first
        let anchorName = anchor?.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let anchorName, !anchorName.isEmpty {
            return "\(anchorName) Look"
        }

        return index == 0 ? "Wardrobe Look" : "Wardrobe Look \(index + 1)"
    }

    private func rankedSourceItems() -> [WardrobeItem] {
        let occasion = request.occasion.lowercased()
        let weather = request.weather
        let temperature = Int(weather.replacingOccurrences(of: "°C", with: "").replacingOccurrences(of: "+", with: "")) ?? 20

        return sourceItems.sorted { lhs, rhs in
            score(lhs, occasion: occasion, temperature: temperature) > score(rhs, occasion: occasion, temperature: temperature)
        }
    }

    private func score(_ item: WardrobeItem, occasion: String, temperature: Int) -> Int {
        let text = ([item.name, item.category.rawValue, item.brand] + item.colors + item.styles + item.materials + item.seasons)
            .joined(separator: " ")
            .lowercased()
        var value = 10
        if occasion.contains("business") || occasion.contains("meeting") {
            value += text.contains("shirt") || text.contains("blazer") || text.contains("jacket") ? 12 : 0
            value += item.category == .tops || item.category == .bottoms ? 6 : 0
        }
        if occasion.contains("summer") || temperature >= 25 {
            value += item.category == .dresses || item.category == .tops || item.category == .bikinis ? 8 : 0
            value += text.contains("cotton") || text.contains("linen") || text.contains("light") ? 5 : 0
        }
        if occasion.contains("party") || occasion.contains("date") {
            value += item.category == .dresses || item.category == .bags ? 10 : 0
            value += text.contains("pink") || text.contains("black") || text.contains("silk") ? 4 : 0
        }
        if temperature <= 12 {
            value += text.contains("jacket") || text.contains("coat") || text.contains("sweater") || item.category == .bottoms ? 9 : 0
        }
        return value
    }

    private func selectedItems(from items: [WardrobeItem], offset: Int) -> [WardrobeItem] {
        guard !items.isEmpty else { return [] }
        let rotated = Array(items.dropFirst(offset)) + Array(items.prefix(offset))
        var selected: [WardrobeItem] = []
        var usedSlots: Set<String> = []
        var hasDress = false

        for item in rotated {
            let slot = outfitSlot(for: item)
            if slot == "dress" {
                guard !usedSlots.contains("dress"), !usedSlots.contains("top"), !usedSlots.contains("bottom") else { continue }
                hasDress = true
                usedSlots.insert("dress")
            } else if slot == "top" || slot == "bottom" {
                guard !hasDress, !usedSlots.contains(slot) else { continue }
                usedSlots.insert(slot)
            } else {
                guard !usedSlots.contains(slot) else { continue }
                usedSlots.insert(slot)
            }
            selected.append(item)
            if selected.count == 6 { break }
        }

        return selected.isEmpty ? Array(rotated.prefix(1)) : selected
    }

    private func outfitSlot(for item: WardrobeItem) -> String {
        let text = ([item.name, item.category.rawValue] + item.styles + item.materials)
            .joined(separator: " ")
            .lowercased()
        if item.category == .dresses || text.contains("dress") { return "dress" }
        if item.category == .bottoms || text.contains("jeans") || text.contains("pants") || text.contains("skirt") || text.contains("shorts") { return "bottom" }
        if item.category == .bags || text.contains("bag") || text.contains("handbag") || text.contains("purse") { return "bag" }
        if text.contains("hat") || text.contains("cap") || text.contains("beanie") { return "headwear" }
        if text.contains("shoe") || text.contains("sneaker") || text.contains("boot") || text.contains("loafer") || text.contains("heel") { return "shoes" }
        if text.contains("glasses") || text.contains("sunglasses") { return "eyewear" }
        if text.contains("jacket") || text.contains("coat") || text.contains("blazer") || text.contains("vest") { return "outerwear" }
        if item.category == .tops { return "top" }
        return "accessory-\(item.category.rawValue.lowercased())"
    }

    private static func formattedDate(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct OutfitReviewView: View {
    @Environment(AppRouter.self) private var router
    @Environment(OutfitDataStore.self) private var store
    let outfits: [OutfitSuggestion]
    @State private var selectedIndex = 0
    @State private var isInfoPresented = false

    private var currentOutfit: OutfitSuggestion {
        guard !outfits.isEmpty else {
            return OutfitSuggestion(id: UUID(), title: "AI Outfit Idea", date: "", match: 0, summary: "", tips: [], itemIDs: [], itemImageNames: [], isFavorite: false)
        }
        return outfits[min(selectedIndex, outfits.count - 1)]
    }

    private var currentItems: [WardrobeItem] {
        items(for: currentOutfit)
    }

    var body: some View {
        AppCanvas {
            ZStack(alignment: .topLeading) {
                reviewContent
                    .blur(radius: isInfoPresented ? 12 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isInfoPresented)

                if isInfoPresented {
                    Color.black.opacity(0.18)
                        .frame(width: 393, height: 852)
                }
            }
        }
        .sheet(isPresented: $isInfoPresented) {
            OutfitReviewInfoSheet(outfit: currentOutfit)
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.hidden)
        }
    }

    private var reviewContent: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 18) {
                Button {
                    router.popToRoot()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.black)
                        .frame(width: 15, height: 15)
                }
                .buttonStyle(.plain)

                Text("Outfit Review")
                    .font(.outfitBody(20, weight: .bold))
                    .foregroundStyle(Color.black)

                Spacer()
            }
            .appFrame(x: 36, y: 70, w: 320, h: 32, alignment: .leading)

            TabView(selection: $selectedIndex) {
                ForEach(Array(outfits.enumerated()), id: \.element.id) { index, outfit in
                    OutfitReviewMosaic(items: items(for: outfit), fallbackImageNames: outfit.itemImageNames)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .appFrame(x: 36, y: 126, w: 320, h: 386)

            Text("\(currentOutfit.match)% Match")
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 99, height: 30)
                .background(Color(hex: 0xE4E4E4), in: Capsule())
                .appFrame(x: 36, y: 528, w: 99, h: 30)

            Text("\(max(currentItems.count, currentOutfit.itemImageNames.count)) Items")
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .appFrame(x: 280, y: 534, w: 76, h: 20, alignment: .trailing)

            Text(currentOutfit.summary)
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(Color.black)
                .lineLimit(2)
                .appFrame(x: 36, y: 568, w: 264, h: 44, alignment: .topLeading)

            Button {
                isInfoPresented = true
            } label: {
                Image(systemName: "eye")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
                    .background(Color.black, in: Circle())
            }
            .buttonStyle(.plain)
            .appFrame(x: 338, y: 574, w: 32, h: 32)

            Text("\(selectedIndex + 1) / \(max(outfits.count, 1))")
                .font(.outfitBody(14, weight: .regular))
                .foregroundStyle(OutfitTheme.Color.secondaryText)
                .appFrame(x: 168, y: 634, w: 58, h: 22)

            OutfitSheetPrimaryButton(title: "Save", systemImage: "checkmark") {
                store.saveOutfitSuggestion(currentOutfit)
                router.selectedTab = .outfits
                router.popToRoot()
            }
            .appFrame(x: 18, y: 674, w: 356, h: 56)

            OutfitReviewDeleteButton {
                router.popToRoot()
            }
            .appFrame(x: 18, y: 742, w: 356, h: 56)
        }
    }

    private func items(for outfit: OutfitSuggestion) -> [WardrobeItem] {
        outfit.itemIDs.compactMap { itemID in
            store.wardrobeItems.first { $0.id == itemID }
        }
    }
}

private struct OutfitReviewMosaic: View {
    let items: [WardrobeItem]
    let fallbackImageNames: [String]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if displayCount == 1 {
                singleTile
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(154), spacing: 10), count: 2), spacing: 10) {
                    if items.isEmpty {
                        ForEach(Array(fallbackImageNames.enumerated()), id: \.offset) { _, imageName in
                            AppImageTile(imageName: imageName, width: 154, height: 183, showsBackground: false)
                        }
                    } else {
                        ForEach(items) { item in
                            AppImageTile(imageName: item.imageName, imageData: item.imageData, width: 154, height: 183, showsBackground: false)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .frame(width: 320, height: 386)
    }

    private var displayCount: Int {
        items.isEmpty ? fallbackImageNames.count : items.count
    }

    @ViewBuilder
    private var singleTile: some View {
        if let item = items.first {
            AppImageTile(imageName: item.imageName, imageData: item.imageData, width: 320, height: 386, showsBackground: false)
        } else if let imageName = fallbackImageNames.first {
            AppImageTile(imageName: imageName, width: 320, height: 386, showsBackground: false)
        }
    }
}

private struct OutfitReviewInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let outfit: OutfitSuggestion

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(hex: 0xA3A3A3))
                .frame(width: 36, height: 4)
                .padding(.top, 20)
                .padding(.bottom, 34)

            VStack(alignment: .leading, spacing: 24) {
                Text("\(outfit.match)% Match")
                    .font(.outfitBody(24, weight: .bold))
                    .foregroundStyle(Color.black)

                Text(outfit.summary)
                    .font(.outfitBody(14, weight: .medium))
                    .foregroundStyle(Color.black)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(outfit.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text(tip)
                        }
                        .font(.outfitBody(14, weight: .medium))
                        .foregroundStyle(Color.black)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Text("Ok")
                        .font(.outfitBody(16, weight: .medium))
                        .foregroundStyle(Color.white)
                        .frame(width: 356, height: 56)
                        .background(Color.black, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0xF3F3F3))
    }
}

private struct OutfitReviewDeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "trash")
                    .font(.system(size: 22, weight: .semibold))
                Text("Delete")
                    .font(.outfitBody(16, weight: .medium))
            }
            .foregroundStyle(Color.black)
            .frame(width: 356, height: 56)
            .overlay {
                Capsule().stroke(Color.black, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct OutfitThumbnail: View {
    @Environment(OutfitDataStore.self) private var store
    let outfit: OutfitSuggestion

    private var items: [WardrobeItem] {
        outfit.itemIDs.compactMap { itemID in
            store.wardrobeItems.first { $0.id == itemID }
        }
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 2), spacing: 2) {
            if items.isEmpty {
                ForEach(Array(outfit.itemImageNames.prefix(4).enumerated()), id: \.offset) { _, imageName in
                    OutfitImage(name: imageName)
                        .padding(2)
                        .frame(height: 69)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                }
            } else {
                ForEach(items.prefix(4)) { item in
                    AppImageContent(imageName: item.imageName, imageData: item.imageData)
                        .padding(2)
                        .frame(height: 69)
                        .frame(maxWidth: .infinity)
                        .background(Color.clear)
                }
            }
        }
        .frame(width: 116, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(OutfitTheme.Color.border, lineWidth: 1)
        }
    }
}

private struct AppImageContent: View {
    let imageName: String
    let imageData: Data?

    private var resolvedImage: UIImage? {
        imageData.flatMap(UIImage.init(data:))
    }

    var body: some View {
        if let resolvedImage {
            Image(uiImage: resolvedImage)
                .resizable()
                .scaledToFit()
        } else {
            OutfitImage(name: imageName)
        }
    }
}

struct OutfitDetailView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.smallDeviceAdaptation) private var smallDeviceAdaptation
    @State private var isCollectionSheetPresented = false
    @State private var isDeleteConfirmationPresented = false
    let outfit: OutfitSuggestion

    private var currentOutfit: OutfitSuggestion {
        store.outfits.first { $0.id == outfit.id } ?? outfit
    }

    private var items: [WardrobeItem] {
        currentOutfit.itemIDs.compactMap { itemID in
            store.wardrobeItems.first { $0.id == itemID }
        }
    }

    private var displayTitle: String {
        let title = currentOutfit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, !title.lowercased().hasPrefix("ai outfit idea") {
            return title
        }

        let anchor = items.first { $0.category == .dresses }
            ?? items.first { $0.category == .tops }
            ?? items.first
        if let anchorName = anchor?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !anchorName.isEmpty {
            return "\(anchorName) Look"
        }
        return "Wardrobe Look"
    }

    private var displayDate: String {
        let rawDate = currentOutfit.date.trimmingCharacters(in: .whitespacesAndNewlines)
        let inputFormatter = DateFormatter()
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.dateFormat = "dd.MM.yyyy"
        guard let date = inputFormatter.date(from: rawDate) else { return rawDate }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        outputFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        return outputFormatter.string(from: date)
    }

    var body: some View {
        AppCanvas {
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    OutfitDetailTopGrid(items: Array(items.prefix(4)), fallbackImageNames: Array(currentOutfit.itemImageNames.prefix(4)))
                        .appFrame(x: 18, y: 8, w: 356, h: 466)

                    OutfitWoreButton {}
                        .appFrame(x: 18, y: 500, w: 356, h: 56)

                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(OutfitTheme.Color.secondaryText)
                            .frame(width: 22, height: 22)
                        Text(displayDate)
                            .font(.outfitBody(12, weight: .regular))
                            .foregroundStyle(OutfitTheme.Color.secondaryText)
                    }
                    .appFrame(x: 18, y: 578, w: 356, h: 24, alignment: .leading)

                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .frame(width: 24, height: 24)
                        Text("Why this combination?")
                            .font(.outfitBody(16, weight: .semibold))
                            .foregroundStyle(Color.black)
                    }
                    .appFrame(x: 18, y: 630, w: 356, h: 24, alignment: .leading)

                    Text(currentOutfit.summary)
                        .font(.outfitBody(14, weight: .medium))
                        .foregroundStyle(Color.black)
                        .fixedSize(horizontal: false, vertical: true)
                        .appFrame(x: 18, y: 666, w: 356, h: 120, alignment: .topLeading)

                    HStack(spacing: 12) {
                        AppIcon(name: "app_ic_tip", size: 24)
                        Text("Styling tips")
                            .font(.outfitBody(16, weight: .semibold))
                            .foregroundStyle(Color.black)
                    }
                    .appFrame(x: 18, y: 806, w: 356, h: 28, alignment: .leading)

                    VStack(spacing: 12) {
                        ForEach(currentOutfit.tips, id: \.self) { tip in
                            Text(tip)
                                .font(.outfitBody(14, weight: .regular))
                                .foregroundStyle(Color.black)
                                .frame(width: 296, alignment: .leading)
                                .padding(.horizontal, 30)
                                .frame(width: 356, height: 82, alignment: .leading)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .appFrame(x: 18, y: 860, w: 356, h: CGFloat(currentOutfit.tips.count) * 94, alignment: .topLeading)

                    HStack(spacing: 12) {
                        AppIcon(name: "app_ic_shirt", size: 24)
                        Text("\(items.count) clothing items")
                            .font(.outfitBody(16, weight: .semibold))
                            .foregroundStyle(Color.black)
                    }
                    .appFrame(x: 18, y: 1168, w: 356, h: 28, alignment: .leading)

                    OutfitDetailItemsGrid(items: items)
                        .appFrame(x: 18, y: 1220, w: 356, h: max(160, CGFloat((items.count + 2) / 3) * 132), alignment: .topLeading)
                }
                .frame(width: 393, height: max(1490, 1340 + CGFloat((items.count + 2) / 3) * 132))
            }
            .frame(width: 393, height: smallDeviceAdaptation.underHeaderHeight(726))
            .clipped()
            .appFrame(
                x: 0,
                y: smallDeviceAdaptation.underHeaderY(126),
                w: 393,
                h: smallDeviceAdaptation.underHeaderHeight(726),
                alignment: .topLeading
            )

            AppTopFade(height: 126)

            OutfitDetailTopBar(
                title: displayTitle,
                outfit: currentOutfit,
                favorite: { store.toggleOutfitFavorite(id: currentOutfit.id) },
                addToCollection: {
                    if store.canCreateCollection {
                        isCollectionSheetPresented = true
                    } else {
                        router.presentPaywall(source: .inApp)
                    }
                },
                delete: {
                    isDeleteConfirmationPresented = true
                }
            )
            .appFrame(x: 18, y: 70, w: 356, h: 40, alignment: .topLeading)
        }
        .sheet(isPresented: $isCollectionSheetPresented) {
            OutfitCollectionMembershipSheetView(outfit: currentOutfit)
                .presentationDetents([.height(560)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(hex: 0xF3F3F3))
        }
        .alert("Вы действительно хотите удалить outfit?", isPresented: $isDeleteConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteOutfit(id: currentOutfit.id)
                router.popToRoot()
            }
        }
    }
}

private struct OutfitDetailTopBar: View {
    @Environment(AppRouter.self) private var router
    let title: String
    let outfit: OutfitSuggestion
    let favorite: () -> Void
    let addToCollection: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppIconButton(name: "app_btn_back") {
                router.pop()
            }

            Text(title)
                .font(.outfitBody(20, weight: .bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            HStack(spacing: 12) {
                Button(action: favorite) {
                    Image(systemName: outfit.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 27, weight: .regular))
                        .foregroundStyle(Color.black)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                AppIconButton(name: "app_btn_category", action: addToCollection)
                    .frame(width: 32, height: 32)
                AppIconButton(name: "app_ic_delete", action: delete)
                    .frame(width: 32, height: 32)
            }
        }
        .frame(width: 356, height: 40)
    }
}

private struct OutfitWoreButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                Text("I wore this today")
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 356, height: 56)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct OutfitDetailTopGrid: View {
    let items: [WardrobeItem]
    let fallbackImageNames: [String]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(174), spacing: 8), count: 2), spacing: 8) {
            if items.isEmpty {
                ForEach(Array(fallbackImageNames.enumerated()), id: \.offset) { _, imageName in
                    AppImageTile(imageName: imageName, width: 174, height: 229, showsBackground: false)
                }
            } else {
                ForEach(items) { item in
                    AppImageTile(imageName: item.imageName, imageData: item.imageData, width: 174, height: 229, showsBackground: false)
                }
            }
        }
    }
}

private struct OutfitDetailItemsGrid: View {
    @Environment(AppRouter.self) private var router
    let items: [WardrobeItem]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(112), spacing: 8), count: 3), spacing: 8) {
            ForEach(items) { item in
                AppImageTile(imageName: item.imageName, imageData: item.imageData, width: 112, height: 124, showsBackground: false) {
                    router.push(.itemDetail(item))
                }
            }
        }
    }
}

private struct OutfitCollectionMembershipSheetView: View {
    @Environment(OutfitDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isCreateCollectionPresented = false
    let outfit: OutfitSuggestion

    private var sortedCollections: [CollectionGroup] {
        store.collections.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private var selectedCollectionIDs: Set<UUID> {
        Set(store.collections.filter { $0.outfitIDs.contains(outfit.id) }.map(\.id))
    }

    private var hasSelectedCollections: Bool {
        !selectedCollectionIDs.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(hex: 0xA3A3A3))
                .frame(width: 36, height: 4)
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 0) {
                Text("Select View")
                    .font(.outfitBody(24, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.top, 28)

                if sortedCollections.isEmpty {
                    CollectionMembershipEmptyState()
                        .frame(width: 356, height: 430)
                        .padding(.top, 20)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(sortedCollections) { collection in
                                OutfitCollectionSelectionRow(
                                    title: collection.title,
                                    subtitle: collection.subtitle,
                                    isSelected: selectedCollectionIDs.contains(collection.id)
                                ) {
                                    toggle(collection)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(width: 356, height: 304, alignment: .top)
                    .padding(.top, 18)
                }
            }
            .frame(width: 356, alignment: .topLeading)

            Spacer(minLength: 0)

            OutfitCollectionSheetActionButton(
                title: hasSelectedCollections ? "Add to collections" : "Create collection",
                systemImage: hasSelectedCollections ? "checkmark" : "plus"
            ) {
                if hasSelectedCollections {
                    dismiss()
                } else {
                    isCreateCollectionPresented = true
                }
            }
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: 0xF3F3F3))
        .sheet(isPresented: $isCreateCollectionPresented) {
            CollectionEditorSheetView()
                .presentationDetents([.height(406)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(hex: 0xF3F3F3))
        }
    }

    private func toggle(_ collection: CollectionGroup) {
        let isSelected = selectedCollectionIDs.contains(collection.id)
        store.setOutfit(outfit.id, included: !isSelected, in: collection.id)
    }
}

private struct OutfitCollectionSelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.outfitBody(14, weight: .bold))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.outfitBody(14, weight: .regular))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: isSelected ? 0xD9D9D9 : 0xEBEBEB))
                    .frame(width: 24, height: 24)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black)
                }
            }
        }
        .padding(.horizontal, 28)
        .frame(width: 356, height: 84)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

private struct OutfitCollectionSheetActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                Text(title)
                    .font(.outfitBody(16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 356, height: 56)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OutfitsView()
        .environment(OutfitDataStore())
        .environment(AppRouter())
}
