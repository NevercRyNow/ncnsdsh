import SwiftUI

/// 工作台：终端 / 文件 / 浏览器 / 改动 / 上下文，一个 sheet 装下。
struct WorkbenchView: View {
    let sessionID: UUID?

    enum Tab: String, CaseIterable, Identifiable {
        case terminal = "终端"
        case files = "文件"
        case browser = "浏览器"
        case changes = "改动"
        case context = "上下文"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .terminal

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider().overlay(DSH.Palette.hairline)

            Group {
                switch tab {
                case .terminal:
                    TerminalPane()
                case .files:
                    FileBrowserPane()
                case .browser:
                    BrowserPane()
                case .changes:
                    FileBrowserPane(sortByDate: true, title: "最近改动")
                case .context:
                    ContextPane(sessionID: sessionID)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DSH.Palette.canvas.ignoresSafeArea())
        .navigationTitle("工作台")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        ZStack {
            Text("工作台")
                .font(DSH.TypeScale.headline)
                .foregroundStyle(DSH.Palette.text)

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DSH.Palette.text)
                        .frame(width: 32, height: 32)
                        .background(DSH.Palette.raised, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var tabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Tab.allCases) { item in
                    Button {
                        withAnimation(DSH.Motion.snap) { tab = item }
                        Haptics.tap()
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 14, weight: tab == item ? .semibold : .regular))
                            .foregroundStyle(tab == item ? Color.black : DSH.Palette.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(tab == item ? Color.white : Color.clear)
                            )
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
