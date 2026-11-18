import SwiftUI

@MainActor
struct RootView: View {
    @EnvironmentObject private var store: HostStore
    @StateObject private var demo = DemoStore()
    @StateObject private var router = AppRouter()
    @StateObject private var account = AccountStore()
    @StateObject private var local = LocalStore()
    @StateObject private var build = BuildStore()
    @StateObject private var plugins = PluginStore()
    @StateObject private var phone = PhoneAuth()
    @StateObject private var chrome = AppChrome()
    @StateObject private var settings = SettingsStore()
    @StateObject private var modelConfig = ModelConfigurationStore()
    @StateObject private var environment = EnvironmentManager()
    @StateObject private var performance = PerformanceCenter()

    var body: some View {
        MainShell()
            .environmentObject(router)
        .environmentObject(demo)
        .environmentObject(account)
        .environmentObject(local)
        .environmentObject(build)
        .environmentObject(plugins)
        .environmentObject(phone)
        .environmentObject(chrome)
        .environmentObject(settings)
        .environmentObject(modelConfig)
        .environmentObject(environment)
        .environmentObject(performance)
        .preferredColorScheme(settings.appearance.scheme ?? .dark)
        .animation(.easeInOut(duration: 0.24), value: store.current?.id)
        .onAppear {
            Haptics.prepare()
            // Siri / 快捷指令 / 小组件按下时，把意图交给当前窗口。
            NcnsIntentBridge.open = { target in
                router.handle(target, demo: demo)
            }
        }
        .onOpenURL { url in
            if url.host == "connect" {
                let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                let target = items?.first { $0.name == "url" }?.value ?? ""
                let token = items?.first { $0.name == "token" }?.value ?? ""
                if !target.isEmpty {
                    store.connect(address: target, token: token)
                    return
                }
            }
            if let route = Route.from(url) {
                router.open(route)
                return
            }
            if let target = NcnsIntentTarget.from(url) {
                router.handle(target, demo: demo)
            }
        }
    }
}

#Preview {
    RootView().environmentObject(HostStore())
}
