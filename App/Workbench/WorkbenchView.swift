import SwiftUI

/// 工作台：终端 / 文件 / 浏览器 / 改动 / 上下文。
///
/// 三件事在这里做对：
/// 1. 切换工具只换内容，不重建视图——已经打开过的 pane 留在 ZStack 里，
///    终端的滚动位置、浏览器的页面、文件的当前目录都不会因为切走再切回而丢；
/// 2. 选中胶囊用 matchedGeometryEffect 连续滑动，不是每个标签自己换色；
/// 3. 专注模式：收起标题和标签栏，把当前 pane 铺满，再点一次回来。
struct WorkbenchView: View {
    let sessionID: UUID?

    enum Tab: String, CaseIterable, Identifiable {
        case terminal = "终端"
        case files = "文件"
        case browser = "浏览器"
        case changes = "改动"
        case context = "上下文"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .terminal: return "terminal"
            case .files: return "folder"
            case .browser: return "globe"
            case .changes: return "plusminus.circle"
            case .context: return "square.stack.3d.up"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tab: Tab = .terminal
    @State private var visited: Set<Tab> = [.terminal]
    @State private var focus = false
    @Namespace private var indicator

    private var motion: Animation {
        Fluid.Motion.respecting(reduceMotion, Fluid.Motion.panel)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !focus {
                header
                tabBar
                Divider().overlay(Fluid.Palette.hairline)
            }

            panes
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    if focus {
                        exitFocusButton
                    }
                }
        }
        .background(Fluid.Palette.canvas.ignoresSafeArea())
        .animation(Fluid.Motion.respecting(reduceMotion, Fluid.Motion.spatial), value: focus)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityLabel("工作台")
    }

    // MARK: - Panes

    private var panes: some View {
        ZStack {
            ForEach(Tab.allCases) { item in
                if visited.contains(item) {
                    pane(item)
                        .opacity(tab == item ? 1 : 0)
                        .allowsHitTesting(tab == item)
                        .accessibilityHidden(tab != item)
                        .zIndex(tab == item ? 1 : 0)
                }
            }
        }
    }

    @ViewBuilder
    private func pane(_ item: Tab) -> some View {
        switch item {
        case .terminal: TerminalPane()
        case .files: FileBrowserPane()
        case .browser: BrowserPane()
        case .changes: DiffPane()
        case .context: ContextPane(sessionID: sessionID)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("工作台")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Fluid.Palette.text)

            Spacer()

            Button {
                focus = true
                Haptics.tap()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Fluid.Palette.mist)
                    .frame(width: 32, height: 32)
                    .background(Fluid.Palette.graphite, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("进入专注模式")

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Fluid.Palette.text)
                    .frame(width: 32, height: 32)
                    .background(Fluid.Palette.raised, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭工作台")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var exitFocusButton: some View {
        Button {
            focus = false
            Haptics.tap()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 10, weight: .bold))
                Text("退出专注")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Fluid.Palette.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Fluid.Palette.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(12)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(Tab.allCases) { item in
                    let selected = item == tab

                    Button {
                        guard !selected else { return }
                        visited.insert(item)
                        withAnimation(motion) { tab = item }
                        Haptics.tap()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 11, weight: .medium))
                            Text(item.rawValue)
                                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                        }
                        .foregroundStyle(selected ? Fluid.Palette.text : Fluid.Palette.mist)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            if selected {
                                Capsule(style: .continuous)
                                    .fill(Fluid.Palette.iceBlue.opacity(0.16))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(Fluid.Palette.iceBlue.opacity(0.45), lineWidth: 0.5)
                                    )
                                    .matchedGeometryEffect(id: "workbench.tab", in: indicator)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
}
