import SwiftUI
import UIKit

/// NcnsDSH 的视觉基调：近黑影院底 + 靛蓝/薄荷双色强调。
/// 旧名字（paper/card/muted/markGradient）保留，网页兜底页还在用。
enum Theme {
    static let accent = Color(hex: 0x0A84FF)
    static let mint = Color(hex: 0x32D74B)

    static let ink = Color.black
    static let paper = Color.black
    static let card = Color.white.opacity(0.06)
    static let raised = Color.white.opacity(0.10)
    static let hairline = Color.white.opacity(0.12)
    static let muted = Color.white.opacity(0.60)
    static let dim = Color.white.opacity(0.36)

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
