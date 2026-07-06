import SwiftUI
import UIKit

struct SmallDeviceAdaptation: Equatable {
    static let smallDeviceMaxHeight: CGFloat = 667
    static let compactTopInsetReduction: CGFloat = 36

    let screenSize: CGSize

    init(screenSize: CGSize = UIScreen.main.bounds.size) {
        self.screenSize = screenSize
    }

    var screenHeight: CGFloat {
        max(screenSize.width, screenSize.height)
    }

    var referenceHeight: CGFloat {
        let referenceWidth = OutfitTheme.Layout.referenceWidth
        let width = max(min(screenSize.width, screenSize.height), 1)
        return screenHeight / width * referenceWidth
    }

    var isSmallHeightDevice: Bool {
        screenHeight <= Self.smallDeviceMaxHeight
    }

    func value<T>(regular: T, small: T) -> T {
        isSmallHeightDevice ? small : regular
    }

    func scaled(_ value: CGFloat, smallMultiplier: CGFloat) -> CGFloat {
        isSmallHeightDevice ? value * smallMultiplier : value
    }

    func topAdjustedY(_ y: CGFloat) -> CGFloat {
        guard isSmallHeightDevice else { return y }
        guard (60...80).contains(y) else { return y }
        return y - Self.compactTopInsetReduction
    }

    func topAdjustedHeight(y: CGFloat, height: CGFloat) -> CGFloat {
        guard isSmallHeightDevice else { return height }
        guard (60...80).contains(y), height >= 40 else { return height }
        return max(32, height - 12)
    }

    func topInsetHeight(_ height: CGFloat) -> CGFloat {
        guard isSmallHeightDevice else { return height }
        return max(0, height - Self.compactTopInsetReduction)
    }

    func underHeaderY(_ y: CGFloat) -> CGFloat {
        guard isSmallHeightDevice else { return y }
        return y - Self.compactTopInsetReduction
    }

    func underHeaderHeight(_ height: CGFloat) -> CGFloat {
        guard isSmallHeightDevice else { return height }
        return height + Self.compactTopInsetReduction
    }

    func scrollBottomPadding(_ regular: CGFloat = 118) -> CGFloat {
        value(regular: regular, small: 206)
    }

    func bottomPinnedY(_ y: CGFloat, height: CGFloat, bottomMargin: CGFloat = 24) -> CGFloat {
        guard isSmallHeightDevice else { return y }
        return min(y, max(0, referenceHeight - height - bottomMargin))
    }
}

private struct SmallDeviceAdaptationKey: EnvironmentKey {
    static let defaultValue = SmallDeviceAdaptation()
}

extension EnvironmentValues {
    var smallDeviceAdaptation: SmallDeviceAdaptation {
        get { self[SmallDeviceAdaptationKey.self] }
        set { self[SmallDeviceAdaptationKey.self] = newValue }
    }
}

extension CGSize {
    var isSmallHeightDevice: Bool {
        SmallDeviceAdaptation(screenSize: self).isSmallHeightDevice
    }
}
