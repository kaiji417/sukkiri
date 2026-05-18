import SwiftUI

enum MainTabSelection: Hashable {
    case swipe
    case dashboard
    case tools
}

struct AppLayoutView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: MainTabSelection?

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List(selection: $selection) {
                    NavigationLink(value: MainTabSelection.swipe) {
                        Label("スワイプ", systemImage: "square.stack")
                    }
                    NavigationLink(value: MainTabSelection.dashboard) {
                        Label("記録", systemImage: "chart.bar.xaxis")
                    }
                    NavigationLink(value: MainTabSelection.tools) {
                        Label("ツール", systemImage: "wrench.and.screwdriver")
                    }
                }
                .navigationTitle("メニュー")
                .listStyle(.sidebar)
            } detail: {
                switch selection {
                case .swipe:
                    MainSwipeView()
                case .dashboard:
                    DashboardView()
                case .tools:
                    ToolsView()
                case nil:
                    MainSwipeView()
                }
            }
            .tint(Color.accent)
        } else {
            MainTabView()
        }
    }
}

#Preview {
    AppLayoutView()
}
