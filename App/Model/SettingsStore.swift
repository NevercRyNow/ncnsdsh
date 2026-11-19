import SwiftUI
import AVFoundation

/// 后台存活：放一段静音音频，App 退到后台也不被挂起。
/// 需要 Info.plist 里的 `UIBackgroundModes = audio`。
final class BackgroundKeeper {
    static let shared = BackgroundKeeper()

    private var player: AVAudioPlayer?
    private var active = false

    func apply(silentAudio: Bool, keepRunning: Bool) {
        setActive(silentAudio || keepRunning)
    }

    private func setActive(_ next: Bool) {
        guard next != active else { return }
        active = next

        if next {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                let player = try AVAudioPlayer(data: Self.silentWave(seconds: 1))
                player.numberOfLoops = -1
                player.volume = 0
                player.prepareToPlay()
                player.play()
                self.player = player
            } catch {
                active = false
            }
        } else {
            player?.stop()
            player = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    /// 44 字节 WAV 头 + 全零采样。
    private static func silentWave(seconds: Int) -> Data {
        let sampleRate = 8_000
        let samples = sampleRate * seconds
        let dataBytes = samples * 2
        var data = Data()

        func append(_ string: String) { data.append(contentsOf: Array(string.utf8)) }
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF")
        append32(UInt32(36 + dataBytes))
        append("WAVE")
        append("fmt ")
        append32(16)
        append16(1)
        append16(1)
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * 2))
        append16(2)
        append16(16)
        append("data")
        append32(UInt32(dataBytes))
        data.append(Data(count: dataBytes))
        return data
    }
}

/// 设置项：全部落 UserDefaults。
@MainActor
final class SettingsStore: ObservableObject {
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "跟随系统"
            case .light: return "浅色"
            case .dark: return "深色"
            }
        }
        var scheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    enum Language: String, CaseIterable, Identifiable {
        case system, zh, en
        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "跟随系统"
            case .zh: return "简体中文"
            case .en: return "English"
            }
        }
    }

    @Published var silentAudio: Bool { didSet { save(); syncKeeper() } }
    @Published var keepRunning: Bool { didSet { save(); syncKeeper() } }
    @Published var showSessionTitles: Bool { didSet { save() } }
    /// 新会话用哪条通道：直连 DeepSeek API，还是 App 内置的 dsh-go 引擎。
    enum EngineChoice: String, CaseIterable, Identifiable {
        case cloud
        case embedded
        var id: String { rawValue }
        var label: String {
            switch self {
            case .cloud: return "云端 API"
            case .embedded: return "内置引擎"
            }
        }
        var detail: String {
            switch self {
            case .cloud: return "直连 api.deepseek.com，需要 API Key。"
            case .embedded: return "用包里内置的 dsh-go 引擎（AGPL），不起网页。"
            }
        }
    }

    @Published var engineChoice: EngineChoice { didSet { save() } }
    @Published var appearance: Appearance { didSet { save() } }
    @Published var language: Language { didSet { save() } }

    private let defaults = UserDefaults.standard

    init() {
        silentAudio = defaults.bool(forKey: "settings.silentAudio")
        keepRunning = defaults.bool(forKey: "settings.keepRunning")
        showSessionTitles = defaults.object(forKey: "settings.showSessionTitles") as? Bool ?? true
        engineChoice = EngineChoice(rawValue: defaults.string(forKey: "settings.engine") ?? "") ?? .cloud
        appearance = Appearance(rawValue: defaults.string(forKey: "settings.appearance") ?? "") ?? .system
        language = Language(rawValue: defaults.string(forKey: "settings.language") ?? "") ?? .system
        syncKeeper()
    }

    private func save() {
        defaults.set(silentAudio, forKey: "settings.silentAudio")
        defaults.set(keepRunning, forKey: "settings.keepRunning")
        defaults.set(showSessionTitles, forKey: "settings.showSessionTitles")
        defaults.set(engineChoice.rawValue, forKey: "settings.engine")
        defaults.set(appearance.rawValue, forKey: "settings.appearance")
        defaults.set(language.rawValue, forKey: "settings.language")
    }

    private func syncKeeper() {
        BackgroundKeeper.shared.apply(silentAudio: silentAudio, keepRunning: keepRunning)
    }
}
