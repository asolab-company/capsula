import Foundation

struct OpenAIAvatarService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidImageResponse
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "OpenAI API key is unavailable."
            case .invalidImageResponse:
                return "OpenAI did not return a valid avatar image."
            case .requestFailed(let message):
                return message
            }
        }
    }

    func cachedAPIKey() async throws -> String {
        if let savedKey = UserDefaults.standard.string(forKey: AppConstants.Storage.openAIAPIKey),
           !savedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return savedKey
        }

        let (data, response) = try await URLSession.shared.data(from: AppConstants.OpenAI.apiKeySourceURL)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw ServiceError.missingAPIKey
        }

        let key = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        UserDefaults.standard.set(key, forKey: AppConstants.Storage.openAIAPIKey)
        return key
    }

    func createAvatar(imageData: Data, maskData: Data) async throws -> Data {
        try await createEditedImage(
            imageData: imageData,
            maskData: maskData,
            prompt: AppConstants.OpenAI.avatarPrompt,
            sourceFilename: "avatar-source.png",
            maskFilename: "avatar-mask.png",
            fallbackMessage: "Avatar generation failed. Please choose another full-body photo."
        )
    }

    func createWardrobeItem(imageData: Data, maskData: Data) async throws -> Data {
        try await createEditedImage(
            imageData: imageData,
            maskData: maskData,
            prompt: AppConstants.OpenAI.wardrobeItemPrompt,
            sourceFilename: "wardrobe-source.png",
            maskFilename: "wardrobe-mask.png",
            fallbackMessage: "Clothing analysis failed. Please choose another clothing photo."
        )
    }

    func createStyledAvatar(avatarImageData: Data, wardrobeItems: [(name: String, category: String, imageData: Data)]) async throws -> Data {
        let itemDescriptions = wardrobeItems.enumerated()
            .map { index, item in
                "\(index + 1). \(item.name) (user category: \(item.category))"
            }
            .joined(separator: "\n")
        let prompt = """
        Dress the person in the first image using the selected wardrobe reference images. The wardrobe images are in this order:
        \(itemDescriptions)

        First visually identify what each reference actually is. Treat user categories and names as hints only; if the image clearly shows a different garment type, trust the image. Build one realistic outfit from the compatible selected items. Do not force contradictory items together: use only one item per body slot when items conflict, such as one top layer, one bottom, one dress/full-body garment, one pair of shoes, one bag, one hat, and one pair of socks. A dress or full-body garment replaces separate top and bottom items. Outerwear such as a coat, jacket, blazer, or vest may be layered over a top/dress and should visually cover the pieces beneath it where natural. If multiple items compete for the same visible slot, choose the item that is outermost, most complete, or most visually dominant, and omit the redundant conflicting item.

        Preserve the original avatar identity exactly. Do not change the person's face, facial expression, skin tone, hair color, hair length, hairstyle, head shape, body shape, height, perceived age, gender presentation, proportions, pose, camera angle, or full-body framing. Only edit the clothing and accessories that are being worn.

        Preserve each selected wardrobe item as the exact same item from its reference image. Do not redesign, restyle, simplify, recolor, crop, replace, or approximate the clothing or accessories. Keep the same garment silhouette, cut, length, fit, proportions, fabric texture, stitching, seams, pockets, straps, buttons, zippers, hardware, logos, prints, patterns, color placement, and visible wear details. If the item is a handbag, preserve that exact handbag shape, handle, strap, hardware, size, color, and material. If the item is a jacket, preserve that exact jacket structure, collar, sleeves, pockets, zipper/buttons, wash, and texture. If the item is a shirt/top, preserve that exact shirt/top cut, collar, sleeve length, fabric, stripe/print placement, and details. Fit the exact item naturally onto the avatar without changing its identity.

        Do not add extra clothing, props, text, background, or new people. Return one clean photorealistic full-body transparent PNG.
        """

        return try await createMultiImageEdit(
            avatarImageData: avatarImageData,
            wardrobeItems: wardrobeItems,
            prompt: prompt,
            fallbackMessage: "Could not generate the styled avatar. Please try another clothing combination."
        )
    }

    func analyzeWardrobeItemMetadata(imageData: Data) async throws -> WardrobeItemMetadata {
        let apiKey = try await cachedAPIKey()
        var request = URLRequest(url: AppConstants.OpenAI.chatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Analyze only the clothing item in this transparent product cutout. Return compact JSON only, with no markdown:
        {"name":"short item type, e.g. Blazer or Sweater","category":"Tops","colors":["Black"],"styles":["Formal"],"materials":["Cotton"],"seasons":["Winter"]}
        Rules: do not include brand names. Prefer these categories when they fit: Tops, Bottoms, Dresses, Bikinis, Socks. If none fit, return a short plural custom category such as Bags, Shoes, Accessories, Outerwear, or Jewelry. Use 1-4 colors, 1-3 styles, 1-3 materials, and 1-4 seasons. If unsure, use the closest simple fashion tag.
        """

        let encodedImage = imageData.base64EncodedString()
        let body: [String: Any] = [
            "model": AppConstants.OpenAI.metadataModel,
            "temperature": 0.1,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        [
                            "type": "image_url",
                            "image_url": ["url": "data:image/png;base64,\(encodedImage)"]
                        ]
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed("Could not analyze clothing details.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ServiceError.requestFailed(decodedAPIError(from: data) ?? "Could not analyze clothing details.")
        }

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw ServiceError.requestFailed("OpenAI did not return clothing details.")
        }
        return try normalizedWardrobeMetadata(from: content)
    }

    func generateOutfitSuggestions(
        request generationRequest: OutfitGenerationRequest,
        sourceItems: [WardrobeItem]
    ) async throws -> [OutfitSuggestion] {
        let apiKey = try await cachedAPIKey()
        var request = URLRequest(url: AppConstants.OpenAI.chatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let wardrobePayload = sourceItems.map { item in
            [
                "id": item.id.uuidString,
                "name": item.name,
                "category": item.category.rawValue,
                "colors": item.colors,
                "styles": item.styles,
                "materials": item.materials,
                "seasons": item.seasons,
                "brand": item.brand
            ] as [String: Any]
        }

        let expectedCount = max(1, min(generationRequest.suggestionCount, 3))
        let weatherText = generationRequest.weather.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldUseWeather = !weatherText.isEmpty && weatherText != "Not specified" && weatherText != "--°C"
        let weatherRequestLine = shouldUseWeather
            ? "- Weather: \(weatherText)"
            : "- Weather: Not specified. Do not optimize for temperature or forecast."
        let compatibilityRule = shouldUseWeather
            ? "- Choose compatible items for the weather, occasion, color harmony, category mix, and layer logic."
            : "- Choose compatible items for the occasion, color harmony, category mix, and layer logic. Ignore weather and temperature."
        let stylingRequest = Self.normalizedStylingIntent(generationRequest.occasion)
        let prompt = """
        You are a fashion outfit planner. Pick EXACTLY \(expectedCount) complete outfit variation(s) using ONLY the wardrobe item IDs provided.

        User request:
        \(weatherRequestLine)
        - Styling request: \(stylingRequest)

        Rules:
        - Return compact JSON only, no markdown.
        - Treat the styling request only as wardrobe/outfit intent. Extract useful fashion context such as occasion, mood, dress code, season, color preference, activity, or place.
        - Ignore greetings, personal introductions, names, weather questions, general questions, and unrelated chat. Do not answer those questions in the summary.
        - If the styling request has no useful fashion context, create a versatile everyday outfit from the wardrobe.
        - Never invent item IDs. Use only IDs from wardrobe_items.
        - Return exactly \(expectedCount) objects in outfits. Do not return more.
        - Each outfit must be a wearable complete look for a body, not a random collection of items.
        - Use only one item per visible slot: one headwear/hat, one eyewear, one top OR one dress/full-body piece, one bottom if no dress, one outerwear layer if useful, one bag, one shoe pair, and one accessory/jewelry group.
        - Do not pick multiple hats, multiple bags, multiple tops, multiple bottoms, or incompatible duplicates.
        - A dress/full-body garment replaces separate top and bottom items.
        \(compatibilityRule)
        - If count is 2 or 3, return meaningfully different complete outfit variations.
        - match is 0-100 and should reflect fit for the user request.
        - summary should be 2-3 detailed sentences explaining why the selected outfit fits.
        - tips must contain exactly 3 practical styling tips.

        JSON shape:
        {"outfits":[{"title":"...","match":82,"summary":"...","tips":["..."],"itemIDs":["uuid"]}]}
        """

        let body: [String: Any] = [
            "model": AppConstants.OpenAI.metadataModel,
            "temperature": 0.35,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "text", "text": "wardrobe_items JSON:\n\(jsonString(from: wardrobePayload))"]
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw ServiceError.requestFailed(decodedAPIError(from: data) ?? "OpenAI could not generate outfit ideas.")
        }

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw ServiceError.requestFailed("OpenAI did not return outfit ideas.")
        }
        return try normalizedOutfitSuggestions(from: content, sourceItems: sourceItems, maxCount: expectedCount)
    }

    private func createEditedImage(
        imageData: Data,
        maskData: Data,
        prompt: String,
        sourceFilename: String,
        maskFilename: String,
        fallbackMessage: String
    ) async throws -> Data {
        let apiKey = try await cachedAPIKey()
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: AppConstants.OpenAI.imageEditURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            boundary: boundary,
            imageData: imageData,
            maskData: maskData,
            prompt: prompt,
            sourceFilename: sourceFilename,
            maskFilename: maskFilename
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidImageResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = decodedAPIError(from: data) ?? fallbackMessage
            throw ServiceError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode(OpenAIImageResponse.self, from: data)
        guard let encodedImage = decoded.data.first?.b64JSON,
              let avatarData = Data(base64Encoded: encodedImage) else {
            throw ServiceError.invalidImageResponse
        }
        return avatarData
    }

    private func createMultiImageEdit(
        avatarImageData: Data,
        wardrobeItems: [(name: String, category: String, imageData: Data)],
        prompt: String,
        fallbackMessage: String
    ) async throws -> Data {
        let apiKey = try await cachedAPIKey()
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: AppConstants.OpenAI.imageEditURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multiImageMultipartBody(
            boundary: boundary,
            avatarImageData: avatarImageData,
            wardrobeItems: wardrobeItems,
            prompt: prompt
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidImageResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = decodedAPIError(from: data) ?? fallbackMessage
            throw ServiceError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode(OpenAIImageResponse.self, from: data)
        guard let encodedImage = decoded.data.first?.b64JSON,
              let avatarData = Data(base64Encoded: encodedImage) else {
            throw ServiceError.invalidImageResponse
        }
        return avatarData
    }

    private func multipartBody(
        boundary: String,
        imageData: Data,
        maskData: Data,
        prompt: String,
        sourceFilename: String,
        maskFilename: String
    ) -> Data {
        var body = Data()
        appendField(name: "model", value: AppConstants.OpenAI.imageEditModel, boundary: boundary, to: &body)
        appendField(name: "prompt", value: prompt, boundary: boundary, to: &body)
        appendField(name: "size", value: "1024x1536", boundary: boundary, to: &body)
        appendField(name: "quality", value: "medium", boundary: boundary, to: &body)
        appendField(name: "background", value: "transparent", boundary: boundary, to: &body)
        appendField(name: "output_format", value: "png", boundary: boundary, to: &body)
        appendFile(name: "image[]", filename: sourceFilename, mimeType: "image/png", data: imageData, boundary: boundary, to: &body)
        appendFile(name: "mask", filename: maskFilename, mimeType: "image/png", data: maskData, boundary: boundary, to: &body)
        body.append("--\(boundary)--\r\n")
        return body
    }

    private func multiImageMultipartBody(
        boundary: String,
        avatarImageData: Data,
        wardrobeItems: [(name: String, category: String, imageData: Data)],
        prompt: String
    ) -> Data {
        var body = Data()
        appendField(name: "model", value: AppConstants.OpenAI.imageEditModel, boundary: boundary, to: &body)
        appendField(name: "prompt", value: prompt, boundary: boundary, to: &body)
        appendField(name: "size", value: "1024x1536", boundary: boundary, to: &body)
        appendField(name: "quality", value: "medium", boundary: boundary, to: &body)
        appendField(name: "background", value: "transparent", boundary: boundary, to: &body)
        appendField(name: "output_format", value: "png", boundary: boundary, to: &body)
        appendFile(name: "image[]", filename: "avatar.png", mimeType: "image/png", data: avatarImageData, boundary: boundary, to: &body)

        for (index, item) in wardrobeItems.enumerated() {
            appendFile(
                name: "image[]",
                filename: "item-\(index + 1)-\(sanitizedFilename(item.name)).png",
                mimeType: "image/png",
                data: item.imageData,
                boundary: boundary,
                to: &body
            )
        }

        body.append("--\(boundary)--\r\n")
        return body
    }

    private func sanitizedFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value
            .lowercased()
            .map { character in
                String(character).rangeOfCharacter(from: allowed) == nil ? "-" : String(character)
            }
            .joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func appendField(name: String, value: String, boundary: String, to body: inout Data) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.append("\(value)\r\n")
    }

    private func appendFile(
        name: String,
        filename: String,
        mimeType: String,
        data: Data,
        boundary: String,
        to body: inout Data
    ) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n")
    }

    private func decodedAPIError(from data: Data) -> String? {
        try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data).error.message
    }

    private func normalizedWardrobeMetadata(from content: String) throws -> WardrobeItemMetadata {
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else {
            throw ServiceError.requestFailed("OpenAI did not return valid clothing details.")
        }

        let payload = try JSONDecoder().decode(OpenAIWardrobeMetadataPayload.self, from: data)
        let category = ClothingCategory(displayName: trimmed(payload.category))
        let name = trimmed(payload.name).isEmpty ? category.singularTitle : trimmed(payload.name)

        return WardrobeItemMetadata(
            name: name,
            category: category,
            colors: normalizedTags(payload.colors, limit: 4),
            styles: normalizedTags(payload.styles, limit: 3),
            materials: normalizedTags(payload.materials, limit: 3),
            seasons: normalizedTags(payload.seasons, limit: 4)
        )
    }

    private func normalizedOutfitSuggestions(from content: String, sourceItems: [WardrobeItem], maxCount: Int) throws -> [OutfitSuggestion] {
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else {
            throw ServiceError.requestFailed("OpenAI did not return valid outfit ideas.")
        }

        let payload = try JSONDecoder().decode(OpenAIOutfitSuggestionsPayload.self, from: data)
        let allowedItems = Dictionary(uniqueKeysWithValues: sourceItems.map { ($0.id.uuidString.lowercased(), $0) })
        return payload.outfits.prefix(maxCount).compactMap { outfit in
            let selectedItems = compatibleOutfitItems(from: (outfit.itemIDs ?? []).compactMap { allowedItems[$0.lowercased()] })
            guard !selectedItems.isEmpty else { return nil }
            let title = normalizedOutfitTitle(trimmed(outfit.title), selectedItems: selectedItems)
            return OutfitSuggestion(
                id: UUID(),
                title: title,
                date: Self.formattedDate(),
                match: min(max(outfit.match ?? 82, 0), 100),
                summary: trimmed(outfit.summary).isEmpty ? "A balanced outfit selected from your wardrobe for this request." : trimmed(outfit.summary),
                tips: exactlyThreeTips(outfit.tips),
                itemIDs: selectedItems.map(\.id),
                itemImageNames: selectedItems.map(\.imageName).filter { !$0.isEmpty },
                isFavorite: false
            )
        }
    }

    private func compatibleOutfitItems(from items: [WardrobeItem]) -> [WardrobeItem] {
        var selected: [WardrobeItem] = []
        var usedSlots: Set<String> = []
        var hasDress = false

        for item in items {
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
            if selected.count == 7 { break }
        }
        return selected
    }

    private func normalizedOutfitTitle(_ title: String, selectedItems: [WardrobeItem]) -> String {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = normalized.lowercased()
        if !normalized.isEmpty,
           !lowercased.hasPrefix("ai outfit idea") {
            return normalized
        }

        let anchor = selectedItems.first { $0.category == .dresses }
            ?? selectedItems.first { $0.category == .tops }
            ?? selectedItems.first
        if let anchorName = anchor?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !anchorName.isEmpty {
            return "\(anchorName) Look"
        }
        return "Wardrobe Look"
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

    private func exactlyThreeTips(_ tips: [String]?) -> [String] {
        var values = normalizedTags(tips, limit: 3)
        while values.count < 3 {
            let fallback = [
                "Keep the main outfit pieces visually balanced with simple accessories.",
                "Use one shared color between accessories and clothing for a cleaner look.",
                "Adjust layers based on the temperature before wearing the outfit."
            ][values.count]
            values.append(fallback)
        }
        return values
    }

    private func jsonString(from value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func normalizedStylingIntent(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "versatile everyday outfit" }

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
            return "versatile everyday outfit"
        }
        return trimmed
    }

    private static func formattedDate(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private func normalizedTags(_ values: [String]?, limit: Int) -> [String] {
        var seen: Set<String> = []
        return (values ?? [])
            .map { trimmed($0) }
            .filter { !$0.isEmpty }
            .filter { value in
                let key = value.lowercased()
                guard !seen.contains(key) else { return false }
                seen.insert(key)
                return true
            }
            .prefix(limit)
            .map { $0 }
    }

    private func trimmed(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct OpenAIImageResponse: Decodable {
    struct ImageData: Decodable {
        let b64JSON: String?

        enum CodingKeys: String, CodingKey {
            case b64JSON = "b64_json"
        }
    }

    let data: [ImageData]
}

private struct OpenAIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct OpenAIWardrobeMetadataPayload: Decodable {
    let name: String?
    let category: String?
    let colors: [String]?
    let styles: [String]?
    let materials: [String]?
    let seasons: [String]?
}

private struct OpenAIOutfitSuggestionsPayload: Decodable {
    struct Outfit: Decodable {
        let title: String?
        let match: Int?
        let summary: String?
        let tips: [String]?
        let itemIDs: [String]?

        enum CodingKeys: String, CodingKey {
            case title
            case match
            case summary
            case tips
            case itemIDs
            case itemIds
            case item_ids
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            match = try container.decodeIfPresent(Int.self, forKey: .match)
            summary = try container.decodeIfPresent(String.self, forKey: .summary)
            tips = try container.decodeIfPresent([String].self, forKey: .tips)
            itemIDs = try container.decodeIfPresent([String].self, forKey: .itemIDs)
                ?? container.decodeIfPresent([String].self, forKey: .itemIds)
                ?? container.decodeIfPresent([String].self, forKey: .item_ids)
        }
    }

    let outfits: [Outfit]
}

private extension ClothingCategory {
    var singularTitle: String {
        switch self {
        case .all:
            return "Clothing Item"
        case .tops:
            return "Top"
        case .bottoms:
            return "Bottom"
        case .dresses:
            return "Dress"
        case .bikinis:
            return "Bikini"
        case .socks:
            return "Socks"
        case .bags:
            return "Bag"
        case .custom(let title):
            return title
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
