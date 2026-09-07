import SwiftUI
import WeatherKit

/// Keep the attribution visible next to every display of Apple Weather data.
struct WeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    var attribution: WeatherAttribution?

    private var markURL: URL? {
        // WeatherKit variants correspond to the background appearance.
        colorScheme == .dark ? attribution?.combinedMarkDarkURL : attribution?.combinedMarkLightURL
    }

    private var legalURL: URL {
        attribution?.legalPageURL
            ?? URL(string: "https://developer.apple.com/weatherkit/data-source-attribution/")!
    }

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: markURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    // The trademark remains visible while offline or while the official mark loads.
                    Text(" Weather")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 86, height: 20)
            .accessibilityLabel("Apple Weather")

            Link(destination: legalURL) {
                Text("Weather data sources")
                    .font(.system(size: 12))
                    .underline()
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("weatherDataSources")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
