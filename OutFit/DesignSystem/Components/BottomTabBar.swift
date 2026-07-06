import SwiftUI

struct BottomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        AppBottomTabBar(selectedTab: $selectedTab)
            .frame(width: 393, height: 70)
    }
}
