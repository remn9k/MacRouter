import SwiftUI

public enum PopoverTab: String, CaseIterable, Identifiable {
    case accounts = "Accounts & Limits"
    case limits = "Usage Stats"
    case settings = "Settings"
    
    public var id: String { self.rawValue }
    
    public func title(language: AppLanguage) -> String {
        switch self {
        case .accounts: return language == .russian ? "Аккаунты" : "Accounts"
        case .limits: return language == .russian ? "Статистика" : "Stats"
        case .settings: return language == .russian ? "Настройки" : "Settings"
        }
    }
}

public struct PopoverContentView: View {
    @ObservedObject var processManager: RouterProcessManager
    @State private var selectedTab: PopoverTab = .accounts

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Card with Green Running Accent
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(headerBadgeBackground)
                        .frame(width: 38, height: 38)
                        .shadow(color: processManager.status.isRunning ? Color.green.opacity(0.35) : Color.clear, radius: 5)
                    
                    Image(nsImage: makeMaterialRouteIcon(size: NSSize(width: 22, height: 22)))
                        .renderingMode(.template)
                        .foregroundColor(processManager.status.isRunning ? Color.white : Color.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("MacRouter")
                        .font(.system(size: 16, weight: .black))
                    
                    Text(processManager.status.statusText(language: processManager.language))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(statusLabelColor)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { processManager.isServerRunning },
                    set: { newValue in processManager.handleToggleChange(newValue) }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .green))
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.85))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // Left-Aligned Custom Tab Bar
            HStack(spacing: 4) {
                ForEach(PopoverTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = tab
                        }
                    }) {
                        Text(tab.title(language: processManager.language))
                            .font(.system(size: 11, weight: selectedTab == tab ? .bold : .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedTab == tab ? Color(NSColor.controlAccentColor).opacity(0.2) : Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            // Fixed-Height Tab Container (Zero Window Resize Jumping!)
            ZStack(alignment: .topLeading) {
                if selectedTab == .accounts {
                    AccountsTabView(processManager: processManager)
                        .transition(.opacity)
                } else if selectedTab == .limits {
                    LimitsTabView(processManager: processManager)
                        .transition(.opacity)
                } else if selectedTab == .settings {
                    SettingsTabView(processManager: processManager)
                        .transition(.opacity)
                }
            }
            .frame(height: 220, alignment: .top)

            Spacer(minLength: 0)

            Divider()

            // Quick Actions: Dashboard + Copy API URL
            HStack(spacing: 8) {
                Button(action: openDashboard) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari.fill")
                            .foregroundColor(.blue)
                        Text("Dashboard")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    processManager.copyApiUrl()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: processManager.copyNotice.isEmpty ? "doc.on.doc" : "checkmark.circle.fill")
                            .foregroundColor(processManager.copyNotice.isEmpty ? .secondary : .green)
                        Text(processManager.copyNotice.isEmpty ? (processManager.language == .russian ? "Копировать API" : "Copy API URL") : processManager.copyNotice)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(processManager.copyNotice.isEmpty ? .primary : .green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Footer Section
            HStack {
                Toggle(processManager.language == .russian ? "Автозапуск при входе" : "Launch at Startup", isOn: Binding(
                    get: { processManager.isLaunchAtLogin },
                    set: { _ in processManager.toggleAutoStart() }
                ))
                .font(.system(size: 11, weight: .medium))
                .toggleStyle(.checkbox)

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text(processManager.language == .russian ? "Выйти" : "Quit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 320, height: 455, alignment: .top)
    }

    private var statusLabelColor: Color {
        if processManager.status.isRunning { return .green }
        if processManager.status.isStarting { return .orange }
        if case .error = processManager.status { return .red }
        return .secondary
    }

    private var headerBadgeBackground: Color {
        if processManager.status.isRunning {
            return Color.green
        } else if processManager.status.isStarting {
            return Color.orange.opacity(0.8)
        } else {
            return Color.secondary.opacity(0.2)
        }
    }



    private func openDashboard() {
        if let url = URL(string: "http://localhost:\(processManager.port)/dashboard") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Accounts Tab View with Ping Feature
struct AccountsTabView: View {
    @ObservedObject var processManager: RouterProcessManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !processManager.status.isRunning {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "power.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text(processManager.language == .russian ? "Включите сервер для просмотра аккаунтов" : "Start server to view accounts")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                HStack {
                    Text(processManager.language == .russian ? "Подключения" : "Connections")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        processManager.fetchQuotas()
                    }) {
                        HStack(spacing: 4) {
                            if processManager.isCheckingQuota {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 10, height: 10)
                            } else {
                                Image(systemName: "chart.bar.doc.horizontal")
                            }
                            Text(processManager.language == .russian ? "Квота" : "Quota")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(processManager.isCheckingQuota)

                    Button(action: {
                        processManager.pingProviders()
                    }) {
                        HStack(spacing: 4) {
                            if processManager.isPinging {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 10, height: 10)
                            } else {
                                Image(systemName: "waveform.path.ecg")
                            }
                            Text(processManager.language == .russian ? "Пинг" : "Ping All")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(processManager.isPinging)
                }

                if processManager.providers.isEmpty {
                    HStack {
                        Spacer()
                        Text(processManager.language == .russian ? "Нет подключенных аккаунтов" : "No connected accounts found")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 16)
                        Spacer()
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(Array(processManager.providers.enumerated()), id: \.element.id) { index, item in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.cardTitle(index: index))
                                                .font(.system(size: 12, weight: .semibold))
                                            
                                            HStack(spacing: 4) {
                                                Text(item.maskedEmail(isMasked: processManager.isEmailMasked))
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                                
                                                if let auth = item.authType {
                                                    Text("• \(auth.uppercased())")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.secondary.opacity(0.8))
                                                }
                                            }
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(item.statusBadge(language: processManager.language))
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(item.isStatusGreen ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                                .foregroundColor(item.isStatusGreen ? .green : .orange)
                                                .cornerRadius(4)
                                        }
                                    }

                                    if let q = item.quotaInfo {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Divider().padding(.vertical, 1)
                                            if item.provider.lowercased() == "antigravity" {
                                                HStack(spacing: 12) {
                                                    if let gPct = q.googlePercentage {
                                                        HStack(spacing: 2) {
                                                            Text("Gemini:")
                                                                .font(.system(size: 9, weight: .medium))
                                                                .foregroundColor(.secondary)
                                                            Text("\(gPct)%")
                                                                .font(.system(size: 10, weight: .bold))
                                                                .foregroundColor(processManager.quotaColor(gPct))
                                                        }
                                                    }
                                                    if let ngPct = q.nonGooglePercentage {
                                                        HStack(spacing: 2) {
                                                            Text("Claude:")
                                                                .font(.system(size: 9, weight: .medium))
                                                                .foregroundColor(.secondary)
                                                            Text("\(ngPct)%")
                                                                .font(.system(size: 10, weight: .bold))
                                                                .foregroundColor(processManager.quotaColor(ngPct))
                                                        }
                                                    }
                                                }
                                            } else if let pct = q.overallPercentage {
                                                HStack(spacing: 2) {
                                                    Text(processManager.language == .russian ? "Квота:" : "Quota:")
                                                        .font(.system(size: 9, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                    Text("\(pct)%")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(processManager.quotaColor(pct))
                                                }
                                            }
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(6)
                                .animation(.easeInOut(duration: 0.35), value: item.quotaInfo != nil)
                            }
                        }
                    }
                    .frame(height: 145)
                }
            }
        }
    }
}

// MARK: - 2x2 Grid Tile Stats View with All-Time Period Option
struct LimitsTabView: View {
    @ObservedObject var processManager: RouterProcessManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !processManager.status.isRunning {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "power.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text(processManager.language == .russian ? "Включите сервер для просмотра статистики" : "Start server to view usage stats")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                // Period Selector Pills (Today / 7d / 30d / All)
                HStack {
                    Text(processManager.language == .russian ? "Период:" : "Period:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    Spacer()

                    HStack(spacing: 3) {
                        PeriodButton(title: processManager.language == .russian ? "Сегодня" : "Today", value: "today", current: processManager.statsPeriod) {
                            processManager.setStatsPeriod("today")
                        }
                        PeriodButton(title: processManager.language == .russian ? "7 дн" : "7d", value: "7d", current: processManager.statsPeriod) {
                            processManager.setStatsPeriod("7d")
                        }
                        PeriodButton(title: processManager.language == .russian ? "30 дн" : "30d", value: "30d", current: processManager.statsPeriod) {
                            processManager.setStatsPeriod("30d")
                        }
                        PeriodButton(title: processManager.language == .russian ? "Всё время" : "All", value: "all", current: processManager.statsPeriod) {
                            processManager.setStatsPeriod("all")
                        }
                    }
                }

                VStack(spacing: 6) {
                    // 2x2 Grid of Stat Cards (Tile 1 & 2)
                    HStack(spacing: 6) {
                        SmallStatCard(
                            title: processManager.language == .russian ? "Запросов" : "Requests",
                            value: "\(processManager.usage.totalRequests)",
                            icon: "bolt.fill",
                            color: .orange
                        )
                        SmallStatCard(
                            title: processManager.language == .russian ? "Расходы" : "Est. Cost",
                            value: String(format: "$%.4f", processManager.usage.totalCost),
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )
                    }

                    // Tile 3 & 4 (Prompt & Completion Tokens)
                    HStack(spacing: 6) {
                        SmallStatCard(
                            title: processManager.language == .russian ? "Входные" : "Prompt",
                            value: formatTokens(processManager.usage.promptTokens),
                            icon: "arrow.down.doc.fill",
                            color: .blue
                        )
                        SmallStatCard(
                            title: processManager.language == .russian ? "Выходные" : "Completion",
                            value: formatTokens(processManager.usage.completionTokens),
                            icon: "arrow.up.doc.fill",
                            color: .purple
                        )
                    }

                    if processManager.usage.cachedTokens > 0 {
                        SmallStatCard(
                            title: processManager.language == .russian ? "Кэшированные токены" : "Cached Tokens",
                            value: formatTokens(processManager.usage.cachedTokens),
                            icon: "sparkles",
                            color: .teal
                        )
                    }
                }
            }
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.2fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        }
        return "\(count)"
    }
}

struct PeriodButton: View {
    let title: String
    let value: String
    let current: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: current == value ? .bold : .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(current == value ? Color.blue.opacity(0.2) : Color.clear)
                .foregroundColor(current == value ? .blue : .secondary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

struct SmallStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 11, weight: .bold))
            }
            Spacer()
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

// MARK: - Settings Tab View
struct SettingsTabView: View {
    @ObservedObject var processManager: RouterProcessManager

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 8) {
                // Language Selection
                HStack {
                    Text(processManager.language == .russian ? "Язык" : "Language")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { processManager.language },
                        set: { newLang in processManager.setLanguage(newLang) }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.title).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 11))
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)

                // Control (Single row: Title "Control" + Restart button + Update button)
                HStack(spacing: 8) {
                    Text(processManager.language == .russian ? "Управление" : "Control")
                        .font(.system(size: 11, weight: .semibold))
                    
                    Spacer()

                    Button(action: {
                        processManager.restartServer()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text(processManager.language == .russian ? "Перезапустить" : "Restart")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }

                    Button(action: {
                        processManager.checkForUpdates()
                    }) {
                        HStack(spacing: 4) {
                            if processManager.isUpdatingEngine {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 10, height: 10)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(processManager.updateNotice.isEmpty ? (processManager.language == .russian ? "Обновить" : "Update") : processManager.updateNotice)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(processManager.updateNotice.contains("обновлен") || processManager.updateNotice.contains("updated") ? .green : .primary)
                    }
                    .disabled(processManager.isUpdatingEngine)
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)

                // Email Masking Toggle
                HStack {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(processManager.language == .russian ? "Скрывать Email" : "Mask Email")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { processManager.isEmailMasked },
                        set: { processManager.setEmailMasked($0) }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)

                // Logging Toggle
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(processManager.language == .russian ? "Логирование" : "Logging")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { processManager.isLoggingEnabled },
                        set: { processManager.setLoggingEnabled($0) }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)

                // Port Config (Buttons Aligned to RIGHT edge)
                VStack(alignment: .leading, spacing: 4) {
                    Text(processManager.language == .russian ? "Порт подключения" : "Server Port")
                        .font(.system(size: 11, weight: .semibold))
                    
                    HStack(spacing: 8) {
                        TextField("20128", text: $processManager.portInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .frame(width: 75)
                        
                        Spacer()

                        Button(processManager.language == .russian ? "Применить" : "Apply") {
                            processManager.applyPortSetting()
                        }
                        .font(.system(size: 11, weight: .medium))

                        Button(processManager.language == .russian ? "Сбросить" : "Reset") {
                            processManager.resetPortToDefault()
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)

                // Password Config (Buttons Aligned to RIGHT edge)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(processManager.language == .russian ? "Пароль доступа" : "Access Password")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        if !processManager.passwordSavedNotice.isEmpty {
                            Text(processManager.passwordSavedNotice)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        SecureField("••••••", text: $processManager.passwordInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .frame(width: 80)
                        
                        Spacer()

                        Button(processManager.language == .russian ? "Сохранить" : "Save") {
                            processManager.savePasswordSetting()
                        }
                        .font(.system(size: 11, weight: .medium))

                        Button(processManager.language == .russian ? "Сбросить" : "Reset") {
                            processManager.resetPasswordToDefault()
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)
            }
            .padding(.trailing, 4)
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 11, weight: .medium))

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .bold))
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}
