import Foundation
import SwiftUI
import Network
import UIKit
import Darwin

/// 进程级性能采样：内存、CPU、热状态、低电量模式、电池、网络。
/// 只用系统 API，不估算、不伪造延迟。
@MainActor
final class PerformanceCenter: ObservableObject {
    @Published private(set) var memoryMB: Double = 0
    @Published private(set) var cpuPercent: Double = 0
    @Published private(set) var thermal: ProcessInfo.ThermalState = .nominal
    @Published private(set) var lowPower = false
    @Published private(set) var batteryLevel: Float = -1
    @Published private(set) var networkStatus: NWPath.Status = .requiresConnection
    @Published private(set) var networkExpensive = false
    @Published private(set) var networkConstrained = false
    @Published private(set) var isWiFi = false
    @Published private(set) var updatedAt: Date = Date()

    private var timer: Timer?
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ncnsdsh.perf")

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.networkStatus = path.status
                self?.networkExpensive = path.isExpensive
                self?.networkConstrained = path.isConstrained
                self?.isWiFi = path.usesInterfaceType(.wifi)
            }
        }
        monitor.start(queue: queue)
    }

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        monitor.cancel()
    }

    private func sample() {
        memoryMB = Self.memoryFootprintMB()
        cpuPercent = Self.cpuUsage()
        thermal = ProcessInfo.processInfo.thermalState
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        batteryLevel = UIDevice.current.batteryLevel
        updatedAt = Date()
    }

    // MARK: - Memory

    private static func memoryFootprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1_048_576
    }

    // MARK: - CPU

    private static func cpuUsage() -> Double {
        var threads: thread_act_array_t?
        var count: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &threads, &count) == KERN_SUCCESS else { return 0 }
        defer {
            if let threads {
                let size = vm_size_t(Int(count) * MemoryLayout<thread_t>.stride)
                vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threads)), size)
            }
        }
        guard let threads else { return 0 }

        var total: Double = 0
        for index in 0..<Int(count) {
            var info = thread_basic_info()
            var infoCount = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
            let result = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(threads[index], thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                }
            }
            guard result == KERN_SUCCESS else { continue }
            if info.flags & TH_FLAGS_IDLE != 0 { continue }
            total += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100
        }
        return min(100, total)
    }

    // MARK: - Labels

    var thermalLabel: String {
        switch thermal {
        case .nominal: return "正常"
        case .fair: return "偏热"
        case .serious: return "过热"
        case .critical: return "临界"
        @unknown default: return "未知"
        }
    }

    var networkLabel: String {
        guard networkStatus == .satisfied else { return "离线" }
        return isWiFi ? "Wi-Fi" : "蜂窝"
    }

    var batteryLabel: String {
        batteryLevel < 0 ? "未知" : "\(Int(batteryLevel * 100))%"
    }

    var pressure: Int {
        // 只用来给 UI 一个粗略量级，不参与任何执行决策。
        if memoryMB > 600 { return 3 }
        if memoryMB > 350 { return 2 }
        if memoryMB > 200 { return 1 }
        return 0
    }
}
