import SwiftUI
import UIKit

/// NcnsDSH 的视觉基调：近黑影院底 + 靛蓝/薄荷双色强调。
/// 旧名字（paper/card/muted/markGradient）保留，网页兜底页还在用。
enum Theme {
    static let accent = adaptive(dark: 0x0A84FF, light: 0x0A6CFF)
    static let mint = adaptive(dark: 0x32D74B, light: 0x1B7A2F)

    // 深色值与旧版逐值一致（近黑底 + 白色透明度分层），浅色另配一套。
    static let ink = adaptive(dark: 0x000000, light: 0xF5F5F7)
    static let paper = adaptive(dark: 0x000000, light: 0xF5F5F7)
    static let card = overlay(dark: 0.06, light: 0.04)
    static let raised = overlay(dark: 0.10, light: 0.06)
    static let hairline = overlay(dark: 0.12, light: 0.10)
    static let muted = overlay(dark: 0.60, light: 0.62)
    static let dim = overlay(dark: 0.36, light: 0.44)

    private static func adaptive(dark: UInt32, light: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            UIColor(rgb: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func overlay(dark: Double, light: Double) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: dark)
                : UIColor(white: 0, alpha: light)
        })
    }

    static let markGradient = LinearGradient(
        colors: [accent, Color(hex: 0x8C61FA)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let liveGradient = LinearGradient(
        colors: [accent, mint],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// 给会话生成一张「封面」：没有真图时用它，色彩按 index 轮转。
    static func artwork(_ index: Int) -> LinearGradient {
        let palettes: [[UInt32]] = [
            [0x2B3A67, 0x5B8CFF],
            [0x233B34, 0x57E0B8],
            [0x3A2340, 0x9B6BFF],
            [0x402A22, 0xFF9F6B],
            [0x1F3239, 0x5BD6E8],
            [0x3B2333, 0xE86B9B],
        ]
        let pair = palettes[abs(index) % palettes.count]
        return LinearGradient(
            colors: [Color(hex: pair[0]), Color(hex: pair[1])],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}


enum Motion {
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.72)
    static let panel = Animation.spring(response: 0.42, dampingFraction: 0.84)
    static let gentle = Animation.easeOut(duration: 0.22)

    static func spring(_ response: Double, _ damping: Double) -> Animation {
        .spring(response: response, dampingFraction: damping)
    }
}
