import SwiftUI
import UIKit

/// Apple Music × Apple TV 方向的 token 层。新代码用它，旧代码里的 Theme 保持兼容。
///
/// 深色值与 2.16.x 完全一致，所以深色观感不变；浅色是新补的一套，不是把深色反相。
/// 这两套值都走 UIColor 动态色，用户切换外观时整页立刻跟着变。
enum DSH {
    enum Palette {
        static let canvas = adaptive(dark: 0x0B0C0F, light: 0xF5F5F7)
        static let surface = overlay(dark: 0.06, light: 0.04)
        static let raised = overlay(dark: 0.10, light: 0.06)
        static let hairline = overlay(dark: 0.12, light: 0.10)
        static let accent = adaptive(dark: 0x0A84FF, light: 0x0A6CFF)
        static let text = adaptive(dark: 0xF5F5F7, light: 0x14161A)
        static let secondary = overlay(dark: 0.60, light: 0.62)
        static let tertiary = overlay(dark: 0.36, light: 0.44)
        static let success = adaptive(dark: 0x32D74B, light: 0x1B7A2F)
        static let danger = adaptive(dark: 0xFF6A61, light: 0xC4271E)
        static let warning = adaptive(dark: 0xE0913A, light: 0xA65D00)
        static let info = adaptive(dark: 0x5B8DEF, light: 0x2857C4)

        private static func adaptive(dark: UInt32, light: UInt32) -> Color {
            Color(uiColor: UIColor { trait in
                UIColor(rgb: trait.userInterfaceStyle == .dark ? dark : light)
            })
        }

        /// 半透明层：深色用白、浅色用黑，和原来深色下的数值对齐。
        private static func overlay(dark: Double, light: Double) -> Color {
            Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(white: 1, alpha: dark)
                    : UIColor(white: 0, alpha: light)
            })
        }
    }

    enum Radius {
        static let card: CGFloat = 12
        static let small: CGFloat = 8
        static let sheet: CGFloat = 22
    }

    enum Inset {
        static let gutter: CGFloat = 20
        static let row: CGFloat = 12
        static let tight: CGFloat = 8
    }

    enum Motion {
        static let snap = Animation.spring(response: 0.28, dampingFraction: 0.86)
        static let flow = Animation.spring(response: 0.42, dampingFraction: 0.90)
        static let fade = Animation.easeOut(duration: 0.18)
    }

    /// 全部走 Dynamic Type：给 TextStyle，不给死字号。
    enum TypeScale {
        static let display = Font.system(.largeTitle, design: .default).weight(.bold)
        static let title = Font.system(.title2, design: .default).weight(.semibold)
        static let headline = Font.system(.headline, design: .default)
        static let body = Font.system(.body, design: .default)
        static let callout = Font.system(.callout, design: .default)
        static let footnote = Font.system(.footnote, design: .default)
        static let caption = Font.system(.caption2, design: .default)
    }
}
