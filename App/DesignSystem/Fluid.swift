import SwiftUI
import UIKit

/// Fluid Intelligence 的语义 token 层。
///
/// 和 `DSH.Palette`（硬编码纯黑）的区别：这里的每个颜色都是 UIColor 动态色，
/// 浅色和深色各有一套值，不是把深色反相。新页面用它；旧页面按阶段迁移。
enum Fluid {
    enum Palette {
        /// 主画布：深石墨，不是纯黑。
        static let obsidian = adaptive(dark: 0x0B0C0F, light: 0xF5F5F7)
        /// 次级背景 / 内容块。
        static let graphite = adaptive(dark: 0x14161A, light: 0xEBECEF)
        /// 正文。
        static let text = adaptive(dark: 0xF2F3F5, light: 0x14161A)
        /// 次级文字。
        static let mist = translucent(dark: 0.60, light: 0.58)
        /// 辅助文字与细线。
        static let slate = translucent(dark: 0.30, light: 0.28)
        /// 品牌强调色：冰蓝。克制使用，只给当前状态和主操作。
        static let iceBlue = adaptive(dark: 0x64B5FF, light: 0x0A6CFF)
        /// 运行正常 / 成功。
        static let mint = adaptive(dark: 0x3DDC84, light: 0x0E7A38)
        /// 等待 / 需要注意。
        static let amber = adaptive(dark: 0xE8A33D, light: 0xA65D00)
        /// 失败 / 破坏性操作。
        static let coral = adaptive(dark: 0xFF6B6B, light: 0xC4271E)
        /// 技术内容的分隔线。
        static let hairline = translucent(dark: 0.10, light: 0.12)
    }

    enum Shape {
        /// 主面板。
        static let panel: CGFloat = 22
        /// 卡片 / 分组。
        static let card: CGFloat = 16
        /// 小控件。
        static let control: CGFloat = 12
    }

    /// 动效按「交互目的」分，不给所有控件套同一个弹簧。
    /// 时长区间来自设计指令 5.3：按压 90–140ms、轻量选择 150–220ms、
    /// 面板 280–420ms、Dock 320–480ms、空间转换 350–550ms、状态 180–300ms。
    enum Motion {
        static let press = Animation.spring(response: 0.12, dampingFraction: 0.86)
        static let select = Animation.spring(response: 0.18, dampingFraction: 0.84)
        static let panel = Animation.spring(response: 0.34, dampingFraction: 0.86)
        static let dock = Animation.spring(response: 0.40, dampingFraction: 0.82)
        static let spatial = Animation.spring(response: 0.46, dampingFraction: 0.88)
        static let state = Animation.easeInOut(duration: 0.24)

        /// Reduce Motion 下不播放位移/缩放，只留一个短的淡入。
        static func respecting(_ reduceMotion: Bool, _ animation: Animation) -> Animation {
            reduceMotion ? .easeOut(duration: 0.18) : animation
        }
    }

    /// 语义字号。全部走 Dynamic Type，技术内容用等宽数字。
    enum Typography {
        static let display = Font.system(.largeTitle, design: .default).weight(.bold)
        static let section = Font.system(.caption, design: .default).weight(.semibold)
        static let body = Font.system(.body)
        static let secondary = Font.system(.footnote)
        static let caption = Font.system(.caption2)
        static let technical = Font.system(.callout, design: .monospaced)
        static let numeric = Font.system(.body, design: .monospaced).monospacedDigit()
    }

    private static func adaptive(dark: UInt32, light: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            UIColor(rgb: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func translucent(dark: Double, light: Double) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: dark)
                : UIColor(white: 0, alpha: light)
        })
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// 内容层表面：实色或常规材质，**不是** Liquid Glass。
/// HIG 明确要求内容层不用玻璃，玻璃只留给导航、浮动控件和 Dock。
private struct FluidSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    shape.fill(Fluid.Palette.graphite)
                } else {
                    shape.fill(Fluid.Palette.graphite.opacity(contrast == .increased ? 1 : 0.86))
                }
            }
            .overlay(
                shape.strokeBorder(Fluid.Palette.slate.opacity(contrast == .increased ? 0.9 : 0.45), lineWidth: 0.5)
            )
    }
}

extension View {
    /// 内容块表面。分组、卡片、列表容器用它，别用玻璃。
    func fluidSurface(cornerRadius: CGFloat = Fluid.Shape.card) -> some View {
        modifier(FluidSurface(cornerRadius: cornerRadius))
    }
}
