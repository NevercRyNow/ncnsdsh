import SwiftUI

/// 对话输入栏：Codex 桌面那种「一张圆角卡，上面写字，下面一排工具」的布局。
/// 底板用液态玻璃；旧系统自动退化成 .ultraThinMaterial。
struct ComposerBar: View {
    @Binding var text: String
    var placeholder: String = "问点什么…"
    var model: String = "deepseek-chat"
    var isBusy = false
    var onSend: () -> Void
    var onAttach: (() -> Void)?
    var onModel: (() -> Void)?
    var onQueue: (() -> Void)?

    @FocusState.Binding var focused: Bool

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
    }

    private var canQueue: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isBusy && onQueue != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .font(DSH.TypeScale.body)
                .foregroundStyle(DSH.Palette.text)
                .tint(DSH.Palette.accent)
                .focused($focused)
                .padding(.horizontal, 4)
                .padding(.top, 4)

            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    onAttach?()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DSH.Palette.secondary)
                        .frame(width: 28, height: 28)
                        .background(DSH.Palette.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(onAttach == nil)
                .opacity(onAttach == nil ? 0.4 : 1)

                Button {
                    Haptics.tap()
                    onModel?()
                } label: {
                    HStack(spacing: 4) {
                        Text(model)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(DSH.Palette.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(DSH.Palette.surface, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(onModel == nil)

                Spacer(minLength: 8)

                Button {
                    if isBusy {
                        guard canQueue else { return }
                        Haptics.light()
                        onQueue?()
                        return
                    }
                    guard canSend else { return }
                    Haptics.soft()
                    onSend()
                } label: {
                    Image(systemName: isBusy ? "text.badge.plus" : "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(isBusy ? (canQueue ? DSH.Palette.warning : Color.white.opacity(0.12)) : (canSend ? DSH.Palette.accent : Color.white.opacity(0.12)))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend && !canQueue)
                .animation(DSH.Motion.snap, value: canSend)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            GlassBackground(
                shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                tint: focused ? DSH.Palette.accent.opacity(0.10) : nil,
                interactive: true
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    focused ? DSH.Palette.accent.opacity(0.35) : DSH.Palette.hairline,
                    lineWidth: 0.5
                )
        )
        .animation(DSH.Motion.fade, value: focused)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .padding(.top, 4)
    }
}
