import SwiftUI
import UIKit

/// 账号与余额：登录、余额、用量入口、退出。
struct AccountView: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var reveal = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if account.isSignedIn {
                        balanceCard
                        keyCard
                        signOutButton
                    } else {
                        signInCard
                    }

                    Text("Key 只存在这台手机的钥匙串里。登录账号或填 API Key，二选一即可使用 DeepSeek 模型。")
                        .font(DSH.TypeScale.footnote)
                        .foregroundStyle(DSH.Palette.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(DSH.Palette.canvas)
            .navigationTitle("账号与余额")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                if account.isSignedIn { await account.loadBalance() }
            }
        }
    }

    // MARK: - Balance

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(DSH.Palette.tertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("已登录 DeepSeek")
                        .font(DSH.TypeScale.headline)
                        .foregroundStyle(DSH.Palette.text)
                    Text(account.balanceError ?? "账号资料暂不可用")
                        .font(DSH.TypeScale.footnote)
                        .foregroundStyle(DSH.Palette.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                Link(destination: URL(string: "https://platform.deepseek.com")!) {
                    Text("更多账号信息 ↗")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DSH.Palette.secondary)
                }
            }

            Divider().overlay(DSH.Palette.hairline)

            HStack(alignment: .firstTextBaseline) {
                Text("充值余额")
                    .font(DSH.TypeScale.body)
                    .foregroundStyle(DSH.Palette.text)
                Spacer()
                Text(balanceText)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(DSH.Palette.text)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 10) {
                Link(destination: URL(string: "https://platform.deepseek.com/usage")!) {
                    Text("查询用量")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DSH.Palette.secondary)
                }

                Spacer()

                Link(destination: URL(string: "https://platform.deepseek.com/top_up")!) {
                    Text("充值")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(Color.white, in: Capsule())
                }

                Button {
                    Task { await account.loadBalance() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DSH.Palette.secondary)
                        .frame(width: 34, height: 34)
                        .background(DSH.Palette.surface, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var balanceText: String {
        guard let info = account.balance?.balance_infos?.first else { return "—" }
        let symbol = info.currency.uppercased() == "CNY" ? "¥" : "$"
        return symbol + info.total_balance
    }

    // MARK: - Key

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("API Key")
                    .font(DSH.TypeScale.body)
                    .foregroundStyle(DSH.Palette.text)
                Spacer()
                Text("已设置")
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.tertiary)
            }

            Text(masked)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(DSH.Palette.secondary)

            Button {
                account.signOut()
                input = ""
            } label: {
                Text("更换 Key")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DSH.Palette.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var signOutButton: some View {
        Button {
            account.signOut()
            Haptics.soft()
            dismiss()
        } label: {
            Text("退出登录")
                .font(DSH.TypeScale.body)
                .foregroundStyle(Color(hex: 0xFF6B6B))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Signed out

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("登录 DeepSeek")
                .font(DSH.TypeScale.title)
                .foregroundStyle(DSH.Palette.text)

            Text("在 platform.deepseek.com 建一个 Key，粘贴进来。登录后本机模式就能直接对话。")
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(DSH.Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Group {
                    if reveal {
                        TextField("sk-…", text: $input)
                    } else {
                        SecureField("sk-…", text: $input)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(DSH.Palette.text)

                Button {
                    reveal.toggle()
                } label: {
                    Image(systemName: reveal ? "eye.slash" : "eye")
                        .foregroundStyle(DSH.Palette.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                Task { await account.signIn(input) }
            } label: {
                HStack(spacing: 8) {
                    if case .checking = account.state {
                        ProgressView().tint(.white)
                    }
                    Text("登录")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DSH.Palette.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)

            if case .failed(let message) = account.state {
                Text(message)
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.danger)
            }

            Link("去建一个 Key", destination: URL(string: "https://platform.deepseek.com/api_keys")!)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSH.Palette.accent)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var masked: String {
        let key = account.key
        guard key.count > 10 else { return "sk-…" }
        return "\(key.prefix(6))…\(key.suffix(4))"
    }
}
