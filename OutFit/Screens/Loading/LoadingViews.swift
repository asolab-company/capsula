import SwiftUI

struct SplashLoadingView: View {
    var body: some View {
        AppCanvas {
            RoundedRectangle(cornerRadius: 44)
                .fill(Color.white)
                .overlay(AppIcon(name: "app_ic_ailogo", size: 96))
                .appFrame(x: 96, y: 326, w: 200, h: 200)
        }
    }
}

#Preview {
    SplashLoadingView()
}
