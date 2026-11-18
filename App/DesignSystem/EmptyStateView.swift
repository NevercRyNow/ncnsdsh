import SwiftUI

/// 统一空状态：符号 + 标题 + 一句说明 + 一个真实入口。
struct EmptyStateView: View {
    var symbol: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(DSH.Palette.tertiary)

            Text(title)
                .font(DSH.TypeScale.headline)
                .foregroundStyle(DSH.Palette.text)

            Text(message)
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(DSH.Palette.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(DSH.Palette.accent, in: Capsule())
                    .buttonStyle(.plain)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
