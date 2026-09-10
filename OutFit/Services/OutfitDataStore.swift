import Foundation
import Observation

@MainActor
@Observable
final class OutfitDataStore {
    var didCompleteOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(didCompleteOnboarding, forKey: AppConstants.Storage.didCompleteOnboarding)
        }
    }
    var hasPremiumAccess: Bool {
        didSet {
            UserDefaults.standard.set(hasPremiumAccess, forKey: AppConstants.Storage.hasPremiumAccess)
        }
    }
    var didAcceptWardrobeAnalysis: Bool {
        didSet {
            UserDefaults.standard.set(didAcceptWardrobeAnalysis, forKey: AppConstants.Storage.didAcceptWardrobeAnalysis)
        }
    }

    var selectedCategory: ClothingCategory = .all
    var profile = ProfileSummary(name: "", age: 25, gender: "Female", clothingCount: 0, outfitCount: 0, favoriteCount: 0) {
        didSet {
            UserDefaults.standard.set(profile.name, forKey: AppConstants.Storage.profileName)
            UserDefaults.standard.set(profile.age, forKey: AppConstants.Storage.profileAge)
            UserDefaults.standard.set(profile.gender, forKey: AppConstants.Storage.profileGender)
        }
    }
    var profileHasAge: Bool {
        didSet {
            UserDefaults.standard.set(profileHasAge, forKey: AppConstants.Storage.profileHasAge)
        }
    }
    var profileHasGender: Bool {
        didSet {
            UserDefaults.standard.set(profileHasGender, forKey: AppConstants.Storage.profileHasGender)
        }
    }
    var profilePhotoData: Data? {
        didSet {
            if let profilePhotoData {
                UserDefaults.standard.set(profilePhotoData, forKey: AppConstants.Storage.profilePhotoData)
            } else {
                UserDefaults.standard.removeObject(forKey: AppConstants.Storage.profilePhotoData)
            }
        }
    }
    var pendingProfilePhotoData: Data?
    var pendingAvatarPhotoData: Data?
    var pendingClothingPhotoData: Data?
    var generatedAvatarData: Data? {
        didSet {
            if let generatedAvatarData {
                UserDefaults.standard.set(generatedAvatarData, forKey: AppConstants.Storage.generatedAvatarData)
            } else {
                UserDefaults.standard.removeObject(forKey: AppConstants.Storage.generatedAvatarData)
            }
        }
    }
    private var outfitGenerationWeekStart: Date = Date(timeIntervalSince1970: 0) {
        didSet {
            UserDefaults.standard.set(outfitGenerationWeekStart, forKey: AppConstants.Storage.outfitGenerationWeekStart)
        }
    }
    private var outfitGenerationWeekCount = 0 {
        didSet {
            UserDefaults.standard.set(outfitGenerationWeekCount, forKey: AppConstants.Storage.outfitGenerationWeekCount)
        }
    }
    private var clothingAnalysisWeekStart: Date = Date(timeIntervalSince1970: 0) {
        didSet {
            UserDefaults.standard.set(clothingAnalysisWeekStart, forKey: AppConstants.Storage.clothingAnalysisWeekStart)
        }
    }
    private var clothingAnalysisWeekCount = 0 {
        didSet {
            UserDefaults.standard.set(clothingAnalysisWeekCount, forKey: AppConstants.Storage.clothingAnalysisWeekCount)
        }
    }

    init() {
        didCompleteOnboarding = UserDefaults.standard.bool(forKey: AppConstants.Storage.didCompleteOnboarding)
        hasPremiumAccess = UserDefaults.standard.bool(forKey: AppConstants.Storage.hasPremiumAccess)
        didAcceptWardrobeAnalysis = UserDefaults.standard.bool(forKey: AppConstants.Storage.didAcceptWardrobeAnalysis)
        profileHasAge = UserDefaults.standard.bool(forKey: AppConstants.Storage.profileHasAge)
        profileHasGender = UserDefaults.standard.bool(forKey: AppConstants.Storage.profileHasGender)
        let savedAge: Int
        if UserDefaults.standard.object(forKey: AppConstants.Storage.profileAge) == nil {
            savedAge = 25
        } else {
            savedAge = UserDefaults.standard.integer(forKey: AppConstants.Storage.profileAge)
        }
        profile = ProfileSummary(
            name: UserDefaults.standard.string(forKey: AppConstants.Storage.profileName) ?? "",
            age: savedAge,
            gender: UserDefaults.standard.string(forKey: AppConstants.Storage.profileGender) ?? "Female",
            clothingCount: 0,
            outfitCount: 0,
            favoriteCount: 0
        )
        profilePhotoData = UserDefaults.standard.data(forKey: AppConstants.Storage.profilePhotoData)
        generatedAvatarData = UserDefaults.standard.data(forKey: AppConstants.Storage.generatedAvatarData)
        outfitGenerationWeekStart = UserDefaults.standard.object(forKey: AppConstants.Storage.outfitGenerationWeekStart) as? Date ?? Self.currentWeekStart()
        outfitGenerationWeekCount = UserDefaults.standard.integer(forKey: AppConstants.Storage.outfitGenerationWeekCount)
        clothingAnalysisWeekStart = UserDefaults.standard.object(forKey: AppConstants.Storage.clothingAnalysisWeekStart) as? Date ?? Self.currentWeekStart()
        clothingAnalysisWeekCount = UserDefaults.standard.integer(forKey: AppConstants.Storage.clothingAnalysisWeekCount)
        refreshWeeklyUsageIfNeeded()
        if let savedAvatars = UserDefaults.standard.data(forKey: AppConstants.Storage.avatars),
           let decodedAvatars = try? JSONDecoder().decode([AvatarProfile].self, from: savedAvatars) {
            avatars = decodedAvatars
        } else if let generatedAvatarData {
            avatars = [
                AvatarProfile(id: UUID(), name: "AI Avatar", imageName: "", imageData: generatedAvatarData)
            ]
        }
        if let savedWardrobeItems = UserDefaults.standard.data(forKey: AppConstants.Storage.wardrobeItems),
           let decodedWardrobeItems = try? JSONDecoder().decode([WardrobeItem].self, from: savedWardrobeItems) {
            wardrobeItems = decodedWardrobeItems
        }
        if let savedCollections = UserDefaults.standard.data(forKey: AppConstants.Storage.collections),
           let decodedCollections = try? JSONDecoder().decode([CollectionGroup].self, from: savedCollections) {
            collections = decodedCollections
        }
        if let savedOutfits = UserDefaults.standard.data(forKey: AppConstants.Storage.outfits),
           let decodedOutfits = try? JSONDecoder().decode([OutfitSuggestion].self, from: savedOutfits) {
            outfits = decodedOutfits
        }
    }

    var wardrobeItems: [WardrobeItem] = [] {
        didSet {
            persistWardrobeItems()
        }
    }
    var outfits: [OutfitSuggestion] = [] {
        didSet {
            persistOutfits()
        }
    }
    var avatars: [AvatarProfile] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(avatars) {
                UserDefaults.standard.set(data, forKey: AppConstants.Storage.avatars)
            }
        }
    }
    var selectedAvatarForLook: AvatarProfile?
    var collections: [CollectionGroup] = [] {
        didSet {
            persistCollections()
        }
    }

    var filteredItems: [WardrobeItem] {
        selectedCategory == .all ? wardrobeItems : wardrobeItems.filter { $0.category == selectedCategory }
    }

    var wardrobeCategories: [ClothingCategory] {
        var categories = ClothingCategory.wardrobeBaseCases
        for category in wardrobeItems.map(\.category) where !categories.contains(category) {
            categories.append(category)
        }
        return categories
    }

    var weeklyOutfitGenerationLimit: Int {
        hasPremiumAccess ? AppConstants.FeatureLimits.proOutfitGenerationsPerWeek : AppConstants.FeatureLimits.freeOutfitGenerationsPerWeek
    }

    var weeklyClothingAnalysisLimit: Int {
        hasPremiumAccess ? AppConstants.FeatureLimits.proClothingAnalysesPerWeek : AppConstants.FeatureLimits.freeClothingAnalysesPerWeek
    }

    var canGenerateOutfitThisWeek: Bool {
        refreshWeeklyUsageIfNeeded()
        return outfitGenerationWeekCount < weeklyOutfitGenerationLimit
    }

    var canAnalyzeClothingThisWeek: Bool {
        refreshWeeklyUsageIfNeeded()
        return clothingAnalysisWeekCount < weeklyClothingAnalysisLimit
    }

    var canCreateCollection: Bool {
        hasPremiumAccess
    }

    var canCreateAvatar: Bool {
        hasPremiumAccess || avatars.count < AppConstants.FeatureLimits.freeAvatarCount
    }

    func recordOutfitGenerationIfAllowed() -> Bool {
        refreshWeeklyUsageIfNeeded()
        guard outfitGenerationWeekCount < weeklyOutfitGenerationLimit else { return false }
        outfitGenerationWeekCount += 1
        return true
    }

    func recordClothingAnalysisIfAllowed() -> Bool {
        refreshWeeklyUsageIfNeeded()
        guard clothingAnalysisWeekCount < weeklyClothingAnalysisLimit else { return false }
        clothingAnalysisWeekCount += 1
        return true
    }

    func saveGeneratedAvatar(data: Data) {
        guard canCreateAvatar else { return }
        generatedAvatarData = data
        pendingAvatarPhotoData = nil
        avatars.insert(AvatarProfile(id: UUID(), name: "AI Avatar", imageName: "", imageData: data), at: 0)
    }

    func deleteGeneratedAvatar(id: UUID) {
        pendingAvatarPhotoData = nil
        avatars.removeAll { $0.id == id }
        generatedAvatarData = avatars.first?.imageData
        if selectedAvatarForLook?.id == id {
            selectedAvatarForLook = avatars.first
        }
    }

    func discardPendingGeneratedAvatar() {
        pendingAvatarPhotoData = nil
    }

    func saveGeneratedWardrobeItem(data: Data, draft: WardrobeItemDraft) {
        guard recordClothingAnalysisIfAllowed() else { return }
        let brand = Self.normalizedTags(draft.brand)
        let item = WardrobeItem(
            id: UUID(),
            name: Self.normalizedItemName(draft.name),
            category: Self.normalizedCategory(from: draft),
            imageName: "",
            imageData: data,
            colors: Self.normalizedTags(draft.colors),
            styles: Self.normalizedTags(draft.styles),
            materials: Self.normalizedTags(draft.materials),
            seasons: Self.normalizedTags(draft.seasons),
            brand: brand.first ?? "",
            wornCount: 0,
            lastWorn: "Never",
            addedDate: Self.formattedWardrobeDate()
        )
        wardrobeItems.insert(item, at: 0)
        pendingClothingPhotoData = nil
    }

    func updateWardrobeItem(id: UUID, draft: WardrobeItemDraft) {
        guard let index = wardrobeItems.firstIndex(where: { $0.id == id }) else { return }
        let brand = Self.normalizedTags(draft.brand)
        wardrobeItems[index].name = Self.normalizedItemName(draft.name)
        wardrobeItems[index].category = Self.normalizedCategory(from: draft)
        wardrobeItems[index].brand = brand.first ?? ""
        wardrobeItems[index].colors = Self.normalizedTags(draft.colors)
        wardrobeItems[index].styles = Self.normalizedTags(draft.styles)
        wardrobeItems[index].materials = Self.normalizedTags(draft.materials)
        wardrobeItems[index].seasons = Self.normalizedTags(draft.seasons)
    }

    func markWardrobeItemWornToday(id: UUID) {
        guard let index = wardrobeItems.firstIndex(where: { $0.id == id }) else { return }
        wardrobeItems[index].wornCount += 1
        wardrobeItems[index].lastWorn = Self.formattedWardrobeDate()
    }

    func deleteWardrobeItem(id: UUID) {
        wardrobeItems.removeAll { $0.id == id }
        for index in collections.indices {
            collections[index].itemIDs.removeAll { $0 == id }
        }
        persistCollections()
    }

    func deleteCollection(id: UUID) {
        collections.removeAll { $0.id == id }
    }

    func toggleCollectionPinned(id: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].isPinned.toggle()
        persistCollections()
    }

    func setWardrobeItem(_ itemID: UUID, included isIncluded: Bool, in collectionID: UUID) {
        guard canCreateCollection else { return }
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionID }) else { return }

        if isIncluded {
            guard !collections[collectionIndex].itemIDs.contains(itemID) else { return }
            collections[collectionIndex].itemIDs.append(itemID)
        } else {
            collections[collectionIndex].itemIDs.removeAll { $0 == itemID }
        }
        persistCollections()
    }

    func setOutfit(_ outfitID: UUID, included isIncluded: Bool, in collectionID: UUID) {
        guard canCreateCollection else { return }
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionID }) else { return }

        if isIncluded {
            guard !collections[collectionIndex].outfitIDs.contains(outfitID) else { return }
            collections[collectionIndex].outfitIDs.append(outfitID)
        } else {
            collections[collectionIndex].outfitIDs.removeAll { $0 == outfitID }
        }
        persistCollections()
    }

    func items(in collection: CollectionGroup) -> [WardrobeItem] {
        guard !collection.itemIDs.isEmpty else { return [] }
        return collection.itemIDs.compactMap { itemID in
            wardrobeItems.first { $0.id == itemID }
        }
    }

    func saveOutfitSuggestion(_ outfit: OutfitSuggestion) {
        guard !outfits.contains(where: { $0.id == outfit.id }) else { return }
        outfits.insert(outfit, at: 0)
        persistOutfits()
    }

    func createCollection(title: String, subtitle: String) -> CollectionGroup? {
        guard canCreateCollection else { return nil }
        let collection = CollectionGroup(id: UUID(), title: title, subtitle: subtitle)
        collections.append(collection)
        return collection
    }

    func toggleOutfitFavorite(id: UUID) {
        guard let index = outfits.firstIndex(where: { $0.id == id }) else { return }
        outfits[index].isFavorite.toggle()
        persistOutfits()
    }

    func deleteOutfit(id: UUID) {
        outfits.removeAll { $0.id == id }
        for index in collections.indices {
            collections[index].outfitIDs.removeAll { $0 == id }
        }
        persistOutfits()
        persistCollections()
    }

    private func persistWardrobeItems() {
        if let data = try? JSONEncoder().encode(wardrobeItems) {
            UserDefaults.standard.set(data, forKey: AppConstants.Storage.wardrobeItems)
        }
    }

    private func persistOutfits() {
        if let data = try? JSONEncoder().encode(outfits) {
            UserDefaults.standard.set(data, forKey: AppConstants.Storage.outfits)
        }
    }

    private func persistCollections() {
        if let data = try? JSONEncoder().encode(collections) {
            UserDefaults.standard.set(data, forKey: AppConstants.Storage.collections)
        }
    }

    private func refreshWeeklyUsageIfNeeded() {
        let weekStart = Self.currentWeekStart()
        if !Calendar.current.isDate(outfitGenerationWeekStart, inSameDayAs: weekStart) {
            outfitGenerationWeekStart = weekStart
            outfitGenerationWeekCount = 0
        }
        if !Calendar.current.isDate(clothingAnalysisWeekStart, inSameDayAs: weekStart) {
            clothingAnalysisWeekStart = weekStart
            clothingAnalysisWeekCount = 0
        }
    }

    private static func currentWeekStart(_ date: Date = Date()) -> Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start ?? Calendar.current.startOfDay(for: date)
    }

    private static func formattedWardrobeDate(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private static func normalizedItemName(_ name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Clothing Item" : trimmedName
    }

    private static func normalizedTags(_ values: [String]) -> [String] {
        var seenValues: Set<String> = []
        var tags: [String] = []

        for value in values {
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedValue.isEmpty else { continue }
            let key = trimmedValue.lowercased()
            guard !seenValues.contains(key) else { continue }
            seenValues.insert(key)
            tags.append(trimmedValue)
        }

        return tags
    }

    private static func normalizedCategory(from draft: WardrobeItemDraft) -> ClothingCategory {
        if let categoryName = normalizedTags(draft.categoryTags).first {
            return ClothingCategory(displayName: categoryName)
        }
        return draft.category
    }

    func resetAllUserData() {
        selectedCategory = .all
        wardrobeItems = []
        outfits = []
        avatars = []
        selectedAvatarForLook = nil
        collections = []
        profilePhotoData = nil
        pendingProfilePhotoData = nil
        pendingAvatarPhotoData = nil
        pendingClothingPhotoData = nil
        generatedAvatarData = nil
        profileHasAge = false
        profileHasGender = false
        profile = ProfileSummary(name: "", age: 25, gender: "Female", clothingCount: 0, outfitCount: 0, favoriteCount: 0)
        hasPremiumAccess = false
        didAcceptWardrobeAnalysis = false
        didCompleteOnboarding = false

        [
            AppConstants.Storage.didCompleteOnboarding,
            AppConstants.Storage.hasPremiumAccess,
            AppConstants.Storage.didAcceptWardrobeAnalysis,
            AppConstants.Storage.profileName,
            AppConstants.Storage.profileAge,
            AppConstants.Storage.profileGender,
            AppConstants.Storage.profileHasAge,
            AppConstants.Storage.profileHasGender,
            AppConstants.Storage.profilePhotoData,
            AppConstants.Storage.generatedAvatarData,
            AppConstants.Storage.wardrobeItems,
            AppConstants.Storage.outfits,
            AppConstants.Storage.avatars,
            AppConstants.Storage.collections,
            AppConstants.Storage.outfitGenerationWeekStart,
            AppConstants.Storage.outfitGenerationWeekCount,
            AppConstants.Storage.clothingAnalysisWeekStart,
            AppConstants.Storage.clothingAnalysisWeekCount
        ].forEach { key in
            UserDefaults.standard.removeObject(forKey: key)
        }
        outfitGenerationWeekStart = Self.currentWeekStart()
        outfitGenerationWeekCount = 0
        clothingAnalysisWeekStart = Self.currentWeekStart()
        clothingAnalysisWeekCount = 0
    }
}
