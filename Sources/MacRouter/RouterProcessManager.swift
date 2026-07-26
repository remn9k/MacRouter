import Foundation
import Combine
import AppKit
import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case russian = "ru"
    case english = "en"

    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .russian: return "Русский 🇷🇺"
        case .english: return "English 🇬🇧"
        }
    }
}

public struct AccountQuotaInfo: Codable {
    public var googlePercentage: Int?
    public var googleOkCount: Int = 0
    public var googleTotalCount: Int = 0
    
    public var nonGooglePercentage: Int?
    public var nonGoogleOkCount: Int = 0
    public var nonGoogleTotalCount: Int = 0
    
    public var overallPercentage: Int?
}

public struct ProviderItem: Identifiable, Codable {
    public var id: String
    public var provider: String
    public var name: String
    public var email: String?
    public var authType: String?
    public var isActive: Bool?
    public var testStatus: String?
    public var lastError: String?
    public var latencyMs: Int?
    public var quotaInfo: AccountQuotaInfo?

    public var displayName: String {
        return name.isEmpty ? provider : name
    }

    public func cardTitle(index: Int) -> String {
        if provider.lowercased() == "antigravity" {
            if name == email || name.contains("@") {
                return "Antigravity #\(index + 1)"
            }
        }
        return displayName
    }

    public func maskedEmail(isMasked: Bool) -> String {
        let raw = email ?? name
        guard isMasked else { return raw }
        guard raw.contains("@") else { return raw }
        let parts = raw.components(separatedBy: "@")
        let local = parts[0]
        let domain = parts.dropFirst().joined(separator: "@")
        
        if local.count <= 4 {
            let f = local.prefix(1)
            let l = local.suffix(1)
            return "\(f)***\(l)@\(domain)"
        } else {
            let f2 = local.prefix(2)
            let l2 = local.suffix(2)
            return "\(f2)***\(l2)@\(domain)"
        }
    }

    public var isStatusGreen: Bool {
        if latencyMs != nil { return true }
        if let s = testStatus?.lowercased(), s == "valid" || s == "active" { return true }
        return isActive ?? true
    }

    public func statusBadge(language: AppLanguage) -> String {
        if let latency = latencyMs, latency > 0 {
            return "\(latency) ms"
        }
        if let err = lastError, !err.isEmpty {
            return language == .russian ? "Ошибка" : "Error"
        }
        if let status = testStatus, !status.isEmpty {
            return status.capitalized
        }
        return (isActive ?? true) ? (language == .russian ? "Активен" : "Active") : (language == .russian ? "Неактивен" : "Inactive")
    }
}

public struct ModelUsageItem: Identifiable, Codable {
    public var id: String { name }
    public var name: String
    public var requests: Int
    public var tokens: Int
}

public struct UsageStatsData {
    public var totalRequests: Int = 0
    public var promptTokens: Int = 0
    public var completionTokens: Int = 0
    public var cachedTokens: Int = 0
    public var totalTokens: Int = 0
    public var totalCost: Double = 0.0
    public var topModels: [ModelUsageItem] = []
}

@MainActor
public class RouterProcessManager: ObservableObject {
    @Published public var status: RouterStatus = .stopped {
        didSet {
            isServerRunning = (status.isRunning || status.isStarting)
        }
    }
    @Published public var isServerRunning: Bool = false
    @Published public var port: Int = 20128
    @Published public var portInput: String = "20128"
    @Published public var passwordInput: String = "123456"
    @Published public var passwordSavedNotice: String = ""
    @Published public var language: AppLanguage = .russian
    @Published public var statsPeriod: String = "today"
    @Published public var isInstalled: Bool = true
    @Published public var isInstalling: Bool = false
    @Published public var isPinging: Bool = false
    @Published public var installMessage: String = ""
    @Published public var providers: [ProviderItem] = []
    @Published public var usage: UsageStatsData = UsageStatsData()
    @Published public var isLaunchAtLogin: Bool = AutoStartManager.isEnabled
    @Published public var repoPath: String = ""
    @Published public var copyNotice: String = ""
    @Published public var updateNotice: String = ""
    @Published public var isLoggingEnabled: Bool = false
    @Published public var isUpdatingEngine: Bool = false
    @Published public var isEmailMasked: Bool = true
    @Published public var isCheckingQuota: Bool = false

    private var process: Process?
    private var healthCheckTimer: Timer?
    private var startTimeoutTimer: Timer?
    private var sessionCookie: String? = nil

    public init() {
        let savedPort = UserDefaults.standard.integer(forKey: "macrouter_port")
        self.port = savedPort > 0 ? savedPort : 20128
        self.portInput = "\(self.port)"
        
        let savedPass = UserDefaults.standard.string(forKey: "macrouter_password") ?? "123456"
        self.passwordInput = savedPass
        
        if let savedLang = UserDefaults.standard.string(forKey: "macrouter_language"),
           let lang = AppLanguage(rawValue: savedLang) {
            self.language = lang
        } else {
            self.language = .russian
        }
        
        self.repoPath = findRepoPath()
        
        let savedLogging = UserDefaults.standard.bool(forKey: "macrouter_logging")
        self.isLoggingEnabled = savedLogging
        
        let savedEmailMasked = UserDefaults.standard.object(forKey: "macrouter_email_masked") as? Bool ?? true
        self.isEmailMasked = savedEmailMasked

        checkInstallationStatus()
        startHealthCheckTimer()
        checkHealth()
        // Сервер запускается только по тумблеру, не при старте приложения
    }

    deinit {
        healthCheckTimer?.invalidate()
        startTimeoutTimer?.invalidate()
    }

    public func setLanguage(_ lang: AppLanguage) {
        self.language = lang
        UserDefaults.standard.set(lang.rawValue, forKey: "macrouter_language")
    }

    public func setStatsPeriod(_ period: String) {
        self.statsPeriod = period
        fetchUsageStats()
    }

    private func getFullSanitizedPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var paths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "\(home)/.nvm/versions/node/current/bin",
            "\(home)/.bun/bin",
            "\(home)/.yarn/bin"
        ]
        
        let nvmVersionsPath = "\(home)/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmVersionsPath) {
            for v in versions {
                paths.insert("\(nvmVersionsPath)/\(v)/bin", at: 0)
            }
        }
        
        if let envPath = ProcessInfo.processInfo.environment["PATH"] {
            paths.append(contentsOf: envPath.components(separatedBy: ":"))
        }
        
        return paths.joined(separator: ":")
    }

    public func checkInstallationStatus() {
        let repo = repoPath
        if FileManager.default.fileExists(atPath: "\(repo)/package.json") {
            isInstalled = true
            return
        }
        
        isInstalled = hasBinaryInPath("9router") || hasBinaryInPath("npx") || hasBinaryInPath("node")
    }

    private func hasBinaryInPath(_ binary: String) -> Bool {
        let task = Process()
        var newEnv = ProcessInfo.processInfo.environment
        newEnv["PATH"] = getFullSanitizedPath()
        task.environment = newEnv
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", binary]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }

    private func findRepoPath() -> String {
        let currentDir = FileManager.default.currentDirectoryPath
        if FileManager.default.fileExists(atPath: "\(currentDir)/package.json") {
            return currentDir
        }
        
        let homeProjects = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Projects/macrouter").path
        if FileManager.default.fileExists(atPath: "\(homeProjects)/package.json") {
            return homeProjects
        }
        
        return currentDir
    }

    public func startHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkHealth()
            }
        }
    }

    private var lastLoginAttempt: Date = .distantPast

    public func checkHealth() {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/settings") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let httpResponse = response as? HTTPURLResponse,
                   (httpResponse.statusCode == 200 || httpResponse.statusCode == 401) {
                    self.startTimeoutTimer?.invalidate()
                    self.startTimeoutTimer = nil
                    
                    if self.status != .running(port: self.port) {
                        self.status = .running(port: self.port)
                    }
                    self.isInstalled = true
                    
                    if self.sessionCookie == nil {
                        let now = Date()
                        if now.timeIntervalSince(self.lastLoginAttempt) > 8.0 {
                            self.lastLoginAttempt = now
                            self.login {
                                self.fetchProviders()
                                self.fetchUsageStats()
                            }
                        }
                    } else {
                        self.fetchProviders()
                        self.fetchUsageStats()
                    }
                } else {
                    if case .starting = self.status {
                        // Starting state handled by timeout
                    } else if self.status != .stopped {
                        self.status = .stopped
                        self.providers = []
                        self.sessionCookie = nil
                    }
                }
            }
        }.resume()
    }

    /// Логинимся в 9router через /api/auth/login и сохраняем cookie
    private func login(completion: (() -> Void)? = nil) {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/auth/login") else {
            completion?()
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 3.0
        let body = ["password": passwordInput]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // Используем отдельную сессию без сохранения куки чтобы вручную контролировать
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   let setCookie = httpResponse.value(forHTTPHeaderField: "Set-Cookie") {
                    // 9router возвращает: auth_token=eyJ...; Path=/; HttpOnly; SameSite=lax
                    let parts = setCookie.components(separatedBy: ";")
                    if let tokenPart = parts.first?.trimmingCharacters(in: .whitespaces) {
                        self.sessionCookie = tokenPart  // "auth_token=eyJ..."
                    }
                } else if let data = data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let token = json["auth_token"] as? String ?? json["token"] as? String {
                    self.sessionCookie = "auth_token=\(token)"
                }
                completion?()
            }
        }.resume()
    }

    /// Создаёт авторизованный URLRequest с куки-сессией
    private func authenticatedRequest(url: URL, method: String = "GET", timeoutInterval: TimeInterval = 15.0) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeoutInterval
        if let cookie = sessionCookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        return request
    }

    public func fetchProviders() {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/providers") else { return }
        let req = authenticatedRequest(url: url)
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            // Если 401 — пробуем перелогиниться и повторить
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                DispatchQueue.main.async {
                    self?.login { self?.fetchProviders() }
                }
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let connectionsJson = json["connections"] as? [[String: Any]] else { return }
            
            let items: [ProviderItem] = connectionsJson.compactMap { dict in
                guard let id = dict["id"] as? String,
                      let provider = dict["provider"] as? String else { return nil }
                
                return ProviderItem(
                    id: id,
                    provider: provider,
                    name: (dict["name"] as? String) ?? provider,
                    email: dict["email"] as? String,
                    authType: dict["authType"] as? String,
                    isActive: dict["isActive"] as? Bool,
                    testStatus: dict["testStatus"] as? String,
                    lastError: dict["lastError"] as? String,
                    latencyMs: nil,
                    quotaInfo: nil
                )
            }
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                var mergedItems = items
                for i in 0..<mergedItems.count {
                    if let existing = self.providers.first(where: { $0.id == mergedItems[i].id }) {
                        mergedItems[i].latencyMs = existing.latencyMs
                        mergedItems[i].quotaInfo = existing.quotaInfo
                    }
                }
                self.providers = mergedItems
            }
        }.resume()
    }

    public func setEmailMasked(_ masked: Bool) {
        self.isEmailMasked = masked
        UserDefaults.standard.set(masked, forKey: "macrouter_email_masked")
    }

    public func quotaColor(_ percentage: Int) -> Color {
        if percentage >= 60 {
            return .green
        } else if percentage >= 20 {
            return .orange
        } else {
            return .red
        }
    }

    public func fetchQuotas() {
        guard status.isRunning, !isCheckingQuota else { return }
        isCheckingQuota = true
        log("[QUOTA] Starting quota check for \(providers.count) providers")
        
        let group = DispatchGroup()
        let currentProviders = self.providers
        
        for item in currentProviders {
            guard let url = URL(string: "http://127.0.0.1:\(port)/api/providers/\(item.id)/test-models") else { continue }
            
            group.enter()
            let req = authenticatedRequest(url: url, method: "POST", timeoutInterval: 25.0)
            
            URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
                defer { group.leave() }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let results = json["results"] as? [[String: Any]] else { return }
                
                var gOk = 0, gTotal = 0
                var ngOk = 0, ngTotal = 0
                var totalOk = 0, totalCount = 0
                var latencies: [Int] = []
                
                for res in results {
                    let modelId = (res["modelId"] as? String ?? "").lowercased()
                    let modelName = (res["name"] as? String ?? "").lowercased()
                    let ok = (res["ok"] as? Bool) ?? false
                    let lat = (res["latencyMs"] as? Int) ?? 0
                    
                    totalCount += 1
                    if ok {
                        totalOk += 1
                        if lat > 0 { latencies.append(lat) }
                    }
                    
                    let isNonGoogle = modelId.contains("claude") || modelId.contains("gpt-oss") || modelName.contains("claude") || modelName.contains("gpt-oss")
                    
                    if isNonGoogle {
                        ngTotal += 1
                        if ok { ngOk += 1 }
                    } else {
                        gTotal += 1
                        if ok { gOk += 1 }
                    }
                }
                
                let gPct = gTotal > 0 ? (gOk * 100) / gTotal : nil
                let ngPct = ngTotal > 0 ? (ngOk * 100) / ngTotal : nil
                let overallPct = totalCount > 0 ? (totalOk * 100) / totalCount : nil
                let avgLat = latencies.isEmpty ? nil : latencies.reduce(0, +) / latencies.count
                
                let qInfo = AccountQuotaInfo(
                    googlePercentage: gPct,
                    googleOkCount: gOk,
                    googleTotalCount: gTotal,
                    nonGooglePercentage: ngPct,
                    nonGoogleOkCount: ngOk,
                    nonGoogleTotalCount: ngTotal,
                    overallPercentage: overallPct
                )
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.status.isRunning else { return }
                    if let idx = self.providers.firstIndex(where: { $0.id == item.id }) {
                        self.providers[idx].quotaInfo = qInfo
                        if let avg = avgLat {
                            self.providers[idx].latencyMs = avg
                            self.providers[idx].testStatus = "active"
                        }
                    }
                }
            }.resume()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isCheckingQuota = false
            self.log("[QUOTA] Quota check completed")
        }
    }

    public func pingProviders() {
        guard status.isRunning, !isPinging else { return }
        isPinging = true
        
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/providers/test-batch") else {
            isPinging = false
            return
        }
        
        var request = authenticatedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["mode": "all"])
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self, self.status.isRunning else {
                    self?.isPinging = false
                    return
                }
                self.isPinging = false
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let results = json["results"] as? [[String: Any]] else { return }
                
                var updated = self.providers
                for r in results {
                    if let connId = r["connectionId"] as? String,
                       let index = updated.firstIndex(where: { $0.id == connId }) {
                        let valid = (r["valid"] as? Bool) ?? false
                        let latency = (r["latencyMs"] as? Int) ?? 0
                        updated[index].latencyMs = valid ? latency : nil
                        updated[index].testStatus = valid ? "valid" : "invalid"
                    }
                }
                self.providers = updated
            }
        }.resume()
    }

    public func fetchUsageStats() {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/usage/stats?period=\(statsPeriod)") else { return }
        let req = authenticatedRequest(url: url)
        URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                DispatchQueue.main.async { self?.login { self?.fetchUsageStats() } }
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            
            let reqs = (json["totalRequests"] as? Int) ?? (json["requests"] as? Int) ?? 0
            let pTokens = (json["totalPromptTokens"] as? Int) ?? (json["promptTokens"] as? Int) ?? 0
            let cTokens = (json["totalCompletionTokens"] as? Int) ?? (json["completionTokens"] as? Int) ?? 0
            let kTokens = (json["totalCachedTokens"] as? Int) ?? (json["cachedTokens"] as? Int) ?? 0
            let totalT = pTokens + cTokens
            let cost = (json["totalCost"] as? Double) ?? (json["cost"] as? Double) ?? 0.0
            
            var modelsList: [ModelUsageItem] = []
            if let byModel = json["byModel"] as? [String: [String: Any]] {
                modelsList = byModel.map { (key, val) in
                    let rawName = (val["rawModel"] as? String) ?? key.components(separatedBy: " ").first ?? key
                    let rCount = (val["requests"] as? Int) ?? 0
                    let pT = (val["promptTokens"] as? Int) ?? 0
                    let cT = (val["completionTokens"] as? Int) ?? 0
                    return ModelUsageItem(name: rawName, requests: rCount, tokens: pT + cT)
                }.sorted(by: { $0.requests > $1.requests })
            }
            
            DispatchQueue.main.async {
                self?.usage = UsageStatsData(
                    totalRequests: reqs,
                    promptTokens: pTokens,
                    completionTokens: cTokens,
                    cachedTokens: kTokens,
                    totalTokens: totalT,
                    totalCost: cost,
                    topModels: Array(modelsList.prefix(3))
                )
            }
        }.resume()
    }

    public func applyPortSetting() {
        if let newPort = Int(portInput.trimmingCharacters(in: .whitespacesAndNewlines)), newPort > 1000 && newPort < 65535 {
            self.port = newPort
            UserDefaults.standard.set(newPort, forKey: "macrouter_port")
            restartServer()
        }
    }

    public func resetPortToDefault() {
        self.port = 20128
        self.portInput = "20128"
        UserDefaults.standard.set(20128, forKey: "macrouter_port")
        restartServer()
    }

    public func savePasswordSetting() {
        let pass = passwordInput.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(pass, forKey: "macrouter_password")
        passwordSavedNotice = language == .russian ? "Сохранено!" : "Saved!"
        
        login { [weak self] in
            self?.fetchProviders()
            self?.fetchUsageStats()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.passwordSavedNotice = ""
        }
    }

    public func resetPasswordToDefault() {
        self.passwordInput = "123456"
        UserDefaults.standard.set("123456", forKey: "macrouter_password")
        
        let dbPath = "\(NSHomeDirectory())/.9router/db/data.sqlite"
        if FileManager.default.fileExists(atPath: dbPath) {
            let cleanTask = Process()
            cleanTask.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            cleanTask.arguments = ["sqlite3", dbPath, "UPDATE settings SET data = '{}' WHERE id = 1;"]
            try? cleanTask.run()
            cleanTask.waitUntilExit()
        }

        passwordSavedNotice = language == .russian ? "Сброшено (123456)" : "Reset (123456)"
        
        login { [weak self] in
            self?.fetchProviders()
            self?.fetchUsageStats()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.passwordSavedNotice = ""
        }
    }

    public func copyApiUrl() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("http://localhost:\(port)/v1", forType: .string)
        
        copyNotice = language == .russian ? "Скопировано!" : "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            self.copyNotice = ""
        }
    }
    public func installAndStart() {
        guard !isInstalling else { return }
        isInstalling = true
        installMessage = language == .russian ? "Установка MacRouter..." : "Installing MacRouter..."
        status = .starting(phase: installMessage)

        let sanitizedPath = getFullSanitizedPath()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            var newEnv = ProcessInfo.processInfo.environment
            newEnv["PATH"] = sanitizedPath
            task.environment = newEnv
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["npm", "install", "-g", "9router"]

            try? task.run()
            task.waitUntilExit()

            DispatchQueue.main.async {
                self?.isInstalling = false
                self?.isInstalled = true
                self?.startServer()
            }
        }
    }

    public func toggleServer() {
        if status.isRunning || status.isStarting {
            stopServer()
        } else {
            startServer()
        }
    }

    public func handleToggleChange(_ targetState: Bool) {
        if targetState {
            if !status.isRunning && !status.isStarting {
                startServer()
            }
        } else {
            if status.isRunning || status.isStarting {
                stopServer()
            }
        }
    }

    public func checkForUpdates() {
        guard !isUpdatingEngine else { return }
        isUpdatingEngine = true
        updateNotice = language == .russian ? "Проверка обновлений..." : "Checking for updates..."
        
        let sanitizedPath = getFullSanitizedPath()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            var newEnv = ProcessInfo.processInfo.environment
            newEnv["PATH"] = sanitizedPath
            task.environment = newEnv
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["npm", "install", "-g", "9router@latest"]
            
            try? task.run()
            task.waitUntilExit()
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isUpdatingEngine = false
                let success = (task.terminationStatus == 0)
                if success {
                    self.updateNotice = self.language == .russian ? "9Router обновлен!" : "9Router updated!"
                    if self.status.isRunning {
                        self.restartServer()
                    }
                } else {
                    self.updateNotice = self.language == .russian ? "Обновление завершено" : "Update complete"
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.updateNotice = ""
                }
            }
        }
    }

    public func restartServer() {
        stopServer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startServer()
        }
    }

    // Возвращает путь к custom-server.js (прямой запуск Next.js, без CLI tray/kill логики)
    private func find9routerServerPath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/lib/node_modules/9router/app/custom-server.js",
            "/opt/homebrew/lib/node_modules/9router/app/server.js",
            "/usr/local/lib/node_modules/9router/app/custom-server.js",
            "/usr/local/lib/node_modules/9router/app/server.js"
        ]
        for p in candidates {
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        let nvmDir = "\(home)/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) {
            for v in versions {
                let p = "\(nvmDir)/\(v)/lib/node_modules/9router/app/custom-server.js"
                if FileManager.default.fileExists(atPath: p) { return p }
            }
        }
        return nil
    }

    private nonisolated func log(_ message: String) {
        let logPath = "/tmp/macrouter.log"
        guard FileManager.default.fileExists(atPath: logPath) || UserDefaults.standard.bool(forKey: "macrouter_logging") else { return }
        let line = "[\(Date())] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let fh = FileHandle(forWritingAtPath: logPath) {
                    fh.seekToEndOfFile()
                    fh.write(data)
                    fh.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: logPath, contents: data)
            }
        }
    }

    public func setLoggingEnabled(_ enabled: Bool) {
        isLoggingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "macrouter_logging")
        if enabled {
            let logPath = "/tmp/macrouter.log"
            let header = "--- MacRouter Logging Enabled \(Date()) ---\n"
            try? header.write(toFile: logPath, atomically: true, encoding: .utf8)
        }
    }

    public func startServer() {
        guard !status.isRunning else { return }

        // Очищаем лог при каждом запуске
        let logPath = "/tmp/macrouter.log"
        try? "--- MacRouter Start \(Date()) ---\n".write(toFile: logPath, atomically: true, encoding: .utf8)

        let phase1 = language == .russian ? "Очистка порта :\(port)..." : "Cleaning port :\(port)..."
        status = .starting(phase: phase1)
        log("[START] port=\(port)")

        let targetPort = self.port
        let targetPassword = self.passwordInput
        let targetRepo = self.repoPath
        let sanitizedPath = getFullSanitizedPath()
        let errMessage = language == .russian ? "Таймаут запуска" : "Launch timeout"
        let serverPath = find9routerServerPath()
        log("[START] serverPath=\(serverPath ?? "nil"), repo=\(targetRepo)")

        startTimeoutTimer?.invalidate()
        startTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if case .starting = self.status {
                    self.log("[ERROR] Timeout after 30s")
                    self.status = .error(message: errMessage)
                }
            }
        }

        let isNextRepo = FileManager.default.fileExists(atPath: "\(targetRepo)/node_modules/.bin/next")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Шаг 1: очистка порта
            self.log("[STEP1] Killing processes on port \(targetPort)")
            let cleanTask = Process()
            var cleanEnv = ProcessInfo.processInfo.environment
            cleanEnv["PATH"] = sanitizedPath
            cleanTask.environment = cleanEnv
            cleanTask.executableURL = URL(fileURLWithPath: "/bin/bash")
            cleanTask.arguments = ["-c", "lsof -ti:\(targetPort) | xargs kill -9 2>/dev/null || true"]
            try? cleanTask.run()
            cleanTask.waitUntilExit()
            self.log("[STEP1] Port cleared")

            // Шаг 2: статус запуска
            DispatchQueue.main.async {
                if case .starting = self.status {
                    let ph = self.language == .russian ? "Запуск сервера..." : "Launching server..."
                    self.status = .starting(phase: ph)
                }
            }

            // Шаг 3: подготовка процесса
            let task = Process()
            var newEnv = ProcessInfo.processInfo.environment
            newEnv["PORT"] = "\(targetPort)"
            newEnv["HOSTNAME"] = "127.0.0.1"
            newEnv["INITIAL_PASSWORD"] = targetPassword
            newEnv["PATH"] = sanitizedPath
            task.environment = newEnv

            // Выбираем метод запуска: custom-server.js (без tray/kill) > next dev > 9router cli
            if isNextRepo {
                self.log("[STEP3] Mode: next dev repo")
                task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                task.arguments = ["npx", "next", "dev", "--port", "\(targetPort)"]
                task.currentDirectoryURL = URL(fileURLWithPath: targetRepo)
            } else if let srv = serverPath {
                self.log("[STEP3] Mode: direct custom-server.js at \(srv)")
                let nodeDir = URL(fileURLWithPath: srv).deletingLastPathComponent().path
                task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                task.arguments = ["node", "--dns-result-order=ipv4first", srv]
                task.currentDirectoryURL = URL(fileURLWithPath: nodeDir)
            } else {
                self.log("[STEP3] Mode: 9router cli fallback")
                task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                task.arguments = ["node", "/opt/homebrew/lib/node_modules/9router/cli.js", "--no-browser", "--port", "\(targetPort)"]
                task.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
            }

            // Пайпы для вывода → пишем всё в лог
            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = errPipe

            let appendToLog = { [weak self] (data: Data) in
                guard let str = String(data: data, encoding: .utf8), !str.isEmpty else { return }
                self?.log("[9ROUTER] " + str.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            outPipe.fileHandleForReading.readabilityHandler = { appendToLog($0.availableData) }
            errPipe.fileHandleForReading.readabilityHandler = { appendToLog($0.availableData) }

            task.terminationHandler = { [weak self] proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                let code = proc.terminationStatus
                self?.log("[EXIT] terminationStatus=\(code)")
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if case .starting = self.status {
                        let errText = self.language == .russian
                            ? "Сервер завершился (\(code))"
                            : "Server exited (\(code))"
                        self.status = .error(message: errText)
                    }
                }
            }

            // Шаг 4: запуск
            do {
                try task.run()
                self.log("[STEP4] Process launched PID=\(task.processIdentifier)")
                DispatchQueue.main.async {
                    self.process = task
                    if case .starting = self.status {
                        let ph = self.language == .russian
                            ? "Ожидание ответа сервера..."
                            : "Waiting for server..."
                        self.status = .starting(phase: ph)
                    }
                }
            } catch {
                self.log("[ERROR] Failed to launch: \(error)")
                DispatchQueue.main.async {
                    self.status = .error(message: error.localizedDescription)
                }
                return
            }

            // Шаг 5: ждём готовности (polling каждые 300ms до 20 сек)
            for i in 1...66 {
                Thread.sleep(forTimeInterval: 0.3)
                if i % 5 == 0 {
                    self.log("[POLL] attempt \(i)/66")
                }
                DispatchQueue.main.async {
                    self.checkHealth()
                }
                if case .running = self.status { break }
            }
        }
    }





    public func stopServer() {
        startTimeoutTimer?.invalidate()
        startTimeoutTimer = nil
        status = .stopped
        isPinging = false
        isCheckingQuota = false
        
        let targetPort = self.port
        let sanitizedPath = getFullSanitizedPath()

        if let process = process, process.isRunning {
            process.terminate()
            self.process = nil
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let task = Process()
            var newEnv = ProcessInfo.processInfo.environment
            newEnv["PATH"] = sanitizedPath
            task.environment = newEnv
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["bash", "-c", "lsof -ti:\(targetPort) | xargs kill -9 2>/dev/null || true"]
            try? task.run()
            task.waitUntilExit()
            
            DispatchQueue.main.async {
                self?.checkHealth()
            }
        }
    }

    public func toggleAutoStart() {
        let newState = !isLaunchAtLogin
        if AutoStartManager.setEnabled(newState) {
            isLaunchAtLogin = newState
        }
    }
}
