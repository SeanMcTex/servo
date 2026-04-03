import Foundation
import IOKit.ps

struct BatteryInfo {
    let percent: Int
    let isCharging: Bool
    let isOnAC: Bool

    /// Returns nil on desktop Macs with no battery.
    nonisolated static func current() -> BatteryInfo? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        guard let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any]
        else { return nil }

        let percent   = info[kIOPSCurrentCapacityKey] as? Int ?? 0
        let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
        let onAC      = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue

        return BatteryInfo(percent: percent, isCharging: isCharging, isOnAC: onAC)
    }

    nonisolated var contextString: String {
        if isOnAC && percent >= 99 { return "Plugged in (full)" }
        if isCharging              { return "Battery: \(percent)% charging" }
        return "Battery: \(percent)% on battery"
    }
}
