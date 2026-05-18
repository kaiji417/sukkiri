import SwiftUI
import SwiftData

@main
struct SukkiriApp: App {

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [SessionRecord.self, AppStats.self])
    }
}

// MARK: - ルートナビゲーション

struct RootView: View {

    // 初回起動フラグ（UserDefaultsで十分な理由：SwiftData不要の軽量フラグ）
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            AppLayoutView()
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
            .transition(.opacity)
        }
    }
}
