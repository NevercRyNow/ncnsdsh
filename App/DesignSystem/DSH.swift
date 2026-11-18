import SwiftUI

/// Apple Music × Apple TV 方向的 token 层。新代码用它，旧代码里的 Theme 保持兼容。
enum DSH {
    enum Palette {
        static let canvas = Color.black
        static let surface = Color.white.opacity(0.06)
        static let raised = Color.white.opacity(0.10)
        static let hairline = Color.white.opacity(0.12)
        static let accent = Color(red: 0.039, green: 0.518, blue: 1.0) // #0A84FF, Apple blue
        static let text = Color.white.opacity(0.96)
        static let secondary = Color.white.opacity(0.60)
        static let tertiary = Color.white.opacity(0.36)
        static let success = Color(red: 0.196, green: 0.843, blue: 0.294)
        static let danger = Color(red: 1.0, green: 0.412, blue: 0.380)
        static let warning = Color(red: 0.878, green: 0.569, blue: 0.227) // #E0913A
        static let info = Color(red: 0.357, green: 0.553, blue: 0.937)
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
