import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            MainSwipeView()
                .tabItem {
                    Label("スワイプ", systemImage: "square.stack")
                }

            DashboardView()
                .tabItem {
                    Label("記録", systemImage: "chart.bar.xaxis")
                }

            ToolsView()
                .tabItem {
                    Label("ツール", systemImage: "wrench.and.screwdriver")
                }
        }
        .tint(Color.accent)
    }
}

#Preview {
    MainTabView()
}
