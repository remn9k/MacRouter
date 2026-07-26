import Foundation
import ServiceManagement

public class AutoStartManager {
    public static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }
    
    public static func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                return true
            } catch {
                print("[AutoStartManager] Error toggling auto-start: \(error)")
                return false
            }
        }
        return false
    }
}
