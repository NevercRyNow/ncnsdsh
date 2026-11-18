import SwiftUI

/// Liquid Command Dock：悬浮的玻璃导航条，替代系统 TabBar 的外观。
///
/// 分工照 HIG：这一层是功能层，可以用玻璃；里面的内容（图标、文字）是实色。
/// 选中区用 matchedGeometryEffect 连续滑动，而不是每个图标自己换色。
struct LiquidDock: View {
    @Binding var selection: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var indicator

    private var motion: Animation {
        Fluid.Motion.respecting(reduceMotion, Fluid.Motion.dock)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                item(tab)
            }
        }
        .padding(6)
        .background {
            if reduceMotion {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Fluid.Palette.graphite)
            } else {
                GlassBackground(
                    shape: RoundedRectangle(cornerRadius: 26, style: .continuous),
                    material: .regularMaterial
                )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Fluid.Palette.slate.opacity(0.35), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.30), radius: 22, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    let dx = value.translation.width
                    guard abs(dx) > 40 else { return }
                    step(dx < 0 ? 1 : -1)
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("主导航")
    }

    private func item(_ tab: AppTab) -> some View {
        let selected = tab == selection

        return Button {
            guard !selected else { return }
            withAnimation(motion) { selection = tab }
            Haptics.tap()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 15, weight: selected ? .semibold : .regular))
                    .frame(width: 22)

                if selected {
                    Text(tab.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .foregroundStyle(selected ? Fluid.Palette.text : Fluid.Palette.mist)
            .padding(.horizontal, selected ? 12 : 10)
            .padding(.vertical, 9)
            .frame(height: 40)
            .background {
                if selected {
                    Capsule(style: .continuous)
                        .fill(Fluid.Palette.iceBlue.opacity(0.16))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Fluid.Palette.iceBlue.opacity(0.45), lineWidth: 0.5)
                        )
                        .matchedGeometryEffect(id: "dock.selected", in: indicator)
                }
            }
        }
        .buttonStyle(DockButtonStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .contextMenu {
            ForEach(AppTab.allCases) { target in
                Button {
                    withAnimation(motion) { selection = target }
                } label: {
                    Label(target.title, systemImage: target.symbol)
                }
                .disabled(target == selection)
            }
        }
    }

    private func step(_ delta: Int) {
        let all = AppTab.allCases
        guard let index = all.firstIndex(of: selection) else { return }
        let next = min(max(index + delta, 0), all.count - 1)
        guard next != index else { return }
        withAnimation(motion) { selection = all[next] }
        Haptics.light()
    }
}

/// 按下时往回收 4%，松手回弹。重量比系统按钮略重一点。
private struct DockButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(Fluid.Motion.press, value: configuration.isPressed)
    }
}
