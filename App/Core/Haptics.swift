import UIKit

/// 集中式触觉。六档，预热生成器，避免第一次点击的延迟。
/// 全 App 只从这里出发，便于统一静音与降频。
@MainActor
enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let note = UINotificationFeedbackGenerator()
    private static var lastFired: CFAbsoluteTime = 0

    /// 离散控件、选择器、Tab 切换。
    static func tap() {
        selection.selectionChanged()
        selection.prepare()
    }

    /// 柔和按压（卡片、胶囊）。
    static func soft() {
        lightImpact.impactOccurred(intensity: 0.6)
        lightImpact.prepare()
    }

    /// 提交类操作（保存、发送）。
    static func light() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// 连接成功/断开、面板收放。
    static func medium() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    /// 成功（构建完成、登录成功）。300ms 内不重复。
    static func success() {
        guard allow() else { return }
        note.notificationOccurred(.success)
    }

    /// 待审批、降级连接。
    static func warning() {
        guard allow() else { return }
        note.notificationOccurred(.warning)
    }

    /// 失败、鉴权错误。
    static func failure() {
        guard allow() else { return }
        note.notificationOccurred(.error)
    }

    /// 启动时预热。
    static func prepare() {
        selection.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
        note.prepare()
    }

    private static func allow() -> Bool {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFired > 0.3 else { return false }
        lastFired = now
        return true
    }
}
