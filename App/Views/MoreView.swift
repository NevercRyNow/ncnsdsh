import SwiftUI

/// 更多：插件、自动化、构建、设备、设置都收在这里，避免 Tab 无限增长。
struct MoreView: View {
    @EnvironmentObject private var plugins: PluginStore
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var store: HostStore
    @EnvironmentObject private var environment: EnvironmentManager

    /// 一个 sheet 入口。之前十个 .sheet(isPresented:) 挂在同一个视图上，
    /// SwiftUI 只保证一个能工作，偶尔就会出现「点了没反应 / 卡住」。
    private enum Panel: String, Identifiable {
        case plugins, automations, build, devices, settings, environment, performance, gallery, about, runtime
        var id: String { rawValue }
    }

    @State private var panel: Panel?


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                sectionTitle("工具")

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile("puzzlepiece.extension", "插件", "\(plugins.installed.count) 个已装") { panel = .plugins }
                    tile("arrow.triangle.2.circlepath", "自动化", "\(demo.schedules.count) 个定时") { panel = .automations }
                    tile("hammer", "构建", "GitHub Actions") { panel = .build }
                    tile("desktopcomputer", "设备", store.current == nil ? "未连接" : "已连接") { panel = .devices }
                    tile("speedometer", "性能", "内存 · 热状态") { panel = .performance }
                    tile("cpu", "本机运行时", "进程内") { panel = .runtime }
                }

                sectionTitle("环境")

                group {
                    row(icon: "point.3.connected.trianglepath.dotted", title: "当前环境", value: environment.current?.name ?? "这台 iPhone") {
                        panel = .environment
                    }
                }

                sectionTitle("系统")

                group {
                    row(icon: "gearshape", title: "设置", value: "") { panel = .settings }
                    divider
                    row(icon: "paintpalette", title: "设计系统", value: "色板 · 材质 · 动效") { panel = .gallery }
                    divider
                    row(icon: "info.circle", title: "关于", value: Bundle.main.appVersion) { panel = .about }
                }

                // 署名往上提、放大一点：它原来是行小灰字，正好被运行中的浮条压住。
                VStack(alignment: .leading, spacing: 3) {
                    Text("NcnsDSH")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(Fluid.Palette.text)
                    HStack(spacing: 6) {
                        Text("由郑壹鸣设计与开发")
                            .font(.system(size: 13))
                            .foregroundStyle(Fluid.Palette.mist)
                        Text("MIT")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Fluid.Palette.slate)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Fluid.Palette.graphite, in: Capsule())
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 10)
            }
            .padding(.horizontal, DSH.Inset.gutter)
            .padding(.top, 8)
            .padding(.bottom, 56)
        }
        .scrollIndicators(.hidden)
        .background(DSH.Palette.canvas)
        .navigationTitle("更多")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $panel) { panel in
            switch panel {
            case .plugins:
                PluginsView().environmentObject(plugins).environmentObject(store)
            case .automations:
                ScheduleView().environmentObject(demo)
            case .build:
                BuildView()
            case .devices:
                NavigationStack { DevicesView() }
            case .settings:
                SettingsView()
            case .environment:
                EnvironmentView().environmentObject(store).environmentObject(environment)
            case .performance:
                PerformanceView()
            case .gallery:
                DesignGalleryView()
            case .about:
                AboutView()
            case .runtime:
                LocalRuntimeView()
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Fluid.Palette.slate)
            .padding(.horizontal, 2)
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(DSH.Palette.hairline)
            .frame(height: 0.5)
            .padding(.leading, 56)
    }

    /// 工具目录里的方块：图标 + 名字 + 一行状态。和设置页的行式列表刻意不同。
    private func tile(_ icon: String, _ title: String, _ value: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Fluid.Palette.iceBlue)
                    .frame(width: 34, height: 34)
                    .background(Fluid.Palette.iceBlue.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Spacer(minLength: 4)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Fluid.Palette.text)
                Text(value)
                    .font(.system(size: 11))
                    .foregroundStyle(Fluid.Palette.mist)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .padding(14)
            .fluidSurface()
        }
        .buttonStyle(.plain)
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
        // 读屏把整行念成一句「插件，3 个已装」，而不是把 cpu、folder 这些装饰图标也念出来。
        .accessibilityElement(children: .combine)
    }
}
