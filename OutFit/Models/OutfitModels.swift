import Foundation
import SwiftUI

struct WardrobeItem: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var category: ClothingCategory
    var imageName: String
    var imageData: Data? = nil
    var colors: [String]
    var styles: [String]
    var materials: [String]
    var seasons: [String]
    var brand: String
    var wornCount: Int
    var lastWorn: String
    var addedDate: String

    init(
        id: UUID,
        name: String,
        category: ClothingCategory,
        imageName: String,
        imageData: Data? = nil,
        colors: [String],
        styles: [String],
        materials: [String] = [],
        seasons: [String],
        brand: String,
        wornCount: Int,
        lastWorn: String,
        addedDate: String = ""
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.imageName = imageName
        self.imageData = imageData
        self.colors = colors
        self.styles = styles
        self.materials = materials
        self.seasons = seasons
        self.brand = brand
        self.wornCount = wornCount
        self.lastWorn = lastWorn
        self.addedDate = addedDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case imageName
        case imageData
        case colors
        case styles
        case materials
        case seasons
        case brand
        case wornCount
        case lastWorn
        case addedDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(ClothingCategory.self, forKey: .category)
        imageName = try container.decode(String.self, forKey: .imageName)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        colors = try container.decodeIfPresent([String].self, forKey: .colors) ?? []
        styles = try container.decodeIfPresent([String].self, forKey: .styles) ?? []
        materials = try container.decodeIfPresent([String].self, forKey: .materials) ?? []
        seasons = try container.decodeIfPresent([String].self, forKey: .seasons) ?? []
        brand = try container.decodeIfPresent(String.self, forKey: .brand) ?? ""
        wornCount = try container.decodeIfPresent(Int.self, forKey: .wornCount) ?? 0
        lastWorn = try container.decodeIfPresent(String.self, forKey: .lastWorn) ?? "Never"
        addedDate = try container.decodeIfPresent(String.self, forKey: .addedDate) ?? ""
    }
}

enum ClothingCategory: Hashable, Identifiable, Codable {
    case all
    case tops
    case bottoms
    case dresses
    case bikinis
    case socks
    case bags
    case custom(String)

    static let allCases: [ClothingCategory] = [.all, .tops, .bottoms, .dresses, .bikinis, .socks, .bags]
    static let wardrobeBaseCases: [ClothingCategory] = [.all, .tops, .bottoms, .dresses, .bikinis, .socks]

    var id: String { rawValue.lowercased() }

    var rawValue: String {
        switch self {
        case .all:
            return "All Items"
        case .tops:
            return "Tops"
        case .bottoms:
            return "Bottoms"
        case .dresses:
            return "Dresses"
        case .bikinis:
            return "Bikinis"
        case .socks:
            return "Socks"
        case .bags:
            return "Bags"
        case .custom(let title):
            return title
        }
    }

    init(displayName: String) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        switch normalized {
        case "all", "all item", "all items":
            self = .all
        case "top", "tops", "shirt", "shirts", "t-shirt", "t-shirts", "tee", "tees", "sweater", "sweaters", "hoodie", "hoodies", "blouse", "blouses", "blazer", "blazers", "jacket", "jackets", "coat", "coats":
            self = .tops
        case "bottom", "bottoms", "pants", "trousers", "jeans", "shorts", "skirt", "skirts":
            self = .bottoms
        case "dress", "dresses":
            self = .dresses
        case "bikini", "bikinis", "swimsuit", "swimsuits", "swimwear":
            self = .bikinis
        case "sock", "socks":
            self = .socks
        case "bag", "bags", "handbag", "handbags", "purse", "purses":
            self = .bags
        default:
            self = .custom(trimmed.isEmpty ? "Other" : trimmed.capitalized)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(displayName: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct WardrobeItemMetadata: Hashable, Codable {
    var name: String
    var category: ClothingCategory
    var colors: [String]
    var styles: [String]
    var materials: [String]
    var seasons: [String]

    static let fallback = WardrobeItemMetadata(
        name: "Clothing Item",
        category: .tops,
        colors: [],
        styles: [],
        materials: [],
        seasons: []
    )
}

struct WardrobeItemDraft: Hashable {
    var name: String
    var category: ClothingCategory
    var categoryTags: [String]
    var brand: [String]
    var colors: [String]
    var styles: [String]
    var materials: [String]
    var seasons: [String]

    init(metadata: WardrobeItemMetadata) {
        name = metadata.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Clothing Item" : metadata.name
        category = metadata.category
        categoryTags = [metadata.category.rawValue]
        brand = []
        colors = metadata.colors
        styles = metadata.styles
        materials = metadata.materials
        seasons = metadata.seasons
    }

    init(item: WardrobeItem) {
        name = item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Clothing Item" : item.name
        category = item.category
        categoryTags = [item.category.rawValue]
        brand = item.brand.isEmpty ? [] : [item.brand]
        colors = item.colors
        styles = item.styles
        materials = item.materials
        seasons = item.seasons
    }

    var resolvedCategory: ClothingCategory {
        ClothingCategory(displayName: categoryTags.first ?? category.rawValue)
    }
}

struct OutfitSuggestion: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var date: String
    var match: Int
    var summary: String
    var tips: [String]
    var itemIDs: [UUID] = []
    var itemImageNames: [String]
    var isFavorite: Bool
}

struct OutfitGenerationRequest: Hashable {
    var suggestionCount: Int
    var sourceID: String
    var weather: String
    var occasion: String
}

struct AvatarProfile: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var imageName: String
    var imageData: Data? = nil
}

struct CollectionGroup: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var subtitle: String
    var itemIDs: [UUID]
    var outfitIDs: [UUID]
    var isPinned: Bool

    init(
        id: UUID,
        title: String,
        subtitle: String,
        itemIDs: [UUID] = [],
        outfitIDs: [UUID] = [],
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.itemIDs = itemIDs
        self.outfitIDs = outfitIDs
        self.isPinned = isPinned
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case itemIDs
        case outfitIDs
        case isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        itemIDs = try container.decodeIfPresent([UUID].self, forKey: .itemIDs) ?? []
        outfitIDs = try container.decodeIfPresent([UUID].self, forKey: .outfitIDs) ?? []
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

struct ProfileSummary: Hashable {
    var name: String
    var age: Int
    var gender: String
    var clothingCount: Int
    var outfitCount: Int
    var favoriteCount: Int
}

enum AssetName {
    static let dress = "wardrobe_dress"
    static let jeans = "wardrobe_jeans"
    static let vest = "wardrobe_vest"
    static let denimJacket = "wardrobe_jacket_denim"
    static let stripedShirt = "wardrobe_pink_bag"
    static let hat = "wardrobe_black_jacket"
    static let pinkBag = "outfit_bag"
    static let handbag = "outfit_bag"
    static let blackJacket = "wardrobe_red_tshirt"
    static let beigeJacket = "wardrobe_beige_jacket"
    static let shoes = "wardrobe_shoes"
    static let redTee = "wardrobe_red_tshirt"
    static let avatarMargo = "avatar_margo"
    static let avatarZoe = "avatar_zoe"
    static let avatarLena = "avatar_lena"
    static let rainy = "06_rainyday_light_2"
    static let weatherSun = "01_sun_light_2"
    static let weatherPartlyCloudy = "05_partial_cloudy_light_2"
    static let weatherCloud = "15_cloud_light_2"
    static let weatherRain = "20_rain_light_2"
    static let weatherHeavyRain = "18_heavy_rain_light_2"
    static let weatherHeavyWind = "21_heavy_wind_light_2"
    static let weatherSnow = "22_snow_light_2"
    static let weatherThunderstorm = "13_thunderstorm_light_2"
    static let weatherHail = "23_hailstrom_light_2"
}
