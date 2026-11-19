import SwiftUI

/// 启动动画：2.6 秒，一块玻璃面板在近黑石墨底上浮起，冰蓝/薄荷两团极慢的光，
/// 一次 14° 的高光掠过后字标浮现。
///
/// 克制规则（也是这份实现的原则）：
/// - 只有一个强调色（冰蓝），薄荷只作 5% 的冷侧补光；
/// - 玻璃只有一层，不叠第二层；
/// - 总位移 < 40px，没有弹跳、没有旋转；
/// - 减弱动态效果时去掉位移与缩放，只保留淡入，并把总时长压到 1.2s。
struct LaunchSequence: View {
    var onFinish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var glow: Double = 0
    @State private var panel: Double = 0
    @State private var sweep: Double = -1.1
    @State private var mark: Double = 0
    @State private var word: Double = 0
    @State private var tagline: Double = 0
    @State private var exiting = false

    private var duration: Double { reduceMotion ? 1.2 : 2.6 }

    var body: some View {
        ZStack {
            Fluid.Palette.obsidian.ignoresSafeArea()

            blobs

            VStack(spacing: 18) {
                glassPanel
                wordmark
                taglineText
            }
            .offset(y: reduceMotion ? 0 : -6)
        }
        .opacity(exiting ? 0 : 1)
        .scaleEffect(exiting && !reduceMotion ? 1.02 : 1)
        .ignoresSafeArea()
        .allowsHitTesting(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("NcnsDSH 正在启动")
        .onAppear(perform: play)
    }

    // MARK: - Pieces

    private var blobs: some View {
        GeometryReader { geo in
            let side = max(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Fluid.Palette.iceBlue.opacity(0.34), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: side * 0.42
                        )
                    )
                    .frame(width: side * 0.9, height: side * 0.9)
                    .position(x: geo.size.width * 0.30, y: geo.size.height * 0.66)
                    .opacity(glow)
                    .blur(radius: 40)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Fluid.Palette.mint.opacity(0.16), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: side * 0.36
                        )
                    )
                    .frame(width: side * 0.8, height: side * 0.8)
                    .position(x: geo.size.width * 0.74, y: geo.size.height * 0.40)
                    .opacity(glow * 0.8)
                    .blur(radius: 48)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var glassPanel: some View {
        ZStack {
            BrandMark(size: 92)
                .opacity(mark)
                .scaleEffect(reduceMotion ? 1 : CGFloat(0.92 + 0.08 * mark))

            // 14° 的单次高光：一条窄白带从左上掠到右下，扫完就不再出现。
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.30), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.6)
                .offset(x: sweep * geo.size.width * 1.1)
            }
            .mask(RoundedRectangle(cornerRadius: 46, style: .continuous))
            .allowsHitTesting(false)
        }
        .frame(width: 168, height: 168)
        .background {
            GlassBackground(shape: RoundedRectangle(cornerRadius: 46, style: .continuous), material: .ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.34), Color.white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: Fluid.Palette.iceBlue.opacity(0.18), radius: 40, y: 18)
        .scaleEffect(reduceMotion ? 1 : CGFloat(0.94 + 0.06 * panel))
        .opacity(panel)
        .rotationEffect(.degrees(reduceMotion ? 0 : -0.6))
    }

    private var wordmark: some View {
        HStack(spacing: 1.5) {
            ForEach(Array("NcnsDSH".enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .foregroundStyle(Fluid.Palette.text)
                    .opacity(word)
                    .offset(y: reduceMotion ? 0 : CGFloat((1 - word) * 8))
                    .animation(
                        reduceMotion
                            ? .easeOut(duration: 0.18).delay(Double(index) * 0.01)
                            : .easeOut(duration: 0.42).delay(Double(index) * 0.03),
                        value: word
                    )
            }
        }
    }

    private var taglineText: some View {
        Text("FLUID INTELLIGENCE")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(CGFloat(2 + 1.2 * tagline))
            .foregroundStyle(Fluid.Palette.mist)
            .opacity(tagline)
    }

    // MARK: - Timeline

    private func play() {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { glow = 1 }
            withAnimation(.easeOut(duration: 0.35).delay(0.1)) { panel = 1; mark = 1 }
            word = 1
            withAnimation(.easeOut(duration: 0.3).delay(0.45)) { tagline = 1 }
        } else {
            withAnimation(.easeOut(duration: 0.45)) { glow = 1 }
            withAnimation(.easeOut(duration: 0.6).delay(0.35)) { panel = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.85)) { mark = 1 }
            withAnimation(.easeInOut(duration: 0.62).delay(0.85)) { sweep = 1.1 }
            withAnimation(.easeOut(duration: 0.4).delay(1.45)) { word = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(1.9)) { tagline = 1 }
        }

        let exitAt = duration - 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + exitAt) {
            withAnimation(.easeInOut(duration: 0.2)) { exiting = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            onFinish()
        }
    }
}
