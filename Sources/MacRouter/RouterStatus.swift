import Foundation

public enum RouterStatus: Equatable {
    case stopped
    case starting(phase: String?)
    case running(port: Int)
    case error(message: String)

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    public var isStarting: Bool {
        if case .starting = self { return true }
        return false
    }

    public func statusText(language: AppLanguage) -> String {
        switch self {
        case .stopped:
            return language == .russian ? "Остановлено" : "Stopped"
        case .starting(let phase):
            if let p = phase, !p.isEmpty {
                return p
            }
            return language == .russian ? "Запуск..." : "Starting..."
        case .running(let port):
            return language == .russian ? "Подключено (:\(port))" : "Connected (:\(port))"
        case .error(let msg):
            return language == .russian ? "Ошибка: \(msg)" : "Error: \(msg)"
        }
    }
}
