import SwiftUI

/// 更多：插件、自动化、构建、设备、设置都收在这里，避免 Tab 无限增长。
struct MoreView: View {
    @EnvironmentObject private var plugins: PluginStore
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var store: HostStore
    @EnvironmentObject private var environment: EnvironmentManager

    @State private var showPlugins = false
    @State private var showAutomations = false
    @State private var showBuild = false
    @State private var showDevices = false
    @State private var showSettings = false
    @State private var showEnvironment = false
    @State private var showPerformance = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                group {
                    row(icon: "puzzlepiece.extension", title: "插件", value: "\(plugins.installed.count) 个") {
                        showPlugins = true
                    }
                    divider
                    row(icon: "arrow.triangle.2.circlepath", title: "自动化", value: "\(demo.schedules.count) 个") {
                        showAutomations = true
                    }
                }

                group {
                    row(icon: "hammer", title: "构建", value: "IPA") { showBuild = true }
                    divider
                    row(icon: "desktopcomputer", title: "设备", value: store.current == nil ? "未连接" : "已连接") { showDevices = true }
                    divider
                    row(icon: "gearshape", title: "设置", value: "") { showSettings = true }
                }

                group {
                    row(icon: "point.3.connected.trianglepath.dotted", title: "环境", value: environment.current?.name ?? "这台 iPhone") {
                        showEnvironment = true
                    }
                    divider
                    row(icon: "speedometer", title: "性能", value: "") {
                        showPerformance = true
                    }
                }

                Text("NcnsDSH 2.0 · 由郑壹鸣设计与开发")
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
            }
            .padding(.horizontal, DSH.Inset.gutter)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(DSH.Palette.canvas)
        .navigationTitle("更多")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPlugins) {
            PluginsView().environmentObject(plugins)
        }
        .sheet(isPresented: $showAutomations) {
            ScheduleView().environmentObject(demo)
        }
        .sheet(isPresented: $showBuild) {
            BuildView()
        }
        .sheet(isPresented: $showDevices) {
            NavigationStack { DevicesView() }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showEnvironment) {
            EnvironmentView().environmentObject(store).environmentObject(environment)
        }
        .sheet(isPresented: $showPerformance) {
            PerformanceView()
        }
    }

    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(DSH.Palette.hairline)
            .frame(height: 0.5)
            .padding(.leading, 54)
    }

    private func row(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            rowContent(icon: icon, title: title, value: value)
        }
        .buttonStyle(.plain)
    }

    private func rowContent(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(DSH.Palette.text)
                .frame(width: 26)

            Text(title)
                .font(DSH.TypeScale.body)
                .foregroundStyle(DSH.Palette.text)

            Spacer()

            Text(value)
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(DSH.Palette.tertiary)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DSH.Palette.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
