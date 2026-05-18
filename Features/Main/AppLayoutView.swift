import SwiftUI

enum MainTabSelection: Hashable {
    case swipe
    case dashboard
}

struct AppLayoutView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: MainTabSelection = .swipe

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad or large screen layout
            NavigationSplitView {
                List(selection: $selection) {
                    NavigationLink(value: MainTabSelection.swipe) {
                        Label("スワイプ", systemImage: "square.stack")
                    }
                    NavigationLink(value: MainTabSelection.dashboard) {
                        Label("記録", systemImage: "chart.bar.xaxis")
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
                }
            }
            .tint(Color.accent)
        } else {
            // iPhone or compact screen layout
            MainTabView()
        }
    }
}

#Preview {
    AppLayoutView()
}
